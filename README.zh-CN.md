# terraform-volcenginecc-rds-cluster

基于 VolcengineCC 创建私网 RDS MySQL 高可用部署的 Terraform 模块草案，覆盖 MultiNode 集群和带只读副本的 DoubleNode 主备架构。

## 1. 概述（Overview）

模块拥有一个 RDS MySQL 实例及其完整节点拓扑、一个数据库白名单、可选参数模板，以及可选的私网 writer/reader 代理端点。VPC、数据库子网和安全组由调用方拥有，Provider 认证与地域也由调用方配置。子网必须属于该 VPC 和主节点 AZ；所有节点必须处于同一地域，最多分布在三个 AZ。这些关系需要云端验证。

MultiNode 为一个 Primary 和 1–8 个可读 Secondary 副本。DoubleNode 为一个 Primary、一个 Secondary 备节点和 0–10 个 ReadOnly 副本。备节点规格必须与主节点一致。自动故障切换是云服务能力，本模块尚未完成切换测试。单 AZ 部署无法抵御 AZ 故障；对于 MultiNode，应按服务建议预留不承载业务的备节点用于故障切换。

AWS Aurora 的 cluster/replica/global 示例和阿里云 RDS 高可用仅作为场景参考。本模块使用常规 RDS MySQL，不具备 Aurora 共享存储语义或兼容 AWS 的 Global Database。PostgreSQL、跨地域 Global 复制、备份恢复和无中断在线副本扩容不属于当前草案范围。

## 2. 用法（Usage）

通过 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 配置认证，通过 `TF_VAR_administrator_password` 提供管理员密码，不提交密码。调用方变量提供既有资源 ID 和地域内可用的节点规格。

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

`terraform-volcenginecc-modules/rds-cluster/volcenginecc` 是预期 Registry 发布地址。尚未确认发布版本，Registry 消费仍未验证。静态验证仅在隔离的临时副本中改写 source。根 Provider、凭据、地域和 backend 由调用方控制。

## 3. 示例（Examples）

- basic：单 AZ MultiNode，一主一可读备节点，限制访问的安全组、默认备份策略和服务自动创建的端点。
- complete：跨 AZ DoubleNode 主备加一个 ReadOnly 副本，私网 writer 开启读写分离，reader 无主节点回退，包含运行期间十四天备份保留、标签和参数模板。
- cross-az：主备位于不同 AZ 的 MultiNode。可增加不同的 Secondary 配置元组表达更多副本，最多八个备节点和三个 AZ。
- readonly-scale-out：通过逻辑 key 的副本 map 表达 DoubleNode 目标读容量。这是创建/目标容量示例，当前 Provider 下修改拓扑可能替换整个实例。

所有示例依赖既有网络。创建自定义 Proxy 端点时，模块通过实例可写的 `cpu_num` 字段在创建阶段申请代理 CPU 核数。代理状态仍是 Computed，必须独立回查。端点不会静默降级为 Direct。安全组通过显式 `SecurityGroupBindInfos` 以 `IngressDirectionIp` 模式绑定。

## 4. 版本要求（Requirements）

| 要求 | 契约 |
|---|---|
| Terraform | 精确验证目标：`1.5.7` |
| OpenTofu | 精确验证目标：`1.11.8` |
| 共同引擎范围 | `>= 1.5.7, < 1.12.0`；未逐一验证范围内其他版本 |
| 最低 Provider | `0.0.60`；已按发布版本 Schema 核对使用的资源和字段 |
| 当前 Provider | `0.0.73`；示例固定此版本 |
| 前提 | RDS/Cloud Control 权限、足够余额与配额、地域可用规格、调用方拥有的网络 |

状态：`draft`。2026-11-05，两个示例使用 Terraform 1.5.7 与 Registry Provider 0.0.73，通过保留配置的真实云周期：apply、独立控制面回读、刷新后二次 plan 无变更、普通删除保护更新和首次标准 destroy。State 为空，独立 API 查询确认受管资源不存在。线上 Handler/Provider 未可靠支持备份公网下载控制、释放后保留策略和自定义域名前缀，因此模块不提供这三类配置。SQL 路由因私网不可达而受阻，故障切换和 Registry 消费仍未验证。

## 5. Providers（Providers）

| 名称 | 来源 | 版本 |
|---|---|---|
| `volcenginecc` | `volcengine/volcenginecc` | 根模块 `>= 0.0.60`；示例 `= 0.0.73` |

## 6. 资源（Resources）

| 名称 | 模式 | 职责 |
|---|---|---|
| `volcenginecc_rdsmysql_instance.this` | Resource | 实例及全部节点；[Provider 文档](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_instance) |
| `volcenginecc_rdsmysql_allow_list.this` | Resource | 限制客户端 CIDR 和安全组关联；[Provider 文档](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_allow_list) |
| `volcenginecc_rdsmysql_parameter_template.this` | 可选 Resource | 创建期绑定的参数模板；[Provider 文档](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_parameter_template) |
| `volcenginecc_rdsmysql_endpoint.writer`, `volcenginecc_rdsmysql_endpoint.reader` | 可选 Resource | DoubleNode 代理；先创建 writer，再创建 reader；先销毁 reader，再销毁 writer；[Provider 文档](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/rdsmysql_endpoint) |
| `data.volcenginecc_rdsmysql_endpoint.proxy` | Data Source | 自定义端点创建后查询真实私网域名/IP；[Provider 文档](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/data-sources/rdsmysql_endpoint) |

默认端点通过实例观察，由云服务随实例生命周期管理。不会创建独立 readonly-node 资源与 `instance.nodes` 争夺归属。

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 要求及含义 |
|---|---|---|---|
| `instance_name` | `string` | 必填 | 字母开头，最多 128 字符；创建自定义代理时最多 57 字符 |
| `vpc_id` | `string` | 必填 | 调用方拥有的 VPC |
| `subnet_id` | `string` | 必填 | 该 VPC 下主节点 AZ 中调用方拥有的数据库子网 |
| `security_group_ids` | `set(string)` | 必填 | 1–10 个调用方拥有且限制访问的安全组 |
| `allowed_cidrs` | `set(string)` | `null` | 额外 IPv4 访问，设置时非空，拒绝 /0 |
| `instance_type` | `string` | `"MultiNode"` | MultiNode 或 DoubleNode，修改会替换 |
| `nodes` | `map(object({node_spec=string,node_type=string,zone_id=string}))` | 必填 | 完整拓扑，角色 Primary/Secondary/ReadOnly，拒绝重复元组 |
| `require_multi_az` | `bool` | `false` | 要求每个 Secondary 与 Primary 的 AZ 不同 |
| `db_engine_version` | `string` | `"MySQL_8_0"` | MySQL_5_7 或 MySQL_8_0，固定 InnoDB 引擎 |
| `storage_space_gb` | `number` | `100` | 整数且至少 20，受规格限制，修改会替换 |
| `storage_type` | `string` | `"LocalSSD"` | LocalSSD、CloudESSD_FlexPL 或 CloudESSD_PL0 |
| `administrator_name` | `string` | `"clusteradmin"` | 创建期高权限账号名，修改会替换 |
| `administrator_password` | `string`，sensitive | 必填 | 8–32 个允许字符，至少三类字符；创建期参数，保存在 State |
| `port` | `number` | `3306` | 1000–65534 的整数，修改会替换 |
| `deletion_protection` | `bool` | `true` | 销毁前需单独 apply 关闭 |
| `backup_policy` | `object({retention_days=optional(number,7),weekdays=optional(set(string),all seven weekdays),start_utc_hour=optional(number,18),binlog_enabled=optional(bool,true)})` | `{}` | 运行期间的保留天数和计划；不配置释放后保留或公网下载开关 |
| `parameter_template` | `object({name=string,description=optional(string),parameters=map(string)})` | `null` | 模块拥有的模板，参数非空，版本与实例匹配 |
| `existing_parameter_template_id` | `string` | `null` | 调用方拥有的模板，与 parameter_template 互斥 |
| `create_proxy_endpoints` | `bool` | `false` | 仅带 ReadOnly 副本的 DoubleNode，在创建实例时申请代理 CPU 核数 |
| `proxy_cpu_num` | `number` | `2` | 代理 CPU 核数，2–1024 整数，还需满足主节点规格对应的 API 最小值 |
| `read_replica_max_delay_seconds` | `number` | `30` | writer 代理读路由的 1–3600 整数秒；ReadOnly reader 不传此参数，最终一致性 |
| `project_name` | `string` | `null` | 资源项目，修改实例项目会替换 |
| `tags` | `map(string)` | `null` | 设置时为非空 Key/Value map，无隐式标签 |

`nodes` key 是配置标签，不是 Terraform 资源地址。Provider 拥有 set：只改 key 而不改元组不会影响资源，重复角色/规格/AZ 元组会折叠，因此被拒绝。主备规格必须一致。计费固定为 PostPaid，Optional+Computed 计费字段保持未声明，不通过 ignore 隐藏差异。

## 8. 输出（Outputs）

| 名称 | 类型 | 含义 |
|---|---|---|
| `instance_id` | `string` | 模块拥有的实例 ID |
| `instance_status` | `string` | Provider 回读状态，云端读取前未知 |
| `writer_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | 自定义 key 为 writer，默认模式为端点 ID，仅私网地址，可能为空 |
| `reader_endpoints` | `map(object({id=string,read_write_mode=string,connection_mode=string,read_write_splitting=bool,private_addresses=list(object({domain=string,ip_address=string,port=string,subnet_id=string}))}))` | 自定义 key 为 reader，默认模式为端点 ID；未回读 ReadOnly 端点时为空 |
| `topology` | `object({nodes=map(object({node_spec=string,node_type=string,zone_id=string})),secondary_count=number,readonly_count=number,availability_zones=set(string),observed_node_count=string})` | 配置中的节点标签/数量，以及单独回读的数量 |
| `allow_list_id` | `string` | 模块拥有的白名单 ID |
| `parameter_template_id` | `string` 或 `null` | 模块或调用方拥有的模板，未配置时为 null |

不输出管理员密码。writer 代理向 Primary 发送写请求，也可分发读请求；显式只读流量应使用 reader。缺失 reader 信息时返回空 map，不虚构域名或复用 writer 地址。只读端点不保证写后立即读的一致性。

## 9. 其他说明（Notes）

发布版本 Schema 支持 MultiNode 与 DoubleNode，但 [CreateDBNodes API](https://www.volcengine.com/docs/6313/1359331) 对 MultiNode 增加 Secondary，对 DoubleNode 增加 ReadOnly。[CreateDBEndpoint API](https://www.volcengine.com/docs/6313/170670) 限制自定义创建仅适用于 DoubleNode。本模块只观察 MultiNode 默认端点的读写分离，不配置其策略。自定义端点要求服务默认端点权重中包含所有副本 ID，且数据库代理可用；回读不完整会被拒绝，不会猜测标识符。

Provider 创建期字段包括引擎/版本、实例类型、节点规格/角色/AZ、存储容量/类型、网络 ID、端口、项目、高权限凭据和参数绑定。修改规格或 AZ 可能替换整个实例。在线增删副本、密码轮换和拓扑迁移需要 Provider 改进及真实云验收，每次 Plan 都需检查替换。模块不使用 `ignore_changes`、SDK、local-exec 或远程脚本隐藏限制。

参数模板在创建期绑定，修改模板内容并不证明运行中的数据库参数已变化，需另行验证运行值。Optional+Computed 备份、标签、计费和端点字段需要刷新后的二次 Plan 验证无变更。可选输入为 null 表示未指定，不承诺清空云端值。只写凭据仍保存在 Terraform/OpenTofu State 中，应保护 State 和保存的 Plan JSON，处理凭据时禁用调试日志。

底层 Provider 支持 import：实例/白名单/模板使用各自资源 ID，自定义端点使用 `instance_id|endpoint_id`。Import 是有意识的 State 迁移，不是自动复用模式。导入后必须还原精确拓扑，并在 apply 前检查替换。

删除保护默认为 true。获授权清理时，先 apply `deletion_protection=false`，再 destroy。本模块不配置备份公网下载开关和释放后保留策略，这些设置由服务控制。最终删除查询返回 Last/7 保留策略，不是模块保证。保留备份可能继续计费，且不是模块拥有的资源。删除后查询活跃实例、端点、白名单、纳管模板和保留备份；网络仍由调用方拥有。不创建最终快照。

自定义代理域名由服务自动生成，通过端点 Data Source 返回。线上 Create/Read 未可靠支持域名前缀持久化，因此不提供自定义域名前缀和地址配置。代理操作通过模块依赖避免同一实例上的写操作重叠。complete 周期已通过首次标准销毁，reader 先于 writer 删除。moved 声明迁移旧 `endpoint.proxy["writer"]` 和 `endpoint.proxy["reader"]` 资源地址，输出 key 仍为 writer/reader。升级调用方时删除旧 `endpoint_domain_prefix`、`keep_policy_after_release` 和 `keep_days_after_release` 参数。

保留的 Terraform 配置已通过两套真实云周期。SQL 路由、故障切换及模块 Registry 发布与消费仍未验证。
