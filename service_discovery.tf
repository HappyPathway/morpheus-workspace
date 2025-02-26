resource "aws_route53_zone" "internal" {
  name = "${local.environment}.morpheus.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = local.tags
}

resource "aws_route53_record" "rabbitmq" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "rabbitmq.${aws_route53_zone.internal.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [module.rabbitmq.broker_endpoint]
}

resource "aws_route53_record" "opensearch" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "opensearch.${aws_route53_zone.internal.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [module.opensearch.domain_endpoint]
}

resource "aws_route53_record" "aurora" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.${aws_route53_zone.internal.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [module.aurora.cluster_endpoint]
}

resource "aws_route53_record" "aurora_reader" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db-reader.${aws_route53_zone.internal.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [module.aurora.cluster_reader_endpoint]
}

resource "aws_route53_record" "efs" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "efs.${aws_route53_zone.internal.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [module.efs.dns_name]
}

resource "aws_route53_record" "redis" {
  count   = var.redis_endpoint != null ? 1 : 0
  zone_id = aws_route53_zone.internal.zone_id
  name    = "redis.${aws_route53_zone.internal.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [var.redis_endpoint]
}
