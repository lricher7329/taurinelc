# combine_results.R
# Combine results from all cluster analyses (power, assurance, type I error)
# Run this after all cluster jobs complete

message("=== Combining Cluster Results ===")

cache_dir <- "data/cached_results"
sample_sizes <- c(120, 180, 240, 300, 360, 420, 480)

# ============================================================================
# Combine Power Results
# ============================================================================
message("\n--- Power Results ---")

power_files <- list.files(cache_dir, pattern = "^power_n\\d+\\.rds$", full.names = TRUE)

if (length(power_files) > 0) {
  power_list <- lapply(power_files, readRDS)

  power_results <- do.call(rbind, lapply(power_list, function(x) {
    data.frame(
      n = x$n,
      power = x$power,
      lower_ci = x$lower_ci,
      upper_ci = x$upper_ci,
      successes = x$successes,
      n_valid = x$n_valid
    )
  }))

  power_results <- power_results[order(power_results$n), ]

  message("Power by Sample Size:")
  for (i in seq_len(nrow(power_results))) {
    message(sprintf("  N = %3d: %.1f%% [%.1f%%, %.1f%%]",
                    power_results$n[i],
                    power_results$power[i] * 100,
                    power_results$lower_ci[i] * 100,
                    power_results$upper_ci[i] * 100))
  }

  saveRDS(power_results, file.path(cache_dir, "power_results.rds"))
  message(sprintf("Saved combined power results: %d sample sizes", nrow(power_results)))
} else {
  message("No power result files found.")
}

# ============================================================================
# Combine Assurance Results
# ============================================================================
message("\n--- Assurance Results ---")

assurance_files <- list.files(cache_dir, pattern = "^assurance_n\\d+\\.rds$", full.names = TRUE)

if (length(assurance_files) > 0) {
  assurance_list <- lapply(assurance_files, readRDS)

  assurance_results <- do.call(rbind, lapply(assurance_list, function(x) {
    data.frame(
      n = x$n,
      assurance = x$assurance,
      lower_ci = x$lower_ci,
      upper_ci = x$upper_ci,
      n_valid = x$n_valid
    )
  }))

  assurance_results <- assurance_results[order(assurance_results$n), ]

  message("Assurance by Sample Size:")
  for (i in seq_len(nrow(assurance_results))) {
    message(sprintf("  N = %3d: %.1f%% [%.1f%%, %.1f%%]",
                    assurance_results$n[i],
                    assurance_results$assurance[i] * 100,
                    assurance_results$lower_ci[i] * 100,
                    assurance_results$upper_ci[i] * 100))
  }

  saveRDS(assurance_results, file.path(cache_dir, "assurance_results.rds"))
  message(sprintf("Saved combined assurance results: %d sample sizes", nrow(assurance_results)))
} else {
  message("No assurance result files found.")
}

# ============================================================================
# Combine Type I Error Results
# ============================================================================
message("\n--- Type I Error Results ---")

type1_files <- list.files(cache_dir, pattern = "^type1_n\\d+\\.rds$", full.names = TRUE)

if (length(type1_files) > 0) {
  type1_list <- lapply(type1_files, readRDS)

  type1_results <- do.call(rbind, lapply(type1_list, function(x) {
    data.frame(
      n = x$n,
      type1_error = x$type1_error,
      lower_ci = x$lower_ci,
      upper_ci = x$upper_ci,
      false_positives = x$false_positives,
      n_valid = x$n_valid
    )
  }))

  type1_results <- type1_results[order(type1_results$n), ]

  message("Type I Error by Sample Size:")
  for (i in seq_len(nrow(type1_results))) {
    message(sprintf("  N = %3d: %.4f [%.4f, %.4f]",
                    type1_results$n[i],
                    type1_results$type1_error[i],
                    type1_results$lower_ci[i],
                    type1_results$upper_ci[i]))
  }

  saveRDS(type1_results, file.path(cache_dir, "type1_results.rds"))
  message(sprintf("Saved combined type I error results: %d sample sizes", nrow(type1_results)))
} else {
  message("No Type I error result files found.")
}

# ============================================================================
# Create Operating Characteristics Table
# ============================================================================
message("\n--- Operating Characteristics Table ---")

if (exists("power_results") && exists("assurance_results") && exists("type1_results")) {
  # Merge all results
  oc_table <- merge(power_results[, c("n", "power")],
                    assurance_results[, c("n", "assurance")],
                    by = "n", all = TRUE)
  oc_table <- merge(oc_table,
                    type1_results[, c("n", "type1_error")],
                    by = "n", all = TRUE)

  oc_table <- oc_table[order(oc_table$n), ]

  message("\nOperating Characteristics Summary:")
  message(sprintf("%-6s  %8s  %10s  %12s", "N", "Power", "Assurance", "Type I Error"))
  message(paste(rep("-", 42), collapse = ""))
  for (i in seq_len(nrow(oc_table))) {
    message(sprintf("%-6d  %7.1f%%  %9.1f%%  %11.4f",
                    oc_table$n[i],
                    oc_table$power[i] * 100,
                    oc_table$assurance[i] * 100,
                    oc_table$type1_error[i]))
  }

  saveRDS(oc_table, file.path(cache_dir, "oc_table.rds"))
  message("\nSaved operating characteristics table.")
}

message("\n=== Complete ===")
