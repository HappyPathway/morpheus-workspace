locals {
  parameter_prefix = "/${var.environment}/morpheus"
  secrets_prefix   = "${var.environment}/morpheus"

  resource_tags = merge(local.tags, {
    Service     = "morpheus"
    Encryption  = "kms"
    Automation  = "terraform"
    AccessLevel = "restricted"
  })
}

# Service Endpoints in Parameter Store
resource "aws_ssm_parameter" "morpheus_endpoints" {
  for_each = {
    aurora     = module.aurora.cluster_endpoint
    aurora_ro  = module.aurora.cluster_reader_endpoint
    rabbitmq   = module.rabbitmq.broker_endpoint
    opensearch = module.opensearch.domain_endpoint
    efs_id     = module.efs.id
    redis      = module.redis.endpoint
  }

  name        = "${local.parameter_prefix}/endpoints/${each.key}"
  description = "Morpheus ${each.key} endpoint"
  type        = "String"
  value       = each.value
  tags = merge(local.resource_tags, {
    EndpointType = each.key
    UpdateSource = "service-module"
  })

  lifecycle {
    ignore_changes = [value]
  }
}

# Application Configuration Parameters
resource "aws_ssm_parameter" "morpheus_config" {
  for_each = {
    app_url          = "https://${local.morpheus_fqdn}"
    environment      = var.environment
    log_level        = var.log_level
    backup_retention = var.backup_retention_days
  }

  name        = "${local.parameter_prefix}/config/${each.key}"
  description = "Morpheus ${each.key} configuration"
  type        = "String"
  value       = each.value
  tags = merge(local.resource_tags, {
    ConfigType      = each.key
    UpdateFrequency = "manual"
  })
}

# Database Credentials in Secrets Manager
resource "aws_secretsmanager_secret" "morpheus_db" {
  name                    = "${local.secrets_prefix}/db/credentials"
  description             = "Morpheus database credentials"
  recovery_window_in_days = 7
  tags = merge(local.resource_tags, {
    CredentialType = "database"
    Rotation       = "90days"
    Database       = "aurora-mysql"
  })
}

resource "aws_secretsmanager_secret_version" "morpheus_db" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = "morpheus"
    password = random_password.database.result
  })
}

# RabbitMQ Credentials in Secrets Manager
resource "aws_secretsmanager_secret" "morpheus_rabbitmq" {
  name                    = "${local.secrets_prefix}/rabbitmq/credentials"
  description             = "Morpheus RabbitMQ credentials"
  recovery_window_in_days = 7
  tags = merge(local.resource_tags, {
    CredentialType = "messaging"
    Rotation       = "90days"
    Service        = "rabbitmq"
  })
}

resource "aws_secretsmanager_secret_version" "morpheus_rabbitmq" {
  secret_id = aws_secretsmanager_secret.morpheus_rabbitmq.id
  secret_string = jsonencode({
    username = "morpheus"
    password = random_password.rabbitmq.result
    vhost    = "/"
    port     = 5671
  })
}

# Secrets for Morpheus components
resource "aws_secretsmanager_secret" "rabbitmq" {
  name_prefix = "${local.project}/${var.environment}/rabbitmq"
  kms_key_id  = aws_kms_key.morpheus.arn
  tags        = local.tags
}

resource "aws_secretsmanager_secret" "database" {
  name_prefix = "${local.project}/${var.environment}/database"
  kms_key_id  = aws_kms_key.morpheus.arn
  tags        = local.tags
}

resource "aws_secretsmanager_secret" "ssl_cert" {
  name_prefix = "${local.project}/${var.environment}/ssl"
  kms_key_id  = aws_kms_key.morpheus.arn
  tags        = local.tags
}

resource "aws_secretsmanager_secret" "redis" {
  name_prefix = "${local.project}/${var.environment}/redis"
  kms_key_id  = aws_kms_key.morpheus.arn
  tags        = local.tags
}

# Initial secret values
resource "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = aws_secretsmanager_secret.rabbitmq.id
  secret_string = jsonencode({
    username = "morpheus"
    password = random_password.rabbitmq.result
  })
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = "morpheus"
    password = random_password.database.result
  })
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = random_password.redis.result
  })
}

# Random passwords for services
resource "random_password" "rabbitmq" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "database" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "redis" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# KMS Key Policy for Secrets
data "aws_iam_policy_document" "secrets_kms_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Morpheus Instance Access"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.cluster.instance_role_arn]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

# Output the prefixes for use in other modules
output "parameter_prefix" {
  value       = local.parameter_prefix
  description = "The SSM Parameter Store prefix for Morpheus configuration"
}

output "secrets_prefix" {
  value       = local.secrets_prefix
  description = "The Secrets Manager prefix for Morpheus secrets"
}
