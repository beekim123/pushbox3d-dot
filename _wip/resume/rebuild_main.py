"""Rebuild isolated main.gd from verified pre-resume baseline; never writes production."""
import hashlib
from pathlib import Path
base=Path('/workspace/scratch/e4cad742399c/fourfold_atelier/scripts/main.gd')
out=Path(__file__).parent/'main.gd'
s=base.read_text()
assert hashlib.sha256(base.read_bytes()).hexdigest()=='417544c6b1f43914bc8f83524d9037e073a7c84cb5ea9ac04cc7971dd0534e41'
s=s.replace('const VIEW =','const RESUME = preload("res://scripts/resume_controller.gd")\nconst VIEW =',1)
s=s.replace('var hints =','var resume_session\nvar resume_button: Button\nvar resume_label: Label\nvar exit_pending:=false\nvar exit_waiting:=false\nvar exit_started_ms:=0\nvar exit_timeout_ms:=1500\nvar exit_previous_mode:="title"\nvar exit_status: Label\nvar shutting_down:=false\nvar require_direction_release:=false\nvar hints =',1)
s=s.replace('\tsetup_audio()\n\tshow_title()','\tsetup_audio()\n\tif not qa_mode: initialize_resume()\n\tshow_title()',1)
s=s.replace('\tprogress_label = null\n','\tprogress_label = null\n\tresume_button=null\n\tresume_label=null\n',1)
s=s.replace('\tv.add_theme_constant_override("separation",22)','\tv.add_theme_constant_override("separation",14)',1)
s=s.replace('\tv.add_child(UI.button("操作与法则",show_help,Vector2(390,50)))','\tif resume_session:\n\t\tresume_button=UI.button("继续此前保存",continue_checkpoint,Vector2(390,52))\n\t\tresume_button.set_meta("resume_action","continue")\n\t\tv.add_child(resume_button)\n\t\tresume_label=wrapped("",390,16)\n\t\tv.add_child(resume_label)\n\t\trefresh_resume_ui()\n\tv.add_child(UI.button("操作与法则",show_help,Vector2(390,50)))',1)
s=s.replace('\tbuild_game_hud()\n\nfunc build_game_hud','\tbuild_game_hud()\n\tmark_resume_changed()\n\nfunc build_game_hud',1)
s=s.replace('copy.add_theme_constant_override("separation",5)','copy.add_theme_constant_override("separation",1)')
s=s.replace('\tcopy.add_child(status_label)\n','\tcopy.add_child(status_label)\n\tif resume_session:\n\t\tresume_label=UI.label("",13,UI.MUTED)\n\t\tcopy.add_child(resume_label)\n\t\trefresh_resume_ui()\n',1)
s=s.replace('\tstate=next\n\tmoving=true','\tstate=next\n\tmark_resume_changed()\n\tmoving=true',1)
s=s.replace('\tstate=history.pop_back()\n','\tstate=history.pop_back()\n\tmark_resume_changed()\n',1)
s=s.replace('\tstate=RULES.initial(level)\n\twin_shown=false','\tstate=RULES.initial(level)\n\tmark_resume_changed()\n\twin_shown=false',1)
s=s.replace('func _unhandled_key_input(event: InputEvent) -> void:\n','func _unhandled_key_input(event: InputEvent) -> void:\n\tif exit_pending: return\n',1)
s=s.replace('if not event is InputEventKey or not event.pressed or event.echo: return','if not event is InputEventKey or not event.pressed or event.echo: return\n\tif require_direction_release and event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]: return')
s=s.replace('if mode!="level" or modal: return\n\thold_timer','if require_direction_release or mode!="level" or modal: return\n\thold_timer',1)
s=s.replace('func _process(delta: float) -> void:\n\tpump_hints()','''func _process(delta: float) -> void:
	var frame_budget_start:=Time.get_ticks_usec()
	pump_hints()
	if resume_session and not shutting_down and not exit_waiting:
		var resume_budget:=maxf(0.0,2.0-(Time.get_ticks_usec()-frame_budget_start)/1000.0)
		if exit_pending and not exit_waiting: resume_budget=8.0
		if resume_budget>0.0: resume_session.tick(level,state,history,resume_budget,exit_pending and not exit_waiting)
		refresh_resume_ui()
		if exit_pending and not exit_waiting: poll_resume_exit()
	if exit_pending: return
	if require_direction_release:
		var held:=false
		for key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]:
			if Input.is_physical_key_pressed(key): held=true
		if not held: require_direction_release=false''',1)
s=s.replace('if mode=="level" and not moving and not modal:','if mode=="level" and not moving and not modal and not require_direction_release:',1)
s=s.replace('func finish_exit(code: int) -> void:\n\tmode="exiting"','func finish_exit(code: int) -> void:\n\tshutting_down=true\n\tif resume_session: resume_session.cancel_jobs()\n\tmode="exiting"',1)
s=s.replace('\t\tsave_progress()\n\t\tfinish_exit(0)\n','\t\trequest_exit()\n',1)
s=s.replace('if moving or mode!="level" or modal: return','if exit_pending or moving or mode!="level" or modal: return',1)
s=s.replace('if mode!="level" or history.is_empty(): return','if exit_pending or mode!="level" or history.is_empty(): return',1)
s=s.replace('func reset_level() -> void:\n\tif mode!="level": return','func reset_level() -> void:\n\tif exit_pending or mode!="level": return',1)
s+='''
func initialize_resume(directory: String="user://fourfold_resume") -> void:
	if resume_session: resume_session.cancel_jobs()
	resume_session=RESUME.new(RULES,levels,directory)

func mark_resume_changed() -> void:
	if resume_session:
		resume_session.changed()
		refresh_resume_ui()

func refresh_resume_ui() -> void:
	if not resume_session: return
	if is_instance_valid(resume_button): resume_button.disabled=resume_session.candidate.is_empty() or resume_session.reading
	if is_instance_valid(resume_label):
		resume_label.text=resume_session.message()
		if mode=="title" and (not resume_session.candidate.is_empty() or not resume_session.invalidated_summary.is_empty()): resume_label.text+="\\n此前保存："+resume_session.checkpoint_summary()

func continue_checkpoint() -> void:
	if not resume_session or exit_pending: return
	var restored: Dictionary=resume_session.take_checkpoint()
	if restored.is_empty():
		refresh_resume_ui()
		return
	var entry: Dictionary=resume_session.catalog[str(restored.level_id)]
	# start_level's transient new-game revision is immediately superseded below.
	start_level(entry)
	state=restored.state
	history=restored.history
	cancel_motion()
	world.sync_state(state)
	update_hud()
	resume_session.saved_revision=resume_session.revision
	resume_session.dirty=false
	resume_session.status="available"
	refresh_resume_ui()
	if RULES.won(level,state): complete_level()

func request_exit() -> void:
	if shutting_down: return
	if exit_pending: return
	save_progress()
	if not resume_session or not resume_session.dirty:
		finish_exit(0)
		return
	exit_pending=true
	exit_waiting=false
	exit_previous_mode=mode
	exit_started_ms=Time.get_ticks_msec()
	cancel_motion()
	var content:=open_modal("保存这一小段旅途","正在核对完整局面与撤销记录，请稍候。")
	exit_status=wrapped("不会保存动画或尚未执行的方向输入。",510,18)
	content.add_child(exit_status)

func poll_resume_exit() -> void:
	if not resume_session.dirty:
		finish_exit(0)
		return
	if not resume_session.paused and resume_session.status!="not_saved" and Time.get_ticks_msec()-exit_started_ms<exit_timeout_ms: return
	exit_waiting=true
	resume_session.cancel_jobs()
	refresh_resume_ui()
	var content:=open_modal("本次局面尚未保存",resume_session.message())
	content.add_child(wrapped("此前保存："+resume_session.checkpoint_summary()+"\\n这不是当前最新局面。上次核对记录仅供参考，不保证仍可恢复。未保存变化在退出后会丢失；本次完整撤销仍保留在当前游戏里。",510,19))
	var back:=UI.button("返回游戏，不丢掉当前局面",cancel_exit,Vector2(510,54))
	back.set_meta("resume_action","cancel_exit")
	content.add_child(back)
	var leave:=UI.button("仍然退出（本次未保存）",func(): finish_exit(0),Vector2(510,50))
	leave.set_meta("resume_action","exit_unsaved")
	content.add_child(leave)

func cancel_exit() -> void:
	require_direction_release=true
	exit_pending=false
	exit_waiting=false
	close_modal()
	mode=exit_previous_mode
	# A stopped win tween must still reconcile its committed logical endpoint.
	if mode=="level" and RULES.won(level,state) and not win_shown: complete_level()
	refresh_resume_ui()
'''
out.write_text(s)
print(hashlib.sha256(out.read_bytes()).hexdigest())
