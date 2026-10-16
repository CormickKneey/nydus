# misc/macos/phase3 — 冷启动对比脚手架

> **脚手架 only。** 无 golden 盘时脚本必须失败；不产生也不声称任何加速数字。  
> 设计：[`docs/experiment-v3-macos-phase3-coldstart.md`](../../../docs/experiment-v3-macos-phase3-coldstart.md)

| 文件 | 作用 |
|------|------|
| `phase3-bench.sh` | 检查 disk/blob/KVM 等；缺资产 exit 1 |
| `phase3-optimize-check.sh` | 检查 optimize 输入；默认 dry-run，`MACOS_PHASE3_RUN_OPTIMIZE=1` 才执行 |
| `optimize-examples.sh` | 打印样例命令行（不跑优化） |
| `results.example.md` | 对比结果 Markdown 模板 |

```bash
make macos-phase3-bench          # 缺盘 → 非零退出（预期）
make macos-phase3-optimize-check
bash misc/macos/phase3/optimize-examples.sh
```
