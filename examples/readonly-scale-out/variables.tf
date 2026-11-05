variable "region" {
  description = "Region of the caller-owned network."
  type        = string
}
variable "network" {
  description = "Existing VPC, primary-AZ database subnet, restricted security groups and distinct primary/secondary AZs."
  type = object({
    vpc_id             = string
    subnet_id          = string
    security_group_ids = set(string)
    primary_zone_id    = string
    secondary_zone_id  = string
  })
}
variable "node_spec" {
  description = "Primary/standby specification compatible with LocalSSD."
  type        = string
}
variable "read_replicas" {
  description = "Target read capacity by logical key; nonempty, at most 10 replicas. Identical role/specification/AZ tuples are unsupported by the Provider set."
  type        = map(object({ node_spec = string, zone_id = string }))
  validation {
    condition     = length(var.read_replicas) >= 1 && length(var.read_replicas) <= 10
    error_message = "Provide 1–10 read replica configurations."
  }
}
variable "administrator_password" {
  description = "Privileged password supplied through TF_VAR_administrator_password."
  type        = string
  sensitive   = true
}
variable "deletion_protection" {
  description = "Apply false separately before destroying the example."
  type        = bool
  default     = true
}
