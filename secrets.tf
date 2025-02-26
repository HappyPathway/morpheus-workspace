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
    rabbitmq   = module.rabbitmq.endpoint
    opensearch = module.opensearch.endpoint
    efs_id     = module.efs.id
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
  secret_id = aws_secretsmanager_secret.morpheus_db.id
  secret_string = jsonencode({
    username = module.aurora.master_username
    password = module.aurora.master_password
    database = "morpheus"
    port     = 3306
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
    username = module.rabbitmq.username
    password = module.rabbitmq.password
    vhost    = "/"
    port     = 5671
  })
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
