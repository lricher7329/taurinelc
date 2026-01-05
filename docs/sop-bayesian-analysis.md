# Standard Operating Procedure (SOP)

## Title

Bayesian Statistical Guidance for Clinical Trials

---

## SOP Metadata

| Field                      | Description                                    |
| -------------------------- | ---------------------------------------------- |
| **SOP ID**           | STAT-BAYES-CT-001                              |
| **Version**          | 1.0                                            |
| **Effective Date**   | TBD                                            |
| **Supersedes**       | New SOP                                        |
| **Owner**            | Office of Clinical Trials / Biostatistics Unit |
| **Author(s)**        | Bayesian Methods Working Group                 |
| **Approved By**      | Clinical Research Governance Committee         |
| **Next Review Date** | Effective Date + 24 months                     |
| **Status**           | Draft for Internal Approval                    |

---

## 1. Purpose

This Standard Operating Procedure (SOP) establishes institutional standards for the **design, simulation, and analysis of Bayesian clinical trials**. It ensures methodological consistency, regulatory readiness, and auditability.

> **Note:** For detailed theoretical justification and policy definitions, refer to the **[Bayesian Methodological Guidance](file:///Users/lawrencericher/code/experiments/taurinelc/docs/guidance-bayesian-methodology.md)**.


---

## 2. Scope

This SOP applies to:

* All investigator-initiated and sponsor-partnered clinical trials using Bayesian statistical methods
* Trial phases I–IV
* Protocols, Statistical Analysis Plans (SAPs), design simulations, and regulatory submissions

This SOP is** ****methodology-focused** and does not mandate specific software platforms.

---

## 3. Definitions and Principles

### 3.1 Bayesian Clinical Trials as Decision Problems

Bayesian clinical trials are decision-theoretic in nature. Design parameters (sample size, interims, stopping rules) are selected to optimize decision quality under uncertainty, subject to ethical and regulatory constraints.

Frequentist operating characteristics (e.g., type I error) are treated as** ** **design constraints** , not inferential foundations, unless explicitly required.

---

## 4. Roles and Responsibilities

| Role                                      | Responsibilities                                   |
| ----------------------------------------- | -------------------------------------------------- |
| **Principal Investigator (PI)**     | Ensures scientific validity and clinical relevance |
| **Statistician / Methodologist**    | Implements Bayesian models, priors, simulations    |
| **SAP Author**                      | Documents methods in compliance with this SOP      |
| **Data Monitoring Committee (DMC)** | Reviews interim decision criteria                  |
| **Clinical Trials Office**          | Governance, compliance, audit readiness            |

---

## 5. Regulatory Context

Bayesian methods are acceptable to regulators when designs are transparent, pre-specified, and supported by simulation-based operating characteristics.

Key expectations include:

* Clear estimand definition (ICH E9(R1))
* Pre-specified decision rules
* Justified prior distributions
* Simulation-based operating characteristics
* Sensitivity analyses

---

## 6. Estimands and Decision Rules

### 6.1 Estimand Specification

All trials must define the primary estimand using the four ICH E9(R1) attributes:

1. Population
2. Endpoint
3. Handling of intercurrent events
4. Population-level summary

### 6.2 Decision Rules

Decision rules must be defined using posterior or predictive probabilities (e.g., P(Δ > 0 | data) ≥ γ). Thresholds are not p-values and must be justified and pre-specified.

---

## 7. Endpoint Models and Missing Data

The primary analysis model must align with the estimand and be explicitly stated.

Missing data assumptions (e.g., MAR) must be declared. Sensitivity analyses under plausible MNAR mechanisms are required for confirmatory trials.

---

## 8. Prior Specification

### 8.1 Design vs. Analysis Priors

Where appropriate, design priors (for assurance) and analysis priors (for inference) should be distinguished.

### 8.2 Acceptable Prior Types

* Weakly informative
* Skeptical
* Informative / enthusiastic
* Robust mixture priors

All priors require justification.

### 8.3 Prior–Data Conflict

For informative priors or borrowing designs, plans must include prior predictive checks and sensitivity analyses.

---

## 9. Sample Size and Assurance

Bayesian sample size justification should be based on assurance, supplemented by conditional power when required.

Target assurance levels must be justified based on trial phase and decision context.

---

## 10. Frequentist Operating Characteristics

### 10.1 Applicability

Calibration to frequentist error rates is required for confirmatory or pivotal trials.

### 10.2 Calibration Methods

Acceptable methods include simulation under null scenarios and threshold calibration.

---

## 11. Interim Analyses and Adaptations

Interim analyses must be pre-specified, including timing, stopping criteria, and maximum/minimum sample sizes.

Operational bias and information leakage must be addressed.

---

## 12. Simulation-Based Design Evaluation

### 12.1 Requirements

Simulation studies must:

* Reflect all adaptive features
* Include null and alternative scenarios
* Report assurance, error rates, and expected sample size

> **Templates:** Standardized R code for design simulation.
>
> **Primary (Bayesian):**
> * **[Binary Outcomes (Bayesian)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-binary-bayesian.md)**
> * **[Ordinal Outcomes (Bayesian)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-ordinal-bayesian.md)**
> * **[Continuous Outcomes (Bayesian)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-continuous.md)**
> * **[Time-to-Event (Bayesian)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-time-to-event.md)**
>
> **Benchmarks (Frequentist Reference):**
> * **[Binary Outcomes (Frequentist)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-binary-frequentist.md)**
> * **[Ordinal Outcomes (Frequentist)](file:///Users/lawrencericher/code/experiments/taurinelc/docs/templates/template-simulation-ordinal-frequentist.md)**


Simulation code must be reproducible and version controlled.

---

## 13. Borrowing External Data

Borrowing methods (e.g., MAP, commensurate priors) must be pre-specified, justified, and accompanied by sensitivity analyses.

---

## 14. Documentation and Reporting

Protocols and SAPs must document:

* Estimands
* Priors
* Decision rules
* Simulation methodology
* Operating characteristics

---

## 15. Quality Control and Audit

All Bayesian designs are subject to internal methodological review prior to trial activation.

Audit trails must include:

* Versioned simulation code
* Archived results
* Decision rule documentation

---

## 16. Review and Maintenance

This SOP will be reviewed every** ** **24 months** , or earlier if:

* New regulatory guidance is issued
* Major methodological advances occur

Revisions require approval by the Clinical Research Governance Committee.

---

## 17. Version History

| Version | Date | Description     | Approved By |
| ------- | ---- | --------------- | ----------- |
| 1.0     | TBD  | Initial release | TBD         |
