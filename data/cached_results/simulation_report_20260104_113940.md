# Taurine Long COVID Trial Simulation Report

**Simulation Assurance Documentation**

**Generated:** 2026-01-04 11:39:40 UTC

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Trial Design Parameters](#trial-design-parameters)
3. [Statistical Model](#statistical-model)
4. [Simulation Configuration](#simulation-configuration)
5. [Infrastructure](#infrastructure)
6. [Simulation Results](#simulation-results)
7. [Quality Assurance](#quality-assurance)
8. [Appendix: Technical Details](#appendix-technical-details)

---

## Executive Summary

This report documents the simulation-based sample size determination for a Phase 2 clinical trial investigating taurine supplementation in Long COVID patients. The trial employs a Bayesian adaptive design with two co-primary endpoints.

### Key Design Features

- **Co-primary Outcomes:** TMT B/A Ratio (cognition) and MFIS (fatigue)
- **Randomization:** 2:1 (treatment:control)
- **Decision Rule:** Declare success if P(benefit) ≥ 0.95 for BOTH outcomes
- **Adaptive Design:** Sequential monitoring with futility stopping

### Simulation Components

| Analysis | Purpose | Replications |
|----------|---------|--------------|
| Power | Conditional probability of success at fixed effect size | 100/N |
| Assurance | Bayesian expected power over effect uncertainty | 100/N |
| Type I Error | False positive rate under null hypothesis | 500/N |


---

## Trial Design Parameters

### Co-Primary Outcomes

| Parameter | TMT B/A Ratio | MFIS |
|-----------|---------------|------|
| Full Name | Trail Making Test B/A | Modified Fatigue Impact Scale |
| Population Mean | 2.22 | 23.7 |
| Population SD | 1.07 | 21.1 |
| MCID | 0.5 | 10 |
| Range | [0.9, 5.0] | [0, 84] |
| Direction | Lower is better | Lower is better |

### Treatment Effects (Design Assumptions)

| Outcome | Treatment Effect | Residual SD |
|---------|------------------|-------------|
| TMT B/A | -0.15 (reduction) | 0.5 |
| MFIS | -5.0 points (reduction) | 8.0 |

**Outcome Correlation (ρ):** 0.2

### Decision Thresholds

| Decision | Criterion |
|----------|-----------|
| Efficacy (Success) | P(γ < 0 \| data) ≥ 0.95 for BOTH outcomes |
| Futility (Stop early) | P(γ < 0 \| data) < 0.10 for EITHER outcome |

### Randomization

- **Allocation Ratio:** 2:1 (Treatment:Control)
- **Sample Size Range:** 120 to 480 (increments of 60)


---

## Statistical Model

### Bivariate Normal Model

The analysis uses a Bayesian bivariate normal model with baseline adjustment:

```
y_tmt[i] ~ Normal(α_tmt + β_tmt * x_tmt[i] + γ_tmt * treat[i], σ_tmt)
y_mfis[i] ~ Normal(α_mfis + β_mfis * x_mfis[i] + γ_mfis * treat[i], σ_mfis)
```

Where:
- `y`: Follow-up outcome
- `x`: Baseline measurement (standardized)
- `treat`: Treatment indicator (1 = taurine, 0 = placebo)
- `γ`: Treatment effect parameter (negative = benefit)

### Prior Distributions

| Parameter | Prior | Rationale |
|-----------|-------|-----------|
| α (intercept) | Normal(0, 5) | Weakly informative |
| β (baseline) | Normal(1, 0.5) | Expected regression to mean |
| γ (treatment) | Normal(0, 2) | Skeptical, centered at null |
| σ (residual SD) | Half-Normal(0, 5) | Weakly informative |
| ρ (correlation) | LKJ(2) | Slight preference for independence |

### Inference

Stan MCMC sampling with:
- 4 parallel chains
- 1,000 warmup iterations
- 2,000 sampling iterations
- adapt_delta = 0.95
- max_treedepth = 12


---

## Simulation Configuration

### Power Analysis

- **Objective:** Estimate conditional power at fixed effect sizes
- **Effect Sizes:** TMT γ = -0.15, MFIS γ = -5.0
- **Replications:** 100 per sample size
- **Sample Sizes:** 120, 180, 240, 300, 360, 420, 480

### Assurance Analysis

- **Objective:** Estimate Bayesian assurance (expected power)
- **Design Prior:** Integrates uncertainty in effect size
  - TMT: Normal(-0.10, 0.05)
  - MFIS: Normal(-0.20, 0.10) on standardized scale
- **Replications:** 100 per sample size

### Type I Error Analysis

- **Objective:** Verify false positive rate under null hypothesis
- **True Effect:** γ = 0 for both outcomes
- **Replications:** 500 per sample size (higher precision needed)
- **Target:** Type I error ≤ 0.025 (one-sided)


---

## Infrastructure

### AWS ParallelCluster Configuration

| Component | Instance Type | Cost/Hour |
|-----------|---------------|-----------|
| Head Node | t3.large | $0.083 |
| Compute Nodes | c5.xlarge (4 vCPU, 8GB) | $0.170 |

**Compute Cluster:**
- Min nodes: 0 (auto-scales down)
- Max nodes: 10
- Slurm job scheduler

### Software Environment

| Component | Version |
|-----------|---------|
| R | 4.x |
| CmdStan | 2.37.0 |
| cmdstanr | Latest |
| Stan Model | coprimary_model_v4.stan |

### Parallelization Strategy

- **Job Arrays:** 7 parallel jobs (one per sample size)
- **Within Job:** 4 parallel MCMC chains
- **Memory:** 6 GB per job
- **CPU:** 4 cores per job


---

## Simulation Results

### Power Analysis

**Status:** COMPLETED
**Runtime:** 1h 8m 39s

| Sample Size | Result File | Status |
|-------------|-------------|--------|
| 120 | power_n120.rds | ✓ Saved |
| 180 | power_n180.rds | ✓ Saved |
| 240 | power_n240.rds | ✓ Saved |
| 300 | power_n300.rds | ✓ Saved |
| 360 | power_n360.rds | ✓ Saved |
| 420 | power_n420.rds | ✓ Saved |
| 480 | power_n480.rds | ✓ Saved |

### Assurance Analysis

**Status:** 2/7 complete

| Sample Size | Status |
|-------------|--------|
| 120 | ✓ Saved |
| 180 | ✓ Saved |
| 240 | Pending |
| 300 | Pending |
| 360 | Pending |
| 420 | Pending |
| 480 | Pending |

### Type I Error Analysis

**Status:** 0/7 complete

| Sample Size | Status |
|-------------|--------|
| 120 | Pending |
| 180 | Pending |
| 240 | Pending |
| 300 | Pending |
| 360 | Pending |
| 420 | Pending |
| 480 | Pending |

### Cost Summary

| Category | Time | Cost (USD) |
|----------|------|------------|
| Completed | 1h 8m 39s | $1.36 |
| Running | 36m 26s | $0.72 |
| Remaining (est.) | 5h 43m 15s | $6.81 |
| **Total** | 8h 0m 42s | **$10.20** |


---

## Quality Assurance

### Reproducibility

- **Random Seeds:** Unique prime-based seeds per array task
  - Power: Base 4231 + task_id × 1117
  - Assurance: Base 2234 + task_id × 1000
  - Type I Error: Base 5000 + task_id × 1000
- **Version Control:** Git repository with locked dependencies
- **Results Cache:** Individual .rds files per sample size

### MCMC Diagnostics

For each simulation replicate, the following diagnostics are checked:
- R-hat < 1.01 for all parameters
- Bulk ESS > 400
- Tail ESS > 400
- No divergent transitions
- No max treedepth warnings

### Data Quality

- Truncated normal distributions respect outcome bounds
- Baseline-adjusted means reflect target population
- 2:1 randomization maintained exactly


---

## Appendix: Technical Details

### File Structure

```
/shared/taurinelc/
├── R/
│   ├── parameters.R          # Trial parameters
│   ├── priors.R              # Two-prior framework
│   ├── simulate_data.R       # Data generation
│   ├── fit_model.R           # Stan model interface
│   ├── power_analysis.R      # Power/assurance functions
│   └── type1_error.R         # Type I error estimation
├── stan/
│   └── coprimary_model_v4.stan  # Bayesian model
├── cluster/
│   ├── slurm_power_array.sh     # Power job script
│   ├── slurm_assurance_array.sh # Assurance job script
│   ├── slurm_type1_array.sh     # Type I error job script
│   └── check_progress.sh        # This monitoring script
├── data/cached_results/
│   ├── power_n*.rds
│   ├── assurance_n*.rds
│   └── type1_n*.rds
└── logs/
    └── *.out, *.err           # SLURM job logs
```

### SLURM Job Configuration

```bash
#SBATCH --partition=compute
#SBATCH --array=1-7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=6G
```

### Result File Format

Each .rds file contains:

**Power/Assurance:**
```r
list(
  n = sample_size,
  power/assurance = point_estimate,
  lower_ci = wilson_lower,
  upper_ci = wilson_upper,
  successes = count,
  n_valid = valid_reps,
  elapsed_mins = runtime
)
```

**Type I Error:**
```r
list(
  n = sample_size,
  type1_error = point_estimate,
  lower_ci = wilson_lower,
  upper_ci = wilson_upper,
  false_positives = count,
  n_valid = valid_reps,
  decision_threshold = 0.95
)
```


---

*Report generated by check_progress.sh on ip-172-31-39-166 at 2026-01-04 11:39:40 UTC*
