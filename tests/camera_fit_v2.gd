extends SceneTree
const VIEW=preload("res://scripts/world_view.gd")
const RULES=preload("res://scripts/puzzle_rules.gd")
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var view=VIEW.new()
 root.add_child(view)
 await process_frame
 var failures:=0
 var checked:=0
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
 for w in ["heaven","inferno","rainforest","city","confluence"]:
  var entries=data.levels.filter(func(l): return l.world==w)
  for index in range(entries.size()):
   view.setup_level(entries[index],RULES.initial(entries[index]))
   var bounds: Rect2=view.camera.get_meta("fit_bounds",Rect2())
   var safe: Rect2=view.camera.get_meta("fit_safe",Rect2())
   checked+=1
   if not Rect2(28,88,1384,714).encloses(bounds):
    failures+=1
    print("CAMERA_CLIP ",entries[index].id," bounds=",bounds," size=",view.camera.size)
   await process_frame
 view.queue_free()
 await process_frame
 print("CAMERA_FIT checked=",checked," HUD_clips=",failures)
 quit(0 if failures==0 else 1)
