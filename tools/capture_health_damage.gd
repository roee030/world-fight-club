extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _frame in range(4):
		await process_frame
	main.selected_stage_id = "knesset_exterior"
	main._setup_bout("bennet", "avigdor", 1, "DAMAGE HUD QA")
	for _frame in range(4):
		await process_frame
	main.round_ready = true
	main.enemy.round_over = false
	main.enemy.invulnerable = 0.0
	main.enemy.receive_hit(32.0, -1.0, "heavy")
	for _frame in range(2):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-health-damage-immediate.png")
	main.enemy_recover_delay = 0.0
	main._update_recoverable_health(0.45)
	for _frame in range(2):
		await process_frame
	get_root().get_texture().get_image().save_png("res://output/ui-health-damage-drained.png")
	main.free()
	quit(0)
