#!/bin/bash
# ═════════════════════════════════════════════════════════════════════
#  entrypoint.sh — Traffic Violation Detection System
#
#  Runs before live_test.py on every container start.
#  Handles model loading for both environments:
#
#  LOCAL (EC2 / Docker Compose):
#    /app/models/ is already filled by volume mount
#    → skips S3 download, starts app immediately
#
#  EKS / Production:
#    /app/models/ is empty (no volume mount)
#    → pulls models from S3 bucket defined in MODEL_BUCKET env var
#    → then starts app
# ═════════════════════════════════════════════════════════════════════
set -e

echo "========================================"
echo " Traffic Violation Detection — Starting"
echo "========================================"

# ── Check if models are already present (volume mount on local) ───────
if [ -z "$(ls -A /app/models 2>/dev/null)" ]; then
    echo "[models] /app/models/ is empty"

    # ── Try S3 pull (EKS / production) ───────────────────────────────
    if [ -n "$MODEL_BUCKET" ]; then
        echo "[models] MODEL_BUCKET=$MODEL_BUCKET — pulling from S3..."
        aws s3 sync s3://${MODEL_BUCKET}/models/ /app/models/ \
            --region ${AWS_DEFAULT_REGION:-us-east-1} \
            --only-show-errors

        echo "[models] S3 sync complete"
        echo "[models] Contents:"
        find /app/models -name "*.pt" | sort

    else
        # No volume mount AND no S3 bucket — warn but don't crash
        # (let live_test.py give a proper error about missing models)
        echo "[models] WARNING: MODEL_BUCKET is not set and /app/models/ is empty"
        echo "[models] On EKS: set MODEL_BUCKET env var in your deployment.yaml"
        echo "[models] Locally: ensure volume mount is set in docker-compose.yml"
        echo "[models] Continuing — live_test.py will report missing model files"
    fi

else
    # Models already present — volume mount is working (local EC2)
    echo "[models] Models found via volume mount:"
    find /app/models -name "*.pt" | sort
    echo "[models] Skipping S3 download"
fi

echo "========================================"
echo "[app] Starting: $@"
echo "========================================"

# Hand off to CMD (python live_test.py)
exec "$@"
