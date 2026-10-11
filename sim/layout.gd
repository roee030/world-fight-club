extends RefCounted

## Flat integer layout of the deterministic match state (see
## docs/superpowers/specs/2026-10-11-3d-fighter-architecture.md). The whole
## match is one PackedInt32Array: a header followed by one block per fighter.
## Units: 1 metre = 10 000 units, velocities in units/frame, 60 frames/second.
## Nothing here may be float: snapshots are array copies and hashes are exact.

const UNITS_PER_METRE := 10000
const FPS := 60

# Input bits (absolute directions; the sim converts to facing-relative).
const IN_UP := 1
const IN_DOWN := 2
const IN_LEFT := 4
const IN_RIGHT := 8
const IN_LP := 16
const IN_HP := 32
const IN_LK := 64
const IN_HK := 128
const IN_DRIVE := 256
const IN_SP := 512          # Easy-mode special button (direction picks the special)
const BUTTONS := [IN_LP, IN_HP, IN_LK, IN_HK]
const BUTTON_NAMES := ["LP", "HP", "LK", "HK"]

# Header.
const H_FRAME := 0
const H_RNG := 1
const H_TIMER := 2          # round frames left
const H_FIGHTERS := 3
const H_WINNER := 4         # -1 none, else fighter index, 99 = draw
const H_DATA_VERSION := 5
const H_ROUND := 6          # current round number (1-based)
const H_INTRO := 7          # frames of round intro left (inputs ignored)
const H_WINS := 8           # H_WINS + team: rounds won per team (2 teams)
const H_END_TIMER := 10     # frames since the round was decided
const H_MATCH_OVER := 11    # 1 when a team reached rounds_to_win
const H_ROUNDS_TO_WIN := 12
const HEADER := 16

# Fighter block.
const F_X := 0
const F_Y := 1
const F_VX := 2
const F_VY := 3
const F_FACING := 4         # +1 faces +x, -1 faces -x
const F_STATE := 5
const F_STATE_FRAME := 6    # frames spent in the state (1 on entry)
const F_MOVE := 7           # move index while attacking, else -1
const F_HITSTOP := 8
const F_STUN := 9           # hitstun / blockstun / knockdown frames left
const F_HP := 10
const F_COMBO := 11         # hits in the combo this fighter is dealing
const F_COMBO_DAMAGE := 12
const F_MOVE_CONNECT := 13  # 0 none, 1 hit, 2 blocked (current move)
const F_PREV_INPUT := 14
const F_BUFFER_MOVE := 15   # buffered button index (0..3) or -1
const F_BUFFER_FRAMES := 16
const F_TEAM := 17
const F_TARGET := 18        # fighter index this fighter faces / fights
const F_LAST_TAP_DIR := 19  # 6 forward, 4 back (for dash double-tap)
const F_LAST_TAP_FRAME := 20
const F_HP_MAX := 21
const F_WALK := 22          # walk speed units/frame (from fighter data)
const F_JUGGLE := 23        # juggle points used on this fighter
const F_COUNTER := 24       # 1 when the last hit taken was a counter-hit
const F_DRIVE := 25         # Drive gauge (0..60000, 10000 per stock)
const F_SUPER := 26         # Super gauge (0..30000, 10000 per bar)
const F_PUSH_VX := 27       # decaying push-back velocity
const F_HITS_TAKEN := 28    # hits in the combo this fighter is receiving
const F_FLAGS := 29         # bits: 1-2 jump dir, 256 airborne move, 512 crouch block, 1024 Easy controls, 2048 assisted move
const FLAG_AIR_MOVE := 256
const FLAG_CROUCH_BLOCK := 512
const FLAG_EASY := 1024
const FLAG_ASSISTED := 2048
const FLAG_NO_TECH := 4096   # being command-grabbed (cannot tech)
const F_HIST_POS := 30      # ring index of the input history
const F_SPECIAL_BUFFER := 31  # buffered special/super move index or -1
const F_HIST := 32          # HIST_LEN facing-relative numpad directions (ring)
const HIST_LEN := 24
const F_SPECIAL_FRAMES := 56
const F_ARMOR := 57         # armor hits left on the current move
const F_WALL_USED := 58     # wall splat already used in the combo against this fighter
const F_RUSH := 59          # frames left of the Drive Rush bonus
const F_BURNOUT := 60       # 1 while burned out (no Drive actions)
const F_PROJECTILE_OUT := 61  # 1 while this fighter's projectile is alive
const F_SUPER_FREEZE := 62  # frames of super flash left (both fighters frozen)
const F_START_X := 63       # spawn position, restored every round
const F_ARCHETYPE := 64     # moveset archetype index (Moveset.archetypes)
const F_MOVE_HITS := 65     # hits landed (or blocked) by the current multi-hit move
const F_POWER := 66         # damage percent from the fighter's stat build (100 = standard)
const F_LAST_HIT_MOVE := 67 # move index of the last strike that hit this fighter (presentation)
const FIGHTER := 72

# Projectiles live after the fighter blocks.
const PROJECTILES := 4
const P_ACTIVE := 0
const P_OWNER := 1
const P_X := 2
const P_Y := 3
const P_VX := 4
const P_LIFE := 5
const P_MOVE := 6
const PROJECTILE := 8

# States.
const S_IDLE := 0
const S_WALK_F := 1
const S_WALK_B := 2
const S_CROUCH := 3
const S_PREJUMP := 4
const S_AIR := 5
const S_LAND := 6
const S_DASH := 7
const S_BACKDASH := 8
const S_ATTACK := 9
const S_BLOCKSTUN := 10
const S_HITSTUN := 11
const S_LAUNCHED := 12      # airborne after a hit (juggle state)
const S_KNOCKDOWN := 13
const S_GETUP := 14
const S_KO := 15
const S_PARRY := 16
const S_THROW := 17
const S_THROWN := 18
const S_RUSH := 19
const STATE_NAMES := ["idle", "walk_f", "walk_b", "crouch", "prejump", "air", "land", "dash", "backdash", "attack", "blockstun", "hitstun", "launched", "knockdown", "getup", "ko", "parry", "throw", "thrown", "rush"]

# Event stream: groups of 4 ints [kind, fighter, a, b].
const EV_HIT := 1           # a = move index, b = damage
const EV_BLOCK := 2         # a = move index, b = chip
const EV_COUNTER := 3       # a = move index
const EV_KO := 4
const EV_LAND := 5
const EV_ATTACK := 6        # a = move index (startup began)
const EV_LAUNCH := 7
const EV_WALL := 8
const EV_DASH := 9
const EV_SUPER := 10        # a = move index (cinematic super flash begins)
const EV_PARRY := 11        # fighter = parrying fighter, a = 1 perfect
const EV_THROW := 12        # fighter = thrower
const EV_TECH := 13
const EV_PROJECTILE := 14   # a = projectile slot
const EV_BURNOUT := 15
const EV_ARMOR := 16
const EV_SPECIAL := 17      # a = move index (special started; for callouts)
const EV_RUSH := 18
const EV_ROUND_START := 19  # fighter = -1, a = round number
const EV_FIGHT := 20        # intro over, fight!
const EV_MATCH_OVER := 21   # a = winning team
const EVENT_SIZE := 4


static func base(fighter: int) -> int:
	return HEADER + fighter * FIGHTER


static func projectile_base(s: PackedInt32Array, slot: int) -> int:
	return HEADER + s[H_FIGHTERS] * FIGHTER + slot * PROJECTILE
