#!/bin/bash
#SBATCH --job-name=type1_array
#SBATCH --output=/shared/taurinelc/logs/type1_n%a_%j.out
#SBATCH --error=/shared/taurinelc/logs/type1_n%a_%j.err
#SBATCH --partition=compute
#SBATCH --array=1-7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=06:00:00
#SBATCH --mem=6G

# Slurm job array script for running Type I error analysis
# Uses more replications (500) for stable estimates
# Each array task handles one sample size

echo "=== Starting Type I error analysis array task ==="
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Set up environment
export CMDSTAN=/shared/cmdstan-2.37.0
export R_LIBS_USER=/shared/R-libs

# Create logs directory if it doesn't exist
mkdir -p /shared/taurinelc/logs

# Sample sizes array (1-indexed to match SLURM_ARRAY_TASK_ID)
SAMPLE_SIZES=(0 120 180 240 300 360 420 480)
N=${SAMPLE_SIZES[$SLURM_ARRAY_TASK_ID]}

echo "Processing sample size N = $N"
echo ""

# Change to project directory
cd /shared/taurinelc

# Run the Type I error analysis for this sample size
# Using 500 replications for stable estimate
SEED=$((5000 + SLURM_ARRAY_TASK_ID * 1000))
Rscript run_single_n_type1.R --n=$N --reps=500 --seed=$SEED --threshold=0.95

echo ""
echo "=== Array task complete ==="
echo "End time: $(date)"
