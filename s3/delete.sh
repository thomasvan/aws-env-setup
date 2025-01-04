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

echo "Cleaning up resources for stack ${STACK_NAME} in region ${REGION}..."

# Get the bucket name from the stack
BUCKET_NAME=$(aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' --output text)

if [ ! -z "$BUCKET_NAME" ]; then
    echo "Emptying S3 bucket ${BUCKET_NAME}..."
    # Empty the S3 bucket first (including versions)
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | while read -r key version; do
        if [ ! -z "$key" ] && [ ! -z "$version" ]; then
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version"
        fi
    done

    # Delete any delete markers
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | while read -r key version; do
        if [ ! -z "$key" ] && [ ! -z "$version" ]; then
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version"
        fi
    done
fi

echo "Deleting stack ${STACK_NAME}..."

# Delete the stack
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"

echo "Waiting for stack deletion to complete..."

# Wait for stack deletion to complete
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"

if [ $? -eq 0 ]; then
    echo "Stack deleted successfully"
else
    echo "Stack deletion failed. Checking stack status..."
    STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus' --output text)
    echo "Current stack status: ${STATUS}"
    echo "You may need to delete some resources manually:"
    echo "1. Empty and delete the S3 bucket (if it exists)"
    echo "2. Delete the IAM user and its access keys"
    echo "3. Try deleting the stack again"
    exit 1
fi
