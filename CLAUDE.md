# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bayesian simulation-based sample size determination for a taurine supplementation trial in Long COVID patients. Uses R + Stan for Bayesian modeling with a Quarto reproducible report.

**Key design features:**
- Co-primary outcomes (TMT B/A Ratio + MFIS) - trial succeeds only if BOTH show benefit
- Both outcomes use "lower is better" convention (negative treatment effect = improvement)
- 2:1 randomization (treatment:control)
- Decision threshold: P(benefit) ≥ 0.95 for both outcomes simultaneously

## Environment Setup

Before running AWS CLI commands (pcluster, aws, etc.), activate the Python virtual environment:
```bash
source .venv/bin/activate
```

## Common Commands

### Local Development
```bash
# Render Quarto report
quarto render

# Full power analysis (~2 hours, 700 model fits)
Rscript run_power_analysis.R

# Quick test (~10 mins)
Rscript run_power_analysis.R --quick

# Single sample size - power, assurance, or type I error
Rscript run_single_n.R --n=300 --reps=10
Rscript run_single_n_assurance.R --n=300 --reps=10
Rscript run_single_n_type1.R --n=300 --reps=100
```

### AWS Cluster Execution
```bash
# Submit job arrays (7 parallel nodes each, ~20 mins total)
sbatch cluster/slurm_power_array.sh
sbatch cluster/slurm_assurance_array.sh
sbatch cluster/slurm_type1_array.sh

# Monitor progress (show all simulations)
bash cluster/check_progress.sh

# Monitor specific simulation type
bash cluster/check_progress.sh --power
bash cluster/check_progress.sh --assurance
bash cluster/check_progress.sh --type1

# Generate comprehensive markdown report for assurance documentation
bash cluster/check_progress.sh --report
# Report saved to: /shared/taurinelc/data/cached_results/simulation_report_YYYYMMDD_HHMMSS.md

# Combine results after completion
Rscript cluster/combine_results.R
```

## Architecture

```
R/parameters.R          # Centralized trial parameters
       ↓
R/priors.R              # Two-prior framework (design vs analysis)
       ↓
R/simulate_data.R       # Generate truncated normal data with 2:1 randomization
       ↓
stan/coprimary_model_v4.stan  # Bivariate normal Bayesian model (MCMC)
       ↓
R/fit_model.R           # Compile & fit Stan model
       ↓
R/power_analysis.R      # Power and assurance via simulation
R/type1_error.R         # Type I error estimation under null
R/sensitivity.R         # Prior sensitivity analysis
R/interim_analysis.R    # Adaptive stopping rules
       ↓
report/*.qmd            # Quarto chapters (10 total)
```

### Key R Files

- **`R/_setup.R`**: Package loading, parallel config, CmdStan path setup. Source first.
- **`R/parameters.R`**: All trial parameters (`outcomes`, `true_effects`, `sim_params`, `stan_options`)
- **`R/priors.R`**: Two-prior framework for assurance
  - `specify_design_prior()`: Define design prior for assurance calculation
  - `specify_analysis_prior()`: Define analysis prior for inference
  - `sample_from_design_prior()`: Generate samples for assurance
  - `calculate_prior_ess()`: Prior effective sample size
  - `create_taurinelc_design_priors()`: TMT/MFIS-specific design priors
- **`R/simulate_data.R`**: `simulate_trial_data(n)` generates Stan-formatted data
- **`R/fit_model.R`**: `compile_model()`, `fit_coprimary_model()`, `extract_treatment_effects()`
- **`R/power_analysis.R`**: Power and assurance estimation
  - `simulate_power()`: Conditional power at fixed effect
  - `estimate_power_curve()`: Power across sample sizes
  - `calculate_assurance()`: Bayesian assurance (integrates over design prior)
  - `estimate_assurance_curve()`: Assurance across sample sizes
  - `estimate_required_n()`: Sample size for target power
  - `estimate_required_n_assurance()`: Sample size for target assurance
- **`R/type1_error.R`**: Type I error calibration
  - `estimate_type1_error()`: False positive rate under null
  - `estimate_type1_curve()`: Type I error across sample sizes
  - `calibrate_threshold()`: Find threshold for target alpha
  - `create_oc_table()`: Combined operating characteristics table
- **`R/sensitivity.R`**: Prior sensitivity analysis
  - `run_prior_sensitivity()`: Power/assurance across prior grid
  - `run_effect_sensitivity()`: Power across effect sizes
  - `compare_prior_scenarios()`: Named scenario comparison
  - `plot_prior_sensitivity()`: Visualization

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
source("R/_setup.R")           # Always first - loads packages, sets paths
source("R/parameters.R")       # Trial parameters (outcomes, effects, thresholds)
source("R/priors.R")           # Two-prior framework (design vs analysis)
source("R/simulate_data.R")    # Data generation
source("R/fit_model.R")        # Stan compilation & fitting
source("R/power_analysis.R")   # Power & assurance estimation
source("R/type1_error.R")      # Type I error calibration
source("R/sensitivity.R")      # Prior sensitivity analysis
source("R/interim_analysis.R") # Stopping rules
source("R/visualization.R")    # Plotting (optional)
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
- CmdStan at `/shared/cmdstan-2.37.0`
- Key scripts: `cluster/setup_cluster.sh`, `cluster/slurm_power_array.sh`, `cluster/check_progress.sh`
- See `cluster/README.md` for full AWS ParallelCluster setup guide

## Troubleshooting

### Stan Compilation
Stan binaries are platform-specific. If you see "wrong architecture" errors:
```r
model <- compile_model()  # Recompiles for current platform
```

### MCMC Issues
- Divergent transitions: Check `adapt_delta` in `stan_options` (currently 0.95)
- Slow sampling: Reduce `max_treedepth` or simplify model
- Stuck chains at specific N: Use prime-based seed strategy (see `run_single_n.R`)

### Quarto Rendering
If computations hang, check for stale `_freeze/` cache or run with `--cache-refresh`
