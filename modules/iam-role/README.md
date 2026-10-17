# Module `iam-role`

One IAM role per component (task role, execution role, Lambda execution role):

- Trust policy limited to the given service principals, with `aws:SourceAccount` (confused deputy) when supported.
- One inline least-privilege policy built by the caller with `aws_iam_policy_document`
  (resources always scoped to ARNs; wildcards only where AWS requires them, commented at the call site).
- Optional permissions boundary for organization guardrails.

Outputs: `role_arn`, `role_name`.
