# run_single_n_type1.R
# Run Type I error analysis for a single sample size (for Slurm job arrays)
# Usage: Rscript run_single_n_type1.R --n=120 --reps=500 --seed=5000

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
n_reps <- as.integer(parse_arg(args, "reps", "500"))
seed_base <- as.integer(parse_arg(args, "seed", "5000"))
threshold <- as.numeric(parse_arg(args, "threshold", "0.95"))

message(sprintf("Running Type I error analysis for N = %d with %d replications", n, n_reps))
message(sprintf("Decision threshold: %.2f", threshold))

# Load all required packages and source files
message("Loading packages and functions...")
source("R/_setup.R")
source("R/parameters.R")
source("R/priors.R")
source("R/simulate_data.R")
source("R/fit_model.R")
source("R/power_analysis.R")
source("R/type1_error.R")

# Compile model
message("Compiling Stan model...")
model <- compile_model()

# Run Type I error analysis for this single sample size
start_time <- Sys.time()
message(sprintf("Starting at %s...", format(start_time, "%H:%M:%S")))

# Run simulations under null hypothesis
results <- estimate_type1_error(
  n = n,
  model = model,
  n_reps = n_reps,
  decision_threshold = threshold,
  parallel = FALSE
)

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")
message(sprintf("Completed N = %d in %.1f minutes", n, as.numeric(elapsed)))

# Print results
message(sprintf("Type I Error: %.4f [%.4f, %.4f]",
                results$type1_error,
                results$lower_ci,
                results$upper_ci))
message(sprintf("False positives: %d/%d", results$false_positives, results$n_valid))

# Save results for this N
cache_dir <- "data/cached_results"
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir, recursive = TRUE)
}

output_file <- file.path(cache_dir, sprintf("type1_n%d.rds", n))
saveRDS(list(
  n = results$n,
  type1_error = results$type1_error,
  lower_ci = results$lower_ci,
  upper_ci = results$upper_ci,
  false_positives = results$false_positives,
  n_valid = results$n_valid,
  n_reps = n_reps,
  decision_threshold = threshold,
  elapsed_mins = as.numeric(elapsed)
), output_file)

message(sprintf("Results saved to %s", output_file))
