# parameters.R
# Centralized parameter definitions for Taurine Long COVID clinical trial simulation

# Co-primary outcome definitions
outcomes <- list(
tmt = list(
  name = "TMT B/A",
  fullname = "Trail Making Test B/A Ratio",
  mean = 2.22,
  sd = 1.07,
  mcid = 0.5,
  range = c(0.9, 5),
  direction = "lower_better",
  baseline_adjustment = 0.2  # +0.2 for ~30% with cognitive impairment
),
mfis = list(
  name = "MFIS",
  fullname = "Modified Fatigue Impact Scale",
  mean = 23.7,
  sd = 21.1,
  mcid = 10,
  range = c(0, 84),
  direction = "lower_better",
  baseline_adjustment = 10  # +10 for ~40% with fatigue severity
),
fas = list(
  name = "FAS",
  fullname = "Fatigue Assessment Scale",
  mean = 19.26,
  sd = 6.52,
  mcid = 3,
  range = c(10, 50),
  direction = "lower_better",
  baseline_adjustment = 0
)
)

# True treatment effects for simulation
true_effects <- list(
tmt = list(
  alpha = 0,           # Intercept adjustment
  beta_base = 1,       # Baseline effect coefficient
  gamma_treat = -0.1,  # Treatment effect (negative = improvement)
  sigma = 0.5          # Residual SD
),
mfis = list(
  alpha = 0,
  beta_base = 1,
  gamma_treat = -3,    # Treatment reduces MFIS by 3 points
  sigma = 8            # Residual SD
),
rho = 0.2              # Correlation between outcomes at follow-up
)

# Stan MCMC sampling options
stan_options <- list(
chains = 4,
parallel_chains = 4,
iter_warmup = 1000,
iter_sampling = 2000,
refresh = 0,
adapt_delta = 0.95,
max_treedepth = 12
)

# Simulation parameters
sim_params <- list(
# Randomization
allocation_ratio = 2/3,  # P(treatment) = 2/3 for 2:1 ratio

# Decision thresholds
efficacy_threshold = 0.95,   # Posterior prob for trial success
futility_threshold = 0.10,   # Posterior prob for futility stopping

# Power analysis
target_power = 0.90,
sample_sizes = seq(120, 480, by = 60),  # Grid for power curve
n_reps = 100,  # Replications per sample size

# Interim analysis schedule
initial_n = 120,
interim_increment = 60,
max_n = 480
)

# Convenience function to get adjusted baseline mean
get_adjusted_mean <- function(outcome) {
outcomes[[outcome]]$mean + outcomes[[outcome]]$baseline_adjustment
}

# Print summary of parameters
print_parameters <- function() {
cat("=== Taurine Long COVID Trial Parameters ===\n\n")

cat("Co-Primary Outcomes:\n")
for (name in c("tmt", "mfis")) {
  o <- outcomes[[name]]
  cat(sprintf("  %s (%s)\n", o$name, o$fullname))
  cat(sprintf("    Baseline: %.2f (SD %.2f), Range: [%.1f, %.1f]\n",
              o$mean, o$sd, o$range[1], o$range[2]))
  cat(sprintf("    MCID: %.1f, Direction: %s\n", o$mcid, o$direction))
  cat(sprintf("    Adjusted mean (for simulation): %.2f\n\n", get_adjusted_mean(name)))
}

cat("True Treatment Effects (for simulation):\n")
cat(sprintf("  TMT: %.2f (SD %.2f)\n", true_effects$tmt$gamma_treat, true_effects$tmt$sigma))
cat(sprintf("  MFIS: %.1f (SD %.1f)\n", true_effects$mfis$gamma_treat, true_effects$mfis$sigma))
cat(sprintf("  Outcome correlation: %.2f\n\n", true_effects$rho))

cat("Decision Thresholds:\n")
cat(sprintf("  Efficacy: P(benefit) > %.2f for BOTH outcomes\n", sim_params$efficacy_threshold))
cat(sprintf("  Futility: P(benefit) < %.2f for EITHER outcome\n", sim_params$futility_threshold))
cat(sprintf("  Target power: %.0f%%\n\n", sim_params$target_power * 100))

cat("Design:\n")
cat(sprintf("  Randomization: %.0f:%.0f (treatment:control)\n",
            sim_params$allocation_ratio * 3, (1 - sim_params$allocation_ratio) * 3))
cat(sprintf("  Sample size range: %d to %d (by %d)\n",
            min(sim_params$sample_sizes), max(sim_params$sample_sizes),
            sim_params$interim_increment))
}
