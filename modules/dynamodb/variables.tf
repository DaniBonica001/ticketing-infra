variable "name" {
  description = "Table name (see docs/design/conventions.md of the application repo)."
  type        = string

  validation {
    condition     = can(regex("^ticketing-[a-z0-9-]{1,240}$", var.name))
    error_message = "name must start with 'ticketing-' and contain only lowercase letters, digits or '-'."
  }
}

variable "hash_key" {
  description = "Partition key attribute name."
  type        = string
}

variable "range_key" {
  description = "Sort key attribute name (null for a simple primary key)."
  type        = string
  default     = null
}

variable "attributes" {
  description = "Key attributes (table and GSI keys only) as name => type (S, N or B)."
  type        = map(string)

  validation {
    condition     = alltrue([for t in values(var.attributes) : contains(["S", "N", "B"], t)])
    error_message = "attribute types must be S, N or B."
  }
}

variable "global_secondary_indexes" {
  description = "Global secondary indexes."
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
  }))
  default = []

  validation {
    condition     = alltrue([for g in var.global_secondary_indexes : contains(["ALL", "KEYS_ONLY", "INCLUDE"], g.projection_type)])
    error_message = "projection_type must be ALL, KEYS_ONLY or INCLUDE."
  }
}

variable "kms_key_arn" {
  description = "Customer managed KMS key used for server-side encryption."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "point_in_time_recovery_enabled" {
  description = "Enable continuous backups (PITR)."
  type        = bool
  default     = true
}

variable "point_in_time_recovery_days" {
  description = "PITR recovery window in days (null = service default of 35; used in LocalStack, which does not persist this field)."
  type        = number
  default     = 35

  validation {
    condition     = var.point_in_time_recovery_days == null || (coalesce(var.point_in_time_recovery_days, 35) >= 1 && coalesce(var.point_in_time_recovery_days, 35) <= 35)
    error_message = "point_in_time_recovery_days must be between 1 and 35."
  }
}

variable "deletion_protection_enabled" {
  description = "Protect the table against accidental deletion (true in prod)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
