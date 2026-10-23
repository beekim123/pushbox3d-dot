# 仓库迁入状态 · 桃冠源码与整合证据检查点

**V2 WIP；本提交不是完整可运行发行包，也不表示美术已获用户验收。**

- 已保存：204关旅程、教学文案修正、自动构图/日光、真实新档解锁、可选三级提示，以及已恢复并重新验证的生产续玩。
- 续玩新独审：13,164检查 = 13,114 headless + 50原生、12进程；独立可移植runner另跑13,114通过，不重复计入。见 `tests/resume_ui_audit/REPORT.md`。
- 原玩法新回归：完整本地工程带音频204关，7,852检查、0失败、退出0；见 `tests/results/resume_recovered_handlers.json`。不复用13:12被中断的结果。
- WIP分支 `work/resume-rebuild` 保留源码恢复和模块测试历史；本 main 树只纳入生产清单，没有 `_wip`、私有 `_runtime` 或用户存档。
- **资源仍只有47/62 GLB、0/18 Ogg/WAV、0/6 Blender源文件**，另缺PNG截图和部分大型测试数据。部分已备份GLB来自11:35冻结，雨林铺路材质后续微调仍未迁入。
- 六张续玩原生PNG在本地已实看，但没有上传到GitHub。报告中截图路径说明的是本地测试/导出，不意味着这个checkout已经包含图片。
- 新二进制上传仍等待未解决的确认；没有换路线补传。完整本地项目的测试不能证明这个部分迁入checkout完整可运行。
- `REPOSITORY_MODEL_FILES.json`保留已备份模型Git SHA/字节数；`RESUME_SOURCE_CHECKPOINT.json`列本阶段文本冻结与包装说明。
- 云端Linux通过不等于macOS/Retina/硬件GPU或真人盲测通过；续玩磁盘历史上限8192、调度预算为软预算，详见审查报告。

历史：82e511d 核心源码，0172ede4 生成脚本，2149d944 部分模型，7ce361e4 教学文案，6c9aaed7 提示，9a8ffccc 日光，f421db6 中断记录。保留历史、不force push。


## 当前新增：F1 情境帮助（2026-10-23 15:32 UTC）

- 章练习formatter与帮助关闭释放键guard已通过专项审查：2,889断言、另计352事件；本阶段重新跑204关7,852处理器检查，0失败/exit0。
- 原生WASD持有与6图像素查看结果已保存文本；physical-arrow/OS autorepeat限制详见 `tests/context_help_audit/REPORT.md`，图片仍未入库。
- 运行源和证据冻结清单见 `CONTEXT_HELP_SOURCE_CHECKPOINT.json`；完整原始布局与原生输入文本记录已保存。
- 上方47/62、0/18、0/6的远程资源缺口仍未解决。新14:57续玩完整包是独立恢复档，不代表GitHub补齐资产，也不含本阶段F1。


## 当前新增：完成态呈现修复（2026-10-23 15:55 UTC）

- 完成登记与呈现分离；Undo胜局恢复、帮助/退出返回协调，不重复反馈或成绩登记，常规移动不重开Esc已关闭面板。运行仅main.gd变化。
- 独审3,187断言、另计920键＋12鼠标事件，4图本地查看；新全204处理器8,056/0、exit0，源hash稳定。证据 `tests/completion_reconcile_audit/` 与 `tests/results/completion_state_handlers.json`。
- 前述47/62、0/18、0/6缺口未变，PNG未上传。完整续玩归档不含此修复；本提交仍不能当作完整可运行发行包。
- 生产清单/包装说明见 `COMPLETION_SOURCE_CHECKPOINT.json`；保留独立WIP和所有前阶段证据，不把旧报告覆盖成新结果。


## 桃冠源码与本地整合证据 — 2026-10-23 16:36 UTC

- main 仅更新生成器、文档与精简测试证据；生成器 SHA256 为 `4077183a1854e81c594557adc6938baecb97c97de1fc9d523ef458a6a0dc9c11`。运行脚本、关卡、场景与所有远端二进制保持前一提交字节。
- 本地五文件整合已核验；204 相机构图 0 裁切、62 模型检查通过。生产复拍为 4 个高画质案例、共 8 PNG，与候选逐字节一致；候选另有高/低画质 8 案例。没有另报本阶段新的全玩法回归、生产低画质或性能通过。
- 内部独立像素审查不等于用户审美验收。导出排序不保证字节重现；语义几何核验与固定交付文件哈希见 `tests/orchard_canopy/`。日志保留同环境 VSync 限制警告。
- 远端仍为 47/62 GLB、0/18 音频、0/6 Blender 源文件；三种新桃树 GLB、对应 .blend 与本阶段 PNG 均未上传。旧 GLB 没有被文本声明替代。查看新美术需后续完整阶段包或完整资源基线上的本地重建，不能把此 checkout 当完整新版本。
- 14:57 续玩归档不含后续 F1、完成态修复或本桃冠阶段；新完整包尚待发布，本文不宣称已经交付。早期 pending 记录保留时序，后续 `production_verification.json` 与独审补记记录其闭环。
- WIP 历史保留在 `work/orchard-canopy` 的 `00ffdf6e9e3304ca9106c3b56e474b95cc88b5aa`；生产树不含原型副本。冻结与包装差异见 `docs/ORCHARD_SOURCE_CHECKPOINT.json`。

