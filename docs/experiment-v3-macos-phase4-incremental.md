# experiment/v3-macos Phase 4：快照与增量（骨架）

> 分支：`experiment/v3-macos`  
> 前置：Phase 2 模型 A 可挂载；Phase 3 有可复现冷启动基线（实验室）  
> 状态：**纸面骨架 only** — 无实现、无 e2e；依赖 v3 incremental writer 与实验室 VM snapshot 流程

## 1. 目标

在只读 nydus 基盘（`disk.raw` via fuse → virtio-blk）之上，让 macOS 容器的 **可写变更** 以增量形式沉淀，避免每次整盘 commit：

1. 对接上游 v3 **incremental writer**（层变更 → 增量 blob）。  
2. 与 **rund / QEMU VM snapshot**（或 qcow2 overlay）生命周期对齐。  
3. 保持 guest 内 APFS 语义；增量仍在 **Linux 主机**侧打包。

## 2. 推荐默认组合（假设，待验证）

| 层 | 机制 | 说明 |
|----|------|------|
| 只读基盘 | nydus 模型 A（可已 optimize） | 永不就地写 FUSE 上的 raw |
| 运行时可写 | qcow2 overlay **或** 第二块 virtio 数据盘 | overlay 文件在普通主机 FS |
| 持久化增量 | 停机后：overlay → raw diff / 文件树 diff → `nydus` 增量写出 | 具体子命令以当时上游 CLI 为准 |
| 恢复 | 基盘 bootstrap + 增量 blob merge/chain → 新实例 | 与 Linux OCI 层链类似，但是「盘字节」语义 |

**不推荐一期：** 对 FUSE 导出的 `disk.raw` 直接读写并期望 cache/blob 自动一致。

## 3. 与 Phase 3 的关系

- optimize 针对 **只读热集**；增量针对 **可变状态**（agent 数据、配置、短暂系统变更）。  
- 新增量发布后，若 boot 路径变化大，应 **重采 trace** 再 optimize，勿假设旧 ondemand 仍最优。

## 4. 工作项清单（未开始）

- [ ] 盘点上游 incremental writer 对「单文件巨大 raw」的适用性（chunk 边界、合并成本）  
- [ ] 定义 overlay → 增量的实验室脚本（停机、qemu-img、校验）  
- [ ] 多代增量链式启动冒烟  
- [ ] 失败模式：增量损坏、基盘 digest 不匹配、部分 apply  
- [ ] 文档：与合规（不把含许可系统的增量公开分发）

## 5. 成功标准（草案）

- 相对「每次导出整盘 raw」，增量体积与生成时间有可复现优势。  
- 从「基盘 + 增量链」冷启到同一 ready 探针。  
- 不破坏 Phase 3 的 B2/B3 对比方法论（指标仍拆分）。

## 6. 非目标

- 实时 block-level CDC 去重集群  
- 在 macOS guest 内安装 nydus  
- 本阶段对上游提 PR（见 Phase 5）
