# Module `sqs-queue`

Standard SQS queue + DLQ with the exact parameters of ADR-0003 as defaults
(visibility 30 s, long polling 20 s, retention 4 d / DLQ 14 d, `maxReceiveCount` 5, SSE-KMS with a CMK).
Used twice: `ticketing-orders-queue` and `ticketing-confirmations-queue`.

Queue policy (main queue):

| Statement | Effect |
|---|---|
| `DenyNonTlsTransport` | Denies any request without TLS (`aws:SecureTransport = false`) |
| `AllowProducersSend` / `AllowConsumersReceive` | Explicit grants to the component roles |
| `DenySendToNonProducers` | Only producers (and break-glass roles) can `SendMessage` |
| `DenyConsumeToNonConsumers` | Only consumers (and break-glass roles) can Receive/Delete/ChangeVisibility |
| `DenyAppPrincipalsOutsideVpce` | App roles must come through the SQS VPC endpoint (`aws:SourceVpce`); skipped when `source_vpce_ids` is empty (LocalStack) |

The DLQ only accepts messages redriven from its main queue (`redrive_allow_policy = byQueue`) and
also denies non-TLS access.

Outputs: `queue_name`, `queue_arn`, `queue_url`, `dlq_name`, `dlq_arn`, `dlq_url`.
