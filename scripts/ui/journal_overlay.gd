extends CanvasLayer

## JournalOverlay
# Persistent toggle overlay for the journal screen. Listens for the "journal"
# action (bound to J by default) and Esc; the screen opens above any scene.
# Autoload singleton — no class_name.

const JOURNAL_SCENE := "res://scenes/ui/journal_screen.tscn"

var _screen: Control = null
var _open: bool = false

func _ready() -> void:
	layer = 100
	var packed := load(JOURNAL_SCENE)
	if packed == null:
		push_error("JournalOverlay: failed to load %s" % JOURNAL_SCENE)
		return
	_screen = packed.instantiate()
	add_child(_screen)
	_screen.visible = false
	_open = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	if _screen == null:
		return
	_screen.refresh_now()
	_screen.open() if _screen.has_method("open") else null
	if not _screen.has_method("open"):
		_screen.visible = true
	_open = true
	AudioLibrary.play("SFX_UI_OPEN", -8.0)

func close() -> void:
	if _screen == null:
		return
	if _screen.has_method("_on_close"):
		_screen.call("_on_close")
	else:
		_screen.visible = false
	_open = false
	AudioLibrary.play("SFX_UI_CLOSE", -8.0)

func is_open() -> bool:
	return _open
