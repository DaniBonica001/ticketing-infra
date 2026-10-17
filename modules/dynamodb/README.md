# Module `dynamodb`

One DynamoDB table, always:

- **On-demand** (`PAY_PER_REQUEST`): no capacity planning for ticket-sale spikes; you pay per request.
- **SSE with a customer managed KMS key** (`kms_key_arn`).
- **Point-In-Time Recovery** (35 days by default).
- **Deletion protection** controlled by variable (`true` in prod, `false` in local).
- Optional GSIs (e.g. the sparse `status-deadlineAt-index` on `ticketing-orders`).

Only key attributes are declared (`attributes`); DynamoDB is schemaless for the rest.

Outputs: `table_name`, `table_arn`, `index_arns` (map by index name, used by IAM policies).
