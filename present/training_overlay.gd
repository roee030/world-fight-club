extends Node3D

## Training-mode overlay (presentation only): hit/hurt/push boxes drawn in the
## fighting plane, an SF6-style frame meter for both fighters, and the frame
## advantage of the last exchange (on hit / on block).

const L = preload("res://sim/layout.gd")
const METER_FRAMES := 80
const COLORS := {
	"idle": Color(0.25, 0.27, 0.3), "startup": Color(0.2, 0.85, 0.45), "active": Color(1.0, 0.25, 0.3),
	"recovery": Color(0.25, 0.55, 1.0), "stun": Color(1.0, 0.85, 0.2), "move": Color(0.55, 0.6, 0.65), "air": Color(0.7, 0.5, 1.0),
}

var _mesh := ImmediateMesh.new()
var _lines: MeshInstance3D
var _meter: Control
var _info: Label
var _history: Array = [[], []]
var _last_frame := -1
var _exchange := {}     # tracks the last hit/block to compute frame advantage
var advantage_text := ""


func setup(hud_root: Control) -> void:
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_lines.material_override = mat
	add_child(_lines)
	_meter = Control.new()
	_meter.anchor_left = 0.1
	_meter.anchor_right = 0.9
	_meter.anchor_top = 1.0
	_meter.anchor_bottom = 1.0
	_meter.offset_top = -120
	_meter.offset_bottom = -76
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	hud_root.add_child(_meter)
	_info = Label.new()
	_info.anchor_left = 0.0
	_info.anchor_right = 1.0
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_top = -146
	_info.offset_bottom = -122
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_info)


func set_active(on: bool) -> void:
	visible = on
	_meter.visible = on
	_info.visible = on


func observe(s: PackedInt32Array, moveset, events: PackedInt32Array) -> void:
	# Called once per simulated frame.
	if s[L.H_FRAME] == _last_frame:
		return
	_last_frame = s[L.H_FRAME]
	for i in range(2):
		_history[i].append(_classify(s, i, moveset))
		if _history[i].size() > METER_FRAMES:
			_history[i].pop_front()
	for e in range(0, events.size(), L.EVENT_SIZE):
		if events[e] in [L.EV_HIT, L.EV_BLOCK]:
			var attacker := events[e + 1]
			_exchange = {"attacker": attacker, "defender": 1 - attacker, "blocked": events[e] == L.EV_BLOCK, "a_free": -1, "d_free": -1, "frame": s[L.H_FRAME], "move": str(moveset.moves[events[e + 2]].name), "damage": events[e + 3]}
	if not _exchange.is_empty():
		for role in ["attacker", "defender"]:
			var key := "a_free" if role == "attacker" else "d_free"
			if int(_exchange[key]) < 0 and _actionable(s, int(_exchange[role])):
				_exchange[key] = s[L.H_FRAME]
		if int(_exchange.a_free) >= 0 and int(_exchange.d_free) >= 0:
			var adv := int(_exchange.d_free) - int(_exchange.a_free)
			advantage_text = "%s  %s  %s%d  (damage %d)" % [_exchange.move, "ON BLOCK" if _exchange.blocked else "ON HIT", "+" if adv >= 0 else "", adv, _exchange.damage]
			_info.text = advantage_text
			_exchange = {}
	_meter.queue_redraw()


func draw_boxes(s: PackedInt32Array, moveset) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var r: Dictionary = moveset.rules
	for i in range(s[L.H_FIGHTERS]):
		var b := L.base(i)
		var x := s[b + L.F_X]
		var y := s[b + L.F_Y]
		var state := s[b + L.F_STATE]
		# Hurtbox (mirrors sim._hurtbox).
		var hurt: Array = r.stand.hurt
		var height := int(hurt[3])
		var bottom := y + int(hurt[1])
		var crouched := state == L.S_CROUCH or (state == L.S_ATTACK and s[b + L.F_MOVE] >= 0 and int(moveset.moves[s[b + L.F_MOVE]].posture) == 1)
		if crouched:
			height = int(r.crouch.hurt_height)
		elif y > 0 or state in [L.S_AIR, L.S_LAUNCHED]:
			hurt = r.air_hurt
			height = int(hurt[3])
			bottom = y + int(hurt[1])
		_rect(x + int(hurt[0]), bottom, int(hurt[2]), height, Color(0.3, 1.0, 0.5))
		# Push box.
		var half := int(r.push_half_width)
		_rect(x - half, y, half * 2, 200, Color(1, 1, 1, 0.6))
		# Active hitbox.
		if state == L.S_ATTACK and s[b + L.F_MOVE] >= 0:
			var m: Dictionary = moveset.moves[s[b + L.F_MOVE]]
			var sf := s[b + L.F_STATE_FRAME]
			if sf >= int(m.startup) and sf < int(m.startup) + int(m.active) and not bool(m.projectile):
				var hb: PackedInt32Array = m.hitbox
				var facing := s[b + L.F_FACING]
				var hx := x + (hb[0] if facing > 0 else -hb[0] - hb[2])
				_rect(hx, y + hb[1], hb[2], hb[3], Color(1, 0.2, 0.25))
	for slot in range(L.PROJECTILES):
		var p := L.projectile_base(s, slot)
		if s[p + L.P_ACTIVE] != 0:
			var pm: Dictionary = moveset.moves[s[p + L.P_MOVE]]
			var box: PackedInt32Array = pm.proj_box
			_rect(s[p + L.P_X] - box[2] / 2, s[p + L.P_Y] + box[1], box[2], box[3], Color(1, 0.5, 0.1))
	_mesh.surface_end()


func _rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	var u := 1.0 / 10000.0
	var corners := [Vector3(x * u, y * u, 0.45), Vector3((x + w) * u, y * u, 0.45), Vector3((x + w) * u, (y + h) * u, 0.45), Vector3(x * u, (y + h) * u, 0.45)]
	for k in range(4):
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(corners[k])
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(corners[(k + 1) % 4])


func _actionable(s: PackedInt32Array, i: int) -> bool:
	var b := L.base(i)
	return s[b + L.F_STATE] in [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH] and s[b + L.F_HITSTOP] == 0


func _classify(s: PackedInt32Array, i: int, moveset) -> String:
	var b := L.base(i)
	var state := s[b + L.F_STATE]
	match state:
		L.S_ATTACK, L.S_THROW:
			var m: Dictionary = moveset.moves[s[b + L.F_MOVE]] if s[b + L.F_MOVE] >= 0 else {}
			if m.is_empty(): return "recovery"
			var sf := s[b + L.F_STATE_FRAME]
			if sf < int(m.startup): return "startup"
			if sf < int(m.startup) + int(m.active): return "active"
			return "recovery"
		L.S_HITSTUN, L.S_BLOCKSTUN, L.S_LAUNCHED, L.S_KNOCKDOWN, L.S_GETUP, L.S_THROWN:
			return "stun"
		L.S_DASH, L.S_BACKDASH, L.S_RUSH, L.S_PREJUMP, L.S_LAND, L.S_PARRY:
			return "move"
		L.S_AIR:
			return "air"
	return "idle"


func _draw_meter() -> void:
	var size := _meter.size
	var cell := size.x / METER_FRAMES
	for i in range(2):
		var row: Array = _history[i]
		var y := i * (size.y * 0.5)
		for k in range(row.size()):
			var color: Color = COLORS.get(row[k], COLORS.idle)
			_meter.draw_rect(Rect2(k * cell, y + 2, cell - 1, size.y * 0.5 - 4), color)
