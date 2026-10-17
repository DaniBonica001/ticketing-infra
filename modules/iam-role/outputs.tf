output "role_arn" {
  description = "Role ARN. Depends on the attached policies so consumers (e.g. Lambda VPC/destination validation) never see a role without permissions."
  value       = aws_iam_role.this.arn

  depends_on = [aws_iam_role_policy.this, aws_iam_role_policy_attachment.managed]
}

output "role_name" {
  description = "Role name."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "Role unique ID (for aws:userid conditions)."
  value       = aws_iam_role.this.unique_id
}
