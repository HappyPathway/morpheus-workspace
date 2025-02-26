# AWS Application Load Balancer Module for Morpheus

## Overview

This module provisions an Application Load Balancer (ALB) designed for high-availability Morpheus deployments. It manages load distribution across application nodes and enforces secure communication patterns.

## Core Features

- HTTP to HTTPS redirection
- Custom health checks
- Sticky sessions for UI consistency
- Access logging
- Cross-zone load balancing
- SSL/TLS termination

## Architecture Integration

### Load Distribution

- Round-robin across nodes
- Sticky sessions for UI
- Connection draining
- Cross-zone balancing enabled

### Security

- TLS 1.2/1.3 support
- Custom SSL certificates
- Security group integration
- HTTPS enforcement

### Monitoring

- Health check customization
- Access logging to S3
- CloudWatch metrics
- Custom response codes

## Module Components

### Load Balancer

```hcl
resource "aws_lb" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets           = var.subnet_ids

  enable_deletion_protection = true
  enable_cross_zone_load_balancing = true
}
```

### Target Group

```hcl
resource "aws_lb_target_group" {
  name     = var.name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/health"
    port = "traffic-port"
  }

  stickiness {
    type = "lb_cookie"
    cookie_duration = 86400
  }
}
```

### Listeners

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

## Configuration Options

### Required Variables

- `name` - Name prefix for ALB resources
- `vpc_id` - VPC ID where ALB will be created
- `subnet_ids` - List of subnet IDs for ALB placement
- `security_group_ids` - Security groups for ALB
- `certificate_arn` - ARN of SSL certificate

### Optional Variables

- `internal` - Whether ALB is internal (default: false)
- `enable_deletion_protection` - Protect from accidental deletion
- `access_logs` - S3 bucket configuration for access logs
- `health_check_*` - Health check customization
- `stickiness_*` - Session stickiness settings

## Best Practices

### Security

- Always enable HTTPS
- Use latest TLS policies
- Implement security headers
- Restrict access with security groups

### Monitoring

- Enable access logging
- Configure health checks
- Set up CloudWatch alarms
- Monitor SSL certificate expiry

### Performance

- Enable cross-zone balancing
- Configure proper timeouts
- Use appropriate instance counts
- Monitor target group metrics

### High Availability

- Deploy across multiple AZs
- Enable stickiness for sessions
- Configure proper health checks
- Implement proper draining

## Usage Example

```hcl
module "alb" {
  source = "terraform-aws-alb"

  name               = "morpheus-alb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnets
  security_group_ids = [aws_security_group.alb.id]
  certificate_arn    = var.ssl_cert_arn

  health_check_path = "/health"

  tags = {
    Environment = "production"
    Service     = "morpheus"
  }
}
```

## Integration Guidelines

### Health Checks

- Configure path: `/health`
- Set appropriate thresholds
- Adjust grace periods
- Monitor response codes

### SSL/TLS

- Use ACM certificates
- Enable TLS 1.2/1.3
- Configure security policies
- Implement HSTS

### Logging

- Enable access logging
- Configure log retention
- Monitor error rates
- Track response times

### Maintenance

- Plan for updates
- Monitor performance
- Review security
- Backup configurations
