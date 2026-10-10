extends RefCounted

## Deterministic two-fighter harness for feel and combat tests. Builds a real
## bout through main.gd, then steps both fighters manually at 60 Hz so a run is
## exactly reproducible. Use through `const FightSim = preload(...)`.
## Usage:  var sim = FightSim.new(); await sim.start(tree, root, "bennet", "avigdor")

const DT := 1.0 / 60.0

var main
var player
var enemy


func start(tree: SceneTree, root: Node, player_id: String = "bennet", rival_id: String = "avigdor", player_x: float = -0.55, rival_x: float = 0.55) -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await tree.process_frame
	main.set_process(false)
	main._setup_bout(player_id, rival_id, 1, "SIM QA")
	for i in range(6): await tree.physics_frame
	main.set_physics_process(false)
	player = main.player
	enemy = main.enemy
	for fighter in [player, enemy]:
		fighter.set_physics_process(false)
		fighter.round_over = false
		fighter.is_cpu = false
		fighter.health = 9999.0
	player.reset_round(player_x, 9999.0)
	enemy.reset_round(rival_x, 9999.0)
	for i in range(12): step()


## Advance both fighters one frame with the given player controls; the rival idles.
func step(axis: float = 0.0, jump: bool = false, block: bool = false, crouch: bool = false, attack: String = "", depth: float = 0.0) -> void:
	player.set_controls(axis, jump, block, crouch, attack, depth)
	enemy.set_controls(0.0, false, false, false, "")
	player._physics_process(DT)
	enemy._physics_process(DT)


func steps(count: int, axis: float = 0.0, jump: bool = false, block: bool = false, crouch: bool = false) -> void:
	for i in range(count): step(axis, jump, block, crouch)


func teleport(fighter_x: float, rival_x: float) -> void:
	player.position = Vector3(fighter_x, 0.0, 0.0)
	enemy.position = Vector3(rival_x, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	enemy.velocity = Vector3.ZERO


func cleanup() -> void:
	main.free()
