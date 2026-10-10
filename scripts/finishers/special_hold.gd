extends RefCounted

var active := false
var elapsed := 0.0
var threshold := 0.55

func update(delta: float, pressed: bool, released: bool, eligible: bool) -> String:
	if pressed:
		cancel()
		return "finisher" if eligible else "special"
	return "none"

func cancel() -> void:
	active = false
	elapsed = 0.0
