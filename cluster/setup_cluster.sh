#!/bin/bash
# Setup script for ParallelCluster head node
# Run this after SSHing into the cluster

set -e

echo "=== Setting up R environment on ParallelCluster ==="

# Update system packages
sudo apt-get update -y

# Install R dependencies
echo "Installing system dependencies..."
sudo apt-get install -y \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libwebp-dev \
    cmake \
    g++

# Install CmdStan
echo "Installing CmdStan..."
CMDSTAN_VERSION="2.34.1"
cd /shared
if [ ! -d "cmdstan-${CMDSTAN_VERSION}" ]; then
    wget -q https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz
    tar -xzf cmdstan-${CMDSTAN_VERSION}.tar.gz
    cd cmdstan-${CMDSTAN_VERSION}
    make build -j2
    cd /shared
    rm cmdstan-${CMDSTAN_VERSION}.tar.gz
fi

# Set CmdStan path
export CMDSTAN=/shared/cmdstan-${CMDSTAN_VERSION}
echo "export CMDSTAN=/shared/cmdstan-${CMDSTAN_VERSION}" >> ~/.bashrc

# Create shared R library directory (accessible from all nodes)
echo "Creating shared R library directory..."
mkdir -p /shared/R-libs
export R_LIBS_USER=/shared/R-libs
echo "export R_LIBS_USER=/shared/R-libs" >> ~/.bashrc

# Install R packages to shared storage
# CRITICAL: Compute nodes don't have access to head node's system R packages.
# ALL dependencies must be installed explicitly to /shared/R-libs.
# Total: 135 packages required for power analysis workflow.
echo "Installing R packages to /shared/R-libs (135 packages)..."
Rscript -e "
# Install ALL dependencies explicitly to shared library
# Compute nodes only have base R - every package must be in /shared/R-libs
install.packages(c(
  # Core infrastructure
  'R6', 'Rcpp', 'rlang', 'cli', 'glue', 'lifecycle', 'vctrs', 'pillar',
  'tibble', 'magrittr', 'crayon', 'fansi', 'utf8', 'pkgconfig', 'digest',
  'withr', 'backports', 'generics', 'cpp11', 'codetools',

  # Stan/Bayesian packages dependencies
  'jsonlite', 'processx', 'ps', 'checkmate', 'data.table', 'matrixStats',
  'abind', 'tensorA', 'distributional', 'loo', 'knitr', 'inline',
  'RcppParallel', 'RcppEigen', 'StanHeaders', 'BH', 'QuickJSR', 'V8',

  # Tidyverse core
  'dplyr', 'tidyr', 'readr', 'purrr', 'stringr', 'forcats', 'lubridate',
  'timechange', 'tidyselect', 'stringi', 'hms', 'clipr', 'tzdb',
  'bit', 'bit64', 'vroom', 'progress', 'prettyunits',

  # ggplot2 and visualization
  'S7', 'ggplot2', 'scales', 'gtable', 'isoband', 'colorspace', 'farver',
  'labeling', 'munsell', 'RColorBrewer', 'viridisLite', 'gridExtra',
  'gridGraphics', 'patchwork', 'ggfortify', 'hexbin', 'svglite', 'vdiffr',

  # Statistical packages
  'MASS', 'Matrix', 'lattice', 'nlme', 'mgcv', 'mvtnorm', 'truncnorm',
  'multcomp', 'TH.data', 'sandwich', 'SparseM', 'minqa', 'nloptr',
  'reformulas',

  # Parallel/async processing
  'future', 'furrr', 'globals', 'listenv', 'parallelly', 'promises', 'later',

  # Shiny and interactive (bayesplot dependencies)
  'shiny', 'httpuv', 'xtable', 'sourcetools', 'htmlwidgets', 'crosstalk',
  'DT', 'dygraphs', 'xts', 'zoo', 'miniUI', 'shinyjs', 'shinythemes',
  'shinystan', 'colourpicker', 'threejs', 'igraph',

  # Tables and reporting
  'gt', 'bigD', 'juicyjuice', 'reactable', 'reactR', 'quarto', 'Rdpack',
  'rbibutils', 'roxygen2', 'brew',

  # Geospatial (ggplot2 map dependencies)
  'maps', 'mapproj', 's2', 'wk', 'classInt',

  # Misc utilities
  'gtools', 'png', 'bitops', 'profvis', 'otel'
), lib = '/shared/R-libs', repos = 'https://cloud.r-project.org/')

# Install cmdstanr from Stan repository (not on CRAN)
install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev', 'https://cloud.r-project.org'), lib = '/shared/R-libs')

# Install rstan (optional, for shinystan compatibility)
install.packages('rstan', repos = 'https://cloud.r-project.org', lib = '/shared/R-libs')
install.packages('rstantools', repos = 'https://cloud.r-project.org', lib = '/shared/R-libs')

# Install main packages (most dependencies should already be installed above)
install.packages(c(
  'posterior',
  'bayesplot',
  'tidyverse'
), lib = '/shared/R-libs', repos = 'https://cloud.r-project.org/', dependencies = TRUE)

# Set cmdstan path for cmdstanr
cmdstanr::set_cmdstan_path('/shared/cmdstan-${CMDSTAN_VERSION}')
"

echo ""
echo "=== Setup complete! ==="
echo "CmdStan installed at: /shared/cmdstan-${CMDSTAN_VERSION}"
echo ""
echo "Next steps:"
echo "1. Copy your project files to /shared/taurinelc/"
echo "2. Run: cd /shared/taurinelc && Rscript run_power_analysis.R"
