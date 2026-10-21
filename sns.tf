resource "aws_sns_topic" "alerts" {
  name              = "guardrail-security-alerts"
  kms_master_key_id = aws_kms_key.main.id 
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}