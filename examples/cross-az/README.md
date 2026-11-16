# CROSS-AZ RDS MySQL Cluster Example

## 1. Overview

This example uses an existing VPC, a primary-AZ database subnet and security groups to create a cross-AZ MultiNode RDS MySQL instance with one primary, one readable secondary, default backups and service-created endpoints. Unlike basic, Primary and Secondary occupy different AZs. Unlike complete, it creates no independent ReadOnly replicas, custom proxies or parameter templates. RDS provides HA and automatic failover.

## 2. Usage

Run from `examples/cross-az`. Prepare `terraform.tfvars` with `region`, `node_spec` and the complete `network` object. Primary and Secondary must occupy different AZs. The subnet belongs to the VPC and primary AZ. Both nodes use the same specification, available in both AZs and compatible with LocalSSD. Retain default deletion protection.

`providers.tf` configures the provider using `var.region`. Supply deployment credentials through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`, and the administrator password through `TF_VAR_administrator_password`. Keep credentials out of source and variable files.

1. Initialize:

   ```shell
   terraform init
   ```

2. Review the first Plan. Expect an instance and allowlist, with different primary/secondary AZs:

   ```shell
   terraform plan
   ```

3. Deploy after reviewing the Plan:

   ```shell
   terraform apply
   ```

4. Run another Plan after deployment; expect no changes:

   ```shell
   terraform plan
   ```

   Use `terraform output` to inspect the instance ID, primary/secondary topology and private endpoints. Applications need a network path to the database's private addresses.

5. When destroying, review the deletion scope, disable deletion protection with a separate apply, then destroy:

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   The managed instance and allowlist are deleted. Existing VPCs, subnets and security groups remain.

## 3. Requirements

| Name | Version |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | `= 0.0.73` |

## 4. Providers

| Name | Source |
|---|---|
| `volcenginecc` | `volcengine/volcenginecc` |

The provider is configured in this directory's `providers.tf`, without an alias, and inherited by the module.

## 5. Resources

| Name | Description |
|---|---|
| `module.cluster` | Uses `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` to create a cross-AZ MultiNode instance and database allowlist. |

This example root declares no direct resources or data sources and creates no prerequisite networking.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Required `string`; region of the existing network and database, used to configure the provider. |
| `network` | Required object containing `vpc_id`, `subnet_id`, `primary_zone_id`, `secondary_zone_id` (all `string`) and `security_group_ids` (`set(string)`). The subnet must belong to that VPC and primary AZ; primary/secondary AZs must differ. Supply 1–10 existing security group IDs. |
| `node_spec` | Required `string`, starting with `rds.mysql.`, compatible with LocalSSD and available in both AZs. Primary and Secondary use the same specification. |
| `administrator_password` | Required sensitive `string`, supplied through `TF_VAR_administrator_password`; 8–32 allowed characters and at least three of uppercase letters, lowercase letters, digits and special characters. Changing it replaces the instance. |
| `deletion_protection` | Optional `bool`, default `true`; disable with a separate apply before destroying. |

Defaults are MySQL 8.0, InnoDB, 100 GiB LocalSSD, port 3306, administrator `clusteradmin` and pay-as-you-go billing. Backups are retained for seven days and scheduled daily at 18:00 UTC, with binlog backups enabled and retention synchronized. The password allows letters, digits and special characters `!@#$%^&*()_+=,.&?|/-`.

## 7. Outputs

| Name | Description |
|---|---|
| `instance_id` | Managed cross-AZ RDS MySQL instance ID. |
| `writer_endpoints` | Service-reported private read/write endpoints keyed by actual endpoint IDs, including connection mode, splitting switch and private domains/IPs/ports. Endpoints or addresses can be empty. |
| `reader_endpoints` | Service-reported private read-only endpoints; an empty map when no ReadOnly endpoint is reported. An empty map is not a connection address. |
| `topology` | Configured primary/readable-secondary topology and service-reported total node count. `secondary_count = 1`, `readonly_count = 0`, with Primary and Secondary in different AZs. |

## 8. Example

This directory contains the cross-az example for MultiNode deployment with a readable secondary across AZs. Use complete when you need an independent ReadOnly replica, custom writer/reader proxies and a parameter template.

## 9. Notes

- Supply authentication credentials through provider-supported environment configuration and the administrator password through `TF_VAR_administrator_password`.
- Security groups bind to the allowlist using `IngressDirectionIp`, importing their ingress IP rules. Restrict rules to actual client networks before deploying.
- The module uses service-default endpoints without changing their splitting policies. For read/write splitting, choose a cluster endpoint containing Primary and readable Secondary members. A primary-only endpoint does not distribute reads.
- Run `terraform plan` after Apply; no changes are required for idempotence. Changing node specifications or AZs can replace the entire instance; review replacement before applying.
- Disable deletion protection before Destroy. The module creates no final snapshot. Save required backups before release, then check service-retained backups and charges. Existing networking remains.
