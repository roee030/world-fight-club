extends RefCounted

## Local-only fighters (personal likenesses) that must never be committed.
## Registry: res://private/fighters.json (the whole private/ folder is git-ignored):
##   {"roee": {"name": "ROEE", "callout": "...", "style": "...", "signature": "...",
##             "height_m": 1.80, "finisher_from": "bennet"}}
## Art: res://private/<id>/sprites/<id>-0..11.png, card.png, portrait.png
## (built by tools/build_private_fighter.py). Missing registry = no private fighters,
## so CI and the public build are unaffected.

const REGISTRY := "res://private/fighters.json"
static var _cache = null


static func entries() -> Dictionary:
	if _cache == null:
		_cache = {}
		if FileAccess.file_exists(REGISTRY):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
			if parsed is Dictionary:
				for id in parsed:
					if ResourceLoader.exists(sprite_path(str(id), 0)):
						_cache[str(id)] = parsed[id]
	return _cache


static func ids() -> Array:
	return entries().keys()


static func has(fighter_id: String) -> bool:
	return entries().has(fighter_id)


static func info(fighter_id: String) -> Dictionary:
	return entries().get(fighter_id, {})


static func sprite_path(fighter_id: String, frame: int) -> String:
	return "res://private/%s/sprites/%s-%d.png" % [fighter_id, fighter_id, frame]
