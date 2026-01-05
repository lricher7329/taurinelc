### Practical R Simulation Template

Below is a modular R framework illustrating **Section 1 (Estimands)** and  **Section 2 (Baseline Sensitivity)** . It compares Risk Difference (RD), Risk Ratio (RR), and Odds Ratio (OR) while varying the baseline control rate.

**R**

```
library(dplyr)
library(broom)
library(ggplot2)

# --- 1. Simulation Function ---
simulate_binary_trial <- function(n_per_arm, p_control, true_OR) {
  
  # Calculate p_treatment based on Odds Ratio
  odds_control <- p_control / (1 - p_control)
  odds_treat   <- odds_control * true_OR
  p_treat      <- odds_treat / (1 + odds_treat)
  
  # Generate Data
  data <- data.frame(
    arm = c(rep("Control", n_per_arm), rep("Treatment", n_per_arm)),
    y   = c(rbinom(n_per_arm, 1, p_control), rbinom(n_per_arm, 1, p_treat))
  )
  
  # --- Model 1: Logistic Regression (Estimand: Odds Ratio) ---
  # Good for: Mathematical stability, covariate adjustment
  fit_logit <- glm(y ~ arm, data = data, family = binomial(link = "logit"))
  res_logit <- tidy(fit_logit) %>% filter(term == "armTreatment")
  
  # --- Model 2: Linear Probability Model (Estimand: Risk Difference) ---
  # Good for: Interpretability (absolute risk), biologically relevant
  # Note: Uses robust SE (sandwich) to handle heteroscedasticity of binary data
  fit_linear <- lm(y ~ arm, data = data) # OLS
  # In full sim, add robust SE calculation here (e.g., lmtest::coeftest)
  res_linear <- tidy(fit_linear) %>% filter(term == "armTreatment")
  
  return(list(
    p_val_OR = res_logit$p.value,
    est_OR   = exp(res_logit$estimate),
    p_val_RD = res_linear$p.value,
    est_RD   = res_linear$estimate,
    true_RD  = p_treat - p_control
  ))
}

# --- 2. Execution Loop (Monte Carlo) ---
run_simulation_grid <- function(n_sims = 500) {
  
  # Design Space: Varying Baseline Risk to see sensitivity
  scenarios <- expand.grid(
    n_per_arm = 200,
    p_control = seq(0.1, 0.5, by = 0.1), # 10% to 50% baseline risk
    true_OR   = 0.6                      # Constant Relative Effect
  )
  
  results <- list()
  
  for(i in 1:nrow(scenarios)) {
    scn <- scenarios[i,]
    sim_out <- replicate(n_sims, simulate_binary_trial(scn$n_per_arm, scn$p_control, scn$true_OR), simplify = FALSE)
    sim_df  <- bind_rows(sim_out)
  
    # Calculate Power (Freq of p < 0.05)
    power_OR <- mean(sim_df$p_val_OR < 0.05)
    power_RD <- mean(sim_df$p_val_RD < 0.05)
  
    results[[i]] <- data.frame(scn, power_OR, power_RD)
  }
  
  return(bind_rows(results))
}

# --- 3. Run & Visualize ---
# set.seed(123)
# sim_results <- run_simulation_grid(n_sims = 1000)

# Visualization Code (Mockup)
# ggplot(sim_results, aes(x = p_control)) +
#   geom_line(aes(y = power_OR, color = "Logit (OR)")) +
#   geom_line(aes(y = power_RD, color = "Linear (RD)")) +
#   labs(title = "Power Sensitivity to Baseline Event Rate",
#        y = "Power", x = "Control Event Rate")
```

### Key Takeaways from the Code:

1. **Effect Scale matters:** Notice how `true_OR` is constant (0.6), but as `p_control` moves from 0.1 to 0.5, the absolute `Risk Difference` changes. This changes the power of the RD analysis significantly.
2. **Model Choice:** The code sets up a direct comparison between Logistic (OR) and Linear (RD) models on the  *exact same datasets* .

Here is the extension of the simulation framework to include  **Bayesian methods** .

In rare event scenarios, Bayesian analysis with **weakly informative priors** is often considered the gold standard. It solves the separation problem (zero events) naturally: the prior provides the "extra information" needed to stabilize the estimate, similar to how Firth's penalty works mathematically, but with more transparency and flexibility.

This simulation compares three approaches on the same datasets:

1. **MLE (Standard GLM)** – The baseline (prone to failure).
2. **Firth (Penalized Likelihood)** – The frequentist fix.
3. **Bayesian (Weakly Informative Priors)** – The probabilistic solution.

### R Simulation: Bayesian vs. Frequentist for Rare Events

**Note:** This simulation uses `rstanarm` for speed and ease of use. It is a pre-compiled wrapper for Stan, perfect for standard regression models.

**R**

```
# Load necessary libraries
# install.packages(c("brglm2", "rstanarm", "dplyr", "ggplot2", "tidyr"))
library(dplyr)
library(brglm2)   # Firth
library(rstanarm) # Bayesian GLM
library(ggplot2)
library(tidyr)

# Set multicore processing for Stan (speeds up sims)
options(mc.cores = parallel::detectCores())

# --- 1. Simulation Worker Function ---
simulate_bayesian_comparison <- function(n_per_arm, p_control, true_OR, sim_id) {
  
  # Setup parameters
  odds_control <- p_control / (1 - p_control)
  odds_treat   <- odds_control * true_OR
  p_treat      <- odds_treat / (1 + odds_treat)
  true_log_OR  <- log(true_OR)
  
  # Generate Data
  data <- data.frame(
    arm = factor(c(rep("Control", n_per_arm), rep("Treatment", n_per_arm)), 
                 levels = c("Control", "Treatment")),
    y   = c(rbinom(n_per_arm, 1, p_control), rbinom(n_per_arm, 1, p_treat))
  )
  
  # Check for Separation (Zero events in one arm)
  events_ctrl <- sum(data$y[data$arm == "Control"])
  events_trt  <- sum(data$y[data$arm == "Treatment"])
  has_separation <- (events_ctrl == 0 | events_trt == 0)
  
  # --- Model A: Firth (Frequentist Benchmark) ---
  fit_firth <- glm(y ~ arm, data = data, family = binomial(link = "logit"), method = "brglmFit")
  est_firth <- coef(fit_firth)["armTreatment"]
  se_firth  <- summary(fit_firth)$coefficients["armTreatment", "Std. Error"]
  
  # --- Model B: Bayesian (Weakly Informative Prior) ---
  # Prior: Normal(0, 2.5) on the Log-OR. 
  # Interpretation: We are 95% sure the OR is between exp(-5) and exp(5) (0.006 to 148).
  # This is "weakly informative" - it rules out impossible effects (OR=1,000,000) but allows strong ones.
  
  # We use 'stan_glm' with 'mean_field' algorithm for simulation speed 
  # (Full MCMC is better for final analysis but too slow for 1000s of sims)
  fit_bayes <- suppressWarnings(stan_glm(y ~ arm, data = data, 
                                         family = binomial(link = "logit"),
                                         prior = normal(location = 0, scale = 2.5),
                                         prior_intercept = normal(0, 5),
                                         algorithm = "meanfield", 
                                         iter = 2000, 
                                         refresh = 0))
  
  bayes_summary <- summary(fit_bayes, pars = "armTreatment", probs = c(0.025, 0.975))
  est_bayes     <- bayes_summary[1, "mean"] # Posterior Mean
  ci_lower      <- bayes_summary[1, "2.5%"]
  ci_upper      <- bayes_summary[1, "97.5%"]
  
  # Calculate if CI covers the true value
  covered <- (true_log_OR >= ci_lower & true_log_OR <= ci_upper)
  
  return(data.frame(
    sim_id = sim_id,
    has_separation = has_separation,
    true_log_OR = true_log_OR,
    est_firth = est_firth,
    est_bayes = est_bayes,
    bayes_covered = covered
  ))
}

# --- 2. Run Simulation Loop ---
# We use a smaller number of sims (e.g., 50-100) here because Bayesian sampling is slower
run_bayes_sim <- function(n_sims = 50) {
  
  results_list <- lapply(1:n_sims, function(i) {
    # Print progress every 10 iterations
    if(i %% 10 == 0) message(paste("Simulating iteration:", i))
  
    # Scenario: High separation risk (N=40, p=0.05, OR=0.5)
    simulate_bayesian_comparison(n_per_arm = 40, p_control = 0.05, true_OR = 0.5, sim_id = i)
  })
  
  bind_rows(results_list)
}

# Run (expect this to take 1-2 mins depending on CPU)
# set.seed(2024)
# sim_results_bayes <- run_bayes_sim(n_sims = 50)

# --- 3. Analysis & Visualization ---

# (Mockup analysis for demonstration)
# sim_results_bayes <- sim_results_bayes %>%
#   mutate(
#     bias_firth = est_firth - true_log_OR,
#     bias_bayes = est_bayes - true_log_OR
#   )

# summary_stats <- sim_results_bayes %>%
#   summarise(
#     avg_bias_firth = mean(bias_firth),
#     avg_bias_bayes = mean(bias_bayes),
#     mse_firth = mean(bias_firth^2),
#     mse_bayes = mean(bias_bayes^2),
#     bayes_coverage = mean(bayes_covered) # Should be near 0.95
#   )

# print(summary_stats)

# Visualizing the Shrinkage
# When separation happens, Firth and Bayes both "shrink" the estimate.
# Bayes often shrinks slightly more aggressively depending on the prior scale.
```

### 4. Key Conceptual Differences for the Designer

When you present this to a clinical team, here is the narrative for choosing between methods:

#### **A. The Firth Approach (Penalized Likelihood)**

* **What it does:** Adds a "penalty" to the likelihood equation that equals adding 0.5 observations to each cell (heuristically).
* **Pros:** It is still "Frequentist." It produces p-values and confidence intervals that regulators are comfortable with. It is computationally instant.
* **Cons:** It is a "black box" fix. You cannot easily inject prior knowledge (e.g., "we know the event rate won't exceed 20%").

#### **B. The Bayesian Approach (Weakly Informative Priors)**

* **What it does:** You mathematically state: *"Before the trial starts, I believe the treatment effect is likely small (between 0.1 and 10), and impossible to be infinite."*
* **Pros:**
  * **Transparency:** You explicitly state your assumptions.
  * **Interpretability:** You get a probability of benefit (e.g., "There is a 96% probability the drug works"), which is much more intuitive for clinicians than a p-value.
  * **Stability:** The prior acts as an anchor. In a "zero event" arm, the estimate doesn't float away; it stays tethered to the prior.
* **Cons:** Requires more computational time and explanation to stakeholders unfamiliar with Bayesian logic.

### 5. Advanced Note: The "Cauchy" vs. "Normal" Prior

In the code above, I used `normal(0, 2.5)`.

* **Normal Prior:** Has "thin tails." It is skeptical of very large effects. It shrinks estimates strongly toward zero.
* **Cauchy Prior:** Has "fat tails." It concentrates mass around zero (skeptical of small noise) but allows occasional massive effects to pass through.

**Design Tip:** For clinical trials, a **Normal** prior is usually preferred for the treatment effect because we genuinely do not expect "miracle cures" (infinite odds ratios). The Cauchy prior can sometimes result in estimates that remain too unstable in small samples.

Would you like to extend this to an "Interim Analysis" scenario?

I can add a module to simulate a "futility stop" at 50% enrollment using the Bayesian posterior probability (e.g., Stop if Prob(Benefit) < 20%).

This is a critical extension. Standard logistic regression relies on Maximum Likelihood Estimation (MLE), which breaks down in two specific ways when event counts are low (rule of thumb: < 10-20 events total):

1. **Complete Separation:** If one arm has zero events, the MLE for the Odds Ratio (OR) is **$0$** or **$\infty$**. In R, `glm()` outputs a massive coefficient (e.g., **$\pm 20$**) and a massive standard error, destroying hypothesis tests.
2. **Small-Sample Bias:** Even if the model converges, MLE systematically overestimates effect sizes (away from the null) in small samples.

**Firth’s Penalized Likelihood (`brglm2`)** solves both by introducing a penalty term into the likelihood function (Jeffreys prior), pulling estimates back toward realistic values and ensuring finite estimates even with zero events.

Here is the refined R simulation template comparing Standard GLM vs. Firth.

### R Simulation: Rare Events and Separation

**R**

```
# Load necessary libraries
# install.packages(c("brglm2", "dplyr", "ggplot2", "tidyr"))
library(dplyr)
library(brglm2)  # For Firth's penalized likelihood
library(ggplot2)
library(tidyr)

# --- 1. Simulation Worker Function ---
simulate_rare_events <- function(n_per_arm, p_control, true_OR, sim_id) {
  
  # Calculate p_treatment from Odds Ratio
  odds_control <- p_control / (1 - p_control)
  odds_treat   <- odds_control * true_OR
  p_treat      <- odds_treat / (1 + odds_treat)
  true_log_OR  <- log(true_OR)
  
  # Generate Data
  # We intentionally use small N and low p to trigger separation often
  data <- data.frame(
    arm = factor(c(rep("Control", n_per_arm), rep("Treatment", n_per_arm)), 
                 levels = c("Control", "Treatment")),
    y   = c(rbinom(n_per_arm, 1, p_control), rbinom(n_per_arm, 1, p_treat))
  )
  
  # Check event counts (Diagnostics)
  events_ctrl <- sum(data$y[data$arm == "Control"])
  events_trt  <- sum(data$y[data$arm == "Treatment"])
  has_separation <- (events_ctrl == 0 | events_trt == 0 | 
                     events_ctrl == n_per_arm | events_trt == n_per_arm)
  
  # --- Model A: Standard Logistic Regression (MLE) ---
  # We wrap in tryCatch because severe separation can sometimes cause errors
  fit_mle <- tryCatch({
    glm(y ~ arm, data = data, family = binomial(link = "logit"))
  }, warning = function(w) NULL, error = function(e) NULL)
  
  if(!is.null(fit_mle)) {
    coef_mle <- coef(fit_mle)["armTreatment"]
    se_mle   <- summary(fit_mle)$coefficients["armTreatment", "Std. Error"]
  } else {
    coef_mle <- NA; se_mle <- NA
  }
  
  # --- Model B: Firth's Penalized Likelihood (brglm2) ---
  # method = "brglmFit" activates the Firth correction
  fit_firth <- tryCatch({
    glm(y ~ arm, data = data, family = binomial(link = "logit"), method = "brglmFit")
  }, error = function(e) NULL)
  
  if(!is.null(fit_firth)) {
    coef_firth <- coef(fit_firth)["armTreatment"]
    se_firth   <- summary(fit_firth)$coefficients["armTreatment", "Std. Error"]
  } else {
    coef_firth <- NA; se_firth <- NA
  }
  
  return(data.frame(
    sim_id = sim_id,
    events_total = events_ctrl + events_trt,
    has_separation = has_separation,
    true_log_OR = true_log_OR,
    est_log_OR_mle = coef_mle,
    se_mle = se_mle,
    est_log_OR_firth = coef_firth,
    se_firth = se_firth
  ))
}

# --- 2. Run Grid Simulation ---
run_rare_event_sim <- function(n_sims = 500) {
  
  # Scenario: 50 patients/arm, 5% control risk, OR = 0.5
  # Expected events: ~2.5 in Control, ~1.2 in Treatment
  # High probability of ZERO events in Treatment arm (Separation)
  
  results_list <- lapply(1:n_sims, function(i) {
    simulate_rare_events(n_per_arm = 50, p_control = 0.05, true_OR = 0.5, sim_id = i)
  })
  
  bind_rows(results_list)
}

# Run the simulation
set.seed(42)
sim_data <- run_rare_event_sim(n_sims = 1000)

# --- 3. Analysis of Results ---

# A. Identification of "Exploded" Estimates
# Standard MLE estimates often go to +/- 20 when separation occurs.
# We define "Unstable" as abs(logOR) > 10 (which is an OR of ~22,000 or 0.00004)
sim_data <- sim_data %>%
  mutate(
    mle_exploded = abs(est_log_OR_mle) > 10,
    firth_exploded = abs(est_log_OR_firth) > 10
  )

# B. Summary Statistics
summary_stats <- sim_data %>%
  summarise(
    separation_rate = mean(has_separation),
    mle_failure_rate = mean(mle_exploded, na.rm=TRUE),
    firth_failure_rate = mean(firth_exploded, na.rm=TRUE),
  
    # Bias (excluding exploded MLEs to be charitable to MLE, 
    # though in reality, those are failures)
    bias_mle_clean = mean(est_log_OR_mle[!mle_exploded] - true_log_OR[1], na.rm=TRUE),
    bias_firth_all = mean(est_log_OR_firth - true_log_OR[1], na.rm=TRUE)
  )

print("--- Simulation Summary ---")
print(summary_stats)

# --- 4. Visualization ---
# We pivot to long format to compare distributions of estimates
plot_data <- sim_data %>%
  filter(!mle_exploded) %>% # Remove MLE explosions for readability of the plot
  select(sim_id, MLE = est_log_OR_mle, Firth = est_log_OR_firth, True = true_log_OR) %>%
  pivot_longer(cols = c("MLE", "Firth"), names_to = "Method", values_to = "Estimate")

ggplot(plot_data, aes(x = Estimate, fill = Method)) +
  geom_density(alpha = 0.5) +
  geom_vline(aes(xintercept = True), linetype="dashed", size=1) +
  labs(
    title = "Stability of Estimates in Rare Event Settings",
    subtitle = "Standard MLE vs Firth (brglm2) | N=50/arm, 5% Event Rate",
    x = "Estimated Log Odds Ratio",
    y = "Density"
  ) +
  theme_minimal()
```

### Interpretation of Results

When you run this simulation, you will observe distinct behaviors in the `summary_stats` and the plot:

**1. The "Explosion" Problem (Separation)**

* **Standard MLE:** In scenarios with separation (zero events in one arm), the MLE `est_log_OR_mle` will often be huge (e.g., -20 or -18). This mathematically represents negative infinity. The standard error (`se_mle`) will also be massive (e.g., 4000).
* **Firth:** Even when separation occurs, `est_log_OR_firth` remains finite (e.g., -2.5 or -3.0). It implicitly "adds" partial events to the empty cell.

**2. Bias (The subtle killer)**

* **Standard MLE:** Even when it doesn't explode (i.e., we filter out the separation cases), MLE is biased away from zero. If the true Log-OR is -0.69, MLE might average -0.80. It exaggerates the treatment effect.
* **Firth:** The bias (`bias_firth_all`) will be significantly closer to zero. It is designed to remove the first-order term of the asymptotic bias.

**3. Power Implications**

* Because Standard MLE produces inflated standard errors in low-count scenarios (the Hauck-Donner effect), the Wald test statistic (**$Est / SE$**) shrinks, causing a  **loss of power** . Firth restores the validity of the test statistic.

### Next Step

Would you like me to extend this rare-event framework to  **Bayesian priors** , showing how a "weakly informative prior" (e.g., Cauchy or Normal) in `rstanarm` or `brms` compares to the Firth correction?
