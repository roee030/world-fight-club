extends SceneTree

func _init() -> void:
	if not FileAccess.file_exists("res://scripts/finishers/finisher_timeline.gd"):
		push_error("FAIL: deterministic finisher timeline is missing")
		quit(1)
		return
	var script = load("res://scripts/finishers/finisher_timeline.gd")
	var timeline = script.new()
	var definition := {"duration": 2.0, "events": [
		{"at": 0.0, "type": "portrait_lightbox", "options": {"strength": 1}},
		{"at": 0.5, "type": "hit", "id": "opening", "damage": 5},
		{"at": 0.5, "type": "camera_impact"},
		{"at": 1.0, "type": "hit", "id": "final", "damage": 999},
		{"at": 2.0, "type": "cleanup"}]}
	timeline.start(definition)
	assert(not timeline.is_finished())
	assert(timeline.current_event_key() == "")
	var first: Array = timeline.advance(0.0)
	assert(first.size() == 1 and first[0].type == "portrait_lightbox")
	assert(timeline.current_event_key() == "portrait_lightbox:0")
	assert(timeline.advance(0.0).is_empty(), "Zero delta must not replay start events")
	definition.events[1].id = "mutated"
	first[0].options.strength = 99
	assert(definition.events[0].options.strength == 1, "Emitted nested data must be isolated")
	timeline.set_paused(true)
	assert(timeline.advance(0.5).is_empty())
	assert(timeline.elapsed() == 0.0)
	timeline.set_paused(false)
	var at_hit: Array = timeline.advance(0.5)
	assert(at_hit.size() == 2 and at_hit[0].id == "opening" and at_hit[1].type == "camera_impact", "Equal timestamps retain source order")
	assert(timeline.current_event_key() == "camera_impact:2")
	assert(timeline.consumed_hit_ids() == PackedStringArray(["opening"]))
	timeline.set_paused(true)
	assert(timeline.advance(4.0).is_empty())
	assert(timeline.elapsed() == 0.5)
	timeline.set_paused(false)
	assert(timeline.advance(0.0).is_empty())
	var hitch: Array = timeline.advance(10.0)
	assert(hitch.size() == 2 and hitch[0].id == "final" and hitch[1].type == "cleanup")
	assert(timeline.is_finished() and timeline.elapsed() == 2.0)
	assert(timeline.consumed_hit_ids() == PackedStringArray(["opening", "final"]))
	assert(timeline.advance(10.0).is_empty())
	timeline.start({"duration": 3.0, "events": [{"at": 0.1, "type": "hit", "id": "one"}, {"at": 0.2, "type": "hit", "id": "one"}, {"at": 0.3, "type": "caption"}]})
	var crossed: Array = timeline.advance(0.5)
	assert(crossed.size() == 2 and crossed[0].id == "one" and crossed[1].type == "caption", "Hitch crosses every event while duplicate hit IDs apply once")
	assert(not timeline.is_finished(), "Last event does not end authored duration")
	timeline.cancel()
	assert(timeline.is_finished() and timeline.advance(9.0).is_empty())
	assert(timeline.current_event_key() == "" and timeline.consumed_hit_ids().is_empty(), "Cancel clears sequence bookkeeping")
	timeline.start({"duration": 1.0, "events": []})
	assert(timeline.elapsed() == 0.0 and timeline.advance(-1.0).is_empty())
	assert(timeline.elapsed() == 0.0 and not timeline.is_finished())
	timeline.advance(1.0)
	assert(timeline.is_finished())
	print("PASS: deterministic finisher timeline order, hitch, pause, cancellation and data isolation")
	quit(0)
