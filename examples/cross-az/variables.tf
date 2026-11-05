variable "region" {
  description = "Region of the caller-owned network."
  type        = string
}
variable "network" {
  description = "Existing network with database subnet in the primary AZ and a different secondary AZ."
  type = object({
    vpc_id             = string
    subnet_id          = string
    security_group_ids = set(string)
    primary_zone_id    = string
    secondary_zone_id  = string
  })
}
variable "node_spec" {
  description = "A regional RDS MySQL specification compatible with LocalSSD."
  type        = string
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
