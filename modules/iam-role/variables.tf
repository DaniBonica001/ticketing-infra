variable "name" {
  description = "Role name."
  type        = string

  validation {
    condition     = can(regex("^ticketing-[a-zA-Z0-9+=,.@_-]{1,54}$", var.name))
    error_message = "name must start with 'ticketing-' and be at most 64 characters."
  }
}

variable "description" {
  description = "Role description."
  type        = string
}

variable "path" {
  description = "IAM path for the role."
  type        = string
  default     = "/ticketing/"

  validation {
    condition     = can(regex("^/([a-zA-Z0-9_-]+/)*$", var.path))
    error_message = "path must start and end with '/'."
  }
}

variable "trusted_services" {
  description = "AWS service principals allowed to assume the role (e.g. ecs-tasks.amazonaws.com)."
  type        = list(string)

  validation {
    condition     = length(var.trusted_services) > 0 && alltrue([for s in var.trusted_services : endswith(s, ".amazonaws.com")])
    error_message = "trusted_services must be a non-empty list of *.amazonaws.com service principals."
  }
}

variable "restrict_to_source_account" {
  description = "Add an aws:SourceAccount condition to the trust policy (confused-deputy protection). Keep true for ECS tasks; Lambda execution roles do not need it because only Lambda in this account can be configured with the role (iam:PassRole)."
  type        = bool
  default     = true
}

variable "inline_policy_json" {
  description = "Least-privilege inline policy (JSON) built with aws_iam_policy_document. Every component role has one."
  type        = string
}

variable "managed_policy_arns" {
  description = "Managed policies to attach (prefer the inline policy; use only when unavoidable)."
  type        = list(string)
  default     = []
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary (governance guardrail set by the platform team)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
