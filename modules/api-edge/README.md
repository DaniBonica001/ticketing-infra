# Module `api-edge`

Public entry point: **WAFv2 → API Gateway REST API (regional) → VPC link → internal NLB → ms-ticketing-api:8080**.

- **REST, not HTTP API:** AWS WAF can only be associated with REST API stages.
- WAF: per-IP rate-based rule (5-minute window) + AWS managed rule groups (IP reputation,
  KnownBadInputs, Common). Logs to `aws-waf-logs-*` (CMK) with the `Authorization` header redacted.
- Stage: throttling (rate/burst), JSON access logs (CMK, retention), X-Ray, execution logs at `ERROR`,
  no data trace, no cache.
- `{proxy+}` HTTP_PROXY integration over the VPC link. The integration overwrites `X-Client-Ip` with
  `context.identity.sourceIp`; the service trusts it only from the NLB subnets
  (`TICKETING_RATE_LIMIT_TRUSTED_PROXIES`) and uses it as the per-IP rate-limit key.
- Authorization: the service validates the JWT (always). `cognito_user_pool_arns` adds a Cognito
  authorizer at the edge (production option, defense in depth).
- NLB: internal, private subnets, SG with no ingress (PrivateLink inbound evaluation off), egress only
  to the API SG; HTTP health check on the actuator port (`/actuator/health/readiness`, 9090).

Outputs: `rest_api_id`, `rest_api_name`, `stage_name`, `invoke_url`, `target_group_arn`, `nlb_arn`,
`nlb_arn_suffix`, `web_acl_arn`.
