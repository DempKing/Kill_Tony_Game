class_name TestCase
extends RefCounted
## Minimal assertion helpers for the headless test runner.

var failures: Array = []
var checks: int = 0
static var _db: ContentDB


static func db() -> ContentDB:
	if _db == null:
		_db = ContentDB.load_default()
	return _db


func new_state(seed_value: int = 12345, background: String = "server_vet", style: String = "observational") -> GameState:
	return GameSim.new_game(db(), {"name": "Test", "stage_name": "Testy", "pronouns": "they", "background": background, "style": style}, seed_value)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	checks += 1
	if a != b:
		failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])


## Builds a coherent joke from a family's premise/setup/strong-or-weak punchline.
func make_joke(s: GameState, fam: String, strong: bool = false, with_tag: bool = false) -> String:
	var d := db()
	var parts: Dictionary = {}
	for c in d.family_components(fam):
		var id: String = str(c["id"])
		match str(c["type"]):
			"premise": parts["premise"] = id
			"setup": parts["setup"] = id
			"punchline":
				var is_strong := id.ends_with("_u2")
				if is_strong == strong:
					parts["punchline"] = id
			"tag":
				if with_tag:
					parts["tag"] = id
	for p in parts:
		JokeRules.unlock_component(s, d, str(parts[p]))
	var res := JokeRules.create_joke(s, d, fam, parts)
	if not bool(res["ok"]):
		# Make room by archiving existing jokes.
		for jid in s.jokes:
			s.jokes[jid]["status"] = "complete"
		res = JokeRules.create_joke(s, d, fam, parts)
	return str(res.get("id", ""))
