extends "res://audit_tests/base.gd"
const Codec=preload("res://scripts/resume/resume_codec.gd")
const SLOT:="user://fourfold_resume"
const EXPECTED:="user://audit_expected.bin"
var sentinel:='{ "version":999, "unknown":"keep future progress byte exact" }\n'.to_utf8_buffer()
func requested() -> String:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--audit-mode="):return arg.trim_prefix("--audit-mode=")
 return "reader"
func save_expected(value:Dictionary) -> void:
 var file:=FileAccess.open(EXPECTED,FileAccess.WRITE);file.store_var(value);file.close()
func expected() -> Dictionary:
 var file:=FileAccess.open(EXPECTED,FileAccess.READ)
 ck(file!=null,"separate-process expected fixture exists")
 if file==null:return {}
 var result:Dictionary=file.get_var();file.close();return result
func seed_terminal() -> void:
 var entry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json")).levels[0]
 var initial:=Rules.initial(entry);var state:=Rules.step(entry,initial,"R")
 var c:=Codec.new(Rules);var id:int=c.begin_encode(entry,state,[initial],1)
 while c.poll().status=="running":c.step_budget(2,id,1)
 var encoded:Dictionary=c.take_result(id,1);ck(encoded.status=="encoded","terminal fixture valid")
 write(SLOT+"/resume.json",encoded.bytes);write("user://fourfold_progress.json",sentinel)
func writer() -> void:
 game.initialize_resume(SLOT);game.start_level(level("heaven_01"))
 await key(KEY_UP);await motion();await key(KEY_R)
 key_state(KEY_UP,true);await process_frame
 ck(game.moving,"close starts during actual tween")
 key_state(KEY_DOWN,true);await process_frame
 ck(game.pending_direction=="D","opposite direction really queued")
 var current:=snap();ck(current.history.size()==3 and current.state.moves==1,"move Reset move stack")
 key_state(KEY_UP,false);key_state(KEY_DOWN,false);save_expected(current)
 game.request_exit();same(current,"ordinary close logical endpoint")
 ck(not game.moving and game.pending_direction=="","close does not preserve tween or queued direction")
 report("restart_writer.json")
 await create_timer(20).timeout
 ck(false,"ordinary exit did not terminate");report("restart_writer.json");await game.finish_exit(1)
func reader(native:bool) -> void:
 game.initialize_resume(SLOT);game.show_title()
 await until(func():return not game.resume_session.reading,"fresh-process verification")
 ck(game.mode=="title" and game.state.is_empty(),"no automatic level entry before explicit Continue")
 ck(not button("continue").disabled,"verified Continue enabled")
 var current:=expected()
 if native:
  await capture("native_title.png");print("AUDIT_NATIVE_CONTINUE")
  await until(func():return game.mode=="level","native pointer Continue",120000)
 else:await click(button("continue"))
 same(current,"fresh-process exact state/full surviving history",false)
 ck(not game.moving and game.pending_direction=="","fresh process snaps logical endpoint")
 if native:
  await capture("native_restored.png");print("AUDIT_NATIVE_UNDO_1")
  await until(func():return game.history.size()==2,"native first Undo",120000)
 else:await key(KEY_Z)
 ck(game.state==current.history[2],"first Undo exact snapshot")
 if native:
  print("AUDIT_NATIVE_UNDO_RESET")
  await until(func():return game.history.size()==1,"native Undo Reset",120000)
 else:await key(KEY_Z)
 ck(game.state==current.history[1],"Undo Reset exact previous state")
 if native:
  await capture("native_undo_reset.png");print("AUDIT_NATIVE_UNDO_LAST")
  await until(func():return game.history.is_empty(),"native final Undo",120000)
 else:await key(KEY_Z)
 ck(game.state==Rules.initial(game.level),"all surviving Undo returns initial")
 report("restart_"+("native" if native else "reader")+".json",{"native_input":native})
 if native:
  print("AUDIT_NATIVE_CLOSE");await create_timer(120).timeout
 else:
  game.request_exit();await create_timer(20).timeout
 ck(false,"normal close not completed");await game.finish_exit(1)
func future_progress() -> void:
 ck(not game.qa_mode and not game.progress_writable,"actual non-QA future-progress read-only policy")
 await until(func():return not game.resume_session.reading,"terminal checkpoint validated")
 await click(button("continue"))
 ck(Rules.won(game.level,game.state) and game.win_shown and game.modal!=null,"actual completion reconciliation on terminal restore")
 ck(game.level.id in game.progress.solved,"in-memory completion reconciled")
 ck(FileAccess.get_file_as_bytes("user://fourfold_progress.json")==sentinel,"future progress unchanged after restore")
 await key(KEY_Z)
 ck(game.state==Rules.initial(game.level) and game.history.is_empty(),"terminal remains undoable")
 ck(FileAccess.get_file_as_bytes("user://fourfold_progress.json")==sentinel,"Undo does not overwrite protected progress")
 report("future_progress.json");game.request_exit();await create_timer(20).timeout;await game.finish_exit(1)
func failure(native:bool) -> void:
 game.initialize_resume(SLOT);game.start_level(level("heaven_01"))
 game.resume_session.tick(game.level,game.state,game.history,8,true)
 await until(func():return not game.resume_session.dirty,"baseline committed before foreign lock")
 var original:=FileAccess.get_file_as_bytes(SLOT+"/resume.json")
 if native:
  original='{ "version":999, "external":"native audit replacement; preserve exact" }'.to_utf8_buffer()
  write(SLOT+"/resume.json",original)
 else:
  ck(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SLOT+"/resume.lock"))==OK,"actual foreign lock")
 write("user://audit_original.bin",original)
 if native:
  print("AUDIT_FAILURE_UP");await until(func():return game.state.moves==1,"native unsaved move",120000)
 else:await key(KEY_UP)
 await motion();var current:=snap()
 await until(func():return game.resume_session.paused,"actual disk refusal pauses")
 if native:
  ck(game.resume_session.candidate.is_empty(),"external replacement invalidates stale in-memory candidate")
  ck("仅供参考" in game.resume_session.checkpoint_summary(),"summary explicitly reference only")
 if native:
  await capture("native_paused_footer.png");print("AUDIT_FAILURE_CLOSE")
 else:game.request_exit()
 await until(func():return game.exit_waiting,"exit warning visible",120000 if native else 15000)
 ck("不保证仍可恢复" in labels() and "未保存变化在退出后会丢失" in labels(),"honest reference/unsaved consequence")
 if native:
  await capture("native_exit_failure.png");print("AUDIT_FAILURE_RETURN")
  await until(func():return not game.exit_pending,"native Return",120000)
 else:await click(button("cancel_exit"))
 same(current,"Return keeps current complete state/history")
 ck(FileAccess.get_file_as_bytes(SLOT+"/resume.json")==original,"Return preserves old bytes")
 if native:
  await capture("native_return_unsaved.png");print("AUDIT_FAILURE_CLOSE_AGAIN")
 else:game.request_exit()
 await until(func():return game.exit_waiting,"second failure warning",120000 if native else 15000)
 ck(button("exit_unsaved")!=null,"explicit Still exit available")
 report("exit_failure_"+("native" if native else "dispatch")+".json",{"native_input":native,"requires_postprocess_file_check":true})
 if native:print("AUDIT_FAILURE_STILL_EXIT")
 else:await click(button("exit_unsaved"))
 await create_timer(120 if native else 20).timeout
 ck(false,"Still exit not completed");await game.finish_exit(1)
func run() -> void:
 mode=requested()
 if mode=="future_progress":seed_terminal()
 await boot()
 match mode:
  "writer":await writer()
  "reader":await reader(false)
  "native_restart":await reader(true)
  "future_progress":await future_progress()
  "exit_failure":await failure(false)
  "native_failure":await failure(true)
  _:ck(false,"unknown mode");await game.finish_exit(2)
