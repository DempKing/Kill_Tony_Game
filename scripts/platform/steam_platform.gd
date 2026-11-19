class_name SteamPlatform
extends PlatformAdapter
## STUB. Not functional and not tested. Intended to wrap a Steam singleton
## (for example GodotSteam's "Steam") once installed. Until then
## PlatformService never selects this adapter. See docs/STEAM_RELEASE_CHECKLIST.md.

var _steam: Object = null


func initialize() -> bool:
	if not Engine.has_singleton("Steam"):
		return false
	_steam = Engine.get_singleton("Steam")
	# Real initialization (steamInit / app id checks) must be implemented and
	# verified against the Steam client before release.
	return false


func platform_name() -> String:
	return "steam (stub)"


func is_available() -> bool:
	return _steam != null


func save_directory() -> String:
	# Steam Cloud Auto-Cloud should be configured to sync this folder.
	return "user://saves"
