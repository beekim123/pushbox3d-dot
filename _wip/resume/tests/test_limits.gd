extends SceneTree
const Codec=preload("res://resume_codec.gd")
const Rules=preload("res://snapshot/puzzle_rules.gd")
var checks:=0
var failures: Array[String]=[]
var records: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func drain(codec: RefCounted,id: int,revision: int) -> Dictionary:
	var frames:=0
	var max_public:=0
	while codec.poll().status=="running" and frames<20000:
		var began:=Time.get_ticks_usec()
		codec.step_budget(2.0,id,revision)
		max_public=maxi(max_public,Time.get_ticks_usec()-began)
		frames+=1
		await process_frame
	check(frames<20000,"bounded validation frames")
	var measured: Dictionary=codec.poll()
	measured["frames"]=frames;measured["max_public_call_ms"]=max_public/1000.0
	return measured
func run() -> void:
	var level: Dictionary={"id":"limit_fixture","width":5,"height":5,"walls":[],"player":[1,1],"crates":[[3,3]],"goals":[[3,2]],"mechanic":{"type":"plain"}}
	var state: Dictionary=Rules.initial(level)
	var history: Array=[]
	for i in range(Codec.MAX_ACTIONS):
		history.append(state)
		state=Rules.step(level,state,"R" if i%2==0 else "L")
	check(state.moves==Codec.MAX_ACTIONS,"full cap consists of actual legal actions")
	var codec:=Codec.new(Rules)
	var began:=Time.get_ticks_usec()
	var id:=codec.begin_encode(level,state,history,100)
	records["begin_encode_ms"]=(Time.get_ticks_usec()-began)/1000.0
	records.encode=await drain(codec,id,100)
	check(codec.poll().status=="encoded","full cap encodes without silent truncation")
	began=Time.get_ticks_usec()
	var encoded: Dictionary=codec.take_result(id,100)
	records["take_encoded_ms"]=(Time.get_ticks_usec()-began)/1000.0
	check(encoded.history_count==Codec.MAX_ACTIONS,"all actions serialized")
	records["encoded_bytes"]=encoded.bytes.size()
	began=Time.get_ticks_usec()
	id=codec.begin_decode(encoded.bytes,{level.id:level})
	records["begin_decode_ms"]=(Time.get_ticks_usec()-began)/1000.0
	records.decode=await drain(codec,id,-1)
	check(codec.poll().status=="restored","full cap replay completes")
	var restored:=codec.take_result(id)
	check(restored.state==state and restored.history==history,"full cap state and every undo snapshot exact")
	for i in range(200): state=history.pop_back()
	var branch_initial:=state.duplicate(true)
	history.append(state);state=Rules.initial(level)
	id=codec.begin_encode(level,state,history,101)
	records.compacted=await drain(codec,id,101)
	var compacted:=codec.take_result(id,101)
	check(compacted.history_count==Codec.MAX_ACTIONS-199,"undo compacts current stack instead of appending event log")
	id=codec.begin_decode(compacted.bytes,{level.id:level})
	await drain(codec,id,-1)
	var branch:=codec.take_result(id)
	check(branch.history.pop_back()==branch_initial,"undo reset after 200 undos restores exact previous counters and boxes")
	id=codec.begin_decode(encoded.bytes,{level.id:level})
	await drain(codec,id,-1)
	began=Time.get_ticks_usec();codec.cancel()
	records["cancel_full_ready_ms"]=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec();codec.begin_encode(level,Rules.initial(level),[],102)
	records["replace_after_cancel_ms"]=(Time.get_ticks_usec()-began)/1000.0
	var over: Array=[];over.resize(Codec.MAX_ACTIONS+1)
	id=codec.begin_encode(level,Rules.initial(level),over,103)
	check(codec.poll().status=="history_limit" and not codec.take_result(id,103).has("bytes"),"8193 refuses; never saves suffix")
	check(over.size()==Codec.MAX_ACTIONS+1,"in-session undo array untouched")
	var file:=FileAccess.open("res://results/limits.json",FileAccess.WRITE)
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"godot":Engine.get_version_info()}
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("RESUME_LIMITS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
