# Network outputs for future VPC integrations
output "vpc_id" {
  description = "ID of the VPC where Morpheus is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets for future service expansion"
  value       = module.vpc.private_subnets
}

# Load balancer outputs for DNS and service integration
output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the load balancer for DNS aliasing"
  value       = module.alb.zone_id
}

# Database outputs for external tools and monitoring
output "db_cluster_id" {
  description = "Aurora cluster identifier for monitoring integration"
  value       = module.aurora.cluster_id
}

output "db_cluster_arn" {
  description = "Aurora cluster ARN for IAM and monitoring"
  value       = module.aurora.cluster_arn
}

output "db_endpoint" {
  description = "Endpoint of the Aurora cluster"
  value       = module.aurora.cluster_endpoint
}

output "db_reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster"
  value       = module.aurora.cluster_reader_endpoint
}

# Search outputs for log integration
output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch cluster"
  value       = module.opensearch.domain_endpoint
}

output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain for log shipping"
  value       = module.opensearch.domain_name
}

output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain for IAM policies"
  value       = module.opensearch.domain_arn
}

# Message queue outputs for external service integration
output "rabbitmq_endpoint" {
  description = "Endpoint of the RabbitMQ broker"
  value       = module.rabbitmq.broker_endpoint
}

output "rabbitmq_broker_id" {
  description = "ID of the RabbitMQ broker for service integration"
  value       = module.rabbitmq.broker_id
}

# Storage outputs for backup integration
output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = module.efs.dns_name
}

output "efs_id" {
  description = "ID of the EFS filesystem for backup solutions"
  value       = module.efs.id
}

output "efs_arn" {
  description = "ARN of the EFS filesystem for IAM policies"
  value       = module.efs.arn
}

# Security outputs for IAM integration
output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = module.kms.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = module.kms.key_arn
}

# Parameter and secrets path outputs
output "parameter_prefix" {
  description = "SSM Parameter Store prefix for Morpheus configuration"
  value       = local.parameter_prefix
}

output "secrets_prefix" {
  description = "Secrets Manager prefix for Morpheus secrets"
  value       = local.secrets_prefix
}

output "cluster_role_arn" {
  description = "ARN of the Morpheus cluster IAM role"
  value       = module.cluster.instance_role_arn
}
