extends SceneTree
const Rules=preload("res://scripts/puzzle_rules.gd")
const Spy=preload("res://tests/completion_reconcile_audit/spy.gd")
var game
var checks:=0
var failures: Array=[]
var observations: Array=[]
var key_events:=0
var mouse_events:=0
var celebrations:=0
var solutions: Dictionary
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);print("COMPLETION_AUDIT_FAIL ",label)
func key(code: Key,pressed: bool):
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed
 key_events+=1;Input.parse_input_event(e)
func tap(code: Key):key(code,true);key(code,false)
func effect_counts() -> Dictionary:
 return {"save_calls":game.audit_save_calls,"win_sfx_calls":game.audit_sfx.count("win"),"celebrate_starts":celebrations}
func board() -> Dictionary:return {"state":game.state.duplicate(true),"history":game.history.duplicate(true),"progress":game.progress.duplicate(true)}
func has_button(text: String) -> bool:return game.ui.find_children("*","Button",true,false).any(func(b):return b.text==text)
func has_result() -> bool:
 return is_instance_valid(game.modal) and game.modal.find_children("*","Label",true,false).any(func(l):return l.text=="线头接上了")
func counts_same(before: Dictionary,label: String):check(effect_counts()==before,label)
func entry(id: String) -> Dictionary:
 for item in game.levels:
  if item.id==id:return item
 return {}
func track_animation():
 check(game.world.animation!=null,"real player animation exists")
 game.world.animation.animation_started.connect(func(name):
  if str(name).to_lower().ends_with("celebrate"):celebrations+=1
 )
func clean(id: String,fresh: bool=false):
 for code in game.DIRECTION_KEYS:key(code,false)
 game.require_direction_release=false
 if fresh:game.progress={"version":2,"solved":[],"best":{},"muted":false}
 game.start_level(entry(id));track_animation();await process_frame
func wait_motion():
 var started:=Time.get_ticks_msec()
 while game.moving and Time.get_ticks_msec()-started<4000:await process_frame
 check(not game.moving,"real tween completed within observation window")
func walk(direction: String):
 tap({"U":KEY_UP,"D":KEY_DOWN,"L":KEY_LEFT,"R":KEY_RIGHT}[direction]);await wait_motion()
func solve(id: String,fresh: bool=false):
 await clean(id,fresh)
 for direction in solutions.levels.filter(func(l):return l.id==id)[0].solution:await walk(direction)
 check(Rules.won(game.level,game.state) and has_result() and game.win_shown,"real solution produces completion "+id)
func click(text: String):
 var nodes=game.ui.find_children("*","Button",true,false).filter(func(b):return b.text==text)
 check(nodes.size()==1,"unique pointer target "+text)
 if nodes.size()!=1:return
 var point=nodes[0].get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);mouse_events+=1
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
  Input.parse_input_event(e);mouse_events+=1;await process_frame
func help():
 tap(KEY_F1);await process_frame
 check(game.modal!=null and game.modal.get_meta("contextual_help",false),"actual F1 opens help")
func settle_resume():
 var started:=Time.get_ticks_msec()
 while (game.resume_session.dirty or game.resume_session.reading) and Time.get_ticks_msec()-started<6000:await process_frame
 check(not game.resume_session.dirty and not game.resume_session.reading,"isolated resume settles")
func run():
 root.size=Vector2i(1440,900);Engine.max_fps=240;Engine.time_scale=4.0;Input.use_accumulated_input=false
 solutions=JSON.parse_string(FileAccess.get_file_as_string("res://tests/solver_report.json"))
 game=load("res://scenes/main.tscn").instantiate();game.set_script(Spy);root.add_child(game);await process_frame
 check(game.qa_mode,"QA enabled before instrumentation and isolated saves")
 await clean("heaven_01",true)
 var before_counts=effect_counts()
 tap(KEY_RIGHT);var won=board()
 check(game.moving and Rules.won(game.level,game.state) and not game.win_shown,"first solved endpoint committed before tween callback")
 tap(KEY_R);tap(KEY_Z)
 check(game.state==won.state and game.history==won.history,"same-frame reset undo restores exact endpoint and history")
 check(has_result() and game.win_shown,"undo handler immediately restores completion actions")
 check(game.progress.solved==["heaven_01"] and game.progress.best.heaven_01=={"moves":1,"pushes":1},"pending first win is registered exactly")
 check(effect_counts()=={"save_calls":before_counts.save_calls+1,"win_sfx_calls":before_counts.win_sfx_calls+1,"celebrate_starts":before_counts.celebrate_starts+1},"pending first win saves and celebrates once")
 before_counts=effect_counts();await create_timer(.4).timeout
 counts_same(before_counts,"cancelled original winning tween cannot duplicate side effects")
 check(not game.moving and game.pending_direction=="","reset-undo leaves no old tween or buffer")
 var solved_board=board()
 for i in range(3):
  tap(KEY_R);check(game.modal==null and not Rules.won(game.level,game.state),"reset from completion remains unsolved and dismisses")
  tap(KEY_Z);check(has_result() and board()==solved_board,"undo-reset immediately restores complete original board/history/progress")
  counts_same(before_counts,"recorded undo-reset has no duplicate win audio/celebration/save")
 check(game.audit_sfx.count("reset")==4 and game.audit_sfx.count("undo")==4,"normal reset/undo sounds still invoked once each")
 for close_method in ["esc","pointer"]:
  await help();await help();var before=board()
  if close_method=="esc":tap(KEY_ESCAPE)
  else:await click("明白了")
  check(has_result() and board()==before,"repeated F1 returns result unchanged via "+close_method)
  counts_same(before_counts,"help-only restoration has no completion side effects "+close_method)
 # Esc remains an intentional escape route for completed-board inspection.
 tap(KEY_ESCAPE);check(game.modal==null,"direct Esc dismisses completion")
 for direction in ["L","U","D"]:
  await walk(direction)
  check(Rules.won(game.level,game.state) and game.modal==null,"ordinary solved-board walk does not reopen dismissed result "+direction)
  counts_same(before_counts,"worse solved-board walk does not rewrite record or celebrate")
 await help();tap(KEY_ESCAPE)
 check(has_result() and game.state.moves==4 and game.progress.best.heaven_01.moves==1,"explicit help restores current result without worsening best")
 counts_same(before_counts,"explicit result return remains presentation-only")
 await process_frame;await click("前往下一道谜题  →")
 check(game.level.id=="heaven_02" and game.modal==null and not game.win_shown,"real Next pointer starts correct next puzzle cleanly")
 # Fresh genuine replay still provides normal feedback, whether best changes or not.
 await clean("heaven_01",true)
 await walk("U");await walk("D");await walk("R")
 check(game.progress.best.heaven_01=={"moves":3,"pushes":1},"real detour establishes worse initial best")
 before_counts=effect_counts();tap(KEY_R);await walk("R")
 check(game.progress.best.heaven_01=={"moves":1,"pushes":1},"already solved ID can improve best via real replay")
 check(game.audit_save_calls==before_counts.save_calls+1 and game.audit_sfx.count("win")==before_counts.win_sfx_calls+1,"better replay saves and celebrates once")
 before_counts=effect_counts();tap(KEY_Z)
 check(game.modal==null and not Rules.won(game.level,game.state) and not game.win_shown,"undo actual winning push returns unsolved playable board")
 await walk("R")
 check(has_result() and game.audit_save_calls==before_counts.save_calls and game.audit_sfx.count("win")==before_counts.win_sfx_calls+1,"equal-score real re-win celebrates without redundant best write")
 # Help may close while first logical win tween still runs; preserve it, no second UI replacement.
 for close_result_early in [false,true]:
  await clean("heaven_01",true);before_counts=effect_counts();tap(KEY_RIGHT);tap(KEY_LEFT)
  check(game.pending_direction=="L","actual move buffer exists before F1")
  tap(KEY_F1);tap(KEY_ESCAPE)
  check(game.moving and has_result() and game.pending_direction=="","early help close preserves tween but clears old buffer")
  var modal_id: int=game.modal.get_instance_id()
  if close_result_early:tap(KEY_ESCAPE)
  await wait_motion()
  check((game.modal==null) if close_result_early else (has_result() and game.modal.get_instance_id()==modal_id),"original tween does not resurrect/replace already-presented result")
  check(game.state.moves==1 and game.audit_save_calls==before_counts.save_calls+1 and game.audit_sfx.count("win")==before_counts.win_sfx_calls+1,"early help reconciliation records one endpoint once")
 # Held old keys remain blocked even after returning through result then dismissing it.
 for pair in [[KEY_UP,"U"],[KEY_DOWN,"D"],[KEY_LEFT,"L"],[KEY_RIGHT,"R"],[KEY_W,"U"],[KEY_A,"L"],[KEY_S,"D"],[KEY_D,"R"]]:
  await solve("heaven_01");await help();var before=board();key(pair[0],true);tap(KEY_ESCAPE)
  check(has_result() and game.help_release_keys.has(pair[0]),"help result return keeps held physical guard "+str(pair[0]))
  tap(KEY_ESCAPE);await create_timer(.3).timeout
  check(game.modal==null and board()==before,"held key cannot leak after result dismissal "+str(pair[0]))
  var expected=Rules.step(game.level,game.state,pair[1]);check(not expected.is_empty(),"same-frame key fixture is legal")
  key(pair[0],false);key(pair[0],true);key(pair[0],false)
  check(game.state==expected,"same-frame release/repress works after help-result chain "+str(pair[0]))
  await wait_motion();check(game.modal==null,"released fresh movement respects dismissed result")
 # R/Z during help are deliberate actions, not requests to restore obsolete result.
 await solve("heaven_01");await help();tap(KEY_Z)
 check(game.modal==null and not Rules.won(game.level,game.state),"Z under victory help undoes winning move without stale result")
 await walk("R");await help();tap(KEY_R)
 check(game.modal==null and not Rules.won(game.level,game.state),"R under victory help resets without stale result")
 await help();tap(KEY_Z)
 check(has_result() and Rules.won(game.level,game.state),"Z undo-reset under help deliberately restores result for solved state")
 for destination in ["world","hub","title","other_level"]:
  await help()
  if destination=="world":game.show_world_menu("city",0)
  elif destination=="hub":game.show_hub()
  elif destination=="title":game.show_title()
  else:game.start_level(entry("heaven_03"))
  game.dismiss_help();check(game.modal==null,"old help callback cannot recreate result after "+destination)
  await help();tap(KEY_ESCAPE)
  check(game.modal==null,"current help cannot leak cached solved level in "+destination)
  await solve("heaven_01")
 # World and bonus final actions use actual authored solution playback.
 for id in ["heaven_50","confluence_04"]:
  await solve(id);var before=board();before_counts=effect_counts();await help();tap(KEY_ESCAPE)
  check(has_result() and has_button("把线带回中庭  →") and not has_button("前往下一道谜题  →"),"final world/bonus restores Hub rather than out-of-range Next "+id)
  check(board()==before,"final help preserves state/history/progress "+id);counts_same(before_counts,"final help has no completion effects "+id)
  await process_frame;await click("把线带回中庭  →")
  check(game.mode=="hub","real final return pointer reaches hub "+id)
 # Real isolated resume controller: save/restore recorded solved board silently.
 await solve("heaven_01",true)
 var directory="user://completion_audit_"+str(Time.get_ticks_usec())
 game.initialize_resume(directory);game.resume_session.debounce_ms=0;game.resume_session.interval_ms=0;game.mark_resume_changed()
 before_counts=effect_counts();var before=board();var revision=game.resume_session.revision
 await help();await settle_resume();tap(KEY_ESCAPE)
 check(has_result() and board()==before and game.resume_session.revision==revision,"dirty solved autosave completes through help without UI revision")
 counts_same(before_counts,"autosaving help does not re-award completion")
 game.initialize_resume(directory);game.show_title();await settle_resume();game.continue_checkpoint();track_animation()
 check(has_result() and board()==before,"real disk restore restores exact solved board/history and correct actions")
 counts_same(before_counts,"already recorded solved resume has no duplicate win/save")
 check(not game.resume_session.dirty,"completion UI restore does not dirty resume")
 # Failed exit return: recorded and first pending logical wins.
 for first_pending in [false,true]:
  if first_pending:
   await clean("heaven_01",true);tap(KEY_RIGHT)
  else:game.mark_resume_changed()
  game.resume_session.protect("completion_audit_failure_fixture")
  game.request_exit();game.poll_resume_exit()
  check(game.exit_waiting and game.modal!=null,"dirty failed exit has explicit decision")
  var exit_modal: int=game.modal.get_instance_id();tap(KEY_F1);game.dismiss_help()
  check(game.modal.get_instance_id()==exit_modal,"help cannot replace failed-exit decision")
  game.show_completion_panel();check(game.modal.get_instance_id()==exit_modal,"pure completion presenter cannot replace failed-exit decision")
  before_counts=effect_counts();before=board();key(KEY_A,true);game.cancel_exit();await process_frame
  check(has_result() and game.state==before.state and game.history==before.history,"cancel exit reconciles committed solved endpoint")
  if first_pending:check(game.audit_save_calls==before_counts.save_calls+1 and game.audit_sfx.count("win")==before_counts.win_sfx_calls+1,"first interrupted exit-return records and celebrates once")
  else:counts_same(before_counts,"recorded exit-return does not duplicate win/save")
  check(game.require_direction_release,"existing exit-return key-release guard retained")
  for code in game.DIRECTION_KEYS:key(code,false)
  await process_frame
 observations.append({"spy":"production scene script replaced by subclass that counts save_progress/sfx then calls super; no handler logic substituted","animation":"actual AnimationPlayer.animation_started signals","disk_scope":"real isolated resume sidecar; QA skips primary progress file writes, spy counts save invocation rather than durable commit","native":false})
 var result={"passed":failures.is_empty(),"assertions":checks,"physical_key_events":key_events,"mouse_events":mouse_events,"failures":failures,"effect_counts":effect_counts(),"observations":observations,"engine":Engine.get_version_info().string}
 var f=FileAccess.open("res://tests/completion_reconcile_audit/behavior.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));print("COMPLETION_AUDIT ",JSON.stringify(result))
 await game.finish_exit(0 if failures.is_empty() else 1)
