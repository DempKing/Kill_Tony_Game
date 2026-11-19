# Steam Release Checklist

Legend: ✅ verified · 🟡 implemented, not verified · ⬜ not started

| Item | Status | Notes |
|---|---|---|
| Runs without Steam client/credentials | 🟡 | `NullPlatform` is the only adapter selected |
| Platform adapter interface | 🟡 | `scripts/platform/platform_adapter.gd` |
| Steam SDK integration (e.g. GodotSteam) | ⬜ | `SteamPlatform` is a stub and never selected |
| App ID / depots / builds | ⬜ | |
| Achievements defined on Steam | ⬜ | Local hooks exist: first_set, first_bomb, bucket_pull, secret_show, first_paid_set |
| Achievement unlock via Steam | ⬜ | |
| Steam Cloud (Auto-Cloud on the save folder) | ⬜ | Saves are organized under one folder (`user://saves`) to make this simple |
| Save migrations | 🟡 | `SaveMigrations` v0→v1; tests written, not run |
| Malformed-save recovery | 🟡 | `.bak` fallback |
| Overlay / focus loss safety | 🟡 | No real-time timers affect gameplay decisions; choices are untimed |
| Controller navigation | 🟡 | Focusable buttons, focus outlines, default ui_* actions |
| Settings (display/audio/accessibility/remap) | 🟡 | |
| Windows export preset | 🟡 | `export_presets.cfg`, never exported |
| Dev tools excluded from release | 🟡 | Release preset has no `dev` tag; `OS.is_debug_build()` is false in release templates |
| Approved partner assets | ⬜ | See ASSET_APPROVALS.md |
| Performance profiling | ⬜ | |
| Store page, ratings, legal review of partner content | ⬜ | |

Nothing in this file is ✅ yet: no Steam environment, and no Godot run, existed
during development.
