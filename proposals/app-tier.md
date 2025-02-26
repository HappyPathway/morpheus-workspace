# Application Tier Implementation Plan

## 1. Launch Template Configuration

### Base AMI Selection

- Use Amazon Linux 2 as base AMI
- Pre-install required packages:
  - java-11-amazon-corretto
  - nginx
  - amazon-efs-utils
  - cloudwatch-agent
  - prometheus-node-exporter

### Instance Configuration

- Instance Type: m5.xlarge (4 vCPU, 16 GB RAM)
- EBS Volume:
  - Root: 100 GB gp3
  - Data: 200 GB gp3 for temp storage
- Instance Profile with required IAM permissions
- User Data script for bootstrap configuration

## 2. Auto Scaling Configuration

### Module Configuration

```hcl
module "morpheus_cluster" {
  source = "../terraform-aws-cluster"

  # Basic Configuration
  cluster_name       = local.cluster_name
  min_size          = 3
  max_size          = 6
  desired_capacity  = 3
  instance_type     = "m5.xlarge"

  # Networking
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnets

  # Health Check Settings
  health_check_type = "ELB"
  health_check_grace_period = 300

  # Scaling Configuration
  target_tracking_configurations = [
    {
      target_value = 70.0
      predefined_metric_specification = {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
    },
    {
      target_value = 1000.0
      predefined_metric_specification = {
        predefined_metric_type = "ALBRequestCountPerTarget"
      }
    }
  ]

  # Tags
  tags = local.tags
}
```

### Health Checks

- EC2 Health Check
- ELB Health Check
- Grace Period: 300 seconds
- Custom Health Check endpoint: /api/health

## 3. Application Configuration

### Morpheus Configuration File

```ruby
# /etc/morpheus/morpheus.rb
appliance_url: 'https://morpheus.example.com'
app_dir: '/opt/morpheus'
elasticsearch:
  host: '${opensearch_endpoint}'
  port: 443
  use_tls: true
rabbitmq:
  host: '${rabbitmq_endpoint}'
  port: 5671
  use_tls: true
  vhost: '/'
  username: '${rabbitmq_user}'
  password: '${rabbitmq_password}'
mysql:
  host: '${aurora_endpoint}'
  port: 3306
  database: 'morpheus'
  username: '${db_user}'
  password: '${db_password}'
```

### Nginx Configuration

```nginx
# /etc/nginx/conf.d/morpheus.conf
upstream morpheus {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name morpheus.example.com;

    ssl_certificate /etc/morpheus/ssl/cert.pem;
    ssl_certificate_key /etc/morpheus/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://morpheus;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 4. Monitoring and Logging

### CloudWatch Agent Configuration

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/morpheus/morpheus-ui/current",
            "log_group_name": "/morpheus/application",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/morpheus/nginx",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "Morpheus",
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"]
      }
    }
  }
}
```

### CloudWatch Alarms

- CPU Utilization > 85% for 5 minutes
- Memory Usage > 85% for 5 minutes
- Disk Usage > 85%
- Application Error Rate > 1%
- Response Time > 2 seconds

## 5. Security Configuration

### IAM Role Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::morpheus-backups/*",
        "arn:aws:s3:::morpheus-backups"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ],
      "Resource": "${efs_arn}"
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "${kms_key_arn}"
    }
  ]
}
```

### Security Group Rules

- Inbound:
  - 80/443 from ALB
  - 22 from bastion
  - 8080 from internal network
- Outbound:
  - All traffic to internal network
  - HTTPS to internet
  - NTP to internet

## 6. High Availability Features

### Load Distribution

- Round-robin across nodes
- Sticky sessions for UI
- Connection draining enabled
- Cross-zone load balancing

### Service Discovery

- DNS-based service discovery
- Internal Route 53 private zone
- Service endpoints for:
  - RabbitMQ
  - OpenSearch
  - Aurora
  - EFS

### State Management

- Shared EFS mount for:
  - Uploaded files
  - Backup archives
  - Report templates
- Session replication via:
  - Sticky sessions
  - Redis session store

### Failover Handling

- Automatic node replacement
- Session persistence
- Connection draining
- Health check grace periods

## 7. Performance Optimization

### JVM Configuration

```sh
JAVA_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:+UseStringDeduplication"
```

### Nginx Tuning

```nginx
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 16384;
    multi_accept on;
    use epoll;
}

http {
    keepalive_timeout 65;
    keepalive_requests 100;
    client_max_body_size 50M;
    client_body_buffer_size 128k;
}
```

### System Limits

```sh
# /etc/security/limits.conf
morpheus soft nofile 65535
morpheus hard nofile 65535
morpheus soft nproc 65535
morpheus hard nproc 65535
```

## 8. Maintenance Procedures

### Updates and Patches

1. Drain connections from node
2. Remove from load balancer
3. Apply updates
4. Validate health checks
5. Return to service
6. Repeat for each node

### Backup Procedures

1. Database backups via Aurora
2. EFS snapshots
3. Configuration backups
4. AMI snapshots

### Monitoring Checks

1. Application health endpoint
2. Resource utilization
3. Error rates
4. Response times
5. Queue depths
