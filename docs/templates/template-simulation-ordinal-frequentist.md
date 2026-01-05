> **Parent Document:** [SOP: Bayesian Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-bayesian-analysis.md)

**Below is a ****frequentist, R-centric framework** for  **simulation-based design of clinical trials with an ordinal primary outcome** **. The structure mirrors the continuous-outcome case but highlights the ** **distinct statistical issues introduced by ordinality** **, nonlinearity, and link-function assumptions. Where relevant, I note ****R packages and modeling choices** commonly used in practice.


---

## **1. Choice of Estimand and Link Function**

### **Core Design Decision**

What treatment effect is being estimated?

Common frequentist estimands:

* **Common odds ratio** (proportional odds model)
* **Category-specific odds ratios**
* **Difference in cumulative probabilities**
* **Win probability / Mann–Whitney estimand**
* **Mean score difference** (less favored, but sometimes used)

### **Simulation Role**

* **Generate data under ****known cumulative logits**
* Fit alternative models to assess:
  * Bias of estimand
  * Interpretability
  * Power under misspecification

### **R Tools**

* MASS::polr
* ordinal::clm
* VGAM::vglm

---

## **2. Proportional Odds (PO) Assumption Violations**

### **Why It Matters**

The PO assumption is often violated in real trials but still widely used.

### **Simulation Scenarios**

* True proportional odds
* Mild non-proportionality
* Strong crossing effects (treatment helps some categories, harms others)

### **What You Learn**

* Type I error robustness
* Power loss under misspecification
* When partial PO models outperform PO

### **R Tools**

* ordinal::clm** with **nominal()** terms**
* **VGAM::vglm** (partial proportional odds)
* **brant** test (diagnostic, not design)

---

## **3. Category Collapse and Sparse Categories**

### **Design Issue**

Ordinal endpoints often have:

* Rare extreme categories
* Post-hoc category collapsing

### **Simulation Role**

* Vary number of categories (e.g., 3 vs 5 vs 7)
* Collapse categories *before* vs *after* analysis

### **Outputs**

* Power vs interpretability tradeoff
* Type I error inflation due to data-driven collapsing
* Stability of model convergence

### **R Tools**

* Custom data-generation code
* **clm()** convergence diagnostics

---

## **4. Distribution of Baseline Severity**

### **Why It Matters**

Power is highly sensitive to baseline category distribution.

### **Simulation Scenarios**

* Balanced baseline categories
* Skewed baseline (floor or ceiling effects)
* Treatment effect conditional on baseline severity

### **Key Outputs**

* Power stratified by baseline severity
* Impact of covariate adjustment

### **R Tools**

* simstudy
* **ordinal::clm** with baseline as predictor

---

## **5. Covariate Adjustment and Stratification**

### **Issues to Model**

* Ordinal baseline outcome adjustment
* Stratified randomization vs model adjustment
* Center effects (multicenter trials)

### **Simulation Outputs**

* Efficiency gains
* Bias under imbalance
* Robustness to misspecification

### **R Tools**

* clm(outcome ~ treatment + baseline)
* Random effects: **ordinal::clmm**

---

## **6. Non-Inferiority and Equivalence Designs**

### **Ordinal-Specific Challenge**

Defining non-inferiority margins is nontrivial.

### **Simulation Role**

* Evaluate power under:
  * OR-based margins
  * Category-specific probability differences
* Stress-test interpretability for regulators

### **Outputs**

* Empirical Type I error
* Power near the margin

---

## **7. Missing Data and Intercurrent Events**

### **Ordinal-Specific Issues**

* Dropout linked to worsening category
* Informative censoring
* Rescue therapy changing category distribution

### **Simulation Scenarios**

* MAR vs MNAR dropout
* Treatment-dependent missingness

### **Analysis Compared**

* Complete case
* Multiple imputation (ordinal models)
* Tipping-point analyses

### **R Tools**

* **mice** (ordinal methods)
* Pattern-mixture custom simulations

---

## **8. Longitudinal Ordinal Outcomes**

### **Common Use Cases**

* Functional scores
* Disease severity scales
* Repeated responder categories

### **Simulation Components**

* Transition probabilities between categories
* Latent continuous disease process mapped to ordinal scale

### **Models Evaluated**

* Mixed-effects cumulative logit models
* GEE for ordinal outcomes
* Markov transition models

### **R Tools**

* ordinal::clmm
* geepack
* **msm** or custom transition models

---

## **9. Competing Analyses: Ordinal Model vs Rank-Based Tests**

### **Why This Matters**

Regulatory submissions often include both.

### **Comparisons**

* Proportional odds model
* Wilcoxon–Mann–Whitney
* van Elteren (stratified rank test)

### **Simulation Outputs**

* Relative power
* Interpretability under non-PO scenarios
* Sensitivity to ties

### **R Tools**

* coin
* **survival::clogit** (for win-ratio variants)

---

## **10. Interim Analyses and Group Sequential Designs**

### **Challenges**

* Information fraction is not linear
* Test statistics are model-dependent

### **Simulation Role**

* Validate alpha spending
* Assess early stopping probabilities

### **R Tools**

* **gsDesign** (with simulation overlay)
* Custom Monte Carlo frameworks

---

## **11. Estimator Stability and Convergence Failures**

### **Common Problems**

* Separation
* Sparse categories
* Non-convergence at interim looks

### **Simulation Role**

* Quantify convergence failure rates
* Compare penalized vs standard likelihood

### **R Tools**

* brglm2
* **ordinal::clm** with control options

---

## **12. Interpretation and Clinical Meaningfulness**

### **Design-Stage Questions**

* How often does treatment produce a  *clinically meaningful shift* ?
* Is the effect driven by a single category?

### **Simulation Outputs**

* Probability of ≥1-category improvement
* Shift plots (distributional effects)
* Number needed to treat (ordinal analogs)

---

## **Recommended Simulation Outputs for Ordinal Trials**

Across scenarios, report:

* Power
* Type I error
* Bias of log-OR or chosen estimand
* CI coverage
* Convergence failure rates
* Probability of clinically meaningful improvement

---

## **Summary Table (Condensed)**

| **Issue**        | **Why Simulate**        |
| ---------------------- | ----------------------------- |
| Proportional odds      | Assumption often violated     |
| Baseline distribution  | Strong power driver           |
| Category sparsity      | Convergence + bias            |
| Missingness            | Informative in ordinal scales |
| Longitudinal structure | Nonlinear information gain    |
| Estimand choice        | Interpretability & robustness |

---

## **Bottom Line**

For ordinal outcomes, **simulation is not optional**. It is essential to:

* Justify the proportional odds model (or alternatives)
* Demonstrate robustness to baseline imbalance and category sparsity
* Support regulatory defensibility of the estimand

If you would like, I can:

* Provide a **minimal R simulation template** for a proportional odds trial
* **Show how to ****simulate PO violations explicitly**
* **Create a ****regulatory-ready simulation summary table**
* **Compare ****ordinal vs dichotomized power loss** in your context


This is a very strong foundation. To update this for modern clinical development—particularly in light of recent major trials (e.g., COVID-19 ordinal scales, cardiology composite scores)—we need to add  **Win Statistics** ,  **Hierarchical Composites** , and  **Quantifying the Cost of Dichotomization** .

Here are **5 Advanced Extensions** to your framework, followed by an **R Simulation Template** focusing on the critical design risk:  *Violating the Proportional Odds Assumption* .

---

### 13. The "Win Ratio" and Hierarchical Composites

Why It Matters

Traditional ordinal models (POM) struggle when the ordinal scale includes a terminal event (Death) alongside functional status. The "Win Ratio" (Finkelstein-Schoenfeld method) is increasingly preferred by regulators for these "hierarchical" outcomes.

**Simulation Scenarios**

* **Hierarchical Logic:** Compare every patient in Arm A to Arm B.
  1. Did one die and the other survive? -> Winner.
  2. If both survived, who had the better ordinal score? -> Winner.
* **Tie-breaking:** What if scores are equal? (Ignore vs. use a continuous tie-breaker).

**Outputs**

* **Win Ratio:** (Wins / Losses).
* **Win Probability:** P(Treatment > Control).
* **Power:** Comparison of Win Ratio test vs. Proportional Odds Model.

**R Tools**

* `WinRatio`
* `survival` (Cox model on the "win" construct)

### 14. Quantifying the "Cost of Dichotomization"

Design Question

Clinicians often want to collapse the ordinal scale to Binary (e.g., "Responder" vs "Non-Responder") for simplicity. Statisticians know this destroys power. Simulation can quantify this loss to defend the ordinal design.

**Simulation Goals**

* Calculate the **Effective Sample Size (ESS)** loss. (e.g., "Collapsing this 5-point scale to binary is mathematically equivalent to throwing away 35% of our patients.")
* Robustness check: Does binary analysis actually perform *better* if the treatment effect is concentrated entirely at that specific cut-point?

### 15. The "Location-Scale" Model (Simulating Non-PO)

Why It Matters

The Proportional Odds (PO) assumption implies the treatment shifts the mean of the latent distribution but not the variance. If a treatment makes patients variable (some get much better, some get worse), PO fails.

**Simulation Scenarios**

* **Location Shift:** Standard treatment effect.
* **Scale Shift:** Treatment increases variance (heterogeneity).
* **Result:** The odds ratios are not constant across cut-points.

**R Tools**

* `ordinal::clm(..., scale = ~arm)` (Allows modeling the variance explicitly).

### 16. Bayesian Ordinal Models with Dirichlet Priors

Why It Matters

In small trials, empty categories cause convergence failure. Bayesian models with "Dirichlet priors" on the cut-points smooth the distribution, preventing the model from crashing even with zero counts in some buckets.

**Simulation Scenarios**

* Compare Frequentist `clm` convergence failures vs. Bayesian `brm` posterior stability in N < 100 trials.

### 17. Longitudinal Multi-State Transitions

Why It Matters

Instead of treating "Day 28 Score" as a static outcome, model the journey.

**Simulation Scenarios**

* **Transitions:** State A (Hospital) -> State B (ICU) -> State C (Recovery).
* **Time-to-Event:** Time to improvement by 2 categories.

**R Tools**

* `mstate`

---

### Practical R Simulation Template

This template addresses the #1 Risk in Ordinal Trials: The Proportional Odds (PO) Assumption.

It generates data using a "Latent Variable" approach (the most physically realistic way to simulate ordinal data) and compares three analysis methods:

1. **Proportional Odds Model (The standard)**
2. **Wilcoxon Rank Sum (The robust nonparametric)**
3. **Binary Logistic (The "Dichotomizer")**

**R**

```
library(ordinal)
library(dplyr)
library(broom)
library(ggplot2)

# --- 1. Simulation Function: Latent Variable Approach ---
simulate_ordinal_trial <- function(n_per_arm, 
                                   effect_location, # Shift in Mean (Standard Effect)
                                   effect_scale    # Shift in SD (Non-PO Effect)
                                   ) {
  
  # A. Generate Latent Continuous Outcome (Z)
  # Control: Normal(0, 1)
  # Treatment: Normal(mean = effect_location, sd = exp(effect_scale))
  # If effect_scale != 0, the variance differs, creating Non-Proportional Odds.
  
  z_control <- rnorm(n_per_arm, mean = 0, sd = 1)
  z_treat   <- rnorm(n_per_arm, mean = effect_location, sd = exp(effect_scale))
  
  # B. Discretize into Ordinal Categories (e.g., 4-point scale)
  # We define "cuts" on the latent variable to create bucket probabilities
  cuts <- c(-Inf, -0.8, 0.2, 1.2, Inf) 
  
  data <- data.frame(
    arm = c(rep("Control", n_per_arm), rep("Treatment", n_per_arm)),
    z_latent = c(z_control, z_treat)
  ) %>%
    mutate(
      # Cut the latent variable into 1, 2, 3, 4
      y_ord = as.factor(as.numeric(cut(z_latent, breaks = cuts))),
      # Create a Binary version (e.g., Success = Score 3 or 4)
      y_bin = as.numeric(y_ord) > 2
    )
  
  # --- Analysis 1: Proportional Odds Model (CLM) ---
  # We use tryCatch to handle non-convergence in small samples
  fit_pom <- tryCatch({
    clm(y_ord ~ arm, data = data)
  }, error = function(e) NULL)
  
  p_pom <- if(!is.null(fit_pom)) summary(fit_pom)$coefficients["armTreatment", "Pr(>|z|)"] else NA
  
  # --- Analysis 2: Wilcoxon Rank Sum (Non-parametric) ---
  # Robust to PO violations, but tests a different hypothesis (stochastic dominance)
  test_wilcox <- wilcox.test(as.numeric(y_ord) ~ arm, data = data)
  p_wilcox <- test_wilcox$p.value
  
  # --- Analysis 3: Dichotomized Logistic Regression ---
  # The "Cost of Dichotomization" check
  fit_bin <- glm(y_bin ~ arm, data = data, family = binomial)
  p_bin <- tidy(fit_bin) %>% filter(term == "armTreatment") %>% pull(p.value)
  
  return(data.frame(
    p_pom = p_pom,
    p_wilcox = p_wilcox,
    p_bin = p_bin
  ))
}

# --- 2. Execution Loop (Monte Carlo) ---
run_ordinal_sim <- function(n_sims = 500) {
  
  # Scenario A: Ideal Proportional Odds (Mean shift only)
  print("Simulating Scenario A: Proportional Odds Holds...")
  res_po <- bind_rows(replicate(n_sims, simulate_ordinal_trial(100, 0.5, 0), simplify = FALSE)) %>%
    mutate(Scenario = "PO Holds (Location Shift)")
  
  # Scenario B: Violation (Treatment improves Mean but increases Variance)
  # This represents a drug that helps some but makes others unstable.
  # The PO model assumes constant variance, so it may lose power or bias here.
  print("Simulating Scenario B: PO Violation (Location + Scale Shift)...")
  res_non_po <- bind_rows(replicate(n_sims, simulate_ordinal_trial(100, 0.5, 0.6), simplify = FALSE)) %>%
    mutate(Scenario = "PO Violated (Heterogeneity)")
  
  bind_rows(res_po, res_non_po)
}

# --- 3. Run & Visualize ---
# set.seed(123)
# results <- run_ordinal_sim(n_sims = 1000)

# Calculate Power
# summary_table <- results %>%
#   group_by(Scenario) %>%
#   summarise(
#     Power_POM = mean(p_pom < 0.05, na.rm=TRUE),
#     Power_Wilcox = mean(p_wilcox < 0.05, na.rm=TRUE),
#     Power_Binary = mean(p_bin < 0.05, na.rm=TRUE)
#   )

# print(summary_table)

# Visualizing the "Cost of Dichotomization"
# ggplot(results, aes(x = p_pom, y = p_bin)) +
#   geom_point(alpha = 0.2) +
#   geom_abline(color = "red") +
#   facet_wrap(~Scenario) +
#   labs(title = "P-value Correlation: Ordinal vs. Binary",
#        x = "Ordinal P-value (More Power)", y = "Binary P-value (Less Power)")
```

### What This Simulation Reveals

1. The Cost of Dichotomization:
   You will likely see that Power_Binary is significantly lower (e.g., 60%) compared to Power_POM (e.g., 80%) in the "PO Holds" scenario.  This is the "gold dust" for convincing clinicians to keep the ordinal scale.
2. Robustness to PO Violation:
   In Scenario B (Heterogeneity), the Proportional Odds model (clm) estimates a "common" odds ratio that doesn't actually exist.
   * The **Wilcoxon test** often maintains better power and validity here because it tests "stochastic dominance" (is one distribution generally higher?) rather than a specific parametric shape.

### Recommended Next Step

Would you like me to extend the code to include a  **Visual Diagnostic of the PO Assumption** ? I can write a function that plots the "Log-Odds of Cumulative Probabilities" for each cut-point to visually demonstrate (to a study team) what a "crossing hazard" or "PO violation" actually looks like.



Here is the extension to the simulation framework.

In clinical trial design, formal statistical tests for the Proportional Odds (PO) assumption (like the Brant test) are often criticized because they are too sensitive in large samples (rejecting trivial deviations) and underpowered in small samples.

**Visual diagnostics are superior.** They tell you *where* the assumption fails (e.g., "The treatment helps prevent Death (Cut 1) but has no effect on quality of life (Cut 4)").

### The Logic of the Diagnostic

Under the Proportional Odds assumption:

$$
\text{logit}(P(Y \ge k | \text{Treat})) - \text{logit}(P(Y \ge k | \text{Control})) = \text{Constant (Log OR)}
$$

If you plot the Empirical Log-Odds of the cumulative probabilities for both arms across the categories:

* **PO Holds:** The two lines should be roughly  **parallel** .
* **PO Violated:** The lines will  **cross** , converge, or diverge.

### R Code: Visual Diagnostic of the PO Assumption

This code simulates two scenarios (Ideal vs. Violated) and generates a diagnostic plot for each side-by-side.

**R**

```
library(dplyr)
library(ggplot2)
library(tidyr)
library(patchwork) # For side-by-side plots (install if needed)

# --- 1. Helper: Generate Large Dataset for Clean Diagnostics ---
# We use a larger N here (1000) just to make the diagnostic plots smooth 
# and free of sampling noise, so the "true" shape is visible.
generate_diagnostic_data <- function(n, shift_mean, shift_sd_scale) {
  
  # Latent Variable Generation
  z_control <- rnorm(n, mean = 0, sd = 1)
  # If shift_sd_scale != 0, we change the variance (Scale shift) -> PO Violation
  z_treat   <- rnorm(n, mean = shift_mean, sd = exp(shift_sd_scale)) 
  
  # Cuts for a 5-point scale (0 to 4)
  cuts <- c(-Inf, -1.5, -0.5, 0.5, 1.5, Inf)
  
  data.frame(
    arm = c(rep("Control", n), rep("Treatment", n)),
    z_latent = c(z_control, z_treat)
  ) %>%
    mutate(
      y_ord = as.numeric(cut(z_latent, breaks = cuts)) # 1,2,3,4,5
    )
}

# --- 2. Helper: Calculate Empirical Log-Odds ---
calc_empirical_logits <- function(data) {
  # Get max category
  k_max <- max(data$y_ord)
  
  # We look at P(Y >= k) for k = 2 to k_max
  # (Standard PO model formulation usually looks at cumulative probabilities)
  results <- list()
  
  for(k in 2:k_max) {
    summary_k <- data %>%
      group_by(arm) %>%
      summarise(
        n_total = n(),
        # Count how many are >= k
        n_ge_k = sum(y_ord >= k),
        prop_ge_k = n_ge_k / n_total,
        # Avoid log(0) or log(1) with small corrections if needed
        # Logit = log(p / 1-p)
        logit = log(prop_ge_k / (1 - prop_ge_k))
      ) %>%
      mutate(cutpoint = paste0(">=", k-1)) # Label for the x-axis
    
    results[[k]] <- summary_k
  }
  
  bind_rows(results)
}

# --- 3. Wrapper: Simulate and Plot ---
visualize_po_assumption <- function() {
  
  # --- Scenario A: PO Holds (Parallel Lines) ---
  # Treatment shifts mean by 0.8, Variance is same (Scale = 0)
  data_ideal <- generate_diagnostic_data(n = 2000, shift_mean = 0.8, shift_sd_scale = 0)
  logits_ideal <- calc_empirical_logits(data_ideal)
  
  p1 <- ggplot(logits_ideal, aes(x = cutpoint, y = logit, group = arm, color = arm)) +
    geom_line(size = 1.2) +
    geom_point(size = 3) +
    labs(title = "Scenario A: PO Holds",
         subtitle = "Lines are roughly parallel (Constant shift)",
         y = "Log-Odds of Cumulative Probability",
         x = "Ordinal Cutpoint") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # --- Scenario B: PO Violated (Non-Parallel / Crossing) ---
  # Treatment shifts mean by 0.8, BUT also increases Variance (Scale = 0.8)
  # This creates "Crossing Hazards"
  data_violated <- generate_diagnostic_data(n = 2000, shift_mean = 0.8, shift_sd_scale = 0.8)
  logits_violated <- calc_empirical_logits(data_violated)
  
  p2 <- ggplot(logits_violated, aes(x = cutpoint, y = logit, group = arm, color = arm)) +
    geom_line(size = 1.2) +
    geom_point(size = 3) +
    labs(title = "Scenario B: PO Violated",
         subtitle = "Lines converge/cross (Variance shift)",
         y = "", # Hide Y label for second plot
         x = "Ordinal Cutpoint") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Return side-by-side plot
  return(p1 + p2)
}

# --- Execute ---
# Note: Requires 'patchwork' package for the '+' syntax
# If not installed, just print p1 and p2 separately.
visualize_po_assumption()
```

### How to Read the Plots

1. **Scenario A (Left Plot - Ideal):**
   * You will see two lines that rise (or fall) together.
   * The vertical distance between the red line and the blue line is constant at every cut-point.
   * **Conclusion:** A single Odds Ratio (e.g., OR = 2.0) accurately summarizes the treatment effect across the entire scale.
2. **Scenario B (Right Plot - Violated):**
   * You will likely see the lines **converging** or even  **crossing** .
   * Example: At the lower end (Severe disease), the lines are far apart (Treatment prevents death). At the higher end (Mild disease), the lines touch or cross (Treatment makes mild patients more variable, perhaps pushing some to "Full Recovery" and others to "Moderate," confusing the cumulative order).
   * **Conclusion:** Reporting a single OR is misleading. You should consider a **Partial Proportional Odds model** (letting the effect vary by cut-point) or the **Wilcoxon/Win Ratio** approach.

### Next Step in the Design Process

If your simulation (Scenario B) reveals that your treatment mechanism might cause these crossed lines, the immediate next step is to  **calculate the power loss** .

I can extend the simulation to answer: *"If the lines cross like this, how much power do we lose by stubbornly using the Proportional Odds model vs. switching to a Win Ratio?"*
