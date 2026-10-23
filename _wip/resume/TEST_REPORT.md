# 故障后重新验证记录

**真实新运行时间：2026-10-23 14:19:49–14:19:54 UTC。** 旧工作区的源码、日志曾丢失；当前两个模块从线程保留的完整原文逐字恢复并实际核对 SHA，测试脚本重新构建、全部重新执行。相同断言数是重跑结果，不是复用旧数字。

- Codec 原冻结与本次 SHA：`5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305`
- Store 原冻结与本次 SHA：`c3840e3fabd873c6fc0dcfb494252bdb0f5fa6331951e9c0afed4f11e8828566`
- 引擎：Godot 4.7.2.stable.official.ed1daf0bf；完整 binary hash / 命令 / 输入哈希在 `results/fresh_run_manifest.json`。
- fixture 使用最新 204 关文本修订 `levels.json`，SHA `3658774f0015b859ff27e13b0ef48c6e5071df921d0d155be797565de302fcda`，不是旧快照 8b2409…。几何、规则、ID 未改。

| 本轮套件 | 新断言 | 结果 |
|---|---:|---|
| Codec | 7098 | 204 关 × 中途/通关/重置 = 612 次精确 state/history 往返；全部撤销回初始，非法/未来/坏数据、revision/旧请求、校验与真实 replay 拒绝路径通过 |
| Store | 82 | 未验证/坏/未来原字节保护，磁盘变化、rename 失败、未知 pending/lock、路径别名、progress 哨兵保持通过 |
| Limits | 14 | 8192 真正合法动作完整恢复，Undo 200 后 Reset 当前链7993；8193拒绝不截断本局栈，通过 |
| 真正独立进程写入/恢复 | 47 + 127 | PID56 / PID70，5类关卡 × 动画逻辑终点/通关/重置15样例，精确完整undo与progress哨兵通过 |
| **总计** | **7368** | **0失败，source前后哈希一致** |

日志无 SCRIPT ERROR / ERROR。故意 INF/NaN 用例会产生 Godot 数值/JSON 警告，数据仍被保护性拒绝。重新签名用例先规范化解析所得整数浮点，并断言 unknown_action / illegal_replayed_action / final_state_mismatch 的具体 reason，避免仅在 checksum 阶段失败造成虚假 replay 覆盖。

## 本轮性能观察（不是保证）

- Campaign 样例最长76条、最大424字节；encode总计算最大5.161ms、decode4.727ms；最大切片约2.443/3.452ms。76只是测试样本观测，不是游戏历史上限。
- 8192动作：8533字节。编码139.515ms分70帧、解码59.884ms分28帧；公开step最大2.118/3.775ms。
- 取消完整未领取恢复结果仍有真实同步析构成本：本轮7.181ms，不受2ms step预算约束。不能因比故障前观察快而宣称已根治或硬实时。

## 范围与剩余项

这是 adapter 的重新验收，不是生产 UI/scene handler 的集成验收。生产恢复控制器由 runtime 另行开发/测试；独立重建审查位于兄弟目录 `fourfold_next/resume_audit_rebuild/`，其真实新运行报告单独提供。本作者套件不冒领旧46619独立断言或SIGKILL/真实同时写者结果。

未修改生产或 Git，文件测试只使用独立 `/tmp` XDG。没有云存档、自动删坏档/锁、反恶意文件系统隔离或硬断电保证。完整接口、只保存已提交逻辑状态、节流/失败提示/退出等候和所有权契约见 README。

## 最小 fixture 与重新执行

为使纯文本远端备份可独立复现，`tests/derive_solutions.py` 从完整报告提取全部204条id/solution（保序，不改变任何路线），生成12,266字节的 `snapshot/resume_solutions.json`。完整原报告SHA为 `8aca00614377e857023e16db0949b164b5e9087e960e028e377561dcc6f1279b`；小fixture SHA为 `0f80ca6c52e42e52de917dfdaab30cd51a2c7dd97617ff7bd057ac58001be986`，来源在 `snapshot/solutions_provenance.json`。

测试改读小fixture后，已经在上方14:19时间窗口真实重跑并更新所有脚本指纹，仍7368/0。14:12使用完整报告的上一轮证据仅归档到 `results/history_141247/`，不是当前manifest。正常测试只需要小fixture，不依赖未备份的1.68MB full report；本地reference/原报告仅供追溯重新派生。
