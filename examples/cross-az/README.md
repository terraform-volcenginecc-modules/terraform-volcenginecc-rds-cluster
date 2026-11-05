# Cross-AZ MultiNode cluster

Create a MultiNode RDS MySQL primary and readable secondary in distinct AZs, using caller-owned network resources and service-created endpoints. Automatic failover is a service feature; this example has not demonstrated failover or AZ outage recovery.

Use Terraform 1.5.7 or OpenTofu 1.11.8 and Provider 0.0.73. Intended Registry source: `terraform-volcenginecc-modules/rds-cluster/volcenginecc`; publication/consumption is unverified.

Prepare `deployment.tfvars` with region, node_spec and network (vpc_id, subnet_id, security_group_ids, primary_zone_id, secondary_zone_id). The AZs must differ and subnet must be in the primary AZ. Select a current regional LocalSSD-compatible specification. Supply Provider credentials through VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY and the password through TF_VAR_administrator_password.

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

Inspect topology and the private writer/reader endpoint maps. Empty endpoint maps mean the service has not reported that role. Default endpoint read splitting is observed, not managed. Add distinct Secondary configuration tuples for more read capacity, within eight secondaries and three AZs; reserve a standby for failover where recommended. Topology edits can replace the entire instance, so this does not promise online expansion.

For authorized cleanup, disable deletion protection with a separate apply, then destroy and independently query managed resources to confirm absence. Retention after release is service-controlled; Last/7 is an observed default, not a module guarantee. Verify actual retention and charges. Caller-owned network resources are retained.

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

Use `tofu` with separate State for OpenTofu. Availability, refreshed no-change, routing and destruction have not passed real-cloud acceptance.
