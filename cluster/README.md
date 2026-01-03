# AWS ParallelCluster Setup Guide

This guide documents how to set up an AWS ParallelCluster for running Bayesian power analysis simulations using R and Stan.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed locally (`brew install awscli`)
- Python 3.8+ for ParallelCluster CLI

## Step 1: AWS IAM Setup

### 1.1 Create IAM User and Group

1. Go to AWS Console → IAM → Users → Create User
2. Create a user (e.g., `parallelcluster-admin`)
3. Create a group (e.g., `parallelcluster-users`) and add the user to it

### 1.2 Attach Required Policies to the Group

The following AWS managed policies are required:

```bash
# Core ParallelCluster policies
aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AWSCloudFormationFullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess

# Additional policies needed for cluster creation
aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

aws iam attach-group-policy --group-name parallelcluster-users \
    --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
```

### 1.3 Create Access Keys

1. Go to IAM → Users → your user → Security credentials
2. Create access key → Choose "Command Line Interface (CLI)"
3. Save the Access Key ID and Secret Access Key securely

## Step 2: Configure AWS CLI

```bash
aws configure
```

Enter:
- AWS Access Key ID: (your access key)
- AWS Secret Access Key: (your secret key)
- Default region name: `ca-central-1` (or your preferred region)
- Default output format: `json`

Verify configuration:
```bash
aws sts get-caller-identity
```

## Step 3: Install ParallelCluster CLI

```bash
# Create virtual environment in project directory
cd /path/to/taurinelc
python3 -m venv .venv
source .venv/bin/activate

# Install ParallelCluster
pip install aws-parallelcluster

# Verify installation
pcluster version
```

## Step 4: Create EC2 Key Pair

Ubuntu 22.04 requires ed25519 keys:

```bash
# Remove any existing key with the same name
rm -f ~/.ssh/pcluster-key.pem

# Create new key pair
aws ec2 create-key-pair \
    --key-name pcluster-key \
    --key-type ed25519 \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/pcluster-key.pem

# Set correct permissions
chmod 400 ~/.ssh/pcluster-key.pem
```

## Step 5: Get Subnet ID

You need a subnet ID for the cluster configuration:

```bash
aws ec2 describe-subnets --query 'Subnets[0].SubnetId' --output text
```

Note the subnet ID (e.g., `subnet-0b87505eec06f2fe9`).

## Step 6: Create Cluster Configuration

Create `cluster-config.yaml` in your project directory:

```yaml
Region: ca-central-1
Image:
  Os: ubuntu2204

HeadNode:
  InstanceType: t3.large  # 8GB RAM - sufficient for CmdStan compilation
  Networking:
    SubnetId: subnet-0b87505eec06f2fe9  # Replace with your subnet ID
  Ssh:
    KeyName: pcluster-key

Scheduling:
  Scheduler: slurm
  SlurmQueues:
    - Name: compute
      ComputeResources:
        - Name: c5xlarge
          InstanceType: c5.xlarge
          MinCount: 0
          MaxCount: 10
      Networking:
        SubnetIds:
          - subnet-0b87505eec06f2fe9  # Replace with your subnet ID

SharedStorage:
  - MountDir: /shared
    Name: shared-storage
    StorageType: Ebs
    EbsSettings:
      Size: 50
      VolumeType: gp3
      DeletionPolicy: Retain  # Keep EBS volume when cluster is deleted
```

**Important notes:**
- `HeadNode.Networking.SubnetId` is singular
- `SlurmQueues.Networking.SubnetIds` is a list (plural)
- `EbsSettings.Size` (not `VolumeSize`)

## Step 7: Create the Cluster

```bash
source .venv/bin/activate
pcluster create-cluster \
    --cluster-name taurine-cluster \
    --cluster-configuration cluster-config.yaml \
    --region ca-central-1
```

Monitor creation status:
```bash
pcluster describe-cluster --cluster-name taurine-cluster --region ca-central-1
```

This takes 10-15 minutes. Wait for `clusterStatus: CREATE_COMPLETE`.

## Step 8: Deploy Project Files

From your local machine:

```bash
./cluster/deploy_to_cluster.sh
```

Or manually:
```bash
# Get head node IP
pcluster describe-cluster --cluster-name taurine-cluster --region ca-central-1 \
    | grep -o '"publicIpAddress": "[^"]*"'

# Copy files
rsync -avz --progress \
    --exclude '.git' \
    --exclude '.venv' \
    --exclude '_archive' \
    --exclude '_output' \
    -e "ssh -i ~/.ssh/pcluster-key.pem" \
    ./ ubuntu@<HEAD_NODE_IP>:/shared/taurinelc/
```

## Step 9: SSH into the Cluster

```bash
ssh -i ~/.ssh/pcluster-key.pem ubuntu@<HEAD_NODE_IP>
```

## Step 10: Set Up R and CmdStan on the Cluster

Run the setup script (this takes ~30-40 minutes):

```bash
bash /shared/taurinelc/cluster/setup_cluster.sh
```

Or run each step manually:

### 10.1 Install System Dependencies

```bash
sudo apt-get update -y
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
```

### 10.2 Install CmdStan

```bash
cd /shared
wget https://github.com/stan-dev/cmdstan/releases/download/v2.34.1/cmdstan-2.34.1.tar.gz
tar -xzf cmdstan-2.34.1.tar.gz
cd cmdstan-2.34.1
make build -j2

# Clean up
cd /shared
rm cmdstan-2.34.1.tar.gz

# Set path
echo 'export CMDSTAN=/shared/cmdstan-2.34.1' >> ~/.bashrc
source ~/.bashrc
```

### 10.4 Install R Packages

**Important:** Packages must be installed to `/shared/R-libs` so compute nodes can access them. Do NOT use `sudo` as it installs to `/usr/local/lib/R/site-library/` which is local to the head node.

**Critical:** Compute nodes do not have access to the head node's system R packages. You must install ALL dependencies (including base packages like R6, rlang, ggplot2, etc.) to the shared library. The `dependencies = TRUE` flag does NOT install packages to the shared library - it installs to the system library which compute nodes cannot access.

```bash
# Create shared R library directory
mkdir -p /shared/R-libs
export R_LIBS_USER=/shared/R-libs
echo "export R_LIBS_USER=/shared/R-libs" >> ~/.bashrc

# Install ALL 135 packages explicitly to shared library
# Compute nodes only have base R - every package must be in /shared/R-libs
Rscript -e "install.packages(c(
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
), lib = '/shared/R-libs', repos = 'https://cloud.r-project.org/')"

# Install cmdstanr from Stan repository (not on CRAN)
Rscript -e "install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev', 'https://cloud.r-project.org'), lib = '/shared/R-libs')"

# Install rstan (optional, for shinystan compatibility)
Rscript -e "install.packages('rstan', repos = 'https://cloud.r-project.org', lib = '/shared/R-libs')"
Rscript -e "install.packages('rstantools', repos = 'https://cloud.r-project.org', lib = '/shared/R-libs')"

# Install main packages (most dependencies already installed above)
Rscript -e "install.packages(c(
  'posterior',
  'bayesplot',
  'tidyverse'
), lib = '/shared/R-libs', repos = 'https://cloud.r-project.org/', dependencies = TRUE)"

# Set cmdstan path for R
Rscript -e "cmdstanr::set_cmdstan_path('/shared/cmdstan-2.34.1')"
```

**Note:** R packages compile from source on Linux. This takes 30-45 minutes for all 135 packages.

## Step 11: Run the Power Analysis

### Option A: Run Directly on Head Node

```bash
cd /shared/taurinelc

# Quick test (3 sample sizes, 10 reps each)
Rscript run_power_analysis.R --quick

# Full analysis (7 sample sizes, 100 reps each)
Rscript run_power_analysis.R
```

### Option B: Submit as Slurm Job (Single Node)

```bash
# Create logs directory
mkdir -p /shared/taurinelc/logs

# Submit job
sbatch /shared/taurinelc/cluster/slurm_power_analysis.sh

# Check job status
squeue

# Watch output
tail -f /shared/taurinelc/logs/power_*.out
```

### Option C: Submit as Job Array (Multiple Nodes - Recommended)

This runs each sample size on a separate compute node in parallel, reducing total runtime from ~2 hours to ~20 minutes.

```bash
# Create logs directory
mkdir -p /shared/taurinelc/logs

# Submit job array (launches 7 parallel jobs)
sbatch /shared/taurinelc/cluster/slurm_power_array.sh

# Check job status (you'll see 7 jobs running)
squeue

# Watch all outputs
tail -f /shared/taurinelc/logs/power_n*.out
```

### Monitoring Job Progress

Use the progress checker script to see how many simulations have completed on each node:

```bash
bash /shared/taurinelc/cluster/check_progress.sh
```

Example output:
```
=== Power Analysis Job Array Progress ===

Queue Status:
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
47_1   compute power_ar   ubuntu  R       5:00      1 compute-dy-c5xlarge-1
47_2   compute power_ar   ubuntu  R       5:00      1 compute-dy-c5xlarge-2
...

Completed Simulations per Node:
  Node 1 (N=120): 26/100
  Node 2 (N=180): 18/100
  Node 3 (N=240): 13/100
  Node 4 (N=300): 11/100
  Node 5 (N=360): 9/100
  Node 6 (N=420): 8/100
  Node 7 (N=480): 7/100

Saved Results:
  N=120: pending
  N=180: pending
  ...
```

**How it works:** The script counts occurrences of "All 4 chains finished" in each log file, which is printed by cmdstanr after every successful model fit.

### Combining Results

After ALL jobs complete, combine results:

```bash
cd /shared/taurinelc
Rscript combine_power_results.R
```

**Note:** Wait for all 7 array tasks to complete before running `combine_power_results.R`. Check with `squeue` - when it shows no jobs, all tasks are done.

## Step 12: Retrieve Results

After the analysis completes, copy results back to your local machine:

```bash
# From local machine
scp -i ~/.ssh/pcluster-key.pem \
    ubuntu@<HEAD_NODE_IP>:/shared/taurinelc/data/cached_results/*.rds \
    ./data/cached_results/
```

## Step 13: Clean Up (Important!)

**Delete the cluster when done to avoid charges:**

```bash
source .venv/bin/activate
pcluster delete-cluster --cluster-name taurine-cluster --region ca-central-1
```

Monitor deletion:
```bash
pcluster describe-cluster --cluster-name taurine-cluster --region ca-central-1
```

## Troubleshooting

### Cluster Creation Fails

Check CloudFormation events:
```bash
pcluster get-cluster-stack-events --cluster-name taurine-cluster --region ca-central-1
```

Common issues:
- **IAM permissions**: Add missing policies to your group
- **Subnet issues**: Make sure subnet is in the correct region
- **Key pair issues**: Ensure ed25519 key type for Ubuntu 22.04

### CmdStan Compilation Fails

Clean and retry:
```bash
cd /shared/cmdstan-2.34.1
make clean
make build -j2
```

### R Package Installation Fails

Check for missing system dependencies:
```bash
sudo apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev
```

### SSH Connection Refused

- Check security group allows inbound SSH (port 22)
- Verify you're using the correct key file
- Ensure the cluster is fully created (status: CREATE_COMPLETE)

## Cost Considerations

| Resource | Cost (approx) |
|----------|---------------|
| t3.large head node (8GB) | ~$0.083/hr |
| c5.xlarge compute nodes | ~$0.17/hr each |
| 50GB EBS storage | ~$4/month |

**Tip:** Compute nodes auto-scale. With MinCount: 0, you only pay when jobs are running.

## Reusing the EBS Volume (Skip Setup on Next Run)

With `DeletionPolicy: Retain`, the EBS volume persists after cluster deletion. This preserves CmdStan and all R packages (~$4/month storage cost).

**Important:** To reuse this volume, you must update `cluster-config.yaml` before creating a new cluster.

### Steps to reuse the retained volume:

1. **Find the volume ID** (after deleting the previous cluster):
   ```bash
   aws ec2 describe-volumes --filters "Name=tag:Name,Values=*shared-storage*" \
       --query 'Volumes[*].{ID:VolumeId,Size:Size,State:State}' --output table
   ```
   Or find it in AWS Console: EC2 → Volumes → look for "shared-storage"

2. **Update `cluster-config.yaml`** - replace the SharedStorage section:
   ```yaml
   SharedStorage:
     - MountDir: /shared
       Name: shared-storage
       StorageType: Ebs
       EbsSettings:
         VolumeId: vol-063e20ca6feca6b43
   ```

   Note: Remove the `Size`, `VolumeType`, and `DeletionPolicy` lines when using an existing volume.

3. **Create the new cluster** as normal:
   ```bash
   pcluster create-cluster --cluster-name taurine-cluster \
       --cluster-configuration cluster-config.yaml --region ca-central-1
   ```

4. **Skip to running the analysis** - CmdStan and R packages are already installed:
   ```bash
   ssh -i ~/.ssh/pcluster-key.pem ubuntu@<HEAD_NODE_IP>
   cd /shared/taurinelc
   Rscript run_power_analysis.R
   ```

### To delete the volume when no longer needed:

```bash
aws ec2 delete-volume --volume-id vol-063e20ca6feca6b43
```

Or use the AWS Console: EC2 → Volumes → Select volume → Actions → Delete volume.

## Maintaining R Packages

To audit installed packages and check for updates:

```bash
cd /shared/taurinelc
Rscript cluster/audit_packages.R
```

This outputs a CSV with all installed packages and flags any that are outdated.

## File Reference

```
cluster/
├── README.md               # This file
├── setup_cluster.sh        # Automated setup script for the cluster
├── deploy_to_cluster.sh    # Script to copy files to cluster
├── slurm_power_analysis.sh # Slurm job script (single node)
├── slurm_power_array.sh    # Slurm job array script (multi-node)
├── check_progress.sh       # Monitor job array progress (completed sims per node)
└── audit_packages.R        # R package version audit utility

# Project root (related files)
├── run_power_analysis.R    # Main script (sequential)
├── run_single_n.R          # Single sample size script (for job arrays)
└── combine_power_results.R # Combine job array results
```

## Quick Reference Commands

```bash
# Activate ParallelCluster CLI
source .venv/bin/activate

# Check cluster status
pcluster describe-cluster --cluster-name taurine-cluster --region ca-central-1

# SSH into cluster
ssh -i ~/.ssh/pcluster-key.pem ubuntu@<HEAD_NODE_IP>

# Delete cluster (IMPORTANT when done!)
pcluster delete-cluster --cluster-name taurine-cluster --region ca-central-1
```
