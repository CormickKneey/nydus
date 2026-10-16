# build-tree.example

`nydus build` 的输入目录约定（模型 A：EROFS 内承载大盘文件）。

## 预期文件

| 文件 | 必需 | 说明 |
|------|------|------|
| `disk.raw` | 是（运行构建时） | 预装 APFS 的系统盘；**勿提交到 git** |
| `META.txt` | 否 | 人类可读的镜像版本、来源策略、尺寸 |

可选：把 OpenCore 小文件放进同树（如 `efi/`），随同一 nydus blob 分发；也可靠 VMM 配置单独挂载固件。

## 本地放置示例

```bash
# 仓库外存放 golden，再 symlink（symlink 目标勿提交）
ln -s /var/lib/nydus-macos/golden/sequoia.raw disk.raw
```

`.gitignore` 已忽略本目录下的 `disk.raw` / `*.qcow2`。
