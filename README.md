# terraform-volcenginecc-rds-cluster

Draft Terraform module for private, highly available RDS MySQL deployments on VolcengineCC, covering MultiNode clusters and DoubleNode primary/standby deployments with read-only replicas.

## 1. Overview

The module owns one RDS MySQL instance and its complete node topology, one database allowlist, an optional parameter template and optional custom private writer/reader proxy endpoints. The caller owns the VPC, database subnet and security groups, and configures Provider authentication and region. The subnet must belong to the VPC and primary AZ; all nodes must be in the same region and at most three AZs. These relationships require cloud-side validation.

MultiNode has one Primary and 1–8 readable Secondary replicas. DoubleNode has one Primary, one Secondary standby and 0–10 ReadOnly replicas. Secondary specifications must match the Primary. Automatic failover is a service capability; this module has not completed a failover test. A single-AZ deployment does not survive an AZ outage. Reserve an unloaded Secondary for MultiNode failover where the service recommends it.

AWS Aurora cluster/replica/global examples and Alibaba Cloud RDS HA are scenario references. This is conventional RDS MySQL, without Aurora shared-storage semantics or an AWS-compatible Global Database. PostgreSQL, cross-region global replication, backup restore and zero-downtime online replica expansion are outside this draft.

## 2. Usage

Configure authentication through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`. Provide the administrator password using `TF_VAR_administrator_password`, without committing it. Caller variables supply existing resource IDs and an available regional node specification.

```hcl
provider "volcenginecc" {
  region = var.region
}

module "cluster" {
  source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"

  instance_name          = "application-cluster"
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_id
  security_group_ids     = var.security_group_ids
  administrator_password = var.administrator_password
  require_multi_az       = true
  nodes = {
    primary   = { node_type = "Primary", node_spec = var.node_spec, zone_id = var.primary_zone_id }
    secondary = { node_type = "Secondary", node_spec = var.node_spec, zone_id = var.secondary_zone_id }
  }
}
```

Registry source `terraform-volcenginecc-modules/rds-cluster/volcenginecc` is the intended publication address. No release has been confirmed and Registry consumption remains unverified. Static validation rewrites sources only in isolated temporary copies. Root Provider, credentials, region and backend remain under caller control.

## 3. Examples

- basic: single-AZ MultiNode cluster with one primary and one readable secondary, restricted security groups, default backup policy and service-created endpoints.
- complete: cross-AZ DoubleNode primary/standby plus a ReadOnly replica, custom private writer with read/write splitting, a reader without primary fallback, fourteen-day running-instance backup retention, tags and a parameter template.
- cross-az: MultiNode primary/secondary in different AZs. Add distinct Secondary tuples to express more replicas; at most eight secondaries and three AZs.
- readonly-scale-out: DoubleNode target read capacity using a logical-key replica map. This is a creation/target-capacity example; topology edits can replace the whole instance with the current Provider.

Each example requires an existing network. For custom Proxy endpoints, the module requests proxy CPU cores through the writable instance `cpu_num` field at creation. Proxy status remains Computed and must be verified independently. No endpoint silently falls back to Direct mode. Security groups use explicit `SecurityGroupBindInfos` with `IngressDirectionIp`.

## 4. Requirements

| Requirement | Contract |
|---|---|
| Terraform | Exact validation target: `1.5.7` |
| OpenTofu | Exact validation target: `1.11.8` |
| Shared engine range | `>= 1.5.7, < 1.12.0`; other versions in this range are not individually verified |
| Minimum Provider | `0.0.60`; used resources and fields checked against its published Schema |
| Current Provider | `0.0.73`; examples pin this release |
| Prerequisites | RDS/Cloud Control permissions, sufficient balance/quotas, valid regional specification, caller-owned network |

Status: `draft`. Both examples passed the retained configuration's real-cloud lifecycle on 2026-11-05 with Terraform 1.5.7 and Registry Provider 0.0.73: apply, independent control-plane readback, refreshed no-change plan, normal deletion-protection update and first standard destroy. State was empty and independent API queries confirmed managed resource absence. The module does not provide backup public-download control, retention after release or custom domain prefixes because the online Handler/Provider does not reliably support those settings. SQL routing is blocked by private-network reachability; failover and Registry consumption remain unverified.

## 5. Providers

| Name | Source | Version |
|---|---|---|
| `volcenginecc` | `volcengine/volcenginecc` | Root `>= 0.0.60`; examples `= 0.0.73` |

## 6. Resources

| Name | Mode | Responsibility |
|---|---|---|
| `volcenginecc_rdsmysql_instance.this` | Resource | Instance and all nodes; [Provider documentation](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_instance) |
| `volcenginecc_rdsmysql_allow_list.this` | Resource | Restricted client CIDRs and security-group association; [Provider documentation](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_allow_list) |
| `volcenginecc_rdsmysql_parameter_template.this` | Optional resource | Create-time parameter template binding; [Provider documentation](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_parameter_template) |
| `volcenginecc_rdsmysql_endpoint.writer`, `volcenginecc_rdsmysql_endpoint.reader` | Optional resources | DoubleNode proxies; writer creates before reader, reader destroys before writer; [Provider documentation](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_endpoint) |
| `data.volcenginecc_rdsmysql_endpoint.proxy` | Data sources | Read actual private domains/IPs after custom endpoint creation; [Provider documentation](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/data-sources/rdsmysql_endpoint) |

Default endpoints are observed through the instance and owned by its service lifecycle. No independent readonly-node resource competes with `instance.nodes`.

## 7. Inputs

| Name | Type | Default | Requirement and meaning |
|---|---|---|---|
| `instance_name` | `string` | Required | Starts with a letter; up to 128 characters, at most 57 with custom proxies |
| `vpc_id` | `string` | Required | Caller-owned VPC |
| `subnet_id` | `string` | Required | Caller-owned primary-AZ database subnet in the VPC |
| `security_group_ids` | `set(string)` | Required | 1–10 caller-owned restricted security groups |
| `allowed_cidrs` | `set(string)` | `null` | Additional IPv4 access; nonempty when set; /0 rejected |
| `instance_type` | `string` | `"MultiNode"` | MultiNode or DoubleNode; replacement on change |
| `nodes` | `map(object({node_spec=string,node_type=string,zone_id=string}))` | Required | Complete topology; roles Primary/Secondary/ReadOnly; duplicate tuples rejected |
| `require_multi_az` | `bool` | `false` | Require every Secondary to differ from the Primary AZ |
| `db_engine_version` | `string` | `"MySQL_8_0"` | MySQL_5_7 or MySQL_8_0; InnoDB engine fixed |
| `storage_space_gb` | `number` | `100` | Integer, at least 20; specification limits apply; replacement on change |
| `storage_type` | `string` | `"LocalSSD"` | LocalSSD, CloudESSD_FlexPL or CloudESSD_PL0 |
| `administrator_name` | `string` | `"clusteradmin"` | Create-time privileged name; replacement on change |
| `administrator_password` | `string`, sensitive | Required | 8–32 allowed characters and three character classes; create-time, persisted in State |
| `port` | `number` | `3306` | Integer 1000–65534; replacement on change |
| `deletion_protection` | `bool` | `true` | Disable with a separate apply before destruction |
| `backup_policy` | `object({retention_days=optional(number,7),weekdays=optional(set(string),all seven weekdays),start_utc_hour=optional(number,18),binlog_enabled=optional(bool,true)})` | `{}` | Running-instance retention and schedule; release retention and public-download control are excluded |
| `parameter_template` | `object({name=string,description=optional(string),parameters=map(string)})` | `null` | Module-owned template; nonempty parameters; version matches instance |
| `existing_parameter_template_id` | `string` | `null` | Caller-owned template; mutually exclusive with parameter_template |
| `create_proxy_endpoints` | `bool` | `false` | DoubleNode with ReadOnly replicas only; requests proxy CPU cores at instance creation |
| `proxy_cpu_num` | `number` | `2` | Proxy CPU cores, integer 2–1024; must also meet the API minimum for the primary specification |
| `read_replica_max_delay_seconds` | `number` | `30` | Integer 1–3600 seconds for writer proxy read routing; omitted for the ReadOnly reader; eventual consistency |
| `project_name` | `string` | `null` | Resource project; replacement on instance project change |
| `tags` | `map(string)` | `null` | Nonempty key/value map when set; no implicit tags |

`nodes` keys label configuration, not Terraform resource addresses. The Provider owns a set: renaming a key without changing its tuple has no resource effect, while duplicate role/specification/AZ tuples would collapse and are rejected. Primary and Secondary always share a specification. Billing is fixed to PostPaid; Optional+Computed billing fields are left undeclared rather than ignored.

## 8. Outputs

| Name | Type | Meaning |
|---|---|---|
| `instance_id` | `string` | Module-owned instance ID |
| `instance_status` | `string` | Provider-reported status; unknown until cloud read |
| `writer_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | Custom key writer or default endpoint IDs; private addresses only; can be empty |
| `reader_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | Custom key reader or default endpoint IDs; empty if no ReadOnly endpoint is reported |
| `topology` | `object({nodes=map(object({node_spec=string,node_type=string,zone_id=string})),secondary_count=number,readonly_count=number,availability_zones=set(string),observed_node_count=string})` | Configured node labels/counts and separately observed count |
| `allow_list_id` | `string` | Module-owned allowlist ID |
| `parameter_template_id` | `string` or `null` | Managed or caller-owned template; null when unspecified |

No administrator password is output. A writer proxy handles writes on Primary and can distribute reads; use the reader for explicit read-only traffic. Missing reader information produces an empty map, never a fabricated domain or an alias of the writer. Read-only endpoints do not provide read-after-write consistency.

## 9. Notes

The published Schema supports MultiNode and DoubleNode, but the [CreateDBNodes API](https://www.volcengine.com/docs/6313/1359331) adds Secondary to MultiNode and ReadOnly to DoubleNode. The [CreateDBEndpoint API](https://www.volcengine.com/docs/6313/170670) restricts custom creation to DoubleNode. MultiNode default endpoint splitting is observed, not configurable through this module. Custom endpoints require all replica IDs to appear in service-created endpoint weights and a working database proxy; the module rejects incomplete read-back instead of guessing identifiers.

Provider create-only fields include engine/version, instance type, node specification/role/AZ, storage size/type, network IDs, port, project, privileged credentials and parameter binding. A changed specification or AZ can replace the entire instance. Online addition/removal, password rotation and topology migration require Provider improvements and real-cloud acceptance; review every plan for replacement. No `ignore_changes`, SDK, local-exec or remote script hides these limitations.

Parameter templates are bound at creation. Changing a template's contents is not proof that running database parameters change; verify running values separately. Optional+Computed backup, tags, billing and endpoint fields need a refreshed second plan to establish no-change behavior. Null optional inputs leave values unspecified and do not promise remote clearing. Write-only credentials are still held by Terraform/OpenTofu State; protect State and saved Plan JSON, and keep debug logging disabled for credentials.

Import is supported by the underlying Provider: instance/allowlist/template use their resource IDs; custom endpoint identity is `instance_id|endpoint_id`. Import is a deliberate State migration, not an automatic existing-resource mode. Reconstruct the exact topology and review replacement before applying imported resources.

Deletion protection defaults to true. For an authorized cleanup, first apply `deletion_protection=false`, then destroy. The module does not configure backup public-download access or retention after release; these settings are controlled by the service. Final deletion queries reported Last/7 retention, which is not a module guarantee. Retained backups may remain billable and are not module-owned resources. Query active instances, endpoints, allowlist, managed template and retained backups after deletion; caller-owned networking remains external. No final snapshot is created.

Custom domains are generated by the service and returned through the endpoint data source. Custom domain prefixes and address edits are excluded because online Create/Read does not reliably preserve them. Proxy operations use a module dependency to avoid overlapping writes to the same instance. The complete lifecycle passed first standard destruction, with reader deleted before writer. Moved blocks migrate former `endpoint.proxy["writer"]` and `endpoint.proxy["reader"]` resource addresses; output keys remain writer/reader. Remove the former `endpoint_domain_prefix`, `keep_policy_after_release` and `keep_days_after_release` arguments from callers when upgrading.

The retained Terraform configuration passed both real-cloud lifecycles. SQL routing, failover and module Registry publication/consumption remain unverified.
