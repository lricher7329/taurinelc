# run_single_n_assurance.R
# Run assurance analysis for a single sample size (for Slurm job arrays)
# Usage: Rscript run_single_n_assurance.R --n=120 --reps=100 --seed=1234

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

parse_arg <- function(args, name, default = NULL) {
  pattern <- paste0("^--", name, "=")
  match <- grep(pattern, args, value = TRUE)
  if (length(match) > 0) {
    return(sub(pattern, "", match[1]))
  }
  return(default)
}

n <- as.integer(parse_arg(args, "n", "300"))
n_reps <- as.integer(parse_arg(args, "reps", "100"))
seed_base <- as.integer(parse_arg(args, "seed", "1234"))

message(sprintf("Running assurance analysis for N = %d with %d replications", n, n_reps))

# Load all required packages and source files
message("Loading packages and functions...")
source("R/_setup.R")
source("R/parameters.R")
source("R/priors.R")
source("R/simulate_data.R")
source("R/fit_model.R")
source("R/power_analysis.R")

# Compile model
message("Compiling Stan model...")
model <- compile_model()

# Create combined design prior for TMT and MFIS
design_prior <- create_combined_design_prior(
  tmt_effect = -0.10,
  tmt_sd = 0.05,
  mfis_effect = -0.20,
  mfis_sd = 0.10
)

message("Design prior:")
message(sprintf("  Mean: %.3f", design_prior$mean))
message(sprintf("  SD: %.3f", design_prior$sd))

# Run assurance analysis for this single sample size
start_time <- Sys.time()
message(sprintf("Starting at %s...", format(start_time, "%H:%M:%S")))

# Run simulations for this N using calculate_assurance()
results <- calculate_assurance(
  n = n,
  model = model,
  design_prior = design_prior,
  n_reps = n_reps
)

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")
message(sprintf("Completed N = %d in %.1f minutes", n, as.numeric(elapsed)))

# Print results
message(sprintf("Assurance: %.1f%% [%.1f%%, %.1f%%]",
                results$power * 100,
                results$lower_ci * 100,
                results$upper_ci * 100))
message(sprintf("Valid simulations: %d/%d", results$n_valid, n_reps))

# Save results for this N
cache_dir <- "data/cached_results"
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir, recursive = TRUE)
}

output_file <- file.path(cache_dir, sprintf("assurance_n%d.rds", n))
saveRDS(list(
  n = results$n,
  assurance = results$power,
  lower_ci = results$lower_ci,
  upper_ci = results$upper_ci,
  successes = results$successes,
  n_valid = results$n_valid,
  n_reps = n_reps,
  design_prior = design_prior,
  elapsed_mins = as.numeric(elapsed)
), output_file)

message(sprintf("Results saved to %s", output_file))
