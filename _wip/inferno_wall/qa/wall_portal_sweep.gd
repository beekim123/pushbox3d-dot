extends SceneTree
# QA-only exact wall mesh rays. No runtime source, materials or camera changes.
const VIEW=preload("res://scripts/world_view.gd")
const RULES=preload("res://scripts/puzzle_rules.gd")
var output:=""
var failures:Array=[]
var counts:Dictionary={"legal_cell_centers":0,"neighbor_legal_cell_centers":0,"goal_ring_samples":0,"goal_tooth_samples":0,"portal_glyph_samples":0,"wall_mesh_triangle_tests":0}
var wall_meshes:Array=[]
var view
var envelopes:Array=[]
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
  for asset in view.set_root.get_children():
   if str(asset.scene_file_path).get_file()!="inferno_portal.glb":continue
   var center:Vector3=asset.global_position;var radius:=0.0;var minimum_y:=100.0
   for node in asset.find_children("","MeshInstance3D",true,false):
    for surface in range(node.mesh.get_surface_count()):
     var material:Material=node.mesh.surface_get_material(surface)
     if material==null or not material.resource_name.ends_with("glow"):continue
     var vertices:PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
     for v in vertices:
      var point:Vector3=node.global_transform*v
      radius=maxf(radius,Vector2(point.x-center.x,point.z-center.z).length());minimum_y=minf(minimum_y,point.y)
   if radius<=0 or minimum_y>1.0:failures.append({"level":level.id,"error":"Invalid imported portal envelope"});continue
   envelopes.append({"level":level.id,"radius":radius,"minimum_y":minimum_y})
   # Full rotation of original glow geometry stays inside this disk; authored
   # animation only bobs upward 0..0.045. Sample the conservative lowest disk.
   for ring in range(5):
    for i in range(144):
     var angle:float=TAU*i/144.0;var r:float=radius*ring/4.0
     check_point(level.id,"portal_glyph_samples",Vector3(center.x+cos(angle)*r,minimum_y,center.z+sin(angle)*r))
  records.append({"level":level.id,"wall_meshes":wall_meshes.size(),"occluded_samples":failures.size()-before})
  await process_frame
 view.queue_free();await process_frame
 var report={"passed":failures.is_empty(),"engine":Engine.get_version_info().string,"scope":"All inferno and inferno-skinned confluence levels at production 1440x900 camera. Legal-cell centers plus conservative full-rotation portal glyph disk sampled at 5 radii and144 angles at imported lowest Y. Radius/minY measured from actual imported glow vertices; original idle rotates360 degrees and bobs upward0..0.045. This is sampled swept-envelope evidence, not pixel-complete animation rendering.","levels":records.size(),"counts":counts,"failures":failures,"records":records,"imported_portal_envelopes":envelopes}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("INFERNO_WALL_OCCLUSION ",JSON.stringify({"passed":failures.is_empty(),"levels":records.size(),"counts":counts,"failures":failures.size()}))
 quit(0 if failures.is_empty() else 1)
