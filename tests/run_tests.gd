extends SceneTree
## Headless test runner: godot --headless --path . --script tests/run_tests.gd
## Exits non-zero if any assertion fails.

var failures := 0
var checks := 0

func check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name)

func _initialize() -> void:
	await process_frame
	var settings = root.get_node("Settings")
	var save = root.get_node("Save")
	var prog = root.get_node("Progression")

	# --- Settings round trip
	settings.music_volume = 0.3
	settings.quality = 2
	settings.reduced_motion = true
	check(settings.save_settings("user://test_settings.cfg"), "settings save")
	settings.music_volume = 0.9
	settings.quality = 0
	settings.load_settings("user://test_settings.cfg")
	check(is_equal_approx(settings.music_volume, 0.3) and settings.quality == 2 and settings.reduced_motion, "settings load restores values")

	# --- Save system incl. corruption recovery
	save.data = save.default_data()
	save.data["unlocked_level"] = 3
	check(save.save_game("user://t_save.json", "user://t_save.json.bak"), "save write")
	save.data["unlocked_level"] = 4
	save.save_game("user://t_save.json", "user://t_save.json.bak")  # creates backup holding level 3
	var f := FileAccess.open("user://t_save.json", FileAccess.WRITE)
	f.store_string("{corrupt")
	f.close()
	save.load_game("user://t_save.json", "user://t_save.json.bak")
	check(int(save.data["unlocked_level"]) == 3, "corrupt save recovers from backup")
	save.data = save.default_data()
	save.load_game("user://does_not_exist.json", "user://nope.bak")
	check(int(save.data["unlocked_level"]) == 1, "missing save falls back to defaults")

	# --- Progression
	save.data = save.default_data()
	check(prog.is_unlocked(1) and not prog.is_unlocked(2), "only level 1 unlocked initially")
	check(not prog.submit_result(1, 0.1) and not prog.is_unlocked(2), "failing target does not unlock")
	check(prog.submit_result(1, 0.9) and prog.is_unlocked(2), "passing target unlocks next level")
	check(float(save.data["best_heights"]["1"]) == 0.9, "personal best stored")
	check(prog.daily_seed({"year": 2026, "month": 11, "day": 22}) == 20261122, "daily seed deterministic")

	# --- Gameplay: drop pieces and confirm physics behaviour
	var main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start(1, 1)  # classic level 1
	check(main.state == main.State.HOLDING and main.held_piece != null, "level start spawns held piece")
	check(main.pieces_left == 5, "level 1 has 6 pieces (1 held, 5 left)")
	main.drop_at(0.0, 0.0)
	var frames := 0
	while main.state == main.State.SETTLING and frames < 600:
		await physics_frame
		frames += 1
	check(main.state == main.State.HOLDING, "piece settles and next piece is spawned (frames=%d)" % frames)
	var h1: float = main.stack_height()
	check(h1 > 0.08 and h1 < 0.25, "first piece rests on platform (h=%.3f)" % h1)
	main.drop_at(0.0, 0.0)
	frames = 0
	while main.state == main.State.SETTLING and frames < 600:
		await physics_frame
		frames += 1
	check(main.stack_height() > h1, "second piece stacks higher (h=%.3f)" % main.stack_height())
	# Piece dropped far off-platform falls into the river and is lost
	main.drop_at(0.7, 0.7)
	main.stack[main.stack.size() - 1].global_position = Vector3(3, 0.5, 3)
	frames = 0
	while main.state == main.State.SETTLING and frames < 900:
		await physics_frame
		frames += 1
	check(main.lost_count >= 1, "piece off the platform is counted as lost")

	print("---- %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
