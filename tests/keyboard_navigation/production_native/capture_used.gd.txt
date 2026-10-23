extends SceneTree
var game
var rows:=[]
var failures:=[]
const OUT:="[workspace]/fourfold_next/keyboard_navigation/qa/production_native"
func _initialize(): call_deferred("run")
func key(code: Key):
 for pressed in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e)
  await process_frame
func take(label: String, expected: String):
 for i in range(8): await process_frame
 await RenderingServer.frame_post_draw
 var owner:=root.gui_get_focus_owner()
 var action: String=str(owner.get_meta("focus_action","")) if is_instance_valid(owner) else ""
 var error:=root.get_texture().get_image().save_png(OUT+"/"+label+".png")
 if error!=OK or action!=expected: failures.append(label)
 rows.append({"name":label,"focus_action":action,"image_error":error,"size":str(root.size)})
func run():
 root.size=Vector2i(1440,900)
 Input.use_accumulated_input=false
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await take("title","hub")
 await key(KEY_F1)
 await take("help","help:close")
 await key(KEY_ESCAPE)
 game.initialize_resume("user://keyboard_production_native_"+str(Time.get_ticks_usec()))
 game.start_level(game.levels_by_world.heaven[1])
 game.resume_session.protect("production_native_explicit_failure_fixture")
 game.request_exit();game.poll_resume_exit()
 await take("failed_exit","exit:return")
 var before: Dictionary=game.state.duplicate(true)
 await key(KEY_ENTER)
 for i in range(3):await process_frame
 if game.exit_pending or game.modal!=null or game.state!=before or root.gui_get_focus_owner()!=null:failures.append("safe_return")
 var report:={"engine":Engine.get_version_info().string,"project":ProjectSettings.globalize_path("res://"),"source_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"rows":rows,"failures":failures,"scope":"Actual integrated production project. External test-only script/direct failure setup; injected keys for Help/Return. No runtime/test source writes to production."}
 var file:=FileAccess.open(OUT+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("PRODUCTION_KEYBOARD_NATIVE ",JSON.stringify(report))
 await game.finish_exit(0 if failures.is_empty() else 1)
