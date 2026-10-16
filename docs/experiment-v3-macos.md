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

1. **rund（默认）**：microVM + 主机 nydus 挂出 `disk.raw` → virtio-blk 文件后端（模型 A）  
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

### Phase 0 — 基线与仓

- [x] private 仓 + `v3` / `experiment/v3-macos`
- [x] 本目标与计划文档
- [ ] 选定可复现 Linux 实验机与基准 macOS 容器镜像
- [ ] （可选）补齐 `workflow` scope，按上游 SHA 完整镜像含 `.github/workflows`

### Phase 1 — 镜像与构建面（文档与脚手架已落地）

- [x] 调研 runc vs rund 包形态与 nydus 主机侧接入点  
  → 详见 [`docs/experiment-v3-macos-phase1-image-pipeline.md`](experiment-v3-macos-phase1-image-pipeline.md)
- [x] 约定 rund 优先流水线（模型 A：EROFS 承载 `disk.raw` + virtio-blk 文件后端）
- [x] 脚手架：`misc/macos/`（config / examples / scripts），Makefile 占位目标
- [x] CI 草稿：`docs/ci/macos-phase1.placeholder.yml`（因缺 `workflow` scope，不进 `.github/workflows`）
- [ ] 真实 golden APFS 盘 + `nydus build` / `nydus check`（需实验室资产）
- [ ] registry/本地分发冒烟（依赖上一款）

### Phase 2 — 主机侧按需读（rund 优先）（设计 + 脚手架已落地）

- [x] 主机按需架构文档（模型 A：fuse/ublk → `disk.raw` → virtio-blk 文件后端）  
  → [`docs/experiment-v3-macos-phase2-host-ondemand.md`](experiment-v3-macos-phase2-host-ondemand.md)
- [x] 脚手架：`misc/macos/phase2/`（host-mount YAML、rund 接线笔记、`phase2-smoke.sh`）
- [x] 代码触点清单：[`docs/experiment-v3-macos-phase2-code-touches.md`](experiment-v3-macos-phase2-code-touches.md)
- [ ] 真实 `nydus fuse` 挂出 + rund/QEMU 冒烟到 shell/agent ready（需 golden 盘 + KVM 接线）
- [ ] 多实例共享 cache 实测

### Phase 3 — 冷启动闭环与对比（设计 + 脚手架已落地）

- [x] 指标拆分与实验协议文档  
  → [`docs/experiment-v3-macos-phase3-coldstart.md`](experiment-v3-macos-phase3-coldstart.md)
- [x] 脚手架：`misc/macos/phase3/`（bench / optimize-check / 样例命令 / 结果模板）
- [ ] 真实采 trace → `nydus optimize` → 填实对比表（需 golden 盘 + KVM + rund/QEMU）
- [ ] 正确性专项（崩溃恢复、缓存失效、权限）随实验室闭环一起做

### Phase 4 — 快照与增量（可选）（纸面骨架已落地）

- [x] 骨架文档：[`docs/experiment-v3-macos-phase4-incremental.md`](experiment-v3-macos-phase4-incremental.md)
- [ ] incremental writer + overlay/快照实验室集成（需 Phase 2/3 真机）

### Phase 5 — 文档、CI、回上游（纸面清单已落地）

- [x] 回上游清单与 CI 占位：[`docs/experiment-v3-macos-phase5-upstream.md`](experiment-v3-macos-phase5-upstream.md)
- [x] CI 草稿：`docs/ci/macos-phase3.placeholder.yml`、`macos-e2e.manual.placeholder.yml`（不进 `.github/workflows`）
- [ ] 实验室 Quickstart 一页纸（首台成功机之后）
- [ ] 对 `dragonflyoss/nydus` 开 PR（需显式授权；默认不开）


## Phase 1 状态（2026-10-16）

| 项 | 状态 |
|----|------|
| 镜像流水线调研文档 | 已写入 `docs/experiment-v3-macos-phase1-image-pipeline.md` |
| 包装脚手架 | `misc/macos/` |
| 真实 e2e / IPSW | **未做**（无基准盘与 KVM 实验机） |
| 上游 PR | 不做（按计划 private 迭代） |

**Phase 1 技术结论摘要：** nydus 留在 Linux 主机；guest 内保持 APFS；默认用「nydus 挂出含 `disk.raw` 的树 → VMM virtio-blk 文件后端」；不要默认走 guest EROFS/UFFD-pmem。

## Phase 2 状态（2026-10-16）

| 项 | 状态 |
|----|------|
| 主机按需架构文档 | 已写入 `docs/experiment-v3-macos-phase2-host-ondemand.md` |
| 代码触点清单 | `docs/experiment-v3-macos-phase2-code-touches.md` |
| phase2 脚手架 | `misc/macos/phase2/` |
| 真实 fuse 挂载 + rund 冒烟 | **未做**（阻塞：golden `disk.raw` + rund/VMM 接线） |
| 上游 PR | 不做 |

**Phase 2 技术结论摘要：** 一期默认 **`nydus fuse` + 文件后端 virtio-blk`**；ublk/nbd 仅作主机 EROFS 挂载备选；UFFD/pmem **不是** macOS 根盘默认。`phase2-smoke.sh` 在缺盘时必须非零退出。

## Phase 3 状态（2026-10-16）

| 项 | 状态 |
|----|------|
| 冷启动设计文档 | 已写入 `docs/experiment-v3-macos-phase3-coldstart.md` |
| phase3 脚手架 | `misc/macos/phase3/` |
| 填实对比数据 / optimize 实跑 | **未做**（阻塞：golden `disk.raw` + rund/VMM + 可启动链路） |
| 上游 PR | 不做 |

**Phase 3 技术结论摘要：** 指标必须拆开 **T_pull / T_runtime / T_ready**；optimize 输入来自 **主机 fuse `/trace`（chunk-group）**，不是 guest 内 APFS 路径；缺盘时 bench 脚本必须失败且不得编造秒数。

## Phase 4–5 状态（2026-10-16）

| 项 | 状态 |
|----|------|
| Phase 4 增量/快照骨架 | `docs/experiment-v3-macos-phase4-incremental.md` |
| Phase 5 上游/CI 清单 | `docs/experiment-v3-macos-phase5-upstream.md` |
| 真机增量 / 上游 PR | **未做** |

**纸面轨道：** Phase 0–5 文档入口已齐；实验室与上游合入仍显式挂起。

## 工作区说明

个人账号无法把公开仓 **private fork**。本仓为独立 private 仓库：树内容对齐上游 `v3` tip，因 OAuth 缺少 `workflow` scope，推送时省略了 `.github/workflows/*`。需要完整历史与 workflow 时，用带 `workflow` 权限的 token 从上游重新 mirror。

## 参考链接

- 上游：https://github.com/dragonflyoss/nydus/tree/v3  
- 里程碑 v3.0.0：https://github.com/dragonflyoss/nydus/milestone/1  
- Phase 1 镜像流水线：[`docs/experiment-v3-macos-phase1-image-pipeline.md`](experiment-v3-macos-phase1-image-pipeline.md)  
- Phase 2 主机按需：[`docs/experiment-v3-macos-phase2-host-ondemand.md`](experiment-v3-macos-phase2-host-ondemand.md)  
- Phase 2 代码触点：[`docs/experiment-v3-macos-phase2-code-touches.md`](experiment-v3-macos-phase2-code-touches.md)  
- Phase 3 冷启动：[`docs/experiment-v3-macos-phase3-coldstart.md`](experiment-v3-macos-phase3-coldstart.md)  
- Phase 4 增量骨架：[`docs/experiment-v3-macos-phase4-incremental.md`](experiment-v3-macos-phase4-incremental.md)  
- Phase 5 上游清单：[`docs/experiment-v3-macos-phase5-upstream.md`](experiment-v3-macos-phase5-upstream.md)  
- 包装脚手架：[`misc/macos/`](../misc/macos/) · Phase 2：[`misc/macos/phase2/`](../misc/macos/phase2/) · Phase 3：[`misc/macos/phase3/`](../misc/macos/phase3/)  
