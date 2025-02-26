locals {
  project     = "morpheus"
  environment = terraform.workspace
  region      = var.aws_region

  tags = {
    Project     = local.project
    Environment = local.environment
    Terraform   = "true"
  }
}

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
  kms_key_id       = module.kms.key_arn

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

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  security_groups = [aws_security_group.aurora.id]

  cluster_instances = {
    1 = {
      instance_class = var.db_instance_class
      promotion_tier = 1
    }
    2 = {
      instance_class = var.db_instance_class
      promotion_tier = 2
    }
  }

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  kms_key_id        = module.kms.key_arn
  storage_encrypted = true

  tags = local.tags
}

# OpenSearch Module
module "opensearch" {
  source = "../terraform-aws-opensearch-cluster"

  domain_name    = "${local.project}-${local.environment}"
  engine_version = "OpenSearch_2.5"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = [module.vpc.private_subnets[0]]
  security_groups = [aws_security_group.opensearch.id]

  cluster_config = {
    instance_type          = var.opensearch_instance_type
    instance_count         = 3
    zone_awareness_enabled = true
  }

  encrypt_at_rest = {
    enabled    = true
    kms_key_id = module.kms.key_arn
  }

  tags = local.tags
}

# RabbitMQ Module
module "rabbitmq" {
  source = "../terraform-aws-mq-cluster"

  broker_name    = "${local.project}-${local.environment}"
  engine_type    = "RabbitMQ"
  engine_version = "3.10.10"

  host_instance_type = var.mq_instance_type
  deployment_mode    = "CLUSTER_MULTI_AZ"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  security_groups = [aws_security_group.rabbitmq.id]

  encryption_options = {
    kms_key_id        = module.kms.key_arn
    use_aws_owned_key = false
  }

  tags = local.tags
}

# Application Cluster Module
module "cluster" {
  source = "./terraform-aws-cluster"

  cluster_name     = "${local.project}-${var.environment}"
  parameter_prefix = local.parameter_prefix
  secrets_prefix   = local.secrets_prefix
  project_name     = local.project
  instance_type    = var.cluster_instance_type

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

  # Security Groups
  security_group_ids = [aws_security_group.app.id]

  # Tags
  tags = merge(local.tags, {
    Service = "morpheus-ui"
  })

  vpc_cluster = true
}
