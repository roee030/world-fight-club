extends SceneTree

const IDS := [
	"bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid",
	"mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich",
	"gadi_eisenkot", "trump", "joint_list"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var heights: Array[float] = []
	for fighter_id in IDS:
		var geometry := FighterVisual.geometry_for(fighter_id)
		for field in ["height_m", "pixel_scale", "pixel_size", "ground_offset_m", "frame_height_px", "foot_baseline_px"]:
			if not geometry.has(field): return _fail("%s geometry is missing %s" % [fighter_id, field])
		if float(geometry.height_m) <= 0.0: return _fail("%s has an invalid physical height" % fighter_id)
		if float(geometry.pixel_size) <= 0.0: return _fail("%s has an invalid pixel scale" % fighter_id)
		heights.append(float(geometry.height_m))

	if heights.max() - heights.min() < 0.15:
		return _fail("fighter height range is not visibly different")

	for fighter_id in IDS:
		var visual := FighterVisual.build(fighter_id)
		var geometry: Dictionary = visual.geometry
		var idle_texture: Texture2D = visual.sprite.sprite_frames.get_frame_texture("idle", 0)
		var idle_image := idle_texture.get_image()
		var alpha_bounds := idle_image.get_used_rect()
		var foot_world_y: float = visual.sprite.position.y + (float(idle_image.get_height()) * 0.5 - float(alpha_bounds.end.y)) * visual.sprite.pixel_size
		if absf(foot_world_y - float(geometry.ground_offset_m)) > 0.001:
			visual.root.free()
			return _fail("%s feet do not touch its configured floor baseline" % fighter_id)
		visual.root.free()

	var short_fighter := FighterVisual.build("bezalel_smotrich")
	var tall_fighter := FighterVisual.build("benny_gantz")
	if float(short_fighter.height_m) >= float(tall_fighter.height_m):
		short_fighter.root.free()
		tall_fighter.root.free()
		return _fail("fighter builds do not expose distinct physical heights")
	short_fighter.root.free()
	tall_fighter.root.free()

	for fighter_id in ["bezalel_smotrich", "benny_gantz"]:
		var fighter := GameFighter.new()
		fighter.setup(fighter_id, 0, false)
		root.add_child(fighter)
		var configured_height := float(FighterVisual.geometry_for(fighter_id).height_m)
		if not is_equal_approx(fighter._standing_capsule.height, configured_height):
			fighter.free()
			return _fail("%s collider does not follow its physical height" % fighter_id)
		if not is_equal_approx(fighter._collider.position.y, configured_height * 0.5):
			fighter.free()
			return _fail("%s collider is not grounded at half its height" % fighter_id)
		fighter.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
