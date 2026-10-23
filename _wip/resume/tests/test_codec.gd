extends SceneTree
const Codec=preload("res://resume_codec.gd")
const Rules=preload("res://snapshot/puzzle_rules.gd")
var failures: Array[String]=[]
var checks:=0
var records: Array=[]
var catalog: Dictionary={}
var reports: Dictionary={}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func drain(codec: RefCounted,id: int,revision: int = -1) -> Dictionary:
	var out: Dictionary=codec.poll()
	var guard:=0
	while out.status=="running" and guard<100000:
		out=codec.step_budget(2.0,id,revision)
		guard+=1
	check(guard<100000,"validation completes within test guard")
	return out

func run() -> void:
	var levels: Array=JSON.parse_string(FileAccess.get_file_as_string("res://snapshot/levels.json")).levels
	for level in levels: catalog[level.id]=level
	for report in JSON.parse_string(FileAccess.get_file_as_string("res://snapshot/resume_solutions.json")).levels: reports[report.id]=report
	for level in levels:
		var state: Dictionary=Rules.initial(level)
		var history: Array=[]
		var solution: String=reports[level.id].solution
		# Exercise forward actions, reset itself, undo-reset, an undone branch,
		# then redo the actual solution. Only CURRENT stack is serialized.
		for index in range(solution.length()):
			history.append(state.duplicate(true))
			state=Rules.step(level,state,solution[index])
			if index==0:
				var before: Dictionary=state.duplicate(true)
				history.append(state.duplicate(true));state=Rules.initial(level)
				state=history.pop_back()
				check(state==before,level.id+": reset undo exact before encoding")
			if index==solution.length()/2:
				verify_roundtrip(level,state,history,"middle")
		verify_roundtrip(level,state,history,"won")
		# Persist a RESET that remains on the actual undo stack.
		history.append(state.duplicate(true));state=Rules.initial(level)
		verify_roundtrip(level,state,history,"reset_after_win")
		await process_frame
	adversarial(levels[0])
	check(records.size()==levels.size()*3,"all expected roundtrips actually executed")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"roundtrips":records.size(),"godot":Engine.get_version_info()}
	var file:=FileAccess.open("res://results/codec.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RESUME_CODEC ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"roundtrips":records.size()}))
	quit(0 if failures.is_empty() else 1)

func verify_roundtrip(level: Dictionary,state: Dictionary,history: Array,label: String) -> void:
	var codec:=Codec.new(Rules)
	var id:=codec.begin_encode(level,state,history,17)
	var encoded:=drain(codec,id,17)
	check(encoded.status=="encoded",level.id+" "+label+": encode "+str(encoded))
	if encoded.status!="encoded": return
	var result:=codec.take_result(id,17)
	check(result.bytes.size()<=Codec.MAX_FILE_BYTES,"bounded wire size")
	id=codec.begin_decode(result.bytes,catalog)
	var decoded:=drain(codec,id)
	check(decoded.status=="restored",level.id+" "+label+": decode "+str(decoded))
	if decoded.status!="restored": return
	var restored:=codec.take_result(id)
	check(restored.state==state,level.id+" "+label+": exact current dictionary including route metadata")
	check(restored.history==history,level.id+" "+label+": exact complete history including reset")
	check(restored.pending_direction=="" and not restored.resume_animation,"never revive buffered input or tween")
	check(restored.won==Rules.won(level,state),"completed checkpoint classification")
	var saved_state: Dictionary=restored.state
	var saved_history: Array=restored.history
	while not saved_history.is_empty(): saved_state=saved_history.pop_back()
	check(saved_state==Rules.initial(level),"undo all the way back to original initial state")
	check(not codec.take_result(id).has("history"),"result ownership transferred only once")
	records.append({"level":level.id,"kind":label,"actions":history.size(),"bytes":result.bytes.size(),"encode_ms":encoded.compute_ms,"decode_ms":decoded.compute_ms,"encode_slice_max_ms":encoded.max_slice_ms,"decode_slice_max_ms":decoded.max_slice_ms})

func encoded_fixture(level: Dictionary) -> Dictionary:
	var current: Dictionary=Rules.step(level,Rules.initial(level),"R")
	var codec:=Codec.new(Rules)
	var id:=codec.begin_encode(level,current,[Rules.initial(level)],3)
	drain(codec,id,3)
	return codec.take_result(id,3)

func integerize(value: Variant) -> Variant:
	if value is float and is_finite(value) and absf(value)<=9007199254740991.0 and value==floorf(value): return int(value)
	if value is Dictionary:
		for key in value: value[key]=integerize(value[key])
	elif value is Array:
		for i in range(value.size()): value[i]=integerize(value[i])
	return value

func signed(data: Dictionary) -> PackedByteArray:
	data=integerize(data)
	data.erase("checksum")
	data.checksum=JSON.stringify(data,"",true,true).sha256_text()
	return JSON.stringify(data,"",true,true).to_utf8_buffer()

func expect_protected(bytes: PackedByteArray,label: String,reason: String = "") -> void:
	var codec:=Codec.new(Rules)
	var id:=codec.begin_decode(bytes,catalog)
	var out:=drain(codec,id)
	check(out.status=="protected",label+": reject protected "+str(out))
	if not reason.is_empty(): check(out.reason==reason,label+": specific refusal path "+str(out))
	check(out.fallback=="fresh_level",label+": transparent fresh-level fallback")
	check(not codec.take_result(id).has("history") and not codec.take_result(id).has("state"),label+": never expose partial replay")

func adversarial(level: Dictionary) -> void:
	var fixture:=encoded_fixture(level)
	var base: Dictionary=JSON.parse_string(fixture.bytes.get_string_from_utf8())
	for patch in [{"version":99},{"version":1.5},{"version":1e100},{"format":"progress"},{"ruleset":"future"},{"level_id":"missing"},{"level_fingerprint":"wrong"},{"actions":"Q"},{"actions":"RR"},{"actions":"L"},{"checksum":"0".repeat(64)},{"extra":true}]:
		var modified:=base.duplicate(true)
		modified.merge(patch,true)
		expect_protected(JSON.stringify(modified,"",true,true).to_utf8_buffer(),"tampered envelope "+str(patch))
	for coordinate in [[-1,2],[4294967297,2],[-4294967295,2],[1.25,2],[INF,2],[NAN,2],[0,0],[5,2]]:
		var modified:=base.duplicate(true)
		modified.state.player=coordinate
		expect_protected(signed(modified),"tampered coordinate "+str(coordinate))
	for change in [{"moves":99},{"pushes":2},{"crates":[[3,2]]},{"crates":[[5,2],[5,2]]},{"moves":0.5},{"player":null},{"crates":{}},{"unknown":1}]:
		var modified:=base.duplicate(true)
		modified.state.merge(change,true)
		expect_protected(signed(modified),"tampered state "+str(change))
	for action in ["L","Q","RR","X"]:
		var modified:=base.duplicate(true);modified.actions=action
		var reason: String={"L":"illegal_replayed_action_at_0","Q":"unknown_action","RR":"replay_final_state_mismatch","X":"replay_final_state_mismatch"}[action]
		expect_protected(signed(modified),"recomputed checksum cannot bypass replay "+action,reason)
	expect_protected("{broken".to_utf8_buffer(),"malformed JSON")
	expect_protected(("[".repeat(100)+"0"+"]".repeat(100)).to_utf8_buffer(),"JSON nesting bomb")
	expect_protected(" ".repeat(Codec.MAX_FILE_BYTES+1).to_utf8_buffer(),"oversized file")
	var duplicate: String=fixture.bytes.get_string_from_utf8().insert(1,'"version":99,')
	expect_protected(duplicate.to_utf8_buffer(),"ambiguous duplicate key")
	var codec:=Codec.new(Rules)
	var old:=codec.begin_encode(level,Rules.initial(level),[],9)
	check(codec.step_budget(2,old,10).status=="stale","state changes invalidate pending checkpoint")
	var newer:=codec.begin_encode(level,Rules.initial(level),[],10)
	check(codec.step_budget(2,old,9).status=="stale","old callback cannot advance replacement")
	drain(codec,newer,10)
	check(codec.take_result(newer,11).status=="stale","state changes before file commit cannot use encoded output")
	codec.cancel()
	check(codec.take_result(newer,10).status=="stale","cancel invalidates completed output")
	var too_long: Array=[];too_long.resize(Codec.MAX_ACTIONS+1)
	var id:=codec.begin_encode(level,Rules.initial(level),too_long,1)
	check(codec.poll().status=="history_limit","no silent undo truncation when history cap exceeded")
	id=codec.begin_decode(fixture.bytes,catalog,0)
	check(drain(codec,id).status=="budget_exhausted","validation timeout is not valid/corrupt proof")
	var wrong: Dictionary=Rules.initial(level);wrong.moves=1
	id=codec.begin_encode(level,wrong,[],0)
	check(drain(codec,id,0).status=="invalid","unreachable current with empty history rejected")
	var corrupt_history: Array=[Rules.initial(level)];corrupt_history[0].player=Vector2i(3,3)
	id=codec.begin_encode(level,Rules.step(level,Rules.initial(level),"R"),corrupt_history,0)
	check(drain(codec,id,0).status=="invalid","broken history root rejected")
