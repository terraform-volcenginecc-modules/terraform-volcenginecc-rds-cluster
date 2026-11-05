variable "instance_name" {
  description = "RDS instance name; 1–128 characters, starting with a letter."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_-]{0,127}$", var.instance_name))
    error_message = "instance_name must start with a letter and contain only letters, digits, underscores and hyphens."
  }
}

variable "vpc_id" {
  description = "Caller-owned VPC ID."
  type        = string
  validation {
    condition     = can(regex("^vpc-.+", var.vpc_id))
    error_message = "vpc_id must be a nonempty VPC ID."
  }
}

variable "subnet_id" {
  description = "Caller-owned database subnet in the VPC and primary availability zone."
  type        = string
  validation {
    condition     = can(regex("^subnet-.+", var.subnet_id))
    error_message = "subnet_id must be a nonempty subnet ID."
  }
}

variable "security_group_ids" {
  description = "1–10 caller-owned security groups bound through the managed RDS allowlist."
  type        = set(string)
  validation {
    condition     = length(var.security_group_ids) >= 1 && length(var.security_group_ids) <= 10 && alltrue([for id in var.security_group_ids : can(regex("^sg-.+", id))])
    error_message = "Provide 1–10 nonempty security group IDs."
  }
}

variable "allowed_cidrs" {
  description = "Additional IPv4 allowlist entries; null delegates access to the security groups. Unrestricted /0 access is rejected."
  type        = set(string)
  default     = null
  validation {
    condition     = var.allowed_cidrs == null ? true : length(var.allowed_cidrs) > 0 && alltrue([for cidr in var.allowed_cidrs : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) > 0, false)])
    error_message = "allowed_cidrs must be null or a nonempty set of IPv4 CIDRs with a prefix longer than /0."
  }
}

variable "instance_type" {
  description = "MultiNode: one primary and 1–8 readable secondary replicas. DoubleNode: one primary, one standby and 0–10 ReadOnly replicas. Changing type replaces the instance."
  type        = string
  default     = "MultiNode"
  validation {
    condition     = contains(["MultiNode", "DoubleNode"], var.instance_type)
    error_message = "Only MultiNode and DoubleNode high-availability architectures are supported."
  }
}

variable "nodes" {
  description = "Complete topology owned exclusively by the instance. Logical keys label configuration only; the Provider uses a set of node_spec/node_type/zone_id and does not expose node IDs. Topology edits can replace the instance."
  type = map(object({
    node_spec = string
    node_type = string
    zone_id   = string
  }))
  validation {
    condition = length(var.nodes) >= 2 && alltrue([
      for node in var.nodes : contains(["Primary", "Secondary", "ReadOnly"], node.node_type) && can(regex("^rds\\.mysql\\.", node.node_spec)) && length(trimspace(node.zone_id)) > 0
    ])
    error_message = "Provide at least two nodes with valid roles, RDS MySQL specifications and availability zones."
  }
  validation {
    condition     = length(distinct([for node in var.nodes : jsonencode(node)])) == length(var.nodes)
    error_message = "Duplicate role/specification/zone tuples cannot be represented by the Provider set; use distinct zones or specifications."
  }
  validation {
    condition     = length(distinct([for node in var.nodes : node.zone_id])) <= 3
    error_message = "An RDS MySQL instance supports at most three availability zones."
  }
}

variable "require_multi_az" {
  description = "Require the primary and every standby to occupy different zones."
  type        = bool
  default     = false
}

variable "db_engine_version" {
  description = "Provider-supported MySQL compatibility version; changing it replaces the instance."
  type        = string
  default     = "MySQL_8_0"
  validation {
    condition     = contains(["MySQL_5_7", "MySQL_8_0"], var.db_engine_version)
    error_message = "This module exposes MySQL_5_7 and MySQL_8_0 from the verified Provider Schema."
  }
}

variable "storage_space_gb" {
  description = "Purchased storage in GiB; changing it replaces the instance in the current Provider. Cloud-side specification limits also apply."
  type        = number
  default     = 100
  validation {
    condition     = var.storage_space_gb >= 20 && var.storage_space_gb == floor(var.storage_space_gb)
    error_message = "storage_space_gb must be an integer of at least 20."
  }
}

variable "storage_type" {
  description = "LocalSSD, CloudESSD_FlexPL or CloudESSD_PL0; check regional specification compatibility before applying."
  type        = string
  default     = "LocalSSD"
  validation {
    condition     = contains(["LocalSSD", "CloudESSD_FlexPL", "CloudESSD_PL0"], var.storage_type)
    error_message = "Select a documented RDS MySQL storage type."
  }
}

variable "administrator_name" {
  description = "Create-time privileged account name; changing it replaces the instance."
  type        = string
  default     = "clusteradmin"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,31}$", var.administrator_name))
    error_message = "administrator_name must start with a lowercase letter and contain lowercase letters, digits or underscores, up to 32 characters."
  }
}

variable "administrator_password" {
  description = "Create-time privileged password, 8–32 characters and at least three character classes. Sensitive in plans; persisted in State. Rotation replaces the instance with this Provider."
  type        = string
  sensitive   = true
  validation {
    condition = length(var.administrator_password) >= 8 && length(var.administrator_password) <= 32 && can(regex("^[A-Za-z0-9!@#$%^&*()_+=,.&?|/\\-]+$", var.administrator_password)) && sum([
      length(regexall("[A-Z]", var.administrator_password)) > 0 ? 1 : 0,
      length(regexall("[a-z]", var.administrator_password)) > 0 ? 1 : 0,
      length(regexall("[0-9]", var.administrator_password)) > 0 ? 1 : 0,
      length(regexall("[^A-Za-z0-9]", var.administrator_password)) > 0 ? 1 : 0
    ]) >= 3
    error_message = "administrator_password must contain 8–32 allowed characters and at least three of uppercase, lowercase, digits and special characters."
  }
}

variable "port" {
  description = "Private database port; changing it replaces the instance."
  type        = number
  default     = 3306
  validation {
    condition     = var.port >= 1000 && var.port <= 65534 && var.port == floor(var.port)
    error_message = "port must be an integer between 1000 and 65534."
  }
}

variable "deletion_protection" {
  description = "Protect the instance against deletion. Apply false separately before an authorized destroy."
  type        = bool
  default     = true
}

variable "backup_policy" {
  description = "Running-instance backup retention, weekdays, UTC start hour and binlog switch. Public download and retention after release are not configurable with the verified online Handler; no final snapshot resource is created."
  type = object({
    retention_days = optional(number, 7)
    weekdays       = optional(set(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    start_utc_hour = optional(number, 18)
    binlog_enabled = optional(bool, true)
  })
  default = {}
  validation {
    condition = var.backup_policy.retention_days >= 7 && var.backup_policy.retention_days <= 3650 && var.backup_policy.retention_days == floor(var.backup_policy.retention_days) && var.backup_policy.start_utc_hour >= 0 && var.backup_policy.start_utc_hour <= 23 && var.backup_policy.start_utc_hour == floor(var.backup_policy.start_utc_hour) && length(var.backup_policy.weekdays) > 0 && alltrue([
      for day in var.backup_policy.weekdays : contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], day)
    ])
    error_message = "Use retention of 7–3650 whole days, nonempty weekday names and UTC hour 0–23."
  }
}

variable "parameter_template" {
  description = "Optional module-owned MySQL parameter template. Parameters are a map of parameter name to string value; engine/version match the instance. Applying changes to an existing template is not guaranteed to update the instance."
  type = object({
    name        = string
    description = optional(string)
    parameters  = map(string)
  })
  default = null
  validation {
    condition     = var.parameter_template == null ? true : length(trimspace(var.parameter_template.name)) > 0 && length(var.parameter_template.parameters) > 0 && alltrue([for key, value in var.parameter_template.parameters : length(trimspace(key)) > 0 && length(value) > 0])
    error_message = "parameter_template requires a name and a nonempty map of parameter names and values."
  }
}

variable "existing_parameter_template_id" {
  description = "Caller-owned parameter template ID, mutually exclusive with parameter_template. Binding changes replace the instance."
  type        = string
  default     = null
  validation {
    condition     = var.existing_parameter_template_id == null ? true : length(trimspace(var.existing_parameter_template_id)) > 0
    error_message = "existing_parameter_template_id must be null or nonempty."
  }
}

variable "create_proxy_endpoints" {
  description = "Create private writer/read-splitting and reader proxy endpoints for DoubleNode instances containing ReadOnly nodes, requesting proxy CPU cores at instance creation. MultiNode uses service-created default endpoints."
  type        = bool
  default     = false
}

variable "proxy_cpu_num" {
  description = "Proxy CPU cores requested at instance creation when create_proxy_endpoints is true. API minimum is max(2, primary CPU cores * 0.125); regional limits still apply. Changes require reviewing the Provider plan."
  type        = number
  default     = 2
  validation {
    condition     = var.proxy_cpu_num >= 2 && var.proxy_cpu_num <= 1024 && var.proxy_cpu_num == floor(var.proxy_cpu_num)
    error_message = "proxy_cpu_num must be an integer from 2 to 1024, also satisfying the primary-node-dependent API minimum."
  }
}

variable "read_replica_max_delay_seconds" {
  description = "Maximum replication lag for custom proxy routing, 1–3600 seconds. Does not make reads strongly consistent."
  type        = number
  default     = 30
  validation {
    condition     = var.read_replica_max_delay_seconds >= 1 && var.read_replica_max_delay_seconds <= 3600 && var.read_replica_max_delay_seconds == floor(var.read_replica_max_delay_seconds)
    error_message = "read_replica_max_delay_seconds must be an integer between 1 and 3600."
  }
}

variable "project_name" {
  description = "Optional project for managed resources; changing the instance project replaces it."
  type        = string
  default     = null
}

variable "tags" {
  description = "Optional instance tags, converted to explicit key/value objects. Null leaves tags unspecified; empty maps are rejected to avoid null/set drift."
  type        = map(string)
  default     = null
  validation {
    condition     = var.tags == null ? true : length(var.tags) > 0 && alltrue([for key, value in var.tags : length(trimspace(key)) > 0 && length(value) > 0])
    error_message = "tags must be null or a nonempty map of nonempty keys and values."
  }
}
