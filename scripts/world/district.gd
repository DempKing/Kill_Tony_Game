extends Node2D
## District scene controller: exploration, interaction prompts, interiors,
## and every modal flow reachable from the street (journal, phone, writing,
## shifts, pre-show set builder, pause/save/settings, developer panel).

const INTERACT_RANGE := 75.0

var db: ContentDB
var s: GameState
var map: DistrictMap
var player: PlayerActor
var cam: Camera2D
var tint: CanvasModulate
var ui: UiLayer
var hud: Hud
var prompt: Label
var _target: Dictionary = {}
var _location_panel: LocationPanel
var _last_saved_slot: int = -1
var _event_open: bool = false
var street_npcs: Dictionary = {}
var _npc_slot: int = -1


func _ready() -> void:
	db = Game.db
	s = Game.state
	if s == null:
		Game.goto(Game.SCENE_BOOT)
		return
	tint = CanvasModulate.new()
	add_child(tint)
	map = DistrictMap.new()
	map.setup(db, s)
	add_child(map)
	for npc_id in db.npcs:
		var sn := StreetNpc.new().setup(str(npc_id), db.npcs[npc_id])
		add_child(sn)
		street_npcs[str(npc_id)] = sn
	_place_npcs(false)
	player = PlayerActor.new()
	player.configure(db, s)
	player.position = s.player_pos
	for id in db.locations:
		var r: Rect2 = map.rect_of(db.locations[id])
		player.blocked.append(r.grow(-4))
	player.bounds = Rect2(0, 0, float(db.world.get("width", 2600)), float(db.world.get("height", 1200)))
	add_child(player)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = not GameSettings.reduced_motion()
	cam.limit_left = 0
	cam.limit_top = -90
	cam.limit_right = int(player.bounds.end.x)
	cam.limit_bottom = int(player.bounds.end.y)
	player.add_child(cam)
	cam.make_current()
	ui = UiLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.root.add_child(hud)
	ui.top_margin = 84
	hud.journal_pressed.connect(open_journal)
	hud.phone_pressed.connect(open_phone)
	hud.wait_pressed.connect(wait_block)
	hud.menu_pressed.connect(open_pause)
	hud.go_now_pressed.connect(_go_now)
	prompt = UiKit.label("", 20, Color("#ffe27a"), false)
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -300
	prompt.offset_right = 300
	prompt.offset_top = -140
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 6)
	ui.root.add_child(prompt)
	ui.modal_opened.connect(func(): player.input_enabled = false)
	ui.modal_closed.connect(_on_modal_closed)
	Game.message.connect(func(t: String): ui.toast(t))
	Game.state_changed.connect(_apply_time_tint)
	Game.state_changed.connect(func(): _place_npcs(true))
	_apply_time_tint()
	Sfx.play_music("street_loop")
	_last_saved_slot = CalendarRules.slot(s.day, s.block)
	if not s.flags.has("intro_shown"):
		s.flags["intro_shown"] = true
		ui.dialog("Austin", "The bus hisses and pulls away from the curb. Hot air, neon, and the sound of a bar band somewhere.\n\nYou have $%d, a bag on the sidewalk, and a journal full of jokes that are, honestly, not great.\n\nYou're going to be a comedian." % s.cash, [{"label": "Let's go.", "cb": Callable()}])
	else:
		_show_pending_event()
	Game.notify()


func _on_modal_closed() -> void:
	if not ui.has_modal():
		player.input_enabled = true
		_location_panel = null
		Game.notify()
		_show_pending_event()


func _apply_time_tint() -> void:
	var c := [Color("#fff4e0"), Color("#ffffff"), Color("#b7a8e8"), Color("#8078c0")][clampi(s.block, 0, 3)] as Color
	tint.color = c
	map.queue_redraw()


## Recurring NPCs stand outside wherever their schedule puts them this block.
## When the block changes they walk there; people with nowhere to be are off-map.
func _place_npcs(animate: bool) -> void:
	var now := CalendarRules.slot(s.day, s.block)
	if animate and now == _npc_slot:
		return
	_npc_slot = now
	var counts: Dictionary = {}
	for npc_id in street_npcs:
		var sn: StreetNpc = street_npcs[npc_id]
		var loc := WorldRules.npc_location(db, npc_id, s.day, s.block)
		sn.location_id = loc
		if loc == "" or not db.locations.has(loc):
			sn.visible = false
			continue
		var idx: int = int(counts.get(loc, 0))
		counts[loc] = idx + 1
		var d := map.door_of(db.locations[loc])
		var north := d.y < 650.0
		var target := Vector2(d.x + 50.0 + idx * 58.0, d.y + (22.0 if north else -22.0))
		var was_hidden := not sn.visible
		sn.visible = true
		if was_hidden:
			sn.position = target
		sn.walk_to(target, animate and not GameSettings.reduced_motion())


func show_day_summary(sm: Dictionary, msg: String) -> void:
	var lines: Array = ["%s recap" % CalendarRules.day_name(int(sm["day"])), ""]
	lines.append("Earned %s · Spent %s · Cash now %s" % [UiKit.money(int(sm["earned"])), UiKit.money(int(sm["spent"])), UiKit.money(int(sm["cash"]))])
	if (sm["sets"] as Array).is_empty():
		lines.append("No stage time today.")
	else:
		lines.append("Sets: " + ", ".join(PackedStringArray(sm["sets"])))
	if int(sm["found"]) > 0:
		lines.append("New material found: %d piece%s." % [int(sm["found"]), "" if int(sm["found"]) == 1 else "s"])
	if int(sm["rent_in"]) >= 0:
		lines.append("Rent due in %d day%s." % [int(sm["rent_in"]), "" if int(sm["rent_in"]) == 1 else "s"])
	if not (sm["next"] as Array).is_empty():
		lines.append("Coming up: " + "; ".join(PackedStringArray(sm["next"])))
	lines.append("")
	lines.append(msg)
	ui.info("Good night", "\n".join(PackedStringArray(lines)))


func _process(_delta: float) -> void:
	if s == null:
		return
	s.player_pos = player.position
	_update_target()
	# Tutorial: first look at the landmark.
	if not s.flags.has("tut_landmark") and player.position.x > 980.0 and s.flags.has("tut_journal"):
		GameSim.tutorial_mark(s, "landmark")
		_landmark_moment()


func _landmark_moment() -> void:
	if not GameSettings.reduced_motion():
		var tw := create_tween()
		tw.tween_property(cam, "offset", Vector2(1300 - player.position.x, -200), 1.2)
		tw.tween_interval(1.0)
		tw.tween_property(cam, "offset", Vector2.ZERO, 0.8)
	ui.info("The Comedy Mothership", "There it is. The marquee glows over the whole block.\n\nEvery Monday night, comics line up outside to drop their names in a bucket. A few get pulled for one minute on Kill Tony, in front of a packed room and a panel of professionals.\n\nOne day. First: somewhere to sleep, and some way to pay for it.")
	Game.notify()


# --- Interaction ----------------------------------------------------------

func _update_target() -> void:
	if ui.has_modal():
		prompt.text = ""
		return
	var best: Dictionary = {}
	var best_d := INTERACT_RANGE
	var p := player.position
	for id in db.location_order:
		var loc: Dictionary = db.locations[id]
		var d := p.distance_to(map.door_of(loc))
		if d < best_d:
			best_d = d
			best = {"kind": "location", "id": id, "label": "Enter " + str(loc["name"])}
	for oid in db.observations:
		var o: Dictionary = db.observations[oid]
		if o.has("pos") and WorldRules.observation_available(s, o):
			var d2 := p.distance_to(Vector2(float(o["pos"][0]), float(o["pos"][1])))
			if d2 < best_d:
				best_d = d2
				best = {"kind": "observe", "id": oid, "label": "Look: " + str(o["label"])}
	for npc_id in street_npcs:
		var sn: StreetNpc = street_npcs[npc_id]
		if not sn.visible:
			continue
		var dn := p.distance_to(sn.position)
		if dn < best_d:
			best_d = dn
			best = {"kind": "npc", "id": npc_id, "label": "Talk to " + str(db.npcs[npc_id]["name"])}
	for po in db.posters:
		var d3 := p.distance_to(Vector2(float(po["pos"][0]), float(po["pos"][1])))
		if d3 < best_d:
			best_d = d3
			best = {"kind": "poster", "id": str(po["id"]), "label": "Read: " + str(po["label"])}
	_target = best
	prompt.text = ("[%s]  %s" % [GameSettings.key_label("interact"), best["label"]]) if not best.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if s == null or ui.has_modal():
		return
	if event.is_action_pressed("interact") and not _target.is_empty():
		_interact(_target)
	elif event.is_action_pressed("journal"):
		open_journal()
	elif event.is_action_pressed("phone"):
		open_phone()
	elif event.is_action_pressed("wait"):
		wait_block()
	elif event.is_action_pressed("pause"):
		open_pause()
	elif event.is_action_pressed("dev_panel") and Game.is_dev_build():
		open_dev()


func _interact(tg: Dictionary) -> void:
	match str(tg["kind"]):
		"location":
			open_location(str(tg["id"]))
		"observe":
			var res := WorldRules.observe(s, db, str(tg["id"]))
			ui.info("You notice something", str(res["message"]))
			Game.notify()
		"poster":
			ui.info("Poster", map.poster_text(str(tg["id"])))
		"npc":
			var nid: String = str(tg["id"])
			var line := WorldRules.talk(s, db, nid)
			var loc_name: String = str(db.locations.get(street_npcs[nid].location_id, {}).get("name", ""))
			ui.info(str(db.npcs[nid]["name"]), "\"%s\"\n\n(%s · hanging around %s)" % [GameSim.fmt(s, db, line), db.npcs[nid]["role"], loc_name])
			Game.notify()


func open_location(id: String) -> void:
	var loc: Dictionary = db.locations.get(id, {})
	s.location_id = id
	if not s.discovered_locations.has(id):
		s.discovered_locations.append(id)
	if not GameSim.location_open(db, id, s.block):
		var hours: Array = []
		for b in loc.get("open_blocks", []):
			hours.append(CalendarRules.block_name(int(b)))
		ui.info(str(loc["name"]), "Closed right now. Open: %s." % ", ".join(PackedStringArray(hours)))
		return
	WorldRules.roll_events(s, db, "enter:" + id)
	_location_panel = LocationPanel.new().setup(self, ui, id)
	ui.open(_location_panel, 1040)
	_show_pending_event()


func teleport_to(id: String) -> void:
	var loc: Dictionary = db.locations.get(id, {})
	if loc.is_empty():
		return
	var d := map.door_of(loc)
	player.position = d + Vector2(0, 30 if d.y < 650 else -30)
	s.player_pos = player.position


func _go_now(cid: String) -> void:
	var c := Scheduler.find(s, cid)
	if c.is_empty():
		return
	ui.close_all()
	teleport_to(str(c["location_id"]))
	open_location(str(c["location_id"]))


## Called by the location panel after any action; autosaves when time moved.
func after_action() -> void:
	var now := CalendarRules.slot(s.day, s.block)
	if now != _last_saved_slot:
		_last_saved_slot = now
		SaveManager.autosave()
	_apply_time_tint()
	Game.notify()


func _show_pending_event() -> void:
	if s.pending_events.is_empty() or _event_open:
		return
	var ev_id: String = str(s.pending_events[0])
	var ev := WorldRules.find_event(db, ev_id)
	if ev.is_empty():
		s.pending_events.remove_at(0)
		return
	var opts: Array = []
	var choices: Array = ev.get("choices", [])
	for i in range(choices.size()):
		var idx := i
		var pick := func():
			_event_open = false
			var r := WorldRules.resolve_event(s, db, ev_id, idx)
			if str(r.get("message", "")) != "":
				ui.toast(str(r["message"]))
			Game.notify()
			_refresh_location()
			_show_pending_event()
		opts.append({"label": str(choices[i]["text"]), "cb": pick})
	_event_open = true
	ui.dialog("", str(ev["text"]), opts)


# --- Time -----------------------------------------------------------------

func wait_block() -> void:
	var a := {"id": "wait", "blocks": 1, "params": {}}
	var conf := GameSim.conflicts_for(s, a)
	var do_wait := func():
		var notes := GameSim.advance(s, db, 1)
		for n in notes:
			ui.toast(str(n))
		after_action()
		_show_pending_event()
	if not conf.is_empty():
		var c: Dictionary = conf[0]
		ui.confirm("Wait?", "%s is happening right now at %s. If you wait, you'll miss it." % [c["title"], db.locations.get(str(c["location_id"]), {}).get("name", "")], "Wait anyway", do_wait, "Don't wait")
		return
	if s.block == 3:
		ui.confirm("Stay up all night?", "Waiting now rolls into tomorrow morning without sleep (energy %d, stress +%d). Sleeping at home is better." % [db.bali("time.all_nighter_energy", -15), db.bali("time.all_nighter_stress", 6)], "Stay up", do_wait)
		return
	do_wait.call()


# --- Journal / writing / shifts / set builder ------------------------------

func open_journal(tab: String = "jokes") -> void:
	GameSim.tutorial_mark(s, "journal")
	if not s.flags.has("journal_intro"):
		s.flags["journal_intro"] = true
		ui.info("The journal", "The first page, written on the bus:\n\n\"Become a global standup superstar. Sell out arenas. Pick my own openers.\"\n\nThe second page has one joke. It's about rent. It needs work.\n\nJokes are built from pieces: a premise, a setup, and a punchline (plus optional tags, act-outs and callbacks). You find pieces by working, wandering, writing, and sometimes by bombing.", func(): _open_journal_now(tab))
		return
	_open_journal_now(tab)


func _open_journal_now(tab: String) -> void:
	var j := JournalUI.new().setup(ui, tab)
	ui.open(j, 1120)


func open_writing(location_id: String) -> void:
	var v := UiKit.vbox(8)
	v.add_child(UiKit.title("Writing session"))
	v.add_child(UiKit.label("One block. Energy -%d. Choose what to work on:" % db.bali("writing.energy_cost", 8), 18, UiKit.C_DIM))
	var holder: Array = [null]
	var tasks := WritingRules.tasks(s, db, location_id)
	if tasks.is_empty():
		v.add_child(UiKit.label("You don't have any premises to develop yet. Explore, work, and talk to people.", 18))
	for tk in tasks:
		var task: Dictionary = tk
		var run := func():
			ui.close(holder[0])
			var res := GameSim.write(s, db, task, location_id)
			after_action()
			ui.info("Writing", str(res["message"]))
			_refresh_location()
		v.add_child(UiKit.button(str(task["label"]), run, bool(task["enabled"])))
		v.add_child(UiKit.label("     " + str(task["hint"]), 15, UiKit.C_DIM))
	holder[0] = ui.open(v, 900)


func open_shift(shift: Dictionary) -> void:
	var events: Array = shift.get("events", [])
	var choices: Array = []
	_shift_step(events, 0, choices)


func _shift_step(events: Array, i: int, choices: Array) -> void:
	if i >= events.size():
		var res := GameSim.finish_shift(s, db, choices)
		after_action()
		ui.info("Shift over", str(res["message"]))
		_refresh_location()
		return
	var ev: Dictionary = db.shift_events.get(str(events[i]), {})
	var opts: Array = []
	var chs: Array = ev.get("choices", [])
	for ci in range(chs.size()):
		var idx := ci
		var pick := func():
			choices.append(idx)
			_shift_step(events, i + 1, choices)
		opts.append({"label": str(chs[ci]["text"]), "cb": pick})
	ui.dialog("On shift", str(ev.get("text", "")), opts)


func _refresh_location() -> void:
	if _location_panel != null and is_instance_valid(_location_panel):
		_location_panel.refresh()


func open_set_builder(venue_id: String, commitment_id: String) -> void:
	var venue: Dictionary = db.venues.get(venue_id, {})
	var c: Dictionary = Scheduler.find(s, commitment_id) if commitment_id != "" else {}
	var slot: int = int(c.get("slot_seconds", venue.get("slot_seconds", 180))) if not c.is_empty() else int(venue.get("slot_seconds", 180))
	var aud_id: String = str(c.get("audience", "")) if not c.is_empty() else ""
	if aud_id == "":
		aud_id = str(venue.get("late_audience", venue.get("audience", ""))) if s.block == 3 and venue.has("late_audience") else str(venue.get("audience", ""))
	var aud: Dictionary = db.audiences.get(aud_id, {})
	var v := UiKit.vbox(8)
	v.add_child(UiKit.title(str(venue.get("name", "Set"))))
	var likes: Array = []
	var dislikes: Array = []
	for t in aud.get("topic_prefs", {}):
		if float(aud["topic_prefs"][t]) > 0:
			likes.append(str(t))
		else:
			dislikes.append(str(t))
	v.add_child(UiKit.label("Audience: %s. %s\nLikes: %s. Not into: %s.\nSlot: %ds%s. Fee: $%d. Pay: $%d." % [aud.get("name", "?"), aud.get("desc", ""), ", ".join(PackedStringArray(likes)) if not likes.is_empty() else "anything", ", ".join(PackedStringArray(dislikes)) if not dislikes.is_empty() else "nothing in particular", slot, " (the light goes on when time's up)" if venue_id != "kill_tony" else "", int(venue.get("fee", 0)) if commitment_id == "" else 0, int(c.get("pay", venue.get("pay", 0))) if not c.is_empty() else int(venue.get("pay", 0))], 18))
	var editor := SetEditor.new().setup(SetRules.DEFAULT_ID, slot, venue_id)
	var sc := UiKit.scroll(380)
	sc.add_child(editor)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var holder: Array = [null]
	var go := func():
		if SetRules.jokes_in(s, SetRules.DEFAULT_ID).is_empty():
			ui.info("No set", "Add at least one complete joke to your set first.")
			return
		var res := GameSim.begin_performance(s, db, venue_id, SetRules.DEFAULT_ID, commitment_id)
		if not bool(res["ok"]):
			ui.info("Can't perform", str(res["message"]))
			return
		SaveManager.autosave()
		ui.close_all()
		Game.goto(Game.SCENE_PERFORMANCE)
	var fee: int = int(venue.get("fee", 0)) if commitment_id == "" else 0
	v.add_child(UiKit.button("Go up%s" % (" (pay $%d)" % fee if fee > 0 else ""), go, s.cash >= fee, "Not enough cash for the bar minimum."))
	holder[0] = ui.open(v, 1060)


func start_kill_tony(commitment_id: String) -> void:
	ui.close_all()
	s.flags["active_kill_tony"] = {"commitment_id": commitment_id, "day": s.day, "phase": "waiting"}
	SaveManager.autosave()
	Game.goto(Game.SCENE_KILL_TONY)


# --- Phone / pause / dev ----------------------------------------------------

func open_phone(tab: String = "calendar") -> void:
	var p := PhoneUI.new().setup(self, ui, tab)
	ui.open(p, 1100)


func open_pause() -> void:
	var v := UiKit.vbox(8)
	v.add_child(UiKit.title("Paused"))
	var holder: Array = [null]
	v.add_child(UiKit.button("Resume", func(): ui.close(holder[0])))
	v.add_child(UiKit.button("Save / load", func(): ui.open(SaveUI.new().setup(ui, true), 760)))
	v.add_child(UiKit.button("Settings", func(): ui.open(SettingsUI.new().setup(ui), 860)))
	if Game.is_dev_build():
		v.add_child(UiKit.button("Developer panel (dev build only)", func(): open_dev()))
	v.add_child(UiKit.button("Save and return to title", func():
		SaveManager.autosave()
		Game.goto(Game.SCENE_BOOT)))
	v.add_child(UiKit.button("Save and quit", func():
		SaveManager.autosave()
		get_tree().quit()))
	holder[0] = ui.open(v, 520)


func open_dev() -> void:
	if not Game.is_dev_build():
		return
	ui.open(DevPanel.new().setup(self, ui), 1000)


func _notification(what: int) -> void:
	# Losing focus never advances time; nothing in the district is timed.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and s != null:
		SaveManager.autosave()
