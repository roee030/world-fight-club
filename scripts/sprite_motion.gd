extends Node3D
class_name SpriteMotion

var sprite: AnimatedSprite3D
var current_state := "idle"
var frozen := false

func bind(animated_sprite: AnimatedSprite3D) -> void:
	sprite = animated_sprite

func play_state(state: String, restart: bool = false, target_duration: float = 0.0) -> void:
	if sprite == null or not sprite.sprite_frames.has_animation(state): return
	if restart or current_state != state:
		sprite.play(state)
		current_state = state
	if target_duration > 0.0:
		var count := maxi(1, sprite.sprite_frames.get_frame_count(state))
		var source_duration := count / maxf(0.1, sprite.sprite_frames.get_animation_speed(state))
		sprite.speed_scale = clampf(source_duration / target_duration, 0.35, 3.5)
	else: sprite.speed_scale = 1.0
	if frozen: sprite.pause()

func set_facing(direction: float) -> void:
	if sprite != null: sprite.flip_h = direction < 0.0

func freeze_motion(value: bool) -> void:
	frozen = value
	if sprite == null: return
	if frozen: sprite.pause()
	else: sprite.play()
