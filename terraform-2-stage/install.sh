#!/bin/bash
set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
REGION="us-central1"
# Cluster name is still needed for Layer 1 input
CLUSTER_NAME="raushankr-tf-cluster"

echo "==================================================="
echo "   GKE Migration Self-Serve Package Installer"
echo "==================================================="
echo "Project ID: $PROJECT_ID"
echo "Region:     $REGION"
echo "Cluster:    $CLUSTER_NAME"
echo "==================================================="

# --- Layer 1: Infrastructure ---
echo ""
echo "=> [1/2] Deploying Infrastructure (GKE Cluster)..."
cd layers/01-infra

# Init if needed
if [ ! -d ".terraform" ]; then
  terraform init
fi

terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" \
  -var="cluster_name=$CLUSTER_NAME"

cd ../..

# --- Layer 2: Workloads ---
echo ""
echo "=> [2/2] Deploying Workloads (Kubernetes Manifests)..."
cd layers/02-workloads

# Init if needed
if [ ! -d ".terraform" ]; then
  terraform init
fi

# Note: No need to pass cluster endpoint/certificates anymore!
# Terraform reads them directly from ../01-infra/terraform.tfstate
terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" 

echo ""
echo "==================================================="
echo "   Deployment Complete!"
echo "==================================================="
