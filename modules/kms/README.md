# Module `kms`

Customer managed KMS key (CMK) with automatic rotation and an alias.

- The key policy delegates authorization to IAM (account root statement); each component role
  receives access to the key through its own identity policy, scoped with `kms:ViaService`.
- Optional key administrators (`admin_principal_arns`).
- `service_policy_json` adds statements for AWS services that encrypt on their own behalf
  (CloudWatch Logs, CloudWatch alarms publishing to an encrypted SNS topic).

| Input | Description |
|---|---|
| `alias` | Alias without the `alias/` prefix |
| `description` | Purpose of the key |
| `deletion_window_in_days` | 7–30 (default 30) |
| `rotation_period_in_days` | 90–2560 (default 365) |
| `admin_principal_arns` | Key administrators |
| `service_policy_json` | Extra policy statements |

Outputs: `key_arn`, `key_id`, `alias_arn`.
