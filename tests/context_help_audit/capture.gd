extends SceneTree
var game
var rows: Array=[]
var failures: Array=[]
func _initialize():call_deferred("run")
func entry(id: String)->Dictionary:
 for item in game.levels:
  if item.id==id:return item
 return {}
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for id in ["city_04","heaven_13","city_06","confluence_01","world_stale_level","title_generic"]:
  if id=="world_stale_level":game.show_world_menu("city",5)
  elif id=="title_generic":game.show_title()
  else:game.start_level(entry(id))
  game.show_help()
  for i in range(8):await process_frame
  await RenderingServer.frame_post_draw
  var screenshot: Image=root.get_texture().get_image()
  var path: String="res://screenshots/context_help_audit/"+id+".png"
  var error:=screenshot.save_png(path)
  var labels: Array=game.ui.find_children("*","Label",true,false).filter(func(l):return l.get_meta("chapter_exercise",false))
  if error!=OK or screenshot.get_size()!=Vector2i(1440,900):failures.append(id+" screenshot missing/wrong size")
  if labels.size()!=(1 if game.mode=="level" else 0):failures.append(id+" incorrect context count")
  rows.append({"id":id,"path":path,"image_size":[screenshot.get_width(),screenshot.get_height()],"save_error":error,"mode":game.mode,"cached_level":game.level.id,"exercise_count":labels.size()})
  print("CONTEXT_NATIVE_CAPTURE ",JSON.stringify(rows[-1]))
 var file:=FileAccess.open("res://tests/context_help_audit/capture.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":failures.is_empty(),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"display_server":DisplayServer.get_name(),"headless":DisplayServer.get_name()=="headless","rows":rows,"failures":failures},"  "))
 await game.finish_exit(0 if failures.is_empty() else 1)
