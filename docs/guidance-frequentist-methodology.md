# Frequentist Statistical Methodology Guidance

> **Related Documents:**
> * **Rules & Procedure:** [SOP: Frequentist Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-frequentist-analysis.md)
> * **Code Templates:** `docs/templates/`

---

## 1. Conceptual Framework: Hypothesis Testing and Error Control

This guidance outlines the principles for designing and analyzing clinical trials using **frequentist inference**. The core objective is to control the rate of erroneous conclusions in the long run.

### 1.1 Hypothesis Testing
Frequentist trials are designed to test a specific null hypothesis ($H_0$, typically "no effect") against an alternative ($H_1$).
* **P-value:** The probability of observing data as extreme as observed, assuming $H_0$ is true. It is **not** the probability that the hypothesis is true.
* **Confidence Intervals (CI):** An interval constructed such that, if the experiment were repeated many times, X% of the intervals would contain the true parameter.

### 1.2 Error Control Principles
Strict control of error rates is the regulatory requirement for confirmational trials.
* **Type I Error ($\alpha$):** The probability of falsely rejecting $H_0$ (false positive). Typically set at 2.5% (one-sided) or 5% (two-sided).
* **Type II Error ($\beta$):** The probability of failing to reject $H_0$ when a true effect exists (false negative).
* **Power ($1 - \beta$):** The probability of correctly rejecting $H_0$. Typically targeted at 80% or 90%.

---

## 2. Estimands and Effect Measures
The **Estimand Framework (ICH E9 R1)** applies equally to frequentist designs.
* **Primary Estimand:** Must measure the treatment effect relevant to the clinical question (e.g., Treatment Policy, Hypothetical).
* **Effect Measures:**
    * **Binary:** Risk Difference, Odds Ratio, Relative Risk.
    * **Continuous:** Mean Difference, LS-Means (MMRM).
    * **Time-to-Event:** Hazard Ratio, Median Survival Difference, RMST.

---

## 3. Sample Size Determination
Sample size must be calculated to achieve target power for a **specific, clinically meaningful effect size** ($\delta$).
* **Sensitivity:** Power is highly sensitive to the assumed standard deviation (continuous) or control event rate (binary/TTE).
* **Adjustment:** Sample size should be inflated for:
    * Dropouts/Missing data.
    * Non-adherence.
    * Interim analyses (inflation factor).

---

## 4. Interim Analyses and Alpha Spending
Trials with interim looks require **Alpha Spending Functions** (e.g., Lan-DeMets with O'Brien-Fleming boundaries) to preserve the overall Type I error rate.
* **Key Rule:** You cannot simply test at p < 0.05 multiple times. The significance threshold must be tighter at each look.

---

## 5. Multiplicity Control
When testing multiple endpoints, doses, or subgroups, **Multiplicity Adjustments** are mandatory to control the Family-Wise Error Rate (FWER).
* **Methods:** Bonferroni, Holm, Hochberg, Hierarchical (Gatekeeping) procedures, Graphical approaches (Bretz et al.).
