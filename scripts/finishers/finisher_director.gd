class_name FinisherDirector
extends Node

signal sequence_started(attacker_id: String)
signal final_hit(defender_index: int)
signal celebration_started(id: String)
signal result_ready(winner_index: int)
signal cancelled(reason: String)
## Emitted when a match finisher ends without a celebration: the rival survived
## the damage budget, or the KO only ended a round.
signal sequence_finished(lethal: bool)

var catalog: Variant
const TimelineScript = preload("res://scripts/finishers/finisher_timeline.gd")
const ActorScript = preload("res://scripts/finishers/finisher_actor.gd")
const SuperMoveCardScript = preload("res://scripts/ui/super_move_card.gd")
const CalloutScript = preload("res://scripts/ui/callout.gd")
var timeline := TimelineScript.new()
var active := false
var diagnostic := ""
var reduced_motion := false
var effect_density := "desktop"
var force_opening_miss := false
var _opening_miss := false
var _host: Node
var _arena: Node3D
var _camera: Camera3D
var _camera_transform := Transform3D.IDENTITY
var _camera_size := 1.0
var _camera_fov := 30.0
var _camera_mode := "wide_stage"
var _fighter_art: Dictionary = {}
var _attacker: GameFighter
var _defender: GameFighter
var _definition: Dictionary
var _actors: Dictionary = {}
var _presentation: Array[Node] = []
var _paused := false
var _final := false
var _celebrating := false
var _lightbox := false
var _hit_ids := PackedStringArray()
var _impact_remaining := 0.0
var _impact_origin := Vector3.ZERO
var _lifetimes: Dictionary = {}
var _clocks: Array[Dictionary] = []
# Match finishers carry a damage budget (a share of the rival's max HP). Without
# one (Fight Lab previews) the final hit keeps the authored always-lethal rule.
var _damage_budget := 0.0
var _celebrate_on_lethal := true
var _dealt := 0.0
var _lethal := false
# The card owns the opening beat: authored finisher events begin only after it
# has left the screen, so the first hit can never happen behind the lightbox.
var _super_card_hold_remaining := 0.0

func configure(host: Node, arena: Node3D, camera: Camera3D) -> void:
	_host = host
	_arena = arena
	_camera = camera

func begin(attacker: GameFighter, defender: GameFighter, definition: Dictionary, opening_in_range: bool = true) -> bool:
	if active or attacker == null or defender == null or defender.health <= 0 or not definition.get("implemented", false): return false
	var cost := float(definition.get("meter_cost", 100))
	if attacker.meter < cost: return false
	var celebration := _celebration(str(definition.get("celebration_id", "")))
	if celebration.is_empty(): return false
	_attacker = attacker
	_defender = defender
	_definition = definition.duplicate(true)
	_final = false
	_celebrating = false
	_lightbox = false
	_hit_ids.clear()
	_paused = false
	_damage_budget = maxf(0.0, float(definition.get("damage_budget", 0.0)))
	_celebrate_on_lethal = bool(definition.get("celebrate_on_lethal", true))
	_dealt = 0.0
	_lethal = false
	_super_card_hold_remaining = 0.0
	_opening_miss = force_opening_miss or not opening_in_range
	active = true
	diagnostic = ""
	if _camera:
		_camera_transform = _camera.transform
		_camera_size = _camera.size
		_camera_fov = _camera.fov
	var direction := 1.0 if defender.position.x >= attacker.position.x else -1.0
	if _opening_miss:
		attacker.enter_cinematic_lock(attacker.position, direction)
		defender.enter_cinematic_lock(defender.position, -direction)
	else:
		var midpoint := clampf((attacker.position.x + defender.position.x) * 0.5, -3.8, 3.8)
		attacker.enter_cinematic_lock(Vector3(midpoint - direction * 0.8, 0, 0), direction)
		defender.enter_cinematic_lock(Vector3(midpoint + direction * 0.8, 0, 0), -direction)
	attacker.meter -= cost
	attacker.meter_changed.emit(attacker.who, attacker.meter)
	timeline.start(_definition)
	_camera_preset(str(_definition.get("camera_preset", "wide_stage")))
	sequence_started.emit(attacker.character_id)
	return true


func begin_celebration(winner: GameFighter, loser: GameFighter, celebration_id: String) -> bool:
	if active or winner == null or loser == null:
		return false
	var celebration := _celebration(celebration_id)
	if celebration.is_empty() or not celebration.get("implemented", false):
		return false
	_attacker = winner
	_defender = loser
	_definition = {"celebration_id": celebration_id}
	_final = true
	_celebrating = true
	_lightbox = false
	_hit_ids.clear()
	_paused = false
	_super_card_hold_remaining = 0.0
	active = true
	diagnostic = ""
	if _camera:
		_camera_transform = _camera.transform
		_camera_size = _camera.size
		_camera_fov = _camera.fov
	winner.enter_cinematic_lock(winner.position, winner.facing)
	loser.enter_defeated_cinematic_lock(loser.position, loser.facing)
	timeline.start(celebration)
	celebration_started.emit(celebration_id)
	return true

func last_sequence_lethal() -> bool:
	return _lethal


func is_celebrating() -> bool:
	return active and _celebrating

func _celebration(id: String) -> Dictionary:
	var source = catalog
	if source == null and _host != null: source = _host.get("_finisher_catalog")
	if source is Dictionary: return source.get(id, {}).duplicate(true)
	if source != null and source.has_method("celebration_for"): return source.celebration_for(id)
	return {}

func advance(delta: float) -> void:
	if not active or _paused: return
	for actor in _actors.values(): actor.advance(delta)
	for node in _presentation:
		if is_instance_valid(node) and node.has_method("advance"): node.advance(delta)
	for node in _lifetimes.keys():
		_lifetimes[node] -= delta
		if _lifetimes[node] <= 0:
			_lifetimes.erase(node)
			_presentation.erase(node)
			node.free()
	for clock in _clocks:
		clock.elapsed = minf(clock.duration, clock.elapsed + delta)
		var seconds := int(lerpf(clock.from, clock.to, clock.elapsed / maxf(clock.duration, 0.001)))
		clock.label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if _impact_remaining > 0 and _camera:
		_impact_remaining = maxf(0, _impact_remaining - delta)
		if _impact_remaining == 0: _camera.position = _impact_origin
	var timeline_delta := delta
	if _super_card_hold_remaining > 0.0:
		if timeline_delta <= _super_card_hold_remaining:
			_super_card_hold_remaining -= timeline_delta
			return
		timeline_delta -= _super_card_hold_remaining
		_super_card_hold_remaining = 0.0
	var was_celebrating := _celebrating
	for event in timeline.advance(timeline_delta):
		if not active: break
		_dispatch(event)
		if _celebrating != was_celebrating: break
	if active and timeline.is_finished():
		_fail("Timeline ended without a celebration or result marker")

func _dispatch(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"hit":
			if _celebrating or _final: return
			if _hit_ids.is_empty() and _opening_miss:
				_fail("Opening missed")
				return
			var id := str(event.get("id", ""))
			if id.is_empty():
				_fail("Authored hit has no event ID")
				return
			if _hit_ids.has(id): return
			var ending := bool(event.get("final", false))
			var damage := float(event.get("damage", 0))
			if ending and _damage_budget > 0.0: damage = maxf(1.0, _damage_budget - _dealt)
			elif ending: damage = maxf(damage, _defender.health)
			else: damage = minf(damage, maxf(0, _defender.health - 1))
			if not ending and damage <= 0 and _defender.health > 0:
				_hit_ids.append(id)
				return
			if not _defender.apply_authored_hit(id, damage, _attacker.facing, str(event.get("reaction", "hit"))):
				_fail("Authored hit rejected: " + id)
				return
			_hit_ids.append(id)
			_dealt += damage
			if ending:
				_final = true
				_lethal = _defender.health <= 0.0
				final_hit.emit(_defender.who)
		"celebration_start":
			if not _final or _celebrating:
				_fail("Celebration requires one final hit")
				return
			if _damage_budget > 0.0 and not (_lethal and _celebrate_on_lethal):
				var lethal := _lethal
				cancel()
				sequence_finished.emit(lethal)
				return
			_cleanup_presentation()
			_restore_fight_camera()
			_celebrating = true
			var id := str(_definition.get("celebration_id", ""))
			timeline.start(_celebration(id))
			celebration_started.emit(id)
		"result_marker":
			if not _celebrating or not _final:
				_fail("Result marker outside celebration")
				return
			var winner := _attacker.who
			cancel()
			result_ready.emit(winner)
		"spawn_actor", "spawn_prop":
			var id := str(event.get("id", event.get("asset", "")))
			if _actors.has(id):
				_fail("Duplicate actor ID: " + id)
				return
			if effect_density == "mobile" and _actors.size() >= 12: return
			var actor := ActorScript.new()
			var actor_data := event.duplicate(true)
			if event.get("anchor", "") in ["attacker", "defender"]:
				var offset := ActorScript.vector_from(event.get("position", [0, 0, 0]))
				offset.x *= _attacker.facing
				actor_data.position = offset
				actor_data.facing = float(event.get("facing", 1.0)) * (_attacker.facing if event.get("mirror_facing", true) else 1.0)
			if not actor.configure(actor_data):
				actor.free()
				_fail("Missing or invalid transparent actor resource: " + str(event.get("asset", "")))
				return
			_arena.add_child(actor)
			if event.get("anchor", "") == "attacker":
				actor.position += _attacker.position
			elif event.get("anchor", "") == "defender":
				actor.position += _defender.position
			actor.reduced_motion = reduced_motion
			_actors[id] = actor
		"move_actor", "launch_prop":
			var id := str(event.get("id", event.get("actor", "")))
			if not _actors.has(id):
				_fail("Motion references missing actor: " + id)
				return
			var target := ActorScript.vector_from(event.get("position", [0, 0, 0]))
			if event.get("anchor", "") in ["attacker", "defender"]:
				target.x *= _attacker.facing
				target += _attacker.position if event.anchor == "attacker" else _defender.position
			elif event.get("target", "") == "defender": target = _defender.position + Vector3(0, 1, 0)
			_actors[id].move_to(target, float(event.get("duration", 0.3)), reduced_motion)
		"fighter_clip", "defender_reaction":
			var fighter := _defender if event.get("target", "attacker") == "defender" or event.type == "defender_reaction" else _attacker
			if not fighter._visual.is_empty():
				if event.has("asset"):
					if not _set_fighter_art(fighter, event):
						_fail("Invalid authored fighter pose")
					return
				var clip := str(event.get("clip", event.get("reaction", "idle")))
				if fighter._visual.sprite.sprite_frames.has_animation(clip): fighter._visual.sprite.play(clip)
				fighter._visual.motion.play_state(clip, false, float(event.get("duration", 0.0)))
		"portrait_lightbox":
			if _lightbox:
				_fail("Duplicate portrait lightbox")
				return
			_lightbox = true
			_super_card()
		"caption":
			var label := _caption(str(event.get("text", "")), false)
			if event.get("ui_position") is Array and event.ui_position.size() == 2:
				label.position = Vector2(event.ui_position[0], event.ui_position[1])
			if event.has("clock_from"):
				_clocks.append({"label": label, "from": float(event.clock_from), "to": float(event.get("clock_to", 0)), "elapsed": 0.0, "duration": float(event.get("duration", 1))})
		"sound":
			var path := str(event.get("asset", ""))
			var stream = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
			if not stream is AudioStream:
				_fail("Missing sound: " + path)
				return
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.bus = &"SFX"
			add_child(player)
			_presentation.append(player)
			player.play()
		"camera_preset": _camera_preset(str(event.get("preset", "wide_stage")))
		"camera_impact":
			if _camera and not reduced_motion:
				if _impact_remaining > 0: _camera.position = _impact_origin
				_impact_origin = _camera.position
				_impact_remaining = 0.12
				_camera.position.x += minf(float(event.get("strength", 0.2)), 0.12 if effect_density == "mobile" else 0.3)
		"screen_flash":
			if not reduced_motion: _caption("", false, true)
		"cleanup": _cleanup_presentation()
		_: _fail("Unknown finisher event: " + str(event.get("type", "")))

func _camera_preset(preset: String) -> void:
	# Every preset keeps the fight framing. The stage art is a camera-attached
	# backplate, so zooming or panning lifted fighters off the painted floor and
	# produced a visible zoom-in / zoom-out jump around the super-move card.
	# Drama comes from the overlay card, flashes and impact shake instead.
	if not _camera: return
	if not preset in ["close_side", "wide_stage", "overhead_pass", "projectile_track", "victory_low"]:
		_fail("Unknown camera preset: " + preset)
		return
	_camera_mode = preset
	_camera.transform = _camera_transform
	_camera.size = _camera_size
	_camera.fov = _camera_fov


func _restore_fight_camera() -> void:
	# Celebrations play in the fight framing so fighters stay on the painted
	# floor of the camera-attached stage backplate.
	if not _camera: return
	_camera_mode = "wide_stage"
	_camera.transform = _camera_transform
	_camera.size = _camera_size
	_camera.fov = _camera_fov


func _set_fighter_art(fighter: GameFighter, event: Dictionary) -> bool:
	var texture = ResourceLoader.load(str(event.asset))
	if not texture is Texture2D:
		return false
	if event.get("region") is Array and event.region.size() == 4:
		var crop := AtlasTexture.new()
		crop.atlas = texture
		crop.region = Rect2(event.region[0], event.region[1], event.region[2], event.region[3])
		texture = crop
	var sprite: AnimatedSprite3D = fighter._visual.sprite
	if not _fighter_art.has(fighter):
		_fighter_art[fighter] = {"frames": sprite.sprite_frames, "pixel_size": sprite.pixel_size, "position": sprite.position}
	var frames := SpriteFrames.new()
	frames.add_animation("authored")
	frames.set_animation_loop("authored", false)
	frames.add_frame("authored", texture)
	sprite.sprite_frames = frames
	var geometry: Dictionary = fighter._visual.geometry.duplicate(true)
	geometry.frame_height_px = texture.get_height()
	geometry.figure_height_px = float(event.get("figure_height_px", texture.get_height()))
	geometry.foot_baseline_px = float(event.get("foot_baseline", texture.get_height()))
	geometry.pixel_size = float(geometry.height_m) * float(geometry.pixel_scale) / maxf(1.0, geometry.figure_height_px)
	sprite.pixel_size = geometry.pixel_size
	sprite.position.y = FighterVisual.ground_y_from_geometry(geometry)
	sprite.play("authored")
	return true

func _super_card() -> CanvasLayer:
	# Full-screen super-move card (fighter art + electric finisher name).
	var id := _attacker.character_id
	# Optional illustrated art, else the fighter's transparent cross-punch pose
	# (frame 5 of the 12-frame contract). The roster cards have an opaque
	# background and looked like a pasted box on the effects.
	var art_path := "res://assets/finishers/%s/super-card.png" % id
	var illustrated := ResourceLoader.exists(art_path)
	if not illustrated:
		art_path = "res://assets/characters/sprites/%s-5.png" % id
	var art = ResourceLoader.load(art_path) if ResourceLoader.exists(art_path) else null
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 1.1
	font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.28, 1), Vector2.ZERO)
	var card = SuperMoveCardScript.new()
	card.reduced_motion = reduced_motion
	card.dense_effects = effect_density != "mobile"
	var fighter_name := str(_host.call("_fighter_name", id)) if _host != null and _host.has_method("_fighter_name") else id.replace("_", " ")
	card.setup(fighter_name, SuperMoveCardScript.display_name_for(_definition), art as Texture2D, font, not illustrated)
	add_child(card)
	_presentation.append(card)
	_lifetimes[card] = SuperMoveCardScript.DURATION
	_super_card_hold_remaining = SuperMoveCardScript.DURATION
	if _host != null and _host.has_method("_play_sfx"):
		_host.call("_play_sfx", &"finisher")
	return card


func _caption(text: String, portrait: bool, flash: bool = false) -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_presentation.append(layer)
	var label := Label.new()
	label.text = text
	label.position = Vector2(390, 135 if portrait else 565)
	label.size = Vector2(500, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38 if portrait else 26)
	label.add_theme_color_override("font_color", Color("#fff0c2"))
	label.add_theme_color_override("font_outline_color", Color("#07101d"))
	label.add_theme_constant_override("outline_size", 6)
	if not text.is_empty():
		# Finisher captions use the same animated banner as match announcements.
		var banner = CalloutScript.new()
		var font := FontVariation.new()
		font.base_font = ThemeDB.fallback_font
		font.variation_embolden = 0.85
		banner.setup(label, font)
		layer.add_child(banner)
		banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(label)
	if portrait:
		var path := "res://assets/characters/portraits/%s.png" % _attacker.character_id
		if ResourceLoader.exists(path):
			var image := TextureRect.new()
			image.texture = ResourceLoader.load(path)
			image.position = Vector2(530, 195)
			image.size = Vector2(220, 220)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			layer.add_child(image)
		_lifetimes[layer] = 0.35
	if flash:
		var rect := ColorRect.new()
		rect.color = Color(1, 1, 1, 0.15)
		rect.size = Vector2(1280, 720)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		_lifetimes[layer] = 0.08
	return label

func set_paused(value: bool) -> void:
	_paused = value
	timeline.set_paused(value)
	for node in _presentation:
		if node is AudioStreamPlayer: node.stream_paused = value

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for actor in _actors.values(): actor.reduced_motion = value
func set_effect_density(value: String) -> void: effect_density = "mobile" if value == "mobile" else "desktop"
func temporary_actor_count() -> int: return _actors.size()
func consumed_hit_ids() -> PackedStringArray: return _hit_ids.duplicate()
func current_event_key() -> String: return timeline.current_event_key()

func _cleanup_presentation() -> void:
	for fighter in _fighter_art:
		if is_instance_valid(fighter):
			var saved: Dictionary = _fighter_art[fighter]
			fighter._visual.sprite.sprite_frames = saved.frames
			fighter._visual.sprite.pixel_size = saved.pixel_size
			fighter._visual.sprite.position = saved.position
			fighter._visual.sprite.play("idle")
	_fighter_art.clear()
	for actor in _actors.values(): actor.free()
	_actors.clear()
	for node in _presentation:
		if is_instance_valid(node): node.free()
	_presentation.clear()
	_lifetimes.clear()
	_clocks.clear()
	_impact_remaining = 0
	_super_card_hold_remaining = 0.0

func cancel() -> void:
	var was_active := active
	active = false
	timeline.cancel()
	_cleanup_presentation()
	if is_instance_valid(_attacker): _attacker.exit_cinematic_lock()
	if is_instance_valid(_defender): _defender.exit_cinematic_lock()
	if was_active and is_instance_valid(_camera):
		_camera.transform = _camera_transform
		_camera.size = _camera_size
		_camera.fov = _camera_fov

func _exit_tree() -> void:
	if active: cancel()

func _fail(reason: String) -> void:
	diagnostic = reason
	push_warning(reason)
	cancel()
	cancelled.emit(reason)
