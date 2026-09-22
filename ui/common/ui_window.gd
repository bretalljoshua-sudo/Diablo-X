class_name UiWindow
extends PanelContainer
## Grundlage aller Fenster: Kopfzeile mit Titel und Schließen-Knopf, Inhalt in body.
## Öffnen und Schließen melden sich über EventBus.ui_window_toggled.

signal opened
signal closed

## Name für EventBus.ui_window_toggled, zum Beispiel &"inventory".
var window_id: StringName = &""
var body: VBoxContainer

var _title_label: Label


func _init(p_window_id: StringName = &"", title: String = "") -> void:
	window_id = p_window_id
	name = String(p_window_id).to_pascal_case() + "Window"
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 8)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"TitleLabel"
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.theme_type_variation = &"FlatButton"
	close_button.text = "✕"
	close_button.tooltip_text = "Schließen (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_window)
	header.add_child(close_button)
	var line := HSeparator.new()
	root.add_child(line)
	body = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)


func set_title(title: String) -> void:
	_title_label.text = title


func is_open() -> bool:
	return visible


func open_window() -> void:
	if visible:
		return
	visible = true
	_on_opened()
	opened.emit()
	EventBus.ui_window_toggled.emit(window_id, true)


func close_window() -> void:
	if not visible:
		return
	visible = false
	_on_closed()
	closed.emit()
	EventBus.ui_window_toggled.emit(window_id, false)


func toggle() -> void:
	if visible:
		close_window()
	else:
		open_window()


## Für Unterklassen: nach dem Öffnen (Inhalt auffrischen, Fokus setzen).
func _on_opened() -> void:
	pass


## Für Unterklassen: nach dem Schließen.
func _on_closed() -> void:
	pass
