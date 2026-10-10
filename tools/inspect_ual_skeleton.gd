extends SceneTree

func _init() -> void:
	var model := (load("res://assets/animations/quaternius/UAL1_Standard.glb") as PackedScene).instantiate()
	root.add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	for index in skeleton.get_bone_count():
		print(index, ":", skeleton.get_bone_name(index))
	quit()
