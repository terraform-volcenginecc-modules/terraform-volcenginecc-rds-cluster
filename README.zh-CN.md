# terraform-volcenginecc-rds-cluster

使用 VolcengineCC 创建私网 RDS MySQL 高可用实例，配置主备拓扑、只读副本、读写分离和备份策略。

## 1. 概述（Overview）

本模块创建一个私网 RDS MySQL 高可用实例及其完整节点拓扑和数据库白名单，可选创建参数模板与 writer/reader 代理端点。MultiNode 使用可读 Secondary 副本，DoubleNode 使用主备节点和可选 ReadOnly 副本。调用方提供已有 VPC、位于主节点可用区的数据库子网和安全组；所有节点位于同一地域，最多分布在三个可用区。高可用和自动故障切换由 RDS 服务提供。

![架构边界图](https://bytedance.larkoffice.com/space/api/box/stream/download/asynccode/?code=ZDJjOGRmOGZlNzkzZWM5MjM5ZjI2ZTU5M2NjZTgyMWVfVll5YkpsU1B0Tk1iSktXSmU5Y3Nmd1k1Rk5hS2ZtWmhfVG9rZW46TUVpYWIwYjRtb0JCVWV4a0tNbmNrSWk5bmNoXzE3MzEzNDc2OTU6MTczMTM1MTI5NV9WNA)

## 2. 用法（Usage）

准备已有 VPC、数据库子网、1–10 个安全组，以及目标地域可用且兼容存储类型的 RDS MySQL 节点规格。子网属于所填 VPC，并位于主节点可用区；安全组入方向规则应只允许实际客户端网段。部署身份需要具备 RDS 和 Cloud Control 的资源管理权限，账号余额与配额能够满足配置。

在调用方的 `versions.tf` 中声明版本和 Provider 来源。以下调用使用与 basic/complete 相同的 Provider 版本：

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

在调用方的 `providers.tf` 中配置地域：

```hcl
provider "volcenginecc" {
  region = var.region
}
```

在调用方的 `variables.tf` 中声明输入：

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

在调用方的 `main.tf` 中创建单可用区 MultiNode 实例：

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

将 `region`、`node_spec` 和完整 `network` 对象填入调用方的 `terraform.tfvars`。通过运行环境中的 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 提供 Provider 凭据，通过 `TF_VAR_administrator_password` 提供管理员密码；凭据不写入源码或参数文件。

在调用方目录执行 `terraform init`、`terraform plan` 和 `terraform apply`。创建后可通过 `module.cluster.instance_id`、`module.cluster.writer_endpoints` 和 `module.cluster.topology` 定义调用方输出。应用连接数据库时，需要能访问该 VPC 私网地址的网络路径。

## 3. 示例（Examples）

- basic：单可用区 MultiNode，一主一可读备节点，使用默认备份策略和服务创建的端点；依赖已有 VPC、主节点子网和安全组。
- complete：跨可用区 DoubleNode，一主一备加一个 ReadOnly 副本，创建 writer/reader 私网代理、参数模板和标签，备份保留 14 天；主备位于不同可用区，依赖已有网络。
- cross-az：跨可用区 MultiNode，主节点与可读备节点分布在不同可用区；依赖已有网络和两个可用区的节点规格支持。
- readonly-scale-out：通过副本 Map 配置 DoubleNode 的目标只读容量，并创建 writer/reader 代理；依赖已有网络和至少一个 ReadOnly 副本，修改拓扑可能重建实例。

各示例在自己的 `examples/basic`、`examples/complete`、`examples/cross-az` 或 `examples/readonly-scale-out` 目录执行，输入文件统一为 `terraform.tfvars`。

## 4. 版本要求（Requirements）

| 名称 | 版本 |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | 根模块 `>= 0.0.60`；basic/complete 固定为 `= 0.0.73` |

## 5. Providers（Providers）

| 名称 | 来源 |
|---|---|
| `volcenginecc` | `volcengine/volcenginecc` |

根模块使用调用方传入的默认 Provider 配置，无 alias；地域和认证由调用方配置。

## 6. 资源（Resources）

| 模式 | 类型 | 名称 |
|---|---|---|
| 创建 | `volcenginecc_rdsmysql_instance` | [volcenginecc_rdsmysql_instance.this](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_instance) |
| 创建 | `volcenginecc_rdsmysql_allow_list` | [volcenginecc_rdsmysql_allow_list.this](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_allow_list) |
| 可选创建 | `volcenginecc_rdsmysql_parameter_template` | [volcenginecc_rdsmysql_parameter_template.this](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_parameter_template) |
| 可选创建 | `volcenginecc_rdsmysql_endpoint` | [volcenginecc_rdsmysql_endpoint.writer](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_endpoint) |
| 可选创建 | `volcenginecc_rdsmysql_endpoint` | [volcenginecc_rdsmysql_endpoint.reader](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_endpoint) |
| 可选读取 | `volcenginecc_rdsmysql_endpoint` | [data.volcenginecc_rdsmysql_endpoint.proxy](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/data-sources/rdsmysql_endpoint) |

固定创建一个实例和一个白名单。配置 `parameter_template` 时创建一个模板；开启 `create_proxy_endpoints` 时创建两个代理端点，并读取各自的私网地址。服务默认端点随实例管理，全部节点由实例拓扑统一管理。模块不创建 VPC、子网或安全组。

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 创建模式下是否必填 | 说明 |
|---|---|---|---|---|
| `instance_name` | `string` | 无 | 是 | 1–128 字符，字母开头，仅含字母、数字、下划线和连字符；创建自定义代理时最多 57 字符。 |
| `vpc_id` | `string` | 无 | 是 | 已有 VPC ID，以 `vpc-` 开头。 |
| `subnet_id` | `string` | 无 | 是 | 已有数据库子网 ID，以 `subnet-` 开头，属于所填 VPC 和主节点可用区。 |
| `security_group_ids` | `set(string)` | 无 | 是 | 1–10 个已有安全组 ID，以 `sg-` 开头；通过白名单绑定并导入入方向 IP 规则。 |
| `allowed_cidrs` | `set(string)` | `null` | 否 | 额外 IPv4 白名单；设置时为非空集合，CIDR 前缀大于 0；`null` 表示只通过安全组规则配置访问。 |
| `instance_type` | `string` | `"MultiNode"` | 否 | `MultiNode` 或 `DoubleNode`，节点角色和数量应符合对应拓扑；修改会替换实例。 |
| `nodes` | `map(object({node_spec=string,node_type=string,zone_id=string}))` | 无 | 是 | 完整节点拓扑，至少两个节点；各节点的规格、角色、可用区均必填，角色为 `Primary`、`Secondary` 或 `ReadOnly`。 |
| `require_multi_az` | `bool` | `false` | 否 | 设为 `true` 时，每个 Secondary 都要与 Primary 位于不同可用区；不强制 ReadOnly 的可用区。 |
| `db_engine_version` | `string` | `"MySQL_8_0"` | 否 | `MySQL_5_7` 或 `MySQL_8_0`，引擎固定为 InnoDB；修改会替换实例。 |
| `storage_space_gb` | `number` | `100` | 否 | 存储容量，单位 GiB，整数且至少为 20；还应符合云端规格限制，修改会替换实例。 |
| `storage_type` | `string` | `"LocalSSD"` | 否 | `LocalSSD`、`CloudESSD_FlexPL` 或 `CloudESSD_PL0`；按地域和节点规格选择兼容类型。 |
| `administrator_name` | `string` | `"clusteradmin"` | 否 | 创建时的高权限账号名，1–32 字符，小写字母开头，仅含小写字母、数字和下划线；修改会替换实例。 |
| `administrator_password` | `string` | 无 | 是 | 敏感输入；8–32 个允许字符，至少包含大写字母、小写字母、数字、特殊字符中的三类；修改会替换实例。 |
| `port` | `number` | `3306` | 否 | 数据库私网端口，1000–65534 的整数；修改会替换实例。 |
| `deletion_protection` | `bool` | `true` | 否 | 实例删除保护；销毁前先单独 apply 设为 `false`。 |
| `backup_policy` | `object` | `{}` | 否 | 运行期间的备份保留与计划；子字段类型、默认值和范围如下。 |
| `parameter_template` | `object({name=string,description=optional(string),parameters=map(string)})` | `null` | 否 | 创建模块管理的参数模板；名称和参数 Map 必填且非空，参数名称和值均非空，版本与实例一致。 |
| `existing_parameter_template_id` | `string` | `null` | 否 | 绑定已有参数模板，设置时不能为空字符串；与 `parameter_template` 互斥，修改绑定会替换实例。 |
| `create_proxy_endpoints` | `bool` | `false` | 否 | 创建自定义 writer/reader 私网代理，仅适用于至少含一个 ReadOnly 副本的 DoubleNode；创建实例时申请代理 CPU。 |
| `proxy_cpu_num` | `number` | `2` | 否 | 代理 CPU 核数，2–1024 的整数，同时满足 API 下限 `max(2, 主节点 CPU 核数 × 0.125)` 和地域限制；仅开启自定义代理时使用。 |
| `read_replica_max_delay_seconds` | `number` | `30` | 否 | writer 代理读路由允许的最大复制延迟，1–3600 的整数秒；不传给只读 reader，不保证强一致读取。 |
| `project_name` | `string` | `null` | 否 | 受管资源所属项目；修改实例项目会替换实例。 |
| `tags` | `map(string)` | `null` | 否 | 实例标签；设置时 Map、标签名称和值均非空，无隐式标签。 |

`nodes` 中，MultiNode 要求一个 Primary、1–8 个可读 Secondary，不能包含 ReadOnly；DoubleNode 要求一个 Primary、一个 Secondary 和 0–10 个 ReadOnly。所有 Secondary 的规格与 Primary 相同。规格以 `rds.mysql.` 开头，可用区不能为空，整个实例最多使用三个可用区。

节点 Map 的 key 只是配置标签，节点由 Provider 按规格、角色和可用区组成的集合管理。只改 key 不改变节点；重复的规格/角色/可用区组合会被拒绝。变更节点配置时检查 Plan 是否替换整个实例。

`backup_policy` 的完整类型与默认子字段为：

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

`retention_days` 为 7–3650 的整数天；`weekdays` 为非空集合，只能填写上述七个英文星期名称；`start_utc_hour` 为 0–23 的整数 UTC 小时，默认 18 对应北京时间次日 02:00。binlog 保留策略与数据备份保留同步。

管理员密码允许字母、数字及特殊字符 `!@#$%^&*()_+=,.&?|/-`。实例计费固定为按量付费（`PostPaid`）。可选输入为 `null` 表示未指定该配置，不表示清空云端已有值。

## 8. 输出（Outputs）

| 名称 | 类型 | 说明 |
|---|---|---|
| `instance_id` | `string` | 受管 RDS MySQL 实例 ID，可用于查询实例和连接配置。 |
| `instance_status` | `string` | Provider 返回的实例状态，创建和读取前未知。 |
| `writer_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | 私网读写端点；自定义模式的 key 为 `writer`，默认模式为实际端点 ID；服务未返回对应端点时可为空 Map。 |
| `reader_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | 私网只读端点；自定义模式的 key 为 `reader`，默认模式为实际端点 ID；没有 ReadOnly 端点时为空 Map。 |
| `topology` | `object({nodes=map(object({node_spec=string,node_type=string,zone_id=string})),secondary_count=number,readonly_count=number,availability_zones=set(string),observed_node_count=string})` | 配置中的节点、备节点数、只读副本数和可用区集合，以及服务返回的节点总数；节点 key 不是云端节点 ID。 |
| `allow_list_id` | `string` | 模块管理的数据库白名单 ID。 |
| `parameter_template_id` | `string`，可为 `null` | 模块创建或调用方提供的参数模板 ID；未配置模板时为 `null`。 |

应用从 `private_addresses` 获取域名、IP 和端口；只返回私网地址，地址列表也可能为空。只读访问使用 `reader_endpoints`，为空时不能将其当作连接地址，也不会用 writer 地址代替。

`read_write_splitting` 反映端点的分离开关；实际读路由取决于端点成员。只有主节点的读写端点，其读写都落到主节点。MultiNode 需要读写分离时，选择成员包含主节点和可读备节点的集群端点。自定义 writer 向 Primary 写入并向 ReadOnly 副本分发读取，reader 只连接 ReadOnly，不回退到 Primary；副本读取不保证写后立即可见。

## 9. 其他说明（Notes）

- 模块管理实例、完整节点拓扑、白名单及可选模板和代理；已有 VPC、子网、安全组及外部参数模板由调用方维护。已有实例、白名单或模板的导入使用各自资源 ID，自定义端点导入标识为 `instance_id|endpoint_id`；导入后还原实际配置并检查 Plan 的替换范围。
- 高可用部署的主备节点要使用相同规格。单可用区部署不能抵御整个可用区故障；需要可用区故障隔离时，将主备分布在不同可用区并设置 `require_multi_az = true`。本模块配置的是 RDS MySQL，不提供 Aurora 共享存储或跨地域 Global Database。
- 自定义代理仅适用于带 ReadOnly 副本的 DoubleNode。实例默认端点信息需要包含全部 ReadOnly 节点 ID，代理才能配置成员。MultiNode 使用服务默认端点，模块不修改其分离策略。代理地址由服务生成，模块不提供自定义域名前缀。
- 自定义 writer 先于 reader 创建，销毁顺序相反；新增节点不会自动加入这两个端点。修改拓扑、实例类型、引擎、存储、网络、端口、项目或参数绑定时，先检查 Plan 是否替换实例，不能将拓扑 Map 的修改当作无中断在线扩容。
- 参数模板在创建实例时绑定。修改模板内容后，核对数据库运行参数是否生效，不把模板配置值当作运行值。
- 部署完成后再次执行正常的 `terraform plan`，预期无变化，以确认幂等性。
- 销毁前先单独 apply 关闭删除保护，再执行 destroy。销毁删除模块管理的资源，保留调用方已有网络和外部模板。模块不创建最终快照，也不配置释放后备份保留或备份公网下载开关；释放前按业务需要另行保存备份，并在释放后核对服务保留的备份与费用。
- 升级已有调用时，旧 `volcenginecc_rdsmysql_endpoint.proxy["writer"]` 和 `volcenginecc_rdsmysql_endpoint.proxy["reader"]` 地址通过 `moved` 声明迁移，输出 key 保持 `writer`/`reader`。调用方移除旧的 `endpoint_domain_prefix`、`keep_policy_after_release` 和 `keep_days_after_release` 参数。
