class_name RuleProbe
extends RefCounted
## SCRATCH（main に入れない）: 測るための決まりの切り替え。環境変数 PROBE_<NAME> で渡す。
static var _cache: Dictionary = {}


static func f(name: String, default := 0.0) -> float:
	if not _cache.has(name):
		var text := OS.get_environment("PROBE_" + name.to_upper())
		_cache[name] = text.to_float() if not text.is_empty() else default
	return _cache[name]
