#!/bin/bash

# run_provisioning_experiment.sh
# Demonstrates how to use ProvisioningRequest to safely request TPU capacity.

set -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TIMESTAMP=$(date +%s)

# Defaults for TPU
# Example: v4-8 (Type: tpu-v4-podslice, Topology: 2x2x1)
# You must adjust these to match your standard TPU machine definitions or DWS Flex requests.
TPU_TYPE="tpu-v4-podslice"
TPU_TOPOLOGY="2x2x1"
TPUS_PER_NODE=4 # For v4-8, it usually presents as 4 chips (or 8 cores) depending on k8s version, often request: 4
COUNT=1
TIMEOUT_SECONDS=300

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

generate_yaml() {
    local template=$1
    local output=$2
    envsubst < "$template" > "$output"
}

export PROVISIONING_REQUEST_NAME="prov-req-${TIMESTAMP}"
export POD_TEMPLATE_NAME="pod-tmpl-${TIMESTAMP}"
export JOB_NAME="job-${TIMESTAMP}"
export COUNT
export TPU_TYPE
export TPU_TOPOLOGY
export TPUS_PER_NODE

log "Starting ProvisioningRequest Experiment (TPU)"
log "Request Name: $PROVISIONING_REQUEST_NAME"
log "TPU Type: $TPU_TYPE, Topology: $TPU_TOPOLOGY"

# 1. Generate Manifests
generate_yaml "$DIR/provisioning-request.yaml" "$DIR/generated-provreq-${TIMESTAMP}.yaml"
generate_yaml "$DIR/job.yaml" "$DIR/generated-job-${TIMESTAMP}.yaml"

# 2. Apply ProvisioningRequest
log "step 1: Submitting ProvisioningRequest..."
kubectl apply -f "$DIR/generated-provreq-${TIMESTAMP}.yaml"

# 3. Watch Loop
log "step 2: Waiting for capacity (Timeout: ${TIMEOUT_SECONDS}s)..."
START_TIME=$(date +%s)
PROVISIONED="false"

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [[ $ELAPSED -gt $TIMEOUT_SECONDS ]]; then
        log "TIMEOUT REACHED! Capacity not provisioned in time."
        break
    fi

    STATUS=$(kubectl get provreq "$PROVISIONING_REQUEST_NAME" -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}' 2>/dev/null)
    FAILED=$(kubectl get provreq "$PROVISIONING_REQUEST_NAME" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
    
    if [[ "$STATUS" == "True" ]]; then
        log "SUCCESS: Capacity is Provisioned!"
        PROVISIONED="true"
        break
    fi
    
    if [[ "$FAILED" == "True" ]]; then
       REASON=$(kubectl get provreq "$PROVISIONING_REQUEST_NAME" -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}')
       log "FAILED: Provisioning failed. Reason: $REASON"
       break
    fi
    
    log "Waiting... ($ELAPSED / $TIMEOUT_SECONDS s)"
    sleep 10
done

# 4. Decision: Submit Job or Abort
if [[ "$PROVISIONED" == "true" ]]; then
    log "step 3: Submitting Workload Job..."
    kubectl apply -f "$DIR/generated-job-${TIMESTAMP}.yaml"
    log "Job submitted. Monitor with: kubectl get jobs $JOB_NAME"
else
    log "step 3: ABORTING. Request was not provisioned."
    log "Cleaning up ProvisioningRequest to prevent Stuck Node Pools..."
    kubectl delete -f "$DIR/generated-provreq-${TIMESTAMP}.yaml" --wait=false
    log "Request deleted."
    exit 1
fi
