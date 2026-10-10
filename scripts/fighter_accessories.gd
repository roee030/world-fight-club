class_name FighterAccessories
extends RefCounted

const HAIR_ROOT := "res://assets/characters/rigged/source/universal-base-characters/Hairstyles/"

static func attach(character_id: String, skeleton: Skeleton3D, definition: Dictionary) -> Array[Node3D]:
	var parts: Array[Node3D] = []
	if character_id == "bennet":
		parts.append_array(_bennet_krav_maga(skeleton, definition.palette))
	elif character_id == "avigdor":
		parts.append(_rigged_hair(skeleton, "Hair_SimpleParted.gltf", "GrayHair", Color("92979b")))
		parts.append(_rigged_hair(skeleton, "Hair_Beard.gltf", "GrayBeard", Color("85898c")))
	elif character_id == "bibi":
		parts.append(_rigged_hair(skeleton, "Hair_SimpleParted.gltf", "SilverHair", Color("c4cbd0")))
	elif character_id == "yair_golan":
		parts.append(_rigged_hair(skeleton, "Hair_Buzzed.gltf", "GrayBuzzCut", Color("9a9d9a")))
		parts.append(_head_box(skeleton, "Sunglasses", Vector3(0.245, 0.055, 0.018), Vector3(0, 0.012, 0.145), Color("080b0d")))
	return parts

static func _bennet_krav_maga(skeleton: Skeleton3D, palette: Dictionary) -> Array[Node3D]:
	return []

static func _rigged_hair(skeleton: Skeleton3D, file_name: String, part_name: String, color: Color) -> MeshInstance3D:
	var source := (load(HAIR_ROOT + file_name) as PackedScene).instantiate()
	var found := source.find_children("*", "MeshInstance3D", true, false)
	var mesh_node := found[0] as MeshInstance3D
	mesh_node.owner = null
	mesh_node.reparent(skeleton, false)
	mesh_node.name = part_name
	mesh_node.skeleton = NodePath("..")
	for surface in mesh_node.mesh.get_surface_count():
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.82
		mesh_node.set_surface_override_material(surface, material)
	source.free()
	return mesh_node

static func _head_attachment(skeleton: Skeleton3D, part_name: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = "%s_Attachment" % part_name
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	return attachment

static func _head_disc(skeleton: Skeleton3D, part_name: String, radius: float, height: float, offset: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = offset
	node.material_override = _material(color)
	_head_attachment(skeleton, part_name).add_child(node)
	return node

static func _head_box(skeleton: Skeleton3D, part_name: String, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = offset
	node.material_override = _material(color)
	_head_attachment(skeleton, part_name).add_child(node)
	return node

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
