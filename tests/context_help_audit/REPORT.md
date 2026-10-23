# F1 章节练习与关闭后输入边界：独立整合审查

## 结论

**最终运行源码通过本轮独立专项审查。** 不是沿用提案原型结果：对真实生产 `show_help`、输入分派、tween、线索及续玩控制器重新执行，**193 项行为断言 + 2696 项布局断言 = 2889 项通过**，实际分派 **352 个物理键事件**。另从原生桌面启动 Godot 渲染 **6 张 1440×900 截图**，逐张独立查看像素，无文字/按钮裁切或旧关卡说明泄露。

冻结功能文件：

- `scripts/main.gd`: `15a68661146db4cc1e47c11ea2a60ca2be0115099d529d0e54a1b46a11a6650e`
- `scripts/context_help.gd`: `0b43d5dedeffa7a305c87a897b103766097c72387ce601ba7a342488fbfd32f4`

前后 hash 相同；完整依赖指纹见 `summary.json`。本审查只写专属测试、结果与截图，未修改运行源码或 Git。

## 实际覆盖

- 真正的 F1 与顶部按钮打开；重复 F1 只有一个弹窗；按键 echo 不重建；“明白了”真实鼠标事件和 Esc 关闭；第一次 Esc 不离开关卡。
- **方向键与 WASD 全部 8 键**：弹窗内按住、关闭后保持、同一帧松开再按下均验证。关闭后旧按住状态不续走；明确的新按下不被过度吞掉；多键同时按住必须释放全部旧键。
- 在 F1 **之前已按住** Left/A，动画中重复 F1 再关闭也不漏步；`clear_ui` 置换帮助后进入新关，旧方向不会推动新关；普通非帮助弹窗关闭不获得新增 guard。
- R/Z 仍有意关闭帮助并重置/撤销；重置保留完整 undo；之后持续按住的方向不偷偷续走。
- 已提交逻辑移动的 tween 保持运行；旧单步缓冲不复活；开关帮助不多走一步。最后一步已赢时仍由正常完成流程显示胜利并记录通关，不取消终点。
- 真实 pending H/J 求解被 F1 取消后，旧请求及 overlay 不复活；重新 H 仍先给第一层，J 新建请求；从不自动移动。
- `mode` 严格门控：不同世界/章节预览、中庭和标题即使仍有旧 `level`，也不出现旧练习。新关刷新文案。缺字段、空白、null、数字、数组均省略章节块。
- 真实隔离续玩 sidecar：dirty 保存可在帮助打开时完成；帮助本身不增 revision/commit，不改局面、历史或永久进度。重新载入控制器的核对可在标题帮助期间完成；继续游戏恢复完整撤销，不持久化帮助开关。失败退出决定不被 F1 或直接帮助 callback 替换；原有退出返回松键防护保持。

这里的输入是 Godot `Input.parse_input_event` 的真实传播，包括 physical keycode 和鼠标事件，**不是只直接调用移动 handler**。存档 round trip 本轮为同进程新控制器，不冒充跨进程重启专项。

## 原生按住键补测（与引擎事件统计分开）

又通过已公开的 CUA `App.pressKey(key, {durationMs})` 操作真实 X11 游戏窗口；专属 observer **没有调用 `Input.parse_input_event`**：

- `a+Escape` 持有：Godot 实际收到 A 的 `physical_keycode=65`，先 A 按下、后 Esc 关闭帮助，A 在 **1273 ms** 后释放。关闭后的 **21 个采样**均显示 A 仍按住、help guard 有效、步数仍为 0；松开后新按 a 恰好走 1 步。`native_hold_wasd.json` 通过。
- 原生 Left 组合的 CUA 注入却给出 `physical_keycode=0`，`is_physical_key_pressed(Left)` 一直为 false。它只证明帮助可关闭及新单按可移动，**不能验证箭头物理长按防护**。`native_hold.json` 保留探针未满足前置条件的原始失败，不将它误解释为生产代码出现漏步；分类说明见 `native_input_review.json`。
- 两次都没有 echo 事件，因此 **OS autorepeat 尚未验证**；也不称真人硬件键盘长按验收。完整 8 键和同帧 release/repress 的证据仍是前述 352 个引擎真实分派事件，不混入原生统计。

## 布局与原生视觉

布局调用真实 `start_level` 和 `show_help`，检查 **204 关 + 4 个非关卡状态 = 208 行布局**。所有 Label/按钮在 1440×900 viewport 与弹窗内；每个弹窗仍只有原有一个关闭按钮。最大 `city_04` 为 **560×741，y=79**，无需新按钮或滚动容器。

最终 helper 版本通过原生 X11 / llvmpipe、Godot 4.7.2 再渲染并独立查看：

| 截图 | 独立查看结果 |
|---|---|
| [city_04](../../screenshots/context_help_audit/city_04.png) | 最长观察问题完整，条件句不规定唯一解法；关闭按钮完整。 |
| [heaven_13](../../screenshots/context_help_audit/heaven_13.png) | “能否成为”挡停问题完整，不把参考解法说成必须路线。 |
| [city_06](../../screenshots/context_help_audit/city_06.png) | 保留已修正的兼目标灯板练习，没有错误的强制回收说明。 |
| [confluence_01](../../screenshots/context_help_audit/confluence_01.png) | 双机制练习温和表述，无必经路线断言。 |
| [world_stale_level](../../screenshots/context_help_audit/world_stale_level.png) | 选关仍缓存 `confluence_01`，弹窗无章节块。 |
| [title_generic](../../screenshots/context_help_audit/title_generic.png) | 标题通用帮助没有残留关卡说明。 |

图片为游戏真实 viewport 渲染，不是图片生成或手工拼图。桌面显示器本身为 1364 px 宽；测试窗口/保存 viewport 明确设成 1440×900，因此此结论是 **1440×900 游戏画布内布局**，不是“窗口整体适配 1364 px 桌面”的结论。未验证小屏、Retina、macOS 字体或硬件 GPU 性能。

## 可复现命令与证据

从项目根目录运行（Linux，Godot 4.7.2）：

```sh
GODOT=/path/to/godot-4.7.2 tests/context_help_audit/run.sh
```

原生截图必须在有图形会话的终端启动，不能在无 DISPLAY 的 executor 假称完成：

```sh
GODOT=/path/to/godot-4.7.2 tests/context_help_audit/native_capture.sh
```

- `behavior.json/.log`：193 行为断言与 352 键事件统计。
- `layout.json/.log`：全部 208 个状态的真实 Label 行数、文字及矩形。
- `source_before.json`、`summary.json`：本轮最终运行依赖前后指纹。
- `capture.json/.log`、`native_source_before.json`、`native_manifest.json`：原生显示服务器、实际分辨率、最终源码和每张 PNG SHA。
- `visual_review.json`：独立像素查看记录；与原生 capture 成功区分。
- `runner_rejects_wrong_version.log`：实际 Godot 4.6.3 被 runner 拒绝，未冒充 4.7.2 测试。
- `native_hold.gd/.json/.log`、`native_hold_wasd.gd/.json/.log`、`native_input_review.json`：原生箭头工具边界与 WASD A 持有证据；原始不通过前置条件的探针也保留。
- `FINAL_SUMMARY.json`：本阶段独审总览；只汇总本次新结果，不混入提案原型、旧 hint 或 resume 阶段统计。

这是一项 UI/生命周期专项通过，不是 204 关真人趣味验证、新最优解证明或全仓库回归通过。求解规则、200+4 关数据、live hint solver 与持久化格式均未由本审查修改。
