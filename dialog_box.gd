extends MarginContainer

signal dialog_finished

@export_range(0.01, 0.2, 0.01) var typing_speed: float = 0.045
var texts_to_display: Array[String] = []
var current_index: int = 0
var is_typing: bool = false
var _elapsed: float = 0.0
var _closing: bool = false
var _tween: Tween

@onready var text_label: Label = $text_container/text_label
@onready var indicator: TextureRect = $indicator


func _ready() -> void:
	# Recebe comandos mesmo com o jogo pausado durante a conversa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	indicator.visible = false
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if not texts_to_display.is_empty():
		get_tree().paused = true
		show_text()


func show_text() -> void:
	if current_index >= texts_to_display.size():
		_close_dialog()
		return
	text_label.text = texts_to_display[current_index]
	text_label.visible_characters = 0
	_elapsed = 0.0
	is_typing = true
	indicator.visible = false


func _process(delta: float) -> void:
	if not is_typing or _closing:
		return
	_elapsed += delta
	var characters_to_show: int = int(_elapsed / typing_speed)
	text_label.visible_characters = mini(characters_to_show, text_label.get_total_character_count())
	if text_label.visible_characters >= text_label.get_total_character_count():
		is_typing = false
		indicator.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _closing or not event.is_action_pressed("ui_accept") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if is_typing:
		text_label.visible_characters = -1
		is_typing = false
		indicator.visible = true
	else:
		current_index += 1
		show_text()


func _close_dialog() -> void:
	if _closing:
		return
	_closing = true
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK)
	await _tween.finished
	get_tree().paused = false
	dialog_finished.emit()
	queue_free()
