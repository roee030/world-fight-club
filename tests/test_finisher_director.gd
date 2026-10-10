extends SceneTree

class RejectingFighter extends GameFighter:
	func apply_authored_hit(_id: String, _damage: float, _direction: float, _reaction: String) -> bool:
		return false

func _init() -> void:
	if not FileAccess.file_exists("res://scripts/finishers/finisher_director.gd"):
		push_error("FAIL: shared finisher director is missing")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var director = load("res://scripts/finishers/finisher_director.gd").new()
	var arena := Node3D.new()
	root.add_child(arena)
	arena.add_child(director)
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(0, 3, 8)
	var original := camera.transform
	var attacker := GameFighter.new()
	var defender := GameFighter.new()
	attacker.setup("bennet", 0, false)
	defender.setup("bibi", 1, false)
	arena.add_child(attacker)
	arena.add_child(defender)
	attacker.set_physics_process(false)
	defender.set_physics_process(false)
	attacker.meter = 100
	defender.health = 10
	director.configure(arena, arena, camera)
	director.catalog = {"victory": {"duration": 2.0, "events": [{"at": 2.0, "type": "result_marker"}]}}
	var counts := {"final": 0, "result": 0, "celebration": 0}
	director.final_hit.connect(func(_who): counts.final += 1)
	director.result_ready.connect(func(_who): counts.result += 1)
	director.celebration_started.connect(func(_id): counts.celebration += 1)
	var definition := {"implemented": true, "meter_cost": 100, "duration": 1.0, "celebration_id": "victory", "events": [
		{"at": 0.0, "type": "portrait_lightbox"},
		{"at": 0.2, "type": "hit", "id": "opening", "damage": 999},
		{"at": 0.3, "type": "hit", "id": "stagger", "damage": 999},
		{"at": 0.5, "type": "hit", "id": "finish", "damage": 999, "final": true},
		{"at": 1.0, "type": "celebration_start"}]}
	assert(director.begin(attacker, defender, definition))
	assert(attacker.cinematic_locked and defender.cinematic_locked)
	assert(attacker.meter == 0)
	assert(not director.begin(attacker, defender, definition))
	director.advance(0.2)
	assert(defender.health == 1, "Intermediate authored hit must preserve one health")
	director.set_paused(true)
	director.advance(5)
	assert(defender.health == 1 and counts.final == 0)
	director.set_paused(false)
	director.advance(0.8)
	assert(defender.health == 0 and counts.final == 1 and counts.celebration == 1)
	director.advance(2)
	director.advance(2)
	assert(counts.result == 1 and camera.transform == original)
	assert(not attacker.cinematic_locked and not defender.cinematic_locked)
	assert(director.temporary_actor_count() == 0)
	attacker.meter = 100
	defender.health = 10
	defender.round_over = false
	assert(director.begin(attacker, defender, definition))
	director.cancel()
	assert(camera.transform == original and counts.result == 1)
	attacker.meter = 100
	var unknown := definition.duplicate(true)
	unknown.events = [{"at": 0.0, "type": "unsupported"}]
	assert(director.begin(attacker, defender, unknown))
	director.advance(0)
	assert(not director.active and director.diagnostic.contains("Unknown finisher event"))
	assert(counts.result == 1 and camera.transform == original)
	var reject := RejectingFighter.new()
	reject.setup("bibi", 1, false)
	arena.add_child(reject)
	reject.set_physics_process(false)
	reject.health = 10
	attacker.meter = 100
	assert(director.begin(attacker, reject, definition))
	director.advance(0.2)
	assert(not director.active and reject.health == 10 and counts.result == 1)
	assert(not attacker.cinematic_locked and not reject.cinematic_locked)
	assert(camera.transform == original)
	attacker.meter = 100
	defender.health = 0
	assert(not director.begin(attacker, defender, definition), "Unrelated KO must reject start before meter spend")
	assert(attacker.meter == 100)
	var actor = load("res://scripts/finishers/finisher_actor.gd").new()
	assert(actor.configure({"asset": "res://assets/characters/portraits/bennet.png", "grounded": true, "foot_baseline": 400, "position": [1, 9, 0], "facing": -1}))
	arena.add_child(actor)
	assert(actor.position.y == 0 and actor.sprite.flip_h)
	actor.move_to(Vector3(2, 6, 0), 1)
	actor.advance(0.5)
	assert(is_equal_approx(actor.position.x, 1.5) and actor.position.y == 0)
	actor.move_to(Vector3(3, 0, 0), 1, true)
	assert(actor.position.x == 3)
	actor.free()
	arena.queue_free()
	print("PASS: finisher director locks, capped damage, pause, final hit, celebration and cleanup")
	quit(0)
