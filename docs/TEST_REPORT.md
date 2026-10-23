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

## F1 情境帮助：最终增量验证

- 首版生产导入无ERROR；最终新增formatter纳入Linux实际字体链扫描，532汉字及7符号无缺字。`tests/results/context_help_import.log`、`context_help_font.log`。
- 真实Godot图形窗口1440×900、高画质截图已生成并亲看：`screenshots/context_help/city_04.png`（最长）、`heaven_13.png`、`city_06.png`、`title_generic.png`。长说明与关闭按钮完整，无裁切；非棋局标题帮助不显示残留上一关章说明。脚本与实际尺寸在 `tests/context_help_capture.gd`、`tests/results/context_help_capture.log`。
- 最初CLI分辨率被窗口初始化限制到1180×737；最终测试脚本明确设置root.size后重拍为1440×900。只将最终目标尺寸图片作为本轮证据，不宣称Mac/Retina/小窗口已测。
- 最终类型守卫版本独审：193行为＋2696布局＝2889断言通过，352个真实Input.parse_input_event键事件；覆盖8方向键、同帧release/repress、R/Z、缓冲与已提交tween终点、胜利协调、pending hint、退出优先级及实际自动保存往返。全204关加非棋局模式共208布局场景；不是2889条关卡，也不把事件数重复计作断言。证据 `tests/context_help_audit/summary.json`、`behavior.json`、`layout.json`。
- 缺失/null/数字/数组/空白元数据省略已加负向断言；内置关卡数据、规则、H/J及续玩模块未改变。最终main SHA为15a68661146db4cc1e47c11ea2a60ca2be0115099d529d0e54a1b46a11a6650e，formatter SHA为0b43d5dedeffa7a305c87a897b103766097c72387ce601ba7a342488fbfd32f4；独审前后运行输入hash一致。
- 独审在最终类型守卫源码上另行真实X11高画质重拍并亲看6图：`screenshots/context_help_audit/`，包括city_04、heaven_13、city_06、confluence_01、title_generic、world_stale_level，全部1440×900。选关保留旧level对象时exercise_count仍为0，六图无裁切。证据 `tests/context_help_audit/native_manifest.json`；保留作者首版4图但不混称最终hash截图。
- 本阶段最终源码另行新跑全204关真实处理器：7852检查、204完成、0失败、退出0，无ERROR/WARNING/泄漏；全部运行源码、关卡与project前后SHA一致。证据 `tests/results/context_help_handlers.json`、`.log`，JSON含源指纹。该回归带混音、QA关闭续玩sidecar，因此证明原玩法无回归，不能替代续玩/帮助生命周期专项；不是复用上一阶段7852。Linux/X11与当前1440×900目标以外的平台、Retina、小窗口尚未验证。
- 额外原生窗口输入探针：WASD A产生真实physical_keycode=65，跨关闭帮助按住1273ms、21个held/guard/moves=0采样；释放后新a只走1步。独立证据 `tests/context_help_audit/native_hold_wasd.json`。原生Left由CUA产生physical_keycode=0，不能据此验证原生箭头held状态；两次探针无echo，不声称OS自动重复已测。方向键与echo覆盖来自上面的Input.parse_input_event行为测试，不能混称原生硬件验收；此额外探针不重复计入2889断言。

## 完成态协调：最终增量验证
- 首版编辑器导入无ERROR。作者实际Input.parse_input_event小回归14检查通过：首次赢局tween未结束时同帧R→Z恢复并真正登记、已登记胜局R→Z、F1→Esc恢复Next、状态/历史/进度不变、未赢/非关卡呈现守卫，以及主动Esc收起后普通行走不重弹（显式Undo恢复胜局仍重开）。证据 `tests/completion_reconcile.gd`、`tests/results/completion_reconcile.log`。
- 原全量harness中undo后手动调用complete_level的修补已删除，改为断言undo实际handler已经协调；未用测试代码代替游戏修复。最终候选main b529ffb5版本新全量真实处理器已完成：8056检查、204关、0失败、退出0，日志无ERROR/WARNING/泄漏，全部运行源前后SHA一致。较前阶段多204个真实协调断言；证据 `tests/results/completion_state_handlers.json`、`.log`。带混音、QA关闭续玩sidecar，因此不替代续玩功能测试。独立副作用/恢复边界及图形审查结果如下。

- 最终独审：298完成专项＋193帮助行为＋2696布局＝3187断言，0失败；920个引擎键事件、12个完成专项鼠标事件（不重复计入断言），全204关加非棋局共208布局状态。证据 `tests/completion_reconcile_audit/REPORT.md`、`FINAL_SUMMARY.json`、各分项JSON/日志；源码前后锁定main b529ffb595d043cf74216a3f603efe20bc0ba69572b8d70d432bbdfe6a9a586e。
- 独审确认：首次pending赢局R→Z登记一次；已记胜局恢复、帮助重开无额外save调用/win声音/celebrate动画；真实更优重玩仍更新best；直接Esc后普通走动不重弹；提前关闭help后旧tween不重换面板；末关回中庭、真实resume磁盘往返、退出返回均通过。保存spy统计实际handler调用，但QA不写主进度；这不冒充多平台磁盘写入测量。
- 最终真实X11高画质1440×900四图已独立亲看无裁切：`screenshots/completion_reconcile_audit/` 下 pending_win_reset_undo、help_returns_next、dismissed_result_exploration、final_world_help_returns_hub。输入为真实图形窗口内Input.parse_input_event，不宣称硬件键盘操作；像素查看与capture成功分开记在visual_review及FINAL_SUMMARY。
- 本阶段最终源码字体扫描仍为532汉字＋7符号，missing=[]，见 `tests/results/completion_state_font.log`。Mac/Retina、小窗口与普通全通庆典帮助返回未在此阶段扩展验证。

## 蟠桃园三树花冠：生产合入有界验证
- 五文件允许清单已合入；main仍b529ffb5、world_view及关卡等运行输入未改。生产编辑器导入、30帧QA启动均exit0；204关相机/HUD审计0裁切；62模型/6Blend源审计errors=[]。import/boot/camera日志无ERROR/WARNING/泄漏。证据 `tests/results/orchard_canopy_{integration.json,import.log,boot.log,camera.log,assets.log}`。这是艺术替换回归，不冒称重新执行8056条玩法检查。
- 隔离最终字节已独立亲看8张Godot 4.7.2、X11、1440×900第3/10/45关与中庭高/低图及2张Blender预览。明确淘汰过初稿深色花冠衬底；最终通过版本局部修几何/材质，没有改全局光照或关闭阴影。历史审查原文/指纹保留在 `tests/orchard_canopy/INDEPENDENT_VISUAL_REVIEW.md` 与对应manifest，不改成新执行时间。
- 三树三角形30184/41204/15412，均12材质网格、AABB在旧包络内；匹配相机高/低绘制调用分别为第3关280、第10关296、第45关312、中庭531，与基线相同。几何语义比较及层级检查通过，但Blender导出SHA不保证字节级复现，使用本次构建固定SHA。
- 便携复拍/Blender预览脚本放 `tests/orchard_canopy/`；仅复制报告、脚本及约定前后PNG，不包含baseline_project、旧克隆docs、.qa_env或私人存档。shell语法与Python AST已检查；真正图形运行另列，不把语法检查当实机通过。截图位于 `screenshots/orchard_canopy/`，被拒绝的native_after未复制。
- 合入后生产main b529ffb最终实拍通过：第3/10/45关与中庭高质量，4张匹配视角＋4张真实自动取景图（native_前缀），全部1440×900/X11/llvmpipe，与已接受候选对应PNG逐字相同、行指标一致，五美术输入hash吻合且无missing assets。证据 `tests/orchard_canopy/production_verification.json`、`production_capture_manifest.json`、`production_capture.log`；图在 `screenshots/orchard_canopy/production/`。图形日志仅有驱动不支持VSync的警告，不冒称原生日志零警告；音频Dummy，仅图形检查，不声称试听或硬件键盘验收。
- Git二进制限制仍存在；纯源码提交不代表新模型已在远程，完整ZIP由主任务另行核实交付。

## 地牢障碍墙 C0.80：最终生产有界验证
- 仅五文件（两墙GLB、Blend、生成脚本、统计JSON）合入；main仍b529ffb，桃冠等其它60GLB及运行逻辑不变。生产导入、30帧QA启动、204关相机/HUD审计0裁切、62模型/6Blend源审计均exit0；import/boot/camera无ERROR/WARNING/泄漏。证据 `tests/results/inferno_wall_{integration.json,import.log,boot.log,camera.log,assets.log}`。
- 新全204真实handler回归8056检查、0失败、completed204、exit0；74个运行/关卡/全部模型SHA前后一致，无ERROR/WARNING/泄漏。证据 `tests/results/inferno_wall_handlers.json`、`.log`。这是当前新模型实跑，不借用前阶段8056；带混音但QA关闭续玩sidecar，不代替存档功能专项。
- 最终C0.80独审六张1440×900/X11第10/23/45关高低图通过，冻结54文件及16张前后图片hash已核对。生产另拍三张高图，逐字等于已接受候选、行指标一致，89保护文件前后不变；独立生产补记重查5输入、3PNG、89文件及root执行的8056证据。报告在`tests/inferno_wall/INDEPENDENT_*`，生产元数据在`production_native/`；图片在`screenshots/inferno_wall/`。原生仅既有llvmpipe VSync警告，不声称图形日志零警告。
- 两墙三角形940→552、3884→3496，材质批次保持2/4；高度有意0.63→0.80，水平包络不变。B0.88因核心金环遮挡拒绝；接受C0.80定位齿局部遮挡这一明确取舍，而非偷偷放宽后仍称零遮挡。
- 51地牢皮肤关卡、1070合法中心（908邻墙）、86580金环表面点、910350初始泉涡表面点命中0。定位齿原711/A414/C80 4119，C新增3408（顶95、上斜1991、侧下1322）；是有限非面积归一样本，不是像素面积。全表面测试仍失败；保守全旋转最低高度盘另测73440点0命中也不是完整动画像素保证。
- 集成适配portable auditor已在生产实跑通过接受门槛，明确输出`zero_occlusion:false`、`decorative_tooth_hits:4119`；证据 `tests/results/inferno_wall_portable_validation.json/.log`。只加图片分包路径与显式输出参数，原54文件manifest与失败原始报告保留不篡改。
- 未复制旧工程、缓存、.qa_env、用户存档/锁或.blend1。脚本源与可编辑Blend保留，GLB逐构建hash固定，不承诺Blender导出字节可复现。Linux/X11结果不证明macOS/Retina；截图与QA输入不冒充人工解题。Git二进制限制仍在，旧已发桃冠包保持历史不改，新资源包由主任务另行验证发布。

- 打包前发现旧A候选delivery_manifest被误放入证据根目录，已原样移至 `tests/inferno_wall/historical/A063_delivery_manifest.json`并加历史标签；不删除原始记录，也不当当前权威。当前核心清单仅FINAL_C80（fc31becb…），生产补记和实拍指纹保持不变。未发现混入旧validation_summary.json。此为文档/包清单修正，不改变任何模型或测试运行源。

## 菜单/弹窗键盘导航：本地生产新阶段
- 本地main已选择性整合为50ff777465b3b9320ca8fde967c264e6b2f733bbda3447bce80aed79b07bb4b8，其余95保护输入检查仅main变化，地牢墙/桃冠/关卡不变。生产导入与30帧QA启动exit0，无ERROR/WARNING/泄漏，证据`tests/results/keyboard_navigation_{integration.json,import.log,boot.log}`。Git仍最后核实51e68且create_tree审批未完，不声称已发布到main。
- 新生产全204真实handler回归8056检查、0失败、completed204、exit0；74运行/关卡/全部模型SHA稳定，无ERROR/WARNING/泄漏。证据`tests/results/keyboard_navigation_handlers.json/.log`。带混音、QA续玩sidecar关闭，不替代存档专项，也不是复用键盘候选或前阶段8056。
- 生产便携作者事件套件新跑637/637，exit0且main前后SHA吻合：363菜单/焦点、245方向释放转场、17鼠标/竞争、两个独立退出进程各6。结果在`tests/keyboard_navigation/production_results/`，与作者候选637分别记，不累计为1274。
- 最终候选作者回归原证据按53文件SHA选择性导出`tests/keyboard_navigation/author_final/`：637键盘、8056/204、20Python、帮助2889、线索2610、续玩13114、完成14、续玩集成13、迁移保护15。迁移测试有故意注入的归档复制ERROR，必须单列，不泛称所有负向日志零ERROR。原16张5a作者截图不是最终50ff截图。
- 独立最终293＝237核心＋12终止进程＋44失效/释放fallback；通过范围包括原生Button事件、异步/失效Continue、作用域与重复激活、安全退出。原报告和93文件导出清单在`tests/keyboard_navigation_audit/`，旧5a证据明确historical不改标。最终CUA/Sky生成的X11键盘旅程不是物理键盘认证；箭头physical_keycode=0限制与引擎注入的held-key测试分开。
- 最终生产1440×900三图（标题/帮助/失败退出安全Return）已独立亲看焦点圈和文案完整，safe_return断言通过；生产图为真实X11渲染＋引擎事件注入，不称CUA手动路径。生产元数据在`tests/keyboard_navigation/production_native/`及独审补记，PNG在`screenshots/keyboard_navigation/`。图形日志保留llvmpipe不支持切换VSync的已知警告。
- 生产完整语料字体重扫534汉字＋7符号，无缺字，`tests/results/keyboard_navigation_font.log`；候选旧522因语料范围不同保留原值。未验证macOS/Retina/硬件GPU/手柄或完整无障碍认证。
- 旧帮助行为测试的普通modal“不锁存”断言被获批的全菜单/modal释放契约替代；原脚本存historical，旧已发布测试日志/JSON不覆盖。运行器支持独立输出/XDG；不复制clone/assets/.godot/qa整目录或私人存档。
- 独审驱动仅extends/output/runner路径适配后，另在实际生产50ff新跑293/293、exit0、75源码/模型/关卡hash不变、无warning/error；证据`tests/keyboard_navigation_audit/portable_smoke_results_final/ADAPTED_SMOKE_SUMMARY.json`。这次是适配烟测，不累计成586独立检查，也不覆盖原冻结293。portable桌面observer只做路径适配，未重跑GUI；生产图形证据仍来自上面明确列明的三图与原CUA旅程。
