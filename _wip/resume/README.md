# 续玩源码恢复 · WIP

本分支用于源码保全和分层验证；**不表示生产UI、完整204关或完整远程运行资产已验收。main仍保持已保存基线。**

## 已保全的四份原始源码

| 文件 | SHA-256 |
|---|---|
| resume_codec.gd | 5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305 |
| resume_store.gd | c3840e3fabd873c6fc0dcfb494252bdb0f5fa6331951e9c0afed4f11e8828566 |
| resume_controller.gd | fecc26a2c27bbe3bdf569efb4e22b4084b167dfa08b8effe93b7ec07a9bda862 |
| main.gd | f4768bae8bedcae981afa1c25051acd23b16d31c7af741b1a7ff15415372c93f |

## 恢复后实际验证

- **2026-10-23 14:19:49–14:19:54 UTC**：独立 codec/store 原型重新执行，7,368 断言、0失败，源码前后哈希不变。证据见 `TEST_REPORT.md`、`results/fresh_run_manifest.json` 和 `BACKUP_MANIFEST.json`。
- 本次使用204条ID+solution的12KB最小夹具，源于完整solver报告；派生脚本与provenance一并保存，不依赖远程缺失的大报告。
- 以上仅为模块级验证。独立审查新结果见下方；生产完整回归和 main 提升仍需另行确认，不能使用旧环境中断的测试冒充通过。
- 旧恢复说明 `RECOVERY.md` 保留为时间线；当前模块状态以上述新run为准。

## 布局与复验

`.gdignore`让本目录不影响仓库根项目的资源导入。原型说明见 `PROTOTYPE_README.md`。从本目录运行：

```sh
GODOT=/path/to/godot-4.7.2 python3 tests/run_tests.py
```

这条命令只运行模块测试，不把备份的UI main/controller变成已连接场景；它们的生产preload路径尚未按本目录布局连接。不要直接覆盖已测试生产版本。

分支：`work/resume-rebuild`。远程资源仍不完整：47/62 GLB，Ogg/WAV与Blender源未齐；此阶段无二进制写入。

## 新增独审证据（2026-10-23）

- 14:27:52–14:28:47 UTC：新 headless 独审 13,114 检查、9进程退出0；源码锁定一致。见 `audit/results/20261023T142752.177145Z/manifest.json`。
- 14:22–14:25 UTC：原生桌面续玩/撤销与失败退出流程 50检查、3进程退出0。见 `audit/results/native_20261023T142253Z/manifest.json`。6张PNG仍未上传。
- 14:27:37–14:27:41 UTC：按提交 `6accd40a` 的42个WIP文件真实布局另跑模块测试，7,368检查通过；见 `results/layout_replay_6accd40a.json`。
- 审查 runner 保留原工作区路径，尚非可直接从本WIP目录运行的完整UI测试包。详细范围、缺失截图和路径限制见 `audit/REPOSITORY_BACKUP.md`。这些证据不代表 main 已合入续玩或远程工程资源完整。
