class_name FinisherTimeline
extends RefCounted

var _definition: Dictionary = {}
var _consumed_indices: Dictionary = {}
var _hit_ids := PackedStringArray()
var _time := 0.0
var _duration := 0.0
var _paused := false
var _finished := true
var _event_key := ""

func start(definition: Dictionary) -> void:
	_definition = definition.duplicate(true)
	_consumed_indices.clear()
	_hit_ids = PackedStringArray()
	_time = 0.0
	_duration = maxf(0.0, float(_definition.get("duration", 0.0)))
	_paused = false
	_finished = false
	_event_key = ""

func advance(delta: float) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	if _paused or _finished or delta < 0.0 or not is_finite(delta):
		return emitted
	_time = minf(_duration, _time + delta)
	var events: Array = _definition.get("events", [])
	# Catalog validation guarantees ascending times. Scan source indices so
	# equal-time cues remain ordered and a hitch cannot skip any cue.
	for index in range(events.size()):
		if _consumed_indices.has(index):
			continue
		var event: Dictionary = events[index]
		if float(event.get("at", 0.0)) > _time:
			continue
		_consumed_indices[index] = true
		var event_type := str(event.get("type", ""))
		var hit_id := str(event.get("id", "")) if event_type == "hit" else ""
		if not hit_id.is_empty():
			if _hit_ids.has(hit_id):
				continue
			_hit_ids.append(hit_id)
		_event_key = hit_id if not hit_id.is_empty() else "%s:%d" % [event_type, index]
		emitted.append(event.duplicate(true))
	_finished = _time >= _duration
	return emitted

func set_paused(paused: bool) -> void:
	_paused = paused

func cancel() -> void:
	_definition.clear()
	_consumed_indices.clear()
	_hit_ids = PackedStringArray()
	_event_key = ""
	_paused = false
	_finished = true

func is_finished() -> bool:
	return _finished

func elapsed() -> float:
	return _time

func current_event_key() -> String:
	return _event_key

func consumed_hit_ids() -> PackedStringArray:
	return _hit_ids.duplicate()
