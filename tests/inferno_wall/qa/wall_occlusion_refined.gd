extends SceneTree
# QA-only exact wall mesh rays. No runtime source, materials or camera changes.
const VIEW=preload("res://scripts/world_view.gd")
const RULES=preload("res://scripts/puzzle_rules.gd")
var output:=""
var failures:Array=[]
var counts:Dictionary={"legal_cell_centers":0,"neighbor_legal_cell_centers":0,"goal_ring_samples":0,"goal_tooth_samples":0,"portal_glyph_samples":0,"wall_mesh_triangle_tests":0}
var wall_meshes:Array=[]
var view
func _initialize():
 for s in OS.get_cmdline_user_args():
  if s.begins_with("--output="):output=s.trim_prefix("--output=")
 call_deferred("run")
func gather_walls():
 wall_meshes.clear()
 for asset in view.set_root.get_children():
  if not str(asset.scene_file_path).get_file() in ["inferno_wall.glb","inferno_wall_b.glb"]:continue
  # Original hidden MeshInstances retain the exact transforms used by batching.
  for mesh_node in asset.find_children("","MeshInstance3D",true,false):
   var faces:PackedVector3Array=mesh_node.mesh.get_faces()
   var transform:Transform3D=mesh_node.global_transform
   var world_faces:PackedVector3Array=[]
   for v in faces:world_faces.append(transform*v)
   var bounds:AABB=transform*mesh_node.mesh.get_aabb()
   wall_meshes.append({"bounds":bounds,"faces":world_faces})
func check_point(level_id:String,kind:String,point:Vector3):
 counts[kind]+=1
 var from:Vector3=point+view.camera.global_basis.z*100.0
 for wall in wall_meshes:
  var bounds:AABB=wall.bounds
  if not bounds.intersects_segment(from,point):continue
  var faces:PackedVector3Array=wall.faces
  for i in range(0,faces.size(),3):
   counts.wall_mesh_triangle_tests+=1
   var hit=Geometry3D.segment_intersects_triangle(from,point,faces[i],faces[i+1],faces[i+2])
   if hit!=null:
    failures.append({"level":level_id,"sample":kind,"point":[point.x,point.y,point.z],"wall_hit":[hit.x,hit.y,hit.z]});return
func run():
 root.size=Vector2i(1440,900);view=VIEW.new();root.add_child(view);await process_frame
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"));var records:Array=[]
 for level in data.levels:
  var asset_world:String=str(level.get("visual_world","heaven")) if level.world=="confluence" else str(level.world)
  if asset_world!="inferno":continue
  view.setup_level(level,RULES.initial(level));gather_walls()
  if wall_meshes.is_empty():failures.append({"level":level.id,"error":"No wall mesh nodes found"})
  var walls=RULES.cells(level.walls);var before:int=failures.size()
  for y in range(int(level.height)):
   for x in range(int(level.width)):
    var cell:=Vector2i(x,y)
    if cell in walls:continue
    check_point(level.id,"legal_cell_centers",view.grid_pos(cell)+Vector3(0,.03,0))
    for d in RULES.DIRS.values():
     if cell+d in walls:
      counts.neighbor_legal_cell_centers+=1;break
  for cell in RULES.cells(level.goals):
   var center:Vector3=view.grid_pos(cell)
   # Outer ring silhouette sampled every 5 degrees at actual torus equator height.
   for i in range(72):
    var a:float=TAU*i/72.0
    check_point(level.id,"goal_ring_samples",center+Vector3(cos(a)*.535,.085,sin(a)*.535))
   # Four locator teeth: conservative unbeveled corner positions at actual top height.
   for i in range(4):
    var a:float=TAU*i/4.0
    for radial in [.555,.725]:
     for cross_offset in [-.06,.06]:
      check_point(level.id,"goal_tooth_samples",center+Vector3(cos(a)*radial-sin(a)*cross_offset,.12,sin(a)*radial+cos(a)*cross_offset))
  for pair in level.get("portals",[]):
   for cell in pair:
    var center:Vector3=view.grid_pos(RULES.cell(cell))
    # Every authored spiral control point and both tube-width extents.
    for i in range(43):
     var a:float=i*.25;var r:float=.05+i*.011
     for delta in [-.035,0,.035]:
      check_point(level.id,"portal_glyph_samples",center+Vector3(cos(a)*(r+delta),.16,-sin(a)*(r+delta)))
  records.append({"level":level.id,"wall_meshes":wall_meshes.size(),"occluded_samples":failures.size()-before})
  await process_frame
 view.queue_free();await process_frame
 var report={"passed":failures.is_empty(),"engine":Engine.get_version_info().string,"scope":"All inferno and inferno-skinned confluence levels at production 1440x900 camera. Rays from legal-cell centers and conservative goal ring/tooth and portal spiral samples toward orthographic camera against exact transformed wall triangles. Glyph sampling is not a whole-pixel proof; matched native frames independently reviewed.","levels":records.size(),"counts":counts,"failures":failures,"records":records}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("INFERNO_WALL_OCCLUSION ",JSON.stringify({"passed":failures.is_empty(),"levels":records.size(),"counts":counts,"failures":failures.size()}))
 quit(0 if failures.is_empty() else 1)
