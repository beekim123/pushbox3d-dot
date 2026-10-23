# 生产渐进提示 UI 独立审查

审查日期：2026-10-23。实际引擎：**Godot 4.7.2 stable ed1daf0bf**。审查者仅新增/修改 `tests/hint_ui_audit*`，没有修改运行代码、关卡或 Git。

## 结论

**在本报告的已测范围内通过，未发现阻塞生产交付的提示 UI 缺陷。** 最终四套共 **2,610 断言，0 失败**；8 个运行源文件/资源在套件运行前后 SHA256 完全一致。结果见 `hint_ui_audit_summary.json`，完整控制台见 `hint_ui_audit_suite.log`。各次实际 Godot 进程退出 0，日志未出现 SCRIPT ERROR / ERROR。

| 独立测试 | 断言 | 实际覆盖 |
|---|---:|---|
| `hint_ui_audit.gd` | 767 | 生产场景、真实按钮信号/键处理器、搜索与退出的 SceneTree 帧、状态快照、提示生命周期、终态文案 |
| `hint_ui_audit_input.gd` | 53 | `Input.parse_input_event` 鼠标点击和键盘事件经过实际 UI 事件分发，不只直接调用处理器 |
| `hint_ui_audit_pending.gd` | 156 | 真正仍在运行且已分配节点时的 9 类取消，以及旧图尚未回收完就请求新提示 |
| `hint_ui_audit_layout.gd` | 1,634 | 全 204 关 × 8 个实际面板文案模板，共 1,632 布局；合法格及提示标注保守投影范围 |

## 行为证据

- **逐级主动揭示**：第一层是通用世界规则/轻线索，不搜索、不声称针对当前状态选中箱子；第二次操作才请求当前局面的下一推（箱子金圈及方向）；第三次操作才展开该推之前的非推动到位路线。默认结果没有完整解法 `solution_actions`。
- 天堂、地狱、雨林、城市和交汇五个实际棋局均完成三层流程，并用原 `PuzzleRules.step` 重放到位路线与下一推。中途合法移动后再次请求使用新局面，而不是开局答案。
- 搜索、展开、重复操作和收起不会改变玩家/箱子、步数/推数、历史或进度；搜索中重复展开不会追加请求。动画中忽略 H/J。获胜和撤销获胜不会残留旧标注。
- 合法移动、撤销、重置、撤销重置、同关重开、换关、世界菜单、中庭、标题、help/modal、收起按钮、H 与 Esc 均检查取消及删除面板/路线。Esc 有提示时只收起，不直接离开棋盘。
- **在途矩阵**不是仅关闭已经显示的解：每一项先在 `inferno_44` 等到实际搜索已分配节点、仍为 running，再执行 close / H / Esc / 移动 / 撤销 / 重置 / 同关 / 换关 / help；实际 `_process` 最终回收，旧 token 失效且标注不复活。
- 旧图未清完立即再次请求：新代号生效，旧代号调用 `step_budget` 返回 stale 且不增加新请求 compute_ms，最终只显示新结果。另有绕过正常移动处理器直接修改 state 的防御用例，晚到结果被状态签名拒绝。
- **真实输入分发**：鼠标点击提示按钮后，按钮不获得焦点；方向键和 WASD 都能恰好走一步并取消提示，释放后不会继续移动。H/J/Esc 和鼠标收起同样经 `Input.parse_input_event` 检查。此项为 headless Godot 的真实事件传播，并非操作系统向原生窗口注入。
- 预算终态通过真实按钮开始，再由测试单独收紧内部节点限额可靠触发；生产处理器显示“达到上限 / 这不代表无解”，不显示死局或部分路径。已知合法无解、已完成状态另外验证。生产请求仍为默认 **8,000 节点**，没有任意提高 cap 的 UI。
- 同一个 solver 跨关卡/菜单持有；进入菜单后即使没有活动提示，实际 `_process` 仍泵退休清理。退出处理器等待清理，无残留引擎报错。QA 模式未创建玩家主存档 `user://fourfold_progress.json`。

## 布局与像素证据

以 **1440 × 900** 实际 viewport/camera/panel 测量：204 关 × clue、running、already_solved、budget_exhausted、unsolvable、invalid、solved tier 2、solved tier 3 共 **1,632** 文案模板布局。检查 **34,496** 合法格投影 AABB，以及 **8,624** 潜在箱子/站位标注采样；对所有地板相邻方向保守计算金圈、箭头和站位圈包围范围，不依赖该格目前是否有箱子或动态阻挡。面板全部在 viewport 内，**与这些棋格和标注 0 重叠**。

这是一组全关卡的几何/文本模板测试，**不是声称实际求解并截图了 204 × 8 局面**。invalid 模板只验证布局，不代表生产玩家流程会产生非法状态。

独立查看了运行作者通过原生 Godot 窗口生成的以下 PNG 像素；没有用占位图代替游戏画面：

- `screenshots/v2/hints_tier1.png`
- `screenshots/v2/hints_tier2.png`
- `screenshots/v2/hints_tier3.png`
- `screenshots/v2/hints_city_45.png`
- `screenshots/v2/hints_rainforest_45.png`

三级天堂示例和后期城市/雨林示例中，中文可读，无明显裁切/缺字；金圈和方向箭头可辨，薄荷路线及站位圈清楚，左面板未遮住合法棋格或底栏，计数仍为 0 步 / 0 推。保存的 PNG 均为 1180 × 737；文件尺寸及 SHA256 见 `hint_ui_audit_capture_manifest.json`，不要将该像素尺寸混同于前述 1440 × 900 几何测试 viewport。截图是作者生成、审查者独立查看；作者另外报告了原生窗口 H/J/J、Left、H/Esc 与窗口关闭手测，此手测不混入本审查断言计数。

## 冻结源版本

| 文件 | SHA256 |
|---|---|
| `scripts/main.gd` | `417544c6b1f43914bc8f83524d9037e073a7c84cb5ea9ac04cc7971dd0534e41` |
| `scripts/hint_solver.gd` | `f266da3bb93226cbb68c3077d8481d637411ea0da81d508016ec431c443ddbe9` |
| `scripts/hint_overlay.gd` | `9e5c58a95617444feb0d2c6475fb9490b0c855bb7e45f20919f2a5e42b11bd7a` |
| `scripts/puzzle_rules.gd` | `260130edbe5978fc610a5e8fcc2f84ff19e8fc8beb16d3a2971790f1cc68df64` |
| `scripts/world_view.gd` | `da7cacb34f8fc3d75bb0355bc07352664ed8781ee09ac46319c16e7837caebe7` |
| `scripts/ui_kit.gd` | `5338959aea6f222952feedf8f3f53c4eaabb2be87d52e3c9c95f359057291be6` |
| `assets/levels.json` | `3658774f0015b859ff27e13b0ef48c6e5071df921d0d155be797565de302fcda` |
| `project.godot` | `a0bca2ccbcdcc25b15b0f8ff59b84307e39c369f851b48f308568f607159850a` |

求解器与前一阶段独立审查冻结版本一致，原规则 SHA 未变。当前 levels hash 已包含批准的 learning_goal 文案调整；该调整不等同于规则变更证明，本报告只记录实际测试的精确资源版本。

## 复现

```sh
cd fourfold_atelier
GODOT=/path/to/godot-4.7.2 bash tests/hint_ui_audit_run.sh
```

如果 PATH 已有合适版本的 `godot` 或 `godot4`，可省略 GODOT。需要 Bash 和 Python 3；不依赖 GNU timeout。runner 严格验证引擎 4.7.2，为每次运行创建独立 mktemp XDG 目录，使用 `--qa`，逐测试以 Python subprocess 施加 180 秒超时，检查日志错误与断言并锁定源文件运行前后 hash。报告/log 写入 `tests/hint_ui_audit*`；不要在同一个 checkout 同时跑两个写这些报告的实例。

本次实际命令为：

```sh
GODOT=/workspace/scratch/e4cad742399c/tools/godot-4.7.2/godot \
  bash tests/hint_ui_audit_run.sh > tests/hint_ui_audit_suite.log 2>&1
```

显式不存在的 binary 已另测清楚报错并退出 1，见 `hint_ui_audit_runner_invalid_binary.log`。

## 剩余风险 / 不作的承诺

- `step_budget(2.0)` 仍是**软预算，不是硬实时**。此前高上限容器缩容/释放尖峰没有被撤销；8,000 UI cap 和渐进回收降低可达负载，不构成任何机器上的帧率或最大延迟保证。不得把高 API cap 直接开放 UI。
- 本次未做 GPU 帧率基准、长时间压力/内存统计，也未系统测试触控、手柄、多分辨率、缩放/窗口缩小或色觉可访问性。全关卡几何结论限定在 1440 × 900。
- 实际 UI 求解行为覆盖代表世界、特定中途状态/终态和在途取消，不是穷尽所有可达局面。求解最优性另有此前独立动作级 oracle 审查，不能用这份 UI 布局计数代替它。
- runner 删除了硬编码云端路径和 GNU timeout 依赖，但**本次只在当前 Linux 环境实际运行，未在 macOS 实测**。
