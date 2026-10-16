# experiment/v3-macos Phase 1：镜像与构建面

> 分支：`experiment/v3-macos`  
> 场景：**Linux 主机**启动 **macOS 容器/沙箱**（不是 Mac 上跑 Linux）  
> Runtime：**rund 优先**，其次 runc  
> 状态：调研 + 约定 + 脚手架；**尚无真实 IPSW / 基准 macOS 盘，无端到端可跑通声明**

本文区分：

- **已证实**：有公开文档 / 上游代码可引用  
- **假设**：需基准镜像与实验室验证后再固化

---

## 1. macOS「容器镜像」在 runc / rund 下通常怎么打包

### 1.1 关键结论（已证实 + 假设）

公开「Linux 上跑 macOS」方案几乎都是 **外层 Linux 进程 + 内层 KVM 虚拟机**，guest 根盘是 **APFS**，不是 Linux rootfs：

| 层级 | 典型内容 | 谁消费 |
|------|----------|--------|
| 外层 Linux 包 | QEMU/VMM、OpenCore/OVMF、启动脚本、（可选）OCI `config.json` | runc / 普通 Docker |
| 内层系统盘 | raw / qcow2，guest 内格式化为 **APFS** | 虚拟机 virtio-blk / AHCI |
| Hypervisor 附件 | CPU 伪装、`isa-applesmc`、固件变量等 | VMM 启动参数 |

**已证实的公开参考：**

- **OCI runc bundle**：[OCI Runtime Spec — bundle](https://github.com/opencontainers/runtime-spec/blob/main/bundle.md) 要求 `config.json` + `root.path`（常为 `rootfs/`）；[runc](https://github.com/opencontainers/runc) 按该 bundle 起进程。这是 **Linux rootfs** 模型。  
- **dockur/macos**：Linux 容器内跑 QEMU/KVM；安装流程要求用 Disk Utility 把 VirtIO 盘 **Erase 为 APFS** 再装系统；磁盘默认约 64GB，可调 `DISK_SIZE`。镜像本身是「安装器 + 运行时」，系统盘常落在 volume（如 `/storage`），**不**把完整 macOS 根树当 OCI layer 分发。见 [dockur/macos](https://github.com/dockur/macos)。  
- **cocoon-macos / 同类**：golden **qcow2**（Sequoia/Tahoe）发布到 registry；`vm run` 做 CoW clone 后 QEMU 启动；固件为 OpenCore + OVMF。见 [cocoonstack/cocoon-macos](https://github.com/cocoonstack/cocoon-macos)（公开描述；本仓库不绑定其许可策略）。  
- **rund**：公开论文/幻灯将 RunD 描述为面向 serverless 的轻量安全容器 runtime，基于 Kata，rootfs 读写分离，并规划 nydus 等存储；Kata 4.x 默认内置 Dragonball VMM，另有 QEMU / Cloud Hypervisor / Firecracker。[USENIX ATC'22 RunD](https://www.usenix.org/system/files/atc22-li-zijun-rund.pdf)、[Kata architecture](https://kata-containers.github.io/kata-containers/design/architecture_4.0/architecture/)。  
- **nydus 上游对 rund 的定义**（本仓 README）：`rund` 为 Kata 风格 microVM runtime，镜像以 **EROFS over virtio-pmem** 挂载——这是 **Linux guest** 路径。

**假设（本实验默认）：**

1. 用户说的「runc 或 rund 起 macOS 容器」= **用同一套 OCI/配置入口**，真正执行 macOS 仍靠 **VMM + APFS 盘**；runc 更偏「外层 Linux wrapper」，rund 更偏「直接 microVM」。  
2. 冷启动大头在 **内层 APFS 系统盘**（数 GB～数十 GB），不是外层 Linux rootfs（通常几十～几百 MB）。  
3. 合规：在非 Apple 硬件上跑 macOS guest 受 Apple EULA 约束；实验文档只谈技术，**不**提供 IPSW/系统盘分发。

### 1.2 runc 路径下的包形态（已证实框架 + 假设细节）

```text
bundle/                          # OCI bundle（runc）
  config.json                    # root.path、linux namespaces、devices:/dev/kvm …
  rootfs/                        # Linux：qemu、脚本、OpenCore 等
guest-disk/                      # 常在 volume / 数据盘，不一定进 OCI layer
  macos.raw | macos.qcow2        # guest 内 APFS
  OVMF_VARS.fd / OpenCore.qcow2  # 可选每实例变量
```

- runc 只直接「看见」`rootfs` + `config.json`。  
- macOS 系统盘多半是 **bind mount / 块设备透传 / 数据卷**，否则 OCI 层会巨大且难按需。  
- **假设**：agent 场景会收敛成「小 OCI（runtime）+ 大 disk artifact（registry/本地）」。

### 1.3 rund 路径下的包形态（假设为主）

Linux→Linux 时，rund/Kata 把容器 rootfs 交给 guest（常为共享/挂载的 Linux fs 或 EROFS-pmem）。  
换 macOS guest 后：

```text
rund / VMM
  ├─ 固件与 bootloader（OpenCore / OVMF）     ← 小，可全量
  ├─ virtio-blk ←── 按需块/文件 ── nydus 主机侧
  │                 （内容语义 = raw APFS 盘字节）
  └─ （可选）agent 数据盘、snapshot
```

- **不会**在 macOS guest 内直接 `mount -t erofs`（macOS 无 Linux EROFS 驱动；根文件系统是 APFS）。  
- nydus 的价值在 **主机侧** 按需提供「看起来像磁盘」的字节流，经 virtio-blk（或文件后端）进 guest。

---

## 2. nydus v3 接在哪里：主机侧 vs guest 内 APFS

### 2.1 主机侧（已证实能力）

上游 v3（本仓文档）提供：

| 能力 | 用途 | 文档 |
|------|------|------|
| `nydus build` / `nydusify convert` | 目录或 OCI → nydus blob（EROFS + chunk group） | README、`docs/nydus.md` |
| `nydus check` / `merge` / `optimize` | 校验、多层合并、访问 trace → ondemand blob | 同上 |
| `nydus fuse` | 用户态挂载 | README |
| `nydus ublk` / `nydus nbd` | 只读块设备 → 内核 EROFS 挂载 | `docs/ublk.md`、`docs/nbd.md` |
| `nydus uffd` + `NydusCore` | microVM virtio-pmem / 可嵌入读路径 | `docs/uffd.md`、`nydus-core` |
| 本地缓存 + prefetch | 多实例共享预热 | `docs/nydus.md` |

**重要边界（已证实）：**

- ublk/nbd/uffd 的 **flattened device** 布局是：`bootstrap @ 0` + blob 映射——面向 **内核 EROFS 挂载** 或 **guest 内 EROFS**。  
- README 性能表中 rund + nydus 的叙事是 **Linux agent 镜像 + EROFS over virtio-pmem**。

### 2.2 guest 内必须留下什么（已证实）

- **APFS 卷 / 系统盘语义**、SIP、签名与 macOS boot 链：只能在 guest 内完成。  
- nydus **不能**替代 APFS；只能加速「盘镜像字节」在主机上的拉取与缓存。

### 2.3 推荐接入模型（假设，Phase 2 验证）

**模型 A — 文件后端（一期优先，实现成本最低）**

```text
[构建]
  tree/
    disk.raw          # 预装好的 APFS 系统盘（用户自备，本仓不托管）
    efi/...           # 可选固件附件
  → nydus build → layer.blob + bootstrap

[运行 · rund 优先]
  nydus fuse|ublk 挂出 EROFS（主机）
       ↓
  主机路径 .../disk.raw（按需填充）
       ↓
  VMM virtio-blk file=.../disk.raw
       ↓
  macOS guest 看到普通块设备，内含 APFS
```

- 主机挂的是 EROFS；guest 从不感知 EROFS。  
- VMM 读 `disk.raw` 的哪些区间，nydus 就拉哪些 chunk group。  
- 适用 rund（直接挂文件）与 runc+外层 QEMU（bind-mount 同一文件）。

**模型 B — 块设备直出 raw（假设，后期）**

- 用 `NydusCore` 的块对齐 fetch，实现「LBA → chunk」的 **raw disk 前端**（virtio-blk 后端），flattened 布局不再以 EROFS bootstrap@0 为前提。  
- 与现有 `nydus ublk`（给内核 EROFS 用）不同，需实验代码；更贴「整盘按需」但工作量大。

**模型 C — 仅加速外层 Linux OCI（已证实可做，收益有限）**

- 对 dockur 式 wrapper 做标准 `nydusify convert`。  
- **假设**：相对整盘，冷启动收益通常远小于模型 A。

**明确不推荐作为 macOS guest 默认路径：**

- 把 Linux 那套 **UFFD + guest EROFS over virtio-pmem** 原样搬进 macOS guest（guest 无法挂 EROFS 作根）。

---

## 3. rund 优先的推荐流水线

### 3.1 端到端（目标态）

```text
1. 准备基准盘（实验室，本仓不提供内容）
   - 合法来源得到可启动 APFS raw/qcow2（golden）
   - 记录版本、尺寸、是否已装 agent SSH

2. 包装为 nydus 构建树
   misc/macos/examples/build-tree.example/
     disk.raw -> （外部路径，gitignore）
     README 说明

3. 构建（主机 Linux）
   nydus build --blob ./artifacts/macos-disk.blob ./build-tree
   nydus check --blob ./artifacts/macos-disk.blob

4. （可选）推 registry
   nydusify 或手动按 blob 命名约定上传
   # 整盘单层时也可只本地文件，不强制 OCI

5. 启动主机侧服务
   nydus fuse --blob ... --mountpoint /run/nydus/macos-a
   # 或 ublk 后再从挂载点取文件（若采用「EROFS 内单大文件」）

6. rund / VMM
   virtio-blk 指向 /run/nydus/macos-a/disk.raw
   + OpenCore/OVMF 参数（见 misc/macos/config）

7. Phase 3：guest 内访问 trace → 主机 nydus optimize → ondemand blob
```

### 3.2 与 runc 路径的差异 / 合并点

| 步骤 | rund | runc |
|------|------|------|
| 谁拉起 VMM | rund / shim 直接管 microVM | runc 先起 Linux wrapper，容器内再起 QEMU |
| nydus 挂载位置 | 主机（推荐） | 主机（推荐）或 wrapper 内（多一跳，不推荐默认） |
| `disk.raw` 传递 | VMM 配置 file/block | bind-mount 进 wrapper + QEMU file= |
| OCI `config.json` | 可能是 rund 扩展 / Kata 配置 | 标准 OCI + `/dev/kvm` |

**合并点（建议）：**

- **同一份** nydus blob / 同一主机挂载点；只换「谁读这个文件」。  
- 外层 wrapper 的 Linux OCI 可另做可选 nydusify，与盘流水线解耦。

### 3.3 构建命令占位（无真实盘时勿声称成功）

见 `misc/macos/README.md` 与 Makefile 目标 `macos-phase1-*`（占位，缺盘则跳过/报错说明）。

---

## 4. 缺口：没有基准 macOS 镜像 + Linux 实验机时卡住什么

| 缺口 | 卡住的工作 | Phase |
|------|------------|-------|
| 合法可启动的 golden `disk.raw`/`qcow2` | 真实 `nydus build`、chunk 分布、压缩率 | 1→2 |
| 带 KVM 的 Linux 机 + rund 或 QEMU+OpenCore | virtio-blk 接 nydus 文件、冒烟到 login/SSH | 2 |
| guest 内 agent 就绪判据 | Ready 时间拆分 | 3 |
| 跨边界 access trace | `nydus optimize` 热数据 blob | 3 |
| Apple 许可与镜像分发策略 | 文档/CI 能否引用外部 artifact URL | 全程 |
| 本仓 `workflow` OAuth scope | 无法推 `.github/workflows/**`；CI 草稿放 `docs/ci/` | 5 |

**Phase 1 在无 IPSW/盘时的交付边界：** 文档约定 + 目录脚手架 + 示例 YAML + Makefile 占位；**不**提交任何 macOS 系统文件，**不**声称 e2e 已通。

---

## 5. 建议的实验目录布局

```text
docs/
  experiment-v3-macos.md                         # 总目标与阶段
  experiment-v3-macos-phase1-image-pipeline.md   # 本文
  ci/
    macos-phase1.placeholder.yml                 # CI 草稿（勿放入 .github/workflows）

misc/macos/
  README.md                                      # 实验包装说明（无 e2e 承诺）
  config/
    rund-macos.example.yaml                      # rund/VMM 侧示例
    storage.local.example.yaml                   # nydus 本地存储配置
  examples/
    build-tree.example/README.md                 # 构建树约定
    oci-bundle.example/config.json.example       # 外层 runc bundle 示意
  scripts/
    phase1-check.sh                              # 检查工具链与占位路径（不拉 IPSW）
```

大文件（`*.raw`、`*.qcow2`、IPSW）应 gitignore，只保留 README 说明外部放置路径。

---

## 6. Phase 1 结论（给 Phase 2 的输入）

1. **包模型**：小 runtime 包 + 大 APFS 盘 artifact；nydus 主攻后者。  
2. **默认技术路线**：模型 A（EROFS 内承载 `disk.raw`，主机 fuse/ublk，VMM 文件后端 virtio-blk）。  
3. **rund 优先**：主机 nydus 与 VMM 同机对接；runc 复用同一挂载点。  
4. **不要**默认走 guest 内 EROFS/UFFD-pmem（那是 Linux rund 路径）。  
5. **下一步**：拿到基准盘与 KVM 机后，用占位脚本换成真实 `nydus build` + 一次 QEMU/rund 启动冒烟。

## 参考

- 上游 nydus v3 README / `docs/nydus.md` / `docs/ublk.md` / `docs/uffd.md` / `docs/nbd.md`（本仓）  
- OCI Runtime Spec bundle / config；runc man  
- RunD ATC'22；Kata Containers 4.x architecture / virtualization  
- dockur/macos；cocoon-macos（公开工程，仅作形态参考）
