extends SceneTree
# Cross-check legal AND blocked transitions against independently sampled Python states.
# Run after: python tools/sample_parity_v2.py
func _initialize():
	var rules = load("res://scripts/puzzle_rules.gd")
	var levels = {}
	for level in JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json")).levels:
		levels[level.id] = level
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/independent_cases_v2.json"))
	var failures = 0
	for c in cases:
		var state = {"player": rules.cell(c.player), "crates":rules.cells(c.crates), "moves":0,"pushes":0}
		var result = rules.step(levels[c.level_id],state,c.action)
		if c.expected == null:
			if not result.is_empty(): failures += 1
		else:
			if result.is_empty():
				failures += 1
				continue
			if result.player != rules.cell(c.expected[0]): failures += 1
			if result.crates.size() != c.expected[1].size(): failures += 1
			for p in result.crates:
				if p not in rules.cells(c.expected[1]): failures += 1
	print("INDEPENDENT_RANDOM_PARITY cases=",cases.size()," failures=",failures)
	quit(0 if failures == 0 else 1)
