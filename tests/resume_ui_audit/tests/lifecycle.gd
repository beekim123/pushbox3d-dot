extends "res://audit_tests/base.gd"
const Codec=preload("res://scripts/resume/resume_codec.gd")
func reset_bytes(entry: Dictionary) -> PackedByteArray:
 var initial:=Rules.initial(entry);var history: Array=[]
 for i in range(8192):history.append(initial.duplicate(true))
 var codec:=Codec.new(Rules);var id:int=codec.begin_encode(entry,initial,history,0)
 while codec.poll().status=="running":codec.step_budget(2.0,id,0)
 var result: Dictionary=codec.take_result(id,0)
 ck(result.status=="encoded","long legal checkpoint fixture")
 return result.get("bytes",PackedByteArray())
func run() -> void:
 mode="lifecycle"
 await boot()
 ck(game.qa_mode and game.resume_session==null,"QA does not touch real sidecar by default")
 var slot:="user://audit_lifecycle"
 game.initialize_resume(slot)
 ck(game.resume_session.debounce_ms==1000 and game.resume_session.interval_ms==5000,"production debounce and cadence")
 game.show_title();await process_frame
 ck(button("continue").disabled,"missing checkpoint cannot continue")
 game.start_level(level("heaven_01"));var initial:=snap()
 var rev:int=game.resume_session.revision
 await key(KEY_UP);await motion();var moved:=snap()
 ck(game.history.size()==1 and game.resume_session.revision>rev,"real input revises history")
 await until(func():return not game.resume_session.dirty,"idle checkpoint saved")
 ck(game.resume_session.commits==1,"first commit once")
 var saved_at:=Time.get_ticks_msec()
 await key(KEY_R);var reset:=snap()
 ck(game.history.size()==2 and game.state==Rules.initial(game.level),"Reset is an undo entry")
 await create_timer(1.2).timeout
 ck(game.resume_session.commits==1 and game.resume_session.dirty,"not writing per input after debounce alone")
 await until(func():return game.resume_session.commits==2,"write interval eventually permits save")
 ck(Time.get_ticks_msec()-saved_at>=4500,"real minimum write interval")
 game.show_title();await process_frame
 await click(button("continue"));same(reset,"Continue Reset checkpoint")
 await key(KEY_Z);same(moved,"Undo Reset")
 await key(KEY_Z);same(initial,"Undo original move")
 game.resume_session.tick(game.level,game.state,game.history,8.0,true)
 await until(func():return not game.resume_session.dirty,"commit baseline before foreign lock")
 var old:=FileAccess.get_file_as_bytes(slot+"/resume.json")
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(slot+"/resume.lock"))
 await key(KEY_UP);var before_exit:=snap()
 game.resume_session.tick(game.level,game.state,game.history,8.0,true)
 ck(game.resume_session.paused,"foreign lock pauses saving")
 game.request_exit();await until(func():return game.exit_waiting,"visible failure exit")
 ck("本次局面尚未保存" in labels() and "未保存变化在退出后会丢失" in labels(),"clear unsaved consequence")
 ck(button("exit_unsaved")!=null,"Still exit offered")
 key_state(KEY_DOWN,true);await process_frame
 await click(button("cancel_exit"));await create_timer(.35).timeout
 same(before_exit,"held input through Return")
 ck(game.require_direction_release and game.pending_direction=="" and not game.moving,"release gate and no queued tween")
 key_state(KEY_DOWN,false);await process_frame;await process_frame
 await key(KEY_DOWN);await motion()
 ck(game.state.moves==before_exit.state.moves+1,"fresh input after release works")
 ck(FileAccess.get_file_as_bytes(slot+"/resume.json")==old,"old checkpoint preserved")
 # Regression A: cancellation of initial validation must not silently dead-end.
 var long_slot:="user://audit_reader_cancel"
 var long_bytes:=reset_bytes(level("heaven_01"));write(long_slot+"/resume.json",long_bytes)
 game.initialize_resume(long_slot);game.start_level(level("heaven_01"));game.exit_timeout_ms=1
 ck(game.resume_session.reading,"old reader actually pending")
 game.request_exit();await until(func():return game.exit_waiting,"exit cap interrupts pending reader")
 await click(button("cancel_exit"));await create_timer(.15).timeout
 ck(game.resume_session.reading or game.resume_session.writable or game.resume_session.paused,"reader cancellation resumes or transparently pauses")
 observations.append({"reader_cancel_status":game.resume_session.status,"message":game.resume_session.message()})
 var unchanged:=snap()
 game.request_exit();await until(func():return game.exit_waiting,"repeat exit while reader paused")
 await click(button("cancel_exit"));same(unchanged,"repeat Return")
 ck(FileAccess.get_file_as_bytes(long_slot+"/resume.json")==long_bytes,"repeat cancellation preserves unverified bytes")
 # Regression B: an invalidated in-memory candidate is not a recoverability promise.
 var external_slot:="user://audit_external_change"
 game.initialize_resume(external_slot);game.start_level(level("heaven_01"))
 await key(KEY_UP);game.resume_session.tick(game.level,game.state,game.history,8.0,true)
 await until(func():return not game.resume_session.dirty,"candidate exists before external change")
 var external:='{ "version":999, "external":"preserve exact bytes" }'.to_utf8_buffer()
 write(external_slot+"/resume.json",external)
 game.reset_level();game.resume_session.tick(game.level,game.state,game.history,8.0,true)
 ck(game.resume_session.paused,"external token difference protected")
 game.show_title();await process_frame
 ck(button("continue").disabled,"invalidated candidate cannot offer Continue")
 game.request_exit();await until(func():return game.exit_waiting,"external-change warning")
 ck(not "退出后只能恢复此前记录" in labels() and "不保证仍可恢复" in labels(),"no false disk recovery promise")
 ck(FileAccess.get_file_as_bytes(external_slot+"/resume.json")==external,"external original never overwritten")
 await click(button("cancel_exit"))
 report("lifecycle.json",{"scope":"Fresh recovered main/controller; actual Input.parse_input_event mouse and key propagation, not native desktop input."})
 await game.finish_exit(0 if failures.is_empty() else 1)
