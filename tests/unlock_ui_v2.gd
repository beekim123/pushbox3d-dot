extends SceneTree
var game: Node
var checks:=0
var failures:=0
func _initialize(): call_deferred("run")
func check(condition: bool,message: String):
 checks+=1
 if not condition:
  failures+=1
  print("UNLOCK_FAIL ",message)
func cards() -> Array:
 return game.ui.find_children("","Button",true,false).filter(func(b): return b.has_meta("level_id"))
func run():
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.progress={"version":2,"solved":[],"best":{},"muted":false}
 game.show_hub()
 var finale=game.ui.find_children("","Button",true,false).filter(func(b): return b.has_meta("campaign_finale"))
 check(finale.size()==1 and finale[0].disabled,"fresh hub locks finale even in capture QA mode")
 for w in ["heaven","inferno","rainforest","city"]:
  game.show_world_menu(w,0)
  var first=cards()
  check(first.size()==5,w+" first chapter has five actual buttons")
  check(first.filter(func(b): return not b.disabled).size()==1 and not first[0].disabled,w+" only first level is enabled")
  game.show_world_menu(w,9)
  check(cards().size()==5 and cards().all(func(b): return b.disabled),w+" chapter ten is entirely locked")
 game.show_world_menu("heaven",0)
 cards()[0].pressed.emit()
 check(game.mode=="level" and game.level.id=="heaven_01","actual first button opens tutorial")
 var report=JSON.parse_string(FileAccess.get_file_as_string("res://tests/solver_report.json"))
 var solution=report.levels.filter(func(l): return l.id=="heaven_01")[0].solution
 for direction in solution:
  game.attempt_move(direction)
  if game.moving: await game.move_tween.finished
 check("heaven_01" in game.progress.solved,"real tutorial completion grants progress")
 game.show_world_menu("heaven",0)
 var unlocked=cards()
 check(not unlocked[0].disabled and not unlocked[1].disabled and unlocked.slice(2).all(func(b): return b.disabled),"completion unlocks exactly next level and keeps replay")
 game.show_world_menu("heaven",9)
 check(cards().all(func(b): return b.disabled),"one win does not unlock distant chapter")
 print("UNLOCK_UI checks=",checks," failures=",failures)
 await game.finish_exit(0 if failures==0 else 1)
