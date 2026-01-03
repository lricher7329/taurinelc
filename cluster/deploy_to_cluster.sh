#!/bin/bash
# Deploy project files to ParallelCluster
# Run this from your local machine

CLUSTER_IP="15.156.64.112"
KEY_FILE="$HOME/.ssh/pcluster-key.pem"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Deploying taurinelc to ParallelCluster ==="
echo "Source: $PROJECT_DIR"
echo "Target: ubuntu@${CLUSTER_IP}:/shared/taurinelc/"
echo ""

# Create target directory on cluster
ssh -i "$KEY_FILE" ubuntu@${CLUSTER_IP} "mkdir -p /shared/taurinelc/logs"

# Sync project files (excluding large/unnecessary files)
rsync -avz --progress \
    --exclude '.git' \
    --exclude '.venv' \
    --exclude '_archive' \
    --exclude '_output' \
    --exclude 'data/cached_results/*.rds' \
    --exclude '*.o' \
    --exclude '*.so' \
    --exclude 'node_modules' \
    -e "ssh -i $KEY_FILE" \
    "$PROJECT_DIR/" \
    ubuntu@${CLUSTER_IP}:/shared/taurinelc/

echo ""
echo "=== Deployment complete! ==="
echo ""
echo "Next steps:"
echo "1. SSH into cluster: ssh -i $KEY_FILE ubuntu@${CLUSTER_IP}"
echo "2. Run setup script: bash /shared/taurinelc/cluster/setup_cluster.sh"
echo "3. Submit job: sbatch /shared/taurinelc/cluster/slurm_power_analysis.sh"
