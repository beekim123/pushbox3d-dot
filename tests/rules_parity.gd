extends SceneTree

const Rules = preload("res://scripts/puzzle_rules.gd")

func canonical(state: Dictionary) -> Array:
	var crates: Array = []
	for c in state.crates:
		crates.append([c.x, c.y])
	crates.sort_custom(func(a, b): return int(a[0])*100+int(a[1]) < int(b[0])*100+int(b[1]))
	return [[state.player.x, state.player.y], crates]

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
	var by_id: Dictionary = {}
	for level in data.levels:
		by_id[level.id] = level
	var matrix: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/rules_matrix.json"))
	var count: int = 0
	var failures: int = 0
	for case in matrix.cases:
		var state: Dictionary = {"player": Rules.cell(case.state[0]), "crates": Rules.cells(case.state[1]), "moves": 0, "pushes": 0}
		for action in ["U", "D", "L", "R"]:
			count += 1
			var result: Dictionary = Rules.step(by_id[case.level], state, action)
			var expected: Variant = case.expected[action]
			if expected == null:
				if not result.is_empty():
					failures += 1
					push_error("Expected blocked: %s %s %s" % [case.level, case.state, action])
			elif result.is_empty() or canonical(result) != canonical({"player": Rules.cell(expected.state[0]), "crates": Rules.cells(expected.state[1])}) or int(result.get("pushes", -1)) != int(expected.pushed):
				failures += 1
				push_error("Transition mismatch: %s %s %s" % [case.level, case.state, action])
	print("RULE_MATRIX: %d transitions; %d failures" % [count, failures])
	quit(0 if failures == 0 else 1)
