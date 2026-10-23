class_name HintSolver
extends RefCounted
## Optional, non-moving, incremental exact push-macro Dijkstra.
## Configure once per level. start() always takes the CURRENT board, not a stored
## opening answer. Call step_budget(2.0, request_id) once per _process frame.
## Objective: lexicographic (remaining pushes, remaining player steps).
## Only `solved` carries a usable hint. `budget_exhausted` is NEVER a deadlock.
## All outputs are copies. No signals/threads, scene changes, input, or save IO.

const ACTIONS := ["U", "D", "L", "R"]
const DELTAS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const MAX_CELLS := 1024
const MAX_BOXES := 16
const HARD_MAX_STATES := 60000
const HARD_MAX_FRONTIER := 120000

var _width := 0
var _height := 0
var _count := 0
var _floor := PackedByteArray()
var _goals: Dictionary = {}
var _glide: Dictionary = {}
var _portals: Dictionary = {}
var _arrows: Dictionary = {}
var _plates: Dictionary = {}
var _gates: Dictionary = {}
var _neighbors: Array[PackedInt32Array] = []
var _configured := false
var _configuration_error := "No level configured"
var _level_revision := 0
var _request_id := 0
var _source_key := ""
var _status := "idle"
var _phase := ""
var _result: Dictionary = {}
var _max_states := 30000
var _max_frontier := 8000
var _max_compute_usec := 5000000
var _compute_usec := 0
var _last_slice_usec := 0
var _largest_slice_usec := 0
var _expanded := 0
var _generated := 0
var _nodes: Array[Dictionary] = []
var _best: Dictionary = {}
var _heap: Array[int] = []
var _initial: Dictionary = {}
var _current: Dictionary = {}
var _current_id := -1
var _occupied: Dictionary = {}
var _open := false
var _walk_queue := PackedInt32Array()
var _walk_seen := PackedInt64Array()
var _walk_distance := PackedInt32Array()
var _walk_parent := PackedInt32Array()
var _walk_action := PackedInt32Array()
var _walk_generation := 0
var _walk_tail := 0
var _walk_index := 0
var _push_index := 0
var _dead_ready := false
var _dead: Dictionary = {}
var _reverse: Array[Array] = []
var _dead_index := 0
var _reachable: Dictionary = {}
var _dead_queue: Array[int] = []
var _dead_head := 0
var _trace_id := -1
var _trace_parts: Array[String] = []
var _winner_id := -1
var _trace_first_part := ""
var _include_solution := false
var _profile_operations := false
var _largest_operation: Dictionary = {}
var _operation_spikes: Array[Dictionary] = []
var _cleanup_pending := false
var _cleanup_usec := 0

func configure(level: Dictionary) -> bool:
	# Bounded level compilation; search/preprocessing work happens in step_budget.
	cancel()
	_level_revision += 1
	_configured = false
	_dead_ready = false
	_dead.clear()
	_goals.clear()
	_glide.clear()
	_portals.clear()
	_arrows.clear()
	_plates.clear()
	_gates.clear()
	_neighbors.clear()
	_configuration_error = ""
	var raw_width: Variant = level.get("width", 0)
	var raw_height: Variant = level.get("height", 0)
	if not _finite_integer(raw_width) or not _finite_integer(raw_height):
		return _bad_level("Board dimensions must be finite integers")
	if float(raw_width) < 1.0 or float(raw_height) < 1.0 or float(raw_width) > 64.0 or float(raw_height) > 64.0:
		return _bad_level("Unsupported board dimensions (maximum 64 per side / 1024 cells)")
	_width = int(raw_width)
	_height = int(raw_height)
	_count = _width * _height
	if _count > MAX_CELLS:
		return _bad_level("Unsupported board dimensions (maximum 1024 cells)")
	var mechanic: Variant = level.get("mechanic", {})
	if not mechanic is Dictionary or not mechanic.get("type", "plain") is String:
		return _bad_level("Mechanic must be a dictionary with a string type")
	if mechanic.get("type", "plain") not in ["plain", "terrain"]:
		return _bad_level("Unsupported mechanic")
	for field in ["walls", "goals", "glide", "plates", "gates", "portals", "arrows"]:
		if not level.get(field, []) is Array:
			return _bad_level(field + " must be an array")
		var entries: int = level.get(field, []).size()
		if entries > _count or (field == "portals" and entries * 2 > _count):
			return _bad_level(field + " has more entries than the board can contain")
	_floor.resize(_count)
	_floor.fill(1)
	for raw in level.get("walls", []):
		var pos := _read_cell(raw)
		if pos < 0: return _bad_level("Wall outside board")
		if not _floor[pos]: return _bad_level("Duplicate wall cell")
		_floor[pos] = 0
	for pos in range(_count):
		var row := PackedInt32Array()
		for delta in DELTAS:
			var xy: Vector2i = _xy(pos) + delta
			row.append(xy.y * _width + xy.x if _inside(xy) else -1)
		_neighbors.append(row)
	for field in ["goals", "glide", "plates", "gates"]:
		var target: Dictionary = _goals if field == "goals" else (_glide if field == "glide" else (_plates if field == "plates" else _gates))
		for raw in level.get(field, []):
			var pos := _read_cell(raw)
			if pos < 0 or not _floor[pos] or target.has(pos):
				return _bad_level("Invalid or duplicate " + field + " cell")
			target[pos] = true
	if _goals.is_empty() or _goals.size() > MAX_BOXES:
		return _bad_level("Expected 1 to 16 goals")
	for pair in level.get("portals", []):
		if not pair is Array or pair.size() != 2: return _bad_level("Invalid portal pair")
		var a := _read_cell(pair[0])
		var b := _read_cell(pair[1])
		if a < 0 or b < 0 or a == b or not _floor[a] or not _floor[b] or _portals.has(a) or _portals.has(b) or _glide.has(a) or _glide.has(b):
			return _bad_level("Invalid / overlapping portal endpoint")
		_portals[a] = b
		_portals[b] = a
	for arrow in level.get("arrows", []):
		if not arrow is Dictionary or not arrow.get("dir", "") is String:
			return _bad_level("Each arrow must be a dictionary with a string direction")
		var pos := _read_cell(arrow.get("cell", null))
		var direction: int = ACTIONS.find(str(arrow.get("dir", "")))
		if pos < 0 or not _floor[pos] or direction < 0 or _arrows.has(pos): return _bad_level("Invalid arrow")
		_arrows[pos] = direction
	if not _gates.is_empty() and _plates.is_empty(): return _bad_level("Gates require a plate")
	_walk_queue.resize(_count)
	_walk_seen.resize(_count)
	_walk_seen.fill(0)
	_walk_distance.resize(_count)
	_walk_parent.resize(_count)
	_walk_action.resize(_count)
	_walk_generation = 0
	_configured = true
	_status = "idle"
	_result = {"status": _status, "request_id": _request_id}
	return true

func start(state: Dictionary, options: Dictionary = {}) -> int:
	_request_id += 1
	_clear_search()
	_source_key = ""
	_status = "running"
	_result = {}
	_include_solution = false
	_profile_operations = false
	for option in ["include_solution", "profile_operations"]:
		if options.has(option) and not options[option] is bool:
			_finish("invalid", option + " must be a bool")
			return _request_id
	_include_solution = options.get("include_solution", false)
	_profile_operations = options.get("profile_operations", false)
	for option in ["max_states", "max_frontier"]:
		if options.has(option) and (not _finite_integer(options[option]) or float(options[option]) < 0.0):
			_finish("invalid", option + " must be a finite non-negative integer")
			return _request_id
	var raw_time: Variant = options.get("max_compute_ms", 5000.0)
	if not _finite_number(raw_time) or float(raw_time) < 0.0:
		_finish("invalid", "max_compute_ms must be a finite non-negative number")
		return _request_id
	_max_states = int(minf(float(options.get("max_states", 30000)), float(HARD_MAX_STATES)))
	_max_frontier = int(minf(float(options.get("max_frontier", 8000)), float(HARD_MAX_FRONTIER)))
	_max_compute_usec = int(minf(float(raw_time), 30000.0) * 1000.0)
	if not _configured:
		_finish("invalid", _configuration_error)
		return _request_id
	_initial = _normalize(state)
	if _initial.is_empty():
		_finish("invalid", "State is not a legal non-overlapping board snapshot")
		return _request_id
	_source_key = _key(_initial.p, _initial.boxes)
	if _won(_initial.boxes):
		_finish("already_solved")
		return _request_id
	if _dead_ready:
		_phase = "seed"
	else:
		_reverse.resize(_count)
		for pos in range(_count): _reverse[pos] = []
		_phase = "dead_edges"
	return _request_id

func step_budget(milliseconds: float = 2.0, expected_request_id: int = -1) -> Dictionary:
	if expected_request_id >= 0 and expected_request_id != _request_id:
		return {"status": "stale", "request_id": expected_request_id, "current_request_id": _request_id}
	if _status != "running" and not _cleanup_pending: return get_result(expected_request_id)
	if not is_finite(milliseconds) or milliseconds <= 0.0: return get_result(expected_request_id)
	var began := Time.get_ticks_usec()
	var slice_limit := int(clampf(milliseconds, 0.01, 8.0) * 1000.0)
	# There is ONE retired container set, never a queue of old searches. New
	# requests replace the pending root but cannot allocate until this is empty.
	var had_cleanup := _cleanup_pending
	while _cleanup_pending and Time.get_ticks_usec() - began < slice_limit:
		_cleanup_tick()
	if had_cleanup: _cleanup_usec += Time.get_ticks_usec() - began
	var search_began := Time.get_ticks_usec()
	var did_search := false
	# Check every small operation, including each BFS cell and candidate push.
	# This is a soft wall-clock budget, not a hard real-time guarantee.
	while _status == "running" and not _cleanup_pending and Time.get_ticks_usec() - began < slice_limit:
		did_search = true
		if _compute_usec + Time.get_ticks_usec() - search_began >= _max_compute_usec:
			_finish("budget_exhausted", "compute_time_limit")
			break
		if _profile_operations:
			var operation_phase := _phase
			var operation_start := Time.get_ticks_usec()
			_tick()
			var operation_usec := Time.get_ticks_usec() - operation_start
			if operation_usec > int(_largest_operation.get("usec", -1)):
				_largest_operation = {"usec":operation_usec,"phase":operation_phase,"allocated_nodes":_nodes.size(),"walk_queue":_walk_tail,"heap_size":_heap.size()}
			if operation_usec >= 1000 and _operation_spikes.size() < 32:
				_operation_spikes.append({"usec":operation_usec,"phase":operation_phase,"allocated_nodes":_nodes.size(),"unix_usec":int(Time.get_unix_time_from_system()*1000000.0)})
		else:
			_tick()
	if did_search: _compute_usec += Time.get_ticks_usec() - search_began
	_last_slice_usec = Time.get_ticks_usec() - began
	_largest_slice_usec = maxi(_largest_slice_usec, _last_slice_usec)
	return get_result(expected_request_id)

func has_pending_cleanup() -> bool:
	return _cleanup_pending

func cancel() -> int:
	_request_id += 1
	_clear_search()
	_source_key = ""
	_status = "cancelled"
	_result = {"status": _status, "request_id": _request_id}
	return _request_id

func is_current(request: int, state: Dictionary) -> bool:
	if request != _request_id or not _configured or _source_key.is_empty(): return false
	var snapshot := _normalize(state)
	return not snapshot.is_empty() and _key(snapshot.p, snapshot.boxes) == _source_key

func get_result(expected_request_id: int = -1) -> Dictionary:
	if expected_request_id >= 0 and expected_request_id != _request_id:
		return {"status": "stale", "request_id": expected_request_id, "current_request_id": _request_id}
	var result := _result.duplicate(true)
	result["status"] = _status
	result["request_id"] = _request_id
	result["level_revision"] = _level_revision
	result["source_key"] = _source_key
	result["expanded_states"] = _expanded
	result["discovered_states"] = 0 if _cleanup_pending else _best.size()
	result["allocated_nodes"] = 0 if _cleanup_pending else _nodes.size()
	result["cleanup_pending"] = _cleanup_pending
	result["retired_nodes"] = _nodes.size() if _cleanup_pending else 0
	result["cleanup_ms"] = _cleanup_usec / 1000.0
	result["limits"] = {"max_states":_max_states,"max_frontier":_max_frontier,"max_compute_ms":_max_compute_usec / 1000.0}
	result["compute_ms"] = _compute_usec / 1000.0
	result["last_slice_ms"] = _last_slice_usec / 1000.0
	result["largest_slice_ms"] = _largest_slice_usec / 1000.0
	if _profile_operations:
		result["largest_operation"] = _largest_operation.duplicate(true)
		result["operation_spikes"] = _operation_spikes.duplicate(true)
	return result

func _tick() -> void:
	match _phase:
		"dead_edges": _dead_edge_tick()
		"dead_reach": _dead_reach_tick()
		"seed":
			if _has_dead(_initial.boxes):
				_finish("unsolvable", "relaxed_one_box_dead_square")
				return
			if _max_frontier == 0:
				_finish("budget_exhausted", "frontier_limit")
				return
			_add_node(_initial.p, _initial.boxes, 0, 0, -1, "", _source_key)
			_phase = "pop"
		"pop": _pop_tick()
		"walk": _walk_tick()
		"push": _push_tick()
		"trace": _trace_tick()

func _dead_edge_tick() -> void:
	# Optimistic reverse box graph: ignore arrows/gates, allow every glide prefix
	# to stop and portal endpoints to stay OR teleport. Only adds possibilities.
	if _dead_index >= _count * 4:
		for goal in _goals:
			_reachable[goal] = true
			_dead_queue.append(goal)
		_phase = "dead_reach"
		return
	var source := _dead_index / 4
	var direction := _dead_index % 4
	_dead_index += 1
	if not _floor[source]: return
	var opposite: int = [1, 0, 3, 2][direction]
	var behind := _neighbors[source][opposite]
	if behind < 0 or not _floor[behind]: return
	var target := _neighbors[source][direction]
	while target >= 0 and _floor[target]:
		_reverse[target].append(source)
		if _portals.has(target): _reverse[_portals[target]].append(source)
		if not _glide.has(target): break
		target = _neighbors[target][direction]

func _dead_reach_tick() -> void:
	if _dead_head >= _dead_queue.size():
		_dead.clear()
		for pos in range(_count):
			if _floor[pos] and not _reachable.has(pos): _dead[pos] = true
		_dead_ready = true
		_reverse.clear()
		_phase = "seed"
		return
	var target := _dead_queue[_dead_head]
	_dead_head += 1
	for source in _reverse[target]:
		if not _reachable.has(source):
			_reachable[source] = true
			_dead_queue.append(source)

func _pop_tick() -> void:
	if _heap.is_empty():
		_finish("unsolvable", "frontier_exhausted")
		return
	_current_id = _heap_pop()
	_current = _nodes[_current_id]
	if _best[_current.key] != _current_id: return
	if _won(_current.boxes):
		_winner_id = _current_id
		_trace_id = _current_id
		_phase = "trace"
		return
	if _expanded >= _max_states:
		_finish("budget_exhausted", "expanded_state_limit")
		return
	_expanded += 1
	_occupied.clear()
	_open = false
	for box in _current.boxes:
		_occupied[box] = true
		if _plates.has(box): _open = true
	_walk_generation += 1
	_walk_seen[_current.p] = _walk_generation
	_walk_distance[_current.p] = 0
	_walk_parent[_current.p] = -1
	_walk_action[_current.p] = -1
	_walk_queue[0] = _current.p
	_walk_tail = 1
	_walk_index = 0
	_push_index = 0
	_phase = "walk"

func _walk_tick() -> void:
	if _walk_index >= _walk_tail:
		_phase = "push"
		return
	var pos := _walk_queue[_walk_index]
	_walk_index += 1
	for direction in range(4):
		var target := _neighbors[pos][direction]
		if target < 0 or _occupied.has(target) or _walk_seen[target] == _walk_generation or not _enter(target, direction, _open): continue
		_walk_seen[target] = _walk_generation
		_walk_distance[target] = _walk_distance[pos] + 1
		_walk_parent[target] = pos
		_walk_action[target] = direction
		_walk_queue[_walk_tail] = target
		_walk_tail += 1

func _push_tick() -> void:
	if _push_index >= _current.boxes.size() * 4:
		_phase = "pop"
		return
	var box_index := _push_index / 4
	var direction := _push_index % 4
	_push_index += 1
	var box: int = _current.boxes[box_index]
	var opposite: int = [1, 0, 3, 2][direction]
	var behind := _neighbors[box][opposite]
	if behind < 0 or _walk_seen[behind] != _walk_generation or not _enter(box, direction, _open): return
	var target := _neighbors[box][direction]
	if not _enter(target, direction, _open) or _occupied.has(target): return
	while _glide.has(target):
		var next := _neighbors[target][direction]
		if not _enter(next, direction, _open) or _occupied.has(next): break
		target = next
	if _portals.has(target):
		target = _portals[target]
		if not _enter(target, direction, _open) or _occupied.has(target) or target == box: return
	var boxes: PackedInt32Array = _current.boxes.duplicate()
	boxes[box_index] = target
	# Post-push plate closure may not trap player (now at old box) or ANY crate.
	var still_open := false
	for item in boxes:
		if _plates.has(item): still_open = true
	if not still_open:
		if _gates.has(box): return
		for item in boxes:
			if _gates.has(item): return
	if _has_dead(boxes): return
	boxes.sort()
	var pushes: int = _current.pushes + 1
	var moves: int = _current.moves + _walk_distance[behind] + 1
	var key := _key(box, boxes)
	if _best.has(key):
		var old: Dictionary = _nodes[_best[key]]
		if pushes > old.pushes or (pushes == old.pushes and moves >= old.moves): return
	if _nodes.size() >= _max_frontier or _heap.size() >= _max_frontier:
		_finish("budget_exhausted", "frontier_limit")
		return
	var part: String = _walk_path(behind) + ACTIONS[direction]
	_add_node(box, boxes, pushes, moves, _current_id, part, key)

func _walk_path(pos: int) -> String:
	var parts := PackedStringArray()
	while _walk_parent[pos] >= 0:
		parts.append(ACTIONS[_walk_action[pos]])
		pos = _walk_parent[pos]
	parts.reverse()
	return "".join(parts)

func _trace_tick() -> void:
	var node := _nodes[_trace_id]
	if node.parent >= 0:
		_trace_first_part = node.part
		if _include_solution: _trace_parts.append(node.part)
		_trace_id = node.parent
		return
	var part := _trace_first_part
	var route := part.substr(0, part.length() - 1)
	var direction: String = part.right(1)
	var pos: int = _initial.p
	var path: Array[Vector2i] = []
	for action in route:
		pos = _neighbors[pos][ACTIONS.find(action)]
		path.append(_xy(pos))
	var box := _neighbors[pos][ACTIONS.find(direction)]
	var winner := _nodes[_winner_id]
	_result = {
		"box": _xy(box), "direction": direction, "direction_vector": DELTAS[ACTIONS.find(direction)],
		"stand_at": _xy(pos), "walk_actions": route, "walk_path": path,
		"optimal_remaining_pushes": winner.pushes, "optimal_remaining_moves": winner.moves,
		"tier_1": {"kind": "focus_box", "box": _xy(box)},
		"tier_2": {"kind": "next_push", "box": _xy(box), "direction": direction},
		"tier_3": {"kind": "optional_walk", "stand_at": _xy(pos), "walk_actions": route, "walk_path": path},
	}
	if _include_solution:
		_trace_parts.reverse()
		_result["solution_actions"] = "".join(_trace_parts)
	_finish("solved")

func _add_node(player: int, boxes: PackedInt32Array, pushes: int, moves: int, parent: int, part: String, key: String) -> void:
	var index := _nodes.size()
	_nodes.append({"p": player, "boxes": boxes, "pushes": pushes, "moves": moves, "parent": parent, "part": part, "key": key})
	_best[key] = index
	_heap.append(index)
	var child := _heap.size() - 1
	while child > 0:
		var above := (child - 1) / 2
		if not _less(_heap[child], _heap[above]): break
		var swap := _heap[above]
		_heap[above] = _heap[child]
		_heap[child] = swap
		child = above
	_generated += 1

func _heap_pop() -> int:
	var result := _heap[0]
	var last: int = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		var parent := 0
		while true:
			var child := parent * 2 + 1
			if child >= _heap.size(): break
			if child + 1 < _heap.size() and _less(_heap[child + 1], _heap[child]): child += 1
			if not _less(_heap[child], _heap[parent]): break
			var swap := _heap[parent]
			_heap[parent] = _heap[child]
			_heap[child] = swap
			parent = child
	return result

func _less(a: int, b: int) -> bool:
	var left := _nodes[a]
	var right := _nodes[b]
	if left.pushes != right.pushes: return left.pushes < right.pushes
	if left.moves != right.moves: return left.moves < right.moves
	return a < b

func _enter(pos: int, direction: int, open: bool) -> bool:
	return pos >= 0 and bool(_floor[pos]) and (not _gates.has(pos) or open) and (not _arrows.has(pos) or _arrows[pos] == direction)

func _won(boxes: PackedInt32Array) -> bool:
	for box in boxes:
		if not _goals.has(box): return false
	return boxes.size() == _goals.size()

func _has_dead(boxes: PackedInt32Array) -> bool:
	for box in boxes:
		if _dead.has(box): return true
	return false

func _normalize(state: Dictionary) -> Dictionary:
	var player := _read_cell(state.get("player", null))
	if player < 0 or not _floor[player]: return {}
	var raw_boxes: Variant = state.get("crates", null)
	if not raw_boxes is Array or raw_boxes.size() != _goals.size(): return {}
	var boxes := PackedInt32Array()
	var occupied: Dictionary = {}
	var open := false
	for raw in raw_boxes:
		var box := _read_cell(raw)
		if box < 0 or not _floor[box] or box == player or occupied.has(box): return {}
		boxes.append(box)
		occupied[box] = true
		if _plates.has(box): open = true
	if not open:
		if _gates.has(player): return {}
		for box in boxes:
			if _gates.has(box): return {}
	boxes.sort()
	return {"p": player, "boxes": boxes}

func _read_cell(raw: Variant) -> int:
	var xy: Vector2i
	if raw is Vector2i:
		xy = raw
	elif (raw is Array or raw is PackedInt32Array) and raw.size() == 2:
		if not _finite_integer(raw[0]) or not _finite_integer(raw[1]): return -1
		# Check range BEFORE int / Vector2i conversion: Vector2i components are
		# int32 and otherwise wrap huge JSON coordinates into valid board cells.
		if float(raw[0]) < 0.0 or float(raw[1]) < 0.0 or float(raw[0]) >= _width or float(raw[1]) >= _height: return -1
		xy = Vector2i(int(raw[0]), int(raw[1]))
	else:
		return -1
	return xy.y * _width + xy.x if _inside(xy) else -1

func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _finite_integer(value: Variant) -> bool:
	return _finite_number(value) and float(value) == floorf(float(value))

func _inside(xy: Vector2i) -> bool:
	return xy.x >= 0 and xy.y >= 0 and xy.x < _width and xy.y < _height

func _xy(pos: int) -> Vector2i:
	return Vector2i(pos % _width, pos / _width)

func _key(player: int, boxes: PackedInt32Array) -> String:
	var parts := PackedStringArray([str(player)])
	for box in boxes: parts.append(str(box))
	return ":".join(parts)

func _finish(status: String, reason: String = "") -> void:
	_status = status
	if not reason.is_empty(): _result["reason"] = reason
	# Keep bounded diagnostics for inspection until cancel/start. There is no
	# self-running continuation once a terminal status has been produced.

func _bad_level(message: String) -> bool:
	_configuration_error = message
	_status = "invalid"
	_result = {"status": _status, "reason": message, "request_id": _request_id}
	return false

func _clear_search() -> void:
	# Invalidate logical ownership immediately, but NEVER deep-destroy a large
	# search here. All search-sized containers retire in the same fixed slot.
	_cleanup_pending = _cleanup_pending or not _nodes.is_empty() or not _heap.is_empty() or not _trace_parts.is_empty()
	_current = {}
	_initial = {}
	_occupied.clear()
	_walk_tail = 0
	_walk_index = 0
	_reverse.clear()
	_reachable.clear()
	_dead_queue.clear()
	_largest_operation.clear()
	_operation_spikes.clear()
	_trace_first_part = ""
	_current_id = -1
	_trace_id = -1
	_winner_id = -1
	_dead_index = 0
	_dead_head = 0
	_compute_usec = 0
	_cleanup_usec = 0
	_last_slice_usec = 0
	_largest_slice_usec = 0
	_expanded = 0
	_generated = 0
	_phase = ""

func _cleanup_tick() -> void:
	# Release only one node (and its matching index/heap/trace entries). Parent
	# links are integer IDs, not references, so no recursive object graph frees.
	if not _nodes.is_empty():
		var node: Dictionary = _nodes.pop_back()
		_best.erase(node.key)
		if not _heap.is_empty(): _heap.pop_back()
		if not _trace_parts.is_empty(): _trace_parts.pop_back()
		return
	if not _heap.is_empty():
		_heap.pop_back()
		return
	if not _trace_parts.is_empty():
		_trace_parts.pop_back()
		return
	# Every best key belongs to a node just erased. These containers are empty;
	# dropping their backing storage does not recursively release node graphs.
	_best = {}
	_cleanup_pending = false
