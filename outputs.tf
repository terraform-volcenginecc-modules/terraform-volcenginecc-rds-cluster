locals {
  default_endpoints = {
    for endpoint in coalesce(volcenginecc_rdsmysql_instance.this.endpoints, []) : endpoint.endpoint_id => {
      id                   = endpoint.endpoint_id
      read_write_mode      = endpoint.read_write_mode
      connection_mode      = endpoint.connection_mode
      read_write_splitting = endpoint.enable_read_write_splitting == "Enable"
      private_addresses = [
        for address in coalesce(endpoint.addresses, []) : {
          domain     = address.domain
          ip_address = address.ip_address
          port       = address.port
          subnet_id  = address.subnet_id
        } if address.network_type == "Private"
      ]
    }
  }
  custom_endpoints = {
    for role, endpoint in data.volcenginecc_rdsmysql_endpoint.proxy : role => {
      id                   = endpoint.endpoint_id
      read_write_mode      = endpoint.read_write_mode
      connection_mode      = endpoint.connection_mode
      read_write_splitting = endpoint.read_write_spliting
      private_addresses = [
        for address in coalesce(endpoint.addresses, []) : {
          domain     = address.domain
          ip_address = address.ip_address
          port       = address.port
          subnet_id  = address.subnet_id
        } if address.network_type == "Private"
      ]
    }
  }
}

output "instance_id" {
  description = "Managed RDS MySQL instance ID."
  value       = volcenginecc_rdsmysql_instance.this.instance_id
}

output "instance_status" {
  description = "Provider-reported status; static plans do not verify availability or failover."
  value       = volcenginecc_rdsmysql_instance.this.instance_status
}

output "writer_endpoints" {
  description = "Private read/write endpoints, keyed by writer for custom mode or endpoint ID for service-default mode. A writer proxy may also route reads to replicas. Empty when the service has not reported one."
  value = var.create_proxy_endpoints ? {
    writer = local.custom_endpoints["writer"]
    } : {
    for id, endpoint in local.default_endpoints : id => endpoint if endpoint.read_write_mode == "ReadWrite"
  }
}

output "reader_endpoints" {
  description = "Private read-only endpoints, keyed by reader for custom mode or endpoint ID for service-default mode. Empty if the service does not report a read-only endpoint; never synthesized from a writer address."
  value = var.create_proxy_endpoints ? {
    reader = local.custom_endpoints["reader"]
    } : {
    for id, endpoint in local.default_endpoints : id => endpoint if endpoint.read_write_mode == "ReadOnly"
  }
}

output "topology" {
  description = "Configured logical nodes and counts. Keys are labels, not independently managed node IDs; changing only a key does not change the Provider set."
  value = {
    nodes               = var.nodes
    secondary_count     = length(local.secondary_nodes)
    readonly_count      = length(local.readonly_nodes)
    availability_zones  = toset([for node in var.nodes : node.zone_id])
    observed_node_count = volcenginecc_rdsmysql_instance.this.node_number
  }
}

output "allow_list_id" {
  description = "Module-owned allowlist ID; VPC, subnet and security groups remain caller-owned."
  value       = volcenginecc_rdsmysql_allow_list.this.allow_list_id
}

output "parameter_template_id" {
  description = "Managed or caller-owned template ID; null when no template was specified."
  value       = local.parameter_template_id
}
