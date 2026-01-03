# combine_power_results.R
# Combine results from job array into final power_results.rds
# Run after all array tasks complete: Rscript combine_power_results.R

message("Combining power analysis results from job array...")

source("R/_setup.R")
source("R/parameters.R")
source("R/power_analysis.R")

cache_dir <- "data/cached_results"
sample_sizes <- sim_params$sample_sizes  # 120, 180, 240, 300, 360, 420, 480

# Read all individual results
all_results <- list()
for (n in sample_sizes) {
  file <- file.path(cache_dir, sprintf("power_n%d.rds", n))
  if (file.exists(file)) {
    all_results[[as.character(n)]] <- readRDS(file)
    message(sprintf("Loaded results for N = %d", n))
  } else {
    warning(sprintf("Missing results for N = %d", n))
  }
}

# Combine into power_results format matching estimate_power_curve() output
power_results <- tibble(
  n = integer(),
  power = numeric(),
  lower_ci = numeric(),
  upper_ci = numeric(),
  successes = integer(),
  n_valid = integer()
)

for (n in sample_sizes) {
  key <- as.character(n)
  if (key %in% names(all_results)) {
    res <- all_results[[key]]
    power_results <- bind_rows(power_results, tibble(
      n = res$n,
      power = res$power,
      lower_ci = res$lower_ci,
      upper_ci = res$upper_ci,
      successes = res$successes,
      n_valid = res$n_valid
    ))
  }
}

# Print summary
message("\n=== Power Curve Results ===")
print(power_results)

# Estimate required N for 90% power
message("\nEstimating required sample size for 90% power...")
required_n_result <- estimate_required_n(power_results, target_power = 0.90)

# Print summary
print_power_summary(power_results, required_n_result)

# Save combined results
saveRDS(power_results, file.path(cache_dir, "power_results.rds"))
saveRDS(required_n_result, file.path(cache_dir, "required_n_result.rds"))

message(sprintf("\nCombined results saved to %s/", cache_dir))
message("  - power_results.rds")
message("  - required_n_result.rds")

# Total elapsed time
total_time <- sum(power_results$elapsed_mins, na.rm = TRUE)
message(sprintf("\nTotal computation time: %.1f minutes (across all nodes)", total_time))
