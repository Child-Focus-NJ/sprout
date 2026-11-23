#!/bin/bash
set -euo pipefail

REGION="us-east-1"

echo "============================================"
echo " Sprout LocalStack Bootstrap"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# 1. S3 Bucket
# ---------------------------------------------------------------------------
echo "--- Creating S3 bucket ---"

awslocal s3 mb "s3://sprout-reports" \
  --region "$REGION" 2>/dev/null || true

echo "  Created: sprout-reports"

# ---------------------------------------------------------------------------
# 2. Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Sprout LocalStack Bootstrap Complete"
echo "============================================"
echo ""
echo "S3 Buckets:"
echo "  - sprout-reports"
echo ""
echo "============================================"
