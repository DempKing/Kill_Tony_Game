class_name UiLayer
extends CanvasLayer
## Modal stack, dialogs, toasts and subtitles shared by gameplay scenes.
## While a modal is open, world input (movement/interaction) is suspended.

signal modal_opened
signal modal_closed

var root: Control
var modal_root: Control
var toast_box: VBoxContainer
var subtitle_label: Label
var _stack: Array = []


func _init() -> void:
	layer = 10


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GameSettings.theme
	add_child(root)
	toast_box = VBoxContainer.new()
	toast_box.anchor_top = 1.0
	toast_box.anchor_bottom = 1.0
	toast_box.offset_left = 20
	toast_box.offset_right = 600
	toast_box.offset_top = -320
	toast_box.offset_bottom = -20
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(toast_box)
	subtitle_label = Label.new()
	subtitle_label.anchor_left = 0.5
	subtitle_label.anchor_right = 0.5
	subtitle_label.anchor_top = 1.0
	subtitle_label.anchor_bottom = 1.0
	subtitle_label.offset_left = -400
	subtitle_label.offset_right = 400
	subtitle_label.offset_top = -90
	subtitle_label.offset_bottom = -50
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", GameSettings.font_size(20))
	subtitle_label.add_theme_color_override("font_color", Color("#fff6c0"))
	subtitle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle_label.add_theme_constant_override("outline_size", 6)
	root.add_child(subtitle_label)
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_root)
	Sfx.subtitle.connect(_on_subtitle)
	GameSettings.changed.connect(func(): root.theme = GameSettings.theme)


func has_modal() -> bool:
	return not _stack.is_empty()


## Opens `content` centered over a dimmer. Returns the wrapper.
func open(content: Control, width: int = 900, closable: bool = true) -> Control:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(center)
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(content)
	if closable:
		v.add_child(UiKit.button("Close  [Esc]", func(): close(wrap)))
	wrap.set_meta("closable", closable)
	modal_root.add_child(wrap)
	_stack.append(wrap)
	UiKit.focus_first(content)
	modal_opened.emit()
	return wrap


func close(wrap: Control = null) -> void:
	if _stack.is_empty():
		return
	var target: Control = wrap if wrap != null else _stack.back()
	_stack.erase(target)
	if is_instance_valid(target):
		target.queue_free()
	if not _stack.is_empty():
		UiKit.focus_first(_stack.back())
	modal_closed.emit()


func close_all() -> void:
	while not _stack.is_empty():
		close()


func _unhandled_input(event: InputEvent) -> void:
	if _stack.is_empty():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		var top: Control = _stack.back()
		if bool(top.get_meta("closable", true)):
			close(top)
			get_viewport().set_input_as_handled()


## A dialog with choice buttons. Each option: {label, cb, enabled?, hint?}.
## Choosing closes the dialog first, then runs the callback.
func dialog(title_text: String, body: String, options: Array, closable: bool = false, width: int = 820) -> Control:
	var v := UiKit.vbox(10)
	if title_text != "":
		v.add_child(UiKit.title(title_text))
	if body != "":
		v.add_child(UiKit.label(body, 20))
	var holder: Array = [null]
	for o in options:
		var opt: Dictionary = o
		var cb: Callable = opt.get("cb", Callable())
		var on_press := func():
			close(holder[0])
			if cb.is_valid():
				cb.call()
		var b := UiKit.button(str(opt["label"]), on_press, bool(opt.get("enabled", true)), str(opt.get("hint", "")))
		v.add_child(b)
		if str(opt.get("hint", "")) != "":
			v.add_child(UiKit.label("   " + str(opt["hint"]), 16, UiKit.C_DIM))
	var w := open(v, width, closable)
	holder[0] = w
	return w


func info(title_text: String, body: String, on_close: Callable = Callable()) -> void:
	dialog(title_text, body, [{"label": "OK", "cb": on_close}])


func confirm(title_text: String, body: String, yes_label: String, on_yes: Callable, no_label: String = "Cancel") -> void:
	dialog(title_text, body, [{"label": yes_label, "cb": on_yes}, {"label": no_label, "cb": Callable()}])


func toast(text: String) -> void:
	if text.strip_edges() == "":
		return
	var l := UiKit.label(text, 18)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.12, 0.88)
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", sb)
	bg.add_child(l)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(bg)
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var t := get_tree().create_timer(6.0)
	t.timeout.connect(_free_toast.bind(bg))


func _on_subtitle(text: String) -> void:
	subtitle_label.text = text
	var t := get_tree().create_timer(2.5)
	t.timeout.connect(_clear_subtitle.bind(text))


func _free_toast(bg: Control) -> void:
	if is_instance_valid(bg):
		bg.queue_free()


func _clear_subtitle(text: String) -> void:
	if is_instance_valid(subtitle_label) and subtitle_label.text == text:
		subtitle_label.text = ""
