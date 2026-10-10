extends RefCounted

enum Value { ROUND_INTRO, FIGHTING, FINISHER_PROMPT, FINISHER_CINEMATIC, KO_HOLD, CELEBRATION, RESULT }

static func can_transition(from: int, to: int) -> bool:
	var allowed := {
		Value.ROUND_INTRO: [Value.FIGHTING],
		Value.FIGHTING: [Value.FINISHER_PROMPT, Value.KO_HOLD, Value.RESULT],
		Value.FINISHER_PROMPT: [Value.FIGHTING, Value.FINISHER_CINEMATIC, Value.KO_HOLD],
		Value.FINISHER_CINEMATIC: [Value.FIGHTING, Value.KO_HOLD],
		Value.KO_HOLD: [Value.CELEBRATION, Value.ROUND_INTRO, Value.RESULT],
		Value.CELEBRATION: [Value.RESULT],
		Value.RESULT: [Value.ROUND_INTRO]
	}
	return to in allowed.get(from, [])
