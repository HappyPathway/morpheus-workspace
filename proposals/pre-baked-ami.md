# Pre-baked AMI Configuration Management

## Overview

This proposal outlines the configuration management approach for Morpheus application nodes using a pre-baked AMI. The focus is on runtime configuration of external service endpoints and application settings, assuming the base OS and application installation are already complete in the AMI.

## User Data Strategy

### Configuration Sources

1. **AWS Systems Manager Parameter Store**

   - Service endpoints
   - Non-sensitive configuration
   - Feature flags
   - Environment-specific settings

2. **AWS Secrets Manager**
   - Database credentials
   - RabbitMQ credentials
   - SSL/TLS certificates
   - API keys and tokens

### User Data Script Structure

```bash
#!/bin/bash

# Configuration Variables
CONFIG_PATH="/etc/morpheus/morpheus.rb"
NGINX_CONFIG="/etc/nginx/conf.d/morpheus.conf"
REGION="${AWS::Region}"

# Mount EFS first - this needs to happen before Morpheus starts
EFS_ID=$(aws ssm get-parameter --name "/morpheus/efs/id" --region $REGION --query "Parameter.Value" --output text)
mkdir -p /mnt/efs/morpheus
mount -t efs -o tls,iam $EFS_ID:/ /mnt/efs/morpheus

# Add mount to fstab for persistence
echo "$EFS_ID:/ /mnt/efs/morpheus efs _netdev,tls,iam 0 0" >> /etc/fstab

# Retrieve service endpoints from Parameter Store
AURORA_ENDPOINT=$(aws ssm get-parameter --name "/morpheus/aurora/endpoint" --region $REGION --query "Parameter.Value" --output text)
RABBITMQ_ENDPOINT=$(aws ssm get-parameter --name "/morpheus/rabbitmq/endpoint" --region $REGION --query "Parameter.Value" --output text)
OPENSEARCH_ENDPOINT=$(aws ssm get-parameter --name "/morpheus/opensearch/endpoint" --region $REGION --query "Parameter.Value" --output text)

# Retrieve credentials from Secrets Manager
DB_CREDS=$(aws secretsmanager get-secret-value --secret-id morpheus/db/credentials --region $REGION --query "SecretString" --output text)
MQ_CREDS=$(aws secretsmanager get-secret-value --secret-id morpheus/rabbitmq/credentials --region $REGION --query "SecretString" --output text)

# Extract credentials
DB_USERNAME=$(echo $DB_CREDS | jq -r .username)
DB_PASSWORD=$(echo $DB_CREDS | jq -r .password)
MQ_USERNAME=$(echo $MQ_CREDS | jq -r .username)
MQ_PASSWORD=$(echo $MQ_CREDS | jq -r .password)

# Update Morpheus configuration
cat > $CONFIG_PATH << EOF
elasticsearch:
  host: '${opensearch_endpoint}'
  port: 443
  use_tls: true

rabbitmq:
  host: '${rabbitmq_endpoint}'
  port: 5671
  use_tls: true
  vhost: '/'
  username: '${mq_username}'
  password: '${mq_password}'

mysql:
  host: '${aurora_endpoint}'
  port: 3306
  database: 'morpheus'
  username: '${db_username}'
  password: '${db_password}'

# EFS mount is handled by cloud-init in terraform configuration
shared_storage:
  root: '/mnt/efs/morpheus'
EOF

# Set proper permissions
chown morpheus-app:morpheus-app $CONFIG_PATH
chmod 600 $CONFIG_PATH

# Start Morpheus services
systemctl start morpheus-ui
```

## Terraform Implementation

### Launch Template Configuration

```hcl
resource "aws_launch_template" "morpheus" {
  name_prefix   = "morpheus-"
  image_id      = var.morpheus_ami_id  # Pre-baked AMI
  instance_type = "m5.xlarge"

  iam_instance_profile {
    name = aws_iam_instance_profile.morpheus.name
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    region = data.aws_region.current.name
    // Additional variables as needed
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 2
  }

  # Existing configuration...
}
```

### Required IAM Permissions

```hcl
data "aws_iam_policy_document" "instance_profile" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/morpheus/*",
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:morpheus/*"
    ]
  }

  # Other necessary permissions...
}
```

## Systems Manager Parameters

### Parameter Structure

```hcl
resource "aws_ssm_parameter" "aurora_endpoint" {
  name  = "/morpheus/aurora/endpoint"
  type  = "String"
  value = module.aurora.cluster_endpoint
}

resource "aws_ssm_parameter" "rabbitmq_endpoint" {
  name  = "/morpheus/rabbitmq/endpoint"
  type  = "String"
  value = module.rabbitmq.endpoint
}

resource "aws_ssm_parameter" "opensearch_endpoint" {
  name  = "/morpheus/opensearch/endpoint"
  type  = "String"
  value = module.opensearch.endpoint
}
```

### Secrets Management

```hcl
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "morpheus/db/credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

resource "aws_secretsmanager_secret" "rabbitmq_credentials" {
  name = "morpheus/rabbitmq/credentials"
}

resource "aws_secretsmanager_secret_version" "rabbitmq_credentials" {
  secret_id = aws_secretsmanager_secret.rabbitmq_credentials.id
  secret_string = jsonencode({
    username = var.rabbitmq_username
    password = var.rabbitmq_password
  })
}
```

## Validation and Testing

### Pre-deployment Validation

1. Verify AMI ID is correct and accessible
2. Validate IAM role permissions
3. Verify Parameter Store values
4. Test Secrets Manager access

### Post-deployment Checks

1. Verify service configuration files
2. Check service endpoints connectivity
3. Validate credentials access
4. Monitor application logs for startup issues

## Maintenance Considerations

### AMI Updates

- Coordinate AMI updates with configuration changes
- Version control AMI IDs
- Maintain AMI update documentation

### Configuration Updates

1. Update Parameter Store/Secrets Manager
2. Rolling instance refresh
3. Validate changes
4. Monitor application health

## Security Considerations

1. **Instance Configuration**

   - IMDSv2 required
   - Minimal IAM permissions
   - Encrypted configuration files

2. **Secret Management**

   - Rotation policies
   - Access auditing
   - Encryption at rest

3. **Network Security**
   - Security group restrictions
   - VPC endpoint policies
   - TLS for all service connections
