class_name ResumeCodec
extends RefCounted
## Bounded, replay-verified resume sidecar. Does not read/write progress or files.
## Inject the game's original PuzzleRules script; no duplicated puzzle rules.
## X means Reset, which is a normal undoable history entry. Undo pops that action.
## Runtime history snapshots must remain immutable (as in current main.gd).
## Any logical move/undo/reset/level change increments caller revision and cancels
## pending work. Visual tween completion does not change the logical revision.

const FORMAT := "fourfold.resume"
const VERSION := 1
const RULESET := "fourfold_rules_v2"
const MAX_ACTIONS := 8192
const MAX_FILE_BYTES := 65536
const MAX_CELLS := 256
const MAX_CRATES := 8
const MAX_CATALOG := 512
const MAX_JSON_DEPTH := 8
const ACTIONS := ["U", "D", "L", "R"]
const DELTAS := [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]
const RECORD_KEYS := ["format","version","ruleset","level_id","level_fingerprint","actions","state","checksum"]

var _rules: Script
var _request := 0
var _revision := 0
var _status := "idle"
var _reason := ""
var _kind := ""
var _phase := ""
var _level: Dictionary = {}
var _fingerprint := ""
var _initial: Dictionary = {}
var _current: Dictionary = {}
var _claimed: Dictionary = {}
var _history_source: Array = []
var _history_output: Array = []
var _tokens := PackedStringArray()
var _actions := ""
var _index := 0
var _bytes := PackedByteArray()
var _input_hash := ""
var _catalog: Dictionary = {}
var _payload: Dictionary = {}
var _ready: Dictionary = {}
var _elapsed_usec := 0
var _slice_max_usec := 0
var _max_usec := 5000000
var _scan_index := 0
var _scan_depth := 0
var _scan_string := false
var _scan_escape := false
var _walls: Dictionary = {}
var _plates: Dictionary = {}
var _gates: Dictionary = {}

func _init(rules: Script) -> void:
	_rules = rules

func begin_encode(level: Dictionary, state: Dictionary, history: Array, revision: int, max_validation_ms: float = 5000.0) -> int:
	_begin("encode", revision, max_validation_ms)
	if _status != "running": return _request
	if history.size() > MAX_ACTIONS:
		_fail("history_limit", "完整撤销历史超过续玩存储上限；本局撤销不受影响，旧续玩文件保留。")
		return _request
	if not _configure_level(level):
		_fail("invalid", "invalid_level")
		return _request
	_claimed = _normalize_state(state)
	if _claimed.is_empty():
		_fail("invalid", "invalid_current_state")
		return _request
	# Main.gd never mutates a stored snapshot after append: it replaces state and
	# pops/appends Array entries. Copying this array isolates those mutations.
	# Snapshot Dictionary mutation without incrementing revision violates the API.
	_history_source = history.duplicate(false)
	_current = _initial.duplicate(true)
	_phase = "encode"
	return _request

func begin_decode(bytes: PackedByteArray, catalog: Dictionary, max_validation_ms: float = 5000.0) -> int:
	_begin("decode", 0, max_validation_ms)
	if _status != "running": return _request
	if bytes.is_empty() or bytes.size() > MAX_FILE_BYTES:
		_fail("protected", "invalid_file_size")
		return _request
	if catalog.size() > MAX_CATALOG:
		_fail("protected", "catalog_limit")
		return _request
	_bytes = bytes.duplicate()
	_input_hash = bytes.hex_encode().sha256_text()
	_catalog = catalog.duplicate(false) # Authored levels are immutable resources.
	_phase = "scan"
	return _request

func step_budget(milliseconds: float = 2.0, expected_request: int = -1, current_revision: int = -1) -> Dictionary:
	if expected_request >= 0 and expected_request != _request:
		return {"status":"stale","request_id":expected_request,"current_request_id":_request}
	if _kind == "encode" and current_revision >= 0 and current_revision != _revision:
		_fail("stale", "logical_state_changed")
	if _status != "running" or not is_finite(milliseconds) or milliseconds <= 0.0: return poll()
	var began := Time.get_ticks_usec()
	var budget := int(clampf(milliseconds,0.01,8.0)*1000.0)
	while _status == "running" and Time.get_ticks_usec()-began < budget:
		if _elapsed_usec+Time.get_ticks_usec()-began >= _max_usec:
			_fail("budget_exhausted", "validation_budget_exhausted")
			break
		match _phase:
			"scan": _scan_tick()
			"parse": _parse_tick()
			"encode": _encode_tick()
			"decode": _decode_tick()
	var used := Time.get_ticks_usec()-began
	_elapsed_usec += used
	_slice_max_usec = maxi(_slice_max_usec,used)
	return poll()

func poll() -> Dictionary:
	return {"status":_status,"reason":_reason,"kind":_kind,"request_id":_request,
		"source_revision":_revision,"processed_actions":_index,
		"total_actions":_history_source.size() if _kind=="encode" else _actions.length(),
		"compute_ms":_elapsed_usec/1000.0,"max_slice_ms":_slice_max_usec/1000.0,
		"fallback":"fresh_level" if _status in ["protected","budget_exhausted","invalid"] and _kind=="decode" else "none"}

func take_result(expected_request: int, current_revision: int = -1) -> Dictionary:
	if expected_request != _request: return {"status":"stale"}
	if _kind == "encode" and current_revision != _revision: return {"status":"stale","reason":"logical_state_changed"}
	if _status not in ["encoded","restored"] or _ready.is_empty(): return poll()
	# One-time ownership transfer: do not deep-copy thousands of undo snapshots on
	# every UI poll. No mutable history/state is exposed by poll().
	var result := _ready
	_ready = {}
	result["status"] = _status
	result["request_id"] = _request
	result["source_revision"] = _revision
	return result

func cancel() -> int:
	_request += 1
	_status = "cancelled"
	_reason = ""
	_ready = {}
	return _request

func _begin(kind: String, revision: int, milliseconds: float) -> void:
	_request += 1
	_status = "running"
	_reason = ""
	_kind = kind
	_revision = revision
	_phase = ""
	_level = {}
	_initial = {}
	_current = {}
	_claimed = {}
	_history_source = []
	_history_output = []
	_tokens = PackedStringArray()
	_actions = ""
	_index = 0
	_bytes = PackedByteArray()
	_input_hash = ""
	_catalog = {}
	_payload = {}
	_ready = {}
	_elapsed_usec = 0
	_slice_max_usec = 0
	_scan_index = 0
	_scan_depth = 0
	_scan_string = false
	_scan_escape = false
	if revision < 0 or not is_finite(milliseconds) or milliseconds < 0.0:
		_fail("invalid", "invalid_request_options")
		return
	_max_usec = int(minf(milliseconds,30000.0)*1000.0)

func _encode_tick() -> void:
	if _index >= _history_source.size():
		if not _same(_current,_claimed):
			_fail("invalid", "history_does_not_reach_current_state")
			return
		_actions = "".join(_tokens)
		var payload := _make_payload(_actions,_claimed)
		payload["checksum"] = _checksum(payload)
		var bytes := JSON.stringify(payload,"",true,true).to_utf8_buffer()
		if bytes.size() > MAX_FILE_BYTES:
			_fail("history_limit", "encoded_file_too_large_no_truncation")
			return
		_ready = {"bytes":bytes,"blob_token":bytes.hex_encode().sha256_text(),"level_id":_level.id,
			"won":_rules.won(_level,_current),"history_count":_index,"source_revision":_revision}
		_status = "encoded"
		return
	var before := _normalize_state(_history_source[_index])
	if before.is_empty() or not _same(before,_current):
		_fail("invalid", "invalid_history_prefix_at_"+str(_index))
		return
	var after := _claimed if _index+1==_history_source.size() else _normalize_state(_history_source[_index+1])
	if after.is_empty():
		_fail("invalid", "invalid_history_snapshot_at_"+str(_index+1))
		return
	if _same(after,_initial):
		_tokens.append("X")
		_current = _initial.duplicate(true)
	else:
		var delta: Vector2i = after.player-_current.player
		var direction: int = DELTAS.find(delta)
		if direction < 0:
			_fail("invalid", "history_not_one_move_or_reset")
			return
		var next: Dictionary = _rules.step(_level,_current,ACTIONS[direction])
		if next.is_empty() or not _same(next,after):
			_fail("invalid", "history_contains_illegal_transition")
			return
		_tokens.append(ACTIONS[direction])
		_current = next
	_index += 1

func _scan_tick() -> void:
	# Bound recursion before invoking the JSON parser; strings/escapes are skipped.
	var stop := mini(_scan_index+256,_bytes.size())
	while _scan_index < stop:
		var c := _bytes[_scan_index]
		_scan_index += 1
		if _scan_string:
			if _scan_escape: _scan_escape=false
			elif c==92: _scan_escape=true
			elif c==34: _scan_string=false
		else:
			if c==34: _scan_string=true
			elif c==123 or c==91:
				_scan_depth += 1
				if _scan_depth > MAX_JSON_DEPTH:
					_fail("protected", "json_nesting_limit")
					return
			elif c==125 or c==93:
				_scan_depth -= 1
				if _scan_depth < 0:
					_fail("protected", "malformed_json")
					return
	if _scan_index >= _bytes.size(): _phase="parse"

func _parse_tick() -> void:
	var text := _bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != _bytes:
		_fail("protected", "invalid_utf8")
		return
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		_fail("protected", "malformed_json")
		return
	var data: Dictionary = parser.data
	if not _integer(data.get("version")) or float(data.version)!=float(VERSION):
		_fail("protected", "future_or_unsupported_version")
		return
	if data.size()!=RECORD_KEYS.size():
		_fail("protected", "unknown_or_missing_fields")
		return
	for key in RECORD_KEYS:
		if not data.has(key):
			_fail("protected", "missing_fields")
			return
	for key in ["format","ruleset","level_id","level_fingerprint","actions","checksum"]:
		if not data[key] is String:
			_fail("protected", "invalid_field_type")
			return
	if data.format!=FORMAT or data.ruleset!=RULESET:
		_fail("protected", "incompatible_format_or_rules")
		return
	if data.level_id.length()>96 or not _catalog.has(data.level_id) or not _catalog[data.level_id] is Dictionary:
		_fail("protected", "unknown_level")
		return
	if not _configure_level(_catalog[data.level_id]) or _level.id!=data.level_id:
		_fail("protected", "invalid_catalog_level")
		return
	if data.level_fingerprint!=_fingerprint:
		_fail("protected", "level_rules_changed")
		return
	if data.actions.length()>MAX_ACTIONS:
		_fail("protected", "history_limit_no_truncation")
		return
	_claimed = _normalize_state(data.state,true)
	if _claimed.is_empty():
		_fail("protected", "invalid_claimed_state")
		return
	_payload = _make_payload(data.actions,_claimed)
	if not _hex_digest(data.checksum) or _checksum(_payload)!=data.checksum:
		_fail("protected", "checksum_mismatch")
		return
	var canonical := _payload.duplicate(true)
	canonical["checksum"] = data.checksum
	if JSON.stringify(canonical,"",true,true).to_utf8_buffer() != _bytes:
		_fail("protected", "noncanonical_or_duplicate_json_fields")
		return
	_actions = data.actions
	_current = _initial.duplicate(true)
	_phase = "decode"

func _decode_tick() -> void:
	if _index >= _actions.length():
		if not _same(_current,_claimed):
			_fail("protected", "replay_final_state_mismatch")
			return
		_ready = {"level_id":_level.id,"state":_current,"history":_history_output,
			"history_count":_history_output.size(),"won":_rules.won(_level,_current),
			"input_token":_input_hash,"validated_format":FORMAT,"validated_version":VERSION,
			"resume_animation":false,"pending_direction":"","completion_policy":"reconcile_via_existing_complete_level"}
		_history_output = []
		_status = "restored"
		return
	var action: String = _actions[_index]
	var next: Dictionary
	if action=="X": next=_initial.duplicate(true)
	elif action in ACTIONS: next=_rules.step(_level,_current,action)
	else:
		_fail("protected", "unknown_action")
		return
	if next.is_empty():
		_fail("protected", "illegal_replayed_action_at_"+str(_index))
		return
	_history_output.append(_current)
	_current = next
	_index += 1

func _configure_level(raw: Dictionary) -> bool:
	if not raw.get("id") is String or raw.id.is_empty() or raw.id.length()>96: return false
	if not _integer(raw.get("width")) or not _integer(raw.get("height")): return false
	var width := float(raw.width)
	var height := float(raw.height)
	if width<1 or height<1 or width>32 or height>32 or width*height>MAX_CELLS: return false
	var mechanic: Variant=raw.get("mechanic",{})
	if not mechanic is Dictionary or mechanic.get("type","plain") not in ["plain","terrain"]: return false
	_level={"id":raw.id,"width":int(width),"height":int(height),"mechanic":{"type":mechanic.get("type","plain")}}
	_walls={};_plates={};_gates={}
	for field in ["walls","goals","crates","glide","plates","gates"]:
		var list: Variant=raw.get(field,[])
		if not list is Array or list.size()>int(width*height): return false
		var seen: Dictionary={}
		var normalized: Array=[]
		for entry in list:
			var cell := _cell(entry)
			if cell.x<0 or seen.has(cell): return false
			seen[cell]=true
			normalized.append([cell.x,cell.y])
		if field!="crates": normalized.sort_custom(func(a,b): return a[1]*32+a[0]<b[1]*32+b[0])
		_level[field]=normalized
		if field=="walls": _walls=seen
		elif field=="plates": _plates=seen
		elif field=="gates": _gates=seen
	if _level.goals.is_empty() or _level.goals.size()>MAX_CRATES or _level.crates.size()!=_level.goals.size(): return false
	for field in ["goals","crates","glide","plates","gates"]:
		for entry in _level[field]:
			if _walls.has(_cell(entry)): return false
	if not _gates.is_empty() and _plates.is_empty(): return false
	var player := _cell(raw.get("player"))
	if player.x<0 or _walls.has(player): return false
	_level.player=[player.x,player.y]
	var portals: Variant=raw.get("portals",[])
	if not portals is Array or portals.size()*2>int(width*height): return false
	var portal_seen: Dictionary={}
	_level.portals=[]
	for pair in portals:
		if not pair is Array or pair.size()!=2: return false
		var a:=_cell(pair[0]);var b:=_cell(pair[1])
		if a.x<0 or b.x<0 or a==b or _walls.has(a) or _walls.has(b) or portal_seen.has(a) or portal_seen.has(b): return false
		if [a.x,a.y] in _level.glide or [b.x,b.y] in _level.glide: return false
		portal_seen[a]=true;portal_seen[b]=true
		var normalized: Array=[[a.x,a.y],[b.x,b.y]]
		normalized.sort_custom(func(x,y):return x[1]*32+x[0]<y[1]*32+y[0])
		_level.portals.append(normalized)
	_level.portals.sort_custom(func(x,y):return x[0][1]*32+x[0][0]<y[0][1]*32+y[0][0])
	var arrows: Variant=raw.get("arrows",[])
	if not arrows is Array or arrows.size()>int(width*height): return false
	var arrow_seen: Dictionary={}
	_level.arrows=[]
	for arrow in arrows:
		if not arrow is Dictionary or not arrow.get("dir") is String or arrow.dir not in ACTIONS: return false
		var pos:=_cell(arrow.get("cell"))
		if pos.x<0 or _walls.has(pos) or arrow_seen.has(pos): return false
		arrow_seen[pos]=true
		_level.arrows.append({"cell":[pos.x,pos.y],"dir":arrow.dir})
	_level.arrows.sort_custom(func(a,b):return a.cell[1]*32+a.cell[0]<b.cell[1]*32+b.cell[0])
	_initial=_rules.initial(_level)
	if _normalize_state(_initial).is_empty(): return false
	_fingerprint=JSON.stringify(_level,"",true,true).sha256_text()
	return true

func _normalize_state(raw: Variant, strict: bool = false) -> Dictionary:
	if not raw is Dictionary: return {}
	if strict and (raw.size()!=4 or not raw.has_all(["player","crates","moves","pushes"])): return {}
	var player:=_cell(raw.get("player"))
	if player.x<0 or _walls.has(player): return {}
	if not raw.get("crates") is Array or raw.crates.size()!=_level.crates.size(): return {}
	if not _integer(raw.get("moves")) or not _integer(raw.get("pushes")): return {}
	if float(raw.moves)<0 or float(raw.moves)>MAX_ACTIONS or float(raw.pushes)<0 or float(raw.pushes)>float(raw.moves): return {}
	var crates: Array[Vector2i]=[]
	var occupied: Dictionary={}
	var open:=false
	for entry in raw.crates:
		var cell:=_cell(entry)
		if cell.x<0 or _walls.has(cell) or occupied.has(cell) or cell==player: return {}
		occupied[cell]=true;crates.append(cell)
		if _plates.has(cell): open=true
	if not open:
		if _gates.has(player): return {}
		for cell in crates:
			if _gates.has(cell): return {}
	return {"player":player,"crates":crates,"moves":int(raw.moves),"pushes":int(raw.pushes)}

func _cell(raw: Variant) -> Vector2i:
	if raw is Vector2i:
		return raw if raw.x>=0 and raw.y>=0 and raw.x<_level.width and raw.y<_level.height else Vector2i(-1,-1)
	if not raw is Array or raw.size()!=2 or not _integer(raw[0]) or not _integer(raw[1]): return Vector2i(-1,-1)
	if float(raw[0])<0 or float(raw[1])<0 or float(raw[0])>=_level.width or float(raw[1])>=_level.height: return Vector2i(-1,-1)
	return Vector2i(int(raw[0]),int(raw[1]))

func _same(a: Dictionary,b: Dictionary) -> bool:
	return a.player==b.player and a.crates==b.crates and int(a.moves)==int(b.moves) and int(a.pushes)==int(b.pushes)

func _make_payload(actions: String,state: Dictionary) -> Dictionary:
	var crates: Array=[]
	for c in state.crates: crates.append([c.x,c.y])
	return {"format":FORMAT,"version":VERSION,"ruleset":RULESET,"level_id":_level.id,
		"level_fingerprint":_fingerprint,"actions":actions,
		"state":{"player":[state.player.x,state.player.y],"crates":crates,"moves":int(state.moves),"pushes":int(state.pushes)}}

func _checksum(payload: Dictionary) -> String:
	return JSON.stringify(payload,"",true,true).sha256_text()

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))

func _hex_digest(value: String) -> bool:
	if value.length()!=64: return false
	for c in value:
		if c not in "0123456789abcdef": return false
	return true

func _fail(status: String,reason: String) -> void:
	_status=status
	_reason=reason
	_ready={}
