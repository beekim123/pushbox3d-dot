extends "res://tests/hint_ui_audit.gd"
var overlap_records: Array=[]
var legal_cells:=0
var annotations:=0
var templates:=0
func bounds(points: Array) -> Rect2:
	var area:=Rect2(points[0],Vector2.ZERO)
	for point in points: area=area.expand(point)
	return area
func overlap(panel: Rect2,area: Rect2,kind: String,id: String,cell: Vector2i,tier: int,direction: String="") -> void:
	if panel.intersects(area):
		overlap_records.append({"level":id,"cell":[cell.x,cell.y],"tier":tier,"direction":direction,"kind":kind,"panel":str(panel),"area":str(area)})
func screen_point(cell: Vector2i,elevation: float) -> Vector2:
	return game.world.camera.unproject_position(game.world.grid_pos(cell)+Vector3(0,elevation,0))
func run() -> void:
	Engine.max_fps=240
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	solver_instance=game.hints.get_instance_id()
	for entry in game.levels:
		game.start_level(entry)
		game.toggle_hint()
		var walls:=Rules.cells(entry.walls)
		for scenario in [["clue",1],["running",1],["already_solved",1],["budget_exhausted",1],["unsolvable",1],["invalid",1],["solved",2],["solved",3]]:
			# Real UI text-template layout only; not fabricated solver results.
			game.hint_status=scenario[0]
			game.hint_tier=scenario[1]
			game.hint_answer={"direction":"D"}
			game.build_hint_panel()
			await process_frame
			await process_frame
			templates+=1
			var panel: Rect2=game.hint_panel.get_global_rect()
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(panel),"template panel in viewport "+entry.id+" "+str(scenario))
			for y in int(entry.height):
				for x in int(entry.width):
					var cell:=Vector2i(x,y)
					if cell in walls: continue
					legal_cells+=1
					var center: Vector3=game.world.grid_pos(cell)
					var corners: Array=[]
					for delta in [Vector3(-.95,.12,-.95),Vector3(.95,.12,-.95),Vector3(.95,.12,.95),Vector3(-.95,.12,.95)]: corners.append(game.world.camera.unproject_position(center+delta))
					overlap(panel,bounds(corners),"legal_floor_aabb",entry.id,cell,scenario[1])
					if scenario[1]<2: continue
					annotations+=1
					var box_center:=screen_point(cell,.75)
					overlap(panel,Rect2(box_center-Vector2(27,27),Vector2(54,54)),"potential_box_ring",entry.id,cell,scenario[1])
					if scenario[1]>=3:
						var stand:=screen_point(cell,.12)
						overlap(panel,Rect2(stand-Vector2(14,14),Vector2(28,28)),"potential_stand_ring",entry.id,cell,scenario[1])
					for action in ["U","D","L","R"]:
						var next: Vector2i=cell+Rules.DIRS[action]
						var behind: Vector2i=cell-Rules.DIRS[action]
						if next.x<0 or next.y<0 or next.x>=entry.width or next.y>=entry.height or next in walls: continue
						if behind.x<0 or behind.y<0 or behind.x>=entry.width or behind.y>=entry.height or behind in walls: continue
						# Ignore dynamic crates/gate closure: conservative superset of possible pushes.
						var direction: Vector2=(screen_point(next,.75)-box_center).normalized()
						var start:=box_center+direction*27
						var tip:=box_center+direction*61
						var extent:=bounds([start,tip,tip-direction.rotated(.55)*14,tip-direction.rotated(-.55)*14]).grow(5)
						overlap(panel,extent,"potential_next_push_arrow",entry.id,cell,scenario[1],action)
	check(templates==204*8,"all 204 levels and eight real templates inspected")
	check(overlap_records.is_empty(),"all tested panels avoid legal floors and conservative hint annotation extents")
	var report: Dictionary={"passed":failures.is_empty(),"assertions":checks,"failures":failures,"levels":game.levels.size(),"templates":templates,"projected_legal_cells":legal_cells,"potential_box_stand_samples":annotations,"overlaps":overlap_records,"engine":Engine.get_version_info().string,"scope":"Actual production camera and panel geometry at1440x900; eight text-template fixtures, not204 solved-gameplay results. Includes floor AABBs and conservative ring/arrow extents on all legal cells."}
	var file:=FileAccess.open("res://tests/hint_ui_audit_layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("HINT_UI_LAYOUT_AUDIT ",JSON.stringify({"passed":report.passed,"assertions":checks,"templates":templates,"projected_legal_cells":legal_cells,"overlap_count":overlap_records.size(),"failures":failures}))
	await game.finish_exit(0 if failures.is_empty() else 1)
