class_name PlatformAdapter
extends RefCounted
## Interface for platform services. The game only talks to this interface.
## NullPlatform is the development default; SteamPlatform is a stub until a
## Steam integration (e.g. GodotSteam) is installed and configured.


func initialize() -> bool:
	return true


func platform_name() -> String:
	return "none"


func is_available() -> bool:
	return false


func unlock_achievement(_id: String) -> void:
	pass


func is_achievement_unlocked(_id: String) -> bool:
	return false


## Directory for save files. Steam Cloud can sync a fixed subfolder of user://.
func save_directory() -> String:
	return "user://saves"


func user_display_name() -> String:
	return ""


func shutdown() -> void:
	pass
