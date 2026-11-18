class_name RuleProbe
extends RefCounted
## SCRATCH (not committed): rule toggles for measurements.
static var flags: Dictionary = {}

static func set_flag(name: String, value: float) -> void:
	flags[name] = value

static func f(name: String, default := 0.0) -> float:
	return flags.get(name, default)
