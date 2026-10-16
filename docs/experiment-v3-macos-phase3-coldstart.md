# experiment/v3-macos Phase 3：冷启动闭环与对比

> 分支：`experiment/v3-macos`  
> 前置：Phase 1 镜像流水线 · Phase 2 主机按需（模型 A）  
> 状态：**设计 + 脚手架**；**无 golden `disk.raw`、无真实 rund/QEMU 跑数，不宣称冷启动收益**

本文约定：在模型 A（`nydus fuse` 挂出含 `disk.raw` 的树 → virtio-blk 文件后端）下，如何拆指标、如何在 **Linux 主机**上采集可喂给 `nydus optimize` 的访问 trace、如何做「整盘拉取 vs nydus」对比实验。

---

## 0. 与 Phase 2 的衔接（不改）

1. 按需发生在主机：VMM 对挂载点下 `disk.raw` 的 `pread` / `mmap` → FUSE → `NydusCore` 拉 chunk。  
2. guest 内仍是 APFS；**不要**指望在 macOS guest 里直接跑 Linux 风格的 EROFS access tracer。  
3. Phase 3 的 optimize 输入 = **主机侧 chunk-group 访问序**（fuse apiserver `/trace` 或导出的 `trace.json`），不是 guest 内文件路径列表。

---

## 1. 指标拆分（必须分开报）

冷启动总时间若只报一个数字，会被「拉镜像 / 起 VM / agent 就绪」混在一起，无法对标 Linux→Linux OCI 叙事。实验默认拆三段（可再加细分）：

| 代号 | 名称 | 起点 | 终点 | 主要看什么 |
|------|------|------|------|------------|
| **T_pull** | 镜像拉取 | 开始 `skopeo`/`oras`/本地 copy，或清空 cache 后首次打开 bootstrap | bootstrap +（可选）元数据就绪；**不**要求 `disk.raw` 全量落盘 | registry RTT、blob 元数据大小、是否只拉 bootstrap |
| **T_runtime** | Runtime 启动 | `rund create` / QEMU 进程起 | guest 固件把手交给 OS（或 virtio-blk 完成首次可读） | VMM/OpenCore 开销；与 nydus 无关的固定成本 |
| **T_ready** | Agent 就绪 | OS 开始挂 APFS / launchd | 约定探针成功（SSH、agent HTTP、或自定义 ready 文件） | 按需 chunk 是否跟得上 boot 工作集 |

**派生指标（建议同时记）：**

| 代号 | 含义 |
|------|------|
| **T_cold** | `T_pull + T_runtime + T_ready`（冷 cache、无 ondemand prefetch） |
| **T_warm** | 清空 VM 但不清 `cache_dir` 后的 `T_runtime + T_ready` |
| **T_opt** | 使用 `nydus optimize` 产出的 bootstrap（含 ondemand blob）后的冷启动 |
| **Bytes_fetch** | 主机从后端实际下载的压缩字节（cache miss） |
| **Bytes_disk_touch** | 主机对 `disk.raw` 逻辑读取的字节（可由 blktrace / FUSE 统计近似） |
| **Cache_hit_ratio** | 解码缓存命中（Prometheus / nydus metrics，若已启用） |

**对比基线（同一 golden 盘、同一 VMM 参数）：**

| 行 | 配置 | 期望叙事 |
|----|------|----------|
| B0 | 整盘 `cp`/`oras` 拉满 `disk.raw` 到本地普通文件，再 virtio-blk | 传统「先下完再起」 |
| B1 | nydus fuse，未 optimize，冷 cache | 按需但无预热序 |
| B2 | nydus fuse + optimize ondemand，冷 cache | Phase 3 主卖点 |
| B3 | B2 + 热 cache | 多实例共享预热上限 |

---

## 2. 在 Linux 主机上采集 access trace（模型 A）

### 2.1 权威来源：fuse apiserver `/trace`

上游约定（见 [`docs/nydus.md` Optimize](nydus.md#optimize)）：

- 运行中的 `nydus fuse` 带 `--apiserver unix:///path/to/api.sock`。  
- `GET /trace` 返回 JSON：`{"version":1,"patterns":[{"blob_index":N,"chunk_group_index":M},...]}`，按 **首次访问** 去重保序。  
- 该序对应 **chunk group**，不是 APFS 文件名；对模型 A 足够：VMM 读 `disk.raw` 哪些区间，就会打到哪些 group。

**推荐采集流程：**

```text
1. 清空或换用空的 cache_dir（保证冷路径）
2. nydus fuse --bootstrap … --config … --mountpoint … --apiserver unix:///run/nydus/macos-a.sock
3. rund/QEMU 启动，跑到 agent-ready（或固定 boot 脚本）
4. 保持 mount 不卸：nydus optimize --apiserver unix:///run/nydus/macos-a.sock …
   或先 curl/自备工具把 /trace 存成 trace.json，再 --trace-file
5. 用新 bootstrap + ondemand blob 重复步骤 1–3 测 T_opt
```

### 2.2 离线 `trace.json`

当实验室不能长时间挂着 fuse、或要把 trace 交给另一台构建机：

```bash
# 示意：从 apiserver 导出（具体 HTTP 客户端以实验室工具为准）
# GET /trace → misc/macos/artifacts/traces/boot-agent-ready.json
nydus optimize \
  --trace-file /var/lib/nydus-macos/traces/boot-agent-ready.json \
  --parent-bootstrap /var/lib/nydus-macos/artifacts/macos-disk.boot \
  --bootstrap /var/lib/nydus-macos/artifacts/macos-disk.opt.boot \
  --blob-dir /var/lib/nydus-macos/artifacts \
  --config /etc/nydus/macos-storage.yaml
```

样例命令行模板见 [`misc/macos/phase3/optimize-examples.sh`](../misc/macos/phase3/optimize-examples.sh)。

### 2.3 辅助观测（不能替代 /trace）

| 手段 | 用途 | 局限 |
|------|------|------|
| `bpftrace` / `perf` 盯 QEMU 对 `disk.raw` 的 `pread` | 理解 boot 热区偏移 | **不能**直接生成 optimize 所需的 chunk-group JSON |
| guest 内 `fs_usage` / 自研 agent | 理解「哪些文件」被碰 | 与 nydus chunk 索引不对齐；仅作叙事补充 |
| Prometheus nydus metrics | Bytes_fetch、延迟 | 需确认 fuse 构建已暴露 metrics |

**结论：** Phase 3 正式 optimize 输入必须以 **主机 nydus access trace** 为准；guest 内 trace 只作对照说明。

### 2.4 工作负载定义（写入实验记录）

每次出数必须固定：

1. **探针**：例如 `ssh` 成功、或 agent `/readyz` 200。  
2. **是否登录桌面**：agent 沙箱建议 **不要** 等完整 GUI。  
3. **预装软件集合**：golden 盘内容 hash / 版本标签。  
4. **网络**：本机 blob vs registry；记录 RTT 档位（0 / 50ms 等，若用 tc）。

---

## 3. `nydus optimize` 如何嵌入本实验

### 3.1 产物

- 新 bootstrap（inode/chunk 索引指向源 blob 不变）。  
- 额外 **ondemand（redirect）blob**：按首次访问序拷贝 chunk group；挂载时 phase-0 prefetch **顺序拉一遍**，解码写入 **源 blob 的 cache**。  
- 运行时文件系统路径仍读源数据；ondemand blob **不**作为第二次 optimize 的源。

### 3.2 与模型 A 的匹配度

| 点 | 评估 |
|----|------|
| fuse 读大文件 `disk.raw` | 高：boot 扫描会形成稳定的 group 序 |
| 多实例共享 cache | 高：与 Phase 2 `cache_dir` 共享一致 |
| APFS 随机小读 | 中：optimize 后仍可能有长尾；需靠 `fetch_size` 与重复实验 |
| 可写 overlay / snapshot | 低耦合：optimize 只管只读基盘；可写层见 Phase 4 |

### 3.3 迭代建议

1. 先采「到 agent-ready」最短路径 trace（避免把无关软件更新打进 ondemand）。  
2. 若 T_ready 仍差：加一轮「agent 典型任务」trace，合并策略需人工审（上游 optimize 以单次 patterns 为主；多 workload 合并属后续课题）。  
3. 不要把整盘顺序读一遍当 trace——那会退化成「几乎全量 prefetch」，失去按需叙事。

---

## 4. 对比矩阵（实验记录模板）

填写版见 [`misc/macos/phase3/results.example.md`](../misc/macos/phase3/results.example.md)。摘要列：

| 场景 | T_pull | T_runtime | T_ready | T_total | Bytes_fetch | 备注 |
|------|--------|-----------|---------|---------|-------------|------|
| B0 整盘本地 | | | | | ≈ disk.raw 全量 | |
| B1 nydus 冷 | | | | | | 未 optimize |
| B2 nydus+opt 冷 | | | | | | 主对比 |
| B3 nydus+opt 热 | —/小 | | | | ≈0 | |

**通过标准（建议，待实验室校准）：**

- B2 的 `T_pull` 明显小于 B0（只拉元数据 + ondemand 热集，而非全盘）。  
- B2 的 `T_ready` ≤ B0 的 `T_ready`（允许小幅抖动）；理想情况总 `T_cold` 优于 B0。  
- B3 相对 B2 有稳定下降，证明 cache 共享。  
- 正确性：guest 能到同一 ready 探针；无文件系统损坏（只读基盘 + overlay 策略下）。

---

## 5. 实验协议（可复现 checklist）

1. **资产**：用户自备 golden `disk.raw`（或 qcow2→raw）；本仓永不提交。  
2. **构建**：`make macos-phase1-build` → blob + bootstrap。  
3. **挂载**：按 Phase 2 `misc/macos/phase2/` 起 fuse + apiserver。  
4. **基线 B0**：同一 raw 放到普通文件系统，测三段时间。  
5. **B1**：nydus 冷 cache，无 optimize，测三段 + Bytes_fetch。  
6. **采 trace**：跑到 ready → 导出 `/trace`。  
7. **optimize**：写出 `*.opt.boot` + ondemand blob。  
8. **B2/B3**：换新 bootstrap，冷/热各 ≥3 次取中位数。  
9. **记录**：填 `results.example.md`，附 nydus 版本、内核、VMM cmdline、盘 hash。  
10. **脚本**：`make macos-phase3-bench` 在缺盘/缺 blob 时 **必须非零退出**（见 `phase3-bench.sh`）。

---

## 6. 缺盘 / 无实验室时的 caveats

| 情况 | 文档与脚本行为 | 禁止声称 |
|------|----------------|----------|
| 无 `disk.raw` | `phase3-bench.sh` / `phase3-optimize-check.sh` exit 1，打印路径说明 | 任何秒数、加速比 |
| 有盘无 KVM/rund | 可做「主机 `dd`/`fio` 读 fuse 上 disk.raw」近似热区，**不能**等价 T_ready | agent 冷启动收益 |
| 无 registry | T_pull 用本地 copy 模拟；对外叙事需标明 | 「跨洋拉取」类结论 |
| OAuth 无 `workflow` | CI 草稿留在 `docs/ci/`，不进 `.github/workflows` | 「CI 已绿」 |
| 合规 | 不托管 IPSW/系统盘；实验仅限合法授权环境 | 公开分发 macOS 盘 |

脚手架路径：[`misc/macos/phase3/`](../misc/macos/phase3/)。

---

## 7. 正确性与已知风险（Phase 3 范围）

- **崩溃恢复**：测 B2 中途杀 QEMU 再起；cache 与 blob 只读一致性。  
- **缓存失效**：手动删 cache 文件后应回退到冷路径且仍能 ready。  
- **权限**：fuse 允许 VMM 用户读 `disk.raw`；勿世界可写。  
- **只读基盘**：实验默认 `readonly=on` + 第二块数据盘或 qcow2 overlay（Phase 2 接线笔记）；避免直接写 FUSE 上的 raw。

---

## 8. 本阶段交付物 vs 仍阻塞项

**已交付（纸面 + 脚手架）：**

- 本设计文档  
- `misc/macos/phase3/`：bench / optimize-check 脚本（缺资产拒绝执行）、结果模板、optimize 样例  
- 总计划 Phase 3 状态更新  

**仍阻塞（需用户资产）：**

- golden APFS `disk.raw`  
- rund 或 QEMU+OpenCore 可启动接线  
- 可复现 Linux 实验机（KVM）  

拿到以上三项后，按 §5 协议跑出第一张填实的 `results` 表，即 Phase 3 实验室闭环。
