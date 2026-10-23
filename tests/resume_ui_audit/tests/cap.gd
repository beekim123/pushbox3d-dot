extends "res://audit_tests/base.gd"
func run() -> void:
 mode="live_history_cap"
 await boot();game.initialize_resume("user://audit_live_cap");game.start_level(level("heaven_01"));game.resume_session.tick(game.level,game.state,game.history,8,true)
 await until(func():return not game.resume_session.dirty,"baseline saved")
 var original:=FileAccess.get_file_as_bytes("user://audit_live_cap/resume.json")
 game.set_process(false)
 var initial:=Rules.initial(game.level)
 for i in range(8193):game.history.append(initial.duplicate(true))
 var before:=snap();game.mark_resume_changed();game.resume_session.tick(game.level,game.state,game.history,8,true)
 ck(game.resume_session.status=="not_saved" and game.resume_session.failure_kind=="history_limit","live save refuses 8193 rather than truncating")
 ck("8192" in game.resume_session.message() and "撤销仍完整" in game.resume_session.message(),"explicit bounded persistence message")
 same(before,"failed oversize checkpoint")
 ck(FileAccess.get_file_as_bytes("user://audit_live_cap/resume.json")==original,"old bytes preserved on cap")
 game.undo_move();ck(game.history.size()==8192,"live Undo unaffected above persistence cap")
 var deadline:=Time.get_ticks_msec()+15000;var max_ms:=0.0
 while game.resume_session.dirty and Time.get_ticks_msec()<deadline:
  var began:=Time.get_ticks_usec();game.resume_session.tick(game.level,game.state,game.history,2,true);max_ms=maxf(max_ms,(Time.get_ticks_usec()-began)/1000.0);await process_frame
 ck(not game.resume_session.dirty and game.resume_session.commits==2,"new revision within bound saves again")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://audit_live_cap/resume.json"))
 ck(data.actions.length()==8192 and game.history.size()==8192,"all surviving history saved without shortening live stack")
 report("cap.json",{"max_tick_ms":max_ms,"requested_budget_ms":2,"scope":"8193 valid Reset fixture snapshots in live main; not 8193 manual native actions."})
 game.set_process(true);await game.finish_exit(0 if failures.is_empty() else 1)
