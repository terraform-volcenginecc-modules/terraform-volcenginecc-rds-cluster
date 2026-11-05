# Basic 单可用区集群

使用调用方拥有的网络、限制访问的安全组、敏感管理员密码和默认备份策略，创建单 AZ RDS MySQL MultiNode 主备集群。该部署不提供 AZ 故障保护。

使用 Terraform 1.5.7 或 OpenTofu 1.11.8，Provider 为 0.0.73。预期 source：`terraform-volcenginecc-modules/rds-cluster/volcenginecc`。Registry 发布/消费未验证，本地检查仅改写临时副本。

准备 `deployment.tfvars`，包含 region、node_spec 和 network（vpc_id、subnet_id、security_group_ids、primary_zone_id）。子网必须属于该 VPC 和主节点 AZ。获取当前可用且兼容 LocalSSD 的节点规格。通过 VOLCENGINE_ACCESS_KEY/VOLCENGINE_SECRET_KEY 提供 Provider 凭据，通过 TF_VAR_administrator_password 提供密码。

```sh
terraform init
terraform plan -var-file=deployment.tfvars
terraform apply -var-file=deployment.tfvars
terraform plan -var-file=deployment.tfvars -detailed-exitcode
terraform output -json
```

通过 writer_endpoints 读写；如果回读 reader_endpoints，可用于显式只读访问；空 map 不是连接地址。OpenTofu 使用 `tofu`，并隔离目录和 State。2026-11-05，保留配置使用 Terraform 1.5.7 与 Registry Provider 0.0.73 通过真实云周期：apply、独立控制面回读、刷新后二次 plan 无变更及首次标准 destroy。State 为空，独立 API 查询确认资源不存在。SQL 路由因私网不可达而受阻，故障切换未验证。

获授权清理时，先 apply 关闭删除保护，再 destroy。本模块不配置释放后保留和备份公网下载开关；Last/7 是已观察到的服务默认行为。核对真实保留备份和费用，并独立查询已删除的纳管资源确认不存在。网络资源仍由调用方拥有。

```sh
terraform apply -var-file=deployment.tfvars -var=deletion_protection=false
terraform destroy -var-file=deployment.tfvars -var=deletion_protection=false
```

拓扑、存储、引擎、凭据和网络变更可能替换实例，apply 前必须检查替换。
