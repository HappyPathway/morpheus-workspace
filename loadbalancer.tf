module "alb" {
  source = "./terraform-aws-alb"

  name                       = "${local.project}-${local.environment}"
  internal                   = false
  security_group_ids         = [aws_security_group.alb.id]
  subnet_ids                 = module.vpc.public_subnets
  vpc_id                     = module.vpc.vpc_id
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = true

  target_port           = 80
  health_check_path     = "/health"
  health_check_matcher  = "200"
  health_check_interval = 30
  health_check_timeout  = 5

  stickiness_enabled  = true
  stickiness_duration = 86400

  tags = local.tags
}
