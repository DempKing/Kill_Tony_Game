class_name NullPlatform
extends PlatformAdapter
## No-op platform for development: no Steam client or credentials required.
## Achievements are recorded locally so they can be inspected in the dev panel.

var unlocked: Dictionary = {}


func platform_name() -> String:
	return "development (no platform)"


func unlock_achievement(id: String) -> void:
	if not unlocked.has(id):
		unlocked[id] = Time.get_datetime_string_from_system()
		print("[NullPlatform] achievement unlocked (local only): ", id)


func is_achievement_unlocked(id: String) -> bool:
	return unlocked.has(id)
