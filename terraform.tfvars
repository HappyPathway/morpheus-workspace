# Region and environment settings
aws_region  = "us-west-2"
environment = "dev"

# Network configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# Cluster configuration
cluster_min_size         = 3
cluster_max_size         = 6
cluster_desired_capacity = 3
cluster_instance_type    = "m5.xlarge"

# AMI configuration for testing with Ubuntu
cluster_ami = {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filters = [
    {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
    },
    {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  ]
}

# Domain and SSL configuration
morpheus_fqdn   = "morpheus.morpheus-test.com"
certificate_arn = "arn:aws:acm:us-west-2:309106931916:certificate/6fe3b5ed-a0a9-46cf-85bb-32826d74d383"

# Resource sizing
db_instance_class        = "db.r5.xlarge"
opensearch_instance_type = "r6g.large.search"
mq_instance_type         = "mq.m5.large"
redis_instance_type      = "cache.t3.medium"
redis_nodes              = 2

# Backup configuration
backup_retention_days = 30

# Logging
log_level = "INFO"
