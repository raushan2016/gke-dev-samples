#!/bin/bash
set -e

# Usage:
# ./switch_backend.sh local
# ./switch_backend.sh gcs <bucket_name>

MODE=$1
BUCKET_NAME=$2

if [[ "$MODE" != "local" && "$MODE" != "gcs" ]]; then
  echo "Usage: $0 {local|gcs <bucket_name>}"
  exit 1
fi

if [[ "$MODE" == "gcs" && -z "$BUCKET_NAME" ]]; then
  echo "Error: Bucket name required for GCS mode."
  echo "Usage: $0 gcs <bucket_name>"
  exit 1
fi

echo "Switching to $MODE backend..."

# --- FUNCTIONS ---

# Function to write local versions.tf
write_local_versions() {
  cat <<EOF > $1
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
  }
}
EOF
}

# Function to write GCS versions.tf
write_gcs_versions() {
  cat <<EOF > $1
terraform {
  required_version = ">= 1.5.7"
  backend "gcs" {
    bucket = "${BUCKET_NAME}"
    prefix = "$2"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
  }
}
EOF
}

# --- EXECUTION ---

if [[ "$MODE" == "local" ]]; then
  # 1. Update Infra versions.tf
  echo "Updating layers/01-infra/versions.tf..."
  write_local_versions "layers/01-infra/versions.tf"

  # 2. Update Workloads versions.tf
  echo "Updating layers/02-workloads/versions.tf..."
  write_local_versions "layers/02-workloads/versions.tf"

  # 3. Update Workloads data.tf
  echo "Updating layers/02-workloads/data.tf..."
  cat <<EOF > layers/02-workloads/data.tf
data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "\${path.module}/../01-infra/terraform.tfstate"
  }
}
EOF

else
  # GCS MODE
  # 1. Update Infra versions.tf
  echo "Updating layers/01-infra/versions.tf..."
  write_gcs_versions "layers/01-infra/versions.tf" "infra"

  # 2. Update Workloads versions.tf
  echo "Updating layers/02-workloads/versions.tf..."
  write_gcs_versions "layers/02-workloads/versions.tf" "workloads"

  # 3. Update Workloads data.tf
  echo "Updating layers/02-workloads/data.tf..."
  cat <<EOF > layers/02-workloads/data.tf
data "terraform_remote_state" "infra" {
  backend = "gcs"

  config = {
    bucket = "${BUCKET_NAME}"
    prefix = "infra"
  }
}
EOF

fi

echo "Files updated."
echo "IMPORTANT: Now run 'terraform init -migrate-state' in both directories if you have existing state."
