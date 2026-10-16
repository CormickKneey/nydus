# experiment/v3-macos Phase 5：文档、CI、回上游（骨架）

> 分支：`experiment/v3-macos`（private `CormickKneey/nydus`）  
> 状态：**纸面清单 + CI 占位**；**不对** `dragonflyoss/nydus` 自动开 PR  
> OAuth 当前缺 `workflow` scope → workflow 文件只放在 `docs/ci/`，不推 `.github/workflows/`

## 1. 目标

1. 最小操作手册（有盘实验室可跟做 Phase 1–3）。  
2. CI：Linux 上能跑的检查（build、scaffold scripts）；e2e 标 manual / self-hosted。  
3. 整理 **PR 系列** 合回上游 `v3`：格式无关优先，macOS 实验适配可留 experiment 或后置。

## 2. 文档交付物（清单）

| 文档 | 状态 |
|------|------|
| [`experiment-v3-macos.md`](experiment-v3-macos.md) 总计划 | 持续更新 |
| Phase 1–3 设计 | 已有 |
| Phase 4 增量骨架 | 已有（本系列） |
| 一页「实验室 Quickstart」 | **待写**（有第一台成功机后再写） |
| 合规 / 分发限制专节 | 总计划已有摘要；Quickstart 需重复强调 |

## 3. CI 占位

| 文件 | 用途 |
|------|------|
| [`docs/ci/macos-phase1.placeholder.yml`](ci/macos-phase1.placeholder.yml) | phase1-check |
| [`docs/ci/macos-phase3.placeholder.yml`](ci/macos-phase3.placeholder.yml) | phase3-bench / optimize-check（缺盘应失败或 skip） |
| [`docs/ci/macos-e2e.manual.placeholder.yml`](ci/macos-e2e.manual.placeholder.yml) | self-hosted + `disk.raw` 密钥/路径；`workflow_dispatch` only |

启用条件：token 具备 `workflow` scope 后，将占位内容移入 `.github/workflows/` 并删掉「禁止 push workflows」约束。

## 4. 回上游 PR 拆分建议

| 序号 | 主题 | 是否依赖 macOS 实验室 | 优先级 |
|------|------|----------------------|--------|
| P1 | 文档：模型 A 主机侧块文件按需（通用表述，可无 macOS 字样） | 低 | 高 |
| P2 | 脚手架脚本中可复用的 fuse+trace+optimize 实验协议 | 低 | 中 |
| P3 | 若有通用 bugfix（fuse 大文件、metrics） | 中 | 高 |
| P4 | `misc/macos/**` 整体 | 高（叙事绑定） | 低（可长期 private） |
| P5 | incremental + VM overlay 集成 | 高 | 待 Phase 4 |

**纪律：** 每个 PR 需 DCO；先对 private 分支自测；上游 PR 需维护者显式授权后再开（本实验默认不开）。

## 5. 上游 PR checklist（开 PR 前勾选）

- [ ] 变更可在无 IPSW 的 Linux CI 上编译  
- [ ] 不引入 Apple 系统镜像二进制  
- [ ] 文档区分「已证实 / 假设」  
- [ ] 与上游 `v3` tip rebase；冲突解决  
- [ ] `Signed-off-by` 齐全  
- [ ] 描述中写清非目标（非生产、非 Mac 上跑 Linux）  
- [ ] 实验室数据若引用，仅公开可公开的相对数字  

## 6. 本 private 仓收尾标准（「实验轨道纸面完成」）

- Phase 0–5 均有文档入口（本提交起满足纸面）。  
- 缺用户资产时脚本失败行为一致。  
- 真实秒数与上游 PR **仍显式挂起**，不在文档中假装完成。
