# type1_error.R
# Type I error estimation and threshold calibration
# Essential for regulatory submissions requiring frequentist operating characteristics

#' Estimate Type I error rate
#'
#' Simulates trials under the null hypothesis (no treatment effect) and
#' calculates the false positive rate.
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param n_reps Number of null simulations
#' @param decision_threshold Posterior probability threshold for declaring success
#' @param parallel Use parallel processing
#' @param conf_level Confidence level for interval
#' @return List with type I error estimate and CI
estimate_type1_error <- function(n,
                                  model,
                                  n_reps = 500,
                                  decision_threshold = 0.95,
                                  parallel = FALSE,
                                  conf_level = 0.95) {
  message(sprintf("Estimating Type I error for N = %d under null hypothesis...", n))

  # Save original true effects
  true_effects_original <- get("true_effects", envir = globalenv())

  # Set treatment effect to 0 (null hypothesis)
  true_effects_null <- true_effects_original
  for (name in names(true_effects_null)) {
    if (name != "rho" && is.list(true_effects_null[[name]])) {
      true_effects_null[[name]]$gamma_treat <- 0
    }
  }
  assign("true_effects", true_effects_null, envir = globalenv())

  # Run simulations under null
  run_null_simulation <- function(i) {
    seed <- 5000 + i
    data <- simulate_trial_data(n, seed = seed)
    fit <- fit_coprimary_model(data, model = model, seed = seed, in_parallel = TRUE)

    if (is.null(fit)) return(NA)

    effects <- extract_treatment_effects(fit)
    if (is.null(effects)) return(NA)

    # False positive: declaring success when null is true
    effects$prob_combined >= decision_threshold
  }

  if (parallel) {
    future::plan(future::multisession)
    results <- furrr::future_map_lgl(
      1:n_reps,
      run_null_simulation,
      .options = furrr::furrr_options(seed = TRUE)
    )
    future::plan(future::sequential)
  } else {
    results <- vapply(1:n_reps, run_null_simulation, logical(1))
  }

  # Restore original effects
  assign("true_effects", true_effects_original, envir = globalenv())

  # Calculate type I error with Wilson CI
  valid_results <- results[!is.na(results)]
  n_valid <- length(valid_results)

  if (n_valid == 0) {
    return(list(n = n, type1_error = NA, lower_ci = NA, upper_ci = NA, n_valid = 0))
  }

  false_positives <- sum(valid_results)
  type1_error <- false_positives / n_valid

  # Wilson score confidence interval
  z <- qnorm(1 - (1 - conf_level) / 2)
  denom <- 1 + (z^2 / n_valid)
  center <- type1_error + (z^2 / (2 * n_valid))
  margin <- z * sqrt((type1_error * (1 - type1_error) / n_valid) + (z^2 / (4 * n_valid^2)))

  lower_ci <- (center - margin) / denom
  upper_ci <- (center + margin) / denom

  list(
    n = n,
    type1_error = type1_error,
    lower_ci = lower_ci,
    upper_ci = upper_ci,
    false_positives = false_positives,
    n_valid = n_valid,
    decision_threshold = decision_threshold
  )
}

#' Calibrate decision threshold for target Type I error
#'
#' Uses binary search to find the posterior probability threshold that
#' achieves the desired type I error rate.
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param target_alpha Target type I error rate (default 0.05)
#' @param n_reps Simulations per threshold evaluation
#' @param threshold_range Range of thresholds to search
#' @param tolerance Acceptable deviation from target
#' @param max_iter Maximum iterations
#' @return List with calibrated threshold and operating characteristics
calibrate_threshold <- function(n,
                                 model,
                                 target_alpha = 0.05,
                                 n_reps = 200,
                                 threshold_range = c(0.90, 0.99),
                                 tolerance = 0.01,
                                 max_iter = 10) {
  message(sprintf("Calibrating threshold for %.1f%% Type I error...", target_alpha * 100))

  # Binary search
  low <- threshold_range[1]
  high <- threshold_range[2]

  history <- data.frame(
    iteration = integer(),
    threshold = numeric(),
    type1_error = numeric(),
    lower_ci = numeric(),
    upper_ci = numeric()
  )

  for (iter in 1:max_iter) {
    mid <- (low + high) / 2
    message(sprintf("  Iteration %d: testing threshold = %.4f", iter, mid))

    result <- estimate_type1_error(n, model, n_reps, decision_threshold = mid)

    history <- rbind(history, data.frame(
      iteration = iter,
      threshold = mid,
      type1_error = result$type1_error,
      lower_ci = result$lower_ci,
      upper_ci = result$upper_ci
    ))

    # Check if within tolerance
    if (abs(result$type1_error - target_alpha) <= tolerance) {
      message(sprintf("  Converged: Type I error = %.4f at threshold = %.4f",
                     result$type1_error, mid))
      break
    }

    # Adjust search range
    # Higher threshold -> lower type I error
    if (result$type1_error > target_alpha) {
      low <- mid
    } else {
      high <- mid
    }
  }

  list(
    calibrated_threshold = mid,
    achieved_type1_error = result$type1_error,
    target_alpha = target_alpha,
    history = history,
    final_result = result
  )
}

#' Estimate Type I error across sample sizes
#'
#' @param sample_sizes Vector of sample sizes
#' @param model Compiled Stan model
#' @param n_reps Replications per sample size
#' @param decision_threshold Decision threshold
#' @return Data frame with type I error by sample size
estimate_type1_curve <- function(sample_sizes,
                                  model,
                                  n_reps = 500,
                                  decision_threshold = 0.95) {
  message(sprintf("Estimating Type I error curve for %d sample sizes...",
                 length(sample_sizes)))

  results <- lapply(sample_sizes, function(n) {
    res <- estimate_type1_error(n, model, n_reps, decision_threshold)
    data.frame(
      n = res$n,
      type1_error = res$type1_error,
      lower_ci = res$lower_ci,
      upper_ci = res$upper_ci,
      n_valid = res$n_valid
    )
  })

  do.call(rbind, results)
}

#' Print Type I error summary
#'
#' @param result Output from estimate_type1_error() or calibrate_threshold()
print_type1_summary <- function(result) {
  cat("=== Type I Error Analysis ===\n\n")

  if ("calibrated_threshold" %in% names(result)) {
    # Calibration result
    cat("Threshold Calibration:\n")
    cat(sprintf("  Target alpha: %.3f\n", result$target_alpha))
    cat(sprintf("  Calibrated threshold: %.4f\n", result$calibrated_threshold))
    cat(sprintf("  Achieved Type I error: %.4f\n", result$achieved_type1_error))
    cat("\nSearch History:\n")
    print(result$history)
  } else {
    # Single estimate
    cat(sprintf("Sample size: %d\n", result$n))
    cat(sprintf("Decision threshold: %.3f\n", result$decision_threshold))
    cat(sprintf("Type I error: %.4f [%.4f, %.4f]\n",
               result$type1_error, result$lower_ci, result$upper_ci))
    cat(sprintf("False positives: %d / %d\n",
               result$false_positives, result$n_valid))
  }
}

#' Create operating characteristics table
#'
#' Combines power, assurance, and type I error for reporting.
#'
#' @param power_results Power curve results
#' @param assurance_results Assurance curve results (optional)
#' @param type1_results Type I error results (optional)
#' @return Data frame with operating characteristics
create_oc_table <- function(power_results,
                             assurance_results = NULL,
                             type1_results = NULL) {
  oc <- power_results[, c("n", "power", "lower_ci", "upper_ci")]
  names(oc)[2:4] <- c("power", "power_lower", "power_upper")

  if (!is.null(assurance_results)) {
    oc$assurance <- assurance_results$assurance
    oc$assurance_lower <- assurance_results$lower_ci
    oc$assurance_upper <- assurance_results$upper_ci
  }

  if (!is.null(type1_results)) {
    oc$type1_error <- type1_results$type1_error
    oc$type1_lower <- type1_results$lower_ci
    oc$type1_upper <- type1_results$upper_ci
  }

  oc
}
