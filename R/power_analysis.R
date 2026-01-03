# power_analysis.R
# Power estimation functions for Bayesian clinical trial simulation

#' Run single simulation replication
#'
#' Simulates data, fits model, and evaluates trial success.
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param sim_params Simulation parameters
#' @param seed Random seed
#' @return Logical indicating trial success, or NA if model failed
run_single_simulation <- function(n,
                                   model,
                                   sim_params = NULL,
                                   seed = NULL) {
# Load defaults (must source parameters.R first)
if (is.null(sim_params)) {
  sim_params <- get("sim_params", envir = globalenv())
}

# Simulate data
data <- simulate_trial_data(n, seed = seed)

# Fit model
fit <- fit_coprimary_model(data, model = model, seed = seed)

if (is.null(fit)) {
  warning("Model fitting failed for n = ", n, ", seed = ", seed)
  return(NA)
}

# Extract posteriors and evaluate success
effects <- extract_treatment_effects(fit)

if (is.null(effects)) {
  return(NA)
}

# Success criterion: combined posterior probability >= threshold
trial_success <- effects$prob_combined >= sim_params$efficacy_threshold

return(trial_success)
}


#' Estimate power for a single sample size
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param n_reps Number of replications
#' @param parallel Use parallel processing
#' @param conf_level Confidence level for Wilson interval
#' @return List with power estimate and confidence interval
simulate_power <- function(n,
                           model,
                           n_reps = 100,
                           parallel = FALSE,
                           conf_level = 0.95) {
message(sprintf("Estimating power for N = %d with %d replications...", n, n_reps))

if (parallel) {
  # Capture global environment variables to pass explicitly to workers
  sim_params_local <- get("sim_params", envir = globalenv())
  outcomes_local <- get("outcomes", envir = globalenv())
  true_effects_local <- get("true_effects", envir = globalenv())
  stan_options_local <- get("stan_options", envir = globalenv())

  # Define a self-contained worker function that doesn't rely on globalenv()
  run_worker <- function(i, n, model, sim_params, outcomes, true_effects, stan_options) {
    # Set up globals for nested function calls
    assign("sim_params", sim_params, envir = globalenv())
    assign("outcomes", outcomes, envir = globalenv())
    assign("true_effects", true_effects, envir = globalenv())
    assign("stan_options", stan_options, envir = globalenv())

    seed <- 1234 + i

    # Simulate data
    data <- simulate_trial_data(n, seed = seed)

    # Fit model with in_parallel = TRUE to avoid temp file conflicts
    fit <- fit_coprimary_model(data, model = model, seed = seed, in_parallel = TRUE)

    if (is.null(fit)) {
      return(NA)
    }

    # Extract posteriors and evaluate success
    effects <- extract_treatment_effects(fit)

    if (is.null(effects)) {
      return(NA)
    }

    # Success criterion
    effects$prob_combined >= sim_params$efficacy_threshold
  }

  future::plan(future::multisession)
  results <- furrr::future_map_lgl(
    1:n_reps,
    function(i) {
      run_worker(i, n, model, sim_params_local, outcomes_local,
                 true_effects_local, stan_options_local)
    },
    .options = furrr::furrr_options(
      seed = TRUE,
      packages = c("cmdstanr", "posterior", "mvtnorm", "truncnorm")
    )
  )
  future::plan(future::sequential)
} else {
  results <- vapply(
    1:n_reps,
    function(i) run_single_simulation(n, model, seed = 1234 + i),
    logical(1)
  )
}

# Remove NAs (failed simulations)
valid_results <- results[!is.na(results)]
n_valid <- length(valid_results)

if (n_valid == 0) {
  warning("All simulations failed for n = ", n)
  return(list(n = n, power = NA, lower_ci = NA, upper_ci = NA, n_valid = 0))
}

# Calculate power
successes <- sum(valid_results)
power <- successes / n_valid

# Wilson score confidence interval
z <- qnorm(1 - (1 - conf_level) / 2)
denom <- 1 + (z^2 / n_valid)
center <- power + (z^2 / (2 * n_valid))
margin <- z * sqrt((power * (1 - power) / n_valid) + (z^2 / (4 * n_valid^2)))

lower_ci <- (center - margin) / denom
upper_ci <- (center + margin) / denom

list(
  n = n,
  power = power,
  lower_ci = lower_ci,
  upper_ci = upper_ci,
  successes = successes,
  n_valid = n_valid,
  n_failed = n_reps - n_valid
)
}


#' Estimate power curve across sample sizes
#'
#' @param sample_sizes Vector of sample sizes to evaluate
#' @param model Compiled Stan model
#' @param n_reps Number of replications per sample size
#' @param parallel Use parallel processing for each sample size
#' @return Data frame with power estimates and CIs
estimate_power_curve <- function(sample_sizes,
                                  model,
                                  n_reps = 100,
                                  parallel = FALSE) {
message(sprintf("Estimating power curve for %d sample sizes...",
                length(sample_sizes)))

results <- lapply(sample_sizes, function(n) {
  res <- simulate_power(n, model, n_reps, parallel)
  data.frame(
    n = res$n,
    power = res$power,
    lower_ci = res$lower_ci,
    upper_ci = res$upper_ci,
    successes = res$successes,
    n_valid = res$n_valid
  )
})

do.call(rbind, results)
}


#' Estimate required sample size for target power
#'
#' Uses logistic regression with delta method for confidence interval.
#'
#' @param power_results Data frame from estimate_power_curve()
#' @param target_power Target power (default 0.90)
#' @return List with point estimate and 95% CI
estimate_required_n <- function(power_results, target_power = 0.90) {
# Fit logistic regression
logit_model <- glm(
  power ~ n,
  data = power_results,
  family = quasibinomial(link = "logit"),
  weights = n_valid
)

# Calculate required N
L <- qlogis(target_power)
beta0 <- coef(logit_model)[1]
beta1 <- coef(logit_model)[2]
required_n <- (L - beta0) / beta1

# Delta method for confidence interval
cov_mat <- vcov(logit_model)
var_beta0 <- cov_mat[1, 1]
var_beta1 <- cov_mat[2, 2]
cov_beta01 <- cov_mat[1, 2]

df_dbeta0 <- -1 / beta1
df_dbeta1 <- -(L - beta0) / (beta1^2)

var_required_n <- (df_dbeta0^2) * var_beta0 +
                   (df_dbeta1^2) * var_beta1 +
                   2 * df_dbeta0 * df_dbeta1 * cov_beta01
se_required_n <- sqrt(var_required_n)

lower_ci <- required_n - 1.96 * se_required_n
upper_ci <- required_n + 1.96 * se_required_n

list(
  target_power = target_power,
  required_n = required_n,
  se = se_required_n,
  lower_ci = lower_ci,
  upper_ci = upper_ci,
  logit_model = logit_model
)
}


#' Print power analysis summary
#'
#' @param power_results Data frame from estimate_power_curve()
#' @param required_n_result Result from estimate_required_n()
print_power_summary <- function(power_results, required_n_result = NULL) {
cat("=== Power Analysis Summary ===\n\n")

cat("Power by Sample Size:\n")
for (i in seq_len(nrow(power_results))) {
  cat(sprintf("  N = %3d: Power = %.3f [%.3f, %.3f]\n",
              power_results$n[i],
              power_results$power[i],
              power_results$lower_ci[i],
              power_results$upper_ci[i]))
}

if (!is.null(required_n_result)) {
  cat(sprintf("\nRequired Sample Size for %.0f%% Power:\n",
              required_n_result$target_power * 100))
  cat(sprintf("  Point estimate: %.1f\n", required_n_result$required_n))
  cat(sprintf("  95%% CI: [%.1f, %.1f]\n",
              required_n_result$lower_ci, required_n_result$upper_ci))
}
}
