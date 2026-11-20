extends Control
## Title screen: new game, continue, load, settings, quit.

var ui: UiLayer
var _menu: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GameSettings.theme
	var bg := ColorRect.new()
	bg.color = Color("#0d0b16")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(TitleBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -200
	center.offset_right = -760
	add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.08, 0.78)
	sb.border_color = Color("#b88cff")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(26)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	_menu = UiKit.vbox(12)
	_menu.custom_minimum_size = Vector2(520, 0)
	card.add_child(_menu)
	ui = UiLayer.new()
	add_child(ui)
	_build()
	if not Game.db.errors.is_empty():
		ui.info("Content warnings", "Some content failed validation:\n" + "\n".join(PackedStringArray(Game.db.errors.slice(0, 8))))


func _build() -> void:
	UiKit.clear(_menu)
	var t := UiKit.label(ProjectSettings.get_setting("application/config/name", "Kill Tony: The Game"), 52, UiKit.C_ACCENT, false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(t)
	var sub := UiKit.label("A comedy career and life simulation · Austin, Texas", 20, UiKit.C_DIM, false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(sub)
	_menu.add_child(UiKit.spacer(20))
	var latest: String = SaveManager.latest_slot()
	if latest != "":
		_menu.add_child(UiKit.button("Continue  (%s)" % SaveManager.slot_info(latest).get("summary", latest), func(): _load(latest)))
	_menu.add_child(UiKit.button("New career", func(): Game.goto(Game.SCENE_CREATE)))
	_menu.add_child(UiKit.button("Load", func(): ui.open(SaveUI.new().setup(ui, false), 760)))
	_menu.add_child(UiKit.button("Settings", func(): ui.open(SettingsUI.new().setup(ui), 860)))
	_menu.add_child(UiKit.button("Quit", func(): get_tree().quit()))
	_menu.add_child(UiKit.spacer(20))
	var note := UiKit.label("Prototype build. All art, audio and characters shown are original placeholders pending partner approval. Platform: %s." % PlatformService.platform_name(), 15, UiKit.C_DIM)
	_menu.add_child(note)
	UiKit.focus_first(_menu)


func _load(slot: String) -> void:
	var res := Game.load_slot(slot)
	if not bool(res.get("ok", false)):
		ui.info("Couldn't load", str(res.get("reason", "")))
