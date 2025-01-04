# S3 Backup

## Remove the stack

aws cloudformation delete-stack --stack-name s3-ap-southeast-1-s-web-app-backup --region ap-southeast-1

### Wait for the stack to be deleted

aws cloudformation wait stack-delete-complete --stack-name s3-ap-southeast-1-s-web-app-backup --region ap-southeast-1

### Now you can rerun the script

./commands.sh s3-ap-southeast-1-s-web-app-backup
