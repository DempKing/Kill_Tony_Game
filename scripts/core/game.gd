extends Node
## Autoload "Game". Owns the loaded content, the current GameState, and scene
## routing. Scenes read and mutate state only through GameSim functions and
## then call notify() so HUDs refresh.

signal state_changed
signal message(text: String)

const SCENE_BOOT := "res://scenes/boot/boot.tscn"
const SCENE_CREATE := "res://scenes/character_creation/character_creation.tscn"
const SCENE_DISTRICT := "res://scenes/district/district.tscn"
const SCENE_PERFORMANCE := "res://scenes/performances/performance.tscn"
const SCENE_KILL_TONY := "res://scenes/performances/kill_tony_stage.tscn"

var db: ContentDB
var state: GameState
## Transient handoff between scenes (not saved; anything that must survive a
## reload is stored on state.flags by GameSim first).
var handoff: Dictionary = {}


func _ready() -> void:
	db = ContentDB.load_default()
	for e in db.errors:
		push_warning("[content] " + str(e))
	get_tree().auto_accept_quit = true


func is_dev_build() -> bool:
	## Cheats and the developer panel exist only in debug/editor builds or
	## exports with the "dev" feature tag. Release exports exclude them.
	return OS.is_debug_build() or OS.has_feature("dev")


func start_new_game(setup: Dictionary) -> void:
	var seed_value: int = int(setup.get("seed", 0))
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	state = GameSim.new_game(db, setup, seed_value)
	SaveManager.autosave()
	goto(SCENE_DISTRICT)


func load_slot(slot: String) -> Dictionary:
	var res: Dictionary = SaveManager.read_state(slot)
	if not bool(res.get("ok", false)):
		return res
	state = res["state"]
	SetRules.ensure_defaults(state)
	# A performance or Kill Tony night in progress resumes in its scene.
	var kt: Dictionary = state.flags.get("active_kill_tony", {})
	if not kt.is_empty():
		goto(SCENE_KILL_TONY)
	elif not (state.flags.get("active_performance", {}) as Dictionary).is_empty():
		handoff = {"resume": true}
		goto(SCENE_PERFORMANCE)
	else:
		goto(SCENE_DISTRICT)
	return res


func goto(path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", path)


func notify(text: String = "") -> void:
	if text != "":
		message.emit(text)
	state_changed.emit()
	_check_achievements()


## Local achievement hooks routed through the platform adapter.
func _check_achievements() -> void:
	if state == null:
		return
	if int(state.stats.get("sets", 0)) >= 1:
		PlatformService.unlock_achievement("first_set")
	if int(state.stats.get("bombs", 0)) >= 1:
		PlatformService.unlock_achievement("first_bomb")
	if int(state.kt.get("appearances", 0)) >= 1:
		PlatformService.unlock_achievement("bucket_pull")
	if bool(state.flags.get("secret_show_done", false)):
		PlatformService.unlock_achievement("secret_show")
	if int(state.stats.get("paid_sets", 0)) >= 1:
		PlatformService.unlock_achievement("first_paid_set")
