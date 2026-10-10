extends RefCounted

## Presentation-only effects (never touch the sim): particle hit bursts,
## projectile visuals with a trail, and a white hit-flash overlay material.
## CPUParticles3D keeps it working on the Web/Compatibility renderer.


static func burst(parent: Node3D, position: Vector3, color: Color, strength: float) -> void:
	# Streaks flying out of the impact point plus a bright core; plain meshes and
	# tweens (no particle systems), so it renders the same on Web and mobile.
	var count := int(7 + 7 * strength)
	for k in range(count):
		var streak := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.05 + 0.04 * strength, 0.34 + 0.3 * strength)
		streak.mesh = quad
		streak.material_override = _glow(color, 0.95)
		var angle := TAU * float(k) / float(count) + randf_range(-0.2, 0.2)
		var dir := Vector3(cos(angle), sin(angle), 0.0)
		streak.position = position + dir * 0.08
		streak.rotation.z = angle - PI * 0.5
		parent.add_child(streak)
		var travel := randf_range(0.35, 0.8) * (0.6 + strength)
		var tween := streak.create_tween()
		tween.tween_property(streak, "position", position + dir * travel, 0.16).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(streak, "scale", Vector3(1, 0.2, 1), 0.16)
		tween.parallel().tween_property(streak.material_override, "albedo_color:a", 0.0, 0.16)
		tween.tween_callback(streak.queue_free)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12 + 0.16 * strength
	sphere.height = sphere.radius * 2.0
	core.mesh = sphere
	core.material_override = _glow(color.lightened(0.6), 0.9)
	core.position = position
	parent.add_child(core)
	var grow := core.create_tween()
	grow.tween_property(core, "scale", Vector3.ONE * 2.0, 0.1)
	grow.parallel().tween_property(core.material_override, "albedo_color:a", 0.0, 0.1)
	grow.tween_callback(core.queue_free)


static func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func projectile(color: Color) -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1, 1, 1)
	core_mat.emission_enabled = true
	core_mat.emission = color.lightened(0.6)
	core_mat.emission_energy_multiplier = 6.0
	core.material_override = core_mat
	root.add_child(core)
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.3
	shell_mesh.height = 0.6
	shell.mesh = shell_mesh
	var shell_mat := StandardMaterial3D.new()
	shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	shell_mat.emission_enabled = true
	shell_mat.emission = color
	shell_mat.emission_energy_multiplier = 3.0
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.material_override = shell_mat
	shell.name = "Shell"
	root.add_child(shell)
	# Motion streak behind the orb.
	var streak := MeshInstance3D.new()
	var tail := SphereMesh.new()
	tail.radius = 0.22
	tail.height = 0.44
	streak.mesh = tail
	streak.material_override = _glow(color, 0.3)
	streak.scale = Vector3(2.6, 0.7, 0.7)
	streak.name = "Tail"
	root.add_child(streak)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 3.0
	root.add_child(light)
	return root


static func flash_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	return mat
