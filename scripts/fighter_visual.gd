extends RefCounted
class_name FighterVisual

const SpriteMotion = preload("res://scripts/sprite_motion.gd")
const TWELVE_FRAME_IDS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]

# Artwork scale, physical height and floor correction stay separate so replacing
# a sprite sheet cannot silently make its collider float or change its reach.
const FIGHTER_GEOMETRY := {
	"bennet": {"height_m": 1.77, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"avigdor": {"height_m": 1.84, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"bibi": {"height_m": 1.81, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"yair_golan": {"height_m": 1.87, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"aryeh_deri": {"height_m": 1.73, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"yair_lapid": {"height_m": 1.85, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"mansour_abbas": {"height_m": 1.80, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"benny_gantz": {"height_m": 1.96, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"itamar_ben_gvir": {"height_m": 1.75, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"bezalel_smotrich": {"height_m": 1.70, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"gadi_eisenkot": {"height_m": 1.69, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"trump": {"height_m": 1.92, "pixel_scale": 1.0, "ground_offset_m": 0.0},
	"joint_list": {"height_m": 1.88, "pixel_scale": 1.0, "ground_offset_m": 0.0},
}

const DEFAULT_GEOMETRY := {"height_m": 1.82, "pixel_scale": 1.0, "ground_offset_m": 0.0}
const NORMALIZED_FRAME_SIZE := 512
const NORMALIZED_FOOT_BASELINE := 490
const NORMALIZED_FIGURE_HEIGHT := 468

static func build(character_id: String) -> Dictionary:
	var geometry := geometry_for(character_id)
	var root := Node3D.new()
	root.name = "SpriteFighter_%s" % character_id
	root.set_meta("visual_height_m", geometry.height_m)
	root.set_meta("pixel_scale", geometry.pixel_scale)
	root.set_meta("ground_offset_m", geometry.ground_offset_m)
	var sprite := AnimatedSprite3D.new()
	sprite.name = "FighterSprite"
	sprite.sprite_frames = _make_frames(character_id)
	sprite.animation = "idle"
	sprite.position.y = ground_y_from_geometry(geometry)
	sprite.pixel_size = geometry.pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.render_priority = 3
	root.add_child(sprite)
	var shadow := MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.012
	disc.radial_segments = 32
	shadow.mesh = disc
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	shadow.position.y = 0.018
	root.add_child(shadow)
	var motion := SpriteMotion.new()
	motion.name = "SpriteMotion"
	root.add_child(motion)
	motion.bind(sprite)
	sprite.play("idle")
	return {
		"root": root,
		"sprite": sprite,
		"motion": motion,
		"shadow": shadow,
		"pipeline": "2d_sprite",
		"geometry": geometry,
		"height_m": geometry.height_m,
		"ground_y": sprite.position.y,
	}


static func geometry_for(character_id: String) -> Dictionary:
	var geometry: Dictionary = FIGHTER_GEOMETRY.get(character_id, DEFAULT_GEOMETRY).duplicate(true)
	var frame_height := NORMALIZED_FRAME_SIZE
	var foot_baseline := NORMALIZED_FOOT_BASELINE
	var figure_height := NORMALIZED_FIGURE_HEIGHT
	var texture_path := "res://assets/characters/sprites/%s-0.png" % character_id
	var texture := load(texture_path) as Texture2D if ResourceLoader.exists(texture_path) else null
	if texture != null:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var bounds := image.get_used_rect()
			if bounds.size.y > 0:
				frame_height = image.get_height()
				foot_baseline = bounds.end.y
				figure_height = bounds.size.y
	geometry["frame_height_px"] = frame_height
	geometry["foot_baseline_px"] = foot_baseline
	geometry["figure_height_px"] = figure_height
	geometry["pixel_size"] = float(geometry.height_m) * float(geometry.pixel_scale) / float(figure_height)
	return geometry


static func ground_y_from_geometry(geometry: Dictionary) -> float:
	return (float(geometry.foot_baseline_px) - float(geometry.frame_height_px) * 0.5) * float(geometry.pixel_size) + float(geometry.ground_offset_m)

static func _make_frames(character_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var clips: Dictionary = _clip_map(character_id)
	for clip_name in clips:
		frames.add_animation(clip_name)
		frames.set_animation_loop(clip_name, clip_name in ["idle", "walk_forward", "walk_back", "jump_air"])
		frames.set_animation_speed(clip_name, _fps_for(clip_name))
		for frame_index in clips[clip_name]:
			var texture := load("res://assets/characters/sprites/%s-%d.png" % [character_id, frame_index]) as Texture2D
			if texture != null: frames.add_frame(clip_name, texture)
	return frames

static func _clip_map(character_id: String) -> Dictionary:
	if character_id in TWELVE_FRAME_IDS:
		return {"idle": [0, 0], "walk_forward": [1, 2], "walk_back": [2, 1], "crouch": [3], "jab": [0, 4, 4, 0], "cross": [0, 5, 5, 0], "hook": [0, 5, 5, 0], "kick": [0, 6, 6, 0], "block": [7], "hit": [8], "knockdown": [8, 9, 10], "getup": [10, 11, 0], "jump_start": [3, 0], "jump_air": [6], "jump_land": [3, 0]}
	if character_id in ["bibi", "yair_golan"]:
		return {"idle": [0, 0], "walk_forward": [1, 0], "walk_back": [0, 1], "crouch": [2], "jab": [0, 3, 3, 0], "cross": [0, 3, 4, 0], "hook": [0, 4, 4, 0], "kick": [0, 5, 5, 0], "block": [2], "hit": [0], "knockdown": [0, 5, 2], "getup": [2, 0], "jump_start": [2, 0], "jump_air": [5], "jump_land": [2, 0]}
	return {"idle": [0, 1], "walk_forward": [8, 9, 10, 11], "walk_back": [12, 13, 14, 15], "crouch": [0], "jab": [16, 17, 18, 19], "cross": [17, 18, 19, 16], "hook": [20, 21, 22, 23], "kick": [1, 4, 4, 7], "block": [6], "hit": [5], "knockdown": [5, 6, 7], "getup": [7, 6, 0], "jump_start": [0, 2], "jump_air": [4], "jump_land": [2, 0]}

static func _fps_for(clip_name: String) -> float:
	if clip_name in ["walk_forward", "walk_back"]: return 8.5
	if clip_name in ["jab", "cross", "hook", "kick"]: return 12.0
	if clip_name in ["knockdown", "getup"]: return 7.0
	return 6.0
