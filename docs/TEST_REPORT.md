# V2 测试状态（持续更新）

日期：2026-10-23。当前不是美术最终验收声明。V1 完整交付已归档；本页不继承其测试计数冒充 V2 结果。

## 已完成的 V2 逻辑验证

- 200 主线（四方向各 50，10章×5关）与4交汇奖励，共204。
- 全204宏推动精确求解、解答快照回放与D4对称指纹唯一；同世界剥离机关与玩家起点的骨架也无重复。
- 独立208次机制旁路搜索：200项禁用机关行为后无解；8项允许更差路线，但至少多3推。四交汇必须用两种机制。
- 32关完整步进Dijkstra与宏推动目标交叉一致；早期另有320随机小盘比对。
- Godot4.7.2规则回放16,269检查，0失败；独立矩阵16,320转移，0差异；生成器矩阵38,984转移，0差异。
- 实际运行时处理器全204关：7,852检查、0失败、完成204；包括移动、单击/缓冲、可撤销重置、胜利后撤销、40章菜单、200主线解锁、204结局与存档读写，退出无错误/警告/泄漏。
- 存档安全独立15断言：V1逐字归档、重名编号另存、备份失败不覆盖、未来版本/损坏内容只读、V2字段验证与完成ID过滤。负向故障注入会刻意制造引擎错误，不能称其日志全无ERROR；它与正常运行日志分开记录。
- Linux系统字体485个不同汉字覆盖无缺字；macOS未验证。

## V2 美术与交付检查点

- 最终62个GLB、6份Blender源结构审计通过，无外部资源依赖。旧宫殿和重复金框底盘已重做，优化花瓣/细枝/城市微倒角，保留形体而降低无效面数。
- 蟠桃园、地牢、雨林、山城均在真实Godot窗口输出两张后续关卡截图，并实际查看；中庭与标题也已重拍。初版截图发现的裁切、石块重复与道路同色已修正。每一项美术“改进”是制作方自检，不宣称用户已经认可。
- 自动构图对204关检查，HUD裁切为0；保留格点可读性。云端图形日志仍有驱动不支持切换V-Sync的警告，不把这写成完全没有任何警告。
- 候选ZIP在全新目录解压后首次导入、30帧启动、带混音完整204关实际处理器7852项检查均通过，退出0，正常headless日志无错误/警告/泄漏。结果见 tests/results/package_*_v2.log。
- 仓库迁入分批进行，只有通过远端读回与资源清单核验的commit才标记已同步；不会把已上传但未挂到分支的blob算成完整备份。
- 上述 7,852 项完整规则回归属于提示接入前的 V2 检查点。提示接入后的增量实测单列如下，不将旧全量结果冒充新版全量重跑。

## 已知限制

CPU软件渲染器的结果不等于Mac/GPU性能；未做真人谜题盲测、听感盲测、Retina或手柄测试。参考作品只用于研究，不复用资产。报告中的“通过”仅对所列实际测试成立，不意味着用户已认可新美术。

详见 tests/acceptance_audit_v2.md、docs/levels_validation.md 和 tests/results/*v2*。

## 渐进提示接入后的增量实测（2026-10-23）

- 生产求解器与冻结原型 SHA256 `f266da3bb93226cbb68c3077d8481d637411ea0da81d508016ec431c443ddbe9` 一致；只读当前棋局，不加载预存答案。
- 编辑器 headless 导入通过；最终源码与最新章节文案下，正常 headless 标题启动 30 帧退出 0，无错误、警告或资源泄漏（`tests/results/hints_boot.log`）；既有真实解锁按钮测试 17 项通过，说明 QA/截图模式没有重新引入解锁旁路。
- 最终章节文案下字体扫描：506 个不同汉字及 `↑↓←→…✓·` 7 个符号均有字形。原有撤销装饰符缺字，已改为纯文字「撤销」。证据：`tests/font_coverage.json`、`tests/results/hints_font.log`。仅验证 Linux 实际 SystemFont 回退链。
- 布局检查：204 关 × 8 种面板状态（机制提醒、搜索中、已完成、额度耗尽、无解、无效、已求解第二层、第三层）共 1,632 场景，合法格与面板投影包围盒交叠为 0。每格按四角投影验证；状态使用专门布局 fixture，不是 1,632 次真实求解。证据：`tests/hint_layout_checks.gd`、`tests/results/hint_layout_checks.log`。
- 五张真实 GUI 截图已生成并实际查看：`screenshots/v2/hints_tier1.png`、`hints_tier2.png`、`hints_tier3.png`、`hints_city_45.png`、`hints_rainforest_45.png`。前三张同一开局均为 0 步 0 推，后两张检查后期密集场景的面板和路线可读性。
- 章节文案修订后，山城第 2 章实际 GUI 截图 `screenshots/v2/chapter_city_02_text.png` 已查看：长说明正常换行、无裁切/重叠，0 进度下第 6–10 关均锁定。
- 原生窗口手动 H→J→J 确认不会自动走棋；Left 后计数才变 1 步，面板、金圈和路线立即清除；再次 H/Esc 只关闭提示，不离开棋盘。桌面正常关闭游戏，日志无 ERROR/资源泄漏；软件驱动仍报告不支持更改 VSync。`fourfold_qa/hints-manual.log` 为工作区证据，不作为工程内文件路径。
- 独立最终冻结审计：2,610 断言通过（767 行为、53 真实 Input.parse_input_event 事件分发、156 已分配搜索节点的在途中断/替换、1,634 布局断言）。9 类取消动作与未回收完立即重请求均无旧结果残留；8 个生产源/数据资源跑前后 hash 完全一致。0 SCRIPT ERROR/ERROR。独立布局额外覆盖 8,624 个潜在箱子/站位标记采样，重叠 0。证据：`tests/hint_ui_audit_summary.json`、`tests/hint_ui_audit_suite.log`、`tests/hint_ui_audit_report.md`。

补充：2026-10-23 12:38 UTC 前完成提示接入与教学文案修订后的全 204 关真实处理器回归，带混音、隔离存档，7,852 项检查全部通过，完成 204，退出码 0；日志无 ERROR / WARNING / 资源泄漏。源文件指纹与独立提示审计一致。证据：`tests/results/hints_full_handlers.log` 及对应 JSON。没有将 12 帧截图的冷启动指标当作性能基准。macOS、Retina、真实 GPU、手柄仍未验证；2ms 是分帧软预算，不保证硬实时。

## 续玩恢复后增量验证（2026-10-23，14:15 UTC以后）

云端故障前13:12启动的续玩后全204回归没有终态证据，**不计通过**。旧续玩截图/临时日志不作为本轮验收。main/controller逐字重建且与故障前SHA一致，codec原封恢复，store仅preload路径改变；这只是恢复真实性，不替代测试。

- 新环境编辑器导入无ERROR，正常headless标题启动30帧退出0，无错误/资源泄漏。`tests/results/resume_rebuild_import.log`、`resume_boot.log`。
- 新跑真实处理器自测13断言通过：逻辑移动、重置、标题真实Continue、完整撤销、revision取消、保存失败确认及返回。`tests/results/resume_integration.log`。
- 新跑真实解锁按钮17项通过；永久进度V2迁移15断言通过，负向故障注入的预期复制失败ERROR单列，不伪称该负向日志零ERROR。`tests/results/resume_unlock.log`、`resume_progress_regression.log`。
- 最新main/controller/关卡文案的实际Linux字体链529汉字与7符号无缺字。`tests/results/resume_font.log`。
- 恢复后的最新生产全204关真实处理器已重新完成：7,852检查、0失败、完成204、退出0；全部scripts、levels和project跑前后SHA一致，日志无ERROR/WARNING/资源泄漏。证据 `tests/results/resume_recovered_handlers.log` 与 `.json`。该项带混音但QA关闭sidecar，只证明原玩法无回归，不替代续玩功能验收。13:12中断的旧回归仍不计通过。
- 恢复后的独立续玩最终新跑：9项headless进程阶段共13,114检查通过，加真实X11原生3进程50检查通过，共13,164，0失败；不累计前面的重复轮。生产与独审隔离副本输入SHA一致，运行前后稳定。证据 `tests/resume_ui_audit/evidence/headless/manifest.json`、`evidence/native/manifest.json` 及分项JSON/日志。
- Headless分项：57生命周期（包括两项已修缺陷）、138存储保护、10节流/并行软预算、9历史上限、12,854布局、15失败退出事件分发、7跨进程写入、12重启恢复、12未来永久进度保护。8192完整历史保留、8193拒绝不截断运行undo；具体范围以分项证据为准。
- 原生窗口真实操作完成：Continue→三次Z（含Undo Reset）→Alt+F4；外部future字节替换已验证记录后，移动/退出触发保护，实际点Return回到未保存局面，再次退出并点StillExit。三个进程均exit0，外部原字节完全保留。不是把调用handler的headless测试冒充鼠标键盘验收。
- 已亲看并复制当前原生窗口截图 `screenshots/v2/resume_title.png`、`resume_restored.png`、`resume_exit_failure.png`。退出图为真实外部文件冲突，显示“不是当前最新局面”“不保证仍可恢复”，无文本裁切；不是停机前的假注入旧图。
- 原两项阻塞缺陷新环境回归通过：取消启动旧档reader会明确只读暂停，不再静默停存；磁盘token变更清可恢复candidate，禁用Continue，只保留参考摘要，不承诺旧档可恢复。
- 独审测得本轮共享2ms软预算调用峰9.616ms，8192历史tick峰3.072ms；这些是实际测量而非硬实时保证。当前Linux/X11结果不证明macOS/Retina/硬断电持久性或极限历史完全无卡顿。
