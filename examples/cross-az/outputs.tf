output "instance_id" {
  description = "Managed multi-AZ cluster ID."
  value       = module.cluster.instance_id
}
output "writer_endpoints" {
  description = "Service-default private read/write endpoints."
  value       = module.cluster.writer_endpoints
}
output "reader_endpoints" {
  description = "Service-default private read-only endpoints; may be empty."
  value       = module.cluster.reader_endpoints
}
output "topology" {
  description = "Configured availability zones and replica counts."
  value       = module.cluster.topology
}
