# Basic single-AZ cluster

Create a single-AZ RDS MySQL MultiNode primary/secondary cluster using caller-owned networking, restricted security groups, a sensitive administrator password and the default backup policy. This does not provide AZ outage protection.

Use Terraform 1.5.7 or OpenTofu 1.11.8, with Provider 0.0.73. Intended source: `terraform-volcenginecc-modules/rds-cluster/volcenginecc`. Registry publication/consumption is unverified; local checks rewrite only temporary copies.

Prepare `deployment.tfvars` containing region, node_spec and network (vpc_id, subnet_id, security_group_ids, primary_zone_id). The subnet must belong to the VPC and primary AZ. Obtain a currently available LocalSSD-compatible node specification. Provide Provider credentials via VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY and the password via TF_VAR_administrator_password.

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

Use writer_endpoints for read/write access and reader_endpoints for explicit read-only access if reported; an empty map is not a connection address. Use `tofu` for OpenTofu in a separate directory and State. On 2026-11-05, the retained configuration passed a real-cloud lifecycle with Terraform 1.5.7 and Registry Provider 0.0.73: apply, independent control-plane readback, refreshed plan with no changes, and the first standard destroy. State was empty and independent API queries confirmed resource absence. SQL routing remains blocked by private-network reachability; failover is unverified.

For authorized cleanup, apply deletion protection off before destroy. Release retention and backup public download are not configurable by this module. Last/7 was observed as the service default; verify actual retained backups and charges, and independently query deleted managed resources to confirm absence. Network resources remain caller-owned.

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

Topology, storage, engine, credentials and network changes can replace the instance. Review replacement before applying.
