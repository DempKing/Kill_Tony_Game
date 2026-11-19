class_name PerformanceRunner
extends PanelContainer
## Drives a PerformanceSim on screen: delivers each joke's lines, shows the
## audience response, then waits (untimed) for the player's choice.
## Emits `reacted` per joke (for stage animation) and `finished` with the summary.

signal reacted(result: Dictionary)
signal choice_made(choice_id: String, message: String)
signal finished(summary: Dictionary)

var sim: PerformanceSim
var _v: VBoxContainer
var _status: Label
var _speech: RichTextLabel
var _reaction: Label
var _buttons: VBoxContainer
var _busy: bool = false


func setup(p_sim: PerformanceSim) -> PerformanceRunner:
	sim = p_sim
	theme = GameSettings.theme
	custom_minimum_size = Vector2(1100, 260)
	_v = UiKit.vbox(6)
	add_child(_v)
	_status = UiKit.label("", 18, UiKit.C_DIM, false)
	_v.add_child(_status)
	_speech = UiKit.rich("", 22)
	_v.add_child(_speech)
	_reaction = UiKit.label("", 22, UiKit.C_WARN)
	_v.add_child(_reaction)
	_buttons = UiKit.vbox(4)
	_v.add_child(_buttons)
	_update_status()
	if sim.queue.is_empty():
		_speech.text = "You step up with nothing coherent prepared."
		_offer([{"id": "_finish", "label": "Say goodnight", "hint": ""}])
	else:
		_speech.text = "You walk up to the mic. The room looks at you."
		_offer([{"id": "_start", "label": "Start your set", "hint": "Nothing here is timed. Take your time with every choice."}])
	return self


func _update_status() -> void:
	var light := " · LIGHT IS ON" if sim.elapsed >= sim.slot_seconds else ""
	_status.text = "%s · %ds / %ds%s · momentum %+d · jokes left %d" % [sim.audience.get("name", ""), int(sim.elapsed), sim.slot_seconds, light, int(sim.momentum), sim.queue.size()]


func _offer(opts: Array) -> void:
	UiKit.clear(_buttons)
	for o in opts:
		var od: Dictionary = o
		var b := UiKit.button(str(od["label"]), func(): _pick(str(od["id"])))
		_buttons.add_child(b)
		if str(od.get("hint", "")) != "":
			_buttons.add_child(UiKit.label("     " + str(od["hint"]), 15, UiKit.C_DIM))
	UiKit.focus_first(_buttons)


func _pick(id: String) -> void:
	if _busy:
		return
	match id:
		"_start", "_next":
			_deliver()
		"_finish":
			finished.emit(sim.finish())
		_:
			var r := sim.choose(id)
			choice_made.emit(id, str(r["message"]))
			_reaction.text = str(r["message"])
			_update_status()
			if sim.has_next():
				_offer([{"id": "_next", "label": "Next bit →", "hint": ""}])
			else:
				_offer([{"id": "_finish", "label": "Walk off", "hint": ""}])


func _deliver() -> void:
	_busy = true
	UiKit.clear(_buttons)
	var res := sim.perform_next()
	var lines: Array = res.get("lines", [])
	var reduced := GameSettings.reduced_motion()
	_reaction.text = ""
	_speech.text = "[i]%s[/i]" % str(lines[0]) if lines.size() > 0 else ""
	if not reduced:
		await get_tree().create_timer(1.1).timeout
	if lines.size() > 1:
		_speech.text += "\n[b]%s[/b]" % str(lines[1])
	if not reduced:
		await get_tree().create_timer(0.7).timeout
	_reaction.text = "%s  (%d/100)" % [res.get("response_label", ""), int(float(res.get("score", 0)))]
	reacted.emit(res)
	_update_status()
	_busy = false
	if sim.ended:
		_reaction.text += "\n" + "\n".join(PackedStringArray(sim.notes.slice(-1)))
		_offer([{"id": "_finish", "label": "Walk off", "hint": ""}])
		return
	var choices := sim.available_choices()
	if choices.is_empty():
		_offer([{"id": "_finish", "label": "Walk off", "hint": ""}] if not sim.has_next() else [{"id": "_next", "label": "Next bit →", "hint": ""}])
	else:
		_offer(choices)
