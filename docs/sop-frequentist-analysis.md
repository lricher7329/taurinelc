# SOP: Frequentist Statistical Analysis for Clinical Trials

> **Parent Document:** [Guidance: Frequentist Methodology](file:///Users/lawrencericher/code/experiments/taurinelc/docs/guidance-frequentist-methodology.md)

## 1. Purpose
To establish the standard operating procedure for designing, simulating, and analyzing clinical trials using frequentist methods.

## 2. Scope
Applies to all clinical trials where the primary analysis is based on p-values, confidence intervals, and hypothesis testing.

## 3. Design and Simulation
While analytic formulas exist for simple designs, **simulation is required** for:
* Complex designs (adaptive, Bayesian-hybrid).
* Assessing robustness to assumption violations (e.g., non-normality, missing data).
* Estimating operating characteristics of interim analyses.

> **Templates:** Standardized R code for frequentist simulation:
> * **[Binary Outcomes (Frequentist)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-binary-frequentist.md)**
> * **[Ordinal Outcomes (Frequentist)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-ordinal-frequentist.md)**
> * **[Continuous Outcomes (Frequentist)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-continuous-frequentist.md)**
> * **[Time-to-Event (Frequentist)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-time-to-event-frequentist.md)**

## 4. Analysis Plan (SAP) Requirements
The SAP must specify:
1.  **Hypotheses:** Clear null and alternative.
2.  **Type I Error Control:** One-sided vs two-sided, alpha level.
3.  **Power Calculation:** Assumptions used ($N$, $\delta$, $\sigma$).
4.  **Model Specification:** Exact regression model, covariates, and link function.
5.  **Multiplicity:** Procedures for FWER control.
6.  **Missing Data:** Primary imputation method (e.g., MI, MMRM) and sensitivity analyses.

## 5. Coding Standards
* Use `renv` for reproducibility.
* Validate all custom functions against valid benchmarks (e.g., SAS `PROC POWER`, `gsDesign`).
* Reports must include `sessionInfo()` and seed for random number generation.
