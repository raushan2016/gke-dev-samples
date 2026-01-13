#!/bin/bash
set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
REGION="us-central1"
CLUSTER_NAME="migration-demo-cluster"

echo "==================================================="
echo "   GKE Migration Self-Serve Package Destructor"
echo "==================================================="
echo "WARNING: This will destroy your cluster and workloads."
echo "==================================================="

# --- Layer 2: Workloads ---
echo ""
echo "=> [1/2] Destroying Workloads..."
cd layers/02-workloads

# No need to fetch variables manually. Terraform state handles the dependency.
# IMPORTANT: Layer 1 state must still exist for this to work, as the provider
# config relies on reading the endpoint from it.
terraform destroy -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" 

cd ../..

# --- Layer 1: Infrastructure ---
echo ""
echo "=> [2/2] Destroying Infrastructure..."
cd layers/01-infra

terraform destroy -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" \
  -var="cluster_name=$CLUSTER_NAME"

echo ""
echo "==================================================="
echo "   Destruction Complete!"
echo "==================================================="
