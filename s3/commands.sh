#!/bin/bash

# Create a bucket
aws cloudformation create-stack \
    --stack-name s3-backup-setup \
    --template-body file://cloudformation/backup-stack.yaml \
    --parameters file://cloudformation/parameters.json \
    --capabilities CAPABILITY_NAMED_IAM

if [ $? -ne 0 ]; then
    echo "Failed to create stack"
    exit 1
fi
sleep 30
# Store all credentials in variables
ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name s3-backup-setup --query 'Stacks[0].Outputs[?OutputKey==`AccessKeyId`].OutputValue' --output text)
SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name s3-backup-setup --query 'Stacks[0].Outputs[?OutputKey==`SecretAccessKey`].OutputValue' --output text)
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name s3-backup-setup --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text)
USER_ARN=$(aws cloudformation describe-stacks --stack-name s3-backup-setup --query 'Stacks[0].Outputs[?OutputKey==`UserArn`].OutputValue' --output text)

# Print the values
cat << EOF
${BUCKET_NAME}:
  AccessKeyId: ${ACCESS_KEY_ID}
  SecretAccessKey: ${SECRET_ACCESS_KEY}
  UserArn: ${USER_ARN}
EOF