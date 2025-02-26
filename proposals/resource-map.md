# Morpheus Infrastructure Resource Map

## morpheus-workspace (Root Module)

### Networking

- VPC Configuration (via terraform-aws-vpc)
- Private/Public Subnets
- Availability Zones

### KMS (kms.tf)

- KMS Key for encryption
- KMS Alias

### Service Discovery (service_discovery.tf)

- Route53 Private Hosted Zone
- Service Endpoint Records:
  - RabbitMQ
  - OpenSearch
  - Aurora (Primary & Reader)
  - EFS
  - Redis (optional)

### Core Service Integration

- Aurora RDS Module
- OpenSearch Module
- RabbitMQ Module
- EFS Module
- Cluster Module
- ALB Module

### Secrets Management (secrets.tf)

- Parameter Store Configuration:
  - Service Endpoints
  - Application Configuration
  - Non-sensitive Settings
- Secrets Manager Resources:
  - Database Credentials
  - RabbitMQ Credentials
  - SSL/TLS Certificates
- KMS Integration:
  - Encryption Keys
  - Key Policies
  - Service Access

## terraform-morpheus-alb

### Load Balancer (main.tf)

- Application Load Balancer
- Target Groups
- Listeners (HTTP/HTTPS)
- Health Checks
- Stickiness Configuration

### Monitoring

- Access Logs
- CloudWatch Integration
- Custom Metrics
- CloudWatch Alarms:
  - Service Health
  - Resource Utilization
  - Secrets Access Monitoring
  - Parameter Store Access

### Security

- SSL/TLS Configuration
- Security Group Integration
- HTTPS Enforcement

## terraform-aws-cluster

### Auto Scaling (autoscaling_group.tf, autoscaling_policy.tf)

- Auto Scaling Group
- Launch Template
- Scaling Policies:
  - CPU Utilization
  - Request Count
- Lifecycle Hooks

### IAM (iam.tf)

- Instance Role
- Instance Profile
- IAM Policies:
  - CloudWatch
  - EFS Access
  - KMS Access
  - Secrets Manager Access

### Monitoring (monitoring.tf)

- CloudWatch Alarms
- CloudWatch Log Groups
- Custom Metrics

### Instance Configuration (launch_template.tf)

- AMI Selection
- Instance Type
- Storage Configuration
- User Data
- Security Groups

## terraform-aws-rds

### Aurora Configuration

- DB Cluster
- DB Instances
- Parameter Groups
- Subnet Groups

### Monitoring

- Enhanced Monitoring
- Performance Insights
- CloudWatch Alarms

### Backup

- Automated Backups
- Snapshot Configuration
- Retention Policies

### Security

- Security Groups
- IAM Authentication
- Encryption Configuration

## terraform-aws-opensearch-cluster

### Domain Configuration

- OpenSearch Domain
- Instance Configuration
- Storage Settings

### Security

- Access Policies
- Encryption Settings
- VPC Access

### Monitoring

- CloudWatch Integration
- Log Publishing

## terraform-aws-mq-cluster

### Broker Configuration

- RabbitMQ Broker
- Instance Type
- Multi-AZ Setup

### Security

- Security Groups
- Access Control
- Encryption Settings

### Monitoring

- CloudWatch Integration
- Log Configuration

## terraform-aws-efs

### File System

- EFS File System
- Mount Targets
- Access Points

### Security

- Security Groups
- Access Control
- Encryption Configuration

### Performance

- Performance Mode
- Throughput Mode
- Burst Credits

## Resource Dependencies

### Primary Dependencies

1. VPC & Networking (morpheus-workspace)

   - Required by all other modules

2. KMS Keys (morpheus-workspace)

   - Used by:
     - RDS
     - OpenSearch
     - EFS
     - MQ
     - Cluster (for secrets)

3. Service Discovery (morpheus-workspace)

   - Depends on all service endpoints
   - Used by Cluster for service resolution

4. Secrets Management (secrets.tf)
   - Required by:
     - Cluster Module (for service configuration)
     - Application nodes (for credentials)
   - Depends on:
     - KMS Keys
     - Service endpoints
     - IAM roles

### Secondary Dependencies

1. Cluster Module

   - Depends on:
     - ALB
     - EFS
     - RDS
     - OpenSearch
     - MQ
     - Service Discovery

2. RDS Module

   - Depends on:
     - VPC
     - KMS
     - Security Groups

3. OpenSearch Module
   - Depends on:
     - VPC
     - KMS
     - Security Groups

## Security Group Distribution

1. morpheus-workspace

   - ALB Security Groups
   - Bastion Security Groups
   - VPC Endpoint Security Groups

2. terraform-aws-cluster

   - Instance Security Groups

3. Service Modules
   - Service-specific security groups
   - Inbound/Outbound rules for service access
