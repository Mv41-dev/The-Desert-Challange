extends Area2D

# @export_file cria um botão super prático no Inspector para escolher o arquivo da próxima cena!
@export_file("*.tscn") var next_scene_path

func _on_body_entered(body):
	if body.name == "Player":
		# call_deferred avisa o Godot para carregar a cena APÓS terminar todos os cálculos de física daquele milissegundo. Evita travamentos!
		call_deferred("change_level")

func change_level():
	if next_scene_path: # Verifica se você preencheu o caminho da cena
		get_tree().change_scene_to_file(next_scene_path)
