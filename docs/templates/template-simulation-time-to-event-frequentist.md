> **Parent Document:** [SOP: Frequentist Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-frequentist-analysis.md)

**Below is a R-centric framework** for **simulation-based design of clinical trials with Time-to-Event (TTE) outcomes** using Frequentist methods (Cox Model, Log-Rank).

---

## **1. Core Concepts**

* **Hazard Ratio (HR):** The primary effect measure (Assumes Proportional Hazards).
* **Events Driven:** Power depends on the number of *events*, not just patients.
* **Log-Rank Test:** The standard non-parametric test for equality of survival curves.
* **Cox Proportional Hazards:** Semi-parametric model for adjusting covariates.

---

## **2. Standard Frequentist Simulation**

Simulates a trial assuming exponential survival times (constant hazard) and analyzing via Cox regression.

### **R Code**

```r
library(survival)
library(broom)
library(dplyr)

simulate_tte_frequentist <- function(n_per_arm, 
                                     HR_true,       # Hazard Ratio (e.g., 0.7)
                                     lambda_ctrl,   # Baseline hazard rate
                                     censor_rate = 0.05) {
  
  n_total <- n_per_arm * 2
  arm <- c(rep(0, n_per_arm), rep(1, n_per_arm))
  
  # A. Generate Survival Times (Exponential)
  # h(t) = lambda * exp(beta * arm)
  rate <- lambda_ctrl * exp(log(HR_true) * arm)
  T_event <- rexp(n_total, rate = rate)
  
  # B. Generate Censoring
  T_censor <- rexp(n_total, rate = censor_rate)
  
  # C. Create Observed Data
  time <- pmin(T_event, T_censor)
  status <- as.numeric(T_event <= T_censor) # 1=Event
  
  data <- data.frame(time, status, arm)
  
  # D. Analysis: Cox Proportional Hazards Model
  fit <- coxph(Surv(time, status) ~ arm, data = data)
  
  res <- tidy(fit)
  
  # Output
  return(data.frame(
    est_log_HR = res$estimate,
    HR = exp(res$estimate),
    p_value = res$p.value,
    significant = res$p.value < 0.05,
    events = sum(status)
  ))
}

# --- Execution ---
# set.seed(42)
# results <- bind_rows(replicate(500, simulate_tte_frequentist(100, 0.7, 0.1), simplify=FALSE))
# power <- mean(results$significant)
```
