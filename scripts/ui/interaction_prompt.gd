class_name InteractionPrompt
extends RefCounted

const FALLBACK_BINDING := "E"
const OUTLINE_COLOR := Color(0.04, 0.03, 0.03, 0.9)

static func binding_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		var key_event := event as InputEventKey
		if key_event.physical_keycode != 0:
			return OS.get_keycode_string(key_event.physical_keycode)
		var event_text := key_event.as_text()
		if not event_text.is_empty():
			return event_text
	return FALLBACK_BINDING

static func configure(label: Label, action: StringName, context: String, color: Color) -> void:
	var binding := binding_label(action)
	label.text = "[%s]" % binding
	if not context.is_empty():
		label.text += " " + context
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 3)
