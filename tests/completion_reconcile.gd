extends SceneTree
var game
var checks:=0
var failures:=[]
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if not ok: failures.append(message)
func has_next() -> bool:
 return game.ui.find_children("*","Button",true,false).any(func(b): return b.text.begins_with("前往下一道"))
func tap(code: Key):
 for pressed in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed
  Input.parse_input_event(e)
func run():
 Input.use_accumulated_input=false
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.progress={"version":2,"solved":[],"best":{},"muted":false}
 game.start_level(game.levels_by_world.heaven[0])
 tap(KEY_RIGHT)
 var solved=game.state.duplicate(true)
 check(game.moving and game.RULES.won(game.level,game.state),"first winning endpoint committed before tween")
 tap(KEY_R);tap(KEY_Z)
 check(game.state==solved,"same-frame R Z restores exact pending endpoint")
 check(game.win_shown and has_next(),"undo handler reconciles win UI without manual repair")
 check(game.level.id in game.progress.solved,"interrupted first completion actually registered")
 var progress=game.progress.duplicate(true)
 var history=game.history.duplicate(true)
 tap(KEY_F1);tap(KEY_ESCAPE)
 check(has_next() and game.win_shown,"F1 Esc restores next action")
 check(game.progress==progress and game.history==history and game.state==solved,"help roundtrip preserves state/history/progress")
 tap(KEY_ESCAPE)
 check(game.modal==null,"direct Esc deliberately dismisses completion")
 for direction in ["U","D","L","R"]:
  var next=game.RULES.step(game.level,game.state,direction)
  if not next.is_empty() and game.RULES.won(game.level,next):
   game.attempt_move(direction)
   if game.moving: await game.move_tween.finished
   break
 check(game.modal==null,"ordinary walking after dismissal does not reopen completion")
 game.undo_move()
 check(has_next() and game.state==solved,"explicit undo to won state reopens completion")
 tap(KEY_R);tap(KEY_Z)
 check(has_next() and game.state==solved,"recorded winning reset undo also reconciles")
 check(game.progress==progress,"recorded result remains identical")
 tap(KEY_Z)
 check(not game.RULES.won(game.level,game.state) and game.modal==null,"undo winning push returns playable unsolved state")
 game.show_completion_panel()
 check(game.modal==null,"presentation ignores unsolved state")
 game.show_title();game.show_completion_panel()
 check(game.modal==null,"presentation ignores non-level mode")
 print("COMPLETION_RECONCILE checks=",checks," failures=",failures)
 await game.finish_exit(0 if failures.is_empty() else 1)
