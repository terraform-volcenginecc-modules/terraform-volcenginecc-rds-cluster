# COMPLETE RDS MySQL Cluster Example

## 1. Overview

This example uses an existing network to create a cross-AZ DoubleNode RDS MySQL instance with one primary, one standby and one ReadOnly replica, private writer/reader proxies, a parameter template, tags and fourteen-day backups. Compared with basic, it adds primary/standby placement across AZs, an independent read replica and explicit read/write splitting. Provide a VPC, primary-AZ subnet, security groups and AZs for the primary, standby and reader.

## 2. Usage

Run from `examples/complete`. Prepare `terraform.tfvars` with `region`, `node_spec` and the complete `network` object, optionally setting `project_name` and `allowed_cidrs`. Primary and Secondary must occupy different AZs. Reader may share either AZ or use a third. The subnet must belong to the VPC and primary AZ. All three nodes use one available specification compatible with LocalSSD.

`providers.tf` configures the provider using `var.region`. Supply deployment credentials through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`, and the administrator password through `TF_VAR_administrator_password`. Keep credentials out of `terraform.tfvars`. Retain default deletion protection and confirm node, storage and proxy quotas cover the configuration.

1. Initialize to install the declared module and provider:

   ```shell
   terraform init
   ```

2. Review the first Plan. Expect an instance, allowlist, parameter template and two custom proxies:

   ```shell
   terraform plan
   ```

3. Deploy after reviewing the Plan. Writer is created before reader:

   ```shell
   terraform apply
   ```

4. Run another Plan after deployment; expect no changes:

   ```shell
   terraform plan
   ```

   Use `terraform output` to obtain private addresses from `writer_endpoints["writer"]` and `reader_endpoints["reader"]`. Applications need a network path to the database's private addresses. Use writer for writes and reader for explicit read-only requests.

5. When destroying, review the resource scope and disable deletion protection with a separate apply. Pass the same value to both operations:

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   Reader is deleted before writer, followed by the managed instance, allowlist and template. Existing networking remains.

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
| `module.cluster` | Uses `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` to create a cross-AZ DoubleNode instance, allowlist, parameter template and writer/reader proxies. |

This example root declares no direct resources or data sources and creates no prerequisite network resources.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Required `string`; region of the existing network and database, used to configure the provider. |
| `network` | Required object containing `vpc_id`, `subnet_id`, `primary_zone_id`, `secondary_zone_id`, `reader_zone_id` (all `string`) and `security_group_ids` (`set(string)`). The subnet must belong to that VPC and primary AZ; supply 1–10 existing security group IDs. Primary/standby AZs must differ; reader may share either or use a third. |
| `node_spec` | Required `string`, starting with `rds.mysql.`; must be regionally available and compatible with LocalSSD. All three nodes use this specification. The example requests two proxy CPU cores and must meet the API minimum `max(2, primary CPU cores × 0.125)`. |
| `administrator_password` | Required sensitive `string`, supplied through `TF_VAR_administrator_password`; 8–32 allowed characters and at least three of uppercase letters, lowercase letters, digits and special characters. Changing it replaces the instance. |
| `deletion_protection` | Optional `bool`, default `true`; disable with a separate apply before destroying. |
| `project_name` | Optional `string`, default `null`; project for managed resources. Changing the instance project replaces it. |
| `allowed_cidrs` | Optional `set(string)`, default `null` for security group rules only. When set, a nonempty set of IPv4 CIDRs with prefixes greater than 0, adding client allowlist entries. |

The example fixes MySQL 8.0, InnoDB, 100 GiB LocalSSD, port 3306 and pay-as-you-go billing. The administrator defaults to `clusteradmin`. The password allows letters, digits and special characters `!@#$%^&*()_+=,.&?|/-`.

Backups are retained for fourteen days and scheduled daily at 18:00 UTC, with binlog backups enabled and retention synchronized. The parameter template sets `max_connections = "200"` and `slow_query_log = "ON"`. Instance tags are `Environment = "example"` and `ManagedBy = "Terraform"`. Writer read routing allows a maximum replication lag of 30 seconds.

## 7. Outputs

| Name | Description |
|---|---|
| `instance_id` | Managed RDS MySQL instance ID. |
| `writer_endpoints` | Private read/write proxy keyed by `writer`; includes endpoint ID, splitting switch and private domains/IPs/ports. The address list can be empty. |
| `reader_endpoints` | Private read-only proxy keyed by `reader`; connects only to ReadOnly replicas without Primary fallback. The address list can be empty. |
| `topology` | Configured primary, standby and ReadOnly topology plus service-reported total node count. Configuration has `secondary_count = 1` and `readonly_count = 1`; Primary and Secondary occupy different AZs. |
| `parameter_template_id` | Template ID created by this example and bound at instance creation. |
| `allow_list_id` | Database allowlist ID created by this example. |

## 8. Example

This directory contains the complete example for primary/standby placement across AZs, an independent ReadOnly replica, explicit read/write splitting and parameter template configuration. Use basic for a single-AZ primary/secondary deployment.

## 9. Notes

- Supply authentication credentials through provider-supported environment configuration and the administrator password through `TF_VAR_administrator_password`.
- Security groups bind to the allowlist using `IngressDirectionIp`, importing their ingress IP rules. The `/0` validation on `allowed_cidrs` does not inspect existing security group rules; review actual client access before deploying.
- Custom proxies require all ReadOnly node IDs to be reported by the instance. Writer sends writes to Primary and distributes reads to ReadOnly replicas. Reader connects only to replicas without Primary fallback. Replica reads do not guarantee immediate visibility after writes; choose endpoints according to application consistency requirements.
- The parameter template binds at instance creation. Check running database parameters after editing the template. New nodes do not automatically join custom endpoints, and topology changes can replace the entire instance.
- Run `terraform plan` after Apply; no changes are required for idempotence. Review instance replacement before changing nodes, engine, storage, networking or parameter binding.
- Disable deletion protection before Destroy. Destroy removes managed proxies, instance, allowlist and template, retaining existing VPCs, subnets and security groups. The module creates no final snapshot; backup retention after release follows service policy. Save required backups before release and check retention charges.
