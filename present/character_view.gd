extends Node3D

## 3D presentation of one fighter. Reads the deterministic sim state every
## render frame and poses a rigged model; it never writes to the sim.
## - Strike clips are time-warped by sim frame so the impact pose lands on the
##   move's first active frame (anim_library.impact_time).
## - Kicks, crouch/air punches, guard and block use two-bone IK on top of the
##   base clip, so moves the clip library lacks still read clearly.
## Spec: docs/superpowers/specs/2026-10-11-3d-fighter-architecture.md

const AnimLib = preload("res://present/anim_library.gd")
const L = preload("res://sim/layout.gd")

const DEFAULT_MODEL := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"
const UNIT := 1.0 / 10000.0

var model_path := DEFAULT_MODEL
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var _leg_ik: TwoBoneIK3D
var _arm_l_ik: TwoBoneIK3D
var _arm_r_ik: TwoBoneIK3D
var _targets := {}
var _clip := ""
var _loop_speed := 1.0
var _guard := 0.0
var _shake_phase := 0
var _scale := 1.0   # model head height / reference male head height, for IK targets


func setup(path: String = DEFAULT_MODEL, tint: Color = Color.WHITE) -> void:
	model_path = path
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player = AnimationPlayer.new()
	model.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", AnimLib.library())
	if tint != Color.WHITE:
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh as MeshInstance3D
			for surface in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(surface)
				if mat is StandardMaterial3D:
					var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					copy.albedo_color = copy.albedo_color * tint
					mi.set_surface_override_material(surface, copy)
	var head := skeleton.find_bone("Head")
	if head >= 0:
		_scale = clampf(skeleton.get_bone_global_rest(head).origin.y / 1.6, 0.8, 1.25)
	_leg_ik = _make_ik("thigh_r", "calf_r", "foot_r", "leg", Vector3(-0.15, 0.6, 1.6))
	_arm_l_ik = _make_ik("upperarm_l", "lowerarm_l", "hand_l", "hand_l", Vector3(0.6, 0.9, -0.4))
	_arm_r_ik = _make_ik("upperarm_r", "lowerarm_r", "hand_r", "hand_r", Vector3(-0.6, 0.9, -0.4))
	_play("Idle")


func _make_ik(root: String, middle: String, end: String, key: String, pole_pos: Vector3) -> TwoBoneIK3D:
	var target := Marker3D.new()
	target.name = key + "_target"
	model.add_child(target)
	var pole := Marker3D.new()
	pole.name = key + "_pole"
	pole.position = pole_pos
	model.add_child(pole)
	var ik := TwoBoneIK3D.new()
	skeleton.add_child(ik)
	ik.setting_count = 1
	ik.set_root_bone_name(0, root)
	ik.set_middle_bone_name(0, middle)
	ik.set_end_bone_name(0, end)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	ik.influence = 0.0
	_targets[key] = target
	return ik


func _play(clip: String, speed: float = 1.0) -> void:
	if _clip != clip:
		_clip = clip
		player.play(clip, 0.08)
	player.speed_scale = speed


func _sample(clip: String, t: float) -> void:
	if _clip != clip:
		_clip = clip
		player.play(clip, 0.05)
	player.speed_scale = 0.0
	player.seek(t, true)


## Pose the model from fighter `i` of sim state `s`.
func show_state(s: PackedInt32Array, i: int, moveset) -> void:
	var b := L.base(i)
	var state := s[b + L.F_STATE]
	var sf := s[b + L.F_STATE_FRAME]
	var facing := s[b + L.F_FACING]
	position = Vector3(s[b + L.F_X] * UNIT, s[b + L.F_Y] * UNIT, 0.0)
	model.rotation_degrees.y = 90.0 * facing
	var leg := 0.0
	var arm_l := 0.0
	var arm_r := 0.0
	var guard := true
	match state:
		L.S_IDLE:
			_play("Idle")
		L.S_WALK_F:
			_play("Walk", 1.3)
		L.S_WALK_B:
			_play("Walk", -1.0)
		L.S_CROUCH:
			_play("Crouch_Idle")
		L.S_PREJUMP:
			_sample("Jump_Start", 0.35)
		L.S_AIR:
			_play("Jump")
		L.S_LAND:
			_sample("Jump_Land", 0.15 + sf * 0.05)
		L.S_DASH:
			_play("Jog_Fwd", 1.6)
		L.S_BACKDASH:
			_play("Walk", -2.2)
		L.S_BLOCKSTUN:
			_play("Crouch_Idle" if (s[b + L.F_FLAGS] & 512) != 0 else "Idle")
			_set_target("hand_l", Vector3(0.05, 1.5 if (s[b + L.F_FLAGS] & 512) == 0 else 0.78, 0.32))
			_set_target("hand_r", Vector3(-0.08, 1.58 if (s[b + L.F_FLAGS] & 512) == 0 else 0.84, 0.3))
			arm_l = 1.0
			arm_r = 1.0
			guard = false
		L.S_HITSTUN:
			_sample("Hit_Chest" if s[b + L.F_HITS_TAKEN] % 2 == 1 else "Hit_Head", minf(0.32, sf * 0.03))
			guard = false
		L.S_LAUNCHED:
			_sample("Hit_Knockback", minf(0.45, sf * 0.025))
			guard = false
		L.S_KNOCKDOWN:
			_sample("Hit_Knockback", 0.8)
			guard = false
		L.S_GETUP:
			_sample("LayToIdle", minf(1.5, 0.35 + sf * 0.065))
			guard = false
		L.S_KO:
			_sample("Death01", minf(2.3, sf * 0.04))
			guard = false
		L.S_ATTACK:
			var m: Dictionary = moveset.moves[s[b + L.F_MOVE]]
			var posture := int(m.posture)
			var anim := str(m.anim)
			var p := _phase(m, sf)   # 0..1 to impact, 1 while active, 1..2 recovering
			if posture == 0 and anim in ["jab", "cross"]:
				var clip := "Punch_Jab" if anim == "jab" else "Punch_Cross"
				_sample(clip, _warp(clip, m, sf))
				guard = false
			elif anim == "kick":
				var reach: Vector3
				if posture == 1: reach = Vector3(-0.1, 0.12, 0.95)
				elif posture == 2: reach = Vector3(-0.1, 0.35, 0.75)
				elif int(m.hitbox[1]) >= 8000: reach = Vector3(-0.1, 1.25, 0.85)
				else: reach = Vector3(-0.1, 0.75, 0.85)
				if posture == 1: _play("Crouch_Idle")
				elif posture == 2: _play("Jump")
				else: _sample("Idle", 0.0)
				var chamber := Vector3(-0.1, reach.y * 0.55 + 0.25, 0.35)
				var rest := Vector3(-0.12, 0.09, -0.05)
				var foot: Vector3
				if p <= 0.5: foot = rest.lerp(chamber, p * 2.0)
				elif p <= 1.0: foot = chamber.lerp(reach, (p - 0.5) * 2.0)
				else: foot = reach.lerp(rest, p - 1.0)
				_set_target("leg", foot)
				leg = 1.0
			else:
				# Crouching and air punches: base pose plus an IK punch.
				_play("Crouch_Idle" if posture == 1 else "Jump")
				var height := 0.75 if posture == 1 else 1.3
				var hand := "hand_l" if anim == "jab" else "hand_r"
				var side := 0.12 if hand == "hand_l" else -0.12
				var start := Vector3(side, height + 0.15, 0.25)
				var hit := Vector3(side * 0.5, height + 0.1, 0.78)
				var hand_pos := start.lerp(hit, minf(p, 1.0)) if p <= 1.0 else hit.lerp(start, p - 1.0)
				_set_target(hand, hand_pos)
				if hand == "hand_l": arm_l = 1.0
				else: arm_r = 1.0
	if guard:
		# Fighting guard: fists up near the chin (lead hand slightly forward).
		var crouched := state == L.S_CROUCH or (state == L.S_ATTACK and int(moveset.moves[s[b + L.F_MOVE]].posture) == 1)
		var gy := 0.74 if crouched else 1.42
		if arm_l == 0.0:
			_set_target("hand_l", Vector3(0.1, gy, 0.34))
			arm_l = 1.0
		if arm_r == 0.0:
			_set_target("hand_r", Vector3(-0.12, gy + 0.05, 0.22))
			arm_r = 1.0
	_leg_ik.influence = leg
	_arm_l_ik.influence = arm_l
	_arm_r_ik.influence = arm_r
	# Hit-stop shake on the defender sells the impact.
	if s[b + L.F_HITSTOP] > 0 and state in [L.S_HITSTUN, L.S_BLOCKSTUN, L.S_LAUNCHED]:
		_shake_phase += 1
		model.position.x = 0.025 * (1 if _shake_phase % 2 == 0 else -1)
	else:
		model.position.x = 0.0


func _set_target(key: String, local: Vector3) -> void:
	(_targets[key] as Node3D).position = local * _scale
	# Elbow poles follow the hands (out, down and back), so crouched guards and
	# blocks bend the elbows naturally instead of flipping the arms overhead.
	if key == "hand_l" or key == "hand_r":
		var side := 0.45 if key == "hand_l" else -0.45
		(model.get_node(key + "_pole") as Node3D).position = (local + Vector3(side, -0.55, -0.35)) * _scale


static func _phase(m: Dictionary, sf: int) -> float:
	var startup := int(m.startup)
	var active := int(m.active)
	if sf < startup:
		return float(sf) / float(startup)
	if sf < startup + active:
		return 1.0
	return 1.0 + float(sf - startup - active + 1) / float(maxi(1, int(m.recovery)))


func _warp(clip: String, m: Dictionary, sf: int) -> float:
	var length := AnimLib.library().get_animation(clip).length
	var impact := AnimLib.impact_time(clip, model_path)
	var p := _phase(m, sf)
	if p <= 1.0:
		return impact * p
	return impact + (length - impact) * clampf(p - 1.0, 0.0, 1.0)
