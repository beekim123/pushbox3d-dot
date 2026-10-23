extends "res://audit_tests/base.gd"
const Codec=preload("res://scripts/resume/resume_codec.gd")
const Store=preload("res://scripts/resume/resume_store.gd")
class FailedRename:
 extends "res://scripts/resume/resume_store.gd"
 func _replace_pending() -> Error:return ERR_CANT_CREATE
var catalog: Dictionary={}
func finish(c: RefCounted,id: int,revision: int=-1) -> Dictionary:
 var guard:=0
 while c.poll().status=="running" and guard<100000:c.step_budget(1.0,id,revision);guard+=1
 ck(guard<100000,"bounded validation drain")
 return c.take_result(id,revision)
func fixture(entry: Dictionary,actions: String,revision: int) -> Dictionary:
 var state:=Rules.initial(entry);var history:Array=[]
 for action in actions:
  history.append(state.duplicate(true));state=Rules.initial(entry) if action=="X" else Rules.step(entry,state,action)
  ck(not state.is_empty(),"legal fixture action")
 var c:=Codec.new(Rules);var encoded:=finish(c,c.begin_encode(entry,state,history,revision),revision)
 ck(encoded.status=="encoded","fixture encoded")
 return {"encoded":encoded,"state":state,"history":history}
func numbers(value: Variant) -> Variant:
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[key]=numbers(value[key])
  return result
 if value is Array:
  var result:Array=[]
  for item in value:result.append(numbers(item))
  return result
 if value is float and is_finite(value) and value==floorf(value) and absf(value)<9e15:return int(value)
 return value
func signed(data: Dictionary) -> PackedByteArray:
 var normalized:Dictionary=numbers(data);normalized.erase("checksum")
 normalized.checksum=JSON.stringify(normalized,"",true,true).sha256_text()
 return JSON.stringify(normalized,"",true,true).to_utf8_buffer()
func reject(bytes: PackedByteArray,label: String,reason: String="",levels:Dictionary=catalog) -> void:
 var c:=Codec.new(Rules);var result:=finish(c,c.begin_decode(bytes,levels))
 ck(result.status=="protected",label+" protected")
 if reason!="":ck(result.reason==reason,label+" reaches expected guard: "+str(result))
 ck(not result.has("state") and not result.has("history"),label+" never partial restore")
func authorize(store: RefCounted) -> Dictionary:
 var disk:Dictionary=store.inspect();ck(disk.status=="read" and not disk.writable,"old file initially readonly")
 var c:=Codec.new(Rules);var result:=finish(c,c.begin_decode(disk.bytes,catalog))
 ck(result.status=="restored","old file full replay")
 ck(store.accept_verified_load(result).status=="authorized","verified original unlocked")
 return result
func preserves(store:RefCounted,data:Dictionary,revision:int,path:String,expected:PackedByteArray,label:String) -> void:
 var result:Dictionary=store.commit(data,revision)
 ck(result.status=="not_saved" and result.keep_current_game,label+" explicit no-save keeps game")
 ck(FileAccess.get_file_as_bytes(path)==expected,label+" exact old bytes")
func run() -> void:
 mode="storage"
 var entries:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json")).levels
 for entry in entries:catalog[entry.id]=entry
 var entry:Dictionary=entries[0]
 var interrupted:=fixture(entry,"RXUDRXU",10);var terminal:=fixture(entry,"R",11)
 var c:=Codec.new(Rules)
 var restored:=finish(c,c.begin_decode(interrupted.encoded.bytes,catalog))
 ck(restored.state==interrupted.state and restored.history==interrupted.history,"complete exact current and Undo-Reset stack")
 ck(not restored.resume_animation and restored.pending_direction=="","no tween/input replay")
 while not restored.history.is_empty():restored.state=restored.history.pop_back()
 ck(restored.state==Rules.initial(entry),"all undo reaches original")
 var base:Dictionary=JSON.parse_string(interrupted.encoded.bytes.get_string_from_utf8())
 for bad in [PackedByteArray(),"x".repeat(65537).to_utf8_buffer(),"{bad".to_utf8_buffer(),("[".repeat(9)+"0"+"]".repeat(9)).to_utf8_buffer(),PackedByteArray([123,34,255,34,58,49,125])]:reject(bad,"malformed/bounded bytes")
 for patch in [{"version":999},{"ruleset":"future"},{"extra":true},{"level_id":"missing"},{"level_fingerprint":"wrong"}]:
  var modified:=base.duplicate(true);modified.merge(patch,true);reject(signed(modified),"unsupported envelope "+str(patch))
 for pair in [["Q","unknown_action"],["L","illegal_replayed_action_at_0"],["RR","replay_final_state_mismatch"]]:
  var modified:=base.duplicate(true);modified.actions=pair[0];reject(signed(modified),"re-signed illegal history",pair[1])
 for patch in [{"moves":-1},{"moves":8193},{"moves":.5},{"pushes":2},{"player":[4294967297,1]},{"player":[2,2]},{"crates":[[0,0]]}]:
  var modified:=base.duplicate(true);modified.state.merge(patch,true);reject(signed(modified),"bad claimed state")
 var changed:=catalog.duplicate(true);changed[entry.id].glide=[]
 reject(interrupted.encoded.bytes,"changed rule fingerprint","level_rules_changed",changed)
 var alternate:=base.duplicate(true);alternate.actions="X"
 alternate.state={"player":entry.player,"crates":entry.crates,"moves":0,"pushes":0}
 ck(finish(c,c.begin_decode(signed(alternate),catalog)).status=="restored","valid re-sign accepted: checksum is not authentication")
 var initial:=Rules.initial(entry);var full:Array=[]
 for i in range(8192):full.append(initial.duplicate(true))
 var encoded:=finish(c,c.begin_encode(entry,initial,full,20),20)
 ck(encoded.status=="encoded" and encoded.history_count==8192,"full bound no truncation")
 restored=finish(c,c.begin_decode(encoded.bytes,catalog))
 ck(restored.history==full and restored.state==initial,"8192 snapshots exact")
 full.append(initial.duplicate(true));var old_full:=full.duplicate(true)
 var id:int=c.begin_encode(entry,initial,full,21)
 ck(c.poll().status=="history_limit" and not c.take_result(id,21).has("bytes"),"8193 refuses checkpoint")
 ck(full==old_full,"8193 does not mutate live Undo")
 ck(finish(c,c.begin_decode(interrupted.encoded.bytes,catalog,0)).status=="budget_exhausted","timeout not corruption")
 var slot:="user://audit_storage";var path:=slot+"/resume.json";var store:=Store.new(slot)
 ck(store.inspect().status=="missing","new slot inspected")
 ck(store.commit(interrupted.encoded,10).status=="saved","first actual commit")
 preserves(store,terminal.encoded,12,path,interrupted.encoded.bytes,"stale revision")
 var first:=Store.new(slot);authorize(first)
 var second:=Store.new(slot);authorize(second)
 ck(second.commit(terminal.encoded,11).status=="saved","second cooperative writer")
 preserves(first,interrupted.encoded,10,path,terminal.encoded.bytes,"disk-token race")
 var fail:=FailedRename.new(slot);authorize(fail)
 preserves(fail,interrupted.encoded,10,path,terminal.encoded.bytes,"rename failure")
 ck(not FileAccess.file_exists(slot+"/resume.pending"),"failed own pending removed")
 var guarded:=Store.new(slot);authorize(guarded)
 var unknown:="unknown pending - do not delete".to_utf8_buffer();write(slot+"/resume.pending",unknown)
 preserves(guarded,interrupted.encoded,10,path,terminal.encoded.bytes,"foreign pending")
 ck(FileAccess.get_file_as_bytes(slot+"/resume.pending")==unknown,"foreign pending retained")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(slot+"/resume.pending"))
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(slot+"/resume.lock"))
 preserves(guarded,interrupted.encoded,10,path,terminal.encoded.bytes,"foreign lock")
 ck(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(slot+"/resume.lock")),"foreign lock retained")
 for alias in ["user://","user://.","user:///","user:////","user://././","res://production","user://../escape"]:
  ck(Store.new(alias).inspect().status=="not_saved","invalid directory alias "+alias)
 var bad_slot:="user://audit_future";var future:='{ "version":999,"unknown":"keep exact" }'.to_utf8_buffer()
 write(bad_slot+"/resume.json",future);var protected:=Store.new(bad_slot)
 var disk:Dictionary=protected.inspect();var invalid:=finish(c,c.begin_decode(disk.bytes,catalog))
 ck(protected.accept_verified_load(invalid).status=="not_saved","future original never authorizes overwrite")
 preserves(protected,terminal.encoded,11,bad_slot+"/resume.json",future,"future original")
 report("storage.json",{"scope":"Fresh bounded codec/store and real file tests; no claim of authentication or physical power-loss durability."})
 quit(0 if failures.is_empty() else 1)
