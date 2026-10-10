extends SceneTree

## Balance and AI quality for the Quick Fight CPU (level 1), measured with a
## scripted "average touch player". Fighters are stepped manually at 60 Hz, so
## a run is deterministic for its seed and fast in headless mode.
##
## Goals (from play-testing feedback):
## - the CPU is not trivial to beat, but an average player still wins often;
## - rounds last long enough to build Special Energy (no five-hit deaths);
## - Special Energy carries over between rounds, so SP is reached in a match;
## - the CPU is unpredictable (its attack choice has high entropy);
## - the CPU learns: it guards a repeated habit more often over time.

const DT := 1.0 / 60.0
const MATCHES := 10
const ROUND_SECONDS := 60.0

var _last_habit_samples := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20261009)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(3):
		await process_frame
	main._setup_bout("bennet", "avigdor", 1, "FAIRNESS QA")
	for _frame in range(6):
		await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	# Seed after the scene is ready: main._ready() calls randomize().
	seed(20261009)
	var player = main.player
	var cpu = main.enemy
	player.set_physics_process(false)
	cpu.set_physics_process(false)
	var cpu_attacks := {}
	var breaks := {"player": 0, "cpu": 0}
	player.combo_broken.connect(func(_who: int): breaks.player += 1)
	cpu.combo_broken.connect(func(_who: int): breaks.cpu += 1)
	cpu.attack_started.connect(func(_who: int, move: String): cpu_attacks[move] = int(cpu_attacks.get(move, 0)) + 1)
	var stats := {"player_rounds": 0, "cpu_rounds": 0, "round_seconds": 0.0, "rounds": 0, "player_dealt": 0.0, "cpu_dealt": 0.0, "sp_matches": 0}
	for match_index in range(MATCHES):
		var player_wins := 0
		var cpu_wins := 0
		var reached_sp := false
		player.meter = 0.0
		cpu.meter = 0.0
		cpu.cpu_brain = null
		while player_wins < 2 and cpu_wins < 2:
			var result: Dictionary = _play_round(main, player, cpu)
			stats.rounds += 1
			stats.round_seconds += float(result.seconds)
			stats.player_dealt += float(result.player_dealt)
			stats.cpu_dealt += float(result.cpu_dealt)
			reached_sp = reached_sp or bool(result.reached_sp)
			if result.player_won: player_wins += 1
			else: cpu_wins += 1
		stats.player_rounds += player_wins
		stats.cpu_rounds += cpu_wins
		if reached_sp: stats.sp_matches += 1
	var average_round := float(stats.round_seconds) / maxf(1.0, float(stats.rounds))
	var win_ratio := float(stats.player_rounds) / maxf(1.0, float(stats.player_rounds + stats.cpu_rounds))
	var entropy := _entropy(cpu_attacks)
	# Learning: a player who always throws CROSS from the same spot.
	cpu.cpu_brain = null
	var early := _guard_rate_against_habit(player, cpu, 14.0)
	var early_samples: int = _last_habit_samples
	_guard_rate_against_habit(player, cpu, 20.0)
	var late := _guard_rate_against_habit(player, cpu, 30.0)
	print("FAIRNESS: player_round_wins=%.2f avg_round=%.1fs player_dealt=%.0f cpu_dealt=%.0f sp_matches=%d/%d cpu_attack_entropy=%.2f bits attacks=%s habit_guard early=%.2f late=%.2f breaks=%s" % [win_ratio, average_round, stats.player_dealt, stats.cpu_dealt, stats.sp_matches, MATCHES, entropy, cpu_attacks, early, late, breaks])
	main.free()
	if win_ratio > 0.82:
		return _fail("the level-1 CPU is too easy (player wins %.2f of rounds)" % win_ratio)
	if win_ratio < 0.40:
		return _fail("an average player loses most rounds to the level-1 CPU (%.2f)" % win_ratio)
	if average_round < 22.0:
		return _fail("rounds end too fast (%.1fs) — the player dies before building Special Energy" % average_round)
	if stats.sp_matches < MATCHES / 2:
		return _fail("Special Energy reached 100%% in only %d of %d matches" % [stats.sp_matches, MATCHES])
	if entropy < 1.2:
		return _fail("CPU attack choice is predictable (%.2f bits)" % entropy)
	if early_samples < 3:
		return _fail("habit test did not connect enough early attacks to measure learning")
	if late < early + 0.08:
		return _fail("CPU did not learn to guard a repeated habit (early %.2f, late %.2f)" % [early, late])
	print("PASS: beatable but not trivial CPU, long enough rounds, SP reachable, unpredictable and adaptive")
	quit(0)


func _play_round(main, player, cpu) -> Dictionary:
	player.reset_round(-1.85, player.max_health(), true)
	cpu.reset_round(1.85, cpu.max_health(), true)
	main.fight_live = true
	main.round_ready = true
	main.intermission = 0.0
	main.match_state = main.MatchState.Value.FIGHTING
	var player_start: float = player.health
	var cpu_start: float = cpu.health
	var elapsed := 0.0
	var attack_cooldown := 0.4
	var guard_time := 0.0
	var guard_decided := false
	var reached_sp := false
	while elapsed < ROUND_SECONDS and player.health > 0.0 and cpu.health > 0.0:
		elapsed += DT
		attack_cooldown -= DT
		guard_time = maxf(0.0, guard_time - DT)
		var dx: float = cpu.global_position.x - player.global_position.x
		var axis := 0.0
		var request := ""
		# Average phone player: guards a quarter of CPU attacks, closes in and
		# attacks at a human tapping cadence.
		if cpu.attack_kind != "" and not guard_decided:
			guard_decided = true
			if randf() < 0.25: guard_time = 0.32
		elif cpu.attack_kind == "":
			guard_decided = false
		if guard_time <= 0.0:
			if absf(dx) > 1.25:
				axis = signf(dx)
			elif attack_cooldown <= 0.0:
				attack_cooldown = randf_range(0.38, 0.8)
				var roll := randf()
				request = "light" if roll < 0.55 else ("heavy" if roll < 0.85 else "kick")
		player.set_controls(axis, false, guard_time > 0.0, false, request)
		player._physics_process(DT)
		cpu._physics_process(DT)
		if player.meter >= 100.0:
			reached_sp = true
	var player_ratio: float = player.health / player.max_health()
	var cpu_ratio: float = cpu.health / cpu.max_health()
	return {"seconds": elapsed, "player_dealt": cpu_start - cpu.health, "cpu_dealt": player_start - player.health, "player_won": player_ratio > cpu_ratio, "reached_sp": reached_sp}


func _guard_rate_against_habit(player, cpu, seconds: float) -> float:
	player.reset_round(-1.85, 999.0, true)
	cpu.reset_round(1.85, 999.0, true)
	# Count every CROSS that connects (blocked or clean) via the game's own signal.
	var tally := {"connected": 0, "guarded": 0}
	var record := func(attacker: int, _defender: int, move: String, blocked: bool, _combo: int):
		if attacker == 0 and move == "heavy":
			tally.connected += 1
			if blocked: tally.guarded += 1
	player.strike_landed.connect(record)
	var cooldown := 0.5
	var elapsed := 0.0
	while elapsed < seconds:
		elapsed += DT
		cooldown -= DT
		var dx: float = cpu.global_position.x - player.global_position.x
		var request := ""
		var axis := signf(dx) if absf(dx) > 1.35 else 0.0
		if cooldown <= 0.0 and absf(dx) <= 1.5:
			request = "heavy"
			cooldown = 0.9
		player.set_controls(axis, false, false, false, request)
		player._physics_process(DT)
		cpu._physics_process(DT)
		player.health = 999.0
		cpu.health = 999.0
	player.strike_landed.disconnect(record)
	_last_habit_samples = int(tally.connected)
	return float(tally.guarded) / maxf(1.0, float(tally.connected))


func _entropy(counts: Dictionary) -> float:
	var total := 0.0
	for key in counts: total += float(counts[key])
	var bits := 0.0
	for key in counts:
		var p := float(counts[key]) / maxf(1.0, total)
		if p > 0.0: bits -= p * log(p) / log(2.0)
	return bits


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
