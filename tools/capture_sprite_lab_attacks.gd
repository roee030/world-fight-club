extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/character_debug.tscn") as PackedScene
	var lab = scene.instantiate()
	get_root().add_child(lab)
	for fighter_id in ["bibi", "mansour_abbas"]:
		lab.fighter_index = lab.FIGHTERS.find(fighter_id)
		lab._load_fighter()
		for state in ["jab", "cross", "kick", "hit", "knockdown"]:
			lab._set_state_by_name(state)
			for _frame in range(3):
				await process_frame
			get_root().get_texture().get_image().save_png("res://output/lab-%s-%s.png" % [fighter_id, state])
	lab.free()
	quit(0)
