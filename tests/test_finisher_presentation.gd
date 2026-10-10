extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director = load("res://scripts/finishers/finisher_director.gd").new()
	var arena := Node3D.new()
	root.add_child(arena)
	arena.add_child(director)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 3.6, 9.7)
	arena.add_child(camera)
	var attacker = load("res://scripts/fighter.gd").new()
	var defender = load("res://scripts/fighter.gd").new()
	attacker.setup("bennet", 0, false)
	defender.setup("bibi", 1, false)
	arena.add_child(attacker)
	arena.add_child(defender)
	attacker.set_physics_process(false)
	defender.set_physics_process(false)
	attacker.meter = 100.0
	defender.health = 10.0
	var original = attacker._visual.sprite.sprite_frames
	director.configure(arena, arena, camera)
	director.catalog = {"victory": {"duration": 2.0, "events": [{"at": 2.0, "type": "result_marker"}]}}
	var definition := {"implemented": true, "duration": 1.0, "camera_preset": "close_side", "celebration_id": "victory", "events": [{"at": 0.0, "type": "fighter_clip", "asset": "res://assets/characters/sprites/bennet-0.png", "region": [0, 0, 512, 512], "figure_height_px": 468, "foot_baseline": 490}]}
	assert(director.begin(attacker, defender, definition))
	assert(camera.fov == 30.0 and camera.position == Vector3(0, 3.6, 9.7), "presets must keep the fight framing (no zoom jump)")
	director.advance(0.0)
	assert(attacker._visual.sprite.sprite_frames != original, "authored celebration texture is used")
	director.cancel()
	assert(camera.fov == 30.0)
	assert(attacker._visual.sprite.sprite_frames == original, "normal fighter frames restored")
	arena.free()
	print("PASS: presets keep fight framing, authored art geometry and cleanup")
	quit(0)
