#!/usr/bin/env Rscript
# audit_packages.R
# Audit installed R packages in shared library and check for updates
# Run with: Rscript cluster/audit_packages.R

lib <- "/shared/R-libs"

# Use CRAN repository
options(repos = c(CRAN = "https://cloud.r-project.org"))

cat("Auditing R packages in:", lib, "\n\n")

ip <- as.data.frame(installed.packages(lib.loc = lib), stringsAsFactors = FALSE)
inst <- ip[, c("Package", "Version", "LibPath")]
inst$Version <- as.character(inst$Version)

avail <- available.packages()
avail_versions <- as.character(avail[inst$Package, "Version"])

inst$Available <- avail_versions
inst$Outdated <- !is.na(inst$Available) & (utils::compareVersion(inst$Version, inst$Available) < 0)

out <- inst[order(inst$Outdated, inst$Package, decreasing = TRUE), ]

ts <- format(Sys.time(), "%Y%m%d-%H%M%S")
outfile <- file.path(tempdir(), paste0("r-libs-audit-", ts, ".csv"))
write.csv(out, outfile, row.names = FALSE)

cat("Wrote:", outfile, "\n")
cat("Installed:", nrow(inst), "Outdated:", sum(inst$Outdated, na.rm = TRUE), "\n")

# Print outdated packages
if (sum(inst$Outdated, na.rm = TRUE) > 0) {
  cat("\nOutdated packages:\n")
  outdated <- out[out$Outdated == TRUE, c("Package", "Version", "Available")]
  print(outdated, row.names = FALSE)
}
