# AWS Security Guardrail

Terraform-built AWS security baseline with automated detection and remediation of misconfigurations, mapped to NIST 800-53.

**Status:** In progress

## Built so far
- KMS customer-managed key with automatic rotation (SC-12)
- S3 bucket: KMS encryption (SC-28), versioning (CP-9), public access blocked (AC-3), TLS-only policy (SC-8)
- Least-privilege IAM role scoped to one bucket and one key (AC-6)

## Coming next
- CloudTrail, GuardDuty, AWS Config, Security Hub (NIST 800-53 standard)
- EventBridge + Lambda auto-remediation
- Checkov scanning in GitHub Actions