# interim_analysis.R
# Interim analysis and stopping rule functions for adaptive trial design

#' Evaluate stopping rule at interim analysis
#'
#' Determines whether trial should stop for efficacy or futility.
#'
#' @param prob_tmt Posterior probability of TMT benefit
#' @param prob_mfis Posterior probability of MFIS benefit
#' @param efficacy_threshold Threshold for early efficacy stop (default 0.95)
#' @param futility_threshold Threshold for futility stop (default 0.10)
#' @return Character: "efficacy", "futility", or "continue"
evaluate_stopping_rule <- function(prob_tmt,
                                    prob_mfis,
                                    efficacy_threshold = 0.95,
                                    futility_threshold = 0.10) {
# Efficacy: Stop if BOTH outcomes show strong benefit
if (prob_tmt > efficacy_threshold && prob_mfis > efficacy_threshold) {
  return("efficacy")
}

# Futility: Stop if EITHER outcome shows no benefit
if (prob_tmt < futility_threshold || prob_mfis < futility_threshold) {
  return("futility")
}

return("continue")
}


#' Run single interim analysis sequence
#'
#' Simulates a trial with interim analyses at specified sample sizes.
#'
#' @param model Compiled Stan model
#' @param initial_n Starting sample size for first interim
#' @param increment Sample size increment per interim
#' @param max_n Maximum sample size
#' @param sim_params Simulation parameters
#' @param seed Random seed
#' @return List with interim results
run_interim_sequence <- function(model,
                                  initial_n = 120,
                                  increment = 60,
                                  max_n = 480,
                                  sim_params = NULL,
                                  seed = NULL) {
if (is.null(sim_params)) {
  sim_params <- get("sim_params", envir = globalenv())
}

if (!is.null(seed)) set.seed(seed)

# Define interim schedule
interim_sizes <- seq(initial_n, max_n, by = increment)

results <- list()
stopped <- FALSE
stop_n <- NA
stop_reason <- NA

for (n in interim_sizes) {
  if (stopped) break

  # Simulate cumulative data up to n
  data <- simulate_trial_data(n, seed = seed)

  # Fit model
  fit <- fit_coprimary_model(data, model = model, seed = seed)

  if (is.null(fit)) {
    results[[as.character(n)]] <- list(
      n = n,
      prob_tmt = NA,
      prob_mfis = NA,
      decision = "model_failed"
    )
    next
  }

  # Extract posteriors
  effects <- extract_treatment_effects(fit)

  prob_tmt <- effects$prob_tmt
  prob_mfis <- effects$prob_mfis

  # Evaluate stopping rule
  decision <- evaluate_stopping_rule(
    prob_tmt,
    prob_mfis,
    efficacy_threshold = sim_params$efficacy_threshold,
    futility_threshold = sim_params$futility_threshold
  )

  results[[as.character(n)]] <- list(
    n = n,
    prob_tmt = prob_tmt,
    prob_mfis = prob_mfis,
    prob_combined = effects$prob_combined,
    decision = decision
  )

  if (decision != "continue") {
    stopped <- TRUE
    stop_n <- n
    stop_reason <- decision
  }
}

# If no stopping, final decision at max_n
if (!stopped) {
  final <- results[[as.character(max_n)]]
  if (!is.null(final) && !is.na(final$prob_combined)) {
    stop_reason <- ifelse(final$prob_combined >= sim_params$efficacy_threshold,
                          "success", "failure")
  } else {
    stop_reason <- "unknown"
  }
  stop_n <- max_n
}

list(
  interim_results = results,
  stopped_early = stopped,
  stop_n = stop_n,
  stop_reason = stop_reason,
  schedule = interim_sizes
)
}


#' Simulate multiple trials with interim analyses
#'
#' @param model Compiled Stan model
#' @param n_reps Number of trial replications
#' @param initial_n Starting sample size
#' @param increment Sample size increment
#' @param max_n Maximum sample size
#' @param parallel Use parallel processing
#' @return List with aggregated interim results
simulate_interim_trials <- function(model,
                                     n_reps = 100,
                                     initial_n = 120,
                                     increment = 60,
                                     max_n = 480,
                                     parallel = FALSE) {
message(sprintf("Simulating %d trials with interim analyses...", n_reps))

run_one <- function(i) {
  run_interim_sequence(
    model = model,
    initial_n = initial_n,
    increment = increment,
    max_n = max_n,
    seed = 1000 + i
  )
}

if (parallel) {
  future::plan(future::multisession)
  results <- furrr::future_map(
    1:n_reps,
    run_one,
    .options = furrr::furrr_options(seed = TRUE),
    .progress = TRUE
  )
  future::plan(future::sequential)
} else {
  results <- lapply(1:n_reps, function(i) {
    if (i %% 10 == 0) message(sprintf("  Completed %d/%d", i, n_reps))
    run_one(i)
  })
}

list(
  trials = results,
  n_reps = n_reps,
  schedule = seq(initial_n, max_n, by = increment)
)
}


#' Summarize interim analysis results
#'
#' @param results Output from simulate_interim_trials()
#' @return Data frame with summary statistics
summarize_interim_results <- function(results) {
trials <- results$trials
n_reps <- results$n_reps
schedule <- results$schedule

# Count outcomes
stop_reasons <- sapply(trials, function(x) x$stop_reason)
stop_ns <- sapply(trials, function(x) x$stop_n)
stopped_early <- sapply(trials, function(x) x$stopped_early)

# Stopping probabilities by stage
stopping_by_stage <- sapply(schedule, function(n) {
  sum(stop_ns == n, na.rm = TRUE)
}) / n_reps

# Overall statistics
summary <- list(
  # Stopping probabilities
  prob_efficacy = mean(stop_reasons == "efficacy", na.rm = TRUE),
  prob_futility = mean(stop_reasons == "futility", na.rm = TRUE),
  prob_success = mean(stop_reasons %in% c("efficacy", "success"), na.rm = TRUE),
  prob_stopped_early = mean(stopped_early, na.rm = TRUE),

  # Sample size statistics
  mean_n = mean(stop_ns, na.rm = TRUE),
  median_n = median(stop_ns, na.rm = TRUE),
  sd_n = sd(stop_ns, na.rm = TRUE),

  # Stopping by stage
  stopping_by_stage = data.frame(
    n = schedule,
    prop_stopped = stopping_by_stage,
    cumulative = cumsum(stopping_by_stage)
  ),

  # Raw data
  stop_reasons = table(stop_reasons),
  stop_ns = stop_ns
)

summary
}


#' Print interim analysis summary
#'
#' @param summary Output from summarize_interim_results()
print_interim_summary <- function(summary) {
cat("=== Interim Analysis Summary ===\n\n")

cat("Stopping Probabilities:\n")
cat(sprintf("  Efficacy (early stop): %.1f%%\n", summary$prob_efficacy * 100))
cat(sprintf("  Futility (early stop): %.1f%%\n", summary$prob_futility * 100))
cat(sprintf("  Overall success: %.1f%%\n", summary$prob_success * 100))
cat(sprintf("  Stopped early: %.1f%%\n\n", summary$prob_stopped_early * 100))

cat("Expected Sample Size:\n")
cat(sprintf("  Mean: %.1f\n", summary$mean_n))
cat(sprintf("  Median: %.0f\n", summary$median_n))
cat(sprintf("  SD: %.1f\n\n", summary$sd_n))

cat("Stopping by Stage:\n")
for (i in seq_len(nrow(summary$stopping_by_stage))) {
  row <- summary$stopping_by_stage[i, ]
  cat(sprintf("  N = %3d: %.1f%% stopped (cumulative: %.1f%%)\n",
              row$n, row$prop_stopped * 100, row$cumulative * 100))
}
}
