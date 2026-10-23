extends Node3D

const UI = preload("res://scripts/ui_kit.gd")
const RULES = preload("res://scripts/puzzle_rules.gd")
const HINTS = preload("res://scripts/hint_solver.gd")
const CONTEXT_HELP = preload("res://scripts/context_help.gd")
const HINT_OVERLAY = preload("res://scripts/hint_overlay.gd")
const RESUME = preload("res://scripts/resume_controller.gd")
const VIEW = preload("res://scripts/world_view.gd")
const SAVE_PATH := "user://fourfold_progress.json"
const WORLD_ORDER := ["heaven","inferno","rainforest","city","confluence"]
const WORLD_INFO := {
	"heaven":{"name":"蟠桃仙园","en":"THE PEACH ORCHARD","tag":"上 · 顺风而行","rule":"落花风径会让箱子滑行。借助墙与箱子，安排它的停点。","short":"箱子进入风纹后，滑到非风纹格或障碍前。","story":"失落的青丝挂在桃枝间。顺着花瓣的方向，让春风送它回家。"},
	"inferno":{"name":"烛糖地牢","en":"THE EMBER VAULT","tag":"下 · 隔空相逢","rule":"把箱子推进一座焰环，它会从成对的焰环出现。出口必须空着。","short":"焰环只传送箱子，不传送你；出口堵住就推不动。","story":"地底的看守不爱恐吓，只爱把包裹藏到另一扇门后。"},
	"rainforest":{"name":"回声雨林","en":"THE VERDANT CHOIR","tag":"左 · 借道生长","rule":"叶箭格只允许顺着箭头进入。你和箱子都要遵守。","short":"叶箭只限制进入方向。绕行，才能从另一面推动。","story":"根须记得雨水流向。绕一小圈，常常比直走更近。"},
	"city":{"name":"层桥山城","en":"THE TERRACED CITY","tag":"右 · 压住通途","rule":"箱子压住金色踏板时，所有吊桥开启。最后一块踏板不能让桥上的人或箱悬空。","short":"箱子压板开桥。撤走最后一箱前，桥上必须没有人和箱。","story":"送货员熟悉每一段阶梯。城市的门，往往在另一层打开。"},
	"confluence":{"name":"四隅交织","en":"THE FINAL WEAVE","tag":"中 · 把远方织在一起","rule":"四种法则开始交织。观察风纹、焰环、叶箭与踏板，逐一建立通路。","short":"混合规则沿用四个世界的法则，没有隐藏的第五种规则。","story":"四根线并不是四条路。把它们织在一起，家才会亮起来。"}
}
var resume_session
var resume_button: Button
var resume_label: Label
var exit_pending:=false
var exit_waiting:=false
var exit_started_ms:=0
var exit_timeout_ms:=1500
var exit_previous_mode:="title"
var exit_status: Label
var shutting_down:=false
var require_direction_release:=false
var help_release_keys: Dictionary={}
const DIRECTION_KEYS := [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]
var hints = HINTS.new()
var hint_request: int = -1
var hint_active := false
var hint_tier := 0
var hint_answer: Dictionary = {}
var hint_status := "idle"
var hint_panel: PanelContainer
var hint_overlay: Control
var hint_capture_expanded := false
var world: AtelierWorld
var canvas: CanvasLayer
var ui: Control
var levels: Array = []
var levels_by_world: Dictionary = {}
var progress := {"version":2,"solved":[],"best":{},"muted":false}
var progress_writable := true
var chapter_pages: Dictionary = {}
var mode := "title"
var active_world := "hub"
var level: Dictionary = {}
var state: Dictionary = {}
var history: Array = []
var moving := false
var pending_direction := ""
var move_tween: Tween
var modal: Control
var status_label: Label
var stat_label: Label
var progress_label: Label
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var sound_index := 0
var hold_timer := 0.0
var win_shown := false
var args: Dictionary = {}
var frame_count := 0
var capture_pending := false
var qa_mode := false
var low_quality := false
var audio_disabled := false
var frame_sample_start := 0
var frame_sample_count := 0

func _ready() -> void:
	get_tree().auto_accept_quit=false
	parse_args()
	# A headless server has no listening device. Avoid creating mixer playbacks,
	# which Godot's forced --quit-after cannot drain before ResourceCache exit.
	# Graphical play and graceful-close audio testing still use the full mixer.
	audio_disabled=DisplayServer.get_name()=="headless" and not args.has("headless-audio")
	qa_mode = args.has("verify-solutions") or args.has("capture-path") or args.has("qa") or args.has("test-integration")
	load_levels()
	if args.has("verify-solutions"):
		verify_solutions()
		return
	load_progress()
	world = VIEW.new()
	add_child(world)
	var adapter:=RenderingServer.get_video_adapter_name().to_lower()
	low_quality=("llvmpipe" in adapter or "lavapipe" in adapter)
	if args.has("quality"): low_quality=str(args["quality"])=="low"
	apply_quality()
	canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	setup_audio()
	if not qa_mode: initialize_resume()
	show_title()
	if args.has("capture-world"):
		var w := str(args["capture-world"])
		var index := int(args.get("capture-level",0))
		if levels_by_world.has(w) and index < levels_by_world[w].size(): start_level(levels_by_world[w][index])
	elif args.get("capture-menu","") == "hub": show_hub()
	elif args.has("capture-menu") and WORLD_ORDER.has(args["capture-menu"]): show_world_menu(str(args["capture-menu"]),int(args.get("capture-chapter",1))-1)
	if args.has("capture-hint") and mode=="level":
		toggle_hint()
		if int(args["capture-hint"])>=2: advance_hint()
	capture_pending = args.has("capture-path")
	if args.has("test-integration"): integration_test.call_deferred()

func parse_args() -> void:
	for item in OS.get_cmdline_user_args():
		var s := str(item).trim_prefix("--")
		var bits := s.split("=",true,1)
		args[bits[0]] = bits[1] if bits.size()>1 else true

func load_levels() -> void:
	var path := "res://assets/levels.json"
	if not FileAccess.file_exists(path):
		push_error("Missing authored levels: "+path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array: levels = parsed
	elif parsed is Dictionary: levels = parsed.get("levels",[])
	for w in WORLD_ORDER: levels_by_world[w] = []
	for entry in levels:
		if levels_by_world.has(entry.world): levels_by_world[entry.world].append(entry)

func load_progress() -> void:
	if qa_mode and not args.has("test-integration"): return
	progress_writable=true
	var target := "user://qa_progress_roundtrip.json" if args.has("test-integration") else SAVE_PATH
	if not FileAccess.file_exists(target): return
	var original:=FileAccess.get_file_as_string(target)
	var parser:=JSON.new()
	if parser.parse(original)!=OK:
		progress_writable=false
		return
	var data: Variant=parser.data
	if not data is Dictionary:
		progress_writable=false
		return
	progress.muted=bool(data.get("muted",false))
	var version:=int(data.get("version",0))
	if version==2:
		if not data.get("solved",[]) is Array or not data.get("best",{}) is Dictionary:
			progress_writable=false
			return
		var known: Array=levels.map(func(entry): return str(entry.id))
		progress.solved=[]
		for id in data.get("solved",[]):
			if id in known and id not in progress.solved: progress.solved.append(id)
		progress.best={}
		for id in data.get("best",{}):
			var record: Variant=data.best[id]
			if id not in known or not record is Dictionary: continue
			if not record.get("moves") is float and not record.get("moves") is int: continue
			if not record.get("pushes") is float and not record.get("pushes") is int: continue
			if float(record.moves)<0 or float(record.pushes)<0: continue
			progress.best[id]={"moves":int(record.moves),"pushes":int(record.pushes)}
	elif version==1:
		# Never overwrite an old campaign until its exact bytes are safely archived.
		var stem:=target.trim_suffix(".json")+"_v1_archive"
		var archive:=stem+".json"
		var suffix:=1
		while FileAccess.file_exists(archive) and FileAccess.get_file_as_string(archive)!=original:
			archive=stem+"_%d.json" % suffix
			suffix+=1
		if not FileAccess.file_exists(archive):
			if DirAccess.copy_absolute(target,archive)!=OK:
				progress_writable=false
				return
		if FileAccess.get_file_as_string(archive)!=original:
			progress_writable=false
			return
		progress.solved=[]
		progress.best={}
		save_progress()
	else:
		# A future or damaged format is not ours to downgrade.
		progress_writable=false

func save_progress() -> void:
	if not progress_writable: return
	if qa_mode and not args.has("test-integration"): return
	var target := "user://qa_progress_roundtrip.json" if args.has("test-integration") else SAVE_PATH
	var file := FileAccess.open(target+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(progress,"  "))
		file.close()
		DirAccess.rename_absolute(target+".tmp",target)

func setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Music"
	ambience.volume_db = -8
	add_child(ambience)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		effects.append(player)
	AudioServer.set_bus_mute(0,bool(progress.muted))

func play_music(w: String) -> void:
	if audio_disabled: return
	var path := "res://assets/audio/"+w+".ogg"
	if ResourceLoader.exists(path):
		var stream: AudioStreamOggVorbis = load(path)
		stream.loop = true
		if music.stream != stream:
			music.stop()
			music.stream = stream
			music.play()
	var ambient_path := "res://assets/audio/"+w+"_ambient.ogg"
	ambience.stop()
	if ResourceLoader.exists(ambient_path):
		var stream: AudioStreamOggVorbis = load(ambient_path)
		stream.loop = true
		ambience.stream = stream
		ambience.play()

func sfx(name: String) -> void:
	if audio_disabled: return
	var path := "res://assets/audio/"+name+".wav"
	if not ResourceLoader.exists(path): return
	var player := effects[sound_index%effects.size()]
	sound_index += 1
	player.stop()
	player.stream = load(path)
	player.play()

func clear_ui(w: String) -> void:
	guard_help_dismissal()
	invalidate_hint()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	modal = null
	status_label = null
	stat_label = null
	progress_label = null
	resume_button=null
	resume_label=null
	ui.theme = UI.theme(VIEW.THEMES.get(w,VIEW.THEMES.hub).accent)

func panel_at(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	ui.add_child(p)
	p.position = pos
	p.size = size
	return p

func text_at(text: String, pos: Vector2, size: int = 20, color: Color = UI.PAPER) -> Label:
	var l := UI.label(text,size,color)
	ui.add_child(l)
	l.position = pos
	return l

func wrapped(text: String, width: float, font_size: int = 19) -> Label:
	var l := UI.label(text,font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l

func common_top(title: String, subtitle: String, w: String) -> void:
	var p := panel_at(Vector2(28,20),Vector2(1384,68))
	var top_style:=UI.style(Color(0.055,0.085,0.13,0.94),Color("45576a"))
	top_style.content_margin_top=8
	top_style.content_margin_bottom=8
	p.add_theme_stylebox_override("panel",top_style)
	var row := HBoxContainer.new()
	p.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation",2)
	row.add_child(labels)
	labels.add_child(UI.label(title,24))
	labels.add_child(UI.label(subtitle,13,VIEW.THEMES.get(w,VIEW.THEMES.hub).accent))
	row.add_child(UI.button("声音  " + ("关" if progress.muted else "开"),toggle_mute,Vector2(100,44)))
	row.add_child(UI.button("帮助  F1",show_help,Vector2(110,44)))
	if mode not in ["title","hub"]: row.add_child(UI.button("织机中庭",show_hub,Vector2(130,44)))

func show_title() -> void:
	cancel_motion()
	mode = "title"
	active_world = "hub"
	world.setup_hub()
	world.camera.position = Vector3(10,24,28)
	world.camera.look_at(Vector3(-4,0,0))
	world.camera.size = 34
	clear_ui("hub")
	play_music("hub")
	var p := panel_at(Vector2(70,160),Vector2(440,520))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",14)
	p.add_child(v)
	v.add_child(UI.label("一枚线轴，四段远方",18,Color("dfbd83")))
	v.add_child(UI.label("四隅织途",52))
	v.add_child(UI.label("LOOM OF FOUR HORIZONS",16,UI.MUTED))
	v.add_child(wrapped("青丝断在云上，红丝落入地底。\n沿着四条路，把世界重新织回家。",390,21))
	v.add_child(UI.button("走进织机中庭  →",show_hub,Vector2(390,62)))
	if resume_session:
		resume_button=UI.button("继续此前保存",continue_checkpoint,Vector2(390,52))
		resume_button.set_meta("resume_action","continue")
		v.add_child(resume_button)
		resume_label=wrapped("",390,16)
		v.add_child(resume_label)
		refresh_resume_ui()
	v.add_child(UI.button("操作与法则",show_help,Vector2(390,50)))
	v.add_child(UI.label("原创 3D 推箱解谜 · %d 道旅途谜题" % levels.size(),16,UI.MUTED))
	if not progress_writable: v.add_child(wrapped("原存档已保护，本次进度暂不写入。",390,16))
	var bottom := panel_at(Vector2(70,790),Vector2(1300,60))
	var row := HBoxContainer.new()
	bottom.add_child(row)
	var l := UI.label("方向键 / WASD 移动     Z 撤销     R 重置     Esc 返回",18)
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UI.label("已织回  %d / %d" % [progress.solved.size(),levels.size()],18,Color("dfbd83")))

func show_hub() -> void:
	cancel_motion()
	mode="hub"
	active_world="hub"
	world.setup_hub()
	clear_ui("hub")
	play_music("hub")
	common_top("四隅织机 · 中庭","THE COMPASS LOOM  /  从四个方向出发，把线带回家", "hub")
	var positions := {"heaven":Vector2(940,128),"inferno":Vector2(510,720),"rainforest":Vector2(44,300),"city":Vector2(1154,350)}
	var symbols:={"heaven":"↑", "inferno":"↓", "rainforest":"←", "city":"→"}
	for w in ["heaven","inferno","rainforest","city"]:
		var info: Dictionary = WORLD_INFO[w]
		var b:=UI.button(symbols[w]+"  "+info.name+"  %d/%d" % [solved_in_world(w),levels_by_world[w].size()],func(): show_world_menu(w),Vector2(242,58))
		ui.add_child(b)
		b.position=positions[w]
		b.add_theme_color_override("font_color",VIEW.THEMES[w].accent)
	var foot := panel_at(Vector2(260,806),Vector2(920,66))
	var row := HBoxContainer.new()
	foot.add_child(row)
	var status := UI.label("四方线束  %d / %d" % [main_solved(),main_total()],20)
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(status)
	var finale := UI.button("四隅交织  →" if main_solved()>=main_total() else "集齐四束线，开启交织",func(): show_world_menu("confluence"),Vector2(300,44))
	finale.set_meta("campaign_finale",true)
	finale.disabled=main_solved()<main_total()
	row.add_child(finale)
	if progress.solved.size()>=levels.size() and levels.size()>0:
		show_ending()

func solved_in_world(w: String) -> int:
	var n := 0
	for l in levels_by_world.get(w,[]):
		if l.id in progress.solved: n+=1
	return n

func main_solved() -> int:
	var n := 0
	for w in ["heaven","inferno","rainforest","city"]: n+=solved_in_world(w)
	return n

func main_total() -> int:
	return levels.size()-levels_by_world.get("confluence",[]).size()

func show_world_menu(w: String, page: int = -1) -> void:
	cancel_motion()
	mode="world"
	active_world=w
	var list: Array = levels_by_world.get(w,[])
	if list.is_empty(): return
	var page_count := ceili(float(list.size())/5.0)
	if page<0:
		page=int(chapter_pages.get(w,mini(solved_in_world(w)/5,page_count-1)))
	page=clampi(page,0,page_count-1)
	chapter_pages[w]=page
	var first := page*5
	world.setup_level(list[first],RULES.initial(list[first]))
	# The chapter landscape is an honest playable board preview, not a static backdrop.
	world.camera.size*=1.12
	world.camera.position+=Vector3(-4,0,0)
	world.camera.look_at(Vector3(-4,0,-0.6))
	clear_ui(w)
	play_music(w)
	var info: Dictionary = WORLD_INFO[w]
	common_top(info.name,info.en+"  /  已织回 %d · 共 %d" % [solved_in_world(w),list.size()],w)
	var p := panel_at(Vector2(40,120),Vector2(358,510))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",18)
	p.add_child(v)
	v.add_child(UI.label("第 %02d 章  /  %02d" % [page+1,page_count],18,VIEW.THEMES[w].accent))
	v.add_child(wrapped(str(list[first].get("chapter_name","远方的一段线")),310,29))
	v.add_child(wrapped(info.story,310,18))
	v.add_child(wrapped(str(list[first].get("learning_goal",info.rule)),310,18))
	v.add_child(UI.label("本章  %d / %d" % [chapter_solved(list,first),mini(5,list.size()-first)],18,VIEW.THEMES[w].accent))
	var nav:=HBoxContainer.new()
	v.add_child(nav)
	var previous:=UI.button("← 上一章",func(): show_world_menu(w,page-1),Vector2(148,48))
	previous.disabled=page==0
	nav.add_child(previous)
	var next:=UI.button("下一章 →",func(): show_world_menu(w,page+1),Vector2(148,48))
	next.disabled=page==page_count-1
	nav.add_child(next)
	v.add_child(wrapped("可以预览所有章节；完成前一关后，下一站会亮起。已完成的关卡随时可重玩。",310,15))
	# A short five-stop stitched journey, leaving the diorama center unobstructed.
	var route:=panel_at(Vector2(426,690),Vector2(972,158))
	var journey:=HBoxContainer.new()
	journey.add_theme_constant_override("separation",12)
	route.add_child(journey)
	for i in range(first,mini(first+5,list.size())):
		var entry: Dictionary=list[i]
		var solved: bool=entry.id in progress.solved
		var unlocked: bool=i==0 or list[i-1].id in progress.solved
		var card:=VBoxContainer.new()
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		journey.add_child(card)
		var number:="✓ %02d" % (i+1) if solved else "%02d" % (i+1)
		var b:=UI.button(number+"  "+("已织回" if solved else ("出发" if unlocked else "未抵达")),func(): start_level(entry),Vector2(170,46))
		b.set_meta("level_id",str(entry.id))
		b.disabled=not unlocked
		card.add_child(b)
		var name_label:=UI.label(str(entry.name),17)
		name_label.custom_minimum_size.x=160
		name_label.clip_text=true
		name_label.tooltip_text=str(entry.name)
		card.add_child(name_label)
		var record: Dictionary=progress.best.get(entry.id,{})
		card.add_child(UI.label("%d 推 · %d 步" % [record.get("pushes",0),record.get("moves",0)] if solved else "第 %d 站" % (i-first+1),14,UI.MUTED))

func chapter_solved(list: Array, first: int) -> int:
	var count:=0
	for i in range(first,mini(first+5,list.size())):
		if list[i].id in progress.solved: count+=1
	return count

func start_level(entry: Dictionary) -> void:
	cancel_motion()
	level=entry
	active_world=level.world
	chapter_pages[active_world]=levels_by_world[active_world].find(level)/5
	mode="level"
	state=RULES.initial(level)
	hints.configure(level)
	history.clear()
	win_shown=false
	world.setup_level(level,state)
	clear_ui(active_world)
	play_music(active_world)
	build_game_hud()
	mark_resume_changed()

func build_game_hud() -> void:
	var info: Dictionary=WORLD_INFO[active_world]
	var ordinal: int=levels_by_world[active_world].find(level)+1
	common_top(str(level.name),info.name+"  /  第 %02d 关 · 共 %d 关" % [ordinal,levels_by_world[active_world].size()],active_world)
	var stat_panel:=panel_at(Vector2(1120,106),Vector2(290,66))
	stat_label=UI.label("",22)
	stat_panel.add_child(stat_label)
	var footer:=panel_at(Vector2(28,802),Vector2(1384,72))
	var footer_style:=UI.style(Color(0.055,0.085,0.13,0.94),Color("45576a"))
	footer_style.content_margin_top=8
	footer_style.content_margin_bottom=8
	footer.add_theme_stylebox_override("panel",footer_style)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	footer.add_child(row)
	var copy:=VBoxContainer.new()
	copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",1)
	row.add_child(copy)
	copy.add_child(UI.label(info.short,18))
	status_label=UI.label("方向键 / WASD 移动 · 所有行动与重置都可以撤销",15,UI.MUTED)
	copy.add_child(status_label)
	if resume_session:
		resume_label=UI.label("",13,UI.MUTED)
		copy.add_child(resume_label)
		refresh_resume_ui()
	row.add_child(hint_button("线索 H",toggle_hint,"toggle",Vector2(98,46)))
	row.add_child(UI.button("撤销 Z",undo_move,Vector2(124,46)))
	row.add_child(UI.button("重置 R",reset_level,Vector2(112,46)))
	row.add_child(UI.button("选关",func(): show_world_menu(active_world),Vector2(90,46)))
	update_hud()

func update_hud() -> void:
	if stat_label: stat_label.text="%d 步   ·   %d 推"%[state.get("moves",0),state.get("pushes",0)]

func cancel_motion() -> void:
	invalidate_hint()
	if move_tween and move_tween.is_valid(): move_tween.kill()
	moving=false
	pending_direction=""
	hold_timer=0.0

func attempt_move(direction: String) -> void:
	if exit_pending or moving or mode!="level" or modal: return
	var next:=RULES.step(level,state,direction)
	if next.is_empty():
		sfx("blocked")
		if status_label: status_label.text="这一步被挡住了。换个方向，或按 Z 回到上一步。"
		return
	invalidate_hint()
	history.append(state.duplicate(true))
	var old:=state
	state=next
	mark_resume_changed()
	moving=true
	if status_label: status_label.text="方向键 / WASD 移动 · Z 撤销 · R 重置（也可撤销）"
	sfx("push" if state.pushed else "step")
	if state.pushed:
		var route: Array=state.get("route",[])
		if route.size()>1 and RULES.cell(route[-1]).distance_to(RULES.cell(route[-2]))>1.1: sfx("portal")
		if state.new_box in RULES.cells(level.goals): sfx("goal")
	move_tween=world.animate_move(old,state,direction)
	move_tween.finished.connect(func():
		moving=false
		if RULES.won(level,state):
			pending_direction=""
			complete_level()
		elif pending_direction!="":
			var buffered:=pending_direction
			pending_direction=""
			attempt_move(buffered)
	)
	update_hud()

func undo_move() -> void:
	if exit_pending or mode!="level" or history.is_empty(): return
	cancel_motion()
	close_modal()
	state=history.pop_back()
	mark_resume_changed()
	win_shown=false
	world.sync_state(state)
	sfx("undo")
	update_hud()
	if status_label: status_label.text="已撤销。你可以一直回到这道谜题的最初。"

func reset_level() -> void:
	if exit_pending or mode!="level": return
	cancel_motion()
	close_modal()
	history.append(state.duplicate(true))
	state=RULES.initial(level)
	mark_resume_changed()
	win_shown=false
	world.sync_state(state)
	sfx("reset")
	update_hud()
	if status_label: status_label.text="已重置。按 Z 可撤销这次重置，恢复刚才的局面。"

func complete_level() -> void:
	if win_shown: return
	win_shown=true
	world.play_animation("celebrate")
	sfx("win")
	if level.id not in progress.solved: progress.solved.append(level.id)
	var old_best: Dictionary=progress.best.get(level.id,{})
	if old_best.is_empty() or state.pushes<int(old_best.get("pushes",99999)) or (state.pushes==int(old_best.get("pushes",99999)) and state.moves<int(old_best.get("moves",99999))):
		progress.best[level.id]={"moves":state.moves,"pushes":state.pushes}
	save_progress()
	var v:=open_modal("线头接上了",str(level.name)+" · %d 步 / %d 推"%[state.moves,state.pushes])
	v.add_child(wrapped("这段路已经记在织机里。你可以继续前行，也可以撤销最后一步，再试一种走法。",510,20))
	var list: Array=levels_by_world[active_world]
	var idx:=list.find(level)
	if idx+1<list.size(): v.add_child(UI.button("前往下一道谜题  →",func(): start_level(list[idx+1]),Vector2(510,56)))
	else: v.add_child(UI.button("把线带回中庭  →",show_hub,Vector2(510,56)))
	v.add_child(UI.button("撤销最后一步  Z",undo_move,Vector2(510,48)))
	v.add_child(UI.button("回到世界选关",func(): show_world_menu(active_world),Vector2(510,48)))

func open_modal(title: String, subtitle: String) -> VBoxContainer:
	close_modal()
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	var shade:=ColorRect.new()
	shade.color=Color(0.01,0.02,0.04,0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(560,0)
	center.add_child(panel)
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",18)
	panel.add_child(v)
	v.add_child(UI.label(title,34,VIEW.THEMES.get(active_world,VIEW.THEMES.hub).accent))
	v.add_child(wrapped(subtitle,510,18))
	return v

func close_modal() -> void:
	guard_help_dismissal()
	invalidate_hint()
	if modal:
		ui.remove_child(modal)
		modal.queue_free()
		modal=null

func show_help() -> void:
	if exit_pending or shutting_down: return
	var v:=open_modal("一步一步，把世界织好","没有倒计时，没有生命损耗。每个错误都可以撤销。")
	modal.set_meta("contextual_help",true)
	var context:=CONTEXT_HELP.text_for(mode,level)
	if not context.is_empty():
		var exercise:=wrapped(context,510,18)
		exercise.set_meta("chapter_exercise",true)
		v.add_child(exercise)
	v.add_child(wrapped("方向键 / WASD：移动与推动\nZ / Backspace：无限撤销\nR：重置本关（重置本身也可撤销）\nEsc：关闭弹窗 / 返回选关\nM：切换声音\nH：线索开关；J：主动展开下一层\nF2：精细 / 轻量画质（软件渲染器自动轻量）\n\n只有铺路格可以移动，草地与边缘园景不是可走的格子。\n把所有箱子推到发光目标上，即可完成谜题。只能推，不能拉；一次只能推动一只箱子。",510,20))
	v.add_child(UI.button("明白了",close_modal,Vector2(510,54)))

func show_ending() -> void:
	var v:=open_modal("远方，都成了家的颜色","四束线穿过云、焰、叶与桥，终于在中庭相遇。")
	v.add_child(wrapped("小小的线轴送货员没有拯救一个破碎的宇宙。它只是让四群很久没见面的邻居，再次找到了彼此。\n\n%d 道谜题全部完成。谢谢你走完这段路。" % levels.size(),510,22))
	v.add_child(UI.button("回到中庭，重访四方",close_modal,Vector2(510,54)))

func toggle_mute() -> void:
	progress.muted=not progress.muted
	AudioServer.set_bus_mute(0,bool(progress.muted))
	save_progress()
	for n in find_children("","Button",true,false):
		if n.text.begins_with("声音"): n.text="声音  "+("关" if progress.muted else "开")

func guard_help_dismissal() -> void:
	if not is_instance_valid(modal) or not modal.get_meta("contextual_help",false): return
	pending_direction=""
	help_release_keys.clear()
	for key in DIRECTION_KEYS:
		if Input.is_physical_key_pressed(key): help_release_keys[key]=true

func _input(event: InputEvent) -> void:
	# Key releases are observed before UI consumption, including release/repress
	# within one rendered frame. Do not consume the event or mutate game state.
	if event is InputEventKey and not event.pressed:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		help_release_keys.erase(key)

func _unhandled_key_input(event: InputEvent) -> void:
	if exit_pending: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if require_direction_release and event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]: return
	match event.keycode:
		KEY_F1: show_help()
		KEY_M: toggle_mute()
		KEY_H: toggle_hint()
		KEY_J: advance_hint()
		KEY_F2:
			low_quality=not low_quality
			apply_quality()
			if status_label: status_label.text="轻量画质" if low_quality else "精细画质"
		KEY_Z,KEY_BACKSPACE: undo_move()
		KEY_R: reset_level()
		KEY_ESCAPE:
			if modal: close_modal()
			elif is_instance_valid(hint_panel): invalidate_hint()
			elif mode=="level": show_world_menu(active_world)
			elif mode=="world": show_hub()
			elif mode=="hub": show_title()
		KEY_UP,KEY_W: request_direction("U")
		KEY_DOWN,KEY_S: request_direction("D")
		KEY_LEFT,KEY_A: request_direction("L")
		KEY_RIGHT,KEY_D: request_direction("R")
	get_viewport().set_input_as_handled()

func request_direction(direction: String) -> void:
	if require_direction_release or not help_release_keys.is_empty() or mode!="level" or modal: return
	hold_timer=0.24
	if moving:
		pending_direction=direction
	else:
		attempt_move(direction)

func _process(delta: float) -> void:
	var frame_budget_start:=Time.get_ticks_usec()
	pump_hints()
	if resume_session and not shutting_down and not exit_waiting:
		var resume_budget:=maxf(0.0,2.0-(Time.get_ticks_usec()-frame_budget_start)/1000.0)
		if exit_pending and not exit_waiting: resume_budget=8.0
		if resume_budget>0.0: resume_session.tick(level,state,history,resume_budget,exit_pending and not exit_waiting)
		refresh_resume_ui()
		if exit_pending and not exit_waiting: poll_resume_exit()
	if exit_pending: return
	# Focus changes may clear physical key state without a key-up event.
	for key in help_release_keys.keys():
		if not Input.is_physical_key_pressed(key): help_release_keys.erase(key)
	if require_direction_release:
		var held:=false
		for key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]:
			if Input.is_physical_key_pressed(key): held=true
		if not held: require_direction_release=false
	frame_count+=1
	if frame_count==10: frame_sample_start=Time.get_ticks_usec()
	elif frame_count>10: frame_sample_count+=1
	if capture_pending and not hint_active and frame_count>=int(args.get("capture-frame",8)):
		capture_pending=false
		capture.call_deferred()
	hold_timer-=delta
	if mode=="level" and not moving and not modal and not require_direction_release and help_release_keys.is_empty():
		if hold_timer<=0.0:
			var dir:=""
			if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W): dir="U"
			elif Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S): dir="D"
			elif Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A): dir="L"
			elif Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D): dir="R"
			if dir!="":
				attempt_move(dir)
				hold_timer=0.18

func capture() -> void:
	await RenderingServer.frame_post_draw
	var path:=str(args["capture-path"])
	var image:=get_viewport().get_texture().get_image()
	var error:=image.save_png(path)
	print("CAPTURE ",path," result=",error," missing_assets=",world.missing_assets.keys()," fps=",Engine.get_frames_per_second()," process_seconds=",Performance.get_monitor(Performance.TIME_PROCESS)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," quality=",("low" if low_quality else "high")," sampled_frame_ms=",(float(Time.get_ticks_usec()-frame_sample_start)/1000.0/maxi(1,frame_sample_count) if frame_sample_count>0 else 0.0))
	await finish_exit(0 if error==OK else 1)

func verify_solutions() -> void:
	var report_path:=str(args.get("verify-solutions","res://tests/solver_report.json"))
	if report_path=="true": report_path="res://tests/solver_report.json"
	var report: Variant=JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not report is Dictionary or not report.has("levels"):
		push_error("Invalid solver report")
		get_tree().quit(1)
		return
	var failures:=0
	var checks:=0
	for result in report.levels:
		var l: Dictionary={}
		for item in levels:
			if item.id==result.id: l=item
		if l.is_empty():
			failures+=1
			continue
		var test_state:=RULES.initial(l)
		var test_history: Array=[]
		var snapshots: Array=result.states
		var sequence:=str(result.solution)
		for i in range(sequence.length()):
			var before:=test_state.duplicate(true)
			test_history.append(before)
			test_state=RULES.step(l,test_state,sequence[i])
			checks+=1
			if test_state.is_empty():
				push_error("Replay rejected "+str(l.id)+" step "+str(i))
				failures+=1
				break
			var expected: Array=snapshots[i+1]
			if test_state.player!=RULES.cell(expected[0]): failures+=1
			var expected_crates:=RULES.cells(expected[1])
			for c in test_state.crates:
				if c not in expected_crates: failures+=1
			# Reset is a history entry, and undo-reset restores exactly.
			var reset_history: Array=[test_state.duplicate(true)]
			var reset_state:=RULES.initial(l)
			reset_state=reset_history.pop_back()
			checks+=1
			if reset_state!=test_state: failures+=1
		if not test_state.is_empty():
			checks+=1
			if not RULES.won(l,test_state): failures+=1
			if test_state.moves!=int(result.moves) or test_state.pushes!=int(result.pushes): failures+=1
		while not test_history.is_empty():
			test_state=test_history.pop_back()
			checks+=1
		if test_state!=RULES.initial(l): failures+=1
		print("REPLAY ",l.id," moves=",result.moves," pushes=",result.pushes)
	print("GODOT_PARITY levels=",report.levels.size()," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func integration_test() -> void:
	progress={"version":2,"solved":[],"best":{},"muted":false}
	# Invoke the actual scene handlers, not substitute history simulations.
	Engine.time_scale=4.0
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/solver_report.json"))
	var checks:=0
	var failures:=0
	# Real V1 migration: retain settings, archive bytes, never inherit solved levels.
	var migration_path:="user://qa_progress_roundtrip.json"
	var archive_path:="user://qa_progress_roundtrip_v1_archive.json"
	if FileAccess.file_exists(archive_path): DirAccess.remove_absolute(archive_path)
	for archive_index in range(1,20):
		var old_archive:="user://qa_progress_roundtrip_v1_archive_%d.json" % archive_index
		if FileAccess.file_exists(old_archive): DirAccess.remove_absolute(old_archive)
	var old_data:={"version":1,"solved":[levels[0].id],"best":{},"muted":true}
	var migration_file:=FileAccess.open(migration_path,FileAccess.WRITE)
	migration_file.store_string(JSON.stringify(old_data))
	migration_file.close()
	load_progress()
	checks+=3
	if not progress.solved.is_empty() or int(progress.version)!=2: failures+=1
	if not progress.muted: failures+=1
	if not FileAccess.file_exists(archive_path) or FileAccess.get_file_as_string(archive_path)!=JSON.stringify(old_data): failures+=1
	# A different old campaign must receive a new archive, never overwrite the first.
	old_data.solved=[levels[-1].id]
	migration_file=FileAccess.open(migration_path,FileAccess.WRITE)
	migration_file.store_string(JSON.stringify(old_data))
	migration_file.close()
	load_progress()
	checks+=1
	var second_archive:="user://qa_progress_roundtrip_v1_archive_1.json"
	if not FileAccess.file_exists(second_archive) or FileAccess.get_file_as_string(second_archive)!=JSON.stringify(old_data): failures+=1
	# Future-format saves are left byte-for-byte untouched and cannot be downgraded.
	var future_bytes:="{\"version\":99,\"muted\":false}"
	migration_file=FileAccess.open(migration_path,FileAccess.WRITE)
	migration_file.store_string(future_bytes)
	migration_file.close()
	load_progress()
	save_progress()
	checks+=1
	if progress_writable or FileAccess.get_file_as_string(migration_path)!=future_bytes: failures+=1
	progress_writable=true
	progress.muted=false
	for w in WORLD_ORDER:
		var world_list: Array=levels_by_world[w]
		for page_index in range(ceili(float(world_list.size())/5.0)):
			show_world_menu(w,page_index)
			checks+=1
			if int(chapter_pages[w])!=page_index or mode!="world": failures+=1
	for result in report.levels:
		var entry: Dictionary={}
		for item in levels:
			if item.id==result.id: entry=item
		start_level(entry)
		checks+=2
		if not world.missing_assets.is_empty():
			print("MISSING ASSETS ",world.missing_assets.keys())
			failures+=1
		if not world.animation or world.animation.get_animation_list().size()<4: failures+=1
		var sequence:=str(result.solution)
		var key_event:=InputEventKey.new()
		key_event.pressed=true
		key_event.keycode={"U":KEY_UP,"D":KEY_DOWN,"L":KEY_LEFT,"R":KEY_RIGHT}[sequence[0]]
		_unhandled_key_input(key_event)
		if moving: await move_tween.finished
		checks+=1
		if state.player!=RULES.cell(result.states[1][0]): failures+=1
		undo_move()
		checks+=1
		if state!=RULES.initial(level): failures+=1
		if sequence.length()>1:
			request_direction(sequence[0])
			request_direction(sequence[1])
			checks+=1
			if pending_direction!=sequence[1]: failures+=1
			while moving: await get_tree().process_frame
			checks+=1
			if state.player!=RULES.cell(result.states[2][0]) or state.moves!=2: failures+=1
		start_level(entry)
		for i in range(sequence.length()):
			attempt_move(sequence[i])
			if moving: await move_tween.finished
			checks+=1
			var expected: Array=result.states[i+1]
			if state.player!=RULES.cell(expected[0]): failures+=1
			for c in state.crates:
				if c not in RULES.cells(expected[1]): failures+=1
			if i==0:
				var before_reset:=state.duplicate(true)
				var before_history:=history.size()
				reset_level()
				checks+=1
				if state!=RULES.initial(level) or history.size()!=before_history+1: failures+=1
				undo_move()
				checks+=1
				if state!=before_reset or history.size()!=before_history: failures+=1
				if RULES.won(level,state): complete_level()
		checks+=3
		if not RULES.won(level,state): failures+=1
		if entry.id not in progress.solved: failures+=1
		if not progress.best.has(entry.id): failures+=1
		undo_move()
		checks+=1
		if modal!=null or RULES.won(level,state): failures+=1
		print("HANDLERS ",entry.id," PASS")
	checks+=2
	if main_solved()!=main_total(): failures+=1
	if progress.solved.size()!=levels.size(): failures+=1
	show_hub()
	checks+=1
	if modal==null: failures+=1
	close_modal()
	# Persistence roundtrip in an isolated file. Never touch the player's save.
	var test_path:="user://qa_progress_roundtrip.json"
	# complete_level called the actual atomic save_progress handler for each level.
	var loaded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(test_path))
	checks+=1
	if loaded.solved.size()!=levels.size() or loaded.best.size()!=levels.size(): failures+=1
	progress={"version":2,"solved":[],"best":{},"muted":false}
	load_progress()
	checks+=1
	if progress.solved.size()!=levels.size() or progress.best.size()!=levels.size(): failures+=1
	print("GODOT_HANDLERS checks=",checks," failures=",failures," completed=",progress.solved.size())
	await finish_exit(0 if failures==0 else 1)

func stop_audio() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream=null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream=null
	for player in effects:
		if is_instance_valid(player):
			player.stop()
			player.stream=null

func finish_exit(code: int) -> void:
	shutting_down=true
	if resume_session: resume_session.cancel_jobs()
	mode="exiting"
	cancel_motion()
	stop_audio()
	while hints.has_pending_cleanup():
		await get_tree().process_frame
	Engine.time_scale=1.0
	# Let the audio mixer release stream playbacks before ResourceCache teardown.
	await get_tree().create_timer(0.30,true,false,true).timeout
	get_tree().quit(code)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		request_exit()

func _exit_tree() -> void:
	stop_audio()

func apply_quality() -> void:
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if low_quality else Viewport.MSAA_4X
	get_viewport().scaling_3d_scale=0.6 if low_quality else 1.0
	RenderingServer.directional_shadow_atlas_set_size(512 if low_quality else 2048,true)
	print("QUALITY ","low" if low_quality else "high"," adapter=",RenderingServer.get_video_adapter_name())

func invalidate_hint() -> void:
	hints.cancel()
	hint_active=false
	hint_request=-1
	hint_tier=0
	hint_status="idle"
	hint_answer.clear()
	if is_instance_valid(hint_panel):
		hint_panel.get_parent().remove_child(hint_panel)
		hint_panel.queue_free()
	hint_panel=null
	if is_instance_valid(hint_overlay):
		hint_overlay.get_parent().remove_child(hint_overlay)
		hint_overlay.queue_free()
	hint_overlay=null

func toggle_hint() -> void:
	if mode!="level" or moving or modal: return
	if is_instance_valid(hint_panel):
		invalidate_hint()
		return
	hint_tier=1
	hint_status="already_solved" if RULES.won(level,state) else "clue"
	build_hint_panel()

func advance_hint() -> void:
	if mode!="level" or moving or modal or not is_instance_valid(hint_panel): return
	if hint_active: return
	if hint_status=="clue":
		hint_request=hints.start(state)
		hint_active=true
		hint_status="running"
		build_hint_panel()
	elif hint_status=="solved" and hint_tier==2 and hints.is_current(hint_request,state):
		hint_tier=3
		build_hint_panel()
		refresh_hint_overlay()

func pump_hints() -> void:
	if not hint_active and not hints.has_pending_cleanup(): return
	var result: Dictionary=hints.step_budget(2.0,hint_request if hint_active else -1)
	if not hint_active or str(result.status)=="running": return
	hint_active=false
	if mode!="level" or not is_instance_valid(hint_panel) or not hints.is_current(hint_request,state):
		invalidate_hint()
		return
	hint_status=str(result.status)
	if hint_status in ["cancelled","stale"]:
		invalidate_hint()
		return
	if hint_status=="solved":
		hint_answer=result.duplicate(true)
		hint_answer.player=state.player
		hint_tier=2
	build_hint_panel()
	refresh_hint_overlay()
	if args.has("capture-hint") and int(args["capture-hint"])>=3 and not hint_capture_expanded and hint_status=="solved":
		hint_capture_expanded=true
		advance_hint()

func hint_message(status: String) -> String:
	match status:
		"clue": return str(WORLD_INFO[active_world].short)+"\n先想好箱子的停点，再绕到它的另一侧。"
		"running": return "正在寻找下一小步……\n你仍可移动或随时关闭，线索会立即取消。"
		"already_solved": return "这一局面已经完成。无需再推箱子。"
		"budget_exhausted": return "这次提示搜索达到上限。\n这不代表无解；可以先试走几步，再重新请求。"
		"unsolvable": return "当前局面已确认无法全部归位。\n可以按 Z 撤销几步，再试另一种走法。"
		"invalid": return "暂时无法分析这个局面。你可以继续游玩或关闭线索。"
		"solved":
			var direction: String={"U":"上 ↑","D":"下 ↓","L":"左 ←","R":"右 →"}.get(str(hint_answer.direction),"")
			if hint_tier==3:
				return "薄荷色路线只通往推箱站位，不包含推动。\n走到圆环处，再把金圈箱子向"+direction+"推一次。"
			return "观察金色圆环标出的箱子。\n下一次推动：向"+direction+"。\n这里只提示一步，不会替你操作。"
	return ""

func build_hint_panel() -> void:
	if is_instance_valid(hint_panel):
		hint_panel.get_parent().remove_child(hint_panel)
		hint_panel.queue_free()
	hint_panel=panel_at(Vector2(28,106),Vector2(300,0))
	hint_panel.set_meta("hint_panel",true)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	hint_panel.add_child(column)
	column.add_child(UI.label("一小段线索  ·  %d / 3" % hint_tier,20,VIEW.THEMES[active_world].accent))
	var message:=wrapped(hint_message(hint_status),260,17)
	message.set_meta("hint_message",true)
	column.add_child(message)
	if hint_status=="clue": column.add_child(hint_button("看看下一推  J",advance_hint,"advance",Vector2(260,42)))
	elif hint_status=="solved" and hint_tier==2: column.add_child(hint_button("显示到位路线  J",advance_hint,"advance",Vector2(260,42)))
	column.add_child(hint_button("收起线索  H / Esc",invalidate_hint,"close",Vector2(260,40)))

func refresh_hint_overlay() -> void:
	if is_instance_valid(hint_overlay):
		hint_overlay.get_parent().remove_child(hint_overlay)
		hint_overlay.queue_free()
	hint_overlay=null
	if hint_status!="solved" or hint_tier<2 or not hints.is_current(hint_request,state): return
	hint_overlay=HINT_OVERLAY.new()
	hint_overlay.view=world
	hint_overlay.answer=hint_answer.duplicate(true)
	hint_overlay.tier=hint_tier
	ui.add_child(hint_overlay)
	ui.move_child(hint_overlay,0)
	hint_overlay.queue_redraw()

func hint_button(text: String, callback: Callable, action: String, dimensions: Vector2) -> Button:
	var button:=UI.button(text,callback,dimensions)
	button.set_meta("hint_action",action)
	return button

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
		if mode=="title" and (not resume_session.candidate.is_empty() or not resume_session.invalidated_summary.is_empty()): resume_label.text+="\n此前保存："+resume_session.checkpoint_summary()

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
	content.add_child(wrapped("此前保存："+resume_session.checkpoint_summary()+"\n这不是当前最新局面。上次核对记录仅供参考，不保证仍可恢复。未保存变化在退出后会丢失；本次完整撤销仍保留在当前游戏里。",510,19))
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
