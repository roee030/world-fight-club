extends Control

## Online lobby: create a room (random code) or join a friend's code, then the
## relay pairs the two players and the battle starts with rollback netcode.
## Relay URL comes from data/site_config.json "relay_url" (see docs/online-relay.md).

const WsClient = preload("res://net/ws_client.gd")
const Battle = preload("res://present/battle_view.gd")
const Loader = preload("res://content/character_loader.gd")
const Builder = preload("res://meta/fighter_builder.gd")
const DEFAULT_RELAY := "ws://localhost:9080"

var client: RefCounted
var _url: LineEdit
var _code: LineEdit
var _status: Label
var _fighters: Array = []
var _pick := 0
var _pick_label: Label
var _team_mode := false
var _mode_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#0b1220")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260
	box.offset_right = 260
	box.offset_top = -220
	box.offset_bottom = 220
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(_text("ONLINE MATCH  ·  BETA", 34))
	box.add_child(_text("Play a friend anywhere. Rollback netcode keeps it smooth.", 15))
	box.add_child(_text("SERVER", 13))
	_url = LineEdit.new()
	_url.text = _configured_relay()
	box.add_child(_url)
	_fighters = Loader.fighter_definitions()
	box.add_child(_text("YOUR FIGHTER", 13))
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 10)
	box.add_child(pick_row)
	pick_row.add_child(_button("<", func(): _cycle(-1)))
	_pick_label = _text("", 24)
	_pick_label.custom_minimum_size = Vector2(260, 0)
	pick_row.add_child(_pick_label)
	pick_row.add_child(_button(">", func(): _cycle(1)))
	_cycle(0)
	_mode_button = _button("MODE: 1 VS 1", func(): _team_mode = not _team_mode; _mode_button.text = "MODE: 2 VS 2 (4 PLAYERS)" if _team_mode else "MODE: 1 VS 1")
	box.add_child(_mode_button)
	box.add_child(_text("ROOM CODE", 13))
	_code = LineEdit.new()
	_code.text = _random_code()
	_code.max_length = 8
	_code.add_theme_font_size_override("font_size", 28)
	box.add_child(_code)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_button("CREATE ROOM", _on_create))
	row.add_child(_button("JOIN ROOM", _on_join))
	row.add_child(_button("BACK", _on_back))
	_status = _text("Share the room code with your friend, then both press a button.", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)


func _process(_delta: float) -> void:
	if client != null:
		client.poll()


func _on_create() -> void:
	_code.text = _random_code()
	_connect()


func _on_join() -> void:
	_connect()


func _on_back() -> void:
	if client != null:
		client.close()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _connect() -> void:
	if client != null:
		client.close()
	client = WsClient.new()
	client.waiting.connect(func(): _status.text = "Room %s is open. Waiting for your friend..." % _code.text.to_upper())
	client.failed.connect(func(reason: String): _status.text = "Connection problem: %s" % reason)
	client.started.connect(_on_started)
	client.room_size = 4 if _team_mode else 2
	if not _fighters.is_empty():
		client.fighter_def = shareable_def(_fighters[_pick])
	var err: Error = client.connect_to(_url.text.strip_edges(), _code.text, str(_fighters[_pick].id) if not _fighters.is_empty() else "atlas", "res://assets/stages/kaplan-junction-arena.jpg")
	_status.text = "Connecting..." if err == OK else "Invalid server address."


func _on_started(player: int, seed_value: int) -> void:
	Battle.pending_online = {"client": client, "player": player, "seed": seed_value}
	Battle.pending_selection = online_selection(client.last_start, _fighters)
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


## What a player's fighter looks like to the opponent: build data only. A model
## that lives in this player's user:// folder cannot be sent, so the other side
## shows the matching base body instead.
static func shareable_def(def: Dictionary) -> Dictionary:
	var out := {"id": str(def.get("id", "atlas")), "name": str(def.get("name", "FIGHTER")).left(16), "archetype": str(def.get("archetype", "all-rounder")),
		"moveset": str(def.get("moveset", "universal")), "tint": def.get("tint", [1, 1, 1]), "custom": bool(def.get("custom", false))}
	var model := str(def.get("model", ""))
	out["model"] = model if model.begins_with("res://") else Builder.BASE_MODELS[0][1]
	if def.has("points"): out["points"] = def.points
	return out


## A remote custom fighter is rebuilt from its points, so stats can never exceed the budget.
static func sanitize_remote(def: Dictionary) -> Dictionary:
	var points: Dictionary = def.get("points", {})
	var power := int(points.get("power", 100))
	var speed := int(points.get("speed", 100))
	var defense := int(points.get("defense", 100))
	if not Builder.is_valid_split(power, speed, defense):
		power = 100
		speed = 100
		defense = 100
	var arch_index := 0
	for k in range(Builder.ARCHETYPES.size()):
		if Builder.ARCHETYPES[k][1] == str(def.get("moveset", "universal")):
			arch_index = k
	var model := str(def.get("model", ""))
	if not model.begins_with("res://") or not ResourceLoader.exists(model):
		model = Builder.BASE_MODELS[0][1]
	var tint_raw: Array = def.get("tint", [1, 1, 1])
	var tint := Color(float(tint_raw[0]), float(tint_raw[1]), float(tint_raw[2])) if tint_raw.size() >= 3 else Color.WHITE
	var rebuilt: Dictionary = Builder.build_def(str(def.get("name", "RIVAL")), arch_index, model, tint, power, speed, defense)
	rebuilt["id"] = str(def.get("id", rebuilt.id))
	return rebuilt


## Builds the battle selection from the relay's start message (slot order).
static func online_selection(start: Dictionary, fighters: Array) -> Dictionary:
	var picks: Array = start.get("fighters", ["atlas", "nova"])
	var shared: Array = start.get("defs", [{}, {}])
	var defs := []
	for slot in range(picks.size()):
		var id := str(picks[slot])
		var found: Dictionary = {}
		for def in fighters:
			if str(def.id) == id and not bool(def.get("custom", false)):
				found = def
		var remote: Dictionary = shared[slot] if slot < shared.size() and shared[slot] is Dictionary else {}
		if found.is_empty() and bool(remote.get("custom", false)):
			found = sanitize_remote(remote)
			# Our own custom fighter keeps its local avatar model; stats come from the
			# same points on both machines, so the match stays identical.
			for def in fighters:
				if str(def.id) == id and bool(def.get("custom", false)) and def.get("points", {}) == remote.get("points", {}):
					found["model"] = str(def.get("model", found.model))
		if found.is_empty():
			found = fighters[0] if not fighters.is_empty() else {}
		defs.append(found)
	var stage := str(start.get("stage", ""))
	var sel := {"p1": defs[0], "p2": defs[1], "stage": stage if stage != "" else "res://assets/stages/kaplan-junction-arena.jpg"}
	if defs.size() >= 4:
		# 2v2 slots: 0 and 2 are one team, 1 and 3 the other (sim order p1, p2, p1b, p2b).
		sel["p1b"] = defs[2]
		sel["p2b"] = defs[3]
		sel["team"] = true
	return sel


func _cycle(step: int) -> void:
	if _fighters.is_empty():
		return
	_pick = wrapi(_pick + step, 0, _fighters.size())
	_pick_label.text = "%s  ·  %s" % [_fighters[_pick].name, str(_fighters[_pick].get("archetype", "")).to_upper()]


static func _configured_relay() -> String:
	var path := "res://data/site_config.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and str(parsed.get("relay_url", "")) != "":
			return str(parsed.relay_url)
	return DEFAULT_RELAY


static func _random_code() -> String:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for k in range(4):
		code += letters[randi() % letters.length()]
	return code


func _text(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(160, 52)
	button.pressed.connect(action)
	return button
