# Phase 2：rund / VMM 接线笔记（模型 A）

> 假设约定，**不是**某一发行版 rund 的官方配置格式。  
> 目标：把主机 nydus 挂载点下的 `disk.raw` 交给 microVM 的 **virtio-blk 文件后端**。

## 1. 启动顺序

1. 准备 blob/bootstrap（Phase 1 `nydus build`；需用户 golden 盘）。  
2. 启动主机按需服务，例如：

   ```bash
   sudo mkdir -p /run/nydus/macos-a
   nydus fuse \
     --bootstrap /var/lib/nydus-macos/artifacts/macos-disk.boot \
     --config /etc/nydus/macos-storage.yaml \
     --mountpoint /run/nydus/macos-a
   # 实际 flag 以 `nydus fuse --help` 为准
   ```

3. 确认：`test -r /run/nydus/macos-a/disk.raw`。  
4. 再 `rund` / QEMU / Dragonball **create**，disk 源为该绝对路径。  
5. 停止：先销毁 VM，再 `fusermount -u` / `umount`（ublk 路径还要 delete 设备）。

## 2. rund 优先：配置映射示意

将 [`../config/rund-macos.example.yaml`](../config/rund-macos.example.yaml) 中的：

```yaml
nydus:
  mountpoint: /run/nydus/macos-a
  disk_relative_path: disk.raw
disks:
  - source: "${nydus.mountpoint}/${nydus.disk_relative_path}"
    driver: virtio-blk
```

翻译成真实引擎字段，例如 QEMU：

```text
-drive file=/run/nydus/macos-a/disk.raw,format=raw,if=none,id=sysdisk,readonly=on
-device virtio-blk-pci,drive=sysdisk,bootindex=1
```

（OpenCore/OVMF、CPU 伪装、`isa-applesmc` 等仍按实验室固件文档；本仓不托管固件。）

## 3. runc 包装（次要）

- 主机仍跑 nydus；向 wrapper bundle **bind-mount** `/run/nydus/macos-a`。  
- 容器内 QEMU 使用相同 `file=` 路径。  
- 勿在每个容器内再起一套 nydus（缓存会分裂）。

## 4. 可写策略

| 方案 | 说明 |
|------|------|
| 系统盘 readonly + 第二块数据盘 | 推荐实验默认 |
| qcow2 overlay 指向 raw 基盘 | overlay 文件在普通主机文件系统上，基盘仍来自 nydus |
| 直接写 FUSE 上的 disk.raw | **不推荐**；增量与缓存语义复杂 |

## 5. 当前阻塞

- 无用户提供的 golden `disk.raw` → 无法真实 mount 出文件。  
- 无 rund/QEMU+OpenCore 接线 → 无法验证 virtio-blk 链路。  
- 因此 `phase2-smoke.sh` 只做前置检查，**缺盘必须失败**。
