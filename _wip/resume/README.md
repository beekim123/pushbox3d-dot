# 续玩源码恢复 · WIP

本目录是恢复后的源码保全检查点，不是已经接入 `main` 或完成新环境回归的可玩功能。

## 已保存源码

| 文件 | SHA-256 |
|---|---|
| resume_codec.gd | 5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305 |
| resume_store.gd | c3840e3fabd873c6fc0dcfb494252bdb0f5fa6331951e9c0afed4f11e8828566 |
| resume_controller.gd | fecc26a2c27bbe3bdf569efb4e22b4084b167dfa08b8effe93b7ec07a9bda862 |
| main.gd | f4768bae8bedcae981afa1c25051acd23b16d31c7af741b1a7ff15415372c93f |

四份源码已重建并对稳定读取字节核验，哈希与先前冻结值一致。`rebuild_main.py` 和 `RECOVERY.md` 记录恢复过程；相同源码哈希不等于测试已经重跑通过。

**此检查点只证明源码已备份；恢复后的解析、独立模块/UI审查和完整204关回归结果须以后续新证据为准。旧环境中断的回归不得记作通过。**

目录通过 `.gdignore` 隔离，内部 `res://scripts/...` 依赖路径尚未按此备份布局连接。不得直接把本目录当成可运行工程或覆盖已测试版本。

分支为 `work/resume-rebuild`；`main` 保持基线 `f421db6716fbac6ae1de326b02758e9376ac48a4`。远程资源仍不完整（47/62 GLB，Ogg/WAV与Blender源尚未迁入）；本阶段无二进制写入。
