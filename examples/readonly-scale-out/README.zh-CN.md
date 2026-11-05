# 目标只读副本容量

通过调用方提供的只读副本 map 和私网 writer/reader 代理端点，表达 DoubleNode RDS MySQL 主备目标配置。本示例表达创建时目标容量，不提供已验收的原地扩容流程。

使用 Terraform 1.5.7 或 OpenTofu 1.11.8 和 Provider 0.0.73。预期 source：`terraform-volcenginecc-modules/rds-cluster/volcenginecc`。Registry 发布/消费和真实云副本扩容均未验证。

准备 `deployment.tfvars`，包含 region、node_spec、network（vpc_id、subnet_id、security_group_ids、primary_zone_id、secondary_zone_id）和 read_replicas（包含 node_spec、zone_id 的 map）。设置 1–10 个只读副本，全部节点最多分布三个 AZ，角色/规格/AZ 元组必须不同，主备 AZ 必须不同。子网位于主节点 AZ。副本规格建议不低于主节点，以避免延迟/OOM。通过 VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY 提供凭据，通过 TF_VAR_administrator_password 提供密码。

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

检查 topology.readonly_count 和 writer/reader 私网地址。代理要求服务启用数据库代理能力，并在默认端点权重中回读所有副本 ID。reader 没有 Primary 回退。应另行验证真实路由、延迟和无变更回读。

仅修改 map key 不会改变 Provider set。节点属性属于创建期字段，增加、删除、迁移或调整副本规格可能替换实例。只有接受替换后才能 apply 扩容 Plan。独立 readonly-node 资源会与实例完整节点归属冲突，因此不使用。

获授权清理时，先单独关闭删除保护，再 destroy。释放保留由服务控制，Last/7 只是观察到的默认值，不是模块保证。查询备份、费用和纳管资源是否不存在。输出服务自动生成的端点域名，不提供自定义前缀和备份公网下载控制。网络仍由调用方拥有。

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

OpenTofu 使用 `tofu` 并隔离 State。在线扩容、故障切换、刷新后无变更及备份清理仍未验证。
