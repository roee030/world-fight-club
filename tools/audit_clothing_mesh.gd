extends SceneTree

func _init() -> void:
	var root := (load("res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf") as PackedScene).instantiate()
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var body := root.find_child("SuperHero_Male", true, false) as MeshInstance3D
	print("body=", body, " surfaces=", body.mesh.get_surface_count(), " skin=", body.skin)
	for surface in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		print("surface=", surface, " vertices=", vertices.size(), " indices=", indices.size(), " bones=", bones.size(), " weights=", weights.size(), " aabb=", body.mesh.get_aabb())
		var counts := {}
		for vertex in vertices.size():
			var best := 0
			for influence in 4:
				if weights[vertex * 4 + influence] > weights[vertex * 4 + best]: best = influence
			var bone := bones[vertex * 4 + best]
			var name := skeleton.get_bone_name(bone)
			counts[name] = int(counts.get(name, 0)) + 1
		print(counts)
	root.free()
	quit(0)
