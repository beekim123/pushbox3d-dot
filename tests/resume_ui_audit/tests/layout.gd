extends "res://audit_tests/base.gd"
var overlaps:Array=[]
var templates:=0
var cells:=0
func bounds(points:Array) -> Rect2:
 var r:=Rect2(points[0],Vector2.ZERO)
 for point in points:r=r.expand(point)
 return r
func run() -> void:
 mode="layout"
 await boot();game.initialize_resume("user://audit_layout");game.set_process(false)
 for entry in game.levels:
  game.start_level(entry);var walls:=Rules.cells(entry.walls)
  for scenario in ["pending","saving","saved","paused","history_limit","budget_exhausted","not_saved"]:
   game.resume_session.reading=false;game.resume_session.paused=scenario=="paused";game.resume_session.writing=scenario=="saving";game.resume_session.dirty=scenario=="pending";game.resume_session.saved_revision=1
   game.resume_session.status="not_saved" if scenario in ["history_limit","budget_exhausted","not_saved"] else scenario
   game.resume_session.failure_kind=scenario
   game.refresh_resume_ui();await process_frame;await process_frame;templates+=1
   var label:Label=game.resume_label;var footer:Control=label.get_parent().get_parent().get_parent();var rect:=footer.get_global_rect();var viewport:=Rect2(Vector2.ZERO,Vector2(root.size))
   ck(viewport.encloses(rect),entry.id+" "+scenario+" footer within viewport")
   ck(rect.encloses(label.get_global_rect()),entry.id+" "+scenario+" status line inside footer")
   for child in footer.find_children("","Control",true,false):
    if child is Button or child is Label:ck(rect.encloses(child.get_global_rect()) and viewport.encloses(child.get_global_rect()),"footer label/button enclosed")
   for y in int(entry.height):
    for x in int(entry.width):
     var cell:=Vector2i(x,y)
     if cell in walls:continue
     cells+=1;var center:Vector3=game.world.grid_pos(cell);var points:Array=[]
     for delta in [Vector3(-.95,.12,-.95),Vector3(.95,.12,-.95),Vector3(.95,.12,.95),Vector3(-.95,.12,.95)]:points.append(game.world.camera.unproject_position(center+delta))
     if rect.intersects(bounds(points)):overlaps.append({"level":entry.id,"status":scenario,"cell":[x,y]})
 ck(templates==game.levels.size()*7,"all recovered levels and seven actual status text templates")
 ck(overlaps.is_empty(),"footer avoids projected legal-floor bounds")
 report("layout.json",{"levels":game.levels.size(),"templates":templates,"projected_legal_cells":cells,"overlaps":overlaps,"scope":"Actual camera/footer geometry at1440x900. Text fixtures, not fabricated successful save operations."})
 game.set_process(true);await game.finish_exit(0 if failures.is_empty() else 1)
