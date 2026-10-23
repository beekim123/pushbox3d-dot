extends "res://audit_tests/base.gd"
func run() -> void:
 mode="shared_soft_budget"
 await boot();game.initialize_resume("user://audit_schedule");game.start_level(level("heaven_03"));game.set_process(false)
 var initial:=Rules.initial(game.level);game.state=initial.duplicate(true);game.history=[]
 for i in range(512):game.history.append(initial.duplicate(true))
 game.mark_resume_changed();game.resume_session.tick(game.level,game.state,game.history,.01,true)
 ck(game.resume_session.writing,"valid injected 512-Reset stack creates in-flight encode")
 var old:int=game.resume_session.write_id;var revision:int=game.resume_session.revision
 game.undo_move()
 ck(game.history.size()==511 and game.resume_session.revision>revision,"actual Undo revises stack")
 ck(not game.resume_session.writing and game.resume_session.writer.take_result(old,revision).status=="stale","old callback cannot commit")
 game.resume_session.debounce_ms=0;game.resume_session.interval_ms=0
 game.toggle_hint();game.advance_hint();ck(game.hint_active,"real hint solver active")
 var before:=snap();var max_ms:=0.0;var count:=0;var concurrent:=0;var deadline:=Time.get_ticks_msec()+30000
 while (game.hint_active or game.resume_session.dirty) and Time.get_ticks_msec()<deadline:
  if game.hint_active and game.resume_session.dirty:concurrent+=1
  var began:=Time.get_ticks_usec();game._process(1.0/60);max_ms=maxf(max_ms,(Time.get_ticks_usec()-began)/1000.0);count+=1;await process_frame
 ck(not game.hint_active and not game.resume_session.dirty and concurrent>0,"both pending tasks actually complete")
 ck(game.hint_status=="solved","hint uses current logical state")
 same(before,"background jobs never autoplay")
 ck(game.resume_session.saved_revision==game.resume_session.revision and game.resume_session.commits==1,"only newest revision committed")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://audit_schedule/resume.json"));ck(data.actions.length()==511,"saved full surviving post-Undo stack")
 report("schedule.json",{"max_actual_process_ms":max_ms,"process_calls":count,"concurrent_calls":concurrent,"requested_shared_budget_ms":2,"scope":"Actual _process with automatic invocation disabled for measurement; valid fixture history, soft budget not hard deadline."})
 game.set_process(true);await game.finish_exit(0 if failures.is_empty() else 1)
