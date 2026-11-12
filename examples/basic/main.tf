module "cluster" {
  source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"

  instance_name          = "rds-cluster-basic"
  vpc_id                 = var.network.vpc_id
  subnet_id              = var.network.subnet_id
  security_group_ids     = var.network.security_group_ids
  administrator_password = var.administrator_password
  deletion_protection    = var.deletion_protection
  nodes = {
    primary   = { node_type = "Primary", node_spec = var.node_spec, zone_id = var.network.primary_zone_id }
    secondary = { node_type = "Secondary", node_spec = var.node_spec, zone_id = var.network.primary_zone_id }
  }
}
