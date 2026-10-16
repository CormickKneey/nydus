# experiment/v3-macos：目标与开发计划

> 分支：`experiment/v3-macos`  
> 基线：上游 [dragonflyoss/nydus](https://github.com/dragonflyoss/nydus) `v3` tip `bdff19e95f04a2dbddb6ec6721cfc87889525845`（3.0.0-beta.3）  
> 工作区：private `CormickKneey/nydus`（实验成熟后再对上游提 PR）

## 一句话目标

在 **Linux 主机**上，用 nydus v3 为 **macOS 容器/沙箱**（runtime：**rund 优先**，其次 runc）提供镜像 **冷启动加速** 与 **按需加载**。

**不是**在 macOS 上跑 Linux 容器（OrbStack / Lima 那条叙事不在本期范围）。

## 非目标（一期明确不做）

- 在 macOS 本机加速 Linux OCI / OrbStack / Lima
- 一次移植完整 UFFD / virtio-pmem / Kata 全栈进 macOS guest
- 承诺生产可用或与 `v3` 同步的稳定 CLI/API
- 现在就对 `dragonflyoss/nydus` 开 PR（private 迭代稳了再说）

## Runtime 优先级

1. **rund（默认）**：microVM / 块设备或 UFFD 路径，与现有 Linux agent 沙箱叙事最贴近  
2. **runc**：评估是否复用同一套主机侧后端；若仍依赖 VM 则并入 rund 路径，避免两套重复实现

## 与 Linux→Linux OCI 的关键差异（摘要）

| | Linux → Linux OCI | Linux → macOS 容器 |
|---|---|---|
| 隔离 | namespace / cgroup，常共享宿主机内核 | 必须虚拟化（KVM 等跑 macOS guest） |
| 镜像 | OCI 层 + snapshotter | 系统盘 / APFS 根盘 + runtime 配置 |
| nydus 接入 | snapshotter / FUSE / ublk / UFFD 成熟 | 接到 **块设备或 VMM 读路径**；guest 内仍是 APFS |
| 额外约束 | 较少 | 许可、IPSW/镜像分发、合规 |

## 成功标准

同一 macOS 容器镜像，在 Linux 上相对「整镜像 / 整盘拉取」有可复现对比：

- **首次冷启动**（拉镜像 / 起 runtime / 到可用状态，指标拆开）
- **重复启动 / 缓存命中**
- 一页最小操作文档与已知限制（含合规/分发）

## Phase 0–5 摘要

### Phase 0 — 基线与仓（当前）

- [x] private 仓 + `v3` / `experiment/v3-macos`
- [x] 本目标与计划文档
- [ ] 选定可复现 Linux 实验机与基准 macOS 容器镜像
- [ ] （可选）补齐 `workflow` scope，按上游 SHA 完整镜像含 `.github/workflows`

### Phase 1 — 镜像与构建面

- 摸清 macOS 容器根盘/层在 rund、runc 下如何挂载
- `nydus build` / nydusify：转换或「外层磁盘 + 内层按需」包装约定
- 打通：构建产物 → registry/本地 → 主机侧校验

### Phase 2 — 主机侧按需读（rund 优先）

- `NydusCore` / UFFD 或 ublk/nbd 喂给 microVM
- 本地缓存、多实例共享预热
- 冒烟：最小 macOS 环境到 shell / agent 就绪

### Phase 3 — 冷启动闭环与对比

- 访问 trace → `nydus optimize` → ondemand blob
- 拆开指标并对比整盘/整 OCI
- 修正确性洞（崩溃恢复、缓存失效、权限）

### Phase 4 — 快照与增量（可选）

- 接 v3 incremental writer：层变更 → 增量 blob
- 与 rund / VM snapshot 生命周期对齐

### Phase 5 — 文档、CI、回上游

- 最小操作手册 + 已知限制
- CI：Linux build + 可跑单测/集成；e2e 可标 manual
- 整理 PR 系列合回上游 `v3`（格式无关优先；平台适配可留 experiment）

## 工作区说明

个人账号无法把公开仓 **private fork**。本仓为独立 private 仓库：树内容对齐上游 `v3` tip，因 OAuth 缺少 `workflow` scope，推送时省略了 `.github/workflows/*`。需要完整历史与 workflow 时，用带 `workflow` 权限的 token 从上游重新 mirror。

## 参考链接

- 上游：https://github.com/dragonflyoss/nydus/tree/v3  
- 里程碑 v3.0.0：https://github.com/dragonflyoss/nydus/milestone/1  
