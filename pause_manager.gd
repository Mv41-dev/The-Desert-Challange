
extends Node

func _ready() -> void:

	print("CENA ATUAL: ", get_path())

	print("FILHOS DO PAUSEMANAGER:")

	for child in get_children():
		print(child.name)

	print("PROCURANDO PAUSEMENU:")

	var menu = get_node_or_null("PauseMenu")

	print(menu)
