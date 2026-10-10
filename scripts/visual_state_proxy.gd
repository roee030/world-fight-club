class_name VisualStateProxy
extends Node3D

var flip_h := false
var animation: StringName = &"idle"
var frame := 0
var frame_progress := 0.0
var playing := true

func play(clip: StringName = &"") -> void:
	if not clip.is_empty(): animation = clip
	playing = true

func pause() -> void:
	playing = false

func set_frame_and_progress(next_frame: int, progress: float) -> void:
	frame = next_frame
	frame_progress = progress
