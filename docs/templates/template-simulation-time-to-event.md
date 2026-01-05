> **Parent Document:** [SOP: Bayesian Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-bayesian-analysis.md)

**Below is a R-centric framework** for **simulation-based design of clinical trials with Time-to-Event (TTE) outcomes**. This covers standard Cox Proportional Hazards models and advanced topics like Crossing Hazards (Non-PH) and Restricted Mean Survival Time (RMST).

---

## **1. Choice of Estimand**

### **Core Design Question**
Does the Hazard Ratio (HR) summarizes the effect adequately?
* **Yes:** If curves separate early and stay parallel.
* **No:** If curves cross (Immunotherapy delayed effect) or converge.

### **R Tools**
* `rstanarm::stan_surv` (Bayesian Parametric/Spline Survival)
* `brms` (Bayesian Cox/Weibull)

---

## **2. Bayesian Survival Simulation Template**

Simulating survival time usually involves generating data from an Exponential or Weibull distribution, then analyzing it using a **Bayesian Survival Model**.

### **R Code**

```r
library(rstanarm)
library(dplyr)
library(survival)

simulate_bayesian_survival <- function(n_per_arm, 
                                       HR_true,       # Hazard Ratio
                                       lambda_ctrl,   # Baseline hazard rate
                                       prior_mu = 0,  # Prior mean for logHR
                                       prior_sd = 1   # Prior SD (Skeptical or Weak)
                                       ) {
  
  # A. Generate Data (Exponential for simplicity)
  n_total <- n_per_arm * 2
  arm <- c(rep(0, n_per_arm), rep(1, n_per_arm))
  rate <- lambda_ctrl * exp(log(HR_true) * arm)
  T_event <- rexp(n_total, rate = rate)
  
  # Variable censoring 
  T_censor <- rexp(n_total, rate = 0.1)
  time <- pmin(T_event, T_censor)
  status <- as.numeric(T_event <= T_censor)
  
  data <- data.frame(time, status, arm)
  
  # B. Bayesian Analysis (Bayesian Exponential/Weibull or Cox)
  # Using 'stan_surv' simplifies parametric survival modeling
  # family = "exponential" assumes constant hazard (Cox-like if PH holds)
  
  fit <- stan_surv(Surv(time, status) ~ arm, 
                   data = data,
                   basehaz = "exp", # or "weibull", "ms" (B-spline)
                   prior = normal(prior_mu, prior_sd),
                   chains = 1, iter = 1000, refresh = 0)
  
  # C. Decision Rule
  # Posterior Probability that Hazard Ratio < 1 (Benefit)
  post_samples <- as.matrix(fit)
  
  # Extract 'arm' coefficient (log-hazard ratio)
  log_hr_samples <- post_samples[, "arm"]
  prob_benefit   <- mean(log_hr_samples < 0)
  
  # Success if Prob(HR < 1) > 0.975 (High confidence of benefit)
  success <- prob_benefit > 0.975
  
  return(data.frame(
    post_mean_hr = exp(mean(log_hr_samples)),
    prob_benefit = prob_benefit,
    is_success = success
  ))
}

# --- Execution ---
# set.seed(42)
# results <- bind_rows(replicate(50, simulate_bayesian_survival(100, HR_true=0.7, lambda_ctrl=0.05), simplify=FALSE))
```

---

## **3. Dealing with Non-Proportional Hazards (Crossing Curves)**

In Immuno-Oncology, Kaplan-Meier curves often overlap for 3-6 months before separating ("Delayed Effect"). The Cox standard HR is invalid here because it averages the "no effect" period with the "strong effect" period.

### **Simulation Strategy**
1.  **Piecewise Exponential Generation:**
    *   Period 1 (0-6 months): HR = 1.0
    *   Period 2 (>6 months): HR = 0.5
2.  **Analysis Comparison:**
    *   **Cox:** Will yield low power.
    *   **RMST (Restricted Mean Survival Time):** Measures "Area under the KM curve" up to time $t$. Robust to crossing.
    *   **Weighted Log-Rank:** MaxCombo tests.

### **R Tools for Non-PH**
* `simsurv`: Excellent package for complex survival data generation.
* `survRM2::rmst2`: Calculates difference in mean survival time.

```r
# Example: Generating Delayed Effect
# Use a custom function to generate time T based on hazard function h(t)
# T = InverseH( -log(U) ) where U ~ Uniform(0,1)
```
