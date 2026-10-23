class_name PuzzleRules
extends RefCounted

const DIRS := {"U": Vector2i(0,-1), "D": Vector2i(0,1), "L": Vector2i(-1,0), "R": Vector2i(1,0)}

static func cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	return Vector2i(int(v[0]), int(v[1]))

static func cells(v: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in v: result.append(cell(p))
	return result

static func initial(level: Dictionary) -> Dictionary:
	return {"player":cell(level.player), "crates":cells(level.crates), "moves":0, "pushes":0}

static func gates_open(level: Dictionary, state: Dictionary) -> bool:
	for p in cells(level.get("plates", [])):
		if p in state.crates: return true
	return false

static func passable(level: Dictionary, p: Vector2i, direction: String, open: bool) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= int(level.width) or p.y >= int(level.height): return false
	if p in cells(level.walls): return false
	if p in cells(level.get("gates", [])) and not open: return false
	for arrow in level.get("arrows", []):
		if cell(arrow.cell) == p and str(arrow.dir) != direction: return false
	return true

static func step(level: Dictionary, state: Dictionary, direction: String) -> Dictionary:
	if not DIRS.has(direction): return {}
	var d: Vector2i = DIRS[direction]
	var p: Vector2i = state.player + d
	var open := gates_open(level,state)
	if not passable(level,p,direction,open): return {}
	var crates: Array[Vector2i] = []
	for c in state.crates: crates.append(cell(c))
	var pushed := false
	var route: Array[Vector2i] = []
	var old_box := Vector2i(-99,-99)
	var new_box := Vector2i(-99,-99)
	if p in crates:
		pushed = true
		old_box = p
		var target := p + d
		if not passable(level,target,direction,open) or target in crates: return {}
		route.append(target)
		var glide := cells(level.get("glide", []))
		while target in glide:
			var next := target + d
			if not passable(level,next,direction,open) or next in crates: break
			target = next
			route.append(target)
		for pair in level.get("portals", []):
			var a := cell(pair[0])
			var b := cell(pair[1])
			var exit := Vector2i(-99,-99)
			if target == a: exit = b
			elif target == b: exit = a
			if exit.x != -99:
				if not passable(level,exit,direction,open) or exit in crates or exit == p: return {}
				target = exit
				route.append(target)
				break
		crates[crates.find(p)] = target
		new_box = target
	var result := {"player":p, "crates":crates, "moves":int(state.get("moves",0))+1, "pushes":int(state.get("pushes",0))+(1 if pushed else 0)}
	if not gates_open(level,result):
		var gates := cells(level.get("gates", []))
		if p in gates: return {}
		for c in crates:
			if c in gates: return {}
	result["pushed"] = pushed
	result["old_box"] = old_box
	result["new_box"] = new_box
	result["route"] = route
	return result

static func won(level: Dictionary, state: Dictionary) -> bool:
	var goals := cells(level.goals)
	for c in state.crates:
		if c not in goals: return false
	return state.crates.size() == goals.size()

static func serial(state: Dictionary) -> Dictionary:
	var arr: Array = []
	for c in state.crates: arr.append([c.x,c.y])
	arr.sort_custom(func(a,b): return a[1]*100+a[0] < b[1]*100+b[0])
	return {"player":[state.player.x,state.player.y],"crates":arr}
