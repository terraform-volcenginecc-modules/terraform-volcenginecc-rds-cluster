# READONLY-SCALE-OUT RDS MySQL Cluster 示例

## 1. 概述

本示例使用已有网络和调用方提供的只读副本 Map，创建跨可用区 DoubleNode RDS MySQL 主备实例、1–10 个 ReadOnly 副本及 writer/reader 私网代理。与 complete 相比，可分别配置各只读副本的规格和可用区，不创建参数模板。此示例表达目标只读容量；修改节点属性可能替换整个实例，不能作为无中断原地扩容流程。

## 2. 用法

在 `examples/readonly-scale-out` 目录执行。准备 `terraform.tfvars`，填写 `region`、`node_spec`、完整 `network` 对象和 `read_replicas`。主备可用区不同，子网属于所填 VPC 和主节点可用区；全部节点最多分布在三个可用区。只读副本为 1–10 个，各自规格、角色和可用区组合不能重复。

`providers.tf` 使用 `var.region` 配置 Provider。通过 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 提供部署凭据，通过 `TF_VAR_administrator_password` 提供管理员密码；凭据不写入源码或参数文件。选择可用且兼容 LocalSSD 的规格，并保留默认删除保护。

1. 初始化：

   ```shell
   terraform init
   ```

2. 查看首次计划，确认副本数量、规格、可用区，以及实例、白名单和两个代理的创建：

   ```shell
   terraform plan
   ```

3. 确认计划后部署，writer 先于 reader 创建：

   ```shell
   terraform apply
   ```

4. 部署完成后再次查看计划，预期无变化：

   ```shell
   terraform plan
   ```

   使用 `terraform output` 检查 `topology.readonly_count` 和 writer/reader 私网地址。应用通过可访问数据库私网的网络路径连接，写请求使用 writer，显式只读请求使用 reader。

5. 需要销毁时，先核对删除范围，单独 apply 关闭删除保护，再销毁：

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   reader 先于 writer 删除，随后删除受管实例和白名单；已有网络保留。

## 3. 依赖要求

| 名称 | 版本 |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | `= 0.0.73` |

## 4. Providers

| 名称 | 来源 |
|---|---|
| `volcenginecc` | `volcengine/volcenginecc` |

Provider 在本目录的 `providers.tf` 中配置，无 alias，并由 Module 继承。

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.cluster` | 使用 `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` 创建跨可用区 DoubleNode 实例、完整副本拓扑、数据库白名单和 writer/reader 代理。 |

本 example root 不直接声明 Resource 或 Data Source，也不创建前置网络。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | 必填 `string`，已有网络和数据库所在地域，用于 Provider 配置。 |
| `network` | 必填对象，包含 `vpc_id`、`subnet_id`、`primary_zone_id`、`secondary_zone_id`（均为 `string`）和 `security_group_ids`（`set(string)`）；子网属于该 VPC 和主节点可用区，主备可用区必须不同，安全组为 1–10 个已有 ID。 |
| `node_spec` | 必填 `string`，主备使用同一可用且兼容 LocalSSD 的规格，以 `rds.mysql.` 开头。代理默认申请 2 个 CPU 核，规格应满足 `max(2, 主节点 CPU 核数 × 0.125)` 的 API 下限。 |
| `read_replicas` | 必填 `map(object({node_spec=string,zone_id=string}))`，包含 1–10 个只读副本，每项的规格和可用区均必填；规格以 `rds.mysql.` 开头，可用区非空，重复规格/角色/可用区组合会被拒绝，全部节点最多使用三个可用区。 |
| `administrator_password` | 必填敏感 `string`，通过 `TF_VAR_administrator_password` 提供；8–32 个允许字符，至少包含大写字母、小写字母、数字、特殊字符中的三类，修改会替换实例。 |
| `deletion_protection` | 可选 `bool`，默认 `true`；销毁前通过单独 apply 关闭。 |

默认配置为 MySQL 8.0、InnoDB、100 GiB LocalSSD、3306 端口、`clusteradmin` 管理员账号和按量付费。备份保留 7 天，每天 UTC 18:00 启动，开启 binlog 备份并同步保留策略；writer 最大复制延迟为 30 秒。密码允许字母、数字及特殊字符 `!@#$%^&*()_+=,.&?|/-`。

`read_replicas` 的 key 是配置标签，模块生成 `reader-` 前缀的节点标签。只修改 key 不改变 Provider 的节点集合；增加、删除、迁移或调整副本规格时，检查 Plan 是否替换实例。

## 7. 输出

| 名称 | 说明 |
|---|---|
| `instance_id` | 受管 DoubleNode RDS MySQL 实例 ID。 |
| `writer_endpoints` | key 为 `writer` 的私网读写代理，包含端点 ID、分离开关和私网域名/IP/端口；地址列表可能为空。 |
| `reader_endpoints` | key 为 `reader` 的私网只读代理，仅连接 ReadOnly 副本，不回退主节点；地址列表可能为空。 |
| `topology` | 配置的主备和只读副本、可用区集合及服务返回的节点总数；`secondary_count = 1`，`readonly_count` 等于 `read_replicas` 的项数。 |

## 8. 示例

本目录即为 readonly-scale-out 示例，适合按副本 Map 配置目标只读容量。需要固定一个只读副本并配置参数模板时，可使用 complete 示例；此处的拓扑修改不保证原地在线扩容。

## 9. 说明

- 认证凭据通过 Provider 支持的运行环境传入，管理员密码通过 `TF_VAR_administrator_password` 传入。
- 安全组以 `IngressDirectionIp` 模式绑定白名单，会导入入方向 IP 规则；部署前将规则限制到实际客户端网段。
- 自定义代理要求实例提供全部 ReadOnly 节点 ID。writer 向主节点写入并将读取分发到 ReadOnly 副本；reader 只连接副本，不回退主节点，副本读取不保证写后立即可见。
- 完整节点拓扑由实例统一管理。新增副本不会自动加入自定义端点；变更副本配置前，检查整个实例的替换范围和业务中断影响。
- Apply 后再次执行 `terraform plan`，结果无变化才满足幂等要求。
- Destroy 前先关闭删除保护。模块不创建最终快照；释放前保存业务所需备份，释放后核对服务保留的备份与费用。已有 VPC、子网和安全组保留。
