# _setup.R
# Package loading and global configuration for taurinelc simulation project

# Add shared library path for AWS ParallelCluster (compute nodes need this)
if (dir.exists("/shared/R-libs")) {
  .libPaths(c("/shared/R-libs", .libPaths()))
}

# Required packages
required_packages <- c(

"cmdstanr",
"tidyverse",
"furrr",
"future",
"posterior",
"bayesplot",
"mvtnorm",
"truncnorm",
"ggplot2",
"patchwork"
)

# Load packages (skip installation - packages should be pre-installed)
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is not installed. Please install it first.", pkg))
  }
  library(pkg, character.only = TRUE)
}

# Set CmdStan path - check environment variable first, then common locations
if (Sys.getenv("CMDSTAN") != "") {
  cmdstanr::set_cmdstan_path(Sys.getenv("CMDSTAN"))
} else if (dir.exists("/shared/cmdstan-2.34.1")) {
  # AWS ParallelCluster location
  cmdstanr::set_cmdstan_path("/shared/cmdstan-2.34.1")
} else if (dir.exists(file.path(Sys.getenv("HOME"), ".cmdstan/cmdstan-2.34.1"))) {
  # Default local installation
  cmdstanr::set_cmdstan_path(file.path(Sys.getenv("HOME"), ".cmdstan/cmdstan-2.34.1"))
}

# Configure parallel processing
configure_parallel <- function(n_cores = NULL) {
if (is.null(n_cores)) {
  n_cores <- min(parallel::detectCores() - 1, 8)
}

# Check if running during Quarto render
if (Sys.getenv("QUARTO_RENDER") == "TRUE") {
  plan(sequential)
  message("Running in sequential mode (Quarto render detected)")
} else {
  plan(multisession, workers = n_cores)
  message(sprintf("Configured parallel processing with %d workers", n_cores))
}

invisible(n_cores)
}

# Helper for result caching
compute_with_cache <- function(cache_file, compute_fn, force_recompute = FALSE) {
cache_path <- file.path("data", "cached_results", cache_file)

if (!force_recompute && file.exists(cache_path)) {
  message("Loading cached results from: ", cache_path)
  return(readRDS(cache_path))
}

message("Computing results (this may take a while)...")
result <- compute_fn()

# Ensure directory exists
dir.create(dirname(cache_path), showWarnings = FALSE, recursive = TRUE)
saveRDS(result, cache_path)
message("Cached results saved to: ", cache_path)

return(result)
}

# Set global ggplot theme
theme_set(theme_minimal(base_size = 12))

# Suppress Stan compilation messages in Quarto
if (Sys.getenv("QUARTO_RENDER") == "TRUE") {
options(cmdstanr_verbose = FALSE)
}

message("Setup complete. Use source('R/parameters.R') to load trial parameters.")
