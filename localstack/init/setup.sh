#!/bin/bash
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID="000000000000"

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
# 2. Lambda Functions (stub handlers)
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
# 3. API Gateway REST API
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

# --- /mailchimp ---
MAILCHIMP_ID=$(create_resource "$ROOT_ID" "mailchimp")

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
# 4. Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Sprout LocalStack Bootstrap Complete"
echo "============================================"
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
echo ""
echo "API Gateway: sprout-api (ID: $API_ID)"
echo "  Stage: local"
echo "  Base URL: http://localhost:4566/restapis/$API_ID/local/_user_request_"
echo "  Endpoints:"
echo "    POST /zoom/meeting          -> sprout-zoom-meeting"
echo "    POST /volunteer-management-system/sync -> sprout-volunteer-management-system-sync"
echo "    POST /mailchimp/send-sms    -> sprout-mailchimp-realtime"
echo "    POST /mailchimp/member      -> sprout-mailchimp-realtime"
echo "    POST /mailchimp/tags        -> sprout-mailchimp-realtime"
echo ""
echo "============================================"
