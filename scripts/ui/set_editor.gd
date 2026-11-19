class_name SetEditor
extends VBoxContainer
## Builds and orders a setlist, with live duration/familiarity/exposure/
## callback analysis. Used by the journal and the pre-show set builder.

signal changed

var setlist_id: String = SetRules.DEFAULT_ID
var slot_seconds: int = 180
var venue_id: String = ""
var _list_box: VBoxContainer
var _add_box: VBoxContainer
var _analysis: RichTextLabel


func setup(p_setlist: String, p_slot: int, p_venue: String) -> SetEditor:
	setlist_id = p_setlist
	slot_seconds = p_slot
	venue_id = p_venue
	add_theme_constant_override("separation", 8)
	_build()
	return self


func _build() -> void:
	UiKit.clear(self)
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	var entry: Dictionary = s.setlists.get(setlist_id, {"name": "Set", "jokes": []})
	add_child(UiKit.label("%s%s" % [entry.get("name", "Set"), (" · slot %ds" % slot_seconds) if slot_seconds > 0 else ""], 22, UiKit.C_ACCENT))
	var ids := SetRules.jokes_in(s, setlist_id)
	var a := SetRules.analyze(s, db, ids, slot_seconds, venue_id)
	_analysis = UiKit.rich(_analysis_text(a))
	add_child(_analysis)
	add_child(UiKit.label("Running order (opener first, closer last):", 18, UiKit.C_DIM))
	_list_box = UiKit.vbox(4)
	add_child(_list_box)
	for i in range(ids.size()):
		var jid: String = ids[i]
		var joke: Dictionary = s.jokes[jid]
		var row := UiKit.hbox(6)
		var secs := JokeRules.seconds_of(db, joke)
		var role := "Opener · " if i == 0 else ("Closer · " if i == ids.size() - 1 else "")
		var lbl := UiKit.label("%d. %s%s  (%ds, fam %d)" % [i + 1, role, joke["title"], secs, int(joke.get("familiarity", 0))], 18)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		row.add_child(UiKit.button("↑ Up", func(): _move(jid, -1), i > 0))
		row.add_child(UiKit.button("↓ Down", func(): _move(jid, 1), i < ids.size() - 1))
		row.add_child(UiKit.button("Remove", func(): _remove(jid)))
		_list_box.add_child(row)
	if ids.is_empty():
		_list_box.add_child(UiKit.label("(empty)", 18, UiKit.C_DIM))
	add_child(UiKit.label("Add material:", 18, UiKit.C_DIM))
	_add_box = UiKit.vbox(4)
	add_child(_add_box)
	var any := false
	for jid in s.jokes:
		if ids.has(jid):
			continue
		var joke: Dictionary = s.jokes[jid]
		var st := JokeRules.status_of(db, joke)
		if st == "missing":
			continue
		any = true
		var txt := "+ %s  (%ds, %s, quality %d)" % [joke["title"], JokeRules.seconds_of(db, joke), str(JokeRules.STATUS_LABEL[st]).to_lower(), int(JokeRules.quality_of(db, joke))]
		var jid_c: String = jid
		_add_box.add_child(UiKit.button(txt, func(): _add(jid_c)))
	if not any:
		_add_box.add_child(UiKit.label("No other complete jokes. Assemble one in the journal (premise + setup + punchline).", 18, UiKit.C_DIM))


func _analysis_text(a: Dictionary) -> String:
	var secs: int = int(a["seconds"])
	var core: int = int(a["core_seconds"])
	var col := "#8ef0a0" if core <= slot_seconds else "#ff8a8a"
	var t := "[b]Length:[/b] [color=%s]%ds[/color] with extras / %ds core of %ds  ·  [b]Avg familiarity:[/b] %d" % [col, secs, core, slot_seconds, int(a["avg_familiarity"])]
	if slot_seconds <= 0:
		t = "[b]Length:[/b] %ds  ·  [b]Jokes:[/b] %d  ·  [b]Avg familiarity:[/b] %d" % [secs, int(a["count"]), int(a["avg_familiarity"])]
	if venue_id != "":
		t += "  ·  [b]Heard here before:[/b] %d" % int(a["exposure"])
	for w in a["warnings"]:
		t += "\n[color=#ffd27a]⚠ %s[/color]" % str(w)
	return t


func _ids() -> Array:
	return SetRules.jokes_in(Game.state, setlist_id)


func _save(ids: Array) -> void:
	SetRules.save_setlist(Game.state, setlist_id, "", ids)
	changed.emit()
	_build()
	UiKit.focus_first(self)


func _move(jid: String, d: int) -> void:
	var ids := _ids()
	var i := ids.find(jid)
	var j := clampi(i + d, 0, ids.size() - 1)
	if i < 0 or i == j:
		return
	ids[i] = ids[j]
	ids[j] = jid
	_save(ids)


func _remove(jid: String) -> void:
	var ids := _ids()
	ids.erase(jid)
	_save(ids)


func _add(jid: String) -> void:
	var ids := _ids()
	ids.append(jid)
	_save(ids)
