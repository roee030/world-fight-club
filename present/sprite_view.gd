extends Node3D

## Presents a 12-pose sprite fighter (legacy contract, e.g. a local private
## fighter) inside the new 3D battle, with the same show_state() interface as
## character_view.gd. A stop-gap until the fighter has a rigged 3D model.
## Pose order: idle, walk A, walk B, crouch, jab, cross, kick, block, hit,
## falling, knockdown, get-up (docs/character-pipeline.md).

const L = preload("res://sim/layout.gd")
const UNIT := 1.0 / 10000.0

var sprite: Sprite3D
var _frames: Array[Texture2D] = []
var _height_m := 1.8
var _walk_clock := 0.0
var _shake_phase := 0


func setup_frames(frame_paths: Array, height_m: float = 1.8) -> void:
	_height_m = height_m
	for path in frame_paths:
		_frames.append(load(path) as Texture2D)
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_apply(0)
	# Scale so the idle figure is height_m tall with its feet on the floor.
	var image := _frames[0].get_image()
	var used := image.get_used_rect()
	sprite.pixel_size = _height_m / float(maxi(1, used.size.y))
	sprite.position.y = (image.get_height() * 0.5 - used.end.y) * -sprite.pixel_size
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.01
	shadow.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.position.y = 0.01
	add_child(shadow)
	shadow.name = "Shadow"


func _apply(index: int) -> void:
	if index >= 0 and index < _frames.size():
		sprite.texture = _frames[index]


func show_state(s: PackedInt32Array, i: int, moveset) -> void:
	var b := L.base(i)
	var state := s[b + L.F_STATE]
	var sf := s[b + L.F_STATE_FRAME]
	position = Vector3(s[b + L.F_X] * UNIT, s[b + L.F_Y] * UNIT, 0.0)
	(get_node("Shadow") as Node3D).position.y = 0.01 - position.y
	sprite.flip_h = s[b + L.F_FACING] < 0
	var frame := 0
	match state:
		L.S_WALK_F, L.S_WALK_B, L.S_DASH, L.S_BACKDASH, L.S_RUSH:
			frame = 1 + (sf / 8) % 2
		L.S_CROUCH:
			frame = 3
		L.S_PREJUMP, L.S_LAND:
			frame = 3
		L.S_AIR:
			frame = 0
		L.S_BLOCKSTUN, L.S_PARRY:
			frame = 7
		L.S_HITSTUN, L.S_THROWN:
			frame = 8
		L.S_LAUNCHED:
			frame = 9
		L.S_KNOCKDOWN, L.S_KO:
			frame = 10 if s[b + L.F_Y] == 0 else 9
		L.S_GETUP:
			frame = 11
		L.S_THROW:
			frame = 5
		L.S_ATTACK:
			var m: Dictionary = moveset.moves[s[b + L.F_MOVE]]
			var startup := int(m.startup)
			var active_end := startup + int(m.active) + int(m.recovery) / 2
			var strike := 6 if str(m.anim) == "kick" else (4 if str(m.anim) == "jab" else 5)
			if sf < startup - 2: frame = 3 if int(m.posture) == 1 else 0
			elif sf <= active_end: frame = strike
			else: frame = 3 if int(m.posture) == 1 else 0
	_apply(frame)
	if s[b + L.F_HITSTOP] > 0 and state in [L.S_HITSTUN, L.S_BLOCKSTUN, L.S_LAUNCHED]:
		_shake_phase += 1
		sprite.position.x = 0.025 * (1 if _shake_phase % 2 == 0 else -1)
	else:
		sprite.position.x = 0.0
