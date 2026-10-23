# 续玩源码恢复 · WIP

本目录是恢复后的源码保全检查点，不是已集成或已验证的可玩功能。

- 分支：`work/resume-rebuild`；基于已保存的 `f421db6716fbac6ae1de326b02758e9376ac48a4`，不改变 `main`。
- `resume_codec.gd` 和 `resume_controller.gd` 已重新构建，并对稳定读取的字节完成 SHA-256 核验。
- 两份源码的哈希与先前冻结值一致；这不表示恢复后的环境已经重新运行测试。
- **本检查点尚未执行恢复后的 Godot 解析、单元测试、UI 整合或完整 204 关回归。旧测试结果不能作为本次通过证据。**
- controller 所需的 store 模块、运行路径连接与 UI 变换仍待后续检查点。此目录放置 `.gdignore`，避免未连接的 preload 影响已有工程导入。
- 首批源码 SHA-256：
  - codec：`5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305`
  - controller：`fecc26a2c27bbe3bdf569efb4e22b4084b167dfa08b8effe93b7ec07a9bda862`

远程工程资源仍不完整：47 / 62 GLB，Ogg/WAV 与 Blender 源文件尚未迁入；本分支未新增任何二进制资源。
