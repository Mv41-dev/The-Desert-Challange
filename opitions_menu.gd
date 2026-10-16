extends Control

@onready var btn_back: Button = $MarginContainer/PanelContainer/VBoxContainer/BtnBack


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_canc"):
		close_options()

func _on_btn_back_pressed() -> void:
	close_options()


func close_options() -> void:
	hide()
