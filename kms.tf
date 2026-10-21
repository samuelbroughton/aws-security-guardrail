resource "aws_kms_key" "main" {
  description             = "Encryption key for security guardrail project"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "main" {
  name          = "alias/guardrail-key"
  target_key_id = aws_kms_key.main.key_id
}