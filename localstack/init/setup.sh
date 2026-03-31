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
# 4. Lambda Functions (stub handlers)
# ---------------------------------------------------------------------------
echo ""
echo "--- Creating Lambda functions ---"

# Build a minimal Ruby handler zip
LAMBDA_DIR=$(mktemp -d)
cat > "$LAMBDA_DIR/handler.rb" << 'RUBY'
def handler(event:, context:)
  {
    statusCode: 200,
    headers: { "Content-Type" => "application/json" },
    body: '{"status":"ok"}'
  }
end
RUBY

(cd "$LAMBDA_DIR" && zip -j handler.zip handler.rb) > /dev/null

LAMBDA_FUNCTIONS=(
  "sprout-zoom-meeting"
  "sprout-zoom-attendance"
  "sprout-volunteer-management-system-sync"
  "sprout-mailchimp-realtime"
  "sprout-mailchimp-batch"
  "sprout-vms"
  "sprout-vms-session-refresh"
)

for fn in "${LAMBDA_FUNCTIONS[@]}"; do
  # Delete existing function to make the script idempotent
  awslocal lambda delete-function \
    --function-name "$fn" \
    --region "$REGION" 2>/dev/null || true

  awslocal lambda create-function \
    --function-name "$fn" \
    --runtime ruby3.3 \
    --handler handler.handler \
    --role "arn:aws:iam::${ACCOUNT_ID}:role/lambda-role" \
    --zip-file "fileb://${LAMBDA_DIR}/handler.zip" \
    --region "$REGION" > /dev/null

  echo "  Created Lambda: $fn"
done

# Wait briefly for functions to be ready
sleep 2

# Clean up temp directory
rm -rf "$LAMBDA_DIR"

# ---------------------------------------------------------------------------
# 5. SQS -> Lambda Event Source Mappings
# ---------------------------------------------------------------------------
echo ""
echo "--- Creating SQS -> Lambda event source mappings ---"

ZOOM_QUEUE_ARN="arn:aws:sqs:${REGION}:${ACCOUNT_ID}:sprout-zoom-attendance"
MAILCHIMP_QUEUE_ARN="arn:aws:sqs:${REGION}:${ACCOUNT_ID}:sprout-mailchimp-batch"

awslocal lambda create-event-source-mapping \
  --function-name sprout-zoom-attendance \
  --event-source-arn "$ZOOM_QUEUE_ARN" \
  --batch-size 1 \
  --region "$REGION" > /dev/null 2>&1 || true

echo "  Mapped: sprout-zoom-attendance queue -> sprout-zoom-attendance Lambda"

awslocal lambda create-event-source-mapping \
  --function-name sprout-mailchimp-batch \
  --event-source-arn "$MAILCHIMP_QUEUE_ARN" \
  --batch-size 10 \
  --region "$REGION" > /dev/null 2>&1 || true

echo "  Mapped: sprout-mailchimp-batch queue -> sprout-mailchimp-batch Lambda"

# ---------------------------------------------------------------------------
# 6. API Gateway REST API
# ---------------------------------------------------------------------------
echo ""
echo "--- Creating API Gateway REST API ---"

# Create the REST API
API_ID=$(awslocal apigateway create-rest-api \
  --name sprout-api \
  --region "$REGION" \
  --query 'id' \
  --output text)

echo "  API ID: $API_ID"

# Get the root resource ID
ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region "$REGION" \
  --query 'items[0].id' \
  --output text)

# Helper function to create a resource under a parent
create_resource() {
  local parent_id="$1"
  local path_part="$2"
  awslocal apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$parent_id" \
    --path-part "$path_part" \
    --region "$REGION" \
    --query 'id' \
    --output text
}

# Helper function to wire POST method -> Lambda integration
create_post_integration() {
  local resource_id="$1"
  local lambda_name="$2"
  local lambda_arn="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${lambda_name}"

  awslocal apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method POST \
    --authorization-type NONE \
    --region "$REGION" > /dev/null

  awslocal apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${lambda_arn}/invocations" \
    --region "$REGION" > /dev/null
}

# --- /zoom ---
ZOOM_ID=$(create_resource "$ROOT_ID" "zoom")

# POST /zoom/meeting -> sprout-zoom-meeting
ZOOM_MEETING_ID=$(create_resource "$ZOOM_ID" "meeting")
create_post_integration "$ZOOM_MEETING_ID" "sprout-zoom-meeting"
echo "  POST /zoom/meeting -> sprout-zoom-meeting"

# --- /volunteer-management-system ---
VMS_ID=$(create_resource "$ROOT_ID" "volunteer-management-system")

# POST /volunteer-management-system/sync -> sprout-volunteer-management-system-sync
VMS_SYNC_ID=$(create_resource "$VMS_ID" "sync")
create_post_integration "$VMS_SYNC_ID" "sprout-volunteer-management-system-sync"
echo "  POST /volunteer-management-system/sync -> sprout-volunteer-management-system-sync"

# --- /vms ---
VMS_ROOT_ID=$(create_resource "$ROOT_ID" "vms")

# Helper for wiring any HTTP method -> Lambda integration
create_method_integration() {
  local resource_id="$1"
  local http_method="$2"
  local lambda_name="$3"
  local lambda_arn="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${lambda_name}"

  awslocal apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --authorization-type NONE \
    --region "$REGION" > /dev/null

  awslocal apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${lambda_arn}/invocations" \
    --region "$REGION" > /dev/null
}

# POST /vms/session/refresh -> sprout-vms-session-refresh
VMS_SESSION_ID=$(create_resource "$VMS_ROOT_ID" "session")
VMS_SESSION_REFRESH_ID=$(create_resource "$VMS_SESSION_ID" "refresh")
create_post_integration "$VMS_SESSION_REFRESH_ID" "sprout-vms-session-refresh"
echo "  POST /vms/session/refresh -> sprout-vms-session-refresh"

# GET, POST /vms/inquiries -> sprout-vms
VMS_INQUIRIES_ID=$(create_resource "$VMS_ROOT_ID" "inquiries")
create_method_integration "$VMS_INQUIRIES_ID" "GET" "sprout-vms"
create_post_integration "$VMS_INQUIRIES_ID" "sprout-vms"
echo "  GET /vms/inquiries -> sprout-vms"
echo "  POST /vms/inquiries -> sprout-vms"

# PUT, DELETE /vms/inquiries/{id} -> sprout-vms
VMS_INQUIRY_ID_RES=$(create_resource "$VMS_INQUIRIES_ID" "{id}")
create_method_integration "$VMS_INQUIRY_ID_RES" "PUT" "sprout-vms"
create_method_integration "$VMS_INQUIRY_ID_RES" "DELETE" "sprout-vms"
echo "  PUT /vms/inquiries/{id} -> sprout-vms"
echo "  DELETE /vms/inquiries/{id} -> sprout-vms"

# GET, POST /vms/volunteers -> sprout-vms
VMS_VOLUNTEERS_ID=$(create_resource "$VMS_ROOT_ID" "volunteers")
create_method_integration "$VMS_VOLUNTEERS_ID" "GET" "sprout-vms"
create_post_integration "$VMS_VOLUNTEERS_ID" "sprout-vms"
echo "  GET /vms/volunteers -> sprout-vms"
echo "  POST /vms/volunteers -> sprout-vms"

# GET /vms/lookups/{type} -> sprout-vms
VMS_LOOKUPS_ID=$(create_resource "$VMS_ROOT_ID" "lookups")
VMS_LOOKUP_TYPE_ID=$(create_resource "$VMS_LOOKUPS_ID" "{type}")
create_method_integration "$VMS_LOOKUP_TYPE_ID" "GET" "sprout-vms"
echo "  GET /vms/lookups/{type} -> sprout-vms"

# --- Secrets Manager for VMS session ---
echo ""
echo "--- Creating Secrets Manager secret for VMS session ---"
awslocal secretsmanager delete-secret \
  --secret-id "sprout/vms-session" \
  --force-delete-without-recovery \
  --region "$REGION" 2>/dev/null || true

awslocal secretsmanager create-secret \
  --name "sprout/vms-session" \
  --secret-string '{"base_url":"https://nj-passaic.evintotraining.com","username":"","password":"","cookies":{},"refreshed_at":""}' \
  --region "$REGION" > /dev/null
echo "  Created: sprout/vms-session (populate credentials manually)"

# --- /mailchimp ---
MAILCHIMP_ID=$(create_resource "$ROOT_ID" "mailchimp")

# POST /mailchimp/send-email -> sprout-mailchimp-realtime
MC_SEND_EMAIL_ID=$(create_resource "$MAILCHIMP_ID" "send-email")
create_post_integration "$MC_SEND_EMAIL_ID" "sprout-mailchimp-realtime"
echo "  POST /mailchimp/send-email -> sprout-mailchimp-realtime"

# POST /mailchimp/send-sms -> sprout-mailchimp-realtime
MC_SEND_SMS_ID=$(create_resource "$MAILCHIMP_ID" "send-sms")
create_post_integration "$MC_SEND_SMS_ID" "sprout-mailchimp-realtime"
echo "  POST /mailchimp/send-sms -> sprout-mailchimp-realtime"

# POST /mailchimp/member -> sprout-mailchimp-realtime
MC_MEMBER_ID=$(create_resource "$MAILCHIMP_ID" "member")
create_post_integration "$MC_MEMBER_ID" "sprout-mailchimp-realtime"
echo "  POST /mailchimp/member -> sprout-mailchimp-realtime"

# POST /mailchimp/tags -> sprout-mailchimp-realtime
MC_TAGS_ID=$(create_resource "$MAILCHIMP_ID" "tags")
create_post_integration "$MC_TAGS_ID" "sprout-mailchimp-realtime"
echo "  POST /mailchimp/tags -> sprout-mailchimp-realtime"

# Deploy to "local" stage
awslocal apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name local \
  --region "$REGION" > /dev/null

echo "  Deployed to stage: local"

# Write the full API Gateway URL to a shared file so the Rails app can discover it
API_URL="http://localstack:4566/restapis/${API_ID}/local/_user_request_"
mkdir -p /var/lib/localstack/api
echo "$API_URL" > /var/lib/localstack/api/gateway_url

echo "  API URL written to /var/lib/localstack/api/gateway_url"

# ---------------------------------------------------------------------------
# 7. Summary
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
echo "Lambda Functions:"
echo "  - sprout-zoom-meeting"
echo "  - sprout-zoom-attendance"
echo "  - sprout-volunteer-management-system-sync"
echo "  - sprout-mailchimp-realtime"
echo "  - sprout-mailchimp-batch"
echo "  - sprout-vms"
echo "  - sprout-vms-session-refresh"
echo ""
echo "Event Source Mappings:"
echo "  - sprout-zoom-attendance queue -> sprout-zoom-attendance Lambda"
echo "  - sprout-mailchimp-batch queue -> sprout-mailchimp-batch Lambda"
echo ""
echo "Secrets Manager:"
echo "  - sprout/vms-session (VMS session cookies + credentials)"
echo ""
echo "API Gateway: sprout-api (ID: $API_ID)"
echo "  Stage: local"
echo "  Base URL: http://localhost:4566/restapis/$API_ID/local/_user_request_"
echo "  Endpoints:"
echo "    POST /zoom/meeting                      -> sprout-zoom-meeting"
echo "    POST /volunteer-management-system/sync   -> sprout-volunteer-management-system-sync"
echo "    POST /mailchimp/send-email               -> sprout-mailchimp-realtime"
echo "    POST /mailchimp/send-sms                 -> sprout-mailchimp-realtime"
echo "    POST /mailchimp/member                   -> sprout-mailchimp-realtime"
echo "    POST /mailchimp/tags                     -> sprout-mailchimp-realtime"
echo "    POST /vms/session/refresh                -> sprout-vms-session-refresh"
echo "    GET  /vms/inquiries                      -> sprout-vms"
echo "    POST /vms/inquiries                      -> sprout-vms"
echo "    PUT  /vms/inquiries/{id}                 -> sprout-vms"
echo "    DELETE /vms/inquiries/{id}               -> sprout-vms"
echo "    GET  /vms/volunteers                     -> sprout-vms"
echo "    POST /vms/volunteers                     -> sprout-vms"
echo "    GET  /vms/lookups/{type}                 -> sprout-vms"
echo ""
echo "============================================"
