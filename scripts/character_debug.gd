extends Node3D

const FIGHTERS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const NAMES := ["BENNET", "AVIGDOR LIEBERMAN", "BIBI", "YAIR GOLAN", "ARYEH DERI", "YAIR LAPID", "MANSOUR ABBAS", "BENNY GANTZ", "ITAMAR BEN-GVIR", "BEZALEL SMOTRICH", "GADI EISENKOT", "DONALD TRUMP", "JOINT LIST"]
const STATES := ["idle", "walk_forward", "walk_back", "crouch", "jab", "cross", "hook", "kick", "block", "hit", "knockdown", "getup", "jump_start", "jump_air", "jump_land"]

var stage: Node3D
var visual: Dictionary
var fighter_index := 0
var state_index := 0
var info: Label
var finisher_lab: Node3D

func _ready() -> void:
	_build_world()
	_build_ui()
	_load_fighter()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(finisher_lab) and finisher_lab.visible: return
	if event.is_action_pressed("ui_left"):
		fighter_index = wrapi(fighter_index - 1, 0, FIGHTERS.size()); _load_fighter()
	elif event.is_action_pressed("ui_right"):
		fighter_index = wrapi(fighter_index + 1, 0, FIGHTERS.size()); _load_fighter()
	elif event.is_action_pressed("ui_up"):
		state_index = wrapi(state_index - 1, 0, STATES.size()); _play_state()
	elif event.is_action_pressed("ui_down"):
		state_index = wrapi(state_index + 1, 0, STATES.size()); _play_state()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q: fighter_index = wrapi(fighter_index - 1, 0, FIGHTERS.size()); _load_fighter()
			KEY_E: fighter_index = wrapi(fighter_index + 1, 0, FIGHTERS.size()); _load_fighter()
			KEY_1: _set_state_by_name("idle")
			KEY_A: _set_state_by_name("walk_back")
			KEY_D: _set_state_by_name("walk_forward")
			KEY_C: _set_state_by_name("crouch")
			KEY_J: _set_state_by_name("jab")
			KEY_K: _set_state_by_name("cross")
			KEY_L: _set_state_by_name("kick")
			KEY_S: _set_state_by_name("block")
			KEY_H: _set_state_by_name("hit")
			KEY_X: _set_state_by_name("knockdown")
			KEY_R: _set_state_by_name("getup")
			KEY_W: _set_state_by_name("jump_air")
			KEY_F: visual.sprite.flip_h = not visual.sprite.flip_h; _play_state()
			KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main.tscn")

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202731")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dce8f2")
	env.ambient_light_energy = 0.72
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -32, 0); key.light_energy = 1.35; key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0); fill.light_energy = 0.65; fill.light_color = Color("8fc9ff")
	add_child(fill)
	var camera := Camera3D.new()
	camera.name = "SpriteLabCamera"
	camera.position = Vector3(0, 1.08, 3.15); camera.fov = 34.0
	add_child(camera); camera.look_at(Vector3(0, 0.92, 0))
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new(); floor_mesh.size = Vector2(5.5, 5.5); floor_mesh.subdivide_width = 10; floor_mesh.subdivide_depth = 10
	floor.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color("10161d"); floor_mat.metallic = 0.25; floor_mat.roughness = 0.58
	floor.material_override = floor_mat
	add_child(floor)
	stage = Node3D.new(); stage.name = "CharacterStage"; add_child(stage)

func _build_ui() -> void:
	var canvas := CanvasLayer.new(); canvas.name = "DebugUI"; add_child(canvas)
	var title := Label.new(); title.text = "FIGHTER SPRITE LAB"; title.position = Vector2(28, 20); title.add_theme_font_size_override("font_size", 26); canvas.add_child(title)
	info = Label.new(); info.position = Vector2(28, 60); info.size = Vector2(420, 120); info.add_theme_font_size_override("font_size", 15); canvas.add_child(info)
	var controls := HBoxContainer.new(); controls.name = "PoseControls"; controls.position = Vector2(28, 620); controls.size = Vector2(1220, 44); controls.add_theme_constant_override("separation", 5); canvas.add_child(controls)
	var pose_buttons := [
		["IDLE", "idle"], ["WALK", "walk_forward"], ["CROUCH", "crouch"],
		["JAB", "jab"], ["CROSS", "cross"], ["KICK", "kick"],
		["GUARD", "block"], ["HIT", "hit"], ["FALL", "knockdown"], ["GET UP", "getup"], ["JUMP", "jump_air"]
	]
	for spec in pose_buttons:
		var button := Button.new(); button.text = spec[0]; button.custom_minimum_size = Vector2(91, 40)
		button.pressed.connect(func(state: String = spec[1]): _set_state_by_name(state)); controls.add_child(button)
	var help := Label.new(); help.text = "Q/E fighter   J jab   K cross   L kick   S guard   H hit   X fall   R get up   W jump   F flip"; help.position = Vector2(28, 674); help.size = Vector2(1200, 25); help.add_theme_color_override("font_color", Color("b8c7d2")); canvas.add_child(help)
	var back := Button.new(); back.text = "BACK TO MENU"; back.position = Vector2(1090, 24); back.size = Vector2(160, 42); back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn")); canvas.add_child(back)
	var finishers := Button.new(); finishers.name = "FinishersMode"; finishers.text = "FINISHER LAB"; finishers.position = Vector2(900, 24); finishers.size = Vector2(170, 42)
	finishers.pressed.connect(func(): preview_finisher(FIGHTERS[fighter_index], "eligible")); canvas.add_child(finishers)

func preview_finisher(fighter_id: String, outcome: String) -> void:
	if not is_instance_valid(finisher_lab):
		finisher_lab = load("res://scripts/finishers/finisher_lab.gd").new()
		finisher_lab.name = "FinisherLab"
		add_child(finisher_lab)
	stage.visible = false
	get_node("DebugUI").visible = false
	finisher_lab.visible = true
	finisher_lab.get_node("LabUI").visible = true
	finisher_lab.preview(fighter_id, outcome)

func seek_finisher(seconds: float) -> void:
	if is_instance_valid(finisher_lab): finisher_lab.seek(seconds)

func set_finisher_speed(multiplier: float) -> void:
	if is_instance_valid(finisher_lab): finisher_lab.set_speed(multiplier)

func _load_fighter() -> void:
	if visual.has("root") and is_instance_valid(visual.root): visual.root.queue_free()
	visual = FighterVisual.build(FIGHTERS[fighter_index])
	stage.add_child(visual.root)
	_play_state()

func _play_state() -> void:
	if visual.is_empty(): return
	visual.motion.play_state(STATES[state_index], true)
	info.text = "%s\nSPRITE: %s\nANIMATION: %s\nDIRECTION: %s" % [NAMES[fighter_index], FIGHTERS[fighter_index], STATES[state_index], "LEFT" if visual.sprite.flip_h else "RIGHT"]


func _set_state_by_name(state: String) -> void:
	var next_index := STATES.find(state)
	if next_index < 0: return
	state_index = next_index
	_play_state()
