locals {
  primary_nodes   = [for node in var.nodes : node if node.node_type == "Primary"]
  secondary_nodes = [for node in var.nodes : node if node.node_type == "Secondary"]
  readonly_nodes  = [for node in var.nodes : node if node.node_type == "ReadOnly"]
  parameter_template_id = var.parameter_template == null ? var.existing_parameter_template_id : (
    volcenginecc_rdsmysql_parameter_template.this[0].template_id
  )

  # Discover replica IDs from the service-created endpoints. Do not guess IDs
  # or create a second Terraform owner for instance.nodes.
  readonly_node_ids = sort(distinct(flatten([
    for endpoint in coalesce(volcenginecc_rdsmysql_instance.this.endpoints, []) : [
      for node in coalesce(endpoint.read_only_node_weight, []) : node.node_id
      if node.node_type == "ReadOnly" && try(length(node.node_id) > 0, false)
    ]
  ])))
}

resource "volcenginecc_rdsmysql_allow_list" "this" {
  allow_list_name     = "${var.instance_name}-access"
  allow_list_type     = "IPv4"
  allow_list_category = "Ordinary"
  security_group_bind_infos = [
    for id in sort(tolist(var.security_group_ids)) : {
      security_group_id   = id
      bind_mode           = "IngressDirectionIp"
      security_group_name = null
    }
  ]
  user_allow_list = var.allowed_cidrs
  project_name    = var.project_name
}

resource "volcenginecc_rdsmysql_parameter_template" "this" {
  count = var.parameter_template == null ? 0 : 1

  template_name         = var.parameter_template.name
  template_desc         = var.parameter_template.description
  template_type         = "Mysql"
  template_type_version = var.db_engine_version
  engine_type           = "InnoDB"
  project_name          = var.project_name
  template_params = [
    for name, value in var.parameter_template.parameters : {
      name          = name
      running_value = value
    }
  ]
}

resource "volcenginecc_rdsmysql_instance" "this" {
  instance_name          = var.instance_name
  instance_type          = var.instance_type
  cpu_num                = var.create_proxy_endpoints ? var.proxy_cpu_num : null
  db_engine_version      = var.db_engine_version
  engine_type            = "InnoDB"
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_id
  nodes                  = values(var.nodes)
  storage_space          = var.storage_space_gb
  storage_type           = var.storage_type
  charge_detail          = { charge_type = "PostPaid" }
  allow_list_ids         = [volcenginecc_rdsmysql_allow_list.this.allow_list_id]
  super_account_name     = var.administrator_name
  super_account_password = var.administrator_password
  port                   = var.port
  deletion_protection    = var.deletion_protection ? "Enabled" : "Disabled"
  db_param_group_id      = local.parameter_template_id
  project_name           = var.project_name
  tags                   = var.tags == null ? null : [for key, value in var.tags : { key = key, value = value }]

  backup_policy = {
    backup_policy_base = {
      data_backup_retention_day       = var.backup_policy.retention_days
      data_full_backup_periods        = var.backup_policy.weekdays
      data_full_backup_start_utc_hour = var.backup_policy.start_utc_hour
      binlog_backup_enabled           = var.backup_policy.binlog_enabled
      retention_policy_synced         = true
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.primary_nodes) == 1 && length(local.secondary_nodes) >= 1 && length(local.secondary_nodes) <= (var.instance_type == "MultiNode" ? 8 : 1) && length(local.readonly_nodes) <= (var.instance_type == "MultiNode" ? 0 : 10)
      error_message = "MultiNode requires one Primary and 1–8 Secondary nodes, without ReadOnly nodes. DoubleNode requires one Primary, one Secondary and 0–10 ReadOnly nodes."
    }
    precondition {
      condition     = alltrue([for node in local.secondary_nodes : node.node_spec == try(local.primary_nodes[0].node_spec, "")])
      error_message = "Every Secondary specification must match the Primary specification."
    }
    precondition {
      condition     = !var.require_multi_az || alltrue([for node in local.secondary_nodes : node.zone_id != try(local.primary_nodes[0].zone_id, "")])
      error_message = "require_multi_az requires every Secondary to be outside the Primary availability zone."
    }
    precondition {
      condition     = var.parameter_template == null || var.existing_parameter_template_id == null
      error_message = "Set parameter_template or existing_parameter_template_id, not both."
    }
    precondition {
      condition     = !var.create_proxy_endpoints || (var.instance_type == "DoubleNode" && length(local.readonly_nodes) > 0)
      error_message = "Custom proxy endpoints require DoubleNode and at least one ReadOnly node; the API does not create custom MultiNode endpoints."
    }
    precondition {
      condition     = !var.create_proxy_endpoints || length(var.instance_name) <= 57
      error_message = "Custom endpoint names require instance_name of at most 57 characters including the writer/reader suffix."
    }
  }
}

resource "volcenginecc_rdsmysql_endpoint" "writer" {
  count = var.create_proxy_endpoints ? 1 : 0

  instance_id                      = volcenginecc_rdsmysql_instance.this.instance_id
  endpoint_type                    = "Custom"
  endpoint_name                    = "${var.instance_name}-writer"
  connection_mode                  = "Proxy"
  read_write_mode                  = "ReadWrite"
  nodes                            = join(",", concat(["Primary"], local.readonly_node_ids))
  auto_add_new_nodes               = false
  read_write_spliting              = true
  read_only_node_distribution_type = "RoundRobinAuto"
  read_only_node_max_delay_time    = var.read_replica_max_delay_seconds
  master_node_routing              = false

  lifecycle {
    precondition {
      condition     = length(local.readonly_node_ids) == length(local.readonly_nodes)
      error_message = "The instance must report every ReadOnly node ID through its default endpoint weights before custom endpoints can be created."
    }
  }
}

resource "volcenginecc_rdsmysql_endpoint" "reader" {
  count = var.create_proxy_endpoints ? 1 : 0

  # Both endpoints change the same instance proxy. Encode their ordering in
  # the graph so normal parallel apply/destroy does not race these operations.
  depends_on = [volcenginecc_rdsmysql_endpoint.writer]

  instance_id         = volcenginecc_rdsmysql_instance.this.instance_id
  endpoint_type       = "Custom"
  endpoint_name       = "${var.instance_name}-reader"
  connection_mode     = "Proxy"
  read_write_mode     = "ReadOnly"
  nodes               = join(",", local.readonly_node_ids)
  auto_add_new_nodes  = false
  read_write_spliting = false
  master_node_routing = false

  lifecycle {
    precondition {
      condition     = length(local.readonly_node_ids) == length(local.readonly_nodes)
      error_message = "The instance must report every ReadOnly node ID through its default endpoint weights before custom endpoints can be created."
    }
  }
}

moved {
  from = volcenginecc_rdsmysql_endpoint.proxy["writer"]
  to   = volcenginecc_rdsmysql_endpoint.writer[0]
}

moved {
  from = volcenginecc_rdsmysql_endpoint.proxy["reader"]
  to   = volcenginecc_rdsmysql_endpoint.reader[0]
}

# Resource addresses are optional configuration fields; the singular data
# source provides computed private domains/IPs after endpoint creation.
data "volcenginecc_rdsmysql_endpoint" "proxy" {
  for_each = var.create_proxy_endpoints ? {
    writer = volcenginecc_rdsmysql_endpoint.writer[0].endpoint_id
    reader = volcenginecc_rdsmysql_endpoint.reader[0].endpoint_id
  } : {}
  id = "${volcenginecc_rdsmysql_instance.this.instance_id}|${each.value}"
}
