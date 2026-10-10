extends Control

## Online lobby: create a room (random code) or join a friend's code, then the
## relay pairs the two players and the battle starts with rollback netcode.
## Relay URL comes from data/site_config.json "relay_url" (see docs/online-relay.md).

const WsClient = preload("res://net/ws_client.gd")
const Battle = preload("res://present/battle_view.gd")
const DEFAULT_RELAY := "ws://localhost:9080"

var client: RefCounted
var _url: LineEdit
var _code: LineEdit
var _status: Label


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
	var err: Error = client.connect_to(_url.text.strip_edges(), _code.text)
	_status.text = "Connecting..." if err == OK else "Invalid server address."


func _on_started(player: int, seed_value: int) -> void:
	Battle.pending_online = {"client": client, "player": player, "seed": seed_value}
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


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
