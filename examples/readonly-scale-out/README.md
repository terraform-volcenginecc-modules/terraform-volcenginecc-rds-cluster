# READONLY-SCALE-OUT RDS MySQL Cluster Example

## 1. Overview

This example uses an existing network and a caller-supplied replica map to create a cross-AZ DoubleNode RDS MySQL primary/standby instance, 1–10 ReadOnly replicas and private writer/reader proxies. Unlike complete, each read replica has its own specification and AZ, and no parameter template is created. It models target read capacity; changing node attributes can replace the entire instance and is not a guarantee of zero-downtime in-place scaling.

## 2. Usage

Run from `examples/readonly-scale-out`. Prepare `terraform.tfvars` with `region`, `node_spec`, the complete `network` object and `read_replicas`. Primary and Secondary occupy different AZs; the subnet belongs to the VPC and primary AZ. All nodes span at most three AZs. Configure 1–10 ReadOnly replicas with distinct specification/role/AZ tuples.

`providers.tf` configures the provider using `var.region`. Supply deployment credentials through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`, and the administrator password through `TF_VAR_administrator_password`. Keep credentials out of source and variable files. Choose available specifications compatible with LocalSSD and retain default deletion protection.

1. Initialize:

   ```shell
   terraform init
   ```

2. Review the first Plan. Confirm replica count, specifications and AZs, and creation of the instance, allowlist and two proxies:

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

   Use `terraform output` to check `topology.readonly_count` and private writer/reader addresses. Applications need a network path to the database's private addresses. Use writer for writes and reader for explicit read-only requests.

5. When destroying, review the deletion scope, disable deletion protection with a separate apply, then destroy:

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   Reader is deleted before writer, followed by the managed instance and allowlist. Existing networking remains.

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
| `module.cluster` | Uses `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` to create a cross-AZ DoubleNode instance, its complete replica topology, database allowlist and writer/reader proxies. |

This example root declares no direct resources or data sources and creates no prerequisite networking.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Required `string`; region of the existing network and database, used to configure the provider. |
| `network` | Required object containing `vpc_id`, `subnet_id`, `primary_zone_id`, `secondary_zone_id` (all `string`) and `security_group_ids` (`set(string)`). The subnet must belong to that VPC and primary AZ; primary/standby AZs must differ. Supply 1–10 existing security group IDs. |
| `node_spec` | Required `string`, starting with `rds.mysql.`; Primary and Secondary share an available specification compatible with LocalSSD. The proxy defaults to two CPU cores, which must meet the API minimum `max(2, primary CPU cores × 0.125)`. |
| `read_replicas` | Required `map(object({node_spec=string,zone_id=string}))` with 1–10 replicas. Each requires a specification starting with `rds.mysql.` and a nonempty AZ. Duplicate specification/role/AZ tuples are rejected; all nodes span at most three AZs. |
| `administrator_password` | Required sensitive `string`, supplied through `TF_VAR_administrator_password`; 8–32 allowed characters and at least three of uppercase letters, lowercase letters, digits and special characters. Changing it replaces the instance. |
| `deletion_protection` | Optional `bool`, default `true`; disable with a separate apply before destroying. |

Defaults are MySQL 8.0, InnoDB, 100 GiB LocalSSD, port 3306, administrator `clusteradmin` and pay-as-you-go billing. Backups are retained for seven days and scheduled daily at 18:00 UTC, with binlog backups enabled and retention synchronized. Writer allows a maximum replication lag of 30 seconds. The password allows letters, digits and special characters `!@#$%^&*()_+=,.&?|/-`.

`read_replicas` keys are configuration labels. The module prefixes node labels with `reader-`. Renaming keys does not change the provider's node set. Review the Plan for instance replacement when adding, deleting, moving or resizing replicas.

## 7. Outputs

| Name | Description |
|---|---|
| `instance_id` | Managed DoubleNode RDS MySQL instance ID. |
| `writer_endpoints` | Private read/write proxy keyed by `writer`, including endpoint ID, splitting switch and private domains/IPs/ports. The address list can be empty. |
| `reader_endpoints` | Private read-only proxy keyed by `reader`; connects only to ReadOnly replicas without Primary fallback. The address list can be empty. |
| `topology` | Configured primary/standby and read replicas, AZ set and service-reported total node count. `secondary_count = 1`; `readonly_count` equals the number of entries in `read_replicas`. |

## 8. Example

This directory contains the readonly-scale-out example for configuring target read capacity through a replica map. Use complete for one fixed ReadOnly replica and a parameter template. Topology changes here do not guarantee online in-place scaling.

## 9. Notes

- Supply authentication credentials through provider-supported environment configuration and the administrator password through `TF_VAR_administrator_password`.
- Security groups bind to the allowlist using `IngressDirectionIp`, importing their ingress IP rules. Restrict rules to actual client networks before deploying.
- Custom proxies require all ReadOnly node IDs to be reported by the instance. Writer sends writes to Primary and distributes reads to ReadOnly replicas. Reader connects only to replicas without Primary fallback; replica reads do not guarantee immediate visibility after writes.
- The instance manages the complete node topology. New replicas do not automatically join custom endpoints. Before changing replicas, review whole-instance replacement and application downtime.
- Run `terraform plan` after Apply; no changes are required for idempotence.
- Disable deletion protection before Destroy. The module creates no final snapshot. Save required backups before release, then check service-retained backups and charges. Existing VPCs, subnets and security groups remain.
