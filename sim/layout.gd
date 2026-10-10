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
const BUTTONS := [IN_LP, IN_HP, IN_LK, IN_HK]
const BUTTON_NAMES := ["LP", "HP", "LK", "HK"]

# Header.
const H_FRAME := 0
const H_RNG := 1
const H_TIMER := 2          # round frames left
const H_FIGHTERS := 3
const H_WINNER := 4         # -1 none, else fighter index, 99 = draw
const H_DATA_VERSION := 5
const HEADER := 8

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
const F_FLAGS := 29
const FIGHTER := 32

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
const STATE_NAMES := ["idle", "walk_f", "walk_b", "crouch", "prejump", "air", "land", "dash", "backdash", "attack", "blockstun", "hitstun", "launched", "knockdown", "getup", "ko"]

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
const EVENT_SIZE := 4


static func base(fighter: int) -> int:
	return HEADER + fighter * FIGHTER
