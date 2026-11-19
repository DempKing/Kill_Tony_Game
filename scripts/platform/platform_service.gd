extends Node
## Autoload "PlatformService". Selects a platform adapter at boot.
## Only NullPlatform is active in this build.

var adapter: PlatformAdapter


func _ready() -> void:
	adapter = NullPlatform.new()
	adapter.initialize()


func save_directory() -> String:
	return adapter.save_directory() if adapter != null else "user://saves"


func unlock_achievement(id: String) -> void:
	if adapter != null:
		adapter.unlock_achievement(id)


func platform_name() -> String:
	return adapter.platform_name() if adapter != null else "none"
