extends Node3D
class_name QuaterniusMotion

const CLIPS := {
	"idle": "Idle", "walk_forward": "Walk", "walk_back": "Walk",
	"jab": "Punch_Jab", "cross": "Punch_Cross", "hook": "Melee_Hook",
	"hit": "Hit_Chest", "knockdown": "Hit_Knockback", "getup": "LayToIdle",
	"crouch": "Crouch_Idle", "jump_start": "Jump_Start",
	"jump_air": "Jump", "jump_land": "Jump_Land"
}

var animation_player: AnimationPlayer
var current_state := ""
var character_id := "bennet"
var skeleton: Skeleton3D
var assembly_root: Node3D

func configure(id: String) -> void:
	character_id = id

func bind(target_skeleton: Skeleton3D, _bone_map: Dictionary, target_root: Node3D) -> void:
	skeleton = target_skeleton
	assembly_root = target_root
	animation_player = AnimationPlayer.new()
	animation_player.name = "UALAnimationPlayer"
	target_root.add_child(animation_player)
	animation_player.root_node = NodePath("..")
	var first := (load("res://assets/animations/quaternius/UAL1_Standard.glb") as PackedScene).instantiate()
	var first_player := first.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var library := AnimationLibrary.new()
	for clip_name in first_player.get_animation_list():
		library.add_animation(clip_name, first_player.get_animation(clip_name).duplicate(true))
	first.free()
	var second := (load("res://assets/animations/quaternius/UAL2_Standard.glb") as PackedScene).instantiate()
	var second_player := second.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip_name in ["Melee_Hook", "Hit_Knockback", "LayToIdle"]:
		if second_player.has_animation(clip_name):
			if library.has_animation(clip_name): library.remove_animation(clip_name)
			library.add_animation(clip_name, second_player.get_animation(clip_name).duplicate(true))
	second.free()
	animation_player.add_animation_library("", library)
	for clip_name in ["Idle", "Walk", "Crouch_Idle"]:
		if animation_player.has_animation(clip_name):
			animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	play_state("idle", true)
	set_facing(1.0)

func play_state(state: String, restart := false, target_duration := 0.0) -> void:
	if animation_player == null or not CLIPS.has(state): return
	if state == current_state and not restart: return
	var clip: String = CLIPS[state]
	if not animation_player.has_animation(clip): return
	current_state = state
	var speed := -1.0 if state == "walk_back" else 1.0
	if target_duration > 0.0:
		speed *= animation_player.get_animation(clip).length / target_duration
	animation_player.play(clip, 0.10, speed, speed < 0.0)

func freeze_motion(frozen: bool) -> void:
	if animation_player != null:
		animation_player.speed_scale = 0.0 if frozen else 1.0

func set_facing(direction: float) -> void:
	if assembly_root != null:
		assembly_root.rotation.y = PI * 0.5 if direction >= 0.0 else -PI * 0.5
