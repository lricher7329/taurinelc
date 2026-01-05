> **Parent Document:** [SOP: Bayesian Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-bayesian-analysis.md)

**Below is a R-centric framework** for **simulation-based design of clinical trials with a continuous primary outcome**. This template covers standard ANCOVA approaches as well as longitudinal considerations (MMRM).

---

## **1. Choice of Estimand and Effect Measure**

### **Core Design Question**
What quantity defines "treatment effect"?

Common estimands:
* **Difference in Means** (at specific timepoint)
* **Slope difference** (rate of change)
* **Area Under the Curve (AUC)**

### **R Tools**
* `rstanarm::stan_glm()` for Bayesian ANCOVA
* `brms::brm()` for longitudinal models (MMRM)

---

## **2. Bayesian ANCOVA Simulation Template**

This module simulates a simple 2-arm trial comparing change from baseline, adjusting for baseline value, using a **Bayesian Linear Model**.

### **R Code**

```r
library(dplyr)
library(broom.mixed) # For tidy Bayesian results
library(rstanarm)

# Enable parallel processing
options(mc.cores = parallel::detectCores())

simulate_bayesian_continuous <- function(n_per_arm, 
                                         true_diff,     # Treatment effect
                                         sd_outcome,    # Residual SD
                                         prior_scale = 2.5 # Weakly informative prior width
                                         ) {
  
  # A. Generate Data (Standard Normal mechanism)
  baseline <- rnorm(2 * n_per_arm, mean = 50, sd = 10)
  arm <- c(rep("Control", n_per_arm), rep("Treatment", n_per_arm))
  trt_effect <- ifelse(arm == "Treatment", true_diff, 0)
  outcome <- baseline + trt_effect + rnorm(2 * n_per_arm, sd = sd_outcome)
  
  data <- data.frame(arm = as.factor(arm), baseline = baseline, outcome = outcome)
  
  # B. Bayesian Analysis
  # Estimand: Treatment effect (beta_treatment)
  # Model: outcome ~ baseline + arm
  # Priors: Weakly informative Normal(0, 2.5) for coefficients
  
  fit <- stan_glm(outcome ~ baseline + arm, 
                  data = data, 
                  family = gaussian(),
                  prior = normal(0, prior_scale),
                  prior_intercept = normal(50, 10),
                  prior_aux = exponential(1), # Prior for sigma
                  chains = 1, iter = 1000, refresh = 0) # Speed for simulation
  
  # C. Decision Rule (Posterior Probability of Success)
  # Calculate Prob(Treatment Effect > 0)
  post_samples <- as.matrix(fit)
  trt_samples <- post_samples[, "armTreatment"]
  prob_success <- mean(trt_samples > 0)
  
  # Standard Decision Threshold: e.g., > 97.5% probability
  success <- prob_success > 0.975
  
  return(data.frame(
    post_mean = mean(trt_samples),
    prob_success = prob_success,
    is_success = success
  ))
}

# --- Execution ---
# set.seed(123)
# results <- bind_rows(replicate(100, simulate_bayesian_continuous(100, 2.5, 10), simplify = FALSE))
# assurance <- mean(results$is_success)
```

## **3. Longitudinal (MMRM) Extensions**

For trials with repeated measures, we use **Bayesian MMRM** to handle missingness and correlation.

### **R Code Strategy**
Use `brms` to model unstructured covariance (or approximation).

```r
library(brms)

# Model: Change ~ Baseline + Visit*Arm + (1|Subject) or unstr(Visit|Subject)
# brm(formula = outcome ~ baseline + visit * arm + (1|subject), 
#     data = data_long, 
#     prior = set_prior("normal(0,5)", class = "b"))
```

---

## **4. Robustness Checks**

### **Heteroscedasticity**
What if the treatment increases the variance (not just the mean)?
* Standard ANCOVA assumes equal variance.
* **Fix:** Use `nlme::gls(..., weights = varIdent(form = ~1|arm))` to model unequal variances.

### **Non-Normality**
Continuous data is rarely perfectly normal (e.g., skewed biomarkers).
* **Fix:** Simulate Log-Normal data and test if the `lm()` on raw scale holds type I error, or if log-transformation is required.
