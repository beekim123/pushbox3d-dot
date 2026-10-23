# 有界键盘菜单导航

本地生产运行源码：`scripts/main.gd` SHA-256 `50ff777465b3b9320ca8fde967c264e6b2f733bbda3447bce80aed79b07bb4b8`。作者与独立测试、生产复验分开记录；Git最后核实仍51e68，create_tree审批未完成，不宣称键盘或地牢墙已远端合入。

## 玩家操作

- 标题、中庭、世界选关和弹窗：Tab / Shift+Tab 循环选择当前可用按钮，方向键按屏幕布局移动焦点，Enter / Space 激活。
- 锁定、禁用或隐藏的按钮不参与导航。焦点使用原有 3 px 主题色描边，不新增按钮或控件。
- 进入棋局后，普通 HUD 和非模态线索面板不接收键盘焦点。方向键 / WASD 仍只移动；Z / Backspace、R、H、J、F1、Esc、M、F2 保持原快捷键。
- 返回选关恢复对应关卡；返回中庭恢复对应世界。帮助关闭后恢复调用处，完成状态仍显示完成弹窗。
- 退出保存失败时默认选择安全的「返回游戏」，Enter / Space 或 Esc 可返回；只有主动选中「仍然退出」才放弃本次未保存变化。保存进行中不能用 Esc 绕过保存。
- 跨菜单/弹窗进入棋局时，先前按住的方向键需松开后再按。持续按住 Enter / Space 不会连续跳过新屏幕。

## 实现边界

`UI.button` 仍默认 `FOCUS_NONE`。`main.gd` 只对当前菜单或顶层弹窗建立焦点作用域，给可用按钮连接正反循环 Tab 顺序；箭头和激活由 Godot 原生 Control/Button 处理。所有参与键盘导航的按钮均有语义 ID。

焦点初始化延后到控件入树，并核对递增的 generation；旧屏幕的任务不能抢回焦点。异步核对完成后启用 Continue 只把它加入当前作用域，不抢走有效焦点。选中按钮被禁用、隐藏或移除时回退到有效按钮。

方向释放观察位于 GUI 消费之前，保留同一帧松开/重按的语义；方向锁存扩展到所有菜单/弹窗转场，不改变棋盘、历史、提示算法、保存格式或关卡。激活键重复/echo 在 GUI 之前阻断，仍使用原生 Button 激活。

唯一现有测试语义调整：`tests/context_help_audit/behavior.gd` 原来要求普通模态关闭“不获得帮助专用锁存”；新契约要求所有模态共用转场方向锁存，故仅改该断言与注释。不是删除回归覆盖。

## 复现与证据

```sh
GODOT=/path/to/Godot-4.7.2 bash tests/keyboard_navigation/run.sh
```

本阶段仅在已验证的 Linux 云环境中使用独立临时 XDG 数据目录及真实 `Input.parse_input_event` 按下、松开、echo 和鼠标事件。直接设置屏幕仅用于解锁/异常分支夹具；报告不把直接调用当作键盘通路。

- `tests/keyboard_navigation.gd`：四世界、全部 40 主线章节页、交汇菜单、正反 Tab、语义初始/返回焦点、禁用/隐藏回退、异步 Continue、真实完成/下一关、可撤销重置与失败退出安全返回。
- `tests/keyboard_transition_guards.gd`：8 个方向物理键 × 6 类转场，按住不动、同帧松开/重按只执行一次正常动作。
- `tests/keyboard_mouse_races.gd`：鼠标→键盘切换、遮罩阻止背景点击、移除焦点控件、延后焦点竞争、Help→完成状态持续激活防连跳。
- `tests/keyboard_exit_process.gd`：Enter/Space 两个独立进程，明确选中未保存退出、正常结束、此前检查点字节不变。
- `tests/keyboard_focus_capture.gd` 与 `tests/keyboard_navigation/run_native_capture.sh`：桌面 Terminal 启动的真实 X11 截图，16 个 1440×900 状态、llvmpipe 软件渲染。截图有作者像素检查，但不等同真人可用性/无障碍验收。

## 实际结果（最终运行源码 50ff777）

| 检查 | 实际结果 |
|---|---:|
| 新增作者事件测试 | 637 / 637 |
| 独立事件、退出、失效焦点审查 | 293 / 293 |
| 原有完成状态重建 | 14 / 14 |
| 原有续玩集成 | 13 / 13 |
| 原有存档迁移与保护 | 15 / 15（含一次预期归档复制失败日志） |
| 原有帮助行为与布局 | 2,889 / 2,889 |
| 原有线索行为、真实输入、并发清理与布局 | 2,610 / 2,610 |
| 原有续玩存储/生命周期/8193历史边界等审查 | 13,114 / 13,114 |
| 204关真实 handler 回归 | 8,056 / 8,056 |
| Python 求解器回归 | 20 / 20 |
| Linux 当前字体链 | 522个不同CJK字符、0缺失 |

作者16张主题/弹窗截图绑定前一版5a9a4e（保留于原隔离历史，不作为当前生产截图）；最终50ff777只替换标题页底部操作说明。独立审查针对最终源码重新完成293条断言，并以CUA/Sky生成的真实X11输入验证标题→中庭→世界→棋局及安全退出返回，重新截取最终标题。两版证据分别保留，不把旧图/旧全关结果改标为新版本。作者最终8,056条全关回归也已重新运行。

历史截图仍在隔离候选保存；最终作者文本证据按SHA导出 `tests/keyboard_navigation/author_final/`，精确结果见其 `final_manifest.json` 与上级 `author_evidence_export_manifest.json`。新运行器默认事件输出 `tests/keyboard_navigation/results/`（KEYBOARD_QA_OUTPUT可指定外部目录），回归日志regression_results、截图native_results（KEYBOARD_NATIVE_OUTPUT可覆写）。生产新事件637/637与exit0记录在production_results，不累加进候选统计；最终生产三张1440×900图在 `screenshots/keyboard_navigation/production/`、元数据在production_native。独立原293报告在 `tests/keyboard_navigation_audit/independent_frozen/`，生产补记另附；原报告当时b529未合入的历史不改写。GODOT/PATH与临时目录仅在Linux验证，不证明macOS XDG隔离；没有硬件GPU/实体键盘/Retina/手柄/完整无障碍认证。

## 生产复验与证据保护

- 最终生产完整语料（main、resume_controller、context_help、levels）的Linux字体扫描为534个CJK字符＋7符号，missing=[]。上表候选522采用较窄扫描范围，不混同，也不改历史报告。
- 旧帮助测试被批准的新全菜单/弹窗释放契约替代，旧脚本原文保存在 `tests/keyboard_navigation/historical/context_help_behavior_pre_keyboard.gd.txt`。旧已发布日志和JSON未覆写，不能把旧结果自动归到新脚本。
- 输出运行器支持KEYBOARD_QA_OUTPUT/KEYBOARD_NATIVE_OUTPUT；建议指向独立目录，回归汇总默认regression_results。部分既有回归工具有自身输出路径，复验历史证据时应在独立工程副本运行，勿覆盖交付原始证据。
- 没有复制资产/运行源码克隆、旧qa整目录、XDG或私人存档。最终资源包与远端提交由主任务另行核实，历史已发归档不变。

最终生产全204真实handler新跑8056/204/0、exit0，74运行/模型hash稳定；`tests/results/keyboard_navigation_handlers.*`。独审驱动便携适配另外在实际生产新跑293/0、75hash稳定，证据`tests/keyboard_navigation_audit/portable_smoke_results_final/`，不累计成586；只改路径，适配的桌面observer没有另跑GUI。原冻结293、作者候选回归、生产637和root全关结果均分开记录。
