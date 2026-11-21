extends TestCase


func test_save_roundtrip() -> void:
	var s := new_state(2024)
	var d := db()
	GameSim.run_action(s, d, {"id": "rent_bunk", "params": {}})
	JobRules.hire(s, d, "server")
	make_joke(s, "fam_heat", true, true)
	Scheduler.add(s, d, {"kind": "booking", "title": "X", "day": 3, "block": 2, "length": 1, "location_id": "lantern"})
	GameSim.advance(s, d, 5)
	var j1 := JSON.stringify(s.to_dict())
	var loaded := GameState.from_dict(JSON.parse_string(j1))
	var j2 := JSON.stringify(loaded.to_dict())
	eq(j2, j1, "save -> load -> save is lossless")
	eq(loaded.day, s.day, "day restored")
	eq(loaded.housing_id, "bunkhouse", "housing restored")
	eq(loaded.jokes.size(), s.jokes.size(), "jokes restored")


func test_rng_streams_persist() -> void:
	var s := new_state(55)
	s.rng("performance").randi()
	s.rng("world").randf()
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	for stream in GameState.RNG_STREAMS:
		eq(loaded.rng(str(stream)).randi(), s.rng(str(stream)).randi(), "rng stream %s continues identically after load" % stream)


func test_separate_streams() -> void:
	var a := new_state(77)
	var b := new_state(77)
	for i in range(10):
		b.rng("world").randf()
	eq(a.rng("bucket").randi(), b.rng("bucket").randi(), "world events don't disturb the bucket stream")


func test_migration_and_malformed() -> void:
	var old := {"player": {"name": "Old"}, "day": 3, "block": 1, "cash": 50}
	var m := SaveMigrations.migrate(old)
	eq(int(m["version"]), GameState.SAVE_VERSION, "v0 save migrated to current version")
	check(m.has("kt") and m.has("rngs"), "missing blocks added by migration")
	var s := GameState.from_dict(m)
	eq(s.day, 3, "migrated save loads")
	var parsed: Variant = JSON.parse_string("{ this is not json")
	check(parsed == null, "malformed JSON is detected (SaveManager falls back to .bak)")


func test_int_normalization() -> void:
	var s := new_state(9)
	KillTonyRules.ensure_draw(s, db(), 12)
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(loaded.kt["draws"].has("12"), "day-keyed records survive")
	eq(typeof(loaded.kt["draws"]["12"]["entrants"]), TYPE_INT, "whole numbers load back as ints")
	eq(typeof(loaded.skills["writing"]), TYPE_FLOAT, "skills stay floats")
