extends Node3D

const Motion = preload("res://scripts/quaternius_motion.gd")
var rig: QuaterniusMotion
var status: Label

func _ready() -> void:
	rig = Motion.new()
	add_child(rig)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(3.0, 2.0, 4.0)
	camera.look_at(Vector3(0, 0.9, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(24, 20)
	status.text = "QUATERNIUS SKELETAL MOTION • SOURCE PREVIEW\nGeneric source rig; character art has not been retargeted."
	layer.add_child(status)
	var row := HFlowContainer.new()
	row.position = Vector2(24, 610)
	row.size.x = 1200
	layer.add_child(row)
	for state in Motion.CLIPS:
		var button := Button.new()
		button.text = state
		button.pressed.connect(func(): rig.play_state(state, true))
		row.add_child(button)
