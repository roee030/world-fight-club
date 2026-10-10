extends SceneTree

## Entry point for the dedicated relay server:
##   godot --headless --path . --script res://server/relay_main.gd -- --port 9080
## Hosting notes: docs/online-relay.md

const Relay = preload("res://server/relay.gd")


func _init() -> void:
	var port := 9080
	var args := OS.get_cmdline_user_args()
	for k in range(args.size()):
		if args[k] == "--port" and k + 1 < args.size():
			port = int(args[k + 1])
	if OS.has_environment("PORT"):
		port = int(OS.get_environment("PORT"))
	var relay = Relay.new()
	relay.log_line.connect(func(text: String): print(text))
	root.add_child(relay)
	if relay.start(port) != OK:
		push_error("relay could not listen on %d" % port)
		quit(1)
