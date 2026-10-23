extends SceneTree
const Codec=preload("res://resume_codec.gd")
const Store=preload("res://resume_store.gd")
const Rules=preload("res://snapshot/puzzle_rules.gd")
class FailingStore:
	extends "res://resume_store.gd"
	func _replace_pending() -> Error: return ERR_CANT_CREATE
var checks:=0
var failures: Array[String]=[]
var catalog: Dictionary={}
var base:= "user://tests_store_"+str(Time.get_ticks_usec())
var fixture: Dictionary
var other: Dictionary

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func write(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes);f.close()
func read(path: String) -> PackedByteArray: return FileAccess.get_file_as_bytes(path)
func finish(codec: RefCounted,id: int,rev: int = -1) -> Dictionary:
	var guard:=0
	while codec.poll().status=="running" and guard<100000: codec.step_budget(2,id,rev);guard+=1
	check(guard<100000,"bounded test drain")
	return codec.take_result(id,rev)
func encode(level: Dictionary,state: Dictionary,history: Array,revision: int) -> Dictionary:
	var codec:=Codec.new(Rules);return finish(codec,codec.begin_encode(level,state,history,revision),revision)
func verify_load(store: RefCounted) -> Dictionary:
	var inspected: Dictionary=store.inspect()
	check(inspected.status=="read","existing sidecar inspected")
	var codec:=Codec.new(Rules)
	var restored:=finish(codec,codec.begin_decode(inspected.bytes,catalog))
	check(restored.status=="restored","existing sidecar fully replayed")
	check(store.accept_verified_load(restored).status=="authorized","only full replay unlocks write")
	return restored
func refusal_preserves(store: RefCounted,encoded: Dictionary,rev: int,path: String,expected: PackedByteArray,label: String) -> void:
	var result: Dictionary=store.commit(encoded,rev)
	check(result.status=="not_saved" and result.old_file_preserved,label+": explicit refusal")
	check(read(path)==expected,label+": exact original bytes preserved")

func run() -> void:
	var levels: Array=JSON.parse_string(FileAccess.get_file_as_string("res://snapshot/levels.json")).levels
	for level in levels: catalog[level.id]=level
	var level: Dictionary=levels[0]
	var initial: Dictionary=Rules.initial(level)
	var moved: Dictionary=Rules.step(level,initial,"R")
	fixture=encode(level,moved,[initial],9)
	other=encode(level,initial,[initial,moved],10)
	var progress_path:=base+"/fourfold_progress.json"
	var progress_bytes:="{\"version\":999,\"unknown\":\"original incompatible progress\"}\n".to_utf8_buffer()
	write(progress_path,progress_bytes)
	var dir:=base+"/normal"
	var path:=dir+"/resume.json"
	var store:=Store.new(dir)
	check(store.commit(fixture,9).status=="not_saved","inspect required before any write")
	check(store.inspect().status=="missing","missing slot is creatable")
	check(store.commit(fixture,9).status=="saved","initial commit")
	check(read(path)==fixture.bytes,"initial exact wire")
	refusal_preserves(store,other,11,path,fixture.bytes,"revision changed before commit")
	var corrupted: Dictionary=other.duplicate(true);corrupted.bytes.append(32)
	refusal_preserves(store,corrupted,10,path,fixture.bytes,"encoded payload mutation")
	refusal_preserves(store,{"status":"history_limit"},10,path,fixture.bytes,"history limit")
	refusal_preserves(store,{"status":"budget_exhausted"},10,path,fixture.bytes,"validation budget")
	check(store.commit(other,10).status=="saved","valid replacing commit")
	check(read(path)==other.bytes,"replace exact bytes")
	check(not FileAccess.file_exists(dir+"/resume.pending") and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir+"/resume.lock")),"successful transaction cleans owned temp/lock")
	var reopened:=Store.new(dir)
	check(reopened.inspect().writable==false,"existing file read-only before verification")
	refusal_preserves(reopened,fixture,9,path,other.bytes,"unverified original")
	check(reopened.accept_verified_load({"status":"restored"}).status=="not_saved","partial forged load does not unlock")
	var restored:=verify_load(reopened)
	check(restored.history.size()==2 and restored.state==initial,"restored reset retained")
	var history: Array=restored.history
	check(history.pop_back()==moved,"undo reset gives exact pre-reset dictionary")
	check(history.pop_back()==initial,"then undo move gives initial")
	check(reopened.commit(fixture,9).status=="saved","verified original becomes replaceable")
	var first:=Store.new(dir);verify_load(first)
	var second:=Store.new(dir);verify_load(second)
	check(second.commit(other,10).status=="saved","second writer valid commit")
	refusal_preserves(first,fixture,9,path,other.bytes,"cooperative competing writer compare-and-swap")
	var failing:=FailingStore.new(dir);verify_load(failing)
	refusal_preserves(failing,fixture,9,path,other.bytes,"injected rename failure")
	check(not FileAccess.file_exists(dir+"/resume.pending"),"failed rename removes only owned pending")
	var pending_bytes:="interrupted write under manual review".to_utf8_buffer()
	write(dir+"/resume.pending",pending_bytes)
	refusal_preserves(reopened,fixture,9,path,other.bytes,"changed original still protected")
	var pending_store:=Store.new(dir);verify_load(pending_store)
	refusal_preserves(pending_store,fixture,9,path,other.bytes,"preexisting pending blocks write")
	check(read(dir+"/resume.pending")==pending_bytes,"unknown pending preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir+"/resume.pending"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir+"/resume.lock"))
	refusal_preserves(pending_store,fixture,9,path,other.bytes,"active or abandoned lock blocks write")
	check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir+"/resume.lock")),"foreign lock preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir+"/resume.lock"))
	var bad: Array=["{bad".to_utf8_buffer(),"".to_utf8_buffer(),"x".repeat(Codec.MAX_FILE_BYTES+1).to_utf8_buffer()]
	var data: Dictionary=JSON.parse_string(fixture.bytes.get_string_from_utf8());data.version=999
	bad.append(JSON.stringify(data).to_utf8_buffer())
	for index in range(bad.size()):
		var bad_dir:=base+"/protected_"+str(index);var bad_path:=bad_dir+"/resume.json"
		write(bad_path,bad[index]);var protected:=Store.new(bad_dir)
		var inspected: Dictionary=protected.inspect()
		if inspected.status=="read":
			var codec:=Codec.new(Rules);var result:=finish(codec,codec.begin_decode(inspected.bytes,catalog))
			check(result.status=="protected","bad original rejected by replay")
			check(protected.accept_verified_load(result).status=="not_saved","bad original cannot unlock")
		refusal_preserves(protected,fixture,9,bad_path,bad[index],"bad original "+str(index))
	for root_alias in ["user://","user://.","user:///","user:////","user://./","user://././"]:
		check(Store.new(root_alias).inspect().status=="not_saved","cannot target user root via "+root_alias)
	check(Store.new("res://production").inspect().status=="not_saved","cannot target source directory")
	check(Store.new("user://../escape").inspect().status=="not_saved","cannot escape dedicated user directory")
	check(read(progress_path)==progress_bytes,"future-version progress sentinel never touched")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"test_directory":ProjectSettings.globalize_path(base),"godot":Engine.get_version_info()}
	write("res://results/store.json",JSON.stringify(report,"  ").to_utf8_buffer())
	print("RESUME_STORE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
