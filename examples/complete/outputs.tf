output "instance_id" {
  description = "Managed RDS instance ID."
  value       = module.cluster.instance_id
}
output "writer_endpoints" {
  description = "Private writer proxy with read/write splitting."
  value       = module.cluster.writer_endpoints
}
output "reader_endpoints" {
  description = "Private reader proxy without primary-node fallback."
  value       = module.cluster.reader_endpoints
}
output "topology" {
  description = "Configured primary, standby and read-only replica."
  value       = module.cluster.topology
}
output "parameter_template_id" {
  description = "Module-owned parameter template ID."
  value       = module.cluster.parameter_template_id
}
output "allow_list_id" {
  description = "Module-owned database allowlist ID."
  value       = module.cluster.allow_list_id
}
