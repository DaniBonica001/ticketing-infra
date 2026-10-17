# Module `network`

Private-only VPC for the ticketing workloads.

- 2–3 AZs, one private `/20` subnet per AZ, **no IGW, no NAT**, no public subnets.
- Gateway endpoints: **DynamoDB** (policy: only `ticketing-*` tables, only this account's principals)
  and **S3** (policy: only the ECR layer bucket).
- Interface endpoints (private DNS): `sqs`, `secretsmanager`, `kms`, `ecr.api`, `ecr.dkr`, `logs`, `sts`.
  Policy: principals of this account only (+ `aws:ResourceAccount` for sqs/secretsmanager/kms/logs).
- Security groups (least privilege): NLB→API 8080/9090; API/processor/Lambda→endpoints 443 and
  →DynamoDB/S3 prefix lists 443; endpoints accept 443 only from the app SGs; default SG with no rules.
- Optional processor egress to `payment_gateway_cidrs` (PrivateLink or centralized egress), never `0.0.0.0/0`.
- VPC flow logs (ALL) to a CMK-encrypted log group.

Outputs: `vpc_id`, `vpc_cidr`, `private_subnet_ids`, `security_group_ids` (map), `interface_endpoint_ids`
(map by service), `dynamodb_endpoint_id`, `flow_logs_log_group_name`.
