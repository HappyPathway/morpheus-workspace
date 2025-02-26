variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for ALB HTTPS listener"
  type        = string
}

variable "cluster_min_size" {
  description = "Minimum size of the Morpheus application cluster"
  type        = number
  default     = 3
}

variable "cluster_max_size" {
  description = "Maximum size of the Morpheus application cluster"
  type        = number
  default     = 6
}

variable "cluster_desired_capacity" {
  description = "Desired capacity of the Morpheus application cluster"
  type        = number
  default     = 3
}

variable "cluster_instance_type" {
  description = "EC2 instance type for Morpheus application nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "db_instance_class" {
  description = "Instance class for Aurora DB instances"
  type        = string
  default     = "db.r5.xlarge"
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch cluster"
  type        = string
  default     = "r6g.large.search"
}

variable "mq_instance_type" {
  description = "Instance type for RabbitMQ broker"
  type        = string
  default     = "mq.m5.large"
}

variable "redis_endpoint" {
  description = "Redis endpoint for session management. If not provided, Redis service discovery record will not be created."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name, used for resource naming and parameter/secret paths"
  type        = string
  default     = "dev"
}
