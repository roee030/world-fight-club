extends SceneTree

## Fairness matrix: CPU vs CPU across every archetype pairing on the pure sim.
## Every match must finish (KO or time-out, no stuck states) and no archetype
## may dominate another: each side of a pairing wins between 15% and 85%.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")
const CpuPilot = preload("res://ai/cpu_pilot.gd")
const MATCHES := 24
const FIGHTERS := {
	"universal": {"hp": 10000, "walk": 541},
	"rushdown": {"hp": 9800, "walk": 590},
	"grappler": {"hp": 11500, "walk": 470},
	"zoner": {"hp": 9200, "walk": 520},
}


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var ms = Moveset.compile(["res://data/movesets/universal.json", "res://data/movesets/rushdown.json", "res://data/movesets/grappler.json", "res://data/movesets/zoner.json"])
	var names: Array = FIGHTERS.keys()
	var report: Array[String] = []
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var wins := [0, 0]
			for m in range(MATCHES):
				# Alternate sides so spawn position cannot bias the result.
				var swap := m % 2 == 1
				var a: String = names[j] if swap else names[i]
				var b: String = names[i] if swap else names[j]
				var result := _play(ms, a, b, 1000 + m * 17 + i * 101 + j * 7)
				if result < 0:
					return _fail("%s vs %s match %d did not finish" % [a, b, m])
				if result < 2:
					var winner_name: String = [a, b][result]
					wins[0 if winner_name == names[i] else 1] += 1
			var share := float(wins[0]) / maxf(1.0, float(wins[0] + wins[1]))
			report.append("%s %d - %d %s" % [names[i], wins[0], wins[1], names[j]])
			if share < 0.15 or share > 0.85:
				return _fail("unbalanced pairing: %s" % report[-1])
	print("BALANCE: " + ", ".join(report))
	print("PASS: archetype fairness matrix")
	quit()


## Returns the winning side (0/1), 2 for a draw, -1 if the match never ended.
func _play(ms, a: String, b: String, seed_value: int) -> int:
	var s := Sim.new_match(ms, [
		{"x": -16000, "hp": FIGHTERS[a].hp, "walk": FIGHTERS[a].walk, "archetype": a, "easy": true},
		{"x": 16000, "hp": FIGHTERS[b].hp, "walk": FIGHTERS[b].walk, "archetype": b, "easy": true}], seed_value, {"rounds_to_win": 1})
	var cpus := [CpuPilot.new(3, seed_value), CpuPilot.new(3, seed_value + 1)]
	for f in range(int(ms.rules.round_frames) + 400):
		Sim.step(ms, s, PackedInt32Array([cpus[0].decide(s, 0, ms), cpus[1].decide(s, 1, ms)]))
		if s[L.H_MATCH_OVER] != 0 or (s[L.H_WINNER] >= 0 and s[L.H_ROUNDS_TO_WIN] <= 1):
			var w := s[L.H_WINNER]
			return w if w < 2 else 2
	return -1
