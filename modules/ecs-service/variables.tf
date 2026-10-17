variable "name" {
  description = "Service, task family and container name (e.g. ms-ticketing-api)."
  type        = string

  validation {
    condition     = can(regex("^ms-[a-z0-9-]{1,60}$", var.name))
    error_message = "name must follow the 'ms-<component>' convention."
  }
}

variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN."
  type        = string
}

variable "image" {
  description = "Container image pinned by digest: <registry>/<repo>@sha256:<64 hex> (A03 supply chain; tags are mutable)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?/[a-z0-9._/-]+@sha256:[a-f0-9]{64}$", var.image))
    error_message = "image must be pinned by digest (…@sha256:<64 hex chars>)."
  }
}

variable "cpu" {
  description = "Task vCPU units."
  type        = number
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu must be a valid Fargate value."
  }
}

variable "memory" {
  description = "Task memory (MiB); must be compatible with cpu."
  type        = number
  default     = 1024

  validation {
    condition     = var.memory >= 512 && var.memory <= 122880
    error_message = "memory must be between 512 and 122880 MiB."
  }
}

variable "cpu_architecture" {
  description = "ARM64 (Graviton, ~20% cheaper per vCPU-hour) or X86_64. Images must be built for it."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be ARM64 or X86_64."
  }
}

variable "run_as_user" {
  description = "Non-root UID:GID the container runs as."
  type        = string
  default     = "10001:10001"

  validation {
    condition     = can(regex("^[1-9][0-9]*(:[1-9][0-9]*)?$", var.run_as_user))
    error_message = "run_as_user must be a non-root numeric UID[:GID] (0 is not allowed)."
  }
}

variable "container_port" {
  description = "Application port exposed to the load balancer (null for workers without inbound traffic)."
  type        = number
  default     = null
}

variable "management_port" {
  description = "Actuator port (health checks only, never routed by the API)."
  type        = number
  default     = null
}

variable "environment" {
  description = "Plain environment variables (no secrets: secrets are read at runtime from Secrets Manager)."
  type        = map(string)
  default     = {}
}

variable "stop_timeout_seconds" {
  description = "Grace period for in-flight requests/messages on SIGTERM."
  type        = number
  default     = 30

  validation {
    condition     = var.stop_timeout_seconds >= 2 && var.stop_timeout_seconds <= 120
    error_message = "stop_timeout_seconds must be between 2 and 120."
  }
}

variable "task_role_arn" {
  description = "Task role (application permissions)."
  type        = string
}

variable "execution_role_arn" {
  description = "Execution role (image pull and log delivery only)."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnets (two AZs) are required for availability."
  }
}

variable "security_group_ids" {
  description = "Security groups for the task ENIs."
  type        = list(string)
}

variable "load_balancer" {
  description = "Target group to register the tasks in (null for workers)."
  type = object({
    target_group_arn = string
  })
  default = null
}

variable "health_check_grace_period_seconds" {
  description = "Time to ignore LB health checks after a task starts (JVM warm-up)."
  type        = number
  default     = 60
}

variable "capacity_provider_strategy" {
  description = "Capacity provider strategy. E.g. processor: FARGATE base 1 + FARGATE_SPOT weight 3."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = [{ capacity_provider = "FARGATE", weight = 1, base = 1 }]

  validation {
    condition     = alltrue([for s in var.capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
    error_message = "capacity_provider must be FARGATE or FARGATE_SPOT."
  }
}

variable "autoscaling" {
  description = "Autoscaling bounds and CPU target tracking."
  type = object({
    min_capacity               = number
    max_capacity               = number
    cpu_target_percent         = optional(number, 60)
    scale_in_cooldown_seconds  = optional(number, 120)
    scale_out_cooldown_seconds = optional(number, 30)
  })

  validation {
    condition     = var.autoscaling.min_capacity >= 1 && var.autoscaling.max_capacity >= var.autoscaling.min_capacity
    error_message = "autoscaling requires 1 <= min_capacity <= max_capacity."
  }
}

variable "per_task_scaling" {
  description = "Target tracking policies on an external metric divided by RunningTaskCount (requests or SQS backlog per task), keyed by a short policy name. The service scales out if ANY policy asks for it."
  type = map(object({
    namespace       = string
    metric_name     = string
    statistic       = string
    dimensions      = map(string)
    target_per_task = number
  }))
  default = {}

  validation {
    condition     = alltrue([for k, p in var.per_task_scaling : can(regex("^[a-z0-9-]{1,40}$", k)) && p.target_per_task > 0])
    error_message = "per_task_scaling keys must be short lowercase names and target_per_task must be positive."
  }
}

variable "logs_kms_key_arn" {
  description = "CMK for the service log group."
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs."
  }
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
