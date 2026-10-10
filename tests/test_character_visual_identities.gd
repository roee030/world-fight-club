extends SceneTree

const EXPECTED := {
	"avigdor": ["ContinuousOutfit", "IntegratedShoes", "GrayHair", "GrayBeard"],
	"bibi": ["ContinuousOutfit", "IntegratedShoes", "SilverHair"],
	"yair_golan": ["ContinuousOutfit", "IntegratedShoes", "GrayBuzzCut", "Sunglasses"],
}

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var builder = load("res://scripts/rigged_fighter_visual.gd").new()
	for fighter_id in EXPECTED:
		var visual: Dictionary = builder.build(fighter_id)
		if not str(visual.get("error", "")).is_empty():
			_fail(visual.error)
			return
		for part_name in EXPECTED[fighter_id]:
			if visual.root.find_child(part_name, true, false) == null:
				_fail("%s is missing %s" % [fighter_id, part_name])
				return
		if not visual.root.find_children("*", "Sprite3D", true, false).is_empty():
			_fail("%s contains a portrait billboard" % fighter_id)
			return
		visual.root.free()
	quit(0)
