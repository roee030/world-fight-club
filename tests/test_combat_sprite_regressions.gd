extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena := Node3D.new()
	get_root().add_child(arena)
	var attacker := GameFighter.new()
	var victim := GameFighter.new()
	attacker.setup("yair_lapid", 0, false)
	victim.setup("benny_gantz", 1, false)
	arena.add_child(attacker)
	arena.add_child(victim)
	attacker.rival = victim
	victim.rival = attacker
	await process_frame
	attacker.facing = 1.0
	attacker._start_attack("heavy")
	if attacker.attack_kind != "heavy": return _fail("attack did not start")
	var before := victim.health
	victim.receive_hit(14.0, 1.0, "heavy")
	if victim.health >= before: return _fail("health did not decrease")
	if victim.attack_kind != "" or victim.attack_request != "" or victim.buffered_attack != "": return _fail("hit victim retained an attack")
	if victim._visual.sprite.animation != "hit": return _fail("hit art was not selected")
	victim.stun = 0.0
	victim.invulnerable = 0.0
	victim.receive_hit(20.0, 1.0, "special")
	if victim.knockdown_time <= 0.0: return _fail("special did not cause knockdown")
	if victim._visual.sprite.animation != "knockdown": return _fail("knockdown clip was not selected")
	attacker.attack_kind = ""
	attacker.facing = -1.0
	attacker._animate()
	if not attacker._visual.sprite.flip_h: return _fail("neutral facing did not update")
	attacker.reset_round(-1.85, attacker.max_health())
	victim.facing = 1.0
	victim.attack_facing = 1.0
	victim._visual.sprite.flip_h = false
	victim.reset_round(1.85, victim.max_health())
	if attacker.facing != 1.0 or attacker.attack_facing != 1.0 or attacker._visual.sprite.flip_h: return _fail("player facing was not reset at round start")
	if victim.facing != -1.0 or victim.attack_facing != -1.0 or not victim._visual.sprite.flip_h: return _fail("CPU facing was not reset at round start")
	arena.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
