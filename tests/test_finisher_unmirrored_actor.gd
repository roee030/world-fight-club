extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena := Node3D.new(); root.add_child(arena)
	var camera := Camera3D.new(); arena.add_child(camera)
	var attacker := GameFighter.new(); attacker.setup("yair_golan", 0, false); arena.add_child(attacker)
	var defender := GameFighter.new(); defender.setup("bennet", 1, false); arena.add_child(defender)
	attacker.set_physics_process(false); defender.set_physics_process(false)
	attacker.position.x = 0.6; defender.position.x = -0.6; attacker.meter = 100; defender.health = 1
	var director := FinisherDirector.new(); arena.add_child(director); director.configure(arena, arena, camera)
	director.catalog = {"win": {"implemented": true, "duration": 2.0, "camera_preset": "wide_stage", "events": [{"at": 1.8, "type": "result_marker"}]}}
	var definition := {"implemented": true, "meter_cost": 100, "duration": 1.0, "camera_preset": "wide_stage", "celebration_id": "win", "events": [
		{"at": 0.0, "type": "spawn_actor", "id": "readable_sign", "asset": "res://assets/characters/sprites/yair_golan-0.png", "pixel_scale": 0.002, "anchor": "attacker", "position": [0, 0, 0], "mirror_facing": false},
		{"at": 0.5, "type": "hit", "id": "final", "damage": 999, "final": true}, {"at": 1.0, "type": "celebration_start"}]}
	assert(director.begin(attacker, defender, definition))
	director.advance(0.001)
	assert(not director._actors.readable_sign.sprite.flip_h, "Text-bearing crowd art stays readable from the right side")
	director.cancel(); arena.free()
	print("PASS: actor can mirror its anchor without reversing text art")
	quit(0)
