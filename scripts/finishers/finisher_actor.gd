class_name FinisherActor
extends Node3D

var sprite := Sprite3D.new()
var _frames: Array[Texture2D] = []
var _age := 0.0
var _fps := 8.0
var _motion_time := 0.0
var _motion_duration := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var grounded := false
var floor_y := 0.0
var reduced_motion := false
var shadow: MeshInstance3D

func configure(data: Dictionary) -> bool:
	var paths: Array = data.get("frames", [data.get("asset", "")])
	for path in paths:
		var texture = ResourceLoader.load(str(path)) if ResourceLoader.exists(str(path)) else null
		if not texture is Texture2D:
			return false
		if data.get("region") is Array and data.region.size() == 4:
			var cropped := AtlasTexture.new()
			cropped.atlas = texture
			cropped.region = Rect2(float(data.region[0]), float(data.region[1]), float(data.region[2]), float(data.region[3]))
			texture = cropped
		_frames.append(texture)
	if _frames.is_empty():
		return false
	add_child(sprite)
	sprite.texture = _frames[0]
	sprite.pixel_size = float(data.get("pixel_scale", 0.006))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.flip_h = float(data.get("facing", 1.0)) < 0
	var tint = data.get("modulate", [])
	if tint is Array and tint.size() == 4:
		sprite.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3]))
	grounded = bool(data.get("grounded", false))
	floor_y = float(data.get("floor_y", 0.0))
	if grounded:
		if not data.has("foot_baseline"):
			return false
		sprite.position.y = (float(data.foot_baseline) - sprite.texture.get_height() * 0.5) * sprite.pixel_size
	_fps = float(data.get("fps", 8.0))
	scale = Vector3.ONE * float(data.get("scale", 1.0))
	position = vector_from(data.get("position", [0, 0, 0]))
	if grounded: position.y = floor_y
	if grounded:
		shadow = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.3
		disc.bottom_radius = 0.3
		disc.height = 0.01
		shadow.mesh = disc
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0, 0, 0, 0.25)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow.material_override = material
		shadow.position.y = 0.015
		add_child(shadow)
	return true

static func vector_from(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size() >= 3: return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func move_to(target: Vector3, duration: float, reduced: bool = false) -> void:
	_from = position
	_to = target
	_motion_time = 0.0
	_motion_duration = maxf(duration, 0.0)
	if reduced or _motion_duration == 0:
		position = _to
		_motion_duration = 0

func advance(delta: float) -> void:
	_age += delta
	if not _frames.is_empty(): sprite.texture = _frames.back() if reduced_motion else _frames[int(_age * _fps) % _frames.size()]
	if _motion_duration > 0:
		_motion_time = minf(_motion_duration, _motion_time + delta)
		position = _from.lerp(_to, _motion_time / _motion_duration)
	if grounded: position.y = floor_y
