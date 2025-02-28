# Morpheus HA Deployment Guide

This document describes the high-availability deployment of Morpheus using AWS services.

## Architecture Overview

The deployment consists of the following components:

- AWS VPC with 3 Availability Zones
- Application Load Balancer for request distribution
- Auto Scaling Group with minimum 3 application nodes
- Aurora MySQL 8.0 cluster for database
- OpenSearch 2.5 cluster for search functionality
- Amazon MQ (RabbitMQ 3.10.10) for message queueing
- EFS for shared storage
- KMS for encryption
- Secrets Manager for credential management
- Systems Manager Parameter Store for configuration

## Network Architecture

### VPC Configuration

- CIDR Block: 10.0.0.0/16
- 3 Public Subnets: 10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24
- 3 Private Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- NAT Gateways: One per AZ for high availability
- Internet Gateway: For public subnet access

### Security Groups

1. Application Load Balancer (morpheus-dev-alb)

   - Inbound: TCP 80,443 from allowed CIDR blocks
   - Outbound: All traffic to 0.0.0.0/0

2. Application Nodes (morpheus-dev-app)

   - Inbound: TCP 8080 from ALB security group
   - Inbound: TCP 22 from bastion security group
   - Outbound: As required for service access

3. Aurora Database (morpheus-dev-aurora)
   - Inbound: TCP 3306 from application security group
4. OpenSearch (morpheus-dev-opensearch)

   - Inbound: TCP 443 from application security group

5. RabbitMQ (morpheus-dev-rabbitmq)

   - Inbound: TCP 5671 from application security group

6. EFS (morpheus-dev-efs)
   - Inbound: TCP 2049 from application security group

## Service Configuration

### Load Balancer

- Type: Application Load Balancer
- Protocol: HTTPS (ACM certificate)
- Health Check: /health
- Stickiness: Enabled (24 hour duration)

### Application Nodes

- Instance Type: m5.xlarge (4 vCPU, 16GB RAM)
- Auto Scaling:
  - Minimum: 3
  - Desired: 3
  - Maximum: 6
  - Health Check Grace Period: 300 seconds
- Root Volume: 100GB gp3
- EFS Mount: /morpheus/lib

### Database

- Engine: Aurora MySQL 8.0
- Instance Class: db.r5.xlarge
- Multi-AZ: Yes (2 instances)
- Backup Retention: 7 days
- Backup Window: 03:00-04:00 UTC
- Encryption: Yes (KMS)

### Search

- Engine: OpenSearch 2.5
- Instance Type: r6g.large.search
- Node Count: 3
- Zone Awareness: Enabled
- Encryption: Yes (KMS)

### Message Queue

- Engine: RabbitMQ 3.10.10
- Instance Type: mq.m5.large
- Deployment: Multi-AZ cluster
- TLS: Required
- Encryption: Yes (KMS)

### Shared Storage

- Type: EFS
- Performance Mode: generalPurpose
- Throughput Mode: bursting
- Encryption: Yes (KMS)

## Secret Management

### KMS Configuration

Dedicated KMS key for:

- EFS encryption
- Aurora encryption
- OpenSearch encryption
- RabbitMQ encryption
- Secrets Manager encryption
- SSM Parameter Store encryption

### Secrets Manager

Stores credentials for:

- Database access
- RabbitMQ access
- SSL certificates
- Redis auth tokens (if used)

### Parameter Store

Stores configuration for:

- Service endpoints
- Application URL
- Environment settings
- Logging configuration
- Backup settings

## Monitoring & Logging

### CloudWatch Metrics

- CPU Utilization (target: 70%)
- Memory Usage (alert at 85%)
- Disk Usage (alert at 85%)
- Error Rate (alert at >1%)
- Response Time (alert at >2s)

### Auto Scaling Policies

- CPU Utilization Based (target: 70%)
- Request Count Based (target: 1000 req/target)

### CloudWatch Logs

- Application Logs: /morpheus/application
- Nginx Access Logs: /morpheus/nginx
- Retention: 30 days

## Backup & Recovery

- Database: Automated daily backups with 7-day retention
- EFS: EFS-to-EFS backup with 30-day retention
- Configuration: Terraform state backup in S3 with versioning

## Security Considerations

1. Network Security

   - Private subnets for all backend services
   - Security group rules limited to required ports
   - VPC endpoints for AWS services

2. Data Security

   - Encryption at rest for all data stores
   - TLS for all service communication
   - Secrets rotation enabled
   - IAM roles with least privilege

3. Access Security
   - Bastion host for SSH access
   - IMDSv2 required on EC2 instances
   - No direct database access
   - CloudWatch logs for audit trail

## Scaling Considerations

1. Vertical Scaling

   - Application: Scale instance type up to larger compute optimized instances
   - Database: Scale instance class based on CPU/memory metrics
   - Search: Increase instance size based on data volume
   - Message Queue: Scale broker instance type based on throughput

2. Horizontal Scaling
   - Application: Auto Scaling Group handles node addition/removal
   - Database: Add read replicas for read scaling
   - Search: Add data nodes to the OpenSearch cluster
   - Message Queue: Already HA with multi-AZ deployment

## Recovery Procedures

1. Node Failure

   - Auto Scaling Group automatically replaces failed nodes
   - Health checks ensure traffic only routes to healthy instances
   - Session stickiness maintains user sessions during recovery

2. AZ Failure

   - Multi-AZ deployment ensures service continuity
   - Auto Scaling Group launches new nodes in remaining AZs
   - Aurora and RabbitMQ automatic failover to standby

3. Database Recovery

   - Point-in-time recovery available within backup window
   - Aurora cloning for non-disruptive recovery testing
   - Read replica promotion if needed

4. Full Region Recovery
   - AMIs available for EC2 recovery
   - Database snapshots for data recovery
   - Infrastructure as Code enables rapid reconstruction

## Maintenance Procedures

1. Application Updates

   - Rolling deployment through Auto Scaling Group
   - Health checks ensure proper operation
   - Session draining before instance termination

2. Database Updates

   - Aurora zero-downtime patching
   - Minor version updates automatic
   - Major version updates require planning

3. OS Patching
   - Rolling updates through Auto Scaling Group
   - Immutable infrastructure approach
   - New AMI deployment for system updates
