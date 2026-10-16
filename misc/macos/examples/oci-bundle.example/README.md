# oci-bundle.example

外层 **runc** 路径示意：Linux wrapper + bind-mount 主机 nydus 挂载点。

- `config.json.example` 不能直接 `runc run`（缺少真实 `rootfs/` 与启动脚本）。  
- 默认优先仍是 **rund 主机侧直接接 VMM**；本示例仅说明 runc 如何复用同一 `disk.raw`。
