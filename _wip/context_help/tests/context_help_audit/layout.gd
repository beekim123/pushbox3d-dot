extends SceneTree
var game
var checks:=0
var failures: Array=[]
var rows: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label)
func rect_dict(r: Rect2)->Dictionary:return {"x":r.position.x,"y":r.position.y,"width":r.size.x,"height":r.size.y}
func inspect(id: String):
 game.show_help();await process_frame;await process_frame
 var p: PanelContainer=game.modal.find_children("*","PanelContainer",true,false)[0]
 var v: VBoxContainer=p.get_child(0)
 var labels: Array=[]
 for child in v.get_children():
  if child is Label:labels.append({"text":child.text,"characters":child.text.length(),"lines":child.get_line_count(),"context":child.get_meta("chapter_exercise",false),"font_size":child.get_theme_font_size("font_size"),"rect":rect_dict(child.get_global_rect())})
  check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(child.get_global_rect()),id+" child within viewport")
  check(p.get_global_rect().encloses(child.get_global_rect()),id+" child within panel")
 check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(p.get_global_rect()),id+" panel within viewport")
 var context_count: int=labels.filter(func(l):return l.context).size()
 check(context_count==(1 if game.mode=="level" else 0),id+" correct mode-gated context count")
 check(v.find_children("*","Button",true,false).size()==1,id+" no new modal button")
 rows.append({"id":id,"mode":game.mode,"panel":rect_dict(p.get_global_rect()),"labels":labels})
func run():
 root.size=Vector2i(1440,900);Engine.max_fps=240
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 await inspect("title_baseline")
 for item in game.levels:
  game.start_level(item)
  await inspect(str(item.id))
 game.show_world_menu("city",5);await inspect("world_after_level")
 game.show_hub();await inspect("hub_after_level")
 game.show_title();await inspect("title_after_level")
 var report={"passed":failures.is_empty(),"assertions":checks,"failures":failures,"viewport":[1440,900],"engine":Engine.get_version_info().string,"rows":rows,"scope":"Final production show_help/context formatter and all 204 actual start_level HUDs; headless Label/Container geometry with real installed font. Not screenshot QA."}
 var file:=FileAccess.open("res://tests/context_help_audit/layout.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 print("CONTEXT_HELP_LAYOUT ",JSON.stringify({"passed":report.passed,"rows":rows.size(),"assertions":checks,"failures":failures}))
 await game.finish_exit(0 if failures.is_empty() else 1)
