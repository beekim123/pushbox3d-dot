# 安全续玩原型：故障后恢复版

这是独立原型目录，不是生产 UI 已完成的声明。**两个模块从本线程保留的完整源码逐字恢复，SHA-256 与故障前冻结值精确一致**；测试、报告和本说明重新构建，不能称作原文件的逐字备份。

| 模块 | 原始值及本次实际 SHA-256 |
|---|---|
| `resume_codec.gd` | `5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305` |
| `resume_store.gd` | `c3840e3fabd873c6fc0dcfb494252bdb0f5fa6331951e9c0afed4f11e8828566` |

## 数据契约

- 永久进度文件 `fourfold_progress.json` 与可选续玩 **sidecar 分离**；两个模块从不读写、降级或迁移永久进度。保留现有 V1→V2 archive / 未知未来进度只读规则。
- 从关卡初始状态完整重放当前幸存撤销链，动作 `U/D/L/R` 加 `X=Reset`。每个重置也保存前态，因此可以精确撤销重置。Undo 从当前链删边，不记录无限增长的输入事件日志。
- 保留玩家、有序箱子、moves/pushes 和完整撤销历史；route 等规则瞬态字段由实际 `PuzzleRules` 重建。编码只浅拷贝 history Array：**已入栈 Dictionary、关卡目录必须不可变**；任何成功移动、撤销、重置、换关都递增调用者 revision。
- 只在关卡指纹、规范 JSON、checksum、完整合法重放、最终状态全部一致后公开 `state/history`；没有部分恢复。坏档、未来档、未知关卡、改变的规则/地图、越界/重叠/非法推动，均保护性拒绝，不授权覆盖原文件。
- 保存“当前完整撤销栈”上限 **8192 条**，文件 65536 字节；超限或验证预算耗尽不截断、不改本局 undo、不阻止继续玩，**不覆盖上次有效 checkpoint**。界面须明确“本次未保存，保留上次已保存局面”。正常 in-session 撤销没有人为新增此上限。
- 关卡最多 256 格、单边 32、8 箱；目录最多 512 项；地形列表也有界并拒绝重复；JSON 深度先限制到 8，再调用解析器。
- 指纹包括 ID、尺寸、初始玩家/有序箱子、墙/目标/机制，忽略美术名字/教学文案。`RULESET` 是语义版本约定：改变规则行为时必须升级它，不要把几何指纹当作源码哈希。
- checksum 是规范 payload 的 SHA-256；磁盘 token 是 `bytes.hex_encode().sha256_text()`，不是原始字节 SHA。它们是完整性校验，**不是反作弊认证**；完全合法且重算校验的另一条历史可通过。

## API

```gdscript
var codec = ResumeCodec.new(RULES) # 注入真正的生产规则 Script
var request = codec.begin_encode(level, state, history, logical_revision)
var status = codec.step_budget(2.0, request, logical_revision) # 每帧调用
if status.status == "encoded":
    var encoded = codec.take_result(request, logical_revision) # 一次性所有权转移
```

- `begin_encode(level,state,history,revision,max_validation_ms=5000)` / `begin_decode(bytes,catalog_by_id,max_validation_ms=5000)` 返回请求 ID。
- `step_budget(ms=2,expected_request=-1,current_revision=-1)`、`poll()` 只返回轻量状态；旧 ID 不推进替代任务。编码始终传最新 revision。
- `take_result(id,revision)` 只转移一次完整结果，不逐帧深拷贝大历史。`cancel()` 使 ID 无效。调用者不能拿旧 revision 的完成结果提交磁盘。
- 编码成功 `encoded` 含 `bytes/blob_token/source_revision/level_id/won/history_count`；恢复成功 `restored` 含 `state/history/level_id/won/input_token/validated_format/version`。
- 非成功包括 `protected, invalid, history_limit, budget_exhausted, stale, cancelled`。**预算耗尽不是损坏证明**，无权覆盖原文件。

```gdscript
var store = ResumeStore.new("user://fourfold_resume") # 必须独立 user 子目录
var inspected = store.inspect()
if inspected.status == "read":
    var id = codec.begin_decode(inspected.bytes, catalog)
    # 分帧完成并领取 restored 后：
    store.accept_verified_load(restored)
# missing 可以创建；现存文件必须经完整验证才能替换。
var saved = store.commit(encoded, latest_revision)
```

Store 对现存字节默认只读。授权必须来自同一 token 的完整 codec 恢复结果；内部 Dictionary 视作可信程序能力，绝不能把任意外部 JSON 冒充已验证结果。提交检查 revision、bytes token、磁盘是否变化，再通过合作式原子 mkdir 锁、同目录 pending 写后读验、**单次 rename**替换。没有先删旧文件的分支。

`not_saved` 会返回 `old_file_preserved=true, keep_current_game=true`；`fresh_level_on_load_only` 仅适用于加载失败，**保存失败不能清空当前游戏**。未知 lock/pending 不删、不覆盖、不自动提升为正式存档；可加载现存完整主文件，但新保存保守拒绝。

## 生命周期整合契约

1. 先正常加载进度，再读取 sidecar。恢复采用显式等候流程，分帧验证时不接受会与恢复竞争的逻辑操作；用户放弃则取消一次并丢弃旧 ID。
2. 成功后创建已验证的关卡场景，再赋 `state/history`，避免后续 start_level 清栈。同步棋盘到逻辑终点，清 tween、moving、pending_direction、hold_timer；**不恢复动画或缓存按键**。
3. 当前生产的逻辑 move 在 tween 前已提交，所以动画中也可保存终点。保留当前已通关局面及全部 undo；由验证结果计算 `won`，通过现有幂等 `complete_level()` 对账进度并尊重 `progress_writable`，不能从 sidecar 直接赋 progress。历史里曾经通关不自动重放为奖励。
4. 每次逻辑改变递增 revision；运行中的验证取消一次即可，不需要每个按键反复析构完整结果。停手节流后再编码，完成时用最新 revision 再核验提交。碰墙不改逻辑状态。
5. 选关/回菜单不能抢先让仍未提交的最新棋局消失：应有明确保留当前 checkpoint 候选或完成保存的 controller 策略。这个低层 adapter 不拥有场景生命周期。
6. 退出先停止新输入、保留已提交 state，再在可见等待流程中尽量保存。wall-clock 等待上限、存储/验证上限或文件保护失败时明确“最后一次局面未保存，仍保留上次记录”，允许确认退出/返回重试；不能在 `_exit_tree` 里期待异步完成，不能只用关闭前一闪而过的成功提示。
7. 模块没有持久化 dirty/失效 marker：失败刻意保留旧 checkpoint。UI 应说“上次已保存局面”，不保证强杀或断电前最后一个按键已提交。
8. 若复制到生产 `scripts/resume/`，调整 store 中 Codec preload 绝对路径，并针对实际 controller 重跑自动保存、菜单、退出、恢复失败、progress 只读和真实 reset/undo handler 测试。原型测试不是生产集成验收。

## 软预算与文件系统限制

`step_budget` 不是硬实时期限：单个规则 step、JSON 解析/序列化、容器扩缩、入口归一化、文件 flush/rename、取消或替换大结果的同步析构都不能中途抢占。故障前观察过 8192-history 未领取结果取消约 11–34 ms、个别解码调用约 75 ms；原始旧日志已丢失，只能标作历史观察，**不算新验证证据**。本轮实际值见 TEST_REPORT / results，较快一轮不意味着根治此成本。当前 campaign 样例最长 76 条，只是样本，不是游戏历史上限。

使用显式恢复/退出等候与节流，而非宣称所有操作都 2 ms。所有写者须遵守同一锁；不保证恶意非合作进程、符号链接/FIFO 攻击隔离、非 Linux 平台或硬断电 durable-fsync。异常后遗留锁有意阻止替换，自动恢复/删锁策略不在模块中。

## 本轮验证

```bash
python tests/run_tests.py
```

固定 Godot 4.7.2，独立 `/tmp` XDG，不接触真实玩家 userdata。`results/fresh_run_manifest.json` 保存本轮真实起止时间、命令、引擎哈希、source/test/fixture 哈希与前后一致性。测试 fixture 的 `levels.json` 为最新教学文案修订 SHA `3658774f0015b859ff27e13b0ef48c6e5071df921d0d155be797565de302fcda`；规则 SHA `260130edbe5978fc610a5e8fcc2f84ff19e8fc8beb16d3a2971790f1cc68df64`。这是新运行，不复用旧 7368/46619 报告。

### 可独立复现的小夹具

测试仅读取 `snapshot/resume_solutions.json` 中204条id/solution；它由 `tests/derive_solutions.py` 从完整solver_report保序提取。`snapshot/solutions_provenance.json` 保留完整来源SHA、派生SHA、条数与字节数。完整1.68MB报告不需要放进原型备份；正常执行 `tests/run_tests.py` 只需当前小fixture。改用小fixture后已在14:19:49–14:19:54 UTC重新执行所有测试与hash-lock，当前manifest是该新运行。
