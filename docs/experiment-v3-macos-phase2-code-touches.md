# experiment/v3-macos Phase 2：建议代码触点（TODO 清单）

> **不是**未完成大补丁；只列出若推进模型 A / 后续模型 B 时，上游 nydus 里最可能动到的文件。  
> macOS guest / rund 接线多半在 **仓外**；此处只覆盖本仓库。

## P0 — 已由脚手架覆盖（无需改 Rust）

| 路径 | 作用 |
|------|------|
| `docs/experiment-v3-macos-phase2-host-ondemand.md` | 主机按需架构 |
| `misc/macos/phase2/*` | 挂载 YAML、rund 笔记、smoke |
| `misc/macos/config/storage.local.example.yaml` | fuse `--config` 示例 |

一期模型 A 用现有 CLI 即可：`nydus build` / `nydus fuse` / `nydus check`。

## P1 — 集成期可能的小改（仍属 nydus）

| 文件 / 区域 | 可能工作 | 备注 |
|-------------|----------|------|
| `nydus/src/fuse/service.rs` / `fs.rs` | 大文件顺序/随机 `read` 路径的指标与日志，方便对照 VMM pread | 观察后再改；勿先「优化」 |
| `nydus/src/fuse/mount.rs` | 挂载选项（allow_other、超时）是否满足 rund 非 root 读 | 视实验室权限模型 |
| `nydus-config` 配置 schema / 示例 | 固化 `cache_dir`、`fetch_size`、prefetch 与 macos 实验一致 | 示例 YAML 优先于改代码 |
| `nydus-storage` prefetch / access_trace | Phase 3：从「主机读 disk.raw」侧导出可喂 `nydus optimize` 的 trace | 跨边界采 guest 内 APFS 更难，可先用主机 VMM 读模式近似 |

## P2 — 模型 B（raw 块前端，非默认）

仅当模型 A 证明 VMM「经文件系统读大 raw」成为瓶颈时再开：

| 文件 / 区域 | 可能工作 |
|-------------|----------|
| `nydus-core/src/lib.rs`（`NydusCore`） | 在现有 `fetch_flat_ranges` / `Blobs::fetch` 之上，定义「逻辑盘 LBA → 某文件 extent」映射（构建期写入元数据或旁路 map） |
| `nydus-core/src/flat.rs` / `layout.rs` | flattened 布局今天面向 EROFS bootstrap@0；raw-disk 前端可能要旁路或新 layout |
| `nydus/src/ublk/` 或新 `nydus/src/...` | 向 VMM 提供 **纯数据** virtio-blk 后端（不是给内核 mount erofs 的 flattened 设备） |
| `nydus/src/uffd/` | **不**作为 macOS 根盘默认；仅 Linux guest EROFS-pmem |

## 明确暂不改动

| 路径 | 原因 |
|------|------|
| `nydus/src/uffd/*` 作为 macOS 根方案 | Phase 1：guest 无法 EROFS 作根 |
| Guest 内驱动 / APFS | 不在 nydus 仓范围 |
| `.github/workflows/*` | 本 private 仓缺 `workflow` OAuth scope；CI 草稿仍放 `docs/ci/` |

## rund / VMM（仓外 TODO）

- 将 `misc/macos/phase2/host-mount.example.yaml` 的 `disk_path` 映射到真实 rund/Kata/QEMU 配置字段。  
- 启动顺序：fuse ready → VM create；停止顺序相反。  
- 可写：qcow2 overlay 或第二块盘；系统盘 file 只读。

有 golden 盘与 rund 接线后，再把本清单里勾选的 P1 项落成具体 PR（仍先 private）。
