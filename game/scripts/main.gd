extends Node3D
## Stonebalance main scene: builds the riverbank, runs a stacking level, handles touch input and UI.
## Everything is created in code so the project stays small, diff-friendly and CI-testable.

enum State { MENU, HOLDING, SETTLING, RESULT }
enum Mode { RELAX, CLASSIC, DAILY }

const GROUND_TOP := 0.0
const FALL_LIMIT := -1.2
const SETTLE_TIME := 1.2

var state := State.MENU
var mode := Mode.CLASSIC
var level_id := 1
var pieces_left := 0
var lost_count := 0
var stack: Array[Piece] = []
var held_piece: Piece = null
var rng := RandomNumberGenerator.new()
var settle_timer := 0.0
var wind := 0.0
var target_height := 1.0
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var pieces_root: Node3D
var target_marker: MeshInstance3D
var cam_focus_y := 0.7

# UI
var ui: CanvasLayer
var hud_label: Label
var msg_label: Label
var menu_panel: PanelContainer
var result_panel: PanelContainer
var result_label: Label
var next_button: Button

func _ready() -> void:
	_build_world()
	_build_ui()
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	_show_menu()

# ---------------------------------------------------------------- world

func _build_world() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.45, 0.62, 0.78)
	psm.sky_horizon_color = Color(0.86, 0.80, 0.70)
	psm.ground_horizon_color = Color(0.55, 0.52, 0.46)
	psm.ground_bottom_color = Color(0.2, 0.22, 0.22)
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.78, 0.72)
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 42
	camera.position = Vector3(0, 1.3, 3.4)
	add_child(camera)
	camera.look_at(Vector3(0, cam_focus_y, 0), Vector3.UP)

	# Flat-topped stone platform (static)
	var ground := StaticBody3D.new()
	var gmesh := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(1.8, 0.4, 1.8)
	gmesh.mesh = gbox
	gmesh.material_override = Materials.make("ground", 11)
	ground.add_child(gmesh)
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = gbox.size
	gcol.shape = gshape
	ground.add_child(gcol)
	ground.position = Vector3(0, GROUND_TOP - 0.2, 0)
	var gpm := PhysicsMaterial.new()
	gpm.friction = 1.0
	ground.physics_material_override = gpm
	add_child(ground)

	# Riverbed / water (visual only)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	water.mesh = pm
	water.material_override = Materials.make("water")
	water.position = Vector3(0, -0.9, 0)
	add_child(water)

	pieces_root = Node3D.new()
	add_child(pieces_root)

	# Goal marker: a thin ring-like bar plus text in the HUD (not color-only)
	target_marker = MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.4, 0.01, 0.01)
	target_marker.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(1, 1, 1, 0.9)
	tmat.emission_enabled = true
	tmat.emission = Color(1, 1, 1)
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_marker.material_override = tmat
	target_marker.visible = false
	add_child(target_marker)

func _apply_quality() -> void:
	var q := Settings.quality
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 8.0 if q == 1 else 14.0
	# SSAO needs Forward+; on the Mobile renderer High quality uses 4x MSAA and longer shadows instead.
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if q == 0 else (Viewport.MSAA_2X if q == 1 else Viewport.MSAA_4X)
	Engine.max_fps = 60

# ---------------------------------------------------------------- UI

func _button(text: String, on_press: Callable, min_h := 120) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)  # large touch targets
	b.add_theme_font_size_override("font_size", 44)
	if not on_press.is_null():
		b.pressed.connect(on_press)
	return b

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	hud_label = Label.new()
	hud_label.position = Vector2(40, 40)
	hud_label.add_theme_font_size_override("font_size", 48)
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hud_label.add_theme_constant_override("outline_size", 8)
	ui.add_child(hud_label)

	msg_label = Label.new()
	msg_label.position = Vector2(40, 190)
	msg_label.add_theme_font_size_override("font_size", 40)
	msg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	msg_label.add_theme_constant_override("outline_size", 8)
	ui.add_child(msg_label)

	var bottom := HBoxContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -190
	bottom.offset_bottom = -40
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.add_theme_constant_override("separation", 24)
	ui.add_child(bottom)
	var rot := _button("Rotate", rotate_held, 150)
	rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(rot)
	var pause := _button("Menu", _show_menu, 150)
	pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(pause)

	menu_panel = PanelContainer.new()
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -400
	menu_panel.offset_right = 400
	menu_panel.offset_top = -700
	menu_panel.offset_bottom = 700
	ui.add_child(menu_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	menu_panel.add_child(vb)
	var title := Label.new()
	title.text = "Stonebalance"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	vb.add_child(title)
	vb.add_child(_button("Relax (no goals)", func(): start(Mode.RELAX, 1)))
	vb.add_child(_button("Classic (continue)", func(): start(Mode.CLASSIC, int(Save.data.get("unlocked_level", 1)))))
	vb.add_child(_button("Daily puzzle", func(): start(Mode.DAILY, 3)))
	var qb := _button("", Callable())
	qb.pressed.connect(func():
		Settings.quality = (Settings.quality + 1) % Settings.QUALITY_NAMES.size()
		Settings.save_settings()
		Settings.changed.emit()
		qb.text = "Graphics: " + Settings.QUALITY_NAMES[Settings.quality])
	qb.text = "Graphics: " + Settings.QUALITY_NAMES[Settings.quality]
	vb.add_child(qb)
	var vib := _button("", Callable())
	vib.pressed.connect(func():
		Settings.vibration = not Settings.vibration
		Settings.save_settings()
		vib.text = "Vibration: " + ("On" if Settings.vibration else "Off"))
	vib.text = "Vibration: " + ("On" if Settings.vibration else "Off")
	vb.add_child(vib)
	var mute := _button("", Callable())
	mute.pressed.connect(func():
		Settings.muted = not Settings.muted
		Settings.save_settings()
		Settings.changed.emit()
		mute.text = "Sound: " + ("Off" if Settings.muted else "On"))
	mute.text = "Sound: " + ("Off" if Settings.muted else "On")
	vb.add_child(mute)

	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -400
	result_panel.offset_right = 400
	result_panel.offset_top = -330
	result_panel.offset_bottom = 330
	ui.add_child(result_panel)
	var rvb := VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 20)
	result_panel.add_child(rvb)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.add_theme_font_size_override("font_size", 52)
	rvb.add_child(result_label)
	next_button = _button("Next level", func(): start(mode, level_id + 1))
	rvb.add_child(next_button)
	rvb.add_child(_button("Try again", func(): start(mode, level_id)))
	rvb.add_child(_button("Menu", _show_menu))
	result_panel.visible = false

func _show_menu() -> void:
	state = State.MENU
	menu_panel.visible = true
	result_panel.visible = false
	get_tree().paused = false

# ---------------------------------------------------------------- game flow

func start(new_mode: int, id: int) -> void:
	mode = new_mode
	level_id = clampi(id, 1, Progression.LEVELS.size())
	for c in pieces_root.get_children():
		c.queue_free()
	stack.clear()
	held_piece = null
	lost_count = 0
	var lvl := Progression.level(level_id)
	wind = float(lvl["wind"])
	target_height = float(lvl["target"])
	if mode == Mode.RELAX:
		pieces_left = -1  # unlimited
		wind = 0.0
		rng.seed = Time.get_ticks_usec()
	elif mode == Mode.DAILY:
		pieces_left = int(lvl["pieces"])
		rng.seed = Progression.daily_seed(Time.get_date_dict_from_system())
	else:
		pieces_left = int(lvl["pieces"])
		rng.seed = 1000 + level_id  # same pieces every attempt => fair
	target_marker.visible = mode != Mode.RELAX
	target_marker.position = Vector3(0, GROUND_TOP + target_height, 0)
	menu_panel.visible = false
	result_panel.visible = false
	msg_label.text = "Drag to position, release to drop"
	_spawn_next()

func _spawn_next() -> void:
	if pieces_left == 0:
		state = State.SETTLING
		settle_timer = 0.0
		return
	var kinds := ["stone", "stone", "wood", "ceramic"]
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var shape := "disc" if rng.randf() < 0.35 else "box"
	var size := Vector3(rng.randf_range(0.28, 0.55), rng.randf_range(0.10, 0.20), rng.randf_range(0.28, 0.5))
	if shape == "disc":
		size.z = size.x
	var p := Piece.create(kind, shape, size, rng.randi())
	pieces_root.add_child(p)
	p.global_position = Vector3(0, stack_height() + 0.7, 0)
	p.rotation.y = rng.randf_range(0.0, PI)
	held_piece = p
	state = State.HOLDING
	if pieces_left > 0:
		pieces_left -= 1
	_update_hud()

func stack_height() -> float:
	var h := 0.0
	for p in stack:
		if is_instance_valid(p):
			h = maxf(h, p.top_y() - GROUND_TOP)
	return h

func rotate_held() -> void:
	if state == State.HOLDING and held_piece:
		held_piece.rotation.y += PI / 4.0

func release_held() -> void:
	if state != State.HOLDING or held_piece == null:
		return
	held_piece.release()
	stack.append(held_piece)
	held_piece = null
	if Settings.vibration and not Settings.muted:
		Input.vibrate_handheld(15)
	state = State.SETTLING
	settle_timer = 0.0

## Test/automation hook: place held piece at an XZ position and drop it.
func drop_at(x: float, z: float) -> void:
	if held_piece:
		held_piece.global_position.x = clampf(x, -0.7, 0.7)
		held_piece.global_position.z = clampf(z, -0.7, 0.7)
		release_held()

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if state != State.HOLDING or held_piece == null:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_move_held(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_move_held(event.position)
		else:
			release_held()

func _move_held(screen_pos: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, held_piece.global_position.y)
	var hit = plane.intersects_ray(origin, dir)
	if hit != null:
		held_piece.global_position.x = clampf(hit.x, -0.7, 0.7)
		held_piece.global_position.z = clampf(hit.z, -0.7, 0.7)

# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	if wind > 0.0:
		for p in stack:
			if is_instance_valid(p) and not p.held:
				p.apply_central_force(Vector3(wind * 0.6 * p.mass * 0.02, 0, 0))
	if state == State.SETTLING:
		_check_fallen()
		var all_settled := true
		for p in stack:
			if is_instance_valid(p) and not p.is_settled():
				all_settled = false
		if all_settled:
			settle_timer += delta
		else:
			settle_timer = 0.0
		if settle_timer >= SETTLE_TIME:
			_on_settled()
	if state != State.MENU:
		var want := clampf(stack_height() * 0.5 + 0.7, 0.7, 3.0)
		cam_focus_y = want if Settings.reduced_motion else lerpf(cam_focus_y, want, 1.0 - exp(-2.0 * delta))
		camera.position.y = cam_focus_y + 0.6
		camera.look_at(Vector3(0, cam_focus_y, 0), Vector3.UP)
	if held_piece:
		held_piece.global_position.y = stack_height() + 0.7
	_update_hud()

func _check_fallen() -> void:
	for p in stack.duplicate():
		if is_instance_valid(p) and p.global_position.y < FALL_LIMIT:
			stack.erase(p)
			p.queue_free()
			lost_count += 1

func _on_settled() -> void:
	if pieces_left == 0:
		_finish_level()
	else:
		_spawn_next()

func _finish_level() -> void:
	state = State.RESULT
	var h := stack_height()
	var passed := false
	if mode == Mode.CLASSIC:
		passed = Progression.submit_result(level_id, h)
	elif mode == Mode.DAILY:
		passed = h >= target_height
	var txt := "Height %.2f m (goal %.2f m)\n" % [h, target_height]
	txt += "Balanced!" if passed else "Not quite. Try again whenever you like."
	result_label.text = txt
	next_button.visible = passed and mode == Mode.CLASSIC and level_id < Progression.LEVELS.size()
	result_panel.visible = true

func _update_hud() -> void:
	if hud_label == null:
		return
	var left := "∞" if pieces_left < 0 else str(pieces_left + (1 if held_piece else 0))
	var goal := "" if mode == Mode.RELAX else "  Goal %.1f m" % target_height
	hud_label.text = "Height %.2f m%s\nPieces left: %s" % [stack_height(), goal, left]

func _notification(what: int) -> void:
	# App lifecycle: persist on backgrounding so nothing is lost.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Settings.save_settings()
		Save.save_game()
