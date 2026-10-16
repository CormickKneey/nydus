# Phase 3 冷启动对比结果（模板）

> 复制到实验室本地（例如 `misc/macos/artifacts/phase3-results.md`）再填数。  
> **不要**把含专有镜像 hash 以外的敏感路径强行公开；本文件仅为格式示例。  
> 无真实测量时保持单元格为空或写 `N/A`——禁止编造秒数。

## 环境

| 项 | 值 |
|----|-----|
| 日期 | YYYY-MM-DD |
| 主机 | （内核 / CPU / 内存） |
| nydus 版本 / commit | |
| VMM | rund / QEMU / Dragonball + 版本 |
| golden disk | 文件名 + sha256（本地） |
| blob / bootstrap | 路径或 digest |
| optimize | 有/无；trace 工作负载描述 |
| 网络 | 本地 blob / registry；RTT |
| ready 探针 | 例如：SSH 可登录 / agent /readyz |

## 指标定义（与设计文档一致）

- **T_pull**：镜像/元数据拉取  
- **T_runtime**：VMM/rund 启动到 guest 可见块设备/固件交接  
- **T_ready**：到 agent 就绪探针  
- **Bytes_fetch**：后端实际下载压缩字节  

## 结果表（中位数，n≥3）

| 场景 | T_pull | T_runtime | T_ready | T_total | Bytes_fetch | n | 备注 |
|------|--------|-----------|---------|---------|-------------|---|------|
| B0 整盘本地文件 | | | | | | | |
| B1 nydus 冷（未 optimize） | | | | | | | |
| B2 nydus+optimize 冷 | | | | | | | |
| B3 nydus+optimize 热 cache | | | | | | | |

单位：秒（建议三位小数）或毫秒（全文统一）。

## 观察与结论（实验室填写）

- 相对 B0，B2 的收益主要在：T_pull / T_ready / 两者  
- 长尾或失败次数：  
- 是否复现：是 / 否  
- 下一步：调 `fetch_size` / 重采 trace / 修接线  

## 附件索引（本地）

- trace：`.../traces/boot-agent-ready.json`  
- optimize 输出 bootstrap / ondemand digest：  
- VMM cmdline 文本：  
