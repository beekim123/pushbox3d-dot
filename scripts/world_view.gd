class_name AtelierWorld
extends Node3D

const THEMES := {
	"hub": {"accent":Color("e8bd79"), "sky":Color("536b84"), "light":Color("ffe3b1")},
	"heaven": {"accent":Color("f5b4bd"), "sky":Color("b9dace"), "light":Color("fff1d9")},
	"inferno": {"accent":Color("ffb77c"), "sky":Color("554567"), "light":Color("ffd8c1")},
	"rainforest": {"accent":Color("c1e981"), "sky":Color("408b86"), "light":Color("fff1b6")},
	"city": {"accent":Color("f3c66f"), "sky":Color("7ba8b9"), "light":Color("ffe6be")},
	"confluence": {"accent":Color("d1b5f3"), "sky":Color("747aa4"), "light":Color("fff2d6")}
}
# Restrained theme backdrops keep the authored diorama separate from the void.
const BACKDROP_TONES := {
	"hub": Color("65758a"), "heaven": Color("73998e"),
	"inferno": Color("62576e"), "rainforest": Color("527f79"),
	"city": Color("708c9b"), "confluence": Color("73788f")
}
var camera: Camera3D
var set_root: Node3D
var dynamic_root: Node3D
var hero: Node3D
var crate_nodes: Dictionary = {}
var gate_nodes: Array[Node3D] = []
var origin := Vector3.ZERO
var current_world := "hub"
var current_level: Dictionary = {}
var model_cache: Dictionary = {}
var missing_assets: Dictionary = {}
var animation: AnimationPlayer
var hero_facing := 0.0
var environment: WorldEnvironment
var light: DirectionalLight3D

func _ready() -> void:
	set_root = Node3D.new()
	add_child(set_root)
	dynamic_root = Node3D.new()
	add_child(dynamic_root)
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = THEMES.hub.sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e7ff")
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.90
	environment.environment = env
	add_child(environment)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-32,0)
	light.light_energy = 0.60
	light.light_color = Color("fff0d5")
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 70
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.shadow_bias = 0.04
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35,145,0)
	fill.light_energy = 0.055
	fill.light_color = Color("b7d2ff")
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 160
	camera.current = true
	add_child(camera)

func model(asset: String, parent: Node3D, at: Vector3 = Vector3.ZERO, scale_factor: float = 1.0) -> Node3D:
	var path := "res://assets/models/"+asset+".glb"
	if not model_cache.has(path):
		if ResourceLoader.exists(path): model_cache[path] = load(path)
		else:
			missing_assets[asset] = true
			return null
	var n: Node3D = model_cache[path].instantiate()
	parent.add_child(n)
	n.position = at
	n.scale *= scale_factor
	n.set_meta("batchable", not (asset.ends_with("_creature") or asset.ends_with("_portal")))
	if asset.ends_with("_creature") or asset.ends_with("_portal"):
		var player := find_animation(n)
		if player:
			for clip in player.get_animation_list():
				if str(clip).to_lower().ends_with("idle"):
					player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
					player.play(clip)
	return n

func clear() -> void:
	for c in set_root.get_children():
		set_root.remove_child(c)
		c.queue_free()
	for c in dynamic_root.get_children():
		dynamic_root.remove_child(c)
		c.queue_free()
	crate_nodes.clear()
	gate_nodes.clear()
	hero = null
	animation = null

func theme_world(world: String) -> void:
	current_world = world
	var t: Dictionary = THEMES.get(world,THEMES.hub)
	environment.environment.background_color = t.sky.lerp(BACKDROP_TONES.get(world,BACKDROP_TONES.hub),0.22)
	light.light_color = t.light

func grid_pos(p: Vector2i) -> Vector3:
	return Vector3(p.x*2.0,0,p.y*2.0)+origin

func setup_hub() -> void:
	clear()
	theme_world("hub")
	origin = Vector3.ZERO
	if ResourceLoader.exists("res://assets/models/hub_landscape.glb"): model("hub_landscape",set_root)
	for x in range(-5,6):
		for z in range(-5,6):
			if x==0 or z==0 or (abs(x)<=1 and abs(z)<=1):
				model("hub_tile",set_root,Vector3(x*2,0,z*2))
	model("hub_center",set_root,Vector3(0,0,-0.5))
	var worlds := ["heaven","inferno","rainforest","city"]
	var positions := [Vector3(0,0,-10),Vector3(0,0,10),Vector3(-10,0,0),Vector3(10,0,0)]
	for i in range(4):
		var w: String = worlds[i]
		var pos: Vector3 = positions[i]
		if ResourceLoader.exists("res://assets/models/"+w+"_landscape.glb"):
			var island:=model(w+"_landscape",set_root,pos)
			island.scale=Vector3(0.42,0.6,0.42)
		else:
			for a in [-1,0,1]:
				for b in [-1,0,1]: model(w+"_tile",set_root,pos+Vector3(a*2,0,b*2))
		model(w+"_landmark",set_root,pos+Vector3(0,0,-1.5),0.65)
		model(w+"_decor_a",set_root,pos+Vector3(-2.5,0,0.6),0.7)
		model(w+"_creature",set_root,pos+Vector3(2,0,1.4),0.8)
	model("hub_decor_a",set_root,Vector3(-3,0,3),0.8)
	model("hub_decor_b",set_root,Vector3(3,0,-3),0.8)
	hero = model("courier",dynamic_root,Vector3(0,0,3))
	connect_animation()
	play_animation("idle")
	camera.size = 31
	camera.position = Vector3(8,30,27)
	camera.look_at(Vector3(0,0,0))
	batch_static_geometry()

func setup_level(level: Dictionary, state: Dictionary) -> void:
	clear()
	current_level = level
	var world: String = level.world
	theme_world(world)
	var asset_world: String = str(level.get("visual_world","heaven")) if world == "confluence" else world
	var width := int(level.width)
	var height := int(level.height)
	origin = Vector3(-(width-1),0,-(height-1))
	var walls := PuzzleRules.cells(level.walls)
	var has_landscape := ResourceLoader.exists("res://assets/models/"+asset_world+"_landscape.glb")
	if has_landscape:
		var landscape:=model(asset_world+"_landscape",set_root)
		landscape.scale=Vector3(float(width)/7.0,1.0,float(height)/7.0)
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x,y)
			var pos := grid_pos(p)
			if p not in walls or not has_landscape:
				var tile:=model(asset_world+"_tile",set_root,pos)
				if tile: tile.rotation.y=float((x*7+y*3)%4)*PI/2
			var boundary:=x==0 or y==0 or x==width-1 or y==height-1
			var corner:=(x==0 or x==width-1) and (y==0 or y==height-1)
			var draw_wall:=p in walls and (not has_landscape or not boundary or corner or (x+y)%3==0)
			if draw_wall:
				var wall_asset:=asset_world+"_wall"
				if (x+y)%3==0 and ResourceLoader.exists("res://assets/models/"+wall_asset+"_b.glb"): wall_asset+="_b"
				var wall:=model(wall_asset,set_root,pos)
				if wall:
					wall.rotation.y=float((x*3+y*7)%4)*PI/2
					if has_landscape and boundary: wall.scale.y=0.48
			if y==height-1 and not has_landscape:
				model(asset_world+"_edge",set_root,pos+Vector3(0,-0.25,0.9))
	for g in PuzzleRules.cells(level.goals): model(asset_world+"_goal",set_root,grid_pos(g)+Vector3(0,0.02,0))
	for g in PuzzleRules.cells(level.get("glide",[])): model("heaven_glide",set_root,grid_pos(g)+Vector3(0,0.035,0))
	for pair in level.get("portals",[]):
		for g in pair: model("inferno_portal",set_root,grid_pos(PuzzleRules.cell(g))+Vector3(0,0.04,0))
	for a in level.get("arrows",[]):
		var arrow := model("rainforest_arrow",set_root,grid_pos(PuzzleRules.cell(a.cell))+Vector3(0,0.05,0))
		if arrow:
			arrow.rotation.y = {"U":PI,"D":0.0,"L":-PI/2,"R":PI/2}[str(a.dir)]
	for g in PuzzleRules.cells(level.get("plates",[])): model("city_plate",set_root,grid_pos(g)+Vector3(0,0.05,0))
	for g in PuzzleRules.cells(level.get("gates",[])):
		var gate := model("city_gate",dynamic_root,grid_pos(g))
		if gate: gate_nodes.append(gate)
	# Asymmetrical landscape clusters sit beyond the logical grid. No prop masks a legal cell.
	var half_w := float(width)
	var half_h := float(height)
	if not has_landscape:
		# Legacy support until the corresponding newly authored Blender landscape is imported.
		for x in range(-1,width+1):
			for z in [-2,-1]: model(asset_world+"_tile",set_root,Vector3(x*2-(width-1),-0.18,z*2-(height-1)))
		for side in [-1,1]:
			for z in range(-1,height): model(asset_world+"_tile",set_root,Vector3(side*(half_w+1),-0.18,z*2-(height-1)))
	# Five authored perimeter arrangements repeat across paired chapters, never random scatter.
	var vignette:=posmod(int(level.get("chapter",1))-1,5)
	var arrangements:=[[-1.0,0.6,0.88,0.68],[1.0,1.3,0.80,0.62],[-1.0,-0.2,0.94,0.54],[1.0,0.4,0.86,0.72],[-1.0,1.4,0.82,0.78]]
	var arrangement: Array=arrangements[vignette]
	var main_side:=float(arrangement[0])
	var landmark:=model(asset_world+"_landmark",set_root,Vector3(main_side*(half_w+(1.65 if asset_world=="heaven" else 1.0)),-0.03,-half_h+float(arrangement[1])+(2.5 if asset_world=="city" else 0.0)),float(arrangement[2])*(0.85 if asset_world=="city" else (1.27 if asset_world=="heaven" else 1.0)))
	if landmark: landmark.rotation.y=(PI if main_side>0 else 0.0)-0.2*main_side
	var alternate:=asset_world+"_landmark_b"
	if not ResourceLoader.exists("res://assets/models/"+alternate+".glb"): alternate=asset_world+"_decor_a"
	var second:=model(alternate,set_root,Vector3(-main_side*(half_w+(0.8 if asset_world=="heaven" else 2.2)),-0.03,-half_h+1.7),minf(float(arrangement[3]),0.65) if asset_world=="rainforest" else float(arrangement[3]))
	if second: second.rotation.y=0.45+(PI if main_side>0 else 0.0)
	var clusters:=[
		["_decor_b",Vector3(-half_w-0.7,-0.03,half_h-2.2),0.62,0.7],
		["_decor_b",Vector3(half_w+0.6,-0.03,half_h-0.8),0.46,-0.4],
		["_decor_a",Vector3(-half_w*0.12,-0.03,-half_h-1.0),0.78,0.5]
	]
	for item in clusters:
		var prop:=model(asset_world+str(item[0]),set_root,item[1],float(item[2]))
		if prop: prop.rotation.y=float(item[3])+float(vignette)*0.22
	if ResourceLoader.exists("res://assets/models/"+asset_world+"_decor_c.glb"):
		model(asset_world+"_decor_c",set_root,Vector3(half_w+0.9,-0.03,0.8),0.75)
	model(asset_world+"_creature",set_root,Vector3(half_w+0.5,0,half_h-2.4),0.75)
	if world=="confluence":
		for i in range(4):
			var w: String = ["heaven","inferno","rainforest","city"][i]
			model(w+"_decor_b",set_root,Vector3((i-1.5)*3,-0.03,-half_h-1.2),0.48)
	for p in state.crates:
		var n := model(asset_world+"_crate",dynamic_root,grid_pos(p))
		if n: crate_nodes[p] = n
	hero = model("courier",dynamic_root,grid_pos(state.player))
	connect_animation()
	play_animation("idle")
	update_gates(state,true)
	camera.size = maxf(width*2.0+8.5,height*2.0+6.0)
	camera.position = Vector3(8,26,24)
	camera.look_at(Vector3(0,0,0.5))
	batch_static_geometry()
	fit_level_camera()

func connect_animation() -> void:
	animation = find_animation(hero)

func find_animation(n: Node) -> AnimationPlayer:
	if not n: return null
	if n is AnimationPlayer: return n
	for child in n.get_children():
		var found := find_animation(child)
		if found: return found
	return null

func play_animation(clip: String) -> void:
	if not animation: return
	for name in animation.get_animation_list():
		if str(name).to_lower().ends_with(clip) or str(name).to_lower()==clip:
			animation.get_animation(name).loop_mode=Animation.LOOP_LINEAR if clip in ["idle","walk"] else Animation.LOOP_NONE
			animation.play(name,0.08)
			return

func update_gates(state: Dictionary, immediate: bool = false) -> void:
	var open := PuzzleRules.gates_open(current_level,state)
	for n in gate_nodes:
		if n.has_meta("open") and n.get_meta("open")==open and not immediate: continue
		n.set_meta("open",open)
		var player:=find_animation(n)
		if player:
			var target:="open" if open else "close"
			for clip in player.get_animation_list():
				if str(clip).to_lower().ends_with(target):
					player.get_animation(clip).loop_mode=Animation.LOOP_NONE
					player.play(clip)
					if immediate: player.seek(player.get_animation(clip).length,true)
					break

func sync_state(state: Dictionary) -> void:
	for n in crate_nodes.values():
		dynamic_root.remove_child(n)
		n.queue_free()
	crate_nodes.clear()
	var asset_world: String = str(current_level.get("visual_world","hub")) if current_world == "confluence" else current_world
	for p in state.crates:
		var n := model(asset_world+"_crate",dynamic_root,grid_pos(p))
		if n: crate_nodes[p] = n
	if hero: hero.position = grid_pos(state.player)
	update_gates(state,true)
	play_animation("idle")

func animate_move(old_state: Dictionary, state: Dictionary, direction: String) -> Tween:
	var tween := create_tween().set_parallel(true)
	var d: Vector2i = PuzzleRules.DIRS[direction]
	if hero:
		hero_facing = atan2(d.x,d.y)
		tween.tween_property(hero,"rotation:y",hero_facing,0.09)
		tween.tween_property(hero,"position",grid_pos(state.player),0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	play_animation("push" if state.get("pushed",false) else "walk")
	if state.get("pushed",false):
		var old_p: Vector2i = state.old_box
		var new_p: Vector2i = state.new_box
		if crate_nodes.has(old_p):
			var box: Node3D = crate_nodes[old_p]
			crate_nodes.erase(old_p)
			crate_nodes[new_p] = box
			var route: Array = state.get("route",[new_p])
			var elapsed := 0.0
			var previous := old_p
			for point in route:
				var destination := PuzzleRules.cell(point)
				if previous.distance_to(destination)>1.1:
					# Portal is a disappearance/reappearance, never travel through walls.
					tween.tween_callback(func(): box.visible=false).set_delay(elapsed)
					elapsed += 0.12
					var arrival := grid_pos(destination)
					tween.tween_callback(func():
						box.position=arrival
						box.visible=true
					).set_delay(elapsed)
				else:
					var duration := 0.16 if route.size()==1 else 0.10
					tween.tween_property(box,"position",grid_pos(destination),duration).set_delay(elapsed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					elapsed += duration
				previous=destination
	tween.chain().tween_callback(func():
		update_gates(state)
		play_animation("idle")
	)
	return tween

func batch_static_geometry() -> void:
	# Hardware instance repeated Blender-authored meshes; no runtime mesh creation.
	var groups: Dictionary={}
	for root in set_root.get_children():
		if not root.get_meta("batchable",false): continue
		for node in root.find_children("","MeshInstance3D",true,false):
			var mesh_node: MeshInstance3D=node
			if not mesh_node.mesh or mesh_node.skin: continue
			var key:=str(mesh_node.mesh.get_rid())+str(mesh_node.material_override)
			if not groups.has(key): groups[key]=[]
			groups[key].append(mesh_node)
	for group in groups.values():
		if group.size()<2: continue
		var source: MeshInstance3D=group[0]
		var multimesh:=MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=source.mesh
		multimesh.instance_count=group.size()
		var instance:=MultiMeshInstance3D.new()
		instance.multimesh=multimesh
		instance.material_override=source.material_override
		instance.cast_shadow=source.cast_shadow
		set_root.add_child(instance)
		for i in range(group.size()):
			var n: MeshInstance3D=group[i]
			multimesh.set_instance_transform(i,set_root.global_transform.affine_inverse()*n.global_transform)
			n.visible=false

func fit_level_camera() -> void:
	# Fit imported geometry once after assembly; never zoom continuously during play.
	# Individual MultiMesh bounds avoid the empty corners of a giant combined AABB.
	var points: PackedVector3Array=[]
	for node in find_children("","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		if node is MeshInstance3D and node.mesh:
			append_bounds(points,node.mesh.get_aabb(),node.global_transform)
		elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
			for i in range(node.multimesh.instance_count):
				append_bounds(points,node.multimesh.mesh.get_aabb(),node.global_transform*node.multimesh.get_instance_transform(i))
	if points.is_empty(): return
	var screen:=get_viewport().get_visible_rect().size
	if screen.x<2 or screen.y<2: return
	# HUD ends at 88/900 and begins at 802/900. Reserve another 4% breathing room.
	var safe:=Rect2(Vector2(screen.x*0.06,screen.y*0.14),Vector2(screen.x*0.88,screen.y*0.71))
	var bounds:=projected_bounds(points)
	var ratio:=maxf(bounds.size.x/safe.size.x,bounds.size.y/safe.size.y)
	# The landscape may not reduce playable cells to postage stamps.
	# Extreme props are moved/scaled in the authored perimeter instead.
	camera.size*=clampf(ratio,1.0,1.29)
	camera.force_update_transform()
	bounds=projected_bounds(points)
	var shift:=camera.project_position(bounds.get_center(),10.0)-camera.project_position(safe.get_center(),10.0)
	camera.global_position+=shift
	camera.force_update_transform()
	camera.set_meta("fit_bounds",projected_bounds(points))
	camera.set_meta("fit_safe",safe)

func append_bounds(points: PackedVector3Array, box: AABB, transform: Transform3D) -> void:
	for i in range(8): points.append(transform*box.get_endpoint(i))

func projected_bounds(points: PackedVector3Array) -> Rect2:
	var rect:=Rect2(camera.unproject_position(points[0]),Vector2.ZERO)
	for point in points: rect=rect.expand(camera.unproject_position(point))
	return rect
