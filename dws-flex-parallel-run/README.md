# GKE ProvisioningRequest Experiment (DWS Flex + TPU)

This directory contains experimental scripts to demonstrate using the `ProvisioningRequest` API to safely specific **TPU** capacity for GKE workloads. This method avoids the "stuck node pool creation" issue by separating capacity reservation from workload execution.

## Overview

The workflow demonstrates:
1.  **Check**: Submitting a `ProvisioningRequest` to ask GKE "Do you have this TPU capacity?".
2.  **Wait**: Polling the request status (`Provisioned` vs `Failed`).
3.  **Act**: 
    -   If `Provisioned`: Submitting the Job to consume the capacity.
    -   If `Failed` (or Timeout): Deleting the request *without* ever creating a stuck node pool.

## Files

-   `provisioning-request.yaml`: Template for the capacity request.
-   `job.yaml`: Template for the workload job.
-   `run_provisioning_experiment.sh`: Main driver script (Single Job).
-   `run_parallel_reuse_experiment.sh`: Driver script for **Parallel Submission & Reuse**.
-   `cleanup.sh`: Helper to clean up all generated resources (provreq, jobs).

## Usage

### 1. Basic Experiment (Single Job)

```bash
./run_provisioning_experiment.sh
```

### 2. Parallel Reuse Experiment

This scenario submits **two** requests in parallel. Whichever provisions first "wins". The other is cancelled. The first node pool is then **reused** for the second job.

```bash
./run_parallel_reuse_experiment.sh
```

**Environment Variables:**

```bash
# Example for a TPU v4-8
export TPU_TYPE="tpu-v4-podslice"
export TPU_TOPOLOGY="2x2x1"
export COUNT=1
./run_parallel_reuse_experiment.sh
```

### 3. Cleanup

To remove all artifacts:

```bash
./cleanup.sh
```
