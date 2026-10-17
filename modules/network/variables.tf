variable "name" {
  description = "Name prefix for network resources."
  type        = string
  default     = "ticketing"
}

variable "vpc_cidr" {
  description = "VPC CIDR. Must not overlap with other VPCs of the organization (future peering/TGW)."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR of /20 or larger."
  }
}

variable "az_count" {
  description = "Number of AZs (2 for non-prod to save interface endpoint cost, 3 for prod)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "availability_zones" {
  description = "Explicit, ordered AZ list (pinned so the subnet layout never shifts when AWS adds AZs). The first az_count are used."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Provide at least two availability zones."
  }
}

variable "interface_endpoint_services" {
  description = "Interface endpoint service suffixes (com.amazonaws.<region>.<suffix>)."
  type        = list(string)
  default     = ["sqs", "secretsmanager", "kms", "ecr.api", "ecr.dkr", "logs", "sts"]

  validation {
    condition     = alltrue([for s in var.interface_endpoint_services : can(regex("^[a-z0-9.-]+$", s))])
    error_message = "interface_endpoint_services must be service suffixes such as 'sqs' or 'ecr.dkr'."
  }
}

variable "dynamodb_table_prefix" {
  description = "Only tables with this prefix are reachable through the DynamoDB gateway endpoint."
  type        = string
  default     = "ticketing-"
}

variable "api_port" {
  description = "ms-ticketing-api application port."
  type        = number
  default     = 8080
}

variable "api_health_port" {
  description = "Actuator port used by the NLB health check."
  type        = number
  default     = 9090
}

variable "payment_gateway_cidrs" {
  description = "CIDRs of the payment gateway reachable over 443 by the processor (PrivateLink endpoint ENIs or a centralized egress VPC). Empty = no egress beyond AWS endpoints."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.payment_gateway_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "payment_gateway_cidrs must be valid CIDRs and must not be 0.0.0.0/0."
  }
}

variable "logs_kms_key_arn" {
  description = "CMK for the flow logs log group."
  type        = string
}

variable "flow_logs_retention_days" {
  description = "Flow logs retention (1 year: network forensics)."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days must be a value supported by CloudWatch Logs."
  }
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
