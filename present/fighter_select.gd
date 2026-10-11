extends Control

## New-engine fighter select: pick your fighter (data/fighters/*.json, plus any
## local private fighter), a rival and a stage, with a live 3D preview.

const Loader = preload("res://content/character_loader.gd")
const CharacterView = preload("res://present/character_view.gd")
const Battle = preload("res://present/battle_view.gd")
const PrivateRoster = preload("res://scripts/private_roster.gd")
const Profile = preload("res://meta/profile.gd")
const Challenges = preload("res://meta/challenges.gd")
const STAGES := [
	{"name": "UNDERPASS", "art": "res://assets/stages/kaplan-junction-arena.jpg"},
	{"name": "NEWSROOM", "art": "res://assets/stages/hatzinor-studio-arena.png"},
	{"name": "PRIME TIME", "art": "res://assets/stages/friday-studio-arena.png"},
	{"name": "RED ALERT", "art": "res://assets/stages/patriots-studio-arena.png"},
]

var fighters: Array = []
var _player := 0
var _rival := 1
var _stage := 0
var _labels := {}
var _preview_views: Array = []
var _viewports: Array[SubViewport] = []
var _profile
var _level_button: Button
var _controls_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	fighters = Loader.fighter_definitions()
	for id in PrivateRoster.ids():
		var info: Dictionary = PrivateRoster.info(id)
		fighters.append({"id": id, "name": str(info.get("name", id)).to_upper(), "archetype": "personal", "private": true, "stats": {"hp": 10000, "walk": 541}})
	if fighters.size() < 2:
		push_error("need at least two fighters")
	_rival = 1 % fighters.size()
	var bg := ColorRect.new()
	bg.color = Color("#0a1019")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := _label("CHOOSE YOUR FIGHTER", 34, Vector2(0, 26), Vector2(1, 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for side in range(2):
		var vp_container := SubViewportContainer.new()
		vp_container.stretch = true
		vp_container.anchor_left = 0.08 if side == 0 else 0.56
		vp_container.anchor_right = 0.44 if side == 0 else 0.92
		vp_container.anchor_top = 0.14
		vp_container.anchor_bottom = 0.7
		add_child(vp_container)
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp_container.add_child(vp)
		_viewports.append(vp)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.1, 3.4)
		cam.fov = 40
		vp.add_child(cam)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, 30 if side == 0 else -30, 0)
		vp.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.6, 0.62, 0.7)
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		vp.add_child(env)
		_preview_views.append(null)
		var name_label := _label("", 30, Vector2(0, 0), Vector2(0, 0))
		name_label.anchor_left = vp_container.anchor_left
		name_label.anchor_right = vp_container.anchor_right
		name_label.anchor_top = 0.71
		name_label.anchor_bottom = 0.71
		name_label.offset_bottom = 40
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_labels["name%d" % side] = name_label
		var caption := _label("YOU" if side == 0 else "RIVAL", 16, Vector2.ZERO, Vector2.ZERO)
		caption.anchor_left = vp_container.anchor_left
		caption.anchor_right = vp_container.anchor_right
		caption.anchor_top = 0.11
		caption.anchor_bottom = 0.11
		caption.offset_bottom = 24
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_color", Color("#3fd0e0") if side == 0 else Color("#ff5a6a"))
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 0.8
	row.anchor_bottom = 0.8
	row.offset_left = -600
	row.offset_right = 600
	row.offset_bottom = 56
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	row.add_child(_button("< YOU", func(): _cycle(0, -1)))
	row.add_child(_button("YOU >", func(): _cycle(0, 1)))
	row.add_child(_button("< RIVAL", func(): _cycle(1, -1)))
	row.add_child(_button("RIVAL >", func(): _cycle(1, 1)))
	row.add_child(_button("STAGE", func(): _stage = (_stage + 1) % STAGES.size(); _refresh()))
	row.add_child(_button("FIGHT!", _start))
	row.add_child(_button("ARCADE", _start_arcade))
	row.add_child(_button("2 VS 2", _start_team))
	row.add_child(_button("CREATE", func(): get_tree().change_scene_to_file("res://scenes/battle/creator.tscn")))
	_level_button = _button("", _cycle_level)
	row.add_child(_level_button)
	_controls_button = _button("", _toggle_controls)
	row.add_child(_controls_button)
	row.add_child(_button("BACK", func(): get_tree().change_scene_to_file("res://scenes/main.tscn")))
	_labels["stage"] = _label("", 18, Vector2.ZERO, Vector2.ZERO)
	_labels.stage.anchor_left = 0.0
	_labels.stage.anchor_right = 1.0
	_labels.stage.anchor_top = 0.9
	_labels.stage.anchor_bottom = 0.9
	_labels.stage.offset_bottom = 30
	_labels.stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var profile = Profile.load_profile(Battle.profile_path)
	_profile = profile
	_update_setting_buttons()
	var stats := _label("LEVEL %d  ·  %s  ·  %dW %dL  ·  BEST COMBO %d" % [profile.level(), profile.data.title, int(profile.data.wins), int(profile.data.losses), int(profile.data.best_combo)], 16, Vector2.ZERO, Vector2.ZERO)
	stats.anchor_top = 0.94
	stats.anchor_bottom = 0.94
	stats.offset_bottom = 28
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color("#9fe8ff"))
	var daily := _label(Challenges.describe(profile), 16, Vector2.ZERO, Vector2.ZERO)
	daily.anchor_top = 0.075
	daily.anchor_bottom = 0.075
	daily.offset_bottom = 26
	daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daily.add_theme_color_override("font_color", Color("#ffd75a"))
	profile.save()
	_refresh()


func _cycle_level() -> void:
	_profile.set_setting("cpu_level", wrapi(int(_profile.setting("cpu_level", 2)) + 1, 1, 5))
	_profile.save()
	_update_setting_buttons()


func _toggle_controls() -> void:
	_profile.set_setting("easy_controls", not bool(_profile.setting("easy_controls", false)))
	_profile.save()
	_update_setting_buttons()


func _update_setting_buttons() -> void:
	_level_button.text = "CPU LV %d" % int(_profile.setting("cpu_level", 2))
	_controls_button.text = "EASY" if bool(_profile.setting("easy_controls", false)) else "PRO"


## 2v2: your fighter + a CPU partner against your chosen rival + one more.
func _start_team() -> void:
	var others: Array = []
	for k in range(fighters.size()):
		if k != _player and k != _rival and not bool(fighters[k].get("private", false)):
			others.append(fighters[k])
	if others.size() < 2:
		others.append_array([fighters[_rival], fighters[_player]])
	others.shuffle()
	Battle.pending_selection = {"p1": fighters[_player], "p2": fighters[_rival], "p1b": others[0], "p2b": others[1], "team": true, "stage": STAGES[_stage].art}
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _start_arcade() -> void:
	var ladder: Array = Profile.arcade_ladder(fighters, str(fighters[_player].id))
	if ladder.is_empty():
		return
	Battle.pending_selection = {"p1": fighters[_player], "p2": ladder[0].rival, "stage": STAGES[_stage].art, "arcade": {"ladder": ladder, "index": 0, "level": ladder[0].level}}
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _cycle(side: int, step: int) -> void:
	if side == 0: _player = wrapi(_player + step, 0, fighters.size())
	else: _rival = wrapi(_rival + step, 0, fighters.size())
	_refresh()


func _refresh() -> void:
	for side in range(2):
		var def: Dictionary = fighters[_player if side == 0 else _rival]
		(_labels["name%d" % side] as Label).text = "%s  ·  %s" % [def.name, str(def.get("archetype", "")).to_upper()]
		if _preview_views[side] != null:
			_preview_views[side].queue_free()
			_preview_views[side] = null
		if not bool(def.get("private", false)):
			var view := CharacterView.new()
			_viewports[side].add_child(view)
			var tint: Array = def.get("tint", [1, 1, 1])
			view.setup(str(def.model), Color(float(tint[0]), float(tint[1]), float(tint[2])))
			view.rig_root.rotation_degrees.y = 30.0 if side == 0 else -30.0
			_preview_views[side] = view
	(_labels.stage as Label).text = "STAGE: %s" % STAGES[_stage].name


func _start() -> void:
	Battle.pending_selection = {"p1": fighters[_player], "p2": fighters[_rival], "stage": STAGES[_stage].art}
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _label(text: String, size: int, _pos: Vector2, _anchor: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.anchor_right = 1.0
	label.offset_top = 20
	label.offset_bottom = 70
	add_child(label)
	return label


func _button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(104, 52)
	button.pressed.connect(action)
	return button
