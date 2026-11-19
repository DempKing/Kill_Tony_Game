class_name SaveUI
extends VBoxContainer
## Save slots: autosave plus manual slots, load, export and delete.

var ui: UiLayer
var allow_save: bool = true


func setup(p_ui: UiLayer, p_allow_save: bool) -> SaveUI:
	ui = p_ui
	allow_save = p_allow_save
	add_theme_constant_override("separation", 8)
	_build()
	return self


func _build() -> void:
	UiKit.clear(self)
	add_child(UiKit.title("Save / Load"))
	add_child(UiKit.label("Saves are stored at: " + ProjectSettings.globalize_path(SaveManager.save_dir()), 15, UiKit.C_DIM))
	for slot in [SaveManager.AUTOSAVE] + SaveManager.MANUAL_SLOTS:
		var sl: String = str(slot)
		var info: Dictionary = SaveManager.slot_info(sl)
		var label := ("Autosave" if sl == SaveManager.AUTOSAVE else sl.replace("_", " ").capitalize())
		var desc := (str(info.get("summary", "")) + "  ·  " + str(info.get("saved_at", ""))) if bool(info.get("exists", false)) else "(empty)"
		add_child(UiKit.label("%s: %s" % [label, desc], 18))
		var row := UiKit.hbox(6)
		if allow_save and sl != SaveManager.AUTOSAVE and Game.state != null:
			row.add_child(UiKit.button("Save here", func(): _save(sl)))
		row.add_child(UiKit.button("Load", func(): _load(sl), bool(info.get("exists", false))))
		row.add_child(UiKit.button("Export copy", func(): _export(sl), bool(info.get("exists", false))))
		if sl != SaveManager.AUTOSAVE:
			var del := func():
				ui.confirm("Delete save?", "Delete %s? This can't be undone." % label, "Delete", func():
					SaveManager.delete_slot(sl)
					_build())
			row.add_child(UiKit.button("Delete", del, bool(info.get("exists", false))))
		add_child(row)


func _save(slot: String) -> void:
	if SaveManager.write_state(Game.state, slot):
		ui.toast("Saved to %s." % slot)
	_build()


func _load(slot: String) -> void:
	var res := Game.load_slot(slot)
	if not bool(res.get("ok", false)):
		ui.info("Couldn't load", str(res.get("reason", "Unknown error.")))
		return
	if bool(res.get("recovered", false)):
		push_warning("Loaded %s from backup." % slot)


func _export(slot: String) -> void:
	var path := SaveManager.export_slot(slot)
	ui.info("Exported", "Copied to:\n" + path if path != "" else "Export failed.")
