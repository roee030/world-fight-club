extends SceneTree

const IDS := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const CLIPS := ["idle", "walk_forward", "walk_back", "crouch", "jab", "cross", "hook", "kick", "block", "hit", "knockdown", "getup", "jump_start", "jump_air", "jump_land"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for id in IDS:
		var visual := FighterVisual.build(id)
		if visual.get("pipeline", "") != "2d_sprite": return _fail("%s is not on sprite pipeline" % id)
		var sprite: AnimatedSprite3D = visual.sprite
		for clip in CLIPS:
			if not sprite.sprite_frames.has_animation(clip): return _fail("%s missing %s" % [id, clip])
			if sprite.sprite_frames.get_frame_count(clip) < 1: return _fail("%s has empty %s" % [id, clip])
		visual.motion.set_facing(-1.0)
		if not sprite.flip_h: return _fail("%s did not face left" % id)
		visual.motion.set_facing(1.0)
		if sprite.flip_h: return _fail("%s did not face right" % id)
		visual.root.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
