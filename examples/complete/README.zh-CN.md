# COMPLETE RDS MySQL Cluster 示例

## 1. 概述

本示例使用已有网络创建一个跨可用区 DoubleNode RDS MySQL 实例，包含一个主节点、一个备节点和一个 ReadOnly 副本，并创建 writer/reader 私网代理、参数模板、标签和 14 天备份策略。与 basic 相比，本示例增加跨可用区主备、独立只读副本和显式读写分离；调用方提供 VPC、主节点子网、安全组及主备和只读节点的可用区。

## 2. 用法

在 `examples/complete` 目录执行。准备 `terraform.tfvars`，填写 `region`、`node_spec` 和完整 `network` 对象，可选填写 `project_name` 和 `allowed_cidrs`。主备可用区不同，reader 可以与其中一个共享或使用第三个可用区；子网属于所填 VPC 和主节点可用区。三个节点使用同一可用且兼容 LocalSSD 的规格。

`providers.tf` 使用 `var.region` 配置 Provider。通过运行环境中的 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 提供部署凭据，通过 `TF_VAR_administrator_password` 提供管理员密码；凭据不写入 `terraform.tfvars`。保留默认删除保护，并确认节点、存储和代理配额满足配置。

1. 初始化，安装声明的 Module 和 Provider：

   ```shell
   terraform init
   ```

2. 首次查看计划，确认将创建实例、白名单、参数模板和两个自定义代理：

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

   使用 `terraform output` 获取 `writer_endpoints["writer"]` 和 `reader_endpoints["reader"]` 的私网连接地址。应用通过可访问数据库私网的网络路径连接，写请求使用 writer，显式只读请求使用 reader。

5. 需要销毁时，先核对资源范围并单独关闭删除保护，再销毁；两次操作都传入相同值：

   ```shell
   terraform apply -var='deletion_protection=false'
   terraform destroy -var='deletion_protection=false'
   ```

   reader 先于 writer 删除，随后删除受管实例、白名单和参数模板；已有网络保留。

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
| `module.cluster` | 使用 `source = "terraform-volcenginecc-modules/rds-cluster/volcenginecc"` 创建跨可用区 DoubleNode 实例、白名单、参数模板和 writer/reader 代理。 |

本 example root 不直接声明 Resource 或 Data Source，也不创建前置网络资源。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | 必填 `string`，已有网络和数据库所在地域，用于 Provider 配置。 |
| `network` | 必填对象，包含 `vpc_id`、`subnet_id`、`primary_zone_id`、`secondary_zone_id`、`reader_zone_id`（均为 `string`）和 `security_group_ids`（`set(string)`）；子网属于该 VPC 和主节点可用区，安全组为 1–10 个已有 ID，主备可用区必须不同，reader 可共享或使用第三个可用区。 |
| `node_spec` | 必填 `string`，以 `rds.mysql.` 开头，在目标地域可用且兼容 LocalSSD；主、备、只读三个节点使用同一规格。示例申请 2 个代理 CPU 核，规格同时应满足 `max(2, 主节点 CPU 核数 × 0.125)` 的 API 下限。 |
| `administrator_password` | 必填敏感 `string`，通过 `TF_VAR_administrator_password` 提供；8–32 个允许字符，至少包含大写字母、小写字母、数字、特殊字符中的三类，修改会替换实例。 |
| `deletion_protection` | 可选 `bool`，默认 `true`；销毁前通过单独 apply 关闭。 |
| `project_name` | 可选 `string`，默认 `null`，指定受管资源项目；修改实例项目会替换实例。 |
| `allowed_cidrs` | 可选 `set(string)`，默认 `null`，仅使用安全组规则；设置时为非空 IPv4 CIDR 集合，前缀大于 0，用于补充客户端白名单。 |

示例固定 MySQL 8.0、InnoDB、100 GiB LocalSSD、3306 端口、按量付费，管理员账号默认为 `clusteradmin`。密码允许字母、数字及特殊字符 `!@#$%^&*()_+=,.&?|/-`。

备份保留 14 天，每天 UTC 18:00 启动，开启 binlog 备份并同步保留策略。参数模板设置 `max_connections = "200"` 和 `slow_query_log = "ON"`；实例标签为 `Environment = "example"`、`ManagedBy = "Terraform"`。writer 读路由的最大复制延迟配置为 30 秒。

## 7. 输出

| 名称 | 说明 |
|---|---|
| `instance_id` | 受管 RDS MySQL 实例 ID。 |
| `writer_endpoints` | key 为 `writer` 的私网读写代理，值包含端点 ID、读写分离开关和私网域名/IP/端口；地址列表可能为空。 |
| `reader_endpoints` | key 为 `reader` 的私网只读代理，只连接 ReadOnly 副本，不回退主节点；地址列表可能为空。 |
| `topology` | 配置的一主一备一只读拓扑及服务返回的节点总数；配置中 `secondary_count = 1`、`readonly_count = 1`，主备位于不同可用区。 |
| `parameter_template_id` | 本示例创建并在实例创建时绑定的参数模板 ID。 |
| `allow_list_id` | 本示例创建的数据库白名单 ID。 |

## 8. 示例

本目录即为 complete 示例，适合跨可用区主备、独立只读副本、显式读写分离和参数模板配置。只需要单可用区基础主备时，可使用 basic 示例。

## 9. 说明

- 认证凭据通过 Provider 支持的运行环境传入，管理员密码通过 `TF_VAR_administrator_password` 传入。
- 安全组以 `IngressDirectionIp` 模式绑定白名单，会导入入方向 IP 规则；`allowed_cidrs` 的 `/0` 校验不检查安全组已有规则，部署前核对实际客户端访问范围。
- 自定义代理要求实例提供全部 ReadOnly 节点 ID。writer 向主节点写入并将读取分发到 ReadOnly 副本；reader 只连接副本，不回退到主节点。副本读取不保证写后立即可见，应用按一致性要求选择端点。
- 参数模板在创建实例时绑定；修改模板后，核对数据库运行参数是否生效。新增节点不会自动加入自定义端点，拓扑修改可能替换整个实例。
- Apply 后再次执行 `terraform plan`，结果无变化才满足幂等要求。修改节点、引擎、存储、网络或参数绑定前，检查计划中的实例替换。
- Destroy 前先关闭删除保护；销毁删除受管代理、实例、白名单和模板，已有 VPC、子网和安全组保留。模块不创建最终快照，释放后备份由服务保留策略决定；释放前保存业务所需备份，并核对保留费用。
