# Module `secrets`

Secrets Manager secret **without a value**, encrypted with a CMK, plus a resource policy:

- `DenyReadToNonReaders`: only `reader_role_arns` can `GetSecretValue`.
- `DenyReadersOutsideVpce`: readers must use the Secrets Manager VPC endpoint (skipped in LocalStack).
- `block_public_policy = true`.

The value is loaded out-of-band, so it never appears in code, plans or state:

```bash
aws secretsmanager put-secret-value --secret-id ticketing/payment-gateway \
  --secret-string file://payment-gateway.json   # {"apiKey": "..."}
```

Rotation: the API key is issued by the payment provider; rotation is a manual procedure
(new key at the provider → `put-secret-value` → the processor reloads its cache).

Outputs: `secret_arn`, `secret_name`.
