# sensitivity.R
# Prior sensitivity analysis functions
# Systematic evaluation of how results change with different prior specifications

#' Run prior sensitivity analysis
#'
#' Evaluates power/assurance across a grid of prior specifications.
#'
#' @param n Sample size for evaluation
#' @param model Compiled Stan model
#' @param prior_grid Data frame with prior parameters to evaluate
#' @param n_reps Replications per prior specification
#' @param metric "power" or "assurance"
#' @return Data frame with sensitivity results
run_prior_sensitivity <- function(n,
                                   model,
                                   prior_grid,
                                   n_reps = 50,
                                   metric = "power") {
  message(sprintf("Running prior sensitivity analysis with %d specifications...",
                 nrow(prior_grid)))

  results <- lapply(1:nrow(prior_grid), function(i) {
    prior_spec <- prior_grid[i, ]
    message(sprintf("  [%d/%d] Prior mean=%.2f, sd=%.2f",
                   i, nrow(prior_grid), prior_spec$prior_mean, prior_spec$prior_sd))

    if (metric == "assurance") {
      design_prior <- specify_design_prior(
        mean = prior_spec$prior_mean,
        sd = prior_spec$prior_sd
      )
      res <- calculate_assurance(n, model, design_prior, n_reps)
      value <- res$power  # assurance is stored as power in the result
    } else {
      # For power, temporarily modify true effects
      true_effects_original <- get("true_effects", envir = globalenv())
      true_effects_mod <- true_effects_original
      for (name in names(true_effects_mod)) {
        if (name != "rho" && is.list(true_effects_mod[[name]])) {
          true_effects_mod[[name]]$gamma_treat <- prior_spec$prior_mean
        }
      }
      assign("true_effects", true_effects_mod, envir = globalenv())

      res <- simulate_power(n, model, n_reps)
      value <- res$power

      assign("true_effects", true_effects_original, envir = globalenv())
    }

    data.frame(
      prior_mean = prior_spec$prior_mean,
      prior_sd = prior_spec$prior_sd,
      n = n,
      metric = metric,
      value = value,
      lower_ci = res$lower_ci,
      upper_ci = res$upper_ci
    )
  })

  do.call(rbind, results)
}

#' Create prior sensitivity grid
#'
#' Generates a grid of prior specifications for sensitivity analysis.
#'
#' @param mean_range Range of prior means
#' @param sd_range Range of prior SDs
#' @param n_mean Number of mean values
#' @param n_sd Number of SD values
#' @return Data frame with prior_mean and prior_sd columns
create_prior_grid <- function(mean_range = c(-0.5, 0),
                               sd_range = c(0.1, 0.5),
                               n_mean = 5,
                               n_sd = 3) {
  expand.grid(
    prior_mean = seq(mean_range[1], mean_range[2], length.out = n_mean),
    prior_sd = seq(sd_range[1], sd_range[2], length.out = n_sd)
  )
}

#' Effect size sensitivity analysis
#'
#' Evaluates power across different assumed treatment effects.
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param effect_sizes Vector of effect sizes to evaluate
#' @param n_reps Replications per effect size
#' @return Data frame with power by effect size
run_effect_sensitivity <- function(n,
                                    model,
                                    effect_sizes,
                                    n_reps = 100) {
  message(sprintf("Running effect size sensitivity with %d values...",
                 length(effect_sizes)))

  true_effects_original <- get("true_effects", envir = globalenv())

  results <- lapply(effect_sizes, function(effect) {
    message(sprintf("  Effect = %.3f", effect))

    true_effects_mod <- true_effects_original
    for (name in names(true_effects_mod)) {
      if (name != "rho" && is.list(true_effects_mod[[name]])) {
        true_effects_mod[[name]]$gamma_treat <- effect
      }
    }
    assign("true_effects", true_effects_mod, envir = globalenv())

    res <- simulate_power(n, model, n_reps)

    data.frame(
      effect_size = effect,
      n = n,
      power = res$power,
      lower_ci = res$lower_ci,
      upper_ci = res$upper_ci
    )
  })

  assign("true_effects", true_effects_original, envir = globalenv())

  do.call(rbind, results)
}

#' Compare multiple prior specifications
#'
#' Compares power/assurance under different named prior scenarios.
#'
#' @param n Sample size
#' @param model Compiled Stan model
#' @param prior_scenarios Named list of prior specifications
#' @param n_reps Replications per scenario
#' @return Data frame comparing scenarios
compare_prior_scenarios <- function(n,
                                     model,
                                     prior_scenarios,
                                     n_reps = 100) {
  message(sprintf("Comparing %d prior scenarios...", length(prior_scenarios)))

  results <- lapply(names(prior_scenarios), function(scenario_name) {
    scenario <- prior_scenarios[[scenario_name]]
    message(sprintf("  Scenario: %s", scenario_name))

    # Create design prior from scenario
    design_prior <- specify_design_prior(
      distribution = scenario$distribution %||% "normal",
      mean = scenario$mean,
      sd = scenario$sd
    )

    res <- calculate_assurance(n, model, design_prior, n_reps)

    data.frame(
      scenario = scenario_name,
      prior_mean = scenario$mean,
      prior_sd = scenario$sd,
      n = n,
      assurance = res$power,
      lower_ci = res$lower_ci,
      upper_ci = res$upper_ci
    )
  })

  do.call(rbind, results)
}

#' Plot prior sensitivity results
#'
#' @param sensitivity_results Output from run_prior_sensitivity()
#' @return ggplot object
plot_prior_sensitivity <- function(sensitivity_results) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 required for plotting")
  }

  metric_label <- tools::toTitleCase(unique(sensitivity_results$metric))

  ggplot2::ggplot(sensitivity_results,
                  ggplot2::aes(x = prior_mean, y = value,
                               color = factor(prior_sd),
                               group = factor(prior_sd))) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_point(size = 2) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_ci, ymax = upper_ci,
                                       fill = factor(prior_sd)),
                         alpha = 0.2, color = NA) +
    ggplot2::labs(
      x = "Prior Mean (Treatment Effect)",
      y = metric_label,
      color = "Prior SD",
      fill = "Prior SD",
      title = paste("Prior Sensitivity Analysis:", metric_label)
    ) +
    ggplot2::theme_minimal() +
    ggplot2::geom_hline(yintercept = 0.8, linetype = "dashed", alpha = 0.5) +
    ggplot2::geom_hline(yintercept = 0.9, linetype = "dashed", alpha = 0.5) +
    ggplot2::scale_y_continuous(limits = c(0, 1))
}

#' Plot effect size sensitivity
#'
#' @param effect_results Output from run_effect_sensitivity()
#' @return ggplot object
plot_effect_sensitivity <- function(effect_results) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 required for plotting")
  }

  ggplot2::ggplot(effect_results,
                  ggplot2::aes(x = effect_size, y = power)) +
    ggplot2::geom_line(linewidth = 1, color = "#0072B2") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_ci, ymax = upper_ci),
                         alpha = 0.2, fill = "#0072B2") +
    ggplot2::geom_point(size = 2, color = "#0072B2") +
    ggplot2::labs(
      x = "Treatment Effect",
      y = "Power",
      title = sprintf("Effect Size Sensitivity (N = %d)", unique(effect_results$n))
    ) +
    ggplot2::theme_minimal() +
    ggplot2::geom_hline(yintercept = 0.8, linetype = "dashed", alpha = 0.5) +
    ggplot2::geom_hline(yintercept = 0.9, linetype = "dashed", alpha = 0.5) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dotted", alpha = 0.5) +
    ggplot2::scale_y_continuous(limits = c(0, 1))
}

#' Print sensitivity analysis summary
#'
#' @param results Output from run_prior_sensitivity() or run_effect_sensitivity()
print_sensitivity_summary <- function(results) {
  cat("=== Sensitivity Analysis Summary ===\n\n")

  if ("prior_mean" %in% names(results)) {
    cat("Prior Sensitivity:\n")
    cat(sprintf("  Prior means evaluated: %s\n",
               paste(unique(results$prior_mean), collapse = ", ")))
    cat(sprintf("  Prior SDs evaluated: %s\n",
               paste(unique(results$prior_sd), collapse = ", ")))
  }

  if ("effect_size" %in% names(results)) {
    cat("Effect Size Sensitivity:\n")
    cat(sprintf("  Effects evaluated: %s\n",
               paste(round(unique(results$effect_size), 3), collapse = ", ")))
  }

  cat(sprintf("\nMetric range: [%.3f, %.3f]\n",
             min(results$value %||% results$power, na.rm = TRUE),
             max(results$value %||% results$power, na.rm = TRUE)))
}

# Null coalesce operator
`%||%` <- function(x, y) if (is.null(x)) y else x
