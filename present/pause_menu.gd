extends Control

## Pause overlay for the new-engine battle: resume, move list (generated from
## the fighter's archetype moveset, with Pro commands and Easy inputs), quit.
## Pausing freezes the sim because the battle stops stepping while paused.

signal resumed
signal quit_requested

const L = preload("res://sim/layout.gd")
const EASY_LABEL := {"N": "SP", "F": "SP + forward", "B": "SP + back", "D": "SP + down", "SUPER": "SP + HK"}
const COMMAND_LABEL := {"236": "down, down-forward, forward", "623": "forward, down, down-forward", "214": "down, down-back, back", "236236": "down-forward x2"}

var _list: Label
var _panel: Control


func setup() -> void:
	# set_anchors_preset keeps the current rect, so zero the offsets explicitly.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0
	add_child(dim)
	_panel = VBoxContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.offset_left = -360
	_panel.offset_right = 360
	(_panel as VBoxContainer).add_theme_constant_override("separation", 10)
	add_child(_panel)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	for entry in [["RESUME", func(): resumed.emit()], ["QUIT TO MENU", func(): quit_requested.emit()]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(200, 50)
		button.pressed.connect(entry[1])
		row.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)
	_list = Label.new()
	_list.add_theme_font_size_override("font_size", 16)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	visible = false


func show_for(moveset, archetype: int, fighter_name: String) -> void:
	_list.text = move_list_text(moveset, archetype, fighter_name)
	visible = true


static func move_list_text(moveset, archetype: int, fighter_name: String) -> String:
	var lines: Array[String] = ["MOVE LIST  ·  %s  ·  %s" % [fighter_name, str(moveset.archetypes[archetype]).to_upper()], ""]
	lines.append("SPECIALS  (Pro command  |  Easy)")
	for move in moveset.specials_for(archetype):
		var m: Dictionary = moveset.moves[move]
		var button := "punch" if str(m.button_class) == "P" else "kick"
		var pro := "%s + %s" % [COMMAND_LABEL.get(str(m.command), str(m.command)), button]
		lines.append("  %-22s %-44s %s" % [str(m.display_name).to_upper(), pro, EASY_LABEL.get(str(m.easy), "-")])
	lines.append("")
	lines.append("SYSTEM")
	lines.append("  THROW                  light punch + light kick (tech: same, when grabbed)")
	lines.append("  DRIVE PARRY            hold DRIVE")
	lines.append("  DRIVE RUSH             DRIVE + forward (also cancels a connected normal)")
	lines.append("  DRIVE IMPACT           DRIVE + heavy punch (armored)")
	lines.append("  DASH / BACK-DASH       forward, forward  /  back, back")
	lines.append("  BLOCK                  hold back (down-back for low attacks)")
	lines.append("  EASY AUTO-COMBO        tap light punch repeatedly while hitting")
	lines.append("")
	lines.append("NORMALS  (startup frames)")
	for posture in [0, 1, 2]:
		for button_name in ["LP", "HP", "LK", "HK"]:
			var idx: int = moveset.move_for_arch(archetype, posture, button_name)
			if idx >= 0:
				var m2: Dictionary = moveset.moves[idx]
				lines.append("  %-8s startup %-3d damage %-5d %s" % [str(m2.name).split(":")[-1], int(m2.startup), int(m2.damage), ["", "LOW", "", "OVERHEAD"][int(m2.level)] if int(m2.level) in [2, 3] else ""])
	return "\n".join(lines)
