extends SceneTree
# Independent audit: all exercised behavior belongs to production main.gd.
const Rules=preload("res://scripts/puzzle_rules.gd")
var game
var checks:=0
var failures: Array=[]
var observations: Array=[]
var key_events:=0
const DIRECTIONS=[KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok: failures.append(label); print("CONTEXT_AUDIT_FAIL ",label)
func entry(id: String) -> Dictionary:
 for item in game.levels:
  if item.id==id:return item
 return {}
func snapshot() -> Dictionary:
 return {"state":game.state.duplicate(true),"history":game.history.duplicate(true),"progress":game.progress.duplicate(true)}
func unchanged(before: Dictionary,label: String): check(snapshot()==before,label)
func event(code: Key,pressed: bool,echo: bool=false):
 var e:=InputEventKey.new()
 e.keycode=code;e.physical_keycode=code;e.pressed=pressed;e.echo=echo
 key_events+=1
 Input.parse_input_event(e)
func tap(code: Key):
 event(code,true);event(code,false)
func release_directions():
 for code in DIRECTIONS:event(code,false)
func help_labels() -> Array:
 return game.ui.find_children("*","Label",true,false).filter(func(l):return l.get_meta("chapter_exercise",false))
func help_text() -> String:
 var labels:=help_labels()
 return labels[0].text if labels.size()==1 else ""
func wait_motion():
 var began:=Time.get_ticks_msec()
 while game.moving and Time.get_ticks_msec()-began<3000:await process_frame
 check(not game.moving,"movement tween finished within 3 s observation")
func open_help():
 tap(KEY_F1)
 await process_frame
 await process_frame
 check(game.modal!=null and game.modal.get_meta("contextual_help",false),"F1 opens real help modal")
func click_text(text: String):
 var buttons: Array=game.ui.find_children("*","Button",true,false).filter(func(b):return b.text==text)
 check(buttons.size()==1,"one real pointer target "+text)
 if buttons.size()!=1:return
 var point: Vector2=buttons[0].get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
  Input.parse_input_event(e)
  await process_frame
func clean_level(id: String):
 release_directions()
 game.close_modal()
 game.start_level(entry(id))
 await process_frame
 check(game.help_release_keys.is_empty(),"new test setup has no unreleased direction")
func run():
 root.size=Vector2i(1440,900)
 Engine.max_fps=240
 Input.use_accumulated_input=false
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 check(game.qa_mode,"QA prevents primary progress writes")
 await clean_level("heaven_13")
 var before:=snapshot()
 await click_text("帮助  F1")
 check(help_labels().size()==1 and help_text().contains("能否成为"),"real header click opens non-prescriptive stopper question")
 unchanged(before,"header help does not change board/history/progress")
 await open_help()
 check(game.ui.find_children("*","PanelContainer",true,false).filter(func(p):return p.get_parent() is CenterContainer).size()==1,"repeated F1 has one modal")
 var modal_id: int=game.modal.get_instance_id()
 event(KEY_F1,true,true);event(KEY_F1,false)
 check(game.modal.get_instance_id()==modal_id,"F1 key echo ignored")
 tap(KEY_H);tap(KEY_J)
 check(not game.hint_active and game.hint_panel==null,"H/J do not reveal or solve underneath help")
 await click_text("明白了")
 check(game.modal==null and game.mode=="level","pointer close leaves player in level")
 unchanged(before,"repeat open/close is non-mutating")
 await open_help();tap(KEY_ESCAPE)
 check(game.modal==null and game.mode=="level","first Esc closes only help")
 tap(KEY_ESCAPE)
 check(game.mode=="world" and str(game.level.id)=="heaven_13","world menu retains old dictionary fixture")
 # Exact mode gating, including preview of a different world/chapter.
 for where in ["different_world","hub","title"]:
  if where=="different_world":game.show_world_menu("city",5)
  elif where=="hub":game.show_hub()
  else:game.show_title()
  await open_help()
  check(help_labels().is_empty(),"no stale exercise in "+where)
  game.close_modal()
 await clean_level("city_04");await open_help()
 check(help_text().contains("这里的灯板不是目标") and not help_text().contains("一只果篮"),"new level refreshes question")
 for absent in [{},{"chapter_name":"x"},{"learning_goal":"x"},{"chapter_name":" ","learning_goal":"x"},{"chapter_name":null,"learning_goal":"x"},{"chapter_name":"x","learning_goal":null},{"chapter_name":12,"learning_goal":"x"},{"chapter_name":"x","learning_goal":[]}]:
  check(game.CONTEXT_HELP.text_for("level",absent).is_empty(),"missing/blank metadata omits exercise")
 # Every physical direction, both schemes: hold, dismiss, release/repress within one frame.
 for pair in [[KEY_UP,"U"],[KEY_DOWN,"D"],[KEY_LEFT,"L"],[KEY_RIGHT,"R"],[KEY_W,"U"],[KEY_A,"L"],[KEY_S,"D"],[KEY_D,"R"]]:
  await clean_level("heaven_03")
  if pair[1]=="U":game.attempt_move("D");await wait_motion()
  elif pair[1]=="R":game.attempt_move("L");await wait_motion()
  before=snapshot()
  var expected: Dictionary=Rules.step(game.level,game.state,pair[1])
  check(not expected.is_empty(),"held-key fixture move legal "+str(pair[0]))
  await open_help();event(pair[0],true)
  unchanged(before,"direction press under help is ignored "+str(pair[0]))
  tap(KEY_ESCAPE)
  check(game.help_release_keys.has(pair[0]),"dismiss remembers exact held physical key "+str(pair[0]))
  await create_timer(.27).timeout
  unchanged(before,"held key cannot leak after dismissal "+str(pair[0]))
  # Intentionally no await/frame between release and new press.
  event(pair[0],false);event(pair[0],true);event(pair[0],false)
  check(game.help_release_keys.is_empty(),"same-frame release clears guard "+str(pair[0]))
  check(game.state==expected,"same-frame deliberate re-press is not swallowed "+str(pair[0]))
  await wait_motion()
  var after:=snapshot();await create_timer(.25).timeout
  unchanged(after,"released key has no delayed repeat "+str(pair[0]))
 # Hold began before F1, and repeated F1 while still held cannot remove the guard.
 for held_code in [KEY_LEFT,KEY_A]:
  await clean_level("heaven_03")
  event(held_code,true);before=snapshot();tap(KEY_F1);tap(KEY_F1)
  check(game.moving,"held-before-help retains original tween")
  tap(KEY_ESCAPE);await wait_motion();await create_timer(.27).timeout
  unchanged(before,"held-before-help and repeated F1 cannot leak repeat "+str(held_code))
  event(held_code,false);tap(KEY_LEFT);check(game.state.moves==before.state.moves+1,"release after repeated F1 admits deliberate movement")
  await wait_motion()
 # clear_ui dismisses a help modal on navigation, but never displays stale text.
 await clean_level("heaven_13");await open_help();event(KEY_LEFT,true)
 game.show_world_menu("city",1)
 check(game.help_release_keys.has(KEY_LEFT),"clear_ui preserves held-key guard when replacing help")
 game.start_level(entry("heaven_03"));before=snapshot();await create_timer(.27).timeout
 unchanged(before,"held key from old help cannot move new level")
 event(KEY_LEFT,false)
 # A non-help modal dismissal must not create this new help-specific guard.
 game.open_modal("Independent generic modal fixture","No help metadata")
 event(KEY_A,true);game.close_modal()
 check(game.help_release_keys.is_empty(),"generic modal close does not acquire help guard")
 event(KEY_A,false)
 # Pointer close has same guard; all old keys must release, not just one.
 await clean_level("heaven_03");await open_help()
 before=snapshot();event(KEY_LEFT,true);event(KEY_A,true)
 await click_text("明白了")
 check(game.help_release_keys.size()==2,"pointer close remembers both held aliases")
 event(KEY_LEFT,false);tap(KEY_DOWN)
 unchanged(before,"partial old-key release cannot leak a new direction")
 event(KEY_A,false);tap(KEY_DOWN)
 check(game.state.moves==before.state.moves+1,"all old keys released admits new direction")
 await wait_motion()
 # R/Z deliberately dismiss and act; the added hold guard prevents only stray repeats.
 await clean_level("heaven_03");tap(KEY_LEFT);await wait_motion();before=snapshot()
 await open_help();event(KEY_A,true);tap(KEY_R)
 check(game.modal==null and game.state==Rules.initial(game.level),"R under help deliberately resets")
 check(game.history.size()==before.history.size()+1,"reset retains complete undo history")
 var reset:=snapshot();await create_timer(.27).timeout
 unchanged(reset,"held A after R cannot cause stray movement")
 event(KEY_A,false);await open_help();event(KEY_LEFT,true);tap(KEY_Z)
 check(game.modal==null,"Z under help deliberately dismisses")
 unchanged(before,"Z still undoes reset under help")
 await create_timer(.27).timeout;unchanged(before,"held Left after Z cannot cause stray movement")
 event(KEY_LEFT,false)
 # A committed tween is neither killed nor replayed; old buffered move is discarded.
 for close_early in [true,false]:
  await clean_level("heaven_03")
  tap(KEY_LEFT);tap(KEY_DOWN)
  check(game.moving and game.pending_direction=="D","one old direction really buffered")
  before=snapshot();var tween_id: int=game.move_tween.get_instance_id()
  tap(KEY_F1)
  check(game.moving and game.move_tween.is_valid() and game.move_tween.get_instance_id()==tween_id,"F1 keeps committed tween alive")
  if close_early:tap(KEY_ESCAPE)
  await wait_motion()
  if not close_early:tap(KEY_ESCAPE)
  check(game.pending_direction.is_empty(),"old buffer cannot survive help lifecycle")
  unchanged(before,"help preserves one committed endpoint and no buffered extra move")
 # Winning committed move still reconciles through the normal completion modal.
 await clean_level("heaven_01")
 var winning: String=""
 for direction in Rules.DIRS:
  var next:=Rules.step(game.level,game.state,direction)
  if not next.is_empty() and Rules.won(game.level,next):winning=direction
 check(not winning.is_empty(),"single-push winning fixture found")
 var code: Key={"U":KEY_UP,"D":KEY_DOWN,"L":KEY_LEFT,"R":KEY_RIGHT}[winning]
 tap(code);before=snapshot();tap(KEY_F1)
 check(game.moving and Rules.won(game.level,game.state),"win endpoint committed before help opens")
 await wait_motion()
 check(game.win_shown and game.modal!=null and not game.modal.get_meta("contextual_help",false),"winning tween replaces help with normal win modal")
 check(game.state==before.state and game.history==before.history,"help does not cancel winning endpoint or history")
 check("heaven_01" in game.progress.solved,"normal completion records solved level")
 # A real pending hint job cannot reappear after F1.
 await clean_level("heaven_50");before=snapshot()
 tap(KEY_H);tap(KEY_J)
 var request: int=game.hint_request
 check(game.hint_active and request>=0,"real hint request starts before interruption")
 tap(KEY_F1)
 check(not game.hint_active and game.hint_panel==null and game.hint_overlay==null,"F1 immediately cancels pending hint and overlays")
 for i in range(20):await process_frame
 check(game.hint_panel==null and game.hint_overlay==null and game.hints.get_result(request).status=="stale","old asynchronous hint never revives")
 unchanged(before,"cancelled pending hint/help never auto-move")
 tap(KEY_ESCAPE);tap(KEY_H)
 check(game.hint_tier==1 and not game.hint_active,"reopening H remains optional first layer")
 tap(KEY_J);check(game.hint_request!=request,"new explicit J cannot reuse cancelled request")
 game.invalidate_hint()
 # Real dirty autosave while help is open, isolated sidecar; help has no revision.
 await clean_level("heaven_03")
 var directory: String="user://context_audit_"+str(Time.get_ticks_usec())
 game.initialize_resume(directory);game.resume_session.debounce_ms=0;game.resume_session.interval_ms=0
 tap(KEY_LEFT);await wait_motion();game.reset_level()
 var revision: int=game.resume_session.revision;before=snapshot()
 await open_help()
 var began:=Time.get_ticks_msec()
 while game.resume_session.dirty and Time.get_ticks_msec()-began<5000:await process_frame
 check(not game.resume_session.dirty and game.resume_session.commits>0,"dirty autosave completes while help is open")
 check(game.resume_session.revision==revision,"help does not change save revision")
 unchanged(before,"help autosave preserves board/history/progress")
 var commits: int=game.resume_session.commits
 await open_help();tap(KEY_ESCAPE);await create_timer(.1).timeout
 check(game.resume_session.revision==revision and game.resume_session.commits==commits,"clean reopen/close does not produce another write")
 # Reload controller verifies disk, then real continue restores without help persistence.
 game.initialize_resume(directory);game.show_title();await open_help()
 began=Time.get_ticks_msec()
 while game.resume_session.reading and Time.get_ticks_msec()-began<5000:await process_frame
 check(not game.resume_session.reading and not game.resume_session.candidate.is_empty(),"initial save verification progresses while title help is open")
 tap(KEY_ESCAPE);game.continue_checkpoint()
 check(game.modal==null and game.mode=="level","restore never persists help-open UI state")
 unchanged(before,"restored checkpoint preserves reset and complete history")
 # Save failure/exit confirmation cannot be replaced with F1 or callback.
 game.reset_level();await open_help();game.resume_session.protect("audit_failure_fixture")
 game.request_exit();game.poll_resume_exit()
 check(game.exit_waiting and game.modal!=null,"failed dirty exit shows explicit save decision")
 modal_id=game.modal.get_instance_id();tap(KEY_F1);game.show_help()
 check(game.modal.get_instance_id()==modal_id,"F1 and direct help callback cannot replace exit decision")
 before=snapshot();game.cancel_exit()
 check(game.require_direction_release and not game.exit_pending,"existing exit-return release guard retained")
 unchanged(before,"return from failed save preserves complete current state")
 release_directions()
 observations.append({"direction_keys_checked":8,"same_frame_release_repress":true,"pending_tween_endpoints_preserved":true,"winning_tween_preserved":true,"autosave_roundtrip":true})
 var report={"passed":failures.is_empty(),"assertions":checks,"physical_key_events":key_events,"failures":failures,"observations":observations,"engine":Engine.get_version_info().string,"scope":"Final production code, actual Input.parse_input_event physical keys/mouse, real tween/hint/resume lifecycle; headless behavior audit, not screenshots or full regression."}
 var file:=FileAccess.open("res://tests/completion_reconcile_audit/context_behavior.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 print("CONTEXT_HELP_BEHAVIOR ",JSON.stringify(report))
 await game.finish_exit(0 if failures.is_empty() else 1)
