variable "region" {
  description = "Region of the caller-owned network."
  type        = string
}
variable "network" {
  description = "Existing VPC, database subnet, restricted security groups and primary AZ."
  type = object({
    vpc_id             = string
    subnet_id          = string
    security_group_ids = set(string)
    primary_zone_id    = string
  })
}
variable "node_spec" {
  description = "A currently available RDS MySQL specification compatible with LocalSSD in this region."
  type        = string
}
variable "administrator_password" {
  description = "Privileged account password supplied through TF_VAR_administrator_password."
  type        = string
  sensitive   = true
}
variable "deletion_protection" {
  description = "Apply false separately before destroying the example."
  type        = bool
  default     = true
}
