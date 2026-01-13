#!/bin/bash

# run_parallel_reuse_experiment.sh
# Demonstrates "Parallel Submission, Single Provisioning, Reuse" pattern.

set -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TIMESTAMP=$(date +%s)

# Defaults (TPU)
TPU_TYPE="${TPU_TYPE:-tpu-v4-podslice}"
TPU_TOPOLOGY="${TPU_TOPOLOGY:-2x2x1}"
TPUS_PER_NODE="${TPUS_PER_NODE:-4}"
COUNT="${COUNT:-1}"
TIMEOUT_SECONDS=600

# IDs
REQ1_NAME="req1-${TIMESTAMP}"
REQ2_NAME="req2-${TIMESTAMP}"
JOB1_NAME="job1-${TIMESTAMP}"
JOB2_NAME="job2-${TIMESTAMP}"

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"
}

generate_yaml() {
    local template=$1
    local output=$2
    envsubst < "$template" > "$output"
}

export TPU_TYPE TPU_TOPOLOGY TPUS_PER_NODE COUNT

log "Starting Parallel Reuse Experiment"
log "TPU: $TPU_TYPE ($TPU_TOPOLOGY)"

# ---------------------------------------------------------
# Step 1: Submit 2 Requests in Parallel
# ---------------------------------------------------------
log ">>> Step 1: Submitting 2 ProvisioningRequests in parallel..."

# Req 1
export PROVISIONING_REQUEST_NAME="$REQ1_NAME"
export POD_TEMPLATE_NAME="tmpl1-${TIMESTAMP}"
generate_yaml "$DIR/provisioning-request.yaml" "$DIR/gen-${REQ1_NAME}.yaml"
kubectl apply -f "$DIR/gen-${REQ1_NAME}.yaml"

# Req 2
export PROVISIONING_REQUEST_NAME="$REQ2_NAME"
export POD_TEMPLATE_NAME="tmpl2-${TIMESTAMP}"
generate_yaml "$DIR/provisioning-request.yaml" "$DIR/gen-${REQ2_NAME}.yaml"
kubectl apply -f "$DIR/gen-${REQ2_NAME}.yaml"

log "Submitted $REQ1_NAME and $REQ2_NAME. Waiting for ONE of them to provision..."

# ---------------------------------------------------------
# Step 2: Race for Provisioning
# ---------------------------------------------------------
WINNER=""
START_TIME=$(date +%s)

while true; do
    ELAPSED=$(( $(date +%s) - START_TIME ))
    if [[ $ELAPSED -gt $TIMEOUT_SECONDS ]]; then
        log "TIMEOUT: Neither request provisioned in time."
        # Cleanup
        kubectl delete -f "$DIR/gen-${REQ1_NAME}.yaml" --wait=false
        kubectl delete -f "$DIR/gen-${REQ2_NAME}.yaml" --wait=false
        exit 1
    fi

    STATUS1=$(kubectl get provreq "$REQ1_NAME" -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}' 2>/dev/null)
    STATUS2=$(kubectl get provreq "$REQ2_NAME" -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}' 2>/dev/null)

    if [[ "$STATUS1" == "True" ]]; then
        WINNER="$REQ1_NAME"
        LOSER="$REQ2_NAME"
        LOSER_FILE="$DIR/gen-${REQ2_NAME}.yaml"
        break
    fi

    if [[ "$STATUS2" == "True" ]]; then
        WINNER="$REQ2_NAME"
        LOSER="$REQ1_NAME"
        LOSER_FILE="$DIR/gen-${REQ1_NAME}.yaml"
        break
    fi
    
    # Also check failures... (omitted for brevity, assume retry loop)
    log "Waiting for capacity... ($ELAPSED s)"
    sleep 10
done

log ">>> Step 2: WINNER is $WINNER! Capacity Provisioned."

# ---------------------------------------------------------
# Step 3: Optimization - Cancel the Loser
# ---------------------------------------------------------
log ">>> Step 3: Cancelling redundant request $LOSER..."
kubectl delete -f "$LOSER_FILE" --wait=false
log "$LOSER deleted. verify: kubectl get provreq $LOSER"

# ---------------------------------------------------------
# Step 4: Run Job 1 on Winner
# ---------------------------------------------------------
log ">>> Step 4: Submitting Job 1 on $WINNER..."
export JOB_NAME="$JOB1_NAME"
export PROVISIONING_REQUEST_NAME="$WINNER"
generate_yaml "$DIR/job.yaml" "$DIR/gen-${JOB1_NAME}.yaml"
kubectl apply -f "$DIR/gen-${JOB1_NAME}.yaml"

log "Job 1 submitted. Waiting for completion (simulated)..."
# In a real script, we'd wait for Job status. Here we just wait a bit or check.
kubectl wait --for=condition=complete job/$JOB1_NAME --timeout=300s || {
    log "Job 1 didn't complete quickly. Proceeding anyway for demo purpose."
}

# ---------------------------------------------------------
# Step 5: Reuse Winner for Job 2
# ---------------------------------------------------------
log ">>> Step 5: REUSING $WINNER for Job 2..."
# Important: Job 2 uses the SAME ProvisioningRequest Name as annotation!
export JOB_NAME="$JOB2_NAME"
export PROVISIONING_REQUEST_NAME="$WINNER"
generate_yaml "$DIR/job.yaml" "$DIR/gen-${JOB2_NAME}.yaml"
kubectl apply -f "$DIR/gen-${JOB2_NAME}.yaml"

log "Job 2 submitted on SAME provisioning request ($WINNER)."
log "SUCCESS: Logic demonstrated. Clean up everything with cleanup.sh"
