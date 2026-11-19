extends Node
## Autoload "SaveManager". Local save slots (autosave + manual), versioned
## JSON with a .bak of the previous write for malformed-save recovery, and
## export. The save directory is chosen by the platform adapter so it can be
## pointed at a Steam Cloud-synced path later.

signal saved(slot: String)
signal load_failed(slot: String, reason: String)

const AUTOSAVE := "autosave"
const MANUAL_SLOTS: Array = ["slot_1", "slot_2", "slot_3"]


func save_dir() -> String:
	var dir: String = PlatformService.save_directory()
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


func slot_path(slot: String) -> String:
	return save_dir().path_join(slot + ".json")


func write_state(state: GameState, slot: String) -> bool:
	var data := state.to_dict()
	data["meta"] = {
		"saved_at": Time.get_datetime_string_from_system(),
		"summary": "%s · %s · $%d" % [str(state.player.get("stage_name", "")), CalendarRules.describe_slot(state.day, state.block), state.cash],
	}
	var path := slot_path(slot)
	var text := JSON.stringify(data, "\t")
	# Keep the previous good save as a backup, then write via a temp file.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: " + tmp)
		return false
	f.store_string(text)
	f.close()
	DirAccess.rename_absolute(tmp, path)
	saved.emit(slot)
	return true


func autosave() -> void:
	if Game.state != null:
		write_state(Game.state, AUTOSAVE)


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if not d.has("player") or not d.has("day"):
		return {}
	return d


## Reads a slot. Falls back to the .bak file when the main file is malformed.
## Returns {ok, state, recovered, reason}.
func read_state(slot: String) -> Dictionary:
	var path := slot_path(slot)
	var d := _parse(path)
	var recovered := false
	if d.is_empty():
		d = _parse(path + ".bak")
		recovered = not d.is_empty()
	if d.is_empty():
		var reason := "Save is missing or unreadable."
		load_failed.emit(slot, reason)
		return {"ok": false, "reason": reason}
	if int(d.get("version", 0)) > GameState.SAVE_VERSION:
		return {"ok": false, "reason": "This save is from a newer version of the game."}
	d = SaveMigrations.migrate(d)
	var state := GameState.from_dict(d)
	return {"ok": true, "state": state, "recovered": recovered, "reason": "Recovered from backup." if recovered else ""}


func slot_info(slot: String) -> Dictionary:
	var d := _parse(slot_path(slot))
	if d.is_empty():
		if FileAccess.file_exists(slot_path(slot)):
			return {"exists": true, "summary": "(damaged - will try backup)", "saved_at": ""}
		return {"exists": false}
	var meta: Dictionary = d.get("meta", {})
	return {"exists": true, "summary": str(meta.get("summary", "")), "saved_at": str(meta.get("saved_at", ""))}


func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for slot in [AUTOSAVE] + MANUAL_SLOTS:
		var p := slot_path(str(slot))
		if FileAccess.file_exists(p):
			var t := FileAccess.get_modified_time(p)
			if t > best_t:
				best_t = t
				best = str(slot)
	return best


## Copies a slot to user://exports with a timestamp. Returns the absolute path.
func export_slot(slot: String) -> String:
	var src := slot_path(slot)
	if not FileAccess.file_exists(src):
		return ""
	var dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dst := dir.path_join("%s_%s.json" % [slot, stamp])
	DirAccess.copy_absolute(src, dst)
	return ProjectSettings.globalize_path(dst)


func delete_slot(slot: String) -> void:
	for suffix in ["", ".bak"]:
		var p := slot_path(slot) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
