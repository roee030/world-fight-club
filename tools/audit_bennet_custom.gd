extends SceneTree

func _init() -> void:
	var scene := load("res://assets/characters/rigged/custom/bennet/bennet-krav-maga.glb") as PackedScene
	var root := scene.instantiate()
	_print_node(root, "")
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	for skeleton in skeletons:
		print("SKELETON ", skeleton.get_path(), " bones=", skeleton.get_bone_count())
	root.free()
	quit(0)

func _print_node(node: Node, indent: String) -> void:
	print(indent, node.name, " [", node.get_class(), "]")
	for child in node.get_children(): _print_node(child, indent + "  ")
