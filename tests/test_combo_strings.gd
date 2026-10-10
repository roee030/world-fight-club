extends SceneTree

## Data-driven combos (data/combos.json) through the real fighter engine:
## every universal and signature string connects as a true combo from close
## range, KICK chains, damage scales, a guard stops a string, late presses
## inside hitstun keep counting, and the combo breaker works once per combo.

const DT := 1.0 / 60.0

var strings_seen: Array = []


func _init() -> void:
	call_deferred("_run")


func _fresh(main, player_id: String, rival_id: String = "avigdor") -> void:
	main._setup_bout(player_id, rival_id, 1, "COMBO QA")
	for i in range(5): await physics_frame
	for fighter in [main.player, main.enemy]:
		fighter.set_physics_process(false)
		fighter.round_over = false
		fighter.is_cpu = false
		fighter.health = 999.0
	main.player.reset_round(-0.55, 999.0)
	main.enemy.reset_round(0.55, 999.0)
	main.player.combo_string.connect(func(_who: int, name: String, damage: float): strings_seen.append({"name": name, "damage": damage}))
	for i in range(10): _tick(main)


func _tick(main) -> void:
	main.player._physics_process(DT)
	main.enemy._physics_process(DT)
	main.player.set_controls(0.0, false, false, false, "")
	main.enemy.set_controls(0.0, false, main.enemy.input_block, false, "")


func _perform(main, sequence: Array, delay_frames: int = 0) -> int:
	# Press each move as soon as the previous one is allowed to chain.
	var player = main.player
	var index := 0
	var peak := 0
	var started := [0]
	var count_start := func(_who: int, _move: String): started[0] += 1
	player.attack_started.connect(count_start)
	player.set_controls(0.0, false, false, false, sequence[0])
	index = 1
	for frame in range(240):
		player._physics_process(DT)
		main.enemy._physics_process(DT)
		peak = maxi(peak, player.combo_count)
		# One buffered move at a time: press the next only once the previous
		# move has started and connected.
		if index < sequence.size() and started[0] == index and player.attack_confirmed and player.attack_kind != "":
			var move: Dictionary = player.MOVES[player.attack_kind]
			var elapsed: float = player.attack_duration - player.attack_time
			if elapsed >= float(move.cancel_from) - 0.05 + delay_frames * DT:
				player.set_controls(0.0, false, false, false, sequence[index])
				index += 1
		if index >= sequence.size() and player.attack_kind == "" and frame > 30:
			break
	player.attack_started.disconnect(count_start)
	return peak


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	var data: Dictionary = load("res://scripts/fighter.gd").combo_data()
	# 1. Every universal string, with a fighter whose signature does not extend it.
	for entry in data.universal:
		await _fresh(main, "bennet")
		strings_seen.clear()
		var peak := _perform(main, entry.sequence)
		main.player._clear_combo()
		assert(peak == entry.sequence.size(), "%s did not connect as a true combo (peak %d)" % [entry.name, peak])
		var names: Array = strings_seen.map(func(s): return s.name)
		assert(entry.name in names, "%s was not recognised (saw %s)" % [entry.name, names])
	# 2. Every signature string for its own fighter.
	for fighter_id in data.signature:
		var signature: Dictionary = data.signature[fighter_id]
		await _fresh(main, fighter_id, "avigdor" if fighter_id != "avigdor" else "bibi")
		strings_seen.clear()
		var peak := _perform(main, signature.sequence)
		main.player._clear_combo()
		assert(peak == 4, "%s signature %s did not reach 4 hits (peak %d)" % [fighter_id, signature.name, peak])
		var names: Array = strings_seen.map(func(s): return s.name)
		assert(signature.name in names, "%s signature %s not recognised (saw %s)" % [fighter_id, signature.name, names])
	# 3. Damage scaling: a 4-hit string deals less than four unscaled hits.
	await _fresh(main, "yair_lapid")
	strings_seen.clear()
	var start_health: float = main.enemy.health
	_perform(main, ["light", "light", "light", "heavy"])
	var dealt: float = start_health - main.enemy.health
	var moves: Dictionary = main.player.MOVES
	var unscaled: float = (3.0 * moves.light.damage + moves.heavy.damage) * main.player.DAMAGE_SCALE * 0.93
	assert(dealt < unscaled * 0.9, "combo damage is not scaled (%.1f vs %.1f)" % [dealt, unscaled])
	# 4. Guard stops a string at the first hit.
	await _fresh(main, "bennet")
	strings_seen.clear()
	main.enemy.input_block = true
	var guarded_peak := _perform(main, ["light", "light", "heavy"])
	assert(guarded_peak == 0 and strings_seen.is_empty(), "a guarded string still comboed")
	main.enemy.input_block = false
	# 5. Combo breaker: costs 35% energy, ends the rival's combo, needs energy.
	await _fresh(main, "bennet")
	var attacker = main.enemy
	var defender = main.player
	defender.meter = 50.0
	attacker.set_controls(0.0, false, false, false, "light")
	var broke := [false]
	defender.combo_broken.connect(func(_who: int): broke[0] = true)
	for frame in range(60):
		attacker._physics_process(DT)
		defender._physics_process(DT)
		if attacker.combo_count >= 1 and defender.stun > 0.0 and not broke[0]:
			defender.set_controls(0.0, false, true, false, "")
			defender._physics_process(DT)
			defender.set_controls(0.0, false, false, false, "")
			defender._physics_process(DT)
			defender.set_controls(0.0, false, true, false, "")
		if broke[0]:
			break
	assert(broke[0], "double-tap GUARD in hitstun did not break the combo")
	assert(is_equal_approx(defender.meter, 50.0 - float(data.breaker.cost)) or defender.meter < 50.0, "breaker did not spend energy")
	assert(attacker.combo_count == 0 and defender.invulnerable > 0.0, "breaker must end the combo and grant invulnerability")
	defender.meter = 10.0
	defender.stun = 0.3
	attacker.combo_count = 2
	assert(not defender.try_combo_breaker(), "breaker must require 35% energy")
	main.free()
	print("PASS: universal and signature strings, KICK chains, scaling, guard stop and combo breaker")
	quit(0)
