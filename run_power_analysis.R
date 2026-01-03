# run_power_analysis.R
# Script to run full power analysis simulation
# Run with: Rscript run_power_analysis.R
# Or for quick test: Rscript run_power_analysis.R --quick

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
quick_mode <- "--quick" %in% args

# Load all required packages and source files
message("Loading packages and functions...")
source("R/_setup.R")
source("R/parameters.R")
source("R/simulate_data.R")
source("R/fit_model.R")
source("R/power_analysis.R")

# Compile model
message("Compiling Stan model...")
model <- compile_model()

# Set simulation parameters
if (quick_mode) {
  message("\n=== QUICK MODE: Running reduced simulation ===\n")
  sample_sizes <- c(180, 300, 420)  # Subset of sample sizes
  n_reps <- 10  # Fewer replications
} else {
  message("\n=== FULL MODE: Running complete simulation ===\n")
  sample_sizes <- sim_params$sample_sizes  # All sample sizes: 120, 180, 240, 300, 360, 420, 480
  n_reps <- sim_params$n_reps  # 100 replications
}

message(sprintf("Sample sizes: %s", paste(sample_sizes, collapse = ", ")))
message(sprintf("Replications per sample size: %d", n_reps))
message(sprintf("Total model fits: %d", length(sample_sizes) * n_reps))
message("")

# Run power curve estimation
# Note: parallel = FALSE due to cmdstanr temp file issues with furrr
# Instead, we parallelize the MCMC chains within each fit
start_time <- Sys.time()
message("Starting power analysis at ", format(start_time, "%H:%M:%S"), "...")

power_results <- estimate_power_curve(
  sample_sizes = sample_sizes,
  model = model,
  n_reps = n_reps,
  parallel = FALSE  # Use sequential for stability; Stan chains still run in parallel
)

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")
message(sprintf("\nPower analysis completed in %.1f minutes", as.numeric(elapsed)))

# Estimate required N for 90% power
message("\nEstimating required sample size for 90% power...")
required_n_result <- estimate_required_n(power_results, target_power = 0.90)

# Print summary
print_power_summary(power_results, required_n_result)

# Save results to cache
cache_dir <- "data/cached_results"
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir, recursive = TRUE)
}

saveRDS(power_results, file.path(cache_dir, "power_results.rds"))
saveRDS(required_n_result, file.path(cache_dir, "required_n_result.rds"))

message(sprintf("\nResults saved to %s/", cache_dir))
message("  - power_results.rds")
message("  - required_n_result.rds")

# Return results invisibly
invisible(list(
  power_results = power_results,
  required_n_result = required_n_result
))
