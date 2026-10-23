extends RefCounted
# Lifecycle coordinator; no progress file access and no gameplay mutation.
const CODEC=preload("res://scripts/resume/resume_codec.gd")
const STORE=preload("res://scripts/resume/resume_store.gd")
var reader
var writer
var store
var catalog: Dictionary={}
var candidate: Dictionary={}
var revision:=0
var saved_revision:=-1
var dirty:=false
var reading:=false
var writing:=false
var read_id:=-1
var write_id:=-1
var writable:=false
var paused:=false
var reason:=""
var failure_kind:=""
var status:="idle"
var last_change_ms:=0
var last_write_ms:=-100000
var commits:=0
var debounce_ms:=1000
var interval_ms:=5000
var blocked_revision:=-1
var latest_summary:=""
var invalidated_summary:=""

func _init(rules: Script, entries: Array, directory: String="user://fourfold_resume"):
 reader=CODEC.new(rules)
 writer=CODEC.new(rules)
 store=STORE.new(directory)
 for entry in entries: catalog[str(entry.id)]=entry
 var inspected: Dictionary=store.inspect()
 if inspected.status=="missing":
  writable=true
  status="empty"
 elif inspected.status=="read":
  read_id=reader.begin_decode(inspected.bytes,catalog)
  reading=true
  status="checking"
 else:
  protect(str(inspected.get("reason","unavailable")))

func protect(why: String):
 if why=="checkpoint_changed_since_inspect" and not candidate.is_empty():
  invalidated_summary=checkpoint_summary()
  candidate={}
 writable=false
 paused=true
 reason=why
 status="paused"

func changed():
 revision+=1
 dirty=true
 blocked_revision=-1
 last_change_ms=Time.get_ticks_msec()
 if writing:
  writer.cancel()
  writing=false
 if writable: status="pending"

func tick(level: Dictionary,state: Dictionary,history: Array,budget_ms: float=2.0,force: bool=false):
 var began:=Time.get_ticks_usec()
 if reading:
  var loaded: Dictionary=reader.step_budget(budget_ms,read_id)
  if loaded.status!="running":
   reading=false
   if loaded.status=="restored":
    var restored: Dictionary=reader.take_result(read_id)
    var accepted: Dictionary=store.accept_verified_load(restored)
    if accepted.status=="authorized":
     candidate=restored
     writable=true
     status="pending" if dirty else "available"
    else: protect(str(accepted.reason))
   else: protect(str(loaded.get("reason",loaded.status)))
 if not writable or not dirty or level.is_empty() or blocked_revision==revision: return
 var now:=Time.get_ticks_msec()
 if not writing:
  if not force and (now-last_change_ms<debounce_ms or now-last_write_ms<interval_ms): return
  write_id=writer.begin_encode(level,state,history,revision)
  writing=true
  status="saving"
 var remaining:=budget_ms-(Time.get_ticks_usec()-began)/1000.0
 if remaining<=0: return
 var encoded_status: Dictionary=writer.step_budget(remaining,write_id,revision)
 if encoded_status.status=="running": return
 writing=false
 if encoded_status.status!="encoded":
  blocked_revision=revision
  status="not_saved"
  failure_kind=str(encoded_status.status)
  reason=str(encoded_status.get("reason",encoded_status.status))
  return
 var encoded: Dictionary=writer.take_result(write_id,revision)
 var committed: Dictionary=store.commit(encoded,revision)
 if committed.status!="saved":
  protect(str(committed.reason))
  return
 commits+=1
 last_write_ms=now
 saved_revision=revision
 dirty=false
 status="saved"
 reason=""
 latest_summary=str(level.name)+" · %d 步 / %d 推"%[state.moves,state.pushes]
 # Keep one complete owned checkpoint for the optional continue button.
 # Snapshots remain immutable; the array alone isolates future pop/append.
 candidate={"status":"restored","level_id":str(level.id),"state":state.duplicate(true),"history":history.duplicate(false),"input_token":committed.token,"won":bool(encoded.won),"validated_format":CODEC.FORMAT,"validated_version":CODEC.VERSION}

func checkpoint_summary() -> String:
 if candidate.is_empty():
  if not invalidated_summary.is_empty(): return invalidated_summary+"（仅供参考，已不能确认可恢复）"
  return "没有已核对可续玩的记录"
 var entry: Dictionary=catalog.get(str(candidate.level_id),{})
 return str(entry.get("name",candidate.level_id))+" · %d 步 / %d 推"%[candidate.state.moves,candidate.state.pushes]

func message() -> String:
 if reading: return "正在核对此前续玩记录……"
 if paused: return "续玩保存已暂停；原文件已保留。游玩与撤销不受影响。"
 if status=="not_saved":
  if failure_kind=="history_limit": return "续玩最多保存8192条完整历史；本次未保存，游戏内撤销仍完整。"
  if failure_kind=="budget_exhausted": return "核对超时，本次未保存；不代表记录损坏。此前记录保留。"
  return "本次未保存；保留此前记录。完整撤销不受影响。"
 if writing: return "正在核对完整续玩记录……"
 if dirty: return "本次局面尚未保存，停手后会自动保存。"
 if saved_revision>=0: return "已保存当前局面与完整撤销。"
 return "可继续此前保存；也可以直接去中庭。" if not candidate.is_empty() else "停手后自动保存局面与完整撤销。"

func take_checkpoint() -> Dictionary:
 if candidate.is_empty(): return {}
 # Recheck disk token even for an already-validated candidate.
 var accepted: Dictionary=store.accept_verified_load(candidate)
 if accepted.status!="authorized":
  protect(str(accepted.reason))
  return {}
 var restored:=candidate.duplicate(false)
 restored.history=candidate.history.duplicate(false)
 if writing: writer.cancel()
 writing=false
 revision+=1
 saved_revision=revision
 dirty=false
 status="available"
 return restored

func cancel_jobs():
 if reading:
  reader.cancel()
  protect("initial_verification_cancelled")
 if writing: writer.cancel()
 reading=false
 writing=false
