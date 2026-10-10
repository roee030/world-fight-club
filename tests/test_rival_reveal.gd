extends SceneTree

# Quick Fight CONFIRM FIGHT shuffles roster faces through the CPU frame, lands
# on the random rival, opens the arena select, and that rival is the one fought.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sequence: Array[String] = main.rival_reveal_sequence("trump", "bibi", 22, rng)
	if sequence.size() != 22 or sequence[-1] != "trump":
		return _fail("reveal sequence must end on the chosen rival")
	for i in range(sequence.size()):
		if sequence[i] == "bibi":
			return _fail("reveal shuffle must never show the player's own fighter")
		if i > 0 and sequence[i] == sequence[i - 1]:
			return _fail("reveal shuffle repeats the same face twice in a row")

	main._open_select("quick")
	main._select_fighter("bibi")
	main.rival_reveal_animated = true
	main._confirm_selection()
	if not main.rival_reveal_active or not main.select_root.visible or main.map_select_root.visible:
		return _fail("CONFIRM FIGHT must play the rival shuffle on the select screen first")
	var rival: String = main.pending_rival_id
	if rival.is_empty() or rival == "bibi":
		return _fail("reveal picked no valid rival")
	if (main.select_root.find_child("MysteryCpuMark", true, false) as CanvasItem).visible:
		return _fail("the mystery mark must hide while faces shuffle")
	# Shuffled faces use the same card art as the final reveal.
	var shuffle_art := main.select_rival_portrait.texture as Texture2D
	if shuffle_art == null or not shuffle_art.resource_path.ends_with("-card.png"):
		return _fail("shuffle must flick through the fighter card art, not the face thumbnails")
	main._select_fighter("trump")
	main._confirm_selection()
	if main.selecting != "bibi" or main.pending_rival_id != rival:
		return _fail("input during the shuffle must not change the pick")

	var waited := 0.0
	while main.rival_reveal_active and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	if main.rival_reveal_active or not main.map_select_root.visible:
		return _fail("shuffle did not finish into the arena select")
	if main.select_rival_name.text != main._fighter_name(rival).to_upper():
		return _fail("revealed name does not match the chosen rival")
	if main.select_rival_portrait.texture != main._fighter_art(rival):
		return _fail("revealed art does not match the chosen rival's card")

	main._start_selected_mode()
	if main.current_rival_id != rival:
		return _fail("Quick Fight did not use the revealed rival")
	if not main.pending_rival_id.is_empty():
		return _fail("revealed rival must be consumed by the fight")

	main._show_menu()
	if main.select_rival_name.text != "RANDOM OPPONENT":
		return _fail("returning to the menu must reset the mystery rival slot")

	main.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
