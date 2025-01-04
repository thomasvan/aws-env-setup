#!/bin/bash

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
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='plc-global-p-s3-backup'].Arn" --output text)

if [ ! -z "$POLICY_ARN" ]; then
    echo "Policy already exists. Using existing policy."
    echo "Using region: ${REGION}"
    # Create a temporary template without the policy
    jq 'del(.Resources.BackupPolicy)' cloudformation/backup-stack.yaml > cloudformation/backup-stack.tmp.yaml
    TEMPLATE_FILE="cloudformation/backup-stack.tmp.yaml"
else
    TEMPLATE_FILE="cloudformation/backup-stack.yaml"
fi

# Create the stack with inline parameters
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://${TEMPLATE_FILE}" \
    --parameters \
        ParameterKey=Environment,ParameterValue=p \
        ParameterKey=Region,ParameterValue="$REGION" \
        ParameterKey=AppName,ParameterValue="$STACK_NAME" \
        ParameterKey=PolicyName,ParameterValue=plc-global-s3-backup \
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

while [ -z "${ACCESS_KEY_ID}" ]; do
    sleep 5
    # Store all credentials in variables
    ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`AccessKeyId`].OutputValue' --output text --region "$REGION")
    SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`SecretAccessKey`].OutputValue' --output text --region "$REGION")
    BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text --region "$REGION")
    USER_ARN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`UserArn`].OutputValue' --output text --region "$REGION")
done

# Cleanup temporary file if it exists
[ -f "cloudformation/backup-stack.tmp.yaml" ] && rm cloudformation/backup-stack.tmp.yaml

# Print the values
cat << EOF
${BUCKET_NAME}:
  AccessKeyId: ${ACCESS_KEY_ID}
  SecretAccessKey: ${SECRET_ACCESS_KEY}
  UserArn: ${USER_ARN}
  Region: ${REGION}
EOF
