# visualization.R
# Plotting functions for Bayesian clinical trial simulation results

#' Plot power curve with confidence intervals
#'
#' @param power_results Data frame from estimate_power_curve()
#' @param required_n_result Optional result from estimate_required_n()
#' @param target_power Target power to mark on plot
#' @return ggplot object
plot_power_curve <- function(power_results,
                              required_n_result = NULL,
                              target_power = 0.90) {
p <- ggplot(power_results, aes(x = n, y = power)) +
  geom_ribbon(aes(ymin = lower_ci, ymax = upper_ci),
              fill = "steelblue", alpha = 0.2) +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_point(color = "steelblue", size = 2) +
  geom_hline(yintercept = target_power, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(
    title = "Power Curve for Bayesian Co-Primary Outcome Trial",
    subtitle = sprintf("Target power: %.0f%%", target_power * 100),
    x = "Sample Size (N)",
    y = "Power"
  ) +
  theme_minimal(base_size = 12)

# Add required N annotation if provided
if (!is.null(required_n_result)) {
  req_n <- required_n_result$required_n
  p <- p +
    geom_vline(xintercept = req_n, linetype = "dotted", color = "darkgreen") +
    annotate("text",
             x = req_n + 10,
             y = 0.5,
             label = sprintf("N = %.0f", req_n),
             hjust = 0,
             color = "darkgreen")
}

p
}


#' Plot interim stopping probabilities
#'
#' @param interim_summary Output from summarize_interim_results()
#' @return ggplot object
plot_interim_stopping <- function(interim_summary) {
df <- interim_summary$stopping_by_stage

ggplot(df, aes(x = factor(n), y = prop_stopped)) +
  geom_col(fill = "steelblue", alpha = 0.7) +
  geom_line(aes(y = cumulative, group = 1), color = "darkred", linewidth = 1) +
  geom_point(aes(y = cumulative), color = "darkred", size = 2) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    title = "Stopping Probabilities by Interim Analysis Stage",
    subtitle = "Bars: stopped at stage | Line: cumulative",
    x = "Sample Size at Interim",
    y = "Proportion"
  ) +
  theme_minimal(base_size = 12)
}


#' Plot posterior distributions for treatment effects
#'
#' @param effects Output from extract_treatment_effects()
#' @return ggplot object
plot_posterior_effects <- function(effects) {
samples <- effects$samples

# Reshape for plotting
df <- data.frame(
  value = c(samples$tmt_effect, samples$mfis_effect),
  outcome = rep(c("TMT B/A Ratio", "MFIS"), each = nrow(samples))
)

ggplot(df, aes(x = value, fill = outcome)) +
  geom_density(alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  facet_wrap(~outcome, scales = "free") +
  labs(
    title = "Posterior Distributions of Treatment Effects",
    subtitle = "Negative values indicate improvement",
    x = "Treatment Effect",
    y = "Density"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")
}


#' Plot comparison of power curves for sensitivity analysis
#'
#' @param power_results_list Named list of power result data frames
#' @param target_power Target power level
#' @return ggplot object
plot_power_comparison <- function(power_results_list, target_power = 0.90) {
# Combine all results
df <- do.call(rbind, lapply(names(power_results_list), function(name) {
  res <- power_results_list[[name]]
  res$scenario <- name
  res
}))

ggplot(df, aes(x = n, y = power, color = scenario, fill = scenario)) +
  geom_ribbon(aes(ymin = lower_ci, ymax = upper_ci), alpha = 0.1, color = NA) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_hline(yintercept = target_power, linetype = "dashed", color = "gray40") +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(
    title = "Power Curve Comparison",
    subtitle = sprintf("Target power: %.0f%%", target_power * 100),
    x = "Sample Size (N)",
    y = "Power",
    color = "Scenario",
    fill = "Scenario"
  ) +
  theme_minimal(base_size = 12)
}


#' Plot expected sample size distribution
#'
#' @param interim_summary Output from summarize_interim_results()
#' @return ggplot object
plot_sample_size_distribution <- function(interim_summary) {
df <- data.frame(n = interim_summary$stop_ns)

ggplot(df, aes(x = n)) +
  geom_histogram(binwidth = 60, fill = "steelblue", alpha = 0.7, color = "white") +
  geom_vline(xintercept = interim_summary$mean_n,
             linetype = "dashed", color = "darkred", linewidth = 1) +
  annotate("text",
           x = interim_summary$mean_n + 10,
           y = Inf,
           vjust = 2,
           label = sprintf("Mean = %.0f", interim_summary$mean_n),
           color = "darkred") +
  labs(
    title = "Distribution of Final Sample Sizes",
    subtitle = "With interim stopping rules",
    x = "Final Sample Size",
    y = "Count"
  ) +
  theme_minimal(base_size = 12)
}


#' Create combined diagnostic plots
#'
#' @param fit cmdstanr fit object
#' @return patchwork combined plot
plot_diagnostics <- function(fit) {
if (is.null(fit)) {
  stop("Cannot create diagnostic plots: fit is NULL")
}

# Trace plots
trace <- bayesplot::mcmc_trace(
  fit$draws(c("beta_tmt[3]", "beta_mfis[3]")),
  facet_args = list(ncol = 1)
) +
  labs(title = "Trace Plots for Treatment Effects")

# Density overlays
dens <- bayesplot::mcmc_dens_overlay(
  fit$draws(c("beta_tmt[3]", "beta_mfis[3]"))
) +
  labs(title = "Posterior Densities by Chain")

# Combine with patchwork
trace / dens
}


#' Plot simulation validation summary
#'
#' @param data Simulated data from simulate_trial_data()
#' @return ggplot object
plot_simulation_validation <- function(data) {
# Create data frame
df <- data.frame(
  tmt_base = data$tmt_base,
  mfis_base = data$mfis_base,
  tmt_3m = data$tmt_3m,
  mfis_3m = data$mfis_3m,
  treat = factor(data$treat, labels = c("Control", "Treatment"))
)

# Baseline vs follow-up scatter
p1 <- ggplot(df, aes(x = tmt_base, y = tmt_3m, color = treat)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "TMT: Baseline vs Follow-up",
       x = "Baseline", y = "3-month") +
  theme_minimal()

p2 <- ggplot(df, aes(x = mfis_base, y = mfis_3m, color = treat)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "MFIS: Baseline vs Follow-up",
       x = "Baseline", y = "3-month") +
  theme_minimal()

# Outcome distributions by treatment
p3 <- ggplot(df, aes(x = tmt_3m, fill = treat)) +
  geom_density(alpha = 0.5) +
  labs(title = "TMT 3-month by Treatment") +
  theme_minimal()

p4 <- ggplot(df, aes(x = mfis_3m, fill = treat)) +
  geom_density(alpha = 0.5) +
  labs(title = "MFIS 3-month by Treatment") +
  theme_minimal()

(p1 + p2) / (p3 + p4) +
  patchwork::plot_layout(guides = "collect") &
  theme(legend.position = "bottom")
}
