# CROSS-AZ RDS MySQL Cluster 示例

## 1. 概述

本示例使用已有 VPC、主节点可用区的数据库子网和安全组，创建一个跨可用区 MultiNode RDS MySQL 实例，包含一个主节点和一个可读备节点，采用默认备份策略和服务端点。与 basic 相比，主备位于不同可用区；与 complete 相比，不创建独立 ReadOnly 副本、自定义代理或参数模板。高可用和自动故障切换由 RDS 服务提供。

## 2. 用法

在 `examples/cross-az` 目录执行。准备 `terraform.tfvars`，填写 `region`、`node_spec` 和完整 `network` 对象。主备可用区必须不同；子网属于所填 VPC 和主节点可用区。主备使用同一规格，该规格在两个可用区可用且兼容 LocalSSD。保留默认删除保护。

`providers.tf` 使用 `var.region` 配置 Provider。通过 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 提供部署凭据，通过 `TF_VAR_administrator_password` 提供管理员密码；凭据不写入源码或参数文件。

1. 初始化：

   ```shell
   terraform init
   ```

2. 查看首次计划，确认将创建实例和白名单，主备可用区不同：

   ```shell
   terraform plan
   ```

3. 确认计划后部署：

   ```shell
   terraform apply
   ```

4. 部署完成后再次查看计划，预期无变化：

   ```shell
   terraform plan
   ```

   使用 `terraform output` 查看实例 ID、主备拓扑和私网端点。应用需要能访问数据库私网地址的网络路径。

5. 需要销毁时，先核对删除范围，单独 apply 关闭删除保护，再销毁：

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   受管实例和白名单删除，已有 VPC、子网和安全组保留。

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
| `module.cluster` | 使用 `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` 创建跨可用区 MultiNode 实例和数据库白名单。 |

本 example root 不直接声明 Resource 或 Data Source，也不创建前置网络。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | 必填 `string`，已有网络和数据库所在地域，用于 Provider 配置。 |
| `network` | 必填对象，包含 `vpc_id`、`subnet_id`、`primary_zone_id`、`secondary_zone_id`（均为 `string`）和 `security_group_ids`（`set(string)`）；子网属于该 VPC 和主节点可用区，主备可用区必须不同，安全组为 1–10 个已有 ID。 |
| `node_spec` | 必填 `string`，以 `rds.mysql.` 开头，兼容 LocalSSD，且在两个可用区可用；主备使用相同规格。 |
| `administrator_password` | 必填敏感 `string`，通过 `TF_VAR_administrator_password` 提供；8–32 个允许字符，至少包含大写字母、小写字母、数字、特殊字符中的三类，修改会替换实例。 |
| `deletion_protection` | 可选 `bool`，默认 `true`；销毁前通过单独 apply 关闭。 |

默认配置为 MySQL 8.0、InnoDB、100 GiB LocalSSD、3306 端口、`clusteradmin` 管理员账号和按量付费。备份保留 7 天，每天 UTC 18:00 启动，开启 binlog 备份并同步保留策略。密码允许字母、数字及特殊字符 `!@#$%^&*()_+=,.&?|/-`。

## 7. 输出

| 名称 | 说明 |
|---|---|
| `instance_id` | 受管跨可用区 RDS MySQL 实例 ID。 |
| `writer_endpoints` | 服务返回的私网读写端点，以实际端点 ID 为 key，包含连接模式、分离开关和私网域名/IP/端口；端点或地址可能为空。 |
| `reader_endpoints` | 服务返回的私网只读端点；没有 ReadOnly 端点时为空 Map，不能当作连接地址。 |
| `topology` | 配置中的一主一可读备拓扑和服务返回的节点总数；`secondary_count = 1`、`readonly_count = 0`，主备位于不同可用区。 |

## 8. 示例

本目录即为 cross-az 示例，适合使用可读备节点的跨可用区 MultiNode 部署。需要独立 ReadOnly 副本、自定义 writer/reader 代理和参数模板时，可使用 complete 示例。

## 9. 说明

- 认证凭据通过 Provider 支持的运行环境传入，管理员密码通过 `TF_VAR_administrator_password` 传入。
- 安全组以 `IngressDirectionIp` 模式绑定白名单，会导入入方向 IP 规则；部署前将规则限制到实际客户端网段。
- 模块使用服务默认端点，不修改其分离策略。需要读写分离时，选择成员包含主节点和可读备节点的集群端点；只有主节点的端点不会分发读取。
- Apply 后再次执行 `terraform plan`，结果无变化才满足幂等要求。修改节点规格或可用区可能替换整个实例，执行前检查计划中的替换。
- Destroy 前先关闭删除保护。模块不创建最终快照；释放前保存业务所需备份，释放后核对服务保留的备份与费用。已有网络不随实例删除。
