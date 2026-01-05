#!/bin/bash
#SBATCH --job-name=assurance_array
#SBATCH --output=/shared/taurinelc/logs/assurance_n%a_%j.out
#SBATCH --error=/shared/taurinelc/logs/assurance_n%a_%j.err
#SBATCH --partition=compute
#SBATCH --array=1-7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:30:00
#SBATCH --mem=6G

# Slurm job array script for running assurance analysis across multiple nodes
# Each array task handles one sample size

echo "=== Starting assurance analysis array task ==="
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

# Run the assurance analysis for this sample size
SEED=$((2234 + SLURM_ARRAY_TASK_ID * 1000))
Rscript run_single_n_assurance.R --n=$N --reps=100 --seed=$SEED

echo ""
echo "=== Array task complete ==="
echo "End time: $(date)"
