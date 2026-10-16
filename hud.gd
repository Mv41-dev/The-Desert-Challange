extends CanvasLayer

@export var cena_coracao: PackedScene

var vida_atual: int = 3
var vida_maxima: int = 3

@onready var container_coracoes: HBoxContainer = $HBoxContainer


func _ready() -> void:
	vida_maxima = Global.vida_maxima
	vida_atual = Global.vida_atual
	configurar_coracoes()
	if not Global.vida_alterada.is_connected(atualizar_vida):
		Global.vida_alterada.connect(atualizar_vida)


func configurar_coracoes() -> void:
	for child in container_coracoes.get_children():
		container_coracoes.remove_child(child)
		child.queue_free()
	if cena_coracao == null:
		push_error("HUD: cena Coracao.tscn nao atribuida.")
		return

	for indice in range(vida_maxima):
		var coracao: Node = cena_coracao.instantiate()
		container_coracoes.add_child(coracao)
		coracao.definir_estado(indice < vida_atual, false)


func atualizar_vida(quantidade_vida: int) -> void:
	vida_atual = clampi(quantidade_vida, 0, vida_maxima)
	for indice in range(container_coracoes.get_child_count()):
		var coracao: Node = container_coracoes.get_child(indice)
		coracao.definir_estado(indice < vida_atual)
