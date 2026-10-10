class_name RiggedFighterVisual
extends RefCounted

const Catalog = preload("res://scripts/character_visual_catalog.gd")
const HumanoidMapper = preload("res://scripts/humanoid_bone_map.gd")
const Accessories = preload("res://scripts/fighter_accessories.gd")
const Clothing = preload("res://scripts/fighter_clothing.gd")

func build(fighter_id: String) -> Dictionary:
	var definition: Dictionary = Catalog.definition(fighter_id)
	if definition.is_empty():
		return {"error": "Unknown fighter: %s" % fighter_id}
	var packed := load(definition.body_scene) as PackedScene
	if packed == null:
		return {"error": "Could not load body for %s" % fighter_id}
	var root := packed.instantiate()
	root.name = "Rigged_%s" % fighter_id
	var skeleton := root.get_node_or_null(definition.skeleton_path) as Skeleton3D
	if skeleton == null:
		root.free()
		return {"error": "Skeleton missing for %s" % fighter_id}
	var mapping := HumanoidMapper.resolve(skeleton)
	if not mapping.valid:
		root.free()
		return {"error": "Required bones missing for %s: %s" % [fighter_id, mapping.missing]}
	var meshes: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		_make_materials_unique(mesh_instance)
		meshes.append(mesh_instance)
	var body := root.find_child("SuperHero_Male", true, false) as MeshInstance3D
	var clothing: Array[MeshInstance3D] = []
	if not definition.get("prebuilt_outfit", false):
		clothing = Clothing.attach(skeleton, body, definition)
	var shadow := _make_shadow()
	root.add_child(shadow)
	var accessories: Array[Node3D] = []
	if not definition.get("prebuilt_accessories", false):
		accessories = Accessories.attach(fighter_id, skeleton, definition)
	root.set_meta("visual_height_m", 1.82)
	return {
		"error": "", "root": root, "skeleton": skeleton, "meshes": meshes,
		"shadow": shadow, "warnings": [], "bone_map": mapping.bones,
		"definition": definition, "accessories": accessories, "clothing": clothing,
	}

func _make_materials_unique(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface)
		if material == null:
			material = StandardMaterial3D.new()
		else:
			material = material.duplicate(true)
		mesh_instance.set_surface_override_material(surface, material)

func _make_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.34
	disc.bottom_radius = 0.34
	disc.height = 0.008
	disc.radial_segments = 32
	shadow.mesh = disc
	shadow.position.y = 0.006
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.01, 0.015, 0.025, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	return shadow
