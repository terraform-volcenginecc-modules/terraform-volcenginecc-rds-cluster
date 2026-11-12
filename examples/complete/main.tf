module "cluster" {
  source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"

  instance_name                  = "rds-cluster-complete"
  instance_type                  = "DoubleNode"
  vpc_id                         = var.network.vpc_id
  subnet_id                      = var.network.subnet_id
  security_group_ids             = var.network.security_group_ids
  allowed_cidrs                  = var.allowed_cidrs
  administrator_password         = var.administrator_password
  require_multi_az               = true
  db_engine_version              = "MySQL_8_0"
  storage_space_gb               = 100
  storage_type                   = "LocalSSD"
  port                           = 3306
  deletion_protection            = var.deletion_protection
  create_proxy_endpoints         = true
  proxy_cpu_num                  = 2
  read_replica_max_delay_seconds = 30
  project_name                   = var.project_name
  tags                           = { Environment = "example", ManagedBy = "Terraform" }
  nodes = {
    primary   = { node_type = "Primary", node_spec = var.node_spec, zone_id = var.network.primary_zone_id }
    secondary = { node_type = "Secondary", node_spec = var.node_spec, zone_id = var.network.secondary_zone_id }
    reporting = { node_type = "ReadOnly", node_spec = var.node_spec, zone_id = var.network.reader_zone_id }
  }
  backup_policy = {
    retention_days = 14
    weekdays       = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    start_utc_hour = 18
    binlog_enabled = true
  }
  parameter_template = {
    name        = "rds-cluster-complete-parameters"
    description = "Application connection and slow-query settings"
    parameters  = { max_connections = "200", slow_query_log = "ON" }
  }
}
