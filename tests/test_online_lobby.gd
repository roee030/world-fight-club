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
	# A remote custom fighter arrives as build data and is rebuilt within the budget.
	var cheat := {"id": "custom_x", "name": "X", "moveset": "rushdown", "custom": true, "model": "user://avatars/x.glb", "points": {"power": 150, "speed": 150, "defense": 150}}
	var sel2: Dictionary = Lobby.online_selection({"fighters": ["atlas", "custom_x"], "defs": [{}, cheat]}, lobby._fighters)
	if sel2.p2.stats.power != 100 or sel2.p2.moveset != "rushdown" or not str(sel2.p2.model).begins_with("res://"):
		return _fail("over-budget remote builds must be reset to standard stats on a base body (%s)" % [sel2.p2])
	var fair := {"id": "custom_y", "name": "Y", "moveset": "zoner", "custom": true, "points": {"power": 150, "speed": 50, "defense": 100}}
	var sel3: Dictionary = Lobby.online_selection({"fighters": ["custom_y", "atlas"], "defs": [fair, {}]}, lobby._fighters)
	if sel3.p1.stats.power != 110 or sel3.p1.name != "Y":
		return _fail("a valid remote build must keep its stats")
	lobby.free()
	print("PASS: online lobby fighter picks (incl. custom fighters, budget enforced)")
	quit()
