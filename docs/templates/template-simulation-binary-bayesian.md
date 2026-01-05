> **Parent Document:** [SOP: Bayesian Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-bayesian-analysis.md)

**Below is a Bayesian, R-centric framework** for **simulation-based design of clinical trials with a binary primary outcome**. It addresses the limitations of frequentist approaches in rare event settings (zero cells) and provides interpretable probability statements.

---

## **1. Choice of Estimand**

### **Comparison: Estimand vs. Method**
| Estimand | Frequentist Method | Bayesian Method |
| :--- | :--- | :--- |
| **Odds Ratio (OR)** | `glm(family=binomial)` | `stan_glm(family=binomial)` |
| **Risk Difference (RD)** | `lm` (LPM) | `stan_glm(family=gaussian)` or Posterior Transform |
| **Risk Ratio (RR)** | `glm(link="log")` | `stan_glm(family=binomial, link="log")` |

### **R Tools**
* `rstanarm` (Standard Bayesian GLMs)
* `brms` (Advanced, hierarchical models)
* `rethinking` (Educational)

---

## **2. Bayesian Simulation Template (Binary)**

This module simulates a 2-arm trial and compares Bayesian vs. Frequentist performance in a "Rare Event" scenario where frequentist MLE might fail (separation).

### **R Code**

```r
library(dplyr)
library(rstanarm)
library(broom.mixed)

# Use parallel cores for MCM speed
options(mc.cores = parallel::detectCores())

simulate_binary_bayesian <- function(n_per_arm, 
                                     p_control, 
                                     true_OR,
                                     prior_scale = 2.5) {
  
  # A. Generate Data
  odds_control <- p_control / (1 - p_control)
  odds_treat   <- odds_control * true_OR
  p_treat      <- odds_treat / (1 + odds_treat)
  
  data <- data.frame(
    arm = factor(c(rep("Control", n_per_arm), rep("Treatment", n_per_arm)), levels = c("Control", "Treatment")),
    y   = c(rbinom(n_per_arm, 1, p_control), rbinom(n_per_arm, 1, p_treat))
  )
  
  # Check for Separation (Zero events)
  zeros <- sum(data$y[data$arm=="Control"]) == 0 | sum(data$y[data$arm=="Treatment"]) == 0
  
  # B. Bayesian Analysis (Logistic Regression)
  # Prior: Normal(0, 2.5) - Weakly informative, prevents explosion of estimates
  fit <- stan_glm(y ~ arm, data = data, 
                  family = binomial(link = "logit"),
                  prior = normal(0, prior_scale),
                  chains = 1, iter = 1000, refresh = 0)
  
  # C. Decision Rule (Posterior Probability)
  post_samples <- as.matrix(fit)
  log_or_samples <- post_samples[, "armTreatment"]
  
  # Prob(Treatment is effective) i.e. OR < 1 (LogOR < 0)
  prob_success <- mean(log_or_samples < 0)
  
  # Success Threshold (e.g., > 95% probability)
  is_success   <- prob_success > 0.95
  
  return(data.frame(
    est_OR = exp(mean(log_or_samples)),
    prob_success = prob_success,
    is_success = is_success,
    has_separation = zeros
  ))
}

# --- Execution ---
# set.seed(42)
# results <- bind_rows(replicate(50, simulate_binary_bayesian(50, p_control=0.05, true_OR=0.5), simplify = FALSE))
```

---

## **3. Key Advantages of Bayesian Approach**

1.  **No Separation Failures:** Even if one arm has 0 events, the prior stabilizes the estimate (shrinkage). The model always converges.
2.  **Intuitive Success Criteria:** "There is a 98% probability the drug works" vs. "p=0.038".
3.  **Incorporating History:** You can use an informative prior (e.g., `prior = normal(-0.5, 0.5)`) to borrow strength from Phase 2 data.
