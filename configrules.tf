locals {
  config_rules = {
    "restricted-ssh"           = "INCOMING_SSH_DISABLED"                     # SC-7: no SSH open to the world
    "s3-bucket-public-blocked" = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"  # AC-3: buckets block public access
    "cloudtrail-enabled"       = "CLOUD_TRAIL_ENABLED"                       # AU-12: audit logging is on
    "root-mfa-enabled"         = "ROOT_ACCOUNT_MFA_ENABLED"                  # IA-2(1): root has MFA
    "root-no-access-keys"      = "IAM_ROOT_ACCESS_KEY_CHECK"                 # AC-6: root has no API keys
  }
}

resource "aws_config_config_rule" "rules" {
  for_each = local.config_rules

  name = each.key
  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}