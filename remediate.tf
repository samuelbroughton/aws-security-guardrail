data "archive_file" "remediate_ssh" {
  type        = "zip"
  source_file = "${path.module}/lambda/remediate_ssh.py"
  output_path = "${path.module}/build/remediate_ssh.zip"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "remediate_ssh" {
  name               = "guardrail-remediate-ssh-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_cloudwatch_log_group" "remediate_ssh" {
  name              = "/aws/lambda/guardrail-remediate-ssh"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.main.arn
}

data "aws_iam_policy_document" "remediate_ssh" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.remediate_ssh.arn}:*"]
  }
  statement {
    sid       = "ReadSecurityGroups" # Describe calls don't support resource scoping
    actions   = ["ec2:DescribeSecurityGroupRules", "ec2:DescribeSecurityGroups"]
    resources = ["*"]
  }
  statement {
    sid       = "RevokeIngressOnly" # can remove rules, never add them
    actions   = ["ec2:RevokeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:us-east-1:${local.account_id}:security-group/*"]
  }
  statement {
    sid       = "PublishAlerts"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
  statement {
    sid       = "EncryptAlerts"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role_policy" "remediate_ssh" {
  name   = "remediate-ssh"
  role   = aws_iam_role.remediate_ssh.id
  policy = data.aws_iam_policy_document.remediate_ssh.json
}

resource "aws_lambda_function" "remediate_ssh" {
  function_name    = "guardrail-remediate-ssh"
  role             = aws_iam_role.remediate_ssh.arn
  runtime          = "python3.13"
  handler          = "remediate_ssh.handler"
  filename         = data.archive_file.remediate_ssh.output_path
  source_code_hash = data.archive_file.remediate_ssh.output_base64sha256
  timeout          = 30
  kms_key_arn      = aws_kms_key.main.arn

  environment {
    variables = {
      TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.remediate_ssh, aws_iam_role_policy.remediate_ssh]
}

resource "aws_cloudwatch_event_rule" "sg_ingress_change" {
  name        = "guardrail-sg-ingress-change"
  description = "Fires when any security group ingress rule is added"
  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName   = ["AuthorizeSecurityGroupIngress"]
    }
  })
}

resource "aws_cloudwatch_event_target" "remediate_ssh" {
  rule = aws_cloudwatch_event_rule.sg_ingress_change.name
  arn  = aws_lambda_function.remediate_ssh.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediate_ssh.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sg_ingress_change.arn
}