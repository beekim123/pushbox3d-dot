extends SceneTree
# Uses the real UI theme/SystemFont chain, not an unrelated installed-font lookup.
func _initialize():
	var ui_script = load("res://scripts/ui_kit.gd")
	var actual_theme = ui_script.theme(Color.WHITE)
	var font: Font = actual_theme.default_font
	var corpus = FileAccess.get_file_as_string("res://scripts/main.gd") + FileAccess.get_file_as_string("res://assets/levels.json")
	var unique = {}
	for i in range(corpus.length()):
		var cp = corpus.unicode_at(i)
		if (cp >= 0x3400 and cp <= 0x9fff) or (cp >= 0xf900 and cp <= 0xfaff): unique[cp] = true
	var missing = []
	for cp in unique:
		if not font.has_char(cp): missing.append(String.chr(cp))
	var families = []
	var server = TextServerManager.get_primary_interface()
	for rid in font.get_rids():
		var family = server.font_get_name(rid)
		if family not in families: families.append(family)
	var report = {"engine":Engine.get_version_info().string,"platform":OS.get_name(),"font_families":families,"source_files":["scripts/main.gd","assets/levels.json"],"unique_cjk_characters":unique.size(),"missing":missing,"passed":missing.is_empty(),"scope":"Cloud font coverage only; macOS font fallback not tested."}
	var file = FileAccess.open("res://tests/font_coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("FONT_COVERAGE platform=",OS.get_name()," unique_cjk=",unique.size()," missing=",missing," families=",families)
	quit(0 if missing.is_empty() else 1)
