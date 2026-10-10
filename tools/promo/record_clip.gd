extends SceneTree
## Records one real gameplay clip for the promo trailer (Godot Movie Maker).
##
## godot --path . --script tools/promo/record_clip.gd --write-movie out.avi \
##   --fixed-fps 60 --resolution 1920x1080 -- --player=bibi --rival=trump ...
## The player side is driven by the CPU brain (main.promo_autopilot); nothing in
## combat rules is changed. Options: player, rival, stage, level, seconds,
## meter, meter_at, rival_hp, seed.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var o := {"player": "bibi", "rival": "yair_lapid", "stage": "knesset_exterior", "level": "2", "seconds": "8", "meter": "0", "meter_at": "0", "rival_hp": "100", "seed": "1", "finisher": "true", "mode": "fight", "rounds": "0"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			o[parts[0]] = parts[1]
	seed(int(o.seed))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in range(3): await process_frame
	var sys = main.find_child("SystemButtons", true, false)
	main.audio_manager.set_muted(false, false)
	main.audio_manager.set_focus_muted(false)
	# Clips keep SFX and announcer only; the trailer adds its own music bed.
	main.audio_manager.set_volume(&"music", 0.0, false)
	if o.mode == "campaign":
		await _record_campaign(main, o)
		quit(0)
		return
	main.selected_stage_id = o.stage
	main._setup_bout(o.player, o.rival, int(o.level), "")
	main._tutorial_pending = false
	if int(o.rounds) > 0:
		main.player_rounds = int(o.rounds)
		main._update_scores()
	main.promo_autopilot = true
	# Trailer-clean HUD: no system buttons. Audio on for this run only (not saved).
	if sys: sys.visible = false
	main.promo_allow_finisher = o.finisher == "true"
	main.promo_autopilot_level = 4
	var frames := int(float(o.seconds) * 60.0)
	var meter_frame := int(float(o.meter_at) * 60.0)
	for f in range(frames):
		if f == meter_frame and float(o.meter) > 0.0:
			main.player.meter = float(o.meter)
			main._on_meter_changed(0, main.player.meter)
		if f == meter_frame and float(o.rival_hp) < 100.0 and is_instance_valid(main.enemy):
			main.enemy.health = main.enemy.max_health() * float(o.rival_hp) / 100.0
			main._on_health_changed(1, main.enemy.health)
		await process_frame
	quit(0)


func _record_campaign(main, o: Dictionary) -> void:
	# The real Road to the Knesset screen: the ladder fills up rival by rival
	# until the final boss is next.
	main.selecting = o.player
	main._start_campaign()
	var total: int = main.campaign_ladder.size()
	var frames := int(float(o.seconds) * 60.0)
	var first := 1
	var steps := total - first
	for f in range(frames):
		var idx := first + mini(steps - 1, int(float(f) / float(frames) * float(steps) * 1.15))
		if idx != main.campaign_index:
			main.campaign_index = idx
			main._show_campaign_progress()
		await process_frame
