extends RefCounted

const MatchState = preload("res://scripts/finishers/match_state.gd")

static func match_point_for(attacker: int, player_rounds: int, enemy_rounds: int) -> bool:
	return (player_rounds if attacker == 0 else enemy_rounds) == 1

static func is_eligible(context: Dictionary, definition: Dictionary) -> bool:
	if not definition.get("implemented", false) or context.get("paused", false):
		return false
	if context.get("state", -1) != MatchState.Value.FIGHTING:
		return false
	if not context.get("attacker_actionable", context.get("actionable", false)):
		return false
	return float(context.get("meter", 0.0)) >= float(definition.get("meter_cost", 100.0))
