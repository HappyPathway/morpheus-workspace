resource "aws_cloudwatch_metric_alarm" "secrets_access_denied" {
  alarm_name          = "${local.project}-${var.environment}-secrets-access-denied"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AccessDenied"
  namespace           = "AWS/SecretsManager"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors for denied access to secrets"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    SecretId = aws_secretsmanager_secret.morpheus_db.id
  }
}

resource "aws_cloudwatch_metric_alarm" "parameter_access_denied" {
  alarm_name          = "${local.project}-${var.environment}-parameter-access-denied"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ParameterStoreThrottles"
  namespace           = "AWS/SSM"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors for throttled access to parameters"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_sns_topic" "alerts" {
  name = "${local.project}-${var.environment}-alerts"
  tags = local.tags
}
