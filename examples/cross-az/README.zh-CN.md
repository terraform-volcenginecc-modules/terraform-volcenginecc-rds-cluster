# 跨 AZ MultiNode 集群

使用调用方拥有的网络和服务默认端点，在不同 AZ 创建 RDS MySQL MultiNode 主节点与可读备节点。自动故障切换属于服务能力，本示例尚未验证切换或 AZ 故障恢复。

使用 Terraform 1.5.7 或 OpenTofu 1.11.8 和 Provider 0.0.73。预期 Registry source：`terraform-volcenginecc-modules/rds-cluster/volcenginecc`，发布/消费未验证。

准备 `deployment.tfvars`，包含 region、node_spec 和 network（vpc_id、subnet_id、security_group_ids、primary_zone_id、secondary_zone_id）。两个 AZ 必须不同，子网必须位于主节点 AZ。选择当前地域可用且兼容 LocalSSD 的规格。通过 VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY 提供 Provider 凭据，通过 TF_VAR_administrator_password 提供密码。

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

检查 topology 和私网 writer/reader 端点 map。端点 map 为空表示服务未回读该角色。默认端点的读写分离只被观察，不纳管其配置。可增加不同 Secondary 配置元组表达更大读容量，最多八个备节点和三个 AZ，并按建议预留用于故障切换的备节点。修改拓扑可能替换整个实例，不承诺在线扩容。

获授权清理时，先单独 apply 关闭删除保护，再 destroy，随后独立查询纳管资源确认不存在。释放后保留由服务控制，Last/7 是已观察到的默认值，不是模块保证。应核对实际保留和费用。调用方网络资源保持归属。

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

OpenTofu 使用 `tofu` 并隔离 State。可用性、刷新后无变更、路由及销毁尚未通过真实云验收。
