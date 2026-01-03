# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bayesian simulation-based sample size determination for a taurine supplementation trial in Long COVID patients. Uses R + Stan for Bayesian modeling with a Quarto reproducible report.

## Common Commands

### Local Development
```bash
# Render Quarto report
quarto render

# Full power analysis (~2 hours, 700 model fits)
Rscript run_power_analysis.R

# Quick test (~10 mins)
Rscript run_power_analysis.R --quick

# Single sample size test
Rscript run_single_n.R --n=300 --reps=10
```

### AWS Cluster Execution
```bash
# Submit job array (7 parallel nodes, ~20 mins total)
sbatch cluster/slurm_power_array.sh

# Monitor progress
bash cluster/check_progress.sh

# Combine results after completion
Rscript combine_power_results.R
```

## Architecture

```
R/parameters.R          # Centralized trial parameters
       ↓
R/simulate_data.R       # Generate truncated normal data with 2:1 randomization
       ↓
stan/coprimary_model_v4.stan  # Bivariate normal Bayesian model (MCMC)
       ↓
R/fit_model.R           # Compile & fit Stan model
       ↓
R/power_analysis.R      # Estimate power curves via simulation
R/interim_analysis.R    # Adaptive stopping rules
       ↓
report/*.qmd            # Quarto chapters (8 total)
```

### Key R Files

- **`R/_setup.R`**: Package loading, parallel config, CmdStan path setup. Source first.
- **`R/parameters.R`**: All trial parameters (`outcomes`, `true_effects`, `sim_params`, `stan_options`)
- **`R/simulate_data.R`**: `simulate_trial_data(n)` generates Stan-formatted data
- **`R/fit_model.R`**: `compile_model()`, `fit_coprimary_model()`, `extract_treatment_effects()`
- **`R/power_analysis.R`**: `simulate_power()`, `estimate_power_curve()`, `estimate_required_n()`

### Stan Models

- **`coprimary_model_v4.stan`**: Canonical model - bivariate normal with standardized baselines, LKJ(2) correlation prior
- **`coprimary_model_v3.stan`**: Alternative for sensitivity analysis

### Results Format

Power results stored in `data/cached_results/`:
```r
power_results: tibble(n, power, lower_ci, upper_ci, successes, n_valid)
required_n_result: list(target_power, required_n, se, lower_ci, upper_ci, logit_model)
```

## Development Patterns

### Sourcing Order
```r
source("R/_setup.R")
source("R/parameters.R")
source("R/simulate_data.R")
source("R/fit_model.R")
source("R/power_analysis.R")
```

### Parallel Processing
- Local: `furrr::future_map()` with `plan(multisession)` - currently disabled due to cmdstanr temp file conflicts
- Cluster: SLURM job arrays via `run_single_n.R` (one job per sample size)
- Stan always runs 4 parallel chains internally

### Caching
- `compute_with_cache(expr, cache_file)` in `_setup.R` for expensive computations
- RDS files in `data/cached_results/`
- Quarto freeze in `_freeze/`

### Stan Compilation
Stan binaries are platform-specific (macOS arm64 ≠ Linux x86_64). On cluster, models must be recompiled:
```r
model <- compile_model()  # Creates stan/coprimary_model_v4 executable
```

## Trial Parameters

| Parameter | Value |
|-----------|-------|
| Co-primary outcomes | TMT B/A Ratio, MFIS |
| Randomization | 2:1 (Treatment:Control) |
| Decision threshold | P(benefit) ≥ 0.95 |
| Futility threshold | P(benefit) < 0.10 |
| Sample sizes tested | 120, 180, 240, 300, 360, 420, 480 |
| Replications | 100 per sample size |

## Cluster Notes

- Head node: `t3.large`, Compute: `c5.xlarge` (0-10 autoscaling)
- R packages at `/shared/R-libs` (not system library)
- CmdStan at `/shared/cmdstan-2.34.1`
- Key scripts: `cluster/setup_cluster.sh`, `cluster/slurm_power_array.sh`, `cluster/check_progress.sh`
