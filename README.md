# terraform-volcenginecc-rds-cluster

Create private, highly available RDS MySQL instances with VolcengineCC and configure primary/secondary topology, read replicas, read/write splitting and backups.

## 1. Overview

This module creates one private RDS MySQL HA instance, its node topology and allowlist, with optional parameter templates and writer/reader proxies. MultiNode uses readable Secondary replicas; DoubleNode uses a standby and optional ReadOnly replicas. Provide an existing VPC, a subnet in the primary AZ and security groups. All nodes share one region and span at most three AZs; HA and automatic failover are provided by RDS.


## 2. Usage

Prepare an existing VPC, database subnet, 1–10 security groups and a regional RDS MySQL node specification compatible with the storage type. The subnet must belong to the VPC and primary AZ. Restrict security group ingress rules to actual client networks. The deployment identity needs RDS and Cloud Control resource management permissions, with sufficient account balance and quotas.

Declare version constraints and the provider source in the calling project's `versions.tf`. This configuration uses the same provider version as basic/complete:

```hcl
terraform {
  required_version = ">= 1.5.7, < 1.12.0"
  required_providers {
    volcenginecc = {
      source  = "volcengine/volcenginecc"
      version = "= 0.0.73"
    }
  }
}
```

Configure the region in the calling project's `providers.tf`:

```hcl
provider "volcenginecc" {
  region = var.region
}
```

Declare inputs in the calling project's `variables.tf`:

```hcl
variable "region" {
  type = string
}

variable "network" {
  type = object({
    vpc_id             = string
    subnet_id          = string
    security_group_ids = set(string)
    primary_zone_id    = string
  })
}

variable "node_spec" {
  type = string
}

variable "administrator_password" {
  type      = string
  sensitive = true
}
```

Create a single-AZ MultiNode instance in the calling project's `main.tf`:

```hcl
module "cluster" {
  source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"

  instance_name          = "application-cluster"
  vpc_id                 = var.network.vpc_id
  subnet_id              = var.network.subnet_id
  security_group_ids     = var.network.security_group_ids
  administrator_password = var.administrator_password
  nodes = {
    primary   = { node_type = "Primary", node_spec = var.node_spec, zone_id = var.network.primary_zone_id }
    secondary = { node_type = "Secondary", node_spec = var.node_spec, zone_id = var.network.primary_zone_id }
  }
}
```

Set `region`, `node_spec` and the complete `network` object in the calling project's `terraform.tfvars`. Supply provider credentials through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`, and the administrator password through `TF_VAR_administrator_password`. Keep credentials out of source and variable files.

Run `terraform init`, `terraform plan` and `terraform apply` in the calling directory. Define caller outputs using `module.cluster.instance_id`, `module.cluster.writer_endpoints` and `module.cluster.topology`. Applications need a network path to the database's private VPC addresses.

## 3. Examples

- basic: single-AZ MultiNode with one primary and one readable secondary, default backups and service-created endpoints; requires an existing VPC, primary-AZ subnet and security groups.
- complete: cross-AZ DoubleNode with one primary, one standby and one ReadOnly replica, custom private writer/reader proxies, a parameter template, tags and fourteen-day backup retention; requires an existing network and different primary/standby AZs.
- cross-az: MultiNode with the primary and readable secondary in different AZs; requires an existing network and specification availability in both AZs.
- readonly-scale-out: a replica map defines DoubleNode target read capacity with writer/reader proxies; requires an existing network and at least one ReadOnly replica. Topology changes can replace the instance.

Run each example from its own `examples/basic`, `examples/complete`, `examples/cross-az` or `examples/readonly-scale-out` directory. All examples use `terraform.tfvars` for inputs.

## 4. Requirements

| Name | Version |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | Root module `>= 0.0.60`; basic/complete pin `= 0.0.73` |

## 5. Providers

| Name | Source |
|---|---|
| `volcenginecc` | `volcengine/volcenginecc` |

The module inherits the caller's default provider configuration without an alias. The caller configures region and authentication.

## 6. Resources

| Mode | Type | Name |
|---|---|---|
| Create | `volcenginecc_rdsmysql_instance` | [volcenginecc_rdsmysql_instance.this](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_instance) |
| Create | `volcenginecc_rdsmysql_allow_list` | [volcenginecc_rdsmysql_allow_list.this](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_allow_list) |
| Optional create | `volcenginecc_rdsmysql_parameter_template` | [volcenginecc_rdsmysql_parameter_template.this](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_parameter_template) |
| Optional create | `volcenginecc_rdsmysql_endpoint` | [volcenginecc_rdsmysql_endpoint.writer](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_endpoint) |
| Optional create | `volcenginecc_rdsmysql_endpoint` | [volcenginecc_rdsmysql_endpoint.reader](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_endpoint) |
| Optional read | `volcenginecc_rdsmysql_endpoint` | [data.volcenginecc_rdsmysql_endpoint.proxy](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/data-sources/rdsmysql_endpoint) |

The module always creates one instance and one allowlist. Setting `parameter_template` creates one template. Enabling `create_proxy_endpoints` creates two proxies and reads their private addresses. Service-default endpoints follow the instance lifecycle, and the instance owns the entire node topology. The module does not create VPCs, subnets or security groups.

## 7. Inputs

| Name | Type | Default | Required in create mode | Description |
|---|---|---|---|---|
| `instance_name` | `string` | None | Yes | 1–128 characters, starting with a letter; letters, digits, underscores and hyphens only. At most 57 characters with custom proxies. |
| `vpc_id` | `string` | None | Yes | Existing VPC ID, starting with `vpc-`. |
| `subnet_id` | `string` | None | Yes | Existing database subnet ID, starting with `subnet-`; must belong to the specified VPC and primary AZ. |
| `security_group_ids` | `set(string)` | None | Yes | 1–10 existing security group IDs, starting with `sg-`; binding to the allowlist imports ingress IP rules. |
| `allowed_cidrs` | `set(string)` | `null` | No | Additional IPv4 allowlist entries; a nonempty set with prefixes greater than 0 when specified. `null` uses security group rules only. |
| `instance_type` | `string` | `"MultiNode"` | No | `MultiNode` or `DoubleNode`; node roles and counts must match the selected topology. Changing it replaces the instance. |
| `nodes` | `map(object({node_spec=string,node_type=string,zone_id=string}))` | None | Yes | Complete topology with at least two nodes. Each requires a specification, role and AZ; roles are `Primary`, `Secondary` or `ReadOnly`. |
| `require_multi_az` | `bool` | `false` | No | When `true`, every Secondary must be in a different AZ from Primary. Does not constrain the ReadOnly AZ. |
| `db_engine_version` | `string` | `"MySQL_8_0"` | No | `MySQL_5_7` or `MySQL_8_0`, with InnoDB fixed as the engine. Changing it replaces the instance. |
| `storage_space_gb` | `number` | `100` | No | Storage in GiB; integer of at least 20, also subject to service specification limits. Changing it replaces the instance. |
| `storage_type` | `string` | `"LocalSSD"` | No | `LocalSSD`, `CloudESSD_FlexPL` or `CloudESSD_PL0`; select a type compatible with the region and node specification. |
| `administrator_name` | `string` | `"clusteradmin"` | No | Privileged account created with the instance; 1–32 characters, starting with a lowercase letter, using lowercase letters, digits and underscores. Changing it replaces the instance. |
| `administrator_password` | `string` | None | Yes | Sensitive input; 8–32 allowed characters, including at least three of uppercase letters, lowercase letters, digits and special characters. Changing it replaces the instance. |
| `port` | `number` | `3306` | No | Private database port, integer 1000–65534. Changing it replaces the instance. |
| `deletion_protection` | `bool` | `true` | No | Instance deletion protection. Apply `false` separately before destroying. |
| `backup_policy` | `object` | `{}` | No | Running-instance backup retention and schedule; field types, defaults and limits appear below. |
| `parameter_template` | `object({name=string,description=optional(string),parameters=map(string)})` | `null` | No | Create a module-managed parameter template. Name and parameter map are required and nonempty; parameter names and values must be nonempty. Its version matches the instance. |
| `existing_parameter_template_id` | `string` | `null` | No | Bind an existing template; cannot be an empty string when specified. Mutually exclusive with `parameter_template`. Changing the binding replaces the instance. |
| `create_proxy_endpoints` | `bool` | `false` | No | Create private writer/reader proxies for DoubleNode with at least one ReadOnly replica. Requests proxy CPU cores at instance creation. |
| `proxy_cpu_num` | `number` | `2` | No | Proxy CPU cores, integer 2–1024; also must meet the API minimum `max(2, primary CPU cores × 0.125)` and regional limits. Used only for custom proxies. |
| `read_replica_max_delay_seconds` | `number` | `30` | No | Maximum replication lag allowed for writer proxy read routing, integer 1–3600 seconds. Omitted for the read-only reader; does not guarantee strong consistency. |
| `project_name` | `string` | `null` | No | Project for managed resources. Changing the instance project replaces the instance. |
| `tags` | `map(string)` | `null` | No | Instance tags; the map, keys and values must be nonempty when specified. No implicit tags. |

For `nodes`, MultiNode requires one Primary and 1–8 readable Secondary replicas, without ReadOnly nodes. DoubleNode requires one Primary, one Secondary and 0–10 ReadOnly replicas. All Secondary specifications must match Primary. Specifications start with `rds.mysql.`, AZs must be nonempty, and the instance can span at most three AZs.

Node map keys are configuration labels. The provider manages nodes as a set of specification/role/AZ tuples. Renaming a key does not change a node; duplicate tuples are rejected. Review the Plan for whole-instance replacement when changing nodes.

The complete `backup_policy` type and field defaults are:

```hcl
object({
  retention_days = optional(number, 7)
  weekdays = optional(set(string), [
    "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday", "Sunday"
  ])
  start_utc_hour = optional(number, 18)
  binlog_enabled = optional(bool, true)
})
```

`retention_days` is an integer from 7 to 3650 days. `weekdays` is a nonempty set containing only the seven English day names above. `start_utc_hour` is an integer from 0 to 23 in UTC; the default 18 corresponds to 02:00 the following day in Beijing. Binlog retention is synchronized with data backup retention.

The password allows letters, digits and special characters `!@#$%^&*()_+=,.&?|/-`. Billing is fixed to pay-as-you-go (`PostPaid`). A `null` optional input leaves the setting unspecified; it does not clear an existing service-side value.

## 8. Outputs

| Name | Type | Description |
|---|---|---|
| `instance_id` | `string` | Managed RDS MySQL instance ID for instance queries and connection configuration. |
| `instance_status` | `string` | Provider-reported instance status; unknown before creation and readback. |
| `writer_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | Private read/write endpoints; keyed by `writer` in custom mode or actual endpoint IDs in default mode. May be an empty map if the service reports no matching endpoint. |
| `reader_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | Private read-only endpoints; keyed by `reader` in custom mode or actual endpoint IDs in default mode. Empty when no ReadOnly endpoint is reported. |
| `topology` | `object({nodes=map(object({node_spec=string,node_type=string,zone_id=string})),secondary_count=number,readonly_count=number,availability_zones=set(string),observed_node_count=string})` | Configured nodes, secondary/read-only counts and AZ set, plus the service-reported total node count. Node keys are not service node IDs. |
| `allow_list_id` | `string` | Module-managed database allowlist ID. |
| `parameter_template_id` | `string`, nullable | Managed or caller-supplied parameter template ID; `null` when no template is configured. |

Applications obtain domains, IPs and ports from `private_addresses`. Only private addresses are returned; address lists can also be empty. Use `reader_endpoints` for read-only access. An empty reader map is not a connection address and is never replaced with a writer address.

`read_write_splitting` reports an endpoint's splitting switch; actual read routing depends on its members. A primary-only read/write endpoint sends both reads and writes to Primary. For MultiNode splitting, select the cluster endpoint containing Primary and readable Secondary members. A custom writer sends writes to Primary and distributes reads to ReadOnly replicas. A reader connects only to ReadOnly replicas without Primary fallback; replica reads do not guarantee immediate visibility after a write.

## 9. Notes

- The module manages the instance, entire node topology, allowlist and optional template/proxies. The caller maintains existing VPCs, subnets, security groups and external templates. Import instances, allowlists and templates by their resource IDs; custom endpoint import identity is `instance_id|endpoint_id`. Reconstruct the actual configuration after import and review the replacement scope in the Plan.
- Primary and Secondary must use the same specification. A single-AZ deployment cannot withstand an AZ outage. For AZ fault isolation, place Primary and Secondary in different AZs and set `require_multi_az = true`. This module configures RDS MySQL, without Aurora shared storage or cross-region Global Database.
- Custom proxies require DoubleNode with ReadOnly replicas. The instance's default endpoint information must report all ReadOnly node IDs so proxy membership can be configured. MultiNode uses service-default endpoints; the module does not change their splitting policies. Proxy addresses are service-generated; custom domain prefixes are not exposed.
- The custom writer is created before the reader and destroyed after it. New nodes do not automatically join these endpoints. Review the Plan for instance replacement before changing topology, instance type, engine, storage, network, port, project or parameter binding. Editing the topology map is not a guarantee of zero-downtime online scaling.
- Parameter templates are bound when the instance is created. After editing a template, check the database's running parameters; template values alone do not establish live settings.
- After deployment, run a normal `terraform plan` again and expect no changes to confirm idempotence.
- Before destroying, disable deletion protection with a separate apply. Destroy removes module-managed resources and retains caller-owned networking and external templates. The module creates no final snapshot and does not configure backup retention after release or public backup download. Save required backups separately before release and check service-retained backups and charges afterward.
- For existing callers, `moved` blocks migrate former `volcenginecc_rdsmysql_endpoint.proxy["writer"]` and `volcenginecc_rdsmysql_endpoint.proxy["reader"]` addresses. Output keys remain `writer`/`reader`. Remove the former `endpoint_domain_prefix`, `keep_policy_after_release` and `keep_days_after_release` arguments.
