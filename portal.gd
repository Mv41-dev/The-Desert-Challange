extends Area2D

# Proxima fase configurada individualmente no Inspector do portal.
@export_file("*.tscn") var next_scene_path: String = ""
var _transicao_iniciada: bool = false


func _on_body_entered(body: Node2D) -> void:
	if _transicao_iniciada or not body.is_in_group("player"):
		return
	if not ResourceLoader.exists(next_scene_path):
		push_error("Portal: cena de destino inexistente: " + next_scene_path)
		return
	_transicao_iniciada = true
	set_deferred("monitoring", false)
	# A troca só acontece após o frame de física terminar.
	call_deferred("_trocar_fase")


func _trocar_fase() -> void:
	var erro: Error = get_tree().change_scene_to_file(next_scene_path)
	if erro != OK:
		push_error("Portal: não foi possível carregar o destino: " + next_scene_path)
		_transicao_iniciada = false
		set_deferred("monitoring", true)
