#!/bin/bash
#SBATCH --job-name=taurine_power
#SBATCH --output=/shared/taurinelc/logs/power_%j.out
#SBATCH --error=/shared/taurinelc/logs/power_%j.err
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=04:00:00
#SBATCH --mem=6G

# Slurm job script for running power analysis on ParallelCluster

echo "=== Starting power analysis job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Set up environment
export CMDSTAN=/shared/cmdstan-2.34.1
export R_LIBS_USER=/shared/R-libs

# Create logs directory if it doesn't exist
mkdir -p /shared/taurinelc/logs

# Change to project directory
cd /shared/taurinelc

# Run the power analysis
echo "Running power analysis..."
Rscript run_power_analysis.R

echo ""
echo "=== Job complete ==="
echo "End time: $(date)"
