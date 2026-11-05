output "instance_id" {
  description = "Managed cluster ID."
  value       = module.cluster.instance_id
}
output "writer_endpoints" {
  description = "Service-reported private read/write endpoints."
  value       = module.cluster.writer_endpoints
}
output "reader_endpoints" {
  description = "Service-reported private read-only endpoints; may be empty."
  value       = module.cluster.reader_endpoints
}
output "topology" {
  description = "Configured topology and observed node count."
  value       = module.cluster.topology
}
