# Bayesian Statistical Considerations for Clinical Trials

## Purpose and Positioning

This document provides** ****authoritative internal methodological guidance** on the design, simulation, and analysis of Bayesian clinical trials. It is intended to support protocol development, Statistical Analysis Plan (SAP) authoring, internal scientific review, and regulator-facing submissions.

With the refinements incorporated herein, this document represents a** ** **best‑in‑class reference for Bayesian clinical trial methodology** , fully aligned with modern regulatory expectations, contemporary academic standards, and current computational best practices.

This guidance is **methodology-focused** and software-agnostic. Specific implementation choices (e.g., Stan, JAX-based frameworks) must satisfy the principles articulated below.

> **Related Documents:**
>
> * **Rules & Procedure:** [SOP: Bayesian Analysis](file:///Users/lawrencericher/code/experiments/taurinelc/docs/sop-bayesian-analysis.md)
> * **Code Templates:** `docs/templates/`

---

## Conceptual Framework: Bayesian Trials as Decision Problems

Bayesian clinical trials are fundamentally** ** **decision‑theoretic** . Sample size, interim analyses, and stopping rules are chosen to optimize the probability of making correct decisions under uncertainty, subject to ethical, scientific, and regulatory constraints.

Frequentist quantities (e.g., type I error, power) are treated as** ** **design‑level operating characteristics** , imposed when required by regulators, rather than as the inferential basis of the analysis.

---

## Regulatory Landscape

Bayesian methods are increasingly accepted by regulators when designs are transparent, pre‑specified, and supported by rigorous simulation‑based operating characteristics.

Key regulatory principles include:

* Explicit definition of estimands (ICH E9(R1))
* Clear, pre‑specified decision rules
* Clinically and statistically justified prior distributions
* Simulation‑based evaluation of operating characteristics
* Sensitivity analyses demonstrating robustness to key assumptions

For confirmatory or pivotal trials, calibration to nominal frequentist error rates is typically required and must be demonstrated through simulation.

---

## 1. Decision Rules and Estimands

### 1.1 Estimand Definition

All Bayesian trials must define the primary estimand using the four attributes of the ICH E9(R1) framework:

1. Population
2. Variable (endpoint)
3. Handling of intercurrent events
4. Population‑level summary measure

The estimand is** ****methodology‑agnostic** and must be specified independently of the statistical model and prior.

### 1.2 Posterior‑Based Decision Rules

Bayesian success, futility, and harm decisions must be expressed in terms of posterior or predictive probabilities. Examples include:

* Superiority: P(Δ > 0 | data) ≥ γ
* Clinically meaningful benefit: P(Δ > δ | data) ≥ γ
* Non‑inferiority: P(Δ > −δ_NI | data) ≥ γ
* Futility: P(Δ > δ | data) ≤ γ_fut

Decision thresholds are** ****not p‑values** and must not be interpreted as such. Thresholds must be pre‑specified and justified clinically and statistically.

Where required, thresholds may be calibrated via simulation to satisfy regulatory operating characteristics.

---

## 2. Endpoint Models and Likelihoods

The sampling model for the primary endpoint must be explicitly defined and aligned with the estimand.

Typical endpoint–model pairings include:

* Continuous: Normal or robust t models, ANCOVA, MMRM
* Binary: Logistic or probit regression, beta‑binomial models
* Count: Poisson or negative binomial models
* Time‑to‑event: Parametric survival models; semi‑parametric approaches when justified
* Ordinal: Proportional odds or partial proportional odds models
* Clustered or multi‑site: Hierarchical random‑effects models

### Model Robustness

Simulation scenarios should, where feasible, include** ****plausible model misspecification** (e.g., non‑normal residuals, non‑proportional hazards) to assess robustness of decision rules.

### Missing Data

Missing data assumptions must be explicitly stated (e.g., MAR). For confirmatory trials, sensitivity analyses under plausible MNAR mechanisms must be pre‑specified.

---

## 3. Prior Specification

### 3.1 Separation of Design and Analysis Priors

A critical distinction must be made between:

* **Design priors** , used to represent uncertainty about true effects when evaluating assurance and operating characteristics
* **Analysis priors** , used for posterior inference given observed trial data

These priors need not be identical but must be mutually coherent and scientifically defensible.

### 3.2 Prior Categories

Acceptable prior classes include:

* Weakly informative priors
* Skeptical priors centered on no effect
* Informative or enthusiastic priors based on external evidence
* Robust mixture priors combining informative and vague components

All prior choices must be justified clinically and statistically.

### 3.3 Prior–Data Conflict and Diagnostics

For informative or borrowing priors, the analysis plan must include:

* Prior predictive checks
* Posterior predictive checks
* Sensitivity analyses to down‑weighting or mixture components

### 3.4 Prior Effective Sample Size

Where feasible, prior informativeness should be quantified using a prior effective sample size to facilitate transparency and regulatory communication.

---

## 4. Sample Size Determination: Assurance vs. Power

### 4.1 Bayesian Assurance

Bayesian sample size justification should be based on** ** **assurance** , defined as the probability of trial success averaged over uncertainty in the true treatment effect.

Assurance explicitly accounts for uncertainty in effect size and is therefore typically lower than conditional power evaluated at a single assumed effect.

### 4.2 Reporting Expectations

For confirmatory trials, both assurance and conditional power should be reported. Assurance curves as a function of sample size are strongly recommended.

Target assurance levels must be justified based on trial phase, decision context, and ethical considerations.

---

## 5. Frequentist Operating Characteristics

### 5.1 When Required

Calibration to frequentist operating characteristics is generally required for:

* Confirmatory or pivotal trials
* Trials supporting marketing authorization
* Designs with interim analyses or adaptive features
* Multiplicity settings

For exploratory or decision‑support trials, such calibration may be unnecessary provided inferential transparency is maintained.

### 5.2 Calibration Approaches

Acceptable approaches include:

* Simulation under null and near‑null scenarios
* Calibration of posterior probability thresholds
* Scenario‑based robustness analyses

The necessity and target level of error control must be explicitly stated.

---

## 6. Interim Analyses and Adaptive Features

Bayesian designs may include interim analyses for efficacy, futility, or harm.

Requirements include:

* Pre‑specification of number and timing of interims
* Pre‑specification of stopping criteria and thresholds
* Definition of minimum and maximum sample sizes
* Reporting of expected sample size distributions

Although Bayesian updating does not require multiplicity adjustment,** ****operational bias and information leakage** must be addressed through governance and trial conduct safeguards.

---

## 7. Simulation‑Based Design Evaluation

### 7.1 General Simulation Algorithm

For each candidate design:

1. Draw true parameters from the design prior or scenario grid
2. Generate trial data
3. Fit the Bayesian analysis model
4. Apply decision rules
5. Record outcomes (success, error, stopping time, final sample size)

### 7.2 Required Outputs

Standard deliverables include:

* Assurance and power estimates
* Type I error under null scenarios (when required)
* Expected sample size and distribution
* Probability of early stopping
* Sensitivity analyses

Simulation code must be reproducible, version‑controlled, and auditable.

---

## 8. Borrowing External Data

Bayesian borrowing approaches may include:

* Power priors
* Commensurate priors
* Meta‑analytic predictive (MAP) priors
* Robust or dynamic borrowing strategies

Borrowing mechanisms must be pre‑specified and justified. Sensitivity analyses to reduced or no borrowing are mandatory.

---

## 9. Reporting and Documentation Standards

Protocols and SAPs must document:

* Estimands and decision rules
* Analysis and design priors
* Simulation methodology and scenarios
* Operating characteristics
* Sensitivity analyses

Bayesian results must be reported using posterior summaries and probabilities rather than p‑values.

---

## 10. Quality Control and Validation

All Bayesian designs should undergo internal methodological review prior to trial activation. Simulation results and code must be archived to support audit and inspection.

Independent replication or review of pivotal simulation studies is strongly recommended.

---

## References (Authoritative)

### Regulatory Guidance

* U.S. Food and Drug Administration.** ** *Guidance for the Use of Bayesian Statistics in Medical Device Clinical Trials* . 2010.
* U.S. Food and Drug Administration.** ** *Adaptive Designs for Clinical Trials of Drugs and Biologics* . 2019.
* International Council for Harmonisation.** ** *ICH E9(R1): Estimands and Sensitivity Analysis in Clinical Trials* . 2019.
* European Medicines Agency.** ** *Complex Clinical Trials – Questions and Answers* . 2022.

### Core Bayesian Foundations

* Gelman A, Carlin JB, Stern HS, et al.** ** *Bayesian Data Analysis* . 3rd ed. CRC Press, 2013.
* Robert CP, Casella G.** ** *Monte Carlo Statistical Methods* . 2nd ed. Springer, 2004.
* O’Hagan A, Stevens JW, Campbell MJ. Bayesian statistics and the design of experiments.** ** *Statistical Science* . 2005.

### Bayesian Clinical Trial Design

* Berry SM, Carlin BP, Lee JJ, Müller P.** ** *Bayesian Adaptive Methods for Clinical Trials* . CRC Press, 2010.
* Spiegelhalter DJ, Abrams KR, Myles JP.** ** *Bayesian Approaches to Clinical Trials and Health‑Care Evaluation* . Wiley, 2004.
* Chow SC, Chang M.** ** *Adaptive Design Methods in Clinical Trials* . 2nd ed. CRC Press, 2011.

### Assurance, Priors, and Borrowing

* O’Hagan A, Stevens JW. On the probability of trial success.** ** *Statistics in Medicine* . 2001.
* Morita S, Thall PF, Müller P. Determining the effective sample size of a prior.** ** *Biometrics* . 2008.
* Neuenschwander B, et al. Power priors for historical data.** ** *Statistics in Medicine* . 2010.
* Schmidli H, et al. Robust meta‑analytic‑predictive priors.** ** *Biometrics* . 2014.

### Bayesian Workflow and Validation

* Gelman A, Vehtari A, Gabry J. Practical Bayesian workflow.** ** *Statistics and Computing* . 2020.
* Betancourt M. A conceptual introduction to Hamiltonian Monte Carlo. 2017.

## Appendix A: SAP Mapping Checklist for Bayesian Clinical Trials

This appendix maps each section of this guidance document to** ** **required or recommended content in the Statistical Analysis Plan (SAP)** . It is intended for use by SAP authors, reviewers, and quality assurance teams.

### A1. Trial Objectives and Estimands

| Guidance Section      | SAP Requirement                                                                              | Completed (Y/N) | Notes |
| --------------------- | -------------------------------------------------------------------------------------------- | --------------- | ----- |
| Conceptual Framework  | Statement that the trial uses a Bayesian decision-theoretic framework                        |                 |       |
| Section 1.1 Estimands | Explicit definition of primary estimand (population, endpoint, intercurrent events, summary) |                 |       |
| Section 1.1 Estimands | Definition of secondary estimands (if applicable)                                            |                 |       |

---

### A2. Decision Rules and Success Criteria

| Guidance Section                    | SAP Requirement                                            | Completed (Y/N) | Notes |
| ----------------------------------- | ---------------------------------------------------------- | --------------- | ----- |
| Section 1.2 Decision Rules          | Primary success criterion stated as posterior probability  |                 |       |
| Section 1.2 Decision Rules          | Futility and/or harm criteria (if applicable)              |                 |       |
| Section 1.2 Decision Rules          | Decision thresholds justified clinically and statistically |                 |       |
| Section 5 Operating Characteristics | Statement on whether frequentist calibration is required   |                 |       |

---

### A3. Endpoint Models and Likelihoods

| Guidance Section           | SAP Requirement                               | Completed (Y/N) | Notes |
| -------------------------- | --------------------------------------------- | --------------- | ----- |
| Section 2 Endpoint Models  | Primary endpoint likelihood specified         |                 |       |
| Section 2 Endpoint Models  | Covariate adjustments defined                 |                 |       |
| Section 2 Model Robustness | Consideration of model misspecification       |                 |       |
| Section 2 Missing Data     | Missing data assumptions (MAR/MNAR)           |                 |       |
| Section 2 Missing Data     | Planned sensitivity analyses for missing data |                 |       |

---

### A4. Prior Specification

| Guidance Section                 | SAP Requirement                                      | Completed (Y/N) | Notes |
| -------------------------------- | ---------------------------------------------------- | --------------- | ----- |
| Section 3.1 Priors               | Analysis prior distributions fully specified         |                 |       |
| Section 3.1 Priors               | Design prior distributions (if distinct)             |                 |       |
| Section 3.2 Prior Categories     | Rationale for prior choice                           |                 |       |
| Section 3.3 Prior–Data Conflict | Prior predictive checks described                    |                 |       |
| Section 3.3 Prior–Data Conflict | Sensitivity priors defined                           |                 |       |
| Section 3.4 ESS                  | Prior effective sample size reported (if applicable) |                 |       |

---

### A5. Sample Size and Assurance

| Guidance Section    | SAP Requirement                          | Completed (Y/N) | Notes |
| ------------------- | ---------------------------------------- | --------------- | ----- |
| Section 4 Assurance | Target assurance specified               |                 |       |
| Section 4 Assurance | Conditional power reported (if required) |                 |       |
| Section 4 Reporting | Assurance vs. sample size curve included |                 |       |

---

### A6. Operating Characteristics and Error Control

| Guidance Section          | SAP Requirement                               | Completed (Y/N) | Notes |
| ------------------------- | --------------------------------------------- | --------------- | ----- |
| Section 5.1 Error Control | Type I error target specified (if applicable) |                 |       |
| Section 5.2 Calibration   | Description of calibration approach           |                 |       |
| Section 7 Simulation      | Null and alternative scenarios defined        |                 |       |

---

### A7. Interim Analyses and Adaptations

| Guidance Section           | SAP Requirement                            | Completed (Y/N) | Notes |
| -------------------------- | ------------------------------------------ | --------------- | ----- |
| Section 6 Interim Analyses | Number and timing of interims              |                 |       |
| Section 6 Interim Analyses | Stopping criteria (efficacy/futility/harm) |                 |       |
| Section 6 Interim Analyses | Minimum and maximum sample size            |                 |       |
| Section 6 Interim Analyses | Expected sample size reported              |                 |       |

---

### A8. Simulation Methodology

| Guidance Section               | SAP Requirement                               | Completed (Y/N) | Notes |
| ------------------------------ | --------------------------------------------- | --------------- | ----- |
| Section 7 Simulation Algorithm | Simulation steps fully described              |                 |       |
| Section 7 Outputs              | Operating characteristic tables included      |                 |       |
| Section 7 Validation           | Reproducibility and version control described |                 |       |

---

### A9. Borrowing External Data

| Guidance Section    | SAP Requirement                              | Completed (Y/N) | Notes |
| ------------------- | -------------------------------------------- | --------------- | ----- |
| Section 8 Borrowing | Borrowing method specified                   |                 |       |
| Section 8 Borrowing | Justification of historical data relevance   |                 |       |
| Section 8 Borrowing | Sensitivity analyses to reduced/no borrowing |                 |       |

---

### A10. Reporting and Quality Control

| Guidance Section    | SAP Requirement                          | Completed (Y/N) | Notes |
| ------------------- | ---------------------------------------- | --------------- | ----- |
| Section 9 Reporting | Posterior summaries specified            |                 |       |
| Section 10 QC       | Internal review and validation described |                 |       |
| Section 10 QC       | Archiving and audit trail procedures     |                 |       |

---

## Appendix B: Worked Examples by Endpoint Type

This appendix provides** ****worked, regulator-ready examples** illustrating how the principles in this guidance are operationalized for common clinical trial endpoint types. These examples are intended as templates and should be adapted to the specific scientific context.

---

### B1. Continuous Outcome Example

**Clinical context**
Randomized, double-blind, parallel-group trial comparing an active treatment versus placebo on change from baseline in a continuous clinical score at 12 weeks.

**Estimand**
Population: All randomized participants (treatment policy estimand)
Variable: Change from baseline score at week 12
Intercurrent events: Treatment discontinuation handled via treatment policy
Summary: Mean difference between groups

**Statistical model**
Normal linear model with baseline adjustment.

**Analysis prior**
Skeptical normal prior on the standardized treatment effect; weakly informative prior on residual variance.

**Decision rule**
Trial success if posterior probability that the mean difference exceeds 0 is at least 0.975.

**Sample size justification**
Assurance-based simulation using a realistic design prior for the treatment effect.

---

### B2. Binary Outcome Example

**Clinical context**
Phase II trial evaluating binary response at 24 weeks.

**Estimand**
Population: Randomized participants
Variable: Binary response
Intercurrent events: Non-response imputed for early withdrawal
Summary: Risk difference

**Statistical model**
Logistic regression with treatment indicator.

**Analysis prior**
Weakly informative normal prior on the log-odds ratio.

**Decision rule**
Trial success if the posterior probability that the risk difference exceeds a clinically meaningful threshold is at least 0.90.

---

### B3. Ordinal Outcome Example

**Clinical context**
Ordinal functional outcome with five ordered categories assessed at 90 days.

**Estimand**
Population: Modified intention-to-treat
Variable: Ordinal outcome
Intercurrent events: Worst-rank imputation for death
Summary: Common odds ratio

**Statistical model**
Proportional odds model.

**Analysis prior**
Weakly informative normal prior on the log odds ratio.

**Decision rule**
Trial success if the posterior probability that the common odds ratio exceeds 1 is at least 0.95.

---

### B4. Time-to-Event Outcome Example

**Clinical context**
Phase III trial evaluating time to disease progression.

**Estimand**
Population: Randomized participants
Variable: Time to progression
Intercurrent events: Treatment switching addressed via hypothetical estimand
Summary: Hazard ratio

**Statistical model**
Parametric survival model (e.g., Weibull).

**Analysis prior**
Skeptical normal prior on the log hazard ratio; weakly informative prior on baseline hazard parameters.

**Decision rule**
Trial success if the posterior probability that the hazard ratio is less than 1 is at least 0.975.

---

### B5. Cross-Cutting Best Practices

Across all endpoint types:

* Decision rules must map directly to estimands
* Priors must be justified and sensitivity-tested
* Simulation must reflect the final analysis model
* Regulatory constraints must be addressed explicitly

---

## Appendix C: Platform Trials and Adaptive Trial Designs

This appendix provides methodological guidance specific to** ****platform trials** and** ** **adaptive Bayesian trial designs** , which introduce additional complexity in estimands, decision rules, and operating characteristics.

---

### C1. Platform Trials: Conceptual Overview

Platform trials evaluate multiple interventions within a single, ongoing master protocol. Key features include:

* Shared control arms
* Staggered entry and exit of treatment arms
* Borrowing of information across arms and time
* Continuous learning with prespecified decision rules

From a Bayesian perspective, platform trials are naturally accommodated through hierarchical modeling and decision-theoretic design.

---

### C2. Estimands in Platform Trials

Estimands must be defined** ****per comparison** and must explicitly address:

* The relevant control population (concurrent vs non-concurrent controls)
* Temporal drift in outcomes or standard of care
* Intercurrent events related to platform adaptations (e.g., arm dropping)

Best practice is to define:

* A primary estimand based on** ****concurrent controls**
* Sensitivity estimands incorporating partial borrowing from non-concurrent controls

---

### C3. Statistical Models for Platform Trials

Common Bayesian modeling strategies include:

* Hierarchical treatment effects across arms
* Time-varying baseline or control effects
* Dynamic borrowing models that down-weight non-concurrent data

Model complexity must be justified, and simpler sensitivity models should be pre-specified.

---

### C4. Decision Rules in Platform Trials

Decision rules must be arm-specific and may include:

* Graduation for efficacy
* Dropping for futility or harm
* Adaptive allocation

Rules should be defined using posterior or predictive probabilities and must be evaluated through extensive simulation.

---

### C5. Operating Characteristics for Platform Trials

Operating characteristic evaluation must consider:

* Family-wise type I error or Bayesian analogues
* Probability of false graduation across multiple arms
* Expected sample size per arm and overall
* Impact of arm entry/exit timing

Simulation scenarios should include null, partially effective, and fully effective configurations across arms.

---

### C6. Adaptive Trials: General Principles

Adaptive trials allow prospectively planned modifications based on accumulating data. Bayesian methods are particularly well-suited due to coherent updating.

Common adaptive features include:

* Group sequential monitoring
* Sample size re-estimation
* Response-adaptive randomization
* Adaptive enrichment

All adaptations must be pre-specified and justified.

---

### C7. Interim Decision Criteria

Interim decisions should be based on:

* Posterior probabilities of efficacy or harm
* Predictive probabilities of eventual success

Predictive probabilities are especially useful for futility decisions in late-stage trials.

---

### C8. Type I Error and Multiplicity in Adaptive Designs

Although Bayesian inference does not rely on type I error control, regulators may require:

* Calibration of decision thresholds
* Control of family-wise error rates across adaptations or arms

Calibration must be demonstrated via simulation under appropriate null scenarios.

---

### C9. Governance and Operational Considerations

Adaptive and platform trials require enhanced governance, including:

* Independent data monitoring committees
* Firewalls to prevent operational bias
* Clear documentation of adaptation rules

The complexity of these designs necessitates early and ongoing engagement with regulators.

---

### C10. Reporting Expectations

Protocols and SAPs for platform or adaptive trials must additionally document:

* Adaptation algorithms and timing
* Arm-specific estimands and decision rules
* Simulation scenarios reflecting platform evolution
* Sensitivity analyses for temporal drift and borrowing assumptions
