variable "region" {
  description = "Region of the caller-owned network."
  type        = string
}
variable "network" {
  description = "Existing network. Subnet must be in the primary AZ; secondary must use a different AZ. Reader may use either AZ or a third."
  type = object({
    vpc_id             = string
    subnet_id          = string
    security_group_ids = set(string)
    primary_zone_id    = string
    secondary_zone_id  = string
    reader_zone_id     = string
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
variable "project_name" {
  description = "Optional resource project."
  type        = string
  default     = null
}
variable "allowed_cidrs" {
  description = "Additional restricted IPv4 client CIDRs; null uses security groups only."
  type        = set(string)
  default     = null
}
