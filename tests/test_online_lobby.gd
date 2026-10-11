extends SceneTree

## The online lobby builds, lists the data fighters to pick from, and turns a
## relay start message into the right battle selection (slot order).

const Lobby = preload("res://present/online_lobby.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var lobby = (load("res://scenes/online/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	await process_frame
	if lobby._fighters.size() < 3:
		return _fail("the lobby must offer the data fighters")
	lobby._cycle(1)
	if lobby._pick != 1:
		return _fail("fighter picker must cycle")
	var sel: Dictionary = Lobby.online_selection({"fighters": ["titan", "nova"], "stage": ""}, lobby._fighters)
	if sel.p1.id != "titan" or sel.p2.id != "nova" or sel.stage == "":
		return _fail("start message must map to p1/p2 by slot with a default stage")
	lobby.free()
	print("PASS: online lobby fighter picks")
	quit()
