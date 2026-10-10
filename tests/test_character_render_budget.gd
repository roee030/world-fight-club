extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var builder = load("res://scripts/rigged_fighter_visual.gd").new()
	for fighter_id in ["bennet", "avigdor", "bibi", "yair_golan"]:
		var visual: Dictionary = builder.build(fighter_id)
		var triangles := 0
		var skinned_meshes := 0
		var materials := {}
		for node in visual.root.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node.name == "GroundShadow": continue
			if mesh_node.skin != null or not mesh_node.skeleton.is_empty(): skinned_meshes += 1
			if mesh_node.mesh != null:
				triangles += mesh_node.mesh.get_faces().size() / 3
				for surface in mesh_node.mesh.get_surface_count():
					var material := mesh_node.get_active_material(surface)
					if material != null: materials[material.get_instance_id()] = true
		if triangles > 50000:
			_fail("%s exceeds 50k triangles: %d" % [fighter_id, triangles])
			return
		if skinned_meshes > 7:
			_fail("%s exceeds seven skinned meshes including outfit and hair: %d" % [fighter_id, skinned_meshes])
			return
		if materials.size() > 8:
			_fail("%s exceeds eight materials: %d" % [fighter_id, materials.size()])
			return
		visual.root.free()
	quit(0)
