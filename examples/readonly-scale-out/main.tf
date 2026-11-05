provider "volcenginecc" {
  region = var.region
}

# This expresses target capacity. Current node create-only fields can replace
# an existing instance; this is not a promise of in-place online scale-out.
module "cluster" {
  source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"

  instance_name          = "rds-cluster-readers"
  instance_type          = "DoubleNode"
  vpc_id                 = var.network.vpc_id
  subnet_id              = var.network.subnet_id
  security_group_ids     = var.network.security_group_ids
  administrator_password = var.administrator_password
  deletion_protection    = var.deletion_protection
  require_multi_az       = true
  create_proxy_endpoints = true
  nodes = merge({
    primary   = { node_type = "Primary", node_spec = var.node_spec, zone_id = var.network.primary_zone_id }
    secondary = { node_type = "Secondary", node_spec = var.node_spec, zone_id = var.network.secondary_zone_id }
    }, {
    for key, replica in var.read_replicas : "reader-${key}" => {
      node_type = "ReadOnly"
      node_spec = replica.node_spec
      zone_id   = replica.zone_id
    }
  })
}
