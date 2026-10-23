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
- 以上仅为模块级验证。`audit/`、UI integration/capture脚本的独立审查与生产完整回归必须按后续新结果分别记录，不能使用旧环境中断的测试冒充通过。
- 旧恢复说明 `RECOVERY.md` 保留为时间线；当前模块状态以上述新run为准。

## 布局与复验

`.gdignore`让本目录不影响仓库根项目的资源导入。原型说明见 `PROTOTYPE_README.md`。从本目录运行：

```sh
GODOT=/path/to/godot-4.7.2 python3 tests/run_tests.py
```

这条命令只运行模块测试，不把备份的UI main/controller变成已连接场景；它们的生产preload路径尚未按本目录布局连接。不要直接覆盖已测试生产版本。

分支：`work/resume-rebuild`。远程资源仍不完整：47/62 GLB，Ogg/WAV与Blender源未齐；此阶段无二进制写入。
