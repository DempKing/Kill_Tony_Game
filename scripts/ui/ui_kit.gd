class_name UiKit
extends RefCounted
## Small helpers for building UI in code with consistent theme, wrapping and
## keyboard/controller focus.

const C_TEXT := Color("#f0ecff")
const C_DIM := Color("#a9a3c4")
const C_GOOD := Color("#8ef0a0")
const C_BAD := Color("#ff8a8a")
const C_WARN := Color("#ffd27a")
const C_ACCENT := Color("#b88cff")


static func label(text: String, size: int = 20, color: Color = C_TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", GameSettings.font_size(size))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120
	return l


static func title(text: String) -> Label:
	return label(text, 30, C_ACCENT, false)


static func rich(text: String, size: int = 19) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", GameSettings.font_size(size))
	r.add_theme_font_size_override("bold_font_size", GameSettings.font_size(size))
	r.custom_minimum_size.x = 200
	return r


static func button(text: String, cb: Callable, enabled: bool = true, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", GameSettings.font_size(19))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = GameSettings.theme
	return p


static func scroll(min_h: int = 300) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, min_h)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## Grabs focus on the first enabled button inside `root` (controller support).
static func focus_first(root: Node) -> void:
	var b := _find_focusable(root)
	if b != null:
		b.call_deferred("grab_focus")


static func _find_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Button and not (c as Button).disabled and (c as Control).is_visible_in_tree():
			return c
		var f := _find_focusable(c)
		if f != null:
			return f
	return null


static func bar_text(value: int, max_v: int = 100, width: int = 10) -> String:
	## Text meter so values never rely on color alone.
	var filled := clampi(int(round(float(value) / max_v * width)), 0, width)
	return "█".repeat(filled) + "░".repeat(width - filled)


static func money(v: int) -> String:
	return ("-$%d" % absi(v)) if v < 0 else ("$%d" % v)
