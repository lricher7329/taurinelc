# fit_model.R
# Model compilation and fitting wrappers for Bayesian analysis

#' Compile Stan model with caching
#'
#' @param model_name Name of model file (without path)
#' @param stan_dir Directory containing Stan models
#' @return Compiled cmdstanr model object
compile_model <- function(model_name = "coprimary_model_v4.stan",
                          stan_dir = "stan") {
model_path <- file.path(stan_dir, model_name)

if (!file.exists(model_path)) {
  stop("Stan model not found: ", model_path)
}

message("Compiling Stan model: ", model_name)
cmdstanr::cmdstan_model(model_path)
}


#' Generate initial values for Stan chains
#'
#' @param chain_id Chain identifier (1, 2, 3, ...)
#' @param N Sample size (not used but required by cmdstanr)
#' @return List of initial values
generate_init_values <- function(chain_id, N = NULL) {
set.seed(chain_id * 123)

list(
  beta_tmt = rnorm(3, mean = c(0, 0.5, 0), sd = 0.1),
  beta_mfis = rnorm(3, mean = c(0, 0.5, 0), sd = 0.1),
  sigma = runif(2, 0.5, 1.5),
  L_Omega = diag(2)
)
}


#' Fit Bayesian coprimary outcome model
#'
#' @param data Stan data list from simulate_trial_data()
#' @param model Compiled Stan model (or NULL to compile default)
#' @param stan_options MCMC options (from parameters.R)
#' @param use_init Use custom initial values
#' @param seed Random seed for MCMC
#' @param in_parallel Set to TRUE when running inside furrr parallel workers
#' @return cmdstanr fit object
fit_coprimary_model <- function(data,
                                 model = NULL,
                                 stan_options = NULL,
                                 use_init = TRUE,
                                 seed = 1234,
                                 in_parallel = FALSE) {
# Load defaults if not provided (must source parameters.R first)
if (is.null(stan_options)) {
  stan_options <- get("stan_options", envir = globalenv())
}

# Compile model if not provided
if (is.null(model)) {
  model <- compile_model()
}

# Prepare init function
init_fn <- if (use_init) {
  lapply(1:stan_options$chains, generate_init_values, N = data$N)
} else {
  "random"
}

# When running in parallel furrr workers, use sequential chains to avoid
# temp file conflicts and reduce thread contention
parallel_chains <- if (in_parallel) 1 else stan_options$parallel_chains

# Fit model with explicit output directory to avoid temp file issues
fit <- tryCatch(
  model$sample(
    data = data,
    seed = seed,
    chains = stan_options$chains,
    parallel_chains = parallel_chains,
    iter_warmup = stan_options$iter_warmup,
    iter_sampling = stan_options$iter_sampling,
    refresh = stan_options$refresh,
    adapt_delta = stan_options$adapt_delta,
    max_treedepth = stan_options$max_treedepth,
    init = init_fn,
    output_dir = tempdir(),
    output_basename = paste0("stan_fit_", seed)
  ),
  error = function(e) {
    warning("Stan sampling failed: ", e$message)
    return(NULL)
  }
)

fit
}


#' Extract treatment effect posteriors from fit
#'
#' @param fit cmdstanr fit object
#' @return Data frame with posterior samples and summaries
extract_treatment_effects <- function(fit) {
if (is.null(fit)) {
  return(NULL)
}

draws <- posterior::as_draws_df(fit$draws(variables = c("beta_tmt", "beta_mfis")))

# Extract treatment effects (index 3)
tmt_effect <- draws$`beta_tmt[3]`
mfis_effect <- draws$`beta_mfis[3]`

# Calculate posterior probabilities of benefit
# For both outcomes, lower is better (negative effect = improvement)
prob_tmt_benefit <- mean(tmt_effect < 0)
prob_mfis_benefit <- mean(mfis_effect < 0)

# Calculate joint probability
prob_joint <- mean(tmt_effect < 0 & mfis_effect < 0)

# Summary statistics
list(
  samples = data.frame(
    tmt_effect = tmt_effect,
    mfis_effect = mfis_effect
  ),
  summary = data.frame(
    outcome = c("TMT", "MFIS"),
    mean = c(mean(tmt_effect), mean(mfis_effect)),
    sd = c(sd(tmt_effect), sd(mfis_effect)),
    q025 = c(quantile(tmt_effect, 0.025), quantile(mfis_effect, 0.025)),
    q975 = c(quantile(tmt_effect, 0.975), quantile(mfis_effect, 0.975)),
    prob_benefit = c(prob_tmt_benefit, prob_mfis_benefit)
  ),
  prob_tmt = prob_tmt_benefit,
  prob_mfis = prob_mfis_benefit,
  prob_joint = prob_joint,
  prob_combined = (prob_tmt_benefit + prob_mfis_benefit) / 2
)
}


#' Check MCMC diagnostics
#'
#' @param fit cmdstanr fit object
#' @param verbose Print diagnostic summary
#' @return List with diagnostic results
check_diagnostics <- function(fit, verbose = TRUE) {
if (is.null(fit)) {
  return(list(valid = FALSE, reason = "Fit is NULL"))
}

diag <- fit$diagnostic_summary()
summary <- fit$summary()

results <- list(
  valid = TRUE,
  n_divergent = sum(diag$num_divergent),
  max_treedepth_exceeded = sum(diag$num_max_treedepth),
  rhat_max = max(summary$rhat, na.rm = TRUE),
  ess_bulk_min = min(summary$ess_bulk, na.rm = TRUE),
  ess_tail_min = min(summary$ess_tail, na.rm = TRUE)
)

# Check validity
if (results$n_divergent > 0) {
  results$valid <- FALSE
  results$reason <- paste(results$n_divergent, "divergent transitions")
}
if (results$rhat_max > 1.01) {
  results$valid <- FALSE
  results$reason <- paste("High Rhat:", round(results$rhat_max, 3))
}
if (results$ess_bulk_min < 400) {
  results$valid <- FALSE
  results$reason <- paste("Low ESS:", round(results$ess_bulk_min))
}

if (verbose) {
  cat("=== MCMC Diagnostics ===\n")
  cat(sprintf("Divergent transitions: %d\n", results$n_divergent))
  cat(sprintf("Max treedepth exceeded: %d\n", results$max_treedepth_exceeded))
  cat(sprintf("Max Rhat: %.4f\n", results$rhat_max))
  cat(sprintf("Min ESS (bulk): %.0f\n", results$ess_bulk_min))
  cat(sprintf("Min ESS (tail): %.0f\n", results$ess_tail_min))
  cat(sprintf("Valid: %s\n", ifelse(results$valid, "Yes", "No")))
  if (!results$valid) cat(sprintf("Reason: %s\n", results$reason))
}

invisible(results)
}
