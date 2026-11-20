#!/bin/bash
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID="000000000000"

echo "============================================"
echo " Sprout LocalStack Bootstrap"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# 1. SQS Dead-Letter Queues
# ---------------------------------------------------------------------------
echo "--- Creating SQS dead-letter queues ---"

awslocal sqs create-queue \
  --queue-name sprout-zoom-attendance-dlq \
  --region "$REGION" 2>/dev/null || true

awslocal sqs create-queue \
  --queue-name sprout-mailchimp-batch-dlq \
  --region "$REGION" 2>/dev/null || true

echo "  Created: sprout-zoom-attendance-dlq"
echo "  Created: sprout-mailchimp-batch-dlq"

# ---------------------------------------------------------------------------
# 2. SQS Main Queues with Redrive Policies
# ---------------------------------------------------------------------------
echo ""
echo "--- Creating SQS main queues with redrive policies ---"

ZOOM_DLQ_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url "http://sqs.$REGION.localhost.localstack.cloud:4566/$ACCOUNT_ID/sprout-zoom-attendance-dlq" \
  --attribute-names QueueArn \
  --region "$REGION" \
  --query 'Attributes.QueueArn' \
  --output text)

MAILCHIMP_DLQ_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url "http://sqs.$REGION.localhost.localstack.cloud:4566/$ACCOUNT_ID/sprout-mailchimp-batch-dlq" \
  --attribute-names QueueArn \
  --region "$REGION" \
  --query 'Attributes.QueueArn' \
  --output text)

awslocal sqs create-queue \
  --queue-name sprout-zoom-attendance \
  --region "$REGION" \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"${ZOOM_DLQ_ARN}\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" \
  2>/dev/null || true

awslocal sqs create-queue \
  --queue-name sprout-mailchimp-batch \
  --region "$REGION" \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"${MAILCHIMP_DLQ_ARN}\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" \
  2>/dev/null || true

echo "  Created: sprout-zoom-attendance (DLQ ARN: $ZOOM_DLQ_ARN)"
echo "  Created: sprout-mailchimp-batch (DLQ ARN: $MAILCHIMP_DLQ_ARN)"

# ---------------------------------------------------------------------------
# 3. S3 Bucket
# ---------------------------------------------------------------------------
echo ""
echo "--- Creating S3 bucket ---"

awslocal s3 mb "s3://sprout-reports" \
  --region "$REGION" 2>/dev/null || true

echo "  Created: sprout-reports"

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Sprout LocalStack Bootstrap Complete"
echo "============================================"
echo ""
echo "SQS Queues:"
echo "  - sprout-zoom-attendance       (DLQ: sprout-zoom-attendance-dlq, maxReceiveCount: 3)"
echo "  - sprout-mailchimp-batch       (DLQ: sprout-mailchimp-batch-dlq, maxReceiveCount: 3)"
echo ""
echo "S3 Buckets:"
echo "  - sprout-reports"
echo ""
echo "============================================"
