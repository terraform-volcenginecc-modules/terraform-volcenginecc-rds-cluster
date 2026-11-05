output "instance_id" {
  description = "Managed RDS instance ID."
  value       = module.cluster.instance_id
}
output "writer_endpoints" {
  description = "Private read/write proxy endpoints."
  value       = module.cluster.writer_endpoints
}
output "reader_endpoints" {
  description = "Private read-only proxy endpoints."
  value       = module.cluster.reader_endpoints
}
output "topology" {
  description = "Target read replica capacity and observed node count."
  value       = module.cluster.topology
}
