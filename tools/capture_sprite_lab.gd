extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/character_debug.tscn") as PackedScene
	var lab = scene.instantiate()
	get_root().add_child(lab)
	for fighter_index in range(lab.FIGHTERS.size()):
		lab.fighter_index = fighter_index
		lab.state_index = 0
		lab._load_fighter()
		for _i in range(3): await process_frame
		var image := get_root().get_texture().get_image()
		image.save_png("res://output/sprite-lab-%s.png" % lab.FIGHTERS[fighter_index])
	lab.free()
	quit(0)
