# simulate_data.R
# Data generation functions for Taurine Long COVID clinical trial simulation

#' Simulate clinical trial data for two co-primary outcomes
#'
#' Generates baseline and 3-month follow-up data for TMT B/A Ratio and MFIS
#' with treatment effects and correlated errors.
#'
#' @param n Total sample size
#' @param outcomes List of outcome parameters (from parameters.R)
#' @param true_effects List of true treatment effects (from parameters.R)
#' @param sim_params Simulation parameters (from parameters.R)
#' @param seed Random seed for reproducibility
#' @return List formatted for Stan model input
simulate_trial_data <- function(n,
                                 outcomes = NULL,
                                 true_effects = NULL,
                                 sim_params = NULL,
                                 seed = NULL) {
# Use global defaults if not provided (must source parameters.R first)
if (is.null(outcomes)) outcomes <- get("outcomes", envir = globalenv())
if (is.null(true_effects)) true_effects <- get("true_effects", envir = globalenv())
if (is.null(sim_params)) sim_params <- get("sim_params", envir = globalenv())

if (!is.null(seed)) set.seed(seed)

# Simulate baseline TMT (truncated normal)
tmt_base <- truncnorm::rtruncnorm(
  n = n,
  a = outcomes$tmt$range[1],
  b = outcomes$tmt$range[2],
  mean = outcomes$tmt$mean + outcomes$tmt$baseline_adjustment,
  sd = outcomes$tmt$sd
)

# Simulate baseline MFIS (truncated normal)
mfis_base <- truncnorm::rtruncnorm(
  n = n,
  a = outcomes$mfis$range[1],
  b = outcomes$mfis$range[2],
  mean = outcomes$mfis$mean + outcomes$mfis$baseline_adjustment,
  sd = outcomes$mfis$sd
)

# Simulate treatment assignment (2:1 ratio)
treat <- rbinom(n, size = 1, prob = sim_params$allocation_ratio)

# Compute standardized baseline deviations (for probabilistic adjustments)
tmt_deviation <- (tmt_base - outcomes$tmt$mean) / outcomes$tmt$sd
mfis_deviation <- (mfis_base - outcomes$mfis$mean) / outcomes$mfis$sd

# Probability of regression-to-mean adjustment
prob_regress <- plogis(2 * (tmt_deviation + 0.5))
random_direction <- ifelse(runif(n) < prob_regress, -1, 1)

# Magnitude of natural variation
max_change_tmt <- 0.2 * abs(tmt_base)
max_change_mfis <- 0.2 * abs(mfis_base)

# Random adjustments (bounded)
random_adj_tmt <- random_direction * rnorm(n, 0, max_change_tmt / 5)
random_adj_mfis <- random_direction * rnorm(n, 0, max_change_mfis / 5)
random_adj_tmt <- pmax(-max_change_tmt, pmin(max_change_tmt, random_adj_tmt))
random_adj_mfis <- pmax(-max_change_mfis, pmin(max_change_mfis, random_adj_mfis))

# Expected follow-up means
mu_tmt <- tmt_base + random_adj_tmt + true_effects$tmt$gamma_treat * treat
mu_mfis <- mfis_base + random_adj_mfis + true_effects$mfis$gamma_treat * treat

# Covariance matrix for bivariate errors
sigma_tmt <- true_effects$tmt$sigma
sigma_mfis <- true_effects$mfis$sigma
rho <- true_effects$rho

Sigma <- matrix(
  c(sigma_tmt^2, rho * sigma_tmt * sigma_mfis,
    rho * sigma_tmt * sigma_mfis, sigma_mfis^2),
  nrow = 2
)

# Simulate correlated errors
eps <- mvtnorm::rmvnorm(n, mean = c(0, 0), sigma = Sigma)

# Generate follow-up outcomes with truncation to clinical bounds
tmt_3m <- pmax(outcomes$tmt$range[1],
               pmin(outcomes$tmt$range[2], mu_tmt + eps[, 1]))
mfis_3m <- pmax(outcomes$mfis$range[1],
                pmin(outcomes$mfis$range[2], mu_mfis + eps[, 2]))

# Return data formatted for Stan
list(
  N = n,
  treat = as.integer(treat),
  tmt_base = tmt_base,
  mfis_base = mfis_base,
  tmt_3m = tmt_3m,
  mfis_3m = mfis_3m
)
}


#' Validate simulated data
#'
#' Check that simulated data meets expected distributional properties.
#'
#' @param data Simulated data list from simulate_trial_data()
#' @param outcomes Outcome parameters
#' @param verbose Print diagnostic information
#' @return List with validation results
validate_simulation <- function(data, outcomes = NULL, verbose = TRUE) {
if (is.null(outcomes)) {
  outcomes <- get("outcomes", envir = globalenv())
}

results <- list()

# Check sample size
results$n <- data$N

# Check treatment allocation
results$prop_treat <- mean(data$treat)
results$treat_ok <- abs(results$prop_treat - 2/3) < 0.1

# Check baseline distributions
results$tmt_base_mean <- mean(data$tmt_base)
results$tmt_base_sd <- sd(data$tmt_base)
results$mfis_base_mean <- mean(data$mfis_base)
results$mfis_base_sd <- sd(data$mfis_base)

# Check range constraints
results$tmt_in_range <- all(data$tmt_base >= outcomes$tmt$range[1] &
                             data$tmt_base <= outcomes$tmt$range[2])
results$mfis_in_range <- all(data$mfis_base >= outcomes$mfis$range[1] &
                              data$mfis_base <= outcomes$mfis$range[2])
results$tmt_3m_in_range <- all(data$tmt_3m >= outcomes$tmt$range[1] &
                                data$tmt_3m <= outcomes$tmt$range[2])
results$mfis_3m_in_range <- all(data$mfis_3m >= outcomes$mfis$range[1] &
                                 data$mfis_3m <= outcomes$mfis$range[2])

# Check correlation between outcomes
results$correlation <- cor(data$tmt_3m, data$mfis_3m)

# Treatment effect estimates (crude)
treat_idx <- data$treat == 1
ctrl_idx <- data$treat == 0
results$crude_tmt_effect <- mean(data$tmt_3m[treat_idx]) - mean(data$tmt_3m[ctrl_idx])
results$crude_mfis_effect <- mean(data$mfis_3m[treat_idx]) - mean(data$mfis_3m[ctrl_idx])

if (verbose) {
  cat("=== Simulation Validation ===\n")
  cat(sprintf("N = %d\n", results$n))
  cat(sprintf("Treatment proportion: %.2f (expected: 0.67)\n", results$prop_treat))
  cat(sprintf("\nBaseline TMT: mean = %.2f (SD = %.2f)\n",
              results$tmt_base_mean, results$tmt_base_sd))
  cat(sprintf("Baseline MFIS: mean = %.2f (SD = %.2f)\n",
              results$mfis_base_mean, results$mfis_base_sd))
  cat(sprintf("\nOutcome correlation: %.3f\n", results$correlation))
  cat(sprintf("\nCrude treatment effects:\n"))
  cat(sprintf("  TMT: %.3f\n", results$crude_tmt_effect))
  cat(sprintf("  MFIS: %.3f\n", results$crude_mfis_effect))
  cat(sprintf("\nRange constraints satisfied: %s\n",
              ifelse(all(results$tmt_in_range, results$mfis_in_range,
                        results$tmt_3m_in_range, results$mfis_3m_in_range),
                     "Yes", "No")))
}

invisible(results)
}


#' Generate multiple simulated datasets
#'
#' @param n_datasets Number of datasets to generate
#' @param n Sample size per dataset
#' @param ... Additional arguments passed to simulate_trial_data()
#' @return List of simulated datasets
simulate_multiple <- function(n_datasets, n, ...) {
lapply(1:n_datasets, function(i) {
  simulate_trial_data(n, seed = 1000 + i, ...)
})
}
