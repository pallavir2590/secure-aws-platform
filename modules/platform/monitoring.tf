# ---------------------------------------------------------------
# Alerting: an encrypted SNS topic plus CloudWatch alarms
# ---------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = aws_kms_key.main.arn
}

# Optional email subscription (AWS sends a confirmation email you must click)
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarm when the Lambda function returns any errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name}-health-errors"
  alarm_description   = "Lambda ${aws_lambda_function.health.function_name} is returning errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.health.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Alarm when the function is being throttled (hitting its concurrency limit)
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name}-health-throttles"
  alarm_description   = "Lambda ${aws_lambda_function.health.function_name} is being throttled"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.health.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
