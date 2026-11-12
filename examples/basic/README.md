# BASIC RDS MySQL Cluster Example

## 1. Overview

This example uses an existing VPC, a primary-AZ database subnet and security groups to create a single-AZ MultiNode RDS MySQL instance with one primary and one readable secondary, default backups and service-created endpoints. Unlike complete, it creates no ReadOnly replicas, custom proxies or parameter templates. It suits a basic primary/secondary deployment; a single AZ cannot withstand an AZ outage.

## 2. Usage

Run from `examples/basic`. Prepare `terraform.tfvars` with `region`, `node_spec` and the complete `network` object. Keep `deletion_protection = true` or use its default. The subnet must belong to the VPC and primary AZ; the specification must be available in the region and compatible with LocalSSD.

`providers.tf` configures the provider using `var.region`. Supply deployment credentials through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`, and the administrator password through `TF_VAR_administrator_password`. Keep credentials out of `terraform.tfvars`.

1. Initialize to install the declared module and provider:

   ```shell
   terraform init
   ```

2. Review the first Plan. Expect a basic instance and allowlist to be created, with existing networking retained:

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

   Use `terraform output` to inspect the instance ID, topology and endpoints. Applications connect to a writer over a network path to the database's private addresses. A reader is available only if the service reports a read-only endpoint.

5. When destroying, review the resource scope and disable deletion protection with a separate apply. Pass the same value to both operations:

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   Destroy removes the managed instance and allowlist. Existing VPCs, subnets and security groups remain.

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
| `module.cluster` | Uses `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` to create a single-AZ MultiNode instance and database allowlist. |

This example root declares no direct resources or data sources and creates no prerequisite network resources.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Required `string`; region of the existing network and database, used to configure the provider. |
| `network` | Required object containing `vpc_id`, `subnet_id`, `primary_zone_id` (all `string`) and `security_group_ids` (`set(string)`). The subnet must belong to that VPC and primary AZ; supply 1–10 existing security group IDs. Primary and Secondary both use `primary_zone_id`. |
| `node_spec` | Required `string`, starting with `rds.mysql.`; must be regionally available and compatible with LocalSSD. Primary and Secondary use the same specification. |
| `administrator_password` | Required sensitive `string`, supplied through `TF_VAR_administrator_password`; 8–32 allowed characters and at least three of uppercase letters, lowercase letters, digits and special characters. Changing it replaces the instance. |
| `deletion_protection` | Optional `bool`, default `true`; disable with a separate apply before destroying. |

Unexposed settings use module defaults: MySQL 8.0, InnoDB, 100 GiB LocalSSD, port 3306, administrator `clusteradmin` and pay-as-you-go billing. Backups are retained for seven days and scheduled daily at 18:00 UTC, with binlog backups enabled and retention synchronized. The password allows letters, digits and special characters `!@#$%^&*()_+=,.&?|/-`.

## 7. Outputs

| Name | Description |
|---|---|
| `instance_id` | Managed RDS MySQL instance ID. |
| `writer_endpoints` | Service-reported private read/write endpoints, keyed by actual endpoint IDs. Values include connection mode, splitting switch and private domains/IPs/ports. Endpoints or addresses can be empty. |
| `reader_endpoints` | Service-reported private read-only endpoints; an empty map when no ReadOnly endpoint is reported. An empty map is not a connection address. |
| `topology` | Configured primary/secondary nodes, AZs and service-reported total node count. Configuration has `secondary_count = 1` and `readonly_count = 0`, with both nodes in one AZ. |

## 8. Example

This directory contains the basic example for a single-AZ primary/secondary deployment. Use complete when you need primary/standby placement across AZs, an independent ReadOnly replica, writer/reader proxies and a parameter template.

## 9. Notes

- Supply authentication credentials through provider-supported environment configuration and the administrator password through `TF_VAR_administrator_password`.
- Security groups bind to the allowlist using `IngressDirectionIp`, importing their ingress IP rules. Restrict rules to actual client networks before deploying.
- Read/write splitting depends on endpoint members. To distribute reads, select the cluster endpoint containing Primary and readable Secondary members. A primary-only endpoint does not distribute reads to Secondary.
- Run `terraform plan` after Apply; no changes are required for idempotence. Review instance replacement before changing node specifications, AZs, engine, storage or networking.
- Disable deletion protection before Destroy. The module creates no final snapshot; backup retention after release follows service policy. Save required backups before release and check retention charges. Existing networking remains.
