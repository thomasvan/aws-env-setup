#!/bin/bash

# Get the current script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Check if stack name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <stack-name> [region]"
    echo "Example: $0 my-stack-name"
    echo "Default region: ap-southeast-1"
    exit 1
fi

STACK_NAME="$1"
REGION="${2:-ap-southeast-1}"  # Use ap-southeast-1 as default if not specified

# Check if the policy already exists

# replace the prefix "s3" from the $STACK_NAME to "plc" as the policy name
POLICY_NAME=${STACK_NAME/s3-$REGION-/plc-}
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text)

if [ ! -z "$POLICY_ARN" ]; then
    echo "Policy already exists. Using existing policy: ${POLICY_ARN}"
    echo "Using region: ${REGION}"

    # Create a temporary template with BackupPolicy resource removed
    sed '/BackupPolicy:/,/PolicyDocument:/d' cloudformation/backup-stack.yaml > cloudformation/backup-stack.tmp.yaml
    TEMPLATE_FILE="$SCRIPT_DIR/cloudformation/backup-stack.tmp.yaml"
else
    TEMPLATE_FILE="$SCRIPT_DIR/cloudformation/backup-stack.yaml"
fi

# Create the stack with inline parameters
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://${TEMPLATE_FILE}" \
    --parameters \
        ParameterKey=Environment,ParameterValue=p \
        ParameterKey=Region,ParameterValue="$REGION" \
        ParameterKey=AppName,ParameterValue="$STACK_NAME" \
        ParameterKey=PolicyName,ParameterValue="$POLICY_NAME" \
        ParameterKey=TagEnvironment,ParameterValue=Production \
        ParameterKey=RetentionDays,ParameterValue=730 \
        ParameterKey=GlacierTransitionDays,ParameterValue=365 \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION"

if [ $? -ne 0 ]; then
    echo "Failed to create stack"
    # Cleanup temporary file if it exists
    [ -f "cloudformation/backup-stack.tmp.yaml" ] && rm cloudformation/backup-stack.tmp.yaml
    exit 1
fi

echo "Waiting for stack creation to complete..."

# Wait for stack to complete
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"

if [ $? -ne 0 ]; then
    echo "Stack creation failed"
    exit 1
fi

echo "Stack creation completed. Fetching outputs..."

# Get stack outputs
ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`AccessKeyId`].OutputValue' --output text --region "$REGION")
SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`SecretAccessKey`].OutputValue' --output text --region "$REGION")
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text --region "$REGION")
USER_ARN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`UserArn`].OutputValue' --output text --region "$REGION")

# Cleanup temporary file if it exists
[ -f "cloudformation/backup-stack.tmp.yaml" ] && rm cloudformation/backup-stack.tmp.yaml

# Print the values
if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ] || [ -z "$BUCKET_NAME" ] || [ -z "$USER_ARN" ]; then
    echo "Failed to retrieve stack outputs"
    exit 1
fi

cat << EOF
${BUCKET_NAME}:
  AccessKeyId: ${ACCESS_KEY_ID}
  SecretAccessKey: ${SECRET_ACCESS_KEY}
  UserArn: ${USER_ARN}
  Region: ${REGION}
EOF
