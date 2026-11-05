# Target read-replica capacity

Express a DoubleNode RDS MySQL primary/standby with a caller-supplied map of read-only replicas and private writer/reader proxy endpoints. This example models target capacity at creation; it does not provide an accepted in-place scale-out workflow.

Use Terraform 1.5.7 or OpenTofu 1.11.8 and Provider 0.0.73. Intended source: `terraform-volcenginecc-modules/rds-cluster/volcenginecc`. Registry publication/consumption and real-cloud replica expansion are unverified.

Prepare `deployment.tfvars` with region, node_spec, network (vpc_id, subnet_id, security_group_ids, primary_zone_id, secondary_zone_id) and read_replicas (map of node_spec and zone_id). Use 1–10 read replicas across at most three total AZs, distinct role/specification/AZ tuples and distinct primary/secondary AZs. The subnet is in the primary AZ. Prefer replica specifications at least as capable as the primary to avoid lag/OOM. Supply credentials through VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY and the password through TF_VAR_administrator_password.

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

Inspect topology.readonly_count and the writer/reader private addresses. Proxies require the service to enable database proxy capability and report all replica IDs in default endpoint weights. Reader traffic has no Primary fallback. Validate actual routing, lag and no-change read-back separately.

Changing a map key alone leaves the Provider set unchanged. Adding, removing, moving or resizing a replica can replace the instance because node attributes are create-only. Do not apply an expansion plan until its replacement is acceptable. Independent readonly-node resources would conflict with the instance's complete node ownership and are not used.

For authorized cleanup, separately disable deletion protection, then destroy. Release retention is service-controlled; Last/7 is an observed default, not a module guarantee. Query backups, charges and managed resource absence. Service-generated endpoint domains are returned; custom prefixes and backup public-download control are excluded. The network remains caller-owned.

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

Use `tofu` with independent State for OpenTofu. Online expansion, failover, refreshed no-change and backup cleanup remain unverified.
