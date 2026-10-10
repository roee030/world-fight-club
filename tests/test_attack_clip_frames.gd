extends SceneTree

## Punch clips must never show the kick pose. In the 12-frame contract frame 6
## is the signature kick; the heavy "hook" clip once played cross -> kick, so
## one K press looked like a punch and a kick.

const FighterVisualScript = preload("res://scripts/fighter_visual.gd")
const KICK_FRAME := 6
const PUNCH_CLIPS := ["jab", "cross", "hook"]


func _init() -> void:
	for id in FighterVisualScript.TWELVE_FRAME_IDS:
		var clips: Dictionary = FighterVisualScript._clip_map(id)
		for clip in PUNCH_CLIPS:
			if KICK_FRAME in clips[clip]:
				push_error("%s %s clip contains the kick frame: %s" % [id, clip, clips[clip]])
				quit(1)
				return
		if not KICK_FRAME in clips.kick:
			push_error("%s kick clip lost its kick frame" % id)
			quit(1)
			return
	# Every move maps to the intended clip family.
	var moves: Dictionary = load("res://scripts/fighter.gd").MOVES
	if str(moves.light.clip) != "jab" or str(moves.heavy.clip) not in PUNCH_CLIPS or str(moves.kick.clip) != "kick":
		push_error("move-to-clip mapping drifted: %s" % moves)
		quit(1)
		return
	print("PASS: punch clips never show the kick pose")
	quit(0)
