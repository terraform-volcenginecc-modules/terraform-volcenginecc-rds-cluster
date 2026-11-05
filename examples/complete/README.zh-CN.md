# Complete 跨可用区部署

创建跨 AZ DoubleNode RDS MySQL 主备，包含一个 ReadOnly 副本、私网 writer 读写分离和 reader 代理、参数模板、限制数据库访问、标签和运行期间十四天备份保留。

使用 DoubleNode 是因为 API 将独立 ReadOnly 节点和自定义端点创建限制在该架构。MultiNode 使用可读 Secondary 副本和服务默认端点。示例在创建实例时申请两个代理 CPU 核，先创建 writer 再创建 reader，销毁顺序相反。地址由服务生成。线上 Handler/Provider 未可靠支持域名前缀、公网下载控制和释放保留配置，因此模块不提供这些设置。

使用 Terraform 1.5.7 或 OpenTofu 1.11.8 和 Provider 0.0.73。`terraform-volcenginecc-modules/rds-cluster/volcenginecc` 是预期 Registry 地址，发布/消费未验证。

准备 `deployment.tfvars`，包含 region、node_spec 和 network（vpc_id、subnet_id、security_group_ids、primary_zone_id、secondary_zone_id、reader_zone_id）。主备 AZ 必须不同，reader 可与其中一个共享或使用第三个 AZ。子网必须位于主节点 AZ。可选设置 project_name 和 allowed_cidrs。通过 VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY 提供 Provider 凭据，通过 TF_VAR_administrator_password 提供密码。

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

writer 代理向 Primary 写入，并将读请求分发至副本。reader 只选择副本，没有 Primary 回退；副本延迟过高可能导致读失败。2026-11-05，Terraform 1.5.7 与 Registry Provider 0.0.73 通过 apply，独立核对跨 AZ 拓扑、代理成员、真实端点输出、运行参数和 14 天运行备份，并通过刷新后二次 plan 无变更。SQL 路由因私网不可达而受阻，复制行为与故障切换仍需验证。OpenTofu 使用 `tofu` 并隔离 State。

获授权清理时，先单独 apply 关闭删除保护，再 destroy。释放保留由服务控制，历史观察为 Last/7，但不是模块保证；保留备份可能继续计费。查询纳管资源和保留备份，网络仍由调用方拥有。

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

拓扑、密码、存储、引擎、网络或参数绑定变更可能替换实例。修改模板不保证参数即时传播。修改后的周期首次标准 destroy 通过，删除 5 个受管资源，无重试或补偿。State 为空，独立 API 查询确认实例、受管代理、白名单和模板不存在。模块仍为草案，SQL 路由受阻、故障切换未验证。
