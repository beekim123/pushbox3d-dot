extends SceneTree
const RULES=preload("res://scripts/puzzle_rules.gd")
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var failures:=0
 var checked:=0
 for entry in game.levels:
  game.start_level(entry)
  game.toggle_hint()
  for scenario in [["clue",1],["running",1],["already_solved",1],["budget_exhausted",1],["unsolvable",1],["invalid",1],["solved",2],["solved",3]]:
   # Layout fixtures exercise real text templates; no fabricated screenshot or gameplay result.
   game.hint_status=scenario[0]
   game.hint_tier=scenario[1]
   game.hint_answer={"direction":"D"}
   game.build_hint_panel()
   await process_frame
   var panel: Rect2=game.hint_panel.get_global_rect()
   var walls=RULES.cells(entry.walls)
   for y in range(int(entry.height)):
    for x in range(int(entry.width)):
     var cell:=Vector2i(x,y)
     if cell in walls: continue
     var center: Vector3=game.world.grid_pos(cell)
     var corners: Array[Vector3]=[Vector3(-0.95,0,-0.95),Vector3(0.95,0,-0.95),Vector3(-0.95,0,0.95),Vector3(0.95,0,0.95)]
     var bounds:=Rect2(game.world.camera.unproject_position(center+corners[0]),Vector2.ZERO)
     for corner in corners: bounds=bounds.expand(game.world.camera.unproject_position(center+corner))
     if panel.intersects(bounds):
      failures+=1
      print("HINT_LAYOUT_OVERLAP ",entry.id," scenario=",scenario," cell=",cell)
   checked+=1

 print("HINT_LAYOUT scenarios=",checked," legal_cell_overlaps=",failures)
 await game.finish_exit(0 if failures==0 else 1)
