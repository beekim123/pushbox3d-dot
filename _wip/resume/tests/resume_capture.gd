extends SceneTree
var game
func _initialize(): call_deferred("run")
func run():
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.initialize_resume("user://capture_resume_"+str(Time.get_ticks_usec()))
 game.start_level(game.levels_by_world.heaven[2])
 game.attempt_move("L")
 await game.move_tween.finished
 game.reset_level()
 game.attempt_move("L")
 await game.move_tween.finished
 for i in range(1000):
  game.resume_session.tick(game.level,game.state,game.history,8.0,true)
  if not game.resume_session.dirty: break
  await process_frame
 game.show_title()
 var shot=str(game.args.get("resume-shot","title"))
 if shot!="title": game.resume_button.pressed.emit()
 if shot=="paused":
  game.reset_level()
  game.resume_session.protect("capture_failure_fixture")
  game.request_exit()
  game.poll_resume_exit()
 for i in range(6): await process_frame
 await RenderingServer.frame_post_draw
 var path="res://screenshots/v2/resume_"+shot+".png"
 var error=root.get_texture().get_image().save_png(path)
 print("RESUME_CAPTURE ",shot," error=",error," moves=",game.state.moves," history=",game.history.size())
 await game.finish_exit(0 if error==OK else 1)
