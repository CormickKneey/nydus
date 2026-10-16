# misc/macos — experiment/v3-macos 包装脚手架

> **状态：脚手架 only。** 这里没有可启动的 macOS 系统盘，也没有端到端验证。  
> 产品方向：Linux 主机 → macOS 容器（rund 优先 / runc 其次）+ nydus v3 冷启动与按需加载。  
> 详设：Phase 1 [`docs/experiment-v3-macos-phase1-image-pipeline.md`](../../docs/experiment-v3-macos-phase1-image-pipeline.md) · Phase 2 [`docs/experiment-v3-macos-phase2-host-ondemand.md`](../../docs/experiment-v3-macos-phase2-host-ondemand.md) · Phase 3 [`docs/experiment-v3-macos-phase3-coldstart.md`](../../docs/experiment-v3-macos-phase3-coldstart.md)

## 布局

| 路径 | 用途 |
|------|------|
| `config/` | nydus 存储与 rund/VMM 示例 YAML |
| `examples/build-tree.example/` | `nydus build` 输入树约定（不含真实 `disk.raw`） |
| `examples/oci-bundle.example/` | 外层 runc OCI bundle 示意 |
| `scripts/phase1-check.sh` | 检查本机是否具备 build/check 工具链与占位路径 |
| `phase2/` | 主机按需挂载 YAML、rund 接线笔记、`phase2-smoke.sh` |
| `phase3/` | 冷启动 bench/optimize 脚手架、结果模板 |

## 不要提交

- `*.raw` / `*.qcow2` / IPSW / 任何 Apple 系统镜像内容  
- 真实 registry 密码或签名私钥  

请把大文件放在仓库外（例如 `/var/lib/nydus-macos/`），用环境变量或本地 symlink 指向。

## 预期流水线（有基准盘之后）

```bash
# 1) 自备 golden 盘到构建树
cp /path/to/golden.raw misc/macos/examples/build-tree.example/disk.raw   # 本地，勿 git add

# 2) 构建 nydus blob（需已 make release）
make macos-phase1-build MACOS_BUILD_TREE=misc/macos/examples/build-tree.example

# 3) 校验
make macos-phase1-check

# 4) 主机挂载后，把 .../disk.raw 交给 rund/QEMU virtio-blk（Phase 2）
make macos-phase2-smoke

# 5) 冷启动对比前置检查（Phase 3；缺盘必须失败）
make macos-phase3-bench
make macos-phase3-optimize-check
```

无盘时，`make macos-phase1-build` / `macos-phase3-bench` 会失败并打印说明——这是预期行为。
