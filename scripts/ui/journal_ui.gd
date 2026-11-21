class_name JournalUI
extends VBoxContainer
## The joke journal: jokes (works in progress + finished archive), the joke
## builder (assemble/rewrite from components), discovered material, sets,
## performance notes and the book shelf.

var ui: UiLayer
var tab: String = "jokes"
var _content: VBoxContainer
var _editing_id: String = ""
var _draft: Dictionary = {}
var _draft_title: String = ""


func setup(p_ui: UiLayer, start_tab: String = "jokes") -> JournalUI:
	ui = p_ui
	tab = start_tab
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(1080, 640)
	_build()
	return self


func _build() -> void:
	UiKit.clear(self)
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	var book_names: Array = []
	for b in s.books:
		book_names.append(str(db.books.get(str(b), {}).get("name", b)))
	add_child(UiKit.title("Joke Journal"))
	add_child(UiKit.label("Works in progress: %d / %d  ·  Finished archive: unlimited  ·  Books: %s" % [JokeRules.wip_count(s), s.book_capacity(db), ", ".join(PackedStringArray(book_names))], 18, UiKit.C_DIM))
	var tabs := UiKit.hbox(6)
	for t in [["jokes", "Jokes"], ["build", "Build / Rewrite"], ["material", "Material"], ["sets", "Sets"], ["notes", "Performance notes"], ["shelf", "Shelf"]]:
		var tid: String = t[0]
		var b := UiKit.button(("▶ " if tab == tid else "") + str(t[1]), func(): _switch(tid))
		tabs.add_child(b)
	add_child(tabs)
	var sc := UiKit.scroll(520)
	add_child(sc)
	_content = UiKit.vbox(8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_content)
	match tab:
		"jokes": _build_jokes()
		"build": _build_editor()
		"material": _build_material()
		"sets": _build_sets()
		"notes": _build_notes()
		"shelf": _build_shelf()


func _switch(t: String) -> void:
	tab = t
	if t != "build":
		_editing_id = ""
		_draft = {}
	_build()
	UiKit.focus_first(self)


func _build_jokes() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	_content.add_child(UiKit.button("+ Start a new joke", func(): _start_new(), JokeRules.can_add_wip(s, db), "Limited by your active book's capacity."))
	for status in ["wip", "complete"]:
		_content.add_child(UiKit.label("WORKS IN PROGRESS" if status == "wip" else "FINISHED ARCHIVE", 20, UiKit.C_ACCENT))
		var any := false
		for jid in s.jokes:
			var j: Dictionary = s.jokes[jid]
			if str(j.get("status", "wip")) != status:
				continue
			any = true
			_content.add_child(_joke_card(jid, j))
		if not any:
			_content.add_child(UiKit.label("(none)", 18, UiKit.C_DIM))


func _joke_card(jid: String, j: Dictionary) -> Control:
	var db: ContentDB = Game.db
	var p := PanelContainer.new()
	var v := UiKit.vbox(4)
	p.add_child(v)
	var st := JokeRules.status_of(db, j)
	var rev := JokeRules.current_revision(j)
	v.add_child(UiKit.label("%s  ·  rev %d  ·  %s  ·  %ds  ·  quality %d  ·  familiarity %d  ·  tested %dx" % [j["title"], int(rev.get("rev", 1)), JokeRules.STATUS_LABEL.get(st, st), JokeRules.seconds_of(db, j), int(JokeRules.quality_of(db, j)), int(j.get("familiarity", 0)), int(j.get("test_count", 0))], 19))
	var parts: Dictionary = rev.get("parts", {})
	for part in JokeRules.PART_ORDER:
		if parts.has(part):
			v.add_child(UiKit.label("   %s: %s" % [str(part).replace("_", "-").capitalize(), db.component(str(parts[part])).get("text", "")], 17, UiKit.C_DIM))
	if str(j.get("notes", "")) != "":
		v.add_child(UiKit.label("   Notes: " + str(j["notes"]), 17, UiKit.C_WARN))
	var hist: Array = j.get("history", [])
	if not hist.is_empty():
		var last: Dictionary = hist.back()
		v.add_child(UiKit.label("   Last performed: rev %d at %s, score %d (%s)" % [int(last["rev"]), Game.db.venues.get(str(last["venue"]), {}).get("name", last["venue"]), int(float(last["score"])), str(last["response"]).replace("_", " ")], 17))
	var fb: Array = j.get("feedback", [])
	if not fb.is_empty():
		v.add_child(UiKit.label("   Feedback: " + str(fb.back()), 17, UiKit.C_WARN))
	var row := UiKit.hbox(6)
	row.add_child(UiKit.button("Rewrite", func(): _start_edit(jid)))
	if str(j["status"]) == "wip":
		row.add_child(UiKit.button("Move to finished archive", func(): _set_status(jid, "complete")))
	else:
		row.add_child(UiKit.button("Reopen for work", func(): _set_status(jid, "wip")))
	row.add_child(UiKit.button("Title & notes", func(): _edit_notes(jid)))
	v.add_child(row)
	return p


func _set_status(jid: String, st: String) -> void:
	var res := JokeRules.set_status(Game.state, Game.db, jid, st)
	ui.toast(str(res["message"]))
	Game.notify()
	_build()


func _edit_notes(jid: String) -> void:
	var j: Dictionary = Game.state.jokes[jid]
	var v := UiKit.vbox(8)
	v.add_child(UiKit.title("Title & notes"))
	var t := LineEdit.new()
	t.text = str(j["title"])
	t.max_length = 60
	v.add_child(t)
	var n := TextEdit.new()
	n.text = str(j.get("notes", ""))
	n.custom_minimum_size = Vector2(600, 140)
	v.add_child(n)
	v.add_child(UiKit.label("Notes and titles are yours. Performance results come from game attributes (quality, compatibility, delivery, audience fit), not from reading your text.", 16, UiKit.C_DIM))
	var holder: Array = [null]
	v.add_child(UiKit.button("Save", func():
		JokeRules.rename(Game.state, jid, t.text, n.text)
		ui.close(holder[0])
		_build()))
	holder[0] = ui.open(v, 700)


func _start_new() -> void:
	_editing_id = ""
	_draft = {}
	_draft_title = ""
	tab = "build"
	_build()


func _start_edit(jid: String) -> void:
	_editing_id = jid
	var j: Dictionary = Game.state.jokes[jid]
	_draft = JokeRules.parts_of(j).duplicate()
	_draft_title = str(j["title"])
	tab = "build"
	_build()


func _build_editor() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	var editing := _editing_id != ""
	_content.add_child(UiKit.label(("Rewriting: " + _draft_title) if editing else "New joke", 22, UiKit.C_ACCENT))
	_content.add_child(UiKit.label("Pick a premise, setup and punchline that belong together. Tags, act-outs and callbacks are optional extras you choose to use on stage. Compatibility comes from authored links between pieces; the game does not interpret your text.", 16, UiKit.C_DIM))
	if not editing:
		var t := LineEdit.new()
		t.placeholder_text = "Working title"
		t.text = _draft_title
		t.max_length = 60
		t.text_changed.connect(func(x: String): _draft_title = x)
		_content.add_child(t)
	for part in JokeRules.PART_ORDER:
		var row := UiKit.hbox(8)
		var lab := UiKit.label(str(part).replace("_", "-").capitalize() + ("" if JokeRules.REQUIRED.has(part) else " (optional)"), 18, UiKit.C_TEXT, false)
		lab.custom_minimum_size = Vector2(190, 0)
		row.add_child(lab)
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_theme_font_size_override("font_size", GameSettings.font_size(17))
		ob.add_item("(none)")
		ob.set_item_metadata(0, "")
		var comps := JokeRules.components_of_type(s, db, part)
		var sel := 0
		for i in range(comps.size()):
			var c: Dictionary = comps[i]
			var fam_title: String = str(db.families.get(str(c["family"]), {}).get("title", ""))
			ob.add_item("[%s] %s  (q%d, %ds)" % [fam_title, _short(str(c["text"]), 70), int(c["quality"]), int(c["seconds"])])
			ob.set_item_metadata(i + 1, str(c["id"]))
			if str(_draft.get(part, "")) == str(c["id"]):
				sel = i + 1
		ob.select(sel)
		var part_c: String = part
		ob.item_selected.connect(func(idx: int):
			var cid: String = str(ob.get_item_metadata(idx))
			if cid == "":
				_draft.erase(part_c)
			else:
				_draft[part_c] = cid
			_build())
		row.add_child(ob)
		_content.add_child(row)
	var ev := JokeRules.evaluate(db, _draft)
	var st: String = str(ev["status"])
	var col := "#8ef0a0" if st == "coherent" else ("#ffd27a" if st == "weak" else "#ff8a8a")
	var txt := "[b]Status:[/b] [color=%s]%s[/color]" % [col, JokeRules.STATUS_LABEL.get(st, st)]
	if st == "missing":
		txt += "  (needs: %s)" % ", ".join(PackedStringArray(ev["missing"]))
	for l in ev["links"]:
		var lc := "#8ef0a0" if str(l["status"]) == "coherent" else ("#ffd27a" if str(l["status"]) == "weak" else "#ff8a8a")
		txt += "\n  %s → %s: [color=%s]%s[/color]" % [l["a"], l["b"], lc, JokeRules.STATUS_LABEL.get(str(l["status"]), l["status"])]
	var cb: String = str(_draft.get("callback", ""))
	if cb != "":
		txt += "\n  Callback needs an earlier joke about: %s" % db.families.get(str(db.component(cb).get("callback_ref", "")), {}).get("title", "?")
	var polish := 0
	if editing:
		var cur := JokeRules.current_revision(s.jokes[_editing_id])
		if cur.get("parts", {}) == JokeRules._clean_parts(_draft):
			polish = int(cur.get("polish", 0))
	txt += "\n[b]Estimated length:[/b] %ds (core %ds)  ·  [b]Quality:[/b] %d" % [JokeRules.seconds_of_parts(db, _draft), JokeRules.seconds_of_parts(db, _draft, false), int(JokeRules.quality_of_parts(db, _draft, polish))]
	_content.add_child(UiKit.rich(txt))
	var row2 := UiKit.hbox(8)
	if editing:
		row2.add_child(UiKit.button("Save as new revision", func(): _save_edit()))
	else:
		row2.add_child(UiKit.button("Write it into the journal", func(): _save_new(), JokeRules.can_add_wip(s, db), "No free work-in-progress slot."))
	row2.add_child(UiKit.button("Back to jokes", func(): _switch("jokes")))
	_content.add_child(row2)


func _short(t: String, n: int) -> String:
	return t if t.length() <= n else t.substr(0, n - 1) + "…"


func _save_new() -> void:
	var res := JokeRules.create_joke(Game.state, Game.db, _draft_title, _draft)
	ui.toast(str(res["message"]))
	if bool(res["ok"]):
		_switch("jokes")
		Game.notify()


func _save_edit() -> void:
	var res := JokeRules.revise_joke(Game.state, Game.db, _editing_id, _draft)
	ui.toast(str(res["message"]))
	if bool(res["ok"]):
		_switch("jokes")
		Game.notify()


func _build_material() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	_content.add_child(UiKit.label("Material comes from work, the street, people, writing sessions, and bombing. Money can't buy it.", 17, UiKit.C_DIM))
	for fam in db.families:
		var pieces: Array = []
		for cid in s.components:
			var c := db.component(str(cid))
			if str(c.get("family", "")) == fam:
				pieces.append(c)
		if pieces.is_empty():
			continue
		var total := db.family_components(fam).size()
		_content.add_child(UiKit.label("%s  (%d/%d pieces)  ·  topics: %s" % [db.families[fam]["title"], pieces.size(), total, ", ".join(PackedStringArray(db.families[fam]["topics"]))], 20, UiKit.C_ACCENT))
		for c in pieces:
			_content.add_child(UiKit.label("   %s · q%d · orig %d · diff %d · %ds — %s" % [str(c["type"]).replace("_", "-"), int(c["quality"]), int(c["originality"]), int(c["difficulty"]), int(c["seconds"]), c["text"]], 17))


func _build_sets() -> void:
	var s: GameState = Game.state
	SetRules.ensure_defaults(s)
	var e1 := SetEditor.new().setup(SetRules.DEFAULT_ID, 180, "spur_open_mic")
	_content.add_child(e1)
	_content.add_child(UiKit.spacer(12))
	_content.add_child(UiKit.label("Your prepared minute is kept ready in case your name gets pulled at Kill Tony.", 17, UiKit.C_DIM))
	var e2 := SetEditor.new().setup(SetRules.KT_MINUTE_ID, 60, "kill_tony")
	_content.add_child(e2)


func _build_notes() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	if s.performances.is_empty():
		_content.add_child(UiKit.label("No performances yet. Notes from every set will appear here.", 18, UiKit.C_DIM))
	for i in range(s.performances.size() - 1, maxi(-1, s.performances.size() - 11), -1):
		var p: Dictionary = s.performances[i]
		var line := "%s · %s · score %d (%s)" % [CalendarRules.describe_slot(int(p["day"]), int(p["block"])), db.venues.get(str(p["venue"]), {}).get("name", p["venue"]), int(float(p["score"])), str(p["tier"])]
		_content.add_child(UiKit.label(line, 19, UiKit.C_ACCENT))
		for jr in p.get("jokes", []):
			var title: String = str(s.jokes.get(str(jr["joke_id"]), {}).get("title", jr["joke_id"]))
			_content.add_child(UiKit.label("   %s (rev %d): %d" % [title, int(jr["rev"]), int(float(jr["score"]))], 17))
	_content.add_child(UiKit.spacer(10))
	_content.add_child(UiKit.label("STYLE", 20, UiKit.C_ACCENT))
	_content.add_child(UiKit.label("Primary: %s. Secondary: %s." % [db.styles.get(str(s.player.get("style", "")), {}).get("name", "?"), db.styles.get(str(s.player.get("secondary_style", "")), {}).get("name", "none")], 18))
	if int(s.stats.get("sets", 0)) >= 5:
		var row := UiKit.hbox(4)
		for sid in db.styles:
			var sid_c: String = sid
			var pick := func():
				Game.state.player["secondary_style"] = sid_c
				_build()
			row.add_child(UiKit.button(str(db.styles[sid]["name"]), pick, sid != str(s.player.get("style", ""))))
		_content.add_child(UiKit.label("After five sets you can develop a secondary style:", 17, UiKit.C_DIM))
		_content.add_child(row)
	else:
		_content.add_child(UiKit.label("Perform five sets to start blending in a second style.", 17, UiKit.C_DIM))


func _build_shelf() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	for b in s.books:
		var bk: Dictionary = db.books.get(str(b), {})
		_content.add_child(UiKit.label("%s — holds %d works in progress" % [bk.get("name", b), int(bk.get("capacity", 3))], 20, UiKit.C_ACCENT))
		_content.add_child(UiKit.label("   " + str(bk.get("desc", "")), 17, UiKit.C_DIM))
	_content.add_child(UiKit.label("Your active capacity is set by your biggest book. Finished jokes are archived forever; you never forget a joke because a notebook is small.", 17, UiKit.C_DIM))
	_content.add_child(UiKit.spacer(10))
	_content.add_child(UiKit.label("SOUVENIRS", 20, UiKit.C_ACCENT))
	var any := false
	if int(s.stats.get("sets", 0)) > 0:
		_content.add_child(UiKit.label("• A drink ticket from your first open mic.", 18))
		any = true
	if int(s.kt.get("appearances", 0)) > 0:
		_content.add_child(UiKit.label("• A slip of paper with your name on it, pulled from the bucket (%d appearance%s)." % [int(s.kt["appearances"]), "s" if int(s.kt["appearances"]) > 1 else ""], 18))
		any = true
	if bool(s.flags.get("secret_show_done", false)):
		_content.add_child(UiKit.label("• A Secret Show wristband.", 18))
		any = true
	if not any:
		_content.add_child(UiKit.label("(Nothing yet. Go get some stories.)", 18, UiKit.C_DIM))
