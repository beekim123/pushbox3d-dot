extends SceneTree
var game
var rows: Array=[]
var failures: Array=[]
func _initialize():call_deferred("run")
func tap(code: Key):
 for pressed in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func entry(id: String)->Dictionary:
 for item in game.levels:
  if item.id==id:return item
 return {}
func has_result()->bool:return is_instance_valid(game.modal) and game.modal.find_children("*","Label",true,false).any(func(l):return l.text=="线头接上了")
func shot(id: String,expected_result: bool):
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 var path="res://screenshots/completion_reconcile_audit/"+id+".png"
 var error=image.save_png(path)
 if error!=OK or image.get_size()!=Vector2i(1440,900) or has_result()!=expected_result:failures.append(id+" capture/state failure")
 rows.append({"id":id,"path":path,"image_size":[image.get_width(),image.get_height()],"save_error":error,"level":game.level.id,"moves":game.state.moves,"pushes":game.state.pushes,"won":game.RULES.won(game.level,game.state),"result":has_result(),"buttons":game.ui.find_children("*","Button",true,false).map(func(b):return b.text)})
 print("COMPLETION_NATIVE_CAPTURE ",JSON.stringify(rows[-1]))
func run():
 root.size=Vector2i(1440,900);Engine.time_scale=4.0;Input.use_accumulated_input=false
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.progress={"version":2,"solved":[],"best":{},"muted":false}
 game.start_level(entry("heaven_01"));tap(KEY_RIGHT);tap(KEY_R);tap(KEY_Z)
 await shot("pending_win_reset_undo",true)
 tap(KEY_F1);tap(KEY_ESCAPE)
 await shot("help_returns_next",true)
 tap(KEY_ESCAPE);tap(KEY_LEFT)
 while game.moving:await process_frame
 await shot("dismissed_result_exploration",false)
 game.start_level(entry("heaven_50"))
 var report=JSON.parse_string(FileAccess.get_file_as_string("res://tests/solver_report.json"))
 for direction in report.levels.filter(func(l):return l.id=="heaven_50")[0].solution:
  tap({"U":KEY_UP,"D":KEY_DOWN,"L":KEY_LEFT,"R":KEY_RIGHT}[direction])
  while game.moving:await process_frame
 tap(KEY_F1);tap(KEY_ESCAPE)
 await shot("final_world_help_returns_hub",true)
 var f=FileAccess.open("res://tests/completion_reconcile_audit/capture.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"passed":failures.is_empty(),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"display_server":DisplayServer.get_name(),"headless":DisplayServer.get_name()=="headless","rows":rows,"failures":failures,"input_scope":"native graphical production scene with engine Input.parse_input_event, not OS key events"},"  "))
 await game.finish_exit(0 if failures.is_empty() else 1)
