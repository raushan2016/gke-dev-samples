# GKE Migration Self-Serve Package

This package demonstrates a robust, production-ready pattern for creating GKE clusters and deploying resources using the official `hashicorp/kubernetes` provider, eliminating the need for 3rd party providers like `gavinbunney/kubectl`.

## The Challenge
The `hashicorp/kubernetes` provider requires access to the Kubernetes API server to plan resources. When creating a cluster and resources in the same logic, the API server doesn't exist yet, causing "connection refused" errors or unpredictable planning failures ("Chicken-and-Egg" problem).

## The Solution: Layered Architecture
This project uses a **Layered Architecture** to separate the *Infrastructure* (Cluster) from the *Workloads* (Manifests).

- **Layer 1 (`layers/01-infra`)**: Creates the GKE Cluster, VPCs, and Node Pools.
- **Layer 2 (`layers/02-workloads`)**: Configures the Kubernetes Provider using the API endpoint created in Layer 1, and applies manifests.

## Usage

### Prerequisites
- Google Cloud SDK (`gcloud`) installed and authorized.
- Terraform `>= 1.5.7`.
- A GCP Project where you have permissions to create GKE clusters.

### Quick Start
1. **Set your Project ID**:
   ```bash
   export PROJECT_ID=your-project-id
   ```

2. **Run the Installer**:
   This script automates the two-step apply process.
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Cleanup**:
   ```bash
   chmod +x destroy.sh
   ./destroy.sh
   ```

## Production Configuration (GCS Backend)
By default, this package uses a local backend (`terraform.tfstate`) for simplicity. For production, you should use a GCS backend.

### 1. Create a GCS Bucket
Create a bucket to store your state (e.g., `my-terraform-state`).

### 2. Update `layers/01-infra/versions.tf`
Add the backend configuration:
```hcl
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "infra"
  }
}
```

### 3. Update `layers/02-workloads/versions.tf`
Add the backend configuration:
```hcl
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "workloads"
  }
}
```

### 4. Update `layers/02-workloads/data.tf`
Update the `terraform_remote_state` data source to point to the GCS bucket instead of the local path:
```hcl
data "terraform_remote_state" "infra" {
  backend = "gcs"

  config = {
    bucket = "my-terraform-state"
    prefix = "infra"
  }
}
```
This ensures that the workloads layer can find the cluster endpoint from the central state store.

## Directory Structure
```text
.
├── install.sh           # Orchestration script to run layers in order
├── destroy.sh           # Script to tear down layers in reverse order
├── layers
│   ├── 01-infra         # Layer 1: GKE Cluster
│   └── 02-workloads     # Layer 2: Kubernetes Manifests (Official Provider)
```

## Benefits of Migration
1. **Stability & Support**: The official provider is maintained by HashiCorp/Google and aligns with the Terraform ecosystem's best practices.
2. **Server-Side Apply**: The `kubernetes_manifest` resource uses Server-Side Apply (SSA), which is the native Kubernetes method for declarative config management, handling drift detection better than client-side approaches.
3. **Security**: Removes dependencies on unmaintained 3rd party providers.
