locals {
  project       = "morpheus"
  environment   = terraform.workspace
  region        = var.aws_region
  morpheus_fqdn = var.morpheus_fqdn

  tags = {
    Project     = local.project
    Environment = local.environment
    Terraform   = "true"
  }
}

# AWS Provider Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module for network foundation
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.project}-${local.environment}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = false

  tags = local.tags
}

# EFS Module for shared storage
module "efs" {
  source = "../terraform-aws-efs"

  creation_token   = "${local.project}-${local.environment}-shared"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
  kms_key_id       = aws_kms_key.morpheus.arn

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  security_groups = [aws_security_group.efs.id]

  tags = local.tags
}

# RDS Aurora Module
module "aurora" {
  source = "../terraform-aws-rds"

  cluster_identifier = "${local.project}-${local.environment}"
  engine             = "aurora-mysql"
  engine_version     = "8.0"

  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.aurora.id]
  create_db_subnet_group = true
  instance_class         = var.db_instance_class
  number_of_instances    = 2

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  storage_encrypted = true
  kms_key_id        = aws_kms_key.morpheus.arn

  tags = local.tags
}

# OpenSearch Module
module "opensearch" {
  source = "../terraform-aws-opensearch-cluster"

  domain_name = "${local.project}-${local.environment}"

  cluster_config = {
    engine_version         = "OpenSearch_2.5"
    instance_type          = var.opensearch_instance_type
    instance_count         = 3
    zone_awareness_enabled = true
  }

  vpc_options = {
    subnet_ids         = [module.vpc.private_subnets[0]]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  security_group_config = {
    vpc_id = module.vpc.vpc_id
  }

  encrypt_at_rest = {
    enabled    = true
    kms_key_id = aws_kms_key.morpheus.arn
  }

  tags = local.tags
}

# RabbitMQ Module
module "rabbitmq" {
  source = "../terraform-aws-mq-cluster"

  broker_name = "${local.project}-${local.environment}"

  broker_config = {
    engine_type        = "RabbitMQ"
    engine_version     = "3.10.10"
    host_instance_type = var.mq_instance_type
    deployment_mode    = "CLUSTER_MULTI_AZ"
    subnet_ids         = module.vpc.private_subnets
    security_groups    = [aws_security_group.rabbitmq.id]
  }

  security_group_config = {
    vpc_id = module.vpc.vpc_id
  }

  encryption_config = {
    kms_key_id        = aws_kms_key.morpheus.arn
    use_aws_owned_key = false
  }

  tags = local.tags
}

# Redis Module for session management
module "redis" {
  source = "../terraform-aws-elasticache"

  cluster_id      = "${local.project}-${local.environment}"
  node_type       = "cache.t3.medium"
  num_cache_nodes = 2

  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.redis.id]

  auth_token = random_password.redis.result
  kms_key_id = aws_kms_key.morpheus.arn

  tags = local.tags
}

# Application Cluster Module
module "cluster" {
  source = "../terraform-aws-cluster"

  cluster_name     = "${local.project}-${var.environment}"
  parameter_prefix = local.parameter_prefix
  secrets_prefix   = local.secrets_prefix
  project_name     = local.project
  instance_type    = var.cluster_instance_type

  vpc_id = module.vpc.vpc_id
  ami    = var.cluster_ami

  # Required configurations
  morpheus_config = {
    appliance_url   = module.alb.dns_name
    rabbitmq_host   = module.rabbitmq.broker_endpoint
    db_host         = module.aurora.cluster_endpoint
    opensearch_host = module.opensearch.domain_endpoint
    efs_dns_name    = module.efs.dns_name
  }

  morpheus_secrets = {
    rabbitmq_secret_arn = aws_secretsmanager_secret.rabbitmq.arn
    database_secret_arn = aws_secretsmanager_secret.database.arn
    ssl_certificate_arn = aws_secretsmanager_secret.ssl_cert.arn
    redis_secret_arn    = aws_secretsmanager_secret.redis.arn
  }

  target_group_arn = module.alb.target_group_arn

  # Security Groups
  security_group_ids        = [aws_security_group.app.id]
  bastion_security_group_id = aws_security_group.bastion.id
  alb_security_group_id     = aws_security_group.alb.id

  private_subnet_cidrs = var.private_subnet_cidrs

  # Auto Scaling Configuration
  auto_scaling = {
    create                    = true
    min_size                  = var.cluster_min_size
    max_size                  = var.cluster_max_size
    desired_capacity          = var.cluster_desired_capacity
    subnets                   = module.vpc.private_subnets
    health_check_type         = "ELB"
    health_check_grace_period = 300
    target_group_arns         = [module.alb.target_group_arn]
  }

  # Launch Template Configuration
  launch_template = {
    create = true
    block_device_mappings = [
      {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 100
          volume_type = "gp3"
        }
      }
    ]
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "enabled"
    }
  }

  # Tags
  tags = merge(local.tags, {
    Service = "morpheus-ui"
  })

  vpc_cluster = true
}
