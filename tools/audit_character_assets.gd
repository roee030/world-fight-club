extends SceneTree

const SCENES := [
	"res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf",
	"res://assets/characters/rigged/source/universal-base-characters/Hairstyles/Hair_Beard.gltf",
	"res://assets/characters/rigged/source/universal-base-characters/Hairstyles/Hair_Buzzed.gltf",
	"res://assets/characters/rigged/source/universal-base-characters/Hairstyles/Hair_SimpleParted.gltf"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in SCENES:
		print("ASSET ", path)
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Could not load %s" % path)
			continue
		var model := packed.instantiate()
		get_root().add_child(model)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton != null:
			var names: Array[String] = []
			for bone in skeleton.get_bone_count(): names.append(str(skeleton.get_bone_name(bone)))
			print("  skeleton=", str(model.get_path_to(skeleton)), " bones=", skeleton.get_bone_count())
			print("  bone_names=", ",".join(names))
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		for child in meshes:
			var mesh_instance := child as MeshInstance3D
			print("  mesh=", str(model.get_path_to(mesh_instance)), " surfaces=", mesh_instance.mesh.get_surface_count(), " aabb=", mesh_instance.get_aabb())
		model.free()
	quit(0)
