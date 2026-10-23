extends SceneTree
var game
var checks:=0
var failures:=[]
func _initialize(): call_deferred("run")
func check(ok: bool, description: String):
 checks+=1
 if not ok: failures.append(description); print("RESUME_FAIL ",description)
func flush_resume():
 for i in range(1000):
  game.resume_session.tick(game.level,game.state,game.history,8.0,true)
  if not game.resume_session.dirty: return
  await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.initialize_resume("user://resume_integration_"+str(Time.get_ticks_usec()))
 game.resume_session.debounce_ms=0
 game.resume_session.interval_ms=0
 game.start_level(game.levels_by_world.heaven[2])
 game.attempt_move("L")
 check(game.moving,"move logical endpoint is committed before animation")
 var moved=game.state.duplicate(true)
 game.reset_level()
 check(game.history.size()==2,"reset retained original movement snapshot")
 var expected=game.state.duplicate(true)
 var expected_history=game.history.duplicate(true)
 await flush_resume()
 check(not game.resume_session.dirty and game.resume_session.commits==1,"one verified sidecar commit")
 game.show_title()
 check(not game.resume_button.disabled,"real title continue enabled")
 game.resume_button.pressed.emit()
 check(game.state==expected and game.history==expected_history,"actual continue handler preserves reset and complete history")
 game.undo_move()
 check(game.state==moved,"reset is undoable after actual restoration")
 game.undo_move()
 check(game.state==game.RULES.initial(game.level),"restored history reaches initial")
 game.attempt_move("L")
 game.cancel_motion()
 game.resume_session.tick(game.level,game.state,game.history,0.001,true)
 var old_revision=game.resume_session.revision
 game.reset_level()
 check(game.resume_session.revision>old_revision and not game.resume_session.writing,"logical change invalidates existing encoder")
 await flush_resume()
 check(not game.resume_session.dirty,"latest revision persisted")
 var prior=game.resume_session.checkpoint_summary()
 game.attempt_move("L")
 game.cancel_motion()
 game.resume_session.protect("test_injected_failure")
 game.request_exit()
 game.poll_resume_exit()
 check(game.exit_waiting,"failed save opens bounded explicit exit confirmation")
 check(game.resume_session.checkpoint_summary()==prior,"failed exit preserves earlier checkpoint summary")
 var before=game.state.duplicate(true)
 game.cancel_exit()
 check(not game.exit_pending and game.state==before and game.require_direction_release,"cancel exit preserves state and requires key release")
 check(game.ui.find_children("","Button",true,false).filter(func(b): return b.get_meta("resume_action","")=="exit_unsaved").is_empty(),"old exit modal removed")
 print("RESUME_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures}))
 await game.finish_exit(0 if failures.is_empty() else 1)
