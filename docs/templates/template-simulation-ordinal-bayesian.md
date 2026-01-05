> **Parent Document:** [SOP: Bayesian Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-bayesian-analysis.md)

**Below is a Bayesian, R-centric framework** for **simulation-based design of clinical trials with an ordinal primary outcome**. It uses the **Bayesian Proportional Odds Model (Cumulative Logit)**.

---

## **1. choice of Model**

### **Core Design Question**
How do we model ordered categories (e.g., 1=Death, 2=Severe, 3=Mild, 4=Cured)?

*   **Cumulative Logit (Proportional Odds):** Assumes treatment shifts the interpretation of "severity" uniformly.
*   **Adjacent Category Logit:** Better if categories are equidistant.

### **R Tools**
*   `brms::brm(family = cumulative("logit"))` - The gold standard in R.
*   `rstanarm::stan_polr`

---

## **2. Bayesian Ordinal Simulation Template**

This module simulates an ordinal trial and analyzes it using `brms`.

### **R Code**

```r
library(dplyr)
library(brms)

# Enable parallel processing
options(mc.cores = parallel::detectCores())

simulate_ordinal_bayesian <- function(n_per_arm, 
                                      effect_location, # Shift in Latent Mean
                                      prior_sd = 2.5) {
  
  # A. Generate Data (Latent Variable Approach)
  z_control <- rnorm(n_per_arm, mean = 0, sd = 1)
  z_treat   <- rnorm(n_per_arm, mean = effect_location, sd = 1)
  
  cuts <- c(-Inf, -0.8, 0.2, 1.2, Inf)
  
  data <- data.frame(
    arm = c(rep("Control", n_per_arm), rep("Treatment", n_per_arm)),
    z_latent = c(z_control, z_treat)
  ) %>%
    mutate(y_ord = as.ordered(as.numeric(cut(z_latent, breaks = cuts))))
  
  # B. Bayesian Analysis (Cumulative Logit)
  # Formula: y_ord ~ arm
  # Family: cumulative("logit") -> Proportional Odds
  
  fit <- brm(y_ord ~ arm, data = data, 
             family = cumulative("logit"),
             prior = set_prior(paste0("normal(0, ", prior_sd, ")"), class = "b"),
             chains = 1, iter = 1000, refresh = 0, backend = "rstan") # or "cmdstanr"
  
  # C. Decision Rule
  # Posterior samples of the 'armTreatment' coefficient
  # In brm(cumulative), a POSITIVE coefficient usually means HIGHER latent score (Better outcome)
  post_samples <- as_draws_matrix(fit)
  trt_effect   <- post_samples[, "b_armTreatment"]
  
  # Prob(Effect > 0)
  prob_success <- mean(trt_effect > 0)
  is_success   <- prob_success > 0.975
  
  return(data.frame(
    post_mean = mean(trt_effect),
    prob_success = prob_success,
    is_success = is_success
  ))
}

# --- Execution ---
# set.seed(123)
# results <- bind_rows(replicate(20, simulate_ordinal_bayesian(100, 0.5), simplify = FALSE))
```

---

## **3. Handling Empty Categories**

In frequentist `clm`, if a category has 0 patients, the model may crash or produce infinite SEs.
**Bayesian advantage:** The Dirichlet prior on the thresholds (cutpoints) smoothes the distribution, allowing stable estimation even with sparse data.

```r
# Customizing Priors for Thresholds
# prior = set_prior("dirichlet(1)", class = "Intercept")
```
