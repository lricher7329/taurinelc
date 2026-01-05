# priors.R
# Prior specification module implementing the two-prior framework
# Separates design priors (for assurance) from analysis priors (for inference)
# Adapted for taurinelc co-primary endpoints (TMT B/A Ratio and MFIS)

#' Specify a design prior for assurance calculation
#'
#' The design prior reflects realistic uncertainty about the true treatment effect.
#' It is used to generate "true" effects when calculating assurance (expected power).
#'
#' @param distribution Distribution type: "normal", "student_t", "uniform"
#' @param mean Prior mean (location)
#' @param sd Prior standard deviation (scale)
#' @param df Degrees of freedom (for student_t)
#' @param lower Lower bound (for uniform)
#' @param upper Upper bound (for uniform)
#' @return Design prior object
specify_design_prior <- function(distribution = "normal",
                                  mean = 0,
                                  sd = 1,
                                  df = NULL,
                                  lower = NULL,
                                  upper = NULL) {
  prior <- list(
    type = "design",
    distribution = distribution,
    mean = mean,
    sd = sd
  )

  if (distribution == "student_t") {
    if (is.null(df)) stop("df required for student_t distribution")
    prior$df <- df
  } else if (distribution == "uniform") {
    if (is.null(lower) || is.null(upper)) {
      stop("lower and upper required for uniform distribution")
    }
    prior$lower <- lower
    prior$upper <- upper
    prior$mean <- (lower + upper) / 2
    prior$sd <- (upper - lower) / sqrt(12)
  }

  class(prior) <- c("design_prior", "prior")
  prior
}

#' Specify an analysis prior for Bayesian inference
#'
#' The analysis prior is used when fitting the model to trial data.
#' Common choices are weakly informative or skeptical priors.
#'
#' @param type Prior type: "weakly_informative", "skeptical", "informative"
#' @param distribution Distribution: "normal", "student_t"
#' @param mean Prior mean
#' @param sd Prior standard deviation
#' @param df Degrees of freedom (for student_t)
#' @return Analysis prior object
specify_analysis_prior <- function(type = "weakly_informative",
                                    distribution = "normal",
                                    mean = NULL,
                                    sd = NULL,
                                    df = NULL) {
  # Default values based on type
  if (is.null(mean)) {
    mean <- switch(type,
      "weakly_informative" = 0,
      "skeptical" = 0,
      "informative" = 0,
      0
    )
  }

  if (is.null(sd)) {
    sd <- switch(type,
      "weakly_informative" = 2,
      "skeptical" = 0.5,
      "informative" = 0.3,
      1
    )
  }

  prior <- list(
    type = "analysis",
    prior_type = type,
    distribution = distribution,
    mean = mean,
    sd = sd
  )

  if (distribution == "student_t") {
    prior$df <- df %||% 3
  }

  class(prior) <- c("analysis_prior", "prior")
  prior
}

#' Generate samples from a design prior
#'
#' Used in assurance calculation to sample "true" treatment effects.
#'
#' @param prior Design prior object
#' @param n Number of samples
#' @param seed Random seed
#' @return Vector of samples
sample_from_design_prior <- function(prior, n = 1, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  switch(prior$distribution,
    "normal" = rnorm(n, mean = prior$mean, sd = prior$sd),
    "student_t" = prior$mean + prior$sd * rt(n, df = prior$df),
    "uniform" = runif(n, min = prior$lower, max = prior$upper),
    stop("Unknown distribution: ", prior$distribution)
  )
}

#' Calculate prior effective sample size (ESS)
#'
#' Quantifies prior informativeness in terms of equivalent sample size.
#' Higher ESS means more informative prior.
#'
#' @param prior Prior object
#' @param likelihood_var Variance of the likelihood for one observation
#' @param method Calculation method: "morita" or "neuenschwander"
#' @return Prior ESS
calculate_prior_ess <- function(prior, likelihood_var, method = "morita") {
  # For normal priors: ESS = likelihood_var / prior_var
  # This gives the number of observations with variance likelihood_var
  # that would provide equivalent information

  prior_var <- prior$sd^2

  if (method == "morita") {
    # Morita et al. (2008) method
    ess <- likelihood_var / prior_var
  } else if (method == "neuenschwander") {
    # Neuenschwander et al. (2010) method
    # For normal-normal conjugate case
    ess <- likelihood_var / prior_var
  } else {
    stop("Unknown method: ", method)
  }

  ess
}

#' Compare design and analysis priors
#'
#' @param design_prior Design prior object
#' @param analysis_prior Analysis prior object
#' @param plot If TRUE, create comparison plot
#' @return Comparison summary
compare_priors <- function(design_prior, analysis_prior, plot = TRUE) {
  comparison <- list(
    design = design_prior,
    analysis = analysis_prior,
    design_mean = design_prior$mean,
    design_sd = design_prior$sd,
    analysis_mean = analysis_prior$mean,
    analysis_sd = analysis_prior$sd,
    mean_difference = design_prior$mean - analysis_prior$mean,
    sd_ratio = design_prior$sd / analysis_prior$sd
  )

  if (plot && requireNamespace("ggplot2", quietly = TRUE)) {
    x_range <- c(
      min(design_prior$mean - 3 * design_prior$sd,
          analysis_prior$mean - 3 * analysis_prior$sd),
      max(design_prior$mean + 3 * design_prior$sd,
          analysis_prior$mean + 3 * analysis_prior$sd)
    )

    x <- seq(x_range[1], x_range[2], length.out = 200)
    design_density <- dnorm(x, design_prior$mean, design_prior$sd)
    analysis_density <- dnorm(x, analysis_prior$mean, analysis_prior$sd)

    df <- data.frame(
      x = rep(x, 2),
      density = c(design_density, analysis_density),
      Prior = rep(c("Design", "Analysis"), each = length(x))
    )

    p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = density, color = Prior, linetype = Prior)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
      ggplot2::labs(
        x = "Treatment Effect",
        y = "Density",
        title = "Design vs Analysis Prior Comparison"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::scale_color_manual(values = c("Design" = "#E69F00", "Analysis" = "#0072B2"))

    comparison$plot <- p
    print(p)
  }

  invisible(comparison)
}

#' Print prior summary
#'
#' @param prior Prior object
print.prior <- function(prior) {
  cat(sprintf("=== %s Prior ===\n", tools::toTitleCase(prior$type)))
  cat(sprintf("Distribution: %s\n", prior$distribution))
  cat(sprintf("Mean (location): %.3f\n", prior$mean))
  cat(sprintf("SD (scale): %.3f\n", prior$sd))
  if (!is.null(prior$df)) {
    cat(sprintf("Degrees of freedom: %d\n", prior$df))
  }
  if (!is.null(prior$prior_type)) {
    cat(sprintf("Prior type: %s\n", prior$prior_type))
  }
  cat("\n")
  cat(sprintf("95%% interval: [%.3f, %.3f]\n",
              qnorm(0.025, prior$mean, prior$sd),
              qnorm(0.975, prior$mean, prior$sd)))
  invisible(prior)
}

# ============================================================================
# Taurine Long COVID specific design priors
# ============================================================================

#' Create taurinelc design priors
#'
#' Returns design priors for TMT B/A Ratio and MFIS based on expected
#' treatment effects from pilot data and clinical judgment.
#'
#' @return Named list with design priors for each outcome
create_taurinelc_design_priors <- function() {
  list(
    # TMT B/A Ratio: Lower is better
    # Expected improvement of ~0.10 ratio reduction (standardized)
    tmt = specify_design_prior(
      distribution = "normal",
      mean = -0.10,   # Expected treatment effect (standardized)
      sd = 0.05       # Uncertainty in the effect
    ),

    # MFIS: Lower is better
    # Expected improvement of ~3 points (standardized to ~0.2 SD)
    mfis = specify_design_prior(
      distribution = "normal",
      mean = -3.0,    # Expected treatment effect (raw MFIS points)
      sd = 1.5        # Uncertainty
    )
  )
}

#' Create combined design prior for assurance
#'
#' For co-primary endpoints, creates a single design prior representing
#' the expected joint treatment effect (averaged across outcomes).
#'
#' @param tmt_effect Expected TMT effect (standardized)
#' @param tmt_sd Uncertainty in TMT effect
#' @param mfis_effect Expected MFIS effect (standardized)
#' @param mfis_sd Uncertainty in MFIS effect
#' @return Combined design prior
create_combined_design_prior <- function(tmt_effect = -0.10,
                                          tmt_sd = 0.05,
                                          mfis_effect = -0.20,
                                          mfis_sd = 0.10) {
  # Average effect across outcomes (both standardized)
  combined_mean <- (tmt_effect + mfis_effect) / 2

  # Combined uncertainty (assuming independence)
  combined_sd <- sqrt((tmt_sd^2 + mfis_sd^2) / 4)

  specify_design_prior(
    distribution = "normal",
    mean = combined_mean,
    sd = combined_sd
  )
}

# Null coalesce operator
`%||%` <- function(x, y) if (is.null(x)) y else x
