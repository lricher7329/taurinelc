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


# ============================================================================
# Assurance Calculation (integrates over design prior)
# ============================================================================

#' Calculate power with Wilson confidence interval
#'
#' Helper function to compute power and CI from simulation results.
#'
#' @param results Vector of logical trial outcomes
#' @param conf_level Confidence level for interval
#' @param n_sample Sample size for reporting
#' @return List with power estimate and CI
calculate_power_with_ci <- function(results, conf_level = 0.95, n_sample) {
  valid_results <- results[!is.na(results)]
  n_valid <- length(valid_results)

  if (n_valid == 0) {
    return(list(n = n_sample, power = NA, lower_ci = NA, upper_ci = NA, n_valid = 0))
  }

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
    n = n_sample,
    power = power,
    lower_ci = lower_ci,
    upper_ci = upper_ci,
    successes = successes,
    n_valid = n_valid,
    n_failed = length(results) - n_valid
  )
}

#' Run single simulation with specified true effect
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param seed Random seed
#' @param true_effect True treatment effect to use
#' @return Logical indicating trial success
run_simulation_with_effect <- function(n, model, seed, true_effect) {
  # Save original effects
  true_effects_original <- get("true_effects", envir = globalenv())
  sim_params <- get("sim_params", envir = globalenv())

  # Set treatment effects for all outcomes
  true_effects_mod <- true_effects_original
  for (name in names(true_effects_mod)) {
    if (name != "rho" && is.list(true_effects_mod[[name]])) {
      true_effects_mod[[name]]$gamma_treat <- true_effect
    }
  }
  assign("true_effects", true_effects_mod, envir = globalenv())

  # Run simulation
  data <- simulate_trial_data(n, seed = seed)
  fit <- fit_coprimary_model(data, model = model, seed = seed)

  # Restore original effects
  assign("true_effects", true_effects_original, envir = globalenv())

  if (is.null(fit)) return(NA)

  effects <- extract_treatment_effects(fit)
  if (is.null(effects)) return(NA)

  effects$prob_combined >= sim_params$efficacy_threshold
}

#' Calculate Bayesian assurance
#'
#' Assurance is the probability of trial success averaging over uncertainty
#' in the true treatment effect, as represented by the design prior.
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param design_prior Design prior object from specify_design_prior()
#' @param n_reps Number of replications
#' @param conf_level Confidence level for interval
#' @return List with assurance estimate and confidence interval
calculate_assurance <- function(n,
                                 model,
                                 design_prior,
                                 n_reps = 100,
                                 conf_level = 0.95) {
  message(sprintf("Calculating assurance for N = %d...", n))

  # Sample true effects from design prior
  true_effects_sampled <- sample_from_design_prior(design_prior, n_reps, seed = 42)

  # Run simulation for each sampled effect
  results <- vapply(1:n_reps, function(i) {
    run_simulation_with_effect(n, model, seed = 1234 + i, true_effect = true_effects_sampled[i])
  }, logical(1))

  # Calculate assurance with CI
  assurance_result <- calculate_power_with_ci(results, conf_level, n)
  assurance_result$metric <- "assurance"
  assurance_result$design_prior <- design_prior

  assurance_result
}

#' Estimate assurance curve across sample sizes
#'
#' @param sample_sizes Vector of sample sizes
#' @param model Compiled Stan model
#' @param design_prior Design prior object
#' @param n_reps Replications per sample size
#' @return Data frame with assurance estimates
estimate_assurance_curve <- function(sample_sizes,
                                      model,
                                      design_prior,
                                      n_reps = 100) {
  message(sprintf("Estimating assurance curve for %d sample sizes...", length(sample_sizes)))

  results <- lapply(sample_sizes, function(n) {
    res <- calculate_assurance(n, model, design_prior, n_reps)
    data.frame(
      n = res$n,
      assurance = res$power,
      lower_ci = res$lower_ci,
      upper_ci = res$upper_ci,
      n_valid = res$n_valid
    )
  })

  do.call(rbind, results)
}

#' Estimate required sample size for target assurance
#'
#' @param assurance_results Data frame from estimate_assurance_curve()
#' @param target_assurance Target assurance (default 0.80)
#' @return List with point estimate and 95% CI
estimate_required_n_assurance <- function(assurance_results, target_assurance = 0.80) {
  # Fit logistic regression
  logit_model <- glm(
    assurance ~ n,
    data = assurance_results,
    family = quasibinomial(link = "logit"),
    weights = n_valid
  )

  # Calculate required N
  L <- qlogis(target_assurance)
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
    target_assurance = target_assurance,
    required_n = required_n,
    se = se_required_n,
    lower_ci = lower_ci,
    upper_ci = upper_ci,
    logit_model = logit_model
  )
}

#' Print assurance analysis summary
#'
#' @param assurance_results Data frame from estimate_assurance_curve()
#' @param required_n_result Result from estimate_required_n_assurance()
print_assurance_summary <- function(assurance_results, required_n_result = NULL) {
  cat("=== Assurance Analysis Summary ===\n\n")

  cat("Assurance by Sample Size:\n")
  for (i in seq_len(nrow(assurance_results))) {
    cat(sprintf("  N = %3d: Assurance = %.3f [%.3f, %.3f]\n",
                assurance_results$n[i],
                assurance_results$assurance[i],
                assurance_results$lower_ci[i],
                assurance_results$upper_ci[i]))
  }

  if (!is.null(required_n_result)) {
    cat(sprintf("\nRequired Sample Size for %.0f%% Assurance:\n",
                required_n_result$target_assurance * 100))
    cat(sprintf("  Point estimate: %.1f\n", required_n_result$required_n))
    cat(sprintf("  95%% CI: [%.1f, %.1f]\n",
                required_n_result$lower_ci, required_n_result$upper_ci))
  }
}
