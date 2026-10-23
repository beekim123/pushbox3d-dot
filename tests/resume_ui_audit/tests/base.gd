extends SceneTree
const Rules = preload("res://scripts/puzzle_rules.gd")
var game: Node
var checks := 0
var failures: Array[String] = []
var observations: Array = []
var mode := ""
func _initialize() -> void: call_deferred("run")
func run() -> void: quit(2)
func ck(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label);print("RESUME_AUDIT_FAIL ",label)
func boot() -> void:
 Engine.max_fps=240
 Input.use_accumulated_input=false
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 await process_frame
func level(id: String) -> Dictionary:
 for entry in game.levels:
  if entry.id==id: return entry
 ck(false,"known level "+id)
 return {}
func snap() -> Dictionary:
 return {"level_id":game.level.get("id",""),"state":game.state.duplicate(true),"history":game.history.duplicate(true),"progress":game.progress.duplicate(true)}
func same(before: Dictionary,label: String,progress: bool=true) -> void:
 ck(game.level.get("id","")==before.level_id and game.state==before.state and game.history==before.history,label+" exact logical state/history")
 if progress: ck(game.progress==before.progress,label+" progress unchanged")
func button(action: String) -> Button:
 var found: Array=game.ui.find_children("","Button",true,false).filter(func(b):return b.get_meta("resume_action","")==action)
 ck(found.size()==1,"one button "+action)
 return found[0] if found.size()==1 else null
func labels() -> String:
 var result: PackedStringArray=[]
 for label in game.ui.find_children("","Label",true,false): result.append(label.text)
 return "\n".join(result)
func click(target: Button) -> void:
 if target==null:return
 ck(not target.disabled and target.is_visible_in_tree(),"pointer target enabled")
 var center:=target.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=center;motion.global_position=center
 Input.parse_input_event(motion)
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.position=center;down.global_position=center;down.pressed=true
 Input.parse_input_event(down)
 await process_frame
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=center;up.global_position=center;up.pressed=false
 Input.parse_input_event(up)
 await process_frame
 await process_frame
func key_state(code: Key,pressed: bool) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
 Input.parse_input_event(event)
func key(code: Key) -> void:
 key_state(code,true);await process_frame;key_state(code,false);await process_frame
func until(predicate: Callable,label: String,timeout_ms: int=15000) -> void:
 var deadline:=Time.get_ticks_msec()+timeout_ms
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 ck(predicate.call(),label)
func motion() -> void:await until(func():return not game.moving,"real tween completes")
func output_path(name: String) -> String:
 return OS.get_environment("RESUME_AUDIT_RESULTS").path_join(name)
func capture(name: String) -> void:
 ck(DisplayServer.get_name()!="headless","actual graphical display for "+name)
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 ck(root.get_texture().get_image().save_png(output_path(name))==OK,"screenshot "+name)
func report(name: String,extra: Dictionary={}) -> void:
 var result: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"mode":mode,"pid":OS.get_process_id(),"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"userdata":OS.get_user_data_dir(),"recovery_run":true}
 result.merge(extra)
 var f:=FileAccess.open(output_path(name),FileAccess.WRITE)
 if f==null:push_error("report unavailable");quit(2);return
 f.store_string(JSON.stringify(result,"  "));f.close();print("RESUME_AUDIT ",JSON.stringify(result))
func write(path: String,bytes: PackedByteArray) -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var f:=FileAccess.open(path,FileAccess.WRITE)
 ck(f!=null,"fixture write open")
 if f!=null:f.store_buffer(bytes);f.close()
