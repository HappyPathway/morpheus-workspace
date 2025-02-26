# Secrets and Configuration Management Implementation

## Overview

This proposal outlines the implementation of AWS Secrets Manager and Systems Manager Parameter Store for the Morpheus HA deployment, reconciling our pre-baked AMI approach with proper secrets management.

## Parameter Store Structure

### Base Path Configuration

```hcl
locals {
  parameter_prefix = "/${var.environment}/morpheus"
  secrets_prefix   = "${var.environment}/morpheus"
}
```

### Required Parameters

1. **Service Endpoints**

```hcl
resource "aws_ssm_parameter" "morpheus_endpoints" {
  for_each = {
    aurora     = module.aurora.cluster_endpoint
    aurora_ro  = module.aurora.cluster_reader_endpoint
    rabbitmq   = module.rabbitmq.endpoint
    opensearch = module.opensearch.endpoint
    efs_id     = module.efs.id
  }

  name  = "${local.parameter_prefix}/endpoints/${each.key}"
  type  = "String"
  value = each.value
  tags  = local.tags
}
```

2. **Application Configuration**

```hcl
resource "aws_ssm_parameter" "morpheus_config" {
  for_each = {
    app_url = "https://${local.morpheus_fqdn}"
    environment = var.environment
    log_level = var.log_level
    backup_retention = var.backup_retention_days
  }

  name  = "${local.parameter_prefix}/config/${each.key}"
  type  = "String"
  value = each.value
  tags  = local.tags
}
```

## Secrets Manager Structure

### Database Credentials

```hcl
resource "aws_secretsmanager_secret" "morpheus_db" {
  name = "${local.secrets_prefix}/db/credentials"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "morpheus_db" {
  secret_id = aws_secretsmanager_secret.morpheus_db.id
  secret_string = jsonencode({
    username = module.aurora.master_username
    password = module.aurora.master_password
    database = "morpheus"
    port     = 3306
  })
}
```

### RabbitMQ Credentials

```hcl
resource "aws_secretsmanager_secret" "morpheus_rabbitmq" {
  name = "${local.secrets_prefix}/rabbitmq/credentials"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "morpheus_rabbitmq" {
  secret_id = aws_secretsmanager_secret.morpheus_rabbitmq.id
  secret_string = jsonencode({
    username = module.rabbitmq.username
    password = module.rabbitmq.password
    vhost    = "/"
    port     = 5671
  })
}
```

## IAM Role Updates

### Instance Profile Policy

```hcl
data "aws_iam_policy_document" "morpheus_instance_profile" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_prefix}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${local.secrets_prefix}/*"
    ]
  }
}
```

## Implementation Tasks

### Phase 1: Infrastructure Updates

1. **Parameter Store Setup**

   - [ ] Implement parameter prefix structure
   - [ ] Create parameters for service endpoints
   - [ ] Add application configuration parameters
   - [ ] Set up parameter policies for rotation

2. **Secrets Manager Setup**

   - [ ] Implement secrets prefix structure
   - [ ] Create secrets for database credentials
   - [ ] Create secrets for RabbitMQ credentials
   - [ ] Configure secret rotation policies

3. **IAM Updates**
   - [ ] Update instance profile policies
   - [ ] Add KMS key permissions
   - [ ] Configure cross-account access if needed
   - [ ] Set up audit logging for access

### Phase 2: Application Integration

1. **User Data Script Updates**

```bash
#!/bin/bash

# Configuration Variables
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
PARAMETER_PREFIX="/${var.environment}/morpheus"
SECRETS_PREFIX="${var.environment}/morpheus"

# Fetch Service Endpoints
AURORA_ENDPOINT=$(aws ssm get-parameter --name "$PARAMETER_PREFIX/endpoints/aurora" --region $REGION --query "Parameter.Value" --output text)
RABBITMQ_ENDPOINT=$(aws ssm get-parameter --name "$PARAMETER_PREFIX/endpoints/rabbitmq" --region $REGION --query "Parameter.Value" --output text)
OPENSEARCH_ENDPOINT=$(aws ssm get-parameter --name "$PARAMETER_PREFIX/endpoints/opensearch" --region $REGION --query "Parameter.Value" --output text)
EFS_ID=$(aws ssm get-parameter --name "$PARAMETER_PREFIX/endpoints/efs_id" --region $REGION --query "Parameter.Value" --output text)

# Fetch Credentials
DB_CREDS=$(aws secretsmanager get-secret-value --secret-id "$SECRETS_PREFIX/db/credentials" --region $REGION --query "SecretString" --output text)
MQ_CREDS=$(aws secretsmanager get-secret-value --secret-id "$SECRETS_PREFIX/rabbitmq/credentials" --region $REGION --query "SecretString" --output text)

# Parse JSON credentials
DB_USERNAME=$(echo $DB_CREDS | jq -r .username)
DB_PASSWORD=$(echo $DB_CREDS | jq -r .password)
MQ_USERNAME=$(echo $MQ_CREDS | jq -r .username)
MQ_PASSWORD=$(echo $MQ_CREDS | jq -r .password)

# Update Morpheus configuration
cat > /etc/morpheus/morpheus.rb << EOF
elasticsearch:
  host: '$OPENSEARCH_ENDPOINT'
  port: 443
  use_tls: true

rabbitmq:
  host: '$RABBITMQ_ENDPOINT'
  port: 5671
  use_tls: true
  vhost: '/'
  username: '$MQ_USERNAME'
  password: '$MQ_PASSWORD'

mysql:
  host: '$AURORA_ENDPOINT'
  port: 3306
  database: 'morpheus'
  username: '$DB_USERNAME'
  password: '$DB_PASSWORD'

shared_storage:
  root: '/mnt/efs/morpheus'
EOF

# Mount EFS
mkdir -p /mnt/efs/morpheus
mount -t efs -o tls,iam $EFS_ID:/ /mnt/efs/morpheus
```

### Phase 3: Testing and Validation

1. **Infrastructure Testing**

   - [ ] Verify parameter store access
   - [ ] Test secrets manager access
   - [ ] Validate IAM permissions
   - [ ] Check KMS encryption

2. **Application Testing**
   - [ ] Test configuration retrieval
   - [ ] Verify service connections
   - [ ] Validate error handling
   - [ ] Test secret rotation

## Security Considerations

1. **Access Control**

   - Implement strict IAM policies
   - Use KMS encryption for secrets
   - Enable audit logging
   - Regular access reviews

2. **Rotation Policies**

   - Database credentials: 90 days
   - RabbitMQ credentials: 90 days
   - SSL certificates: 1 year
   - API keys: 180 days

3. **Monitoring**
   - Set up CloudWatch alarms for:
     - Failed parameter access
     - Failed secret access
     - Rotation failures
     - Permission denied events

## Next Actions

1. **Immediate Tasks**

   - Create parameter store structure in Terraform
   - Set up secrets manager resources
   - Update IAM policies in cluster module
   - Modify user data script

2. **Follow-up Tasks**
   - Implement secret rotation
   - Set up monitoring
   - Document procedures
   - Test recovery scenarios
