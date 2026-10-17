# Module `component-policies`

Pure module (only `aws_iam_policy_document` data sources, no resources) that renders the
least-privilege identity policy of each component, so `envs/local` and `envs/prod` grant
exactly the same permissions.

| Component | Permissions |
|---|---|
| `ms-ticketing-api` | Get/Put/Update/ConditionCheck/Query on the 3 tables + GSI, Scan on `ticketing-events`, SendMessage on both queues, KMS via DynamoDB/SQS |
| `ms-order-processor` | Get/Put/Update/ConditionCheck/Query on the 3 tables, Receive/Delete/ChangeVisibility on both queues, GetSecretValue on `ticketing/payment-gateway`, KMS via DynamoDB/SQS/Secrets Manager |
| `ticketing-reservation-expirer` | Query on the GSI, Get/Put/Update/ConditionCheck on the tables, SendMessage on both queues + failure destination, KMS via DynamoDB/SQS, env decrypt, own log group, X-Ray, ENI management (VPC) |

Wildcard resources only where AWS requires them (`ec2:*NetworkInterface*`, X-Ray), commented in place.

Outputs: `api_policy_json`, `processor_policy_json`, `expirer_policy_json`.
