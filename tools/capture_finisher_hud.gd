extends SceneTree

class PreviewHost extends "res://scripts/main.gd":
	func _finisher_eligible() -> bool:
		return true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/finisher-review")
	var main := PreviewHost.new()
	get_root().add_child(main)
	main._setup_bout("bennet", "avigdor", 1, "FINISHER HUD PREVIEW")
	main.set_physics_process(false)
	main.enemy.set_physics_process(false)
	main.player.set_physics_process(false)
	main.match_state = main.MatchState.Value.FIGHTING
	main.player.meter = 100.0
	main._on_meter_changed(0, 100.0)
	for resolution in [Vector2i(1280, 720), Vector2i(844, 390)]:
		get_root().size = resolution
		main._cancel_special_hold()
		main._update_special_hold(0.0, false, false)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://output/finisher-review/hud-ready-%d.png" % resolution.x)
		main._update_special_hold(0.2, true, false)
		main._update_special_hold(0.2, false, false)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://output/finisher-review/hud-hold-%d.png" % resolution.x)
	main.free()
	quit(0)
