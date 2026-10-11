extends Control

## CREATE YOUR FIGHTER: body (base model or an imported rigged avatar .glb),
## name, colour, fighting style (archetype) and a fixed 300-point split of
## POWER / SPEED / DEFENSE, with a live 3D preview. Saves to user://fighters.
## Imported avatars are validated by content/character_loader.gd (humanoid bones,
## Mixamo / Avaturn / MetaPerson naming are retargeted automatically).

const Builder = preload("res://meta/fighter_builder.gd")
const Loader = preload("res://content/character_loader.gd")
const CharacterView = preload("res://present/character_view.gd")
const PALETTE := [Color(1, 1, 1), Color(0.85, 0.92, 1.1), Color(1.1, 0.88, 0.85), Color(0.8, 1.05, 0.8), Color(1.1, 1.0, 0.7), Color(0.95, 0.8, 1.1), Color(0.7, 0.7, 0.75), Color(0.75, 0.62, 0.55)]
const STYLE_TEXT := {
	"all-rounder": "Fireball, uppercut and rush kick. Solid at every range.",
	"rushdown": "Fast pokes, Lightning Dash, overhead leap. Never lets up.",
	"grappler": "Huge damage and an unbreakable command grab.",
	"zoner": "Rapid waves, a slow orb and the Hyper Beam. Keeps rivals out.",
}

var _name: LineEdit
var _model_index := 0
var _models: Array = []       # [label, path]
var _color := 1
var _style := 0
var _points := {"power": 100, "speed": 100, "defense": 100}
var _labels := {}
var _status: Label
var _preview: Node3D
var _viewport: SubViewport
var _file_dialog: FileDialog
var _web_callback = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_models = Builder.BASE_MODELS.duplicate()
	var bg := ColorRect.new()
	bg.color = Color("#0a1019")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	var title := Label.new()
	title.text = "CREATE YOUR FIGHTER"
	title.add_theme_font_size_override("font_size", 34)
	title.anchor_right = 1.0
	title.offset_top = 18
	title.offset_bottom = 64
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	# Live preview on the left.
	var container := SubViewportContainer.new()
	container.stretch = true
	container.anchor_left = 0.04
	container.anchor_right = 0.42
	container.anchor_top = 0.12
	container.anchor_bottom = 0.92
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	container.add_child(_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.3)
	cam.fov = 40
	_viewport.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 35, 0)
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	_viewport.add_child(env)
	# Form on the right.
	var form := VBoxContainer.new()
	form.anchor_left = 0.47
	form.anchor_right = 0.96
	form.anchor_top = 0.12
	form.anchor_bottom = 0.95
	form.add_theme_constant_override("separation", 10)
	add_child(form)
	form.add_child(_caption("NAME"))
	_name = LineEdit.new()
	_name.text = "MY FIGHTER"
	_name.max_length = 16
	_name.add_theme_font_size_override("font_size", 24)
	form.add_child(_name)
	form.add_child(_row("BODY", "body", func(): _cycle_model(-1), func(): _cycle_model(1)))
	var import_button := Button.new()
	import_button.text = "IMPORT MY 3D AVATAR (.GLB)"
	import_button.custom_minimum_size = Vector2(0, 44)
	import_button.pressed.connect(_import_avatar)
	form.add_child(import_button)
	form.add_child(_row("COLOR", "color", func(): _cycle_color(-1), func(): _cycle_color(1)))
	form.add_child(_row("STYLE", "style", func(): _cycle_style(-1), func(): _cycle_style(1)))
	_labels["style_text"] = _caption("")
	form.add_child(_labels.style_text)
	form.add_child(_caption("STATS  ·  %d POINTS TO SPLIT (50 - 150 EACH)" % Builder.BUDGET))
	for stat in ["power", "speed", "defense"]:
		var s: String = stat
		form.add_child(_row(stat.to_upper(), stat, func(): _adjust(s, -10), func(): _adjust(s, 10)))
	_labels["pool"] = _caption("")
	form.add_child(_labels.pool)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	form.add_child(actions)
	var save := Button.new()
	save.text = "SAVE FIGHTER"
	save.custom_minimum_size = Vector2(220, 52)
	save.pressed.connect(_save)
	actions.add_child(save)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(140, 52)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle/select.tscn"))
	actions.add_child(back)
	_status = _caption("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	form.add_child(_status)
	_refresh(true)


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#9fb0b6"))
	return label


func _row(title: String, key: String, minus: Callable, plus: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)
	var down := Button.new()
	down.text = "-" if key in ["power", "speed", "defense"] else "<"
	down.custom_minimum_size = Vector2(48, 40)
	down.pressed.connect(minus)
	row.add_child(down)
	var value := Label.new()
	value.custom_minimum_size = Vector2(240, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 20)
	row.add_child(value)
	_labels[key] = value
	var up := Button.new()
	up.text = "+" if key in ["power", "speed", "defense"] else ">"
	up.custom_minimum_size = Vector2(48, 40)
	up.pressed.connect(plus)
	row.add_child(up)
	return row


func _cycle_model(step: int) -> void:
	_model_index = wrapi(_model_index + step, 0, _models.size())
	_refresh(true)


func _cycle_color(step: int) -> void:
	_color = wrapi(_color + step, 0, PALETTE.size())
	_refresh(true)


func _cycle_style(step: int) -> void:
	_style = wrapi(_style + step, 0, Builder.ARCHETYPES.size())
	_refresh(false)


func pool() -> int:
	return Builder.BUDGET - int(_points.power) - int(_points.speed) - int(_points.defense)


func _adjust(stat: String, delta: int) -> void:
	var next := int(_points[stat]) + delta
	if next < Builder.MIN_STAT or next > Builder.MAX_STAT:
		return
	if delta > 0 and pool() < delta:
		return
	_points[stat] = next
	_refresh(false)


func _refresh(rebuild_preview: bool) -> void:
	(_labels.body as Label).text = str(_models[_model_index][0])
	(_labels.color as Label).text = "COLOR %d" % (_color + 1)
	var style: Array = Builder.ARCHETYPES[_style]
	(_labels.style as Label).text = str(style[0]).to_upper()
	(_labels.style_text as Label).text = STYLE_TEXT.get(style[0], "")
	var stats: Dictionary = Builder.stats_for(int(_points.power), int(_points.speed), int(_points.defense))
	(_labels.power as Label).text = "%d   (damage %d%%)" % [_points.power, stats.power]
	(_labels.speed as Label).text = "%d   (walk %.2f m/s)" % [_points.speed, stats.walk * 60 / 10000.0]
	(_labels.defense as Label).text = "%d   (HP %d)" % [_points.defense, stats.hp]
	(_labels.pool as Label).text = "POINTS LEFT: %d" % pool() if pool() != 0 else "BUILD COMPLETE"
	if rebuild_preview:
		if _preview != null:
			_preview.queue_free()
		var view := CharacterView.new()
		_viewport.add_child(view)
		view.setup(str(_models[_model_index][1]), PALETTE[_color])
		view.rig_root.rotation_degrees.y = 25.0
		_preview = view
		if view.load_error != "":
			_status.text = "This model could not be used: %s" % view.load_error


func _save() -> void:
	if pool() != 0:
		_status.text = "Spend all %d points first (points left: %d)." % [Builder.BUDGET, pool()]
		return
	var def: Dictionary = Builder.build_def(_name.text, _style, str(_models[_model_index][1]), PALETTE[_color], int(_points.power), int(_points.speed), int(_points.defense))
	if def.is_empty() or Builder.save_def(def) != OK:
		_status.text = "Could not save the fighter."
		return
	_status.text = "Saved %s! Find it on the fighter select screen." % def.name
	get_tree().change_scene_to_file("res://scenes/battle/select.tscn")


# --- avatar import -------------------------------------------------------------

func _import_avatar() -> void:
	if OS.has_feature("web"):
		_import_web()
		return
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(["*.glb ; Rigged 3D avatar"])
		_file_dialog.file_selected.connect(func(path: String): import_bytes(FileAccess.get_file_as_bytes(path), path.get_file().get_basename()))
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)


func _import_web() -> void:
	# Browser file picker -> base64 -> Godot callback.
	_web_callback = JavaScriptBridge.create_callback(func(args):
		import_bytes(Marshalls.base64_to_raw(str(args[0])), str(args[1])))
	var window = JavaScriptBridge.get_interface("window")
	window.wfcAvatarPicked = _web_callback
	JavaScriptBridge.eval("""
		(function () {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.glb';
			input.onchange = () => {
				const file = input.files[0];
				if (!file) return;
				const reader = new FileReader();
				reader.onload = () => {
					const bytes = new Uint8Array(reader.result);
					let binary = '';
					for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
					window.wfcAvatarPicked(btoa(binary), file.name.replace(/\\.glb$/i, ''));
				};
				reader.readAsArrayBuffer(file);
			};
			input.click();
		})();
	""", true)


## Stores an imported avatar, validates it and selects it as the body.
func import_bytes(bytes: PackedByteArray, label: String) -> String:
	if bytes.size() < 64:
		_status.text = "That file is empty."
		return ""
	var path := Builder.store_avatar(bytes, Builder.slug(label))
	var built := Loader.build(path)
	if str(built.get("error", "")) != "":
		_status.text = "This avatar cannot fight yet: %s" % built.error
		return ""
	(built.root as Node).free()
	_models.append(["MY AVATAR: %s" % label.to_upper().left(18), path])
	_model_index = _models.size() - 1
	_status.text = "Avatar imported%s." % (" and retargeted to the fighting skeleton" if built.retargeted else "")
	_refresh(true)
	return path
