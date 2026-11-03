
extends StaticBody2D

@export var velocidade_subida: float = 60.0
@export var abrir_automaticamente: bool = true

var subindo: bool = false


func _ready() -> void:
	# Porta na camada 2.
	collision_layer = 2
	collision_mask = 0

	# Permite movimentar o corpo físico.
	# O Player precisa detectar a camada 2.
	
	if abrir_automaticamente:
		iniciar_abertura()


func _physics_process(delta: float) -> void:
	if subindo:
		# Sobe infinitamente.
		# Não verifica colisões com o cenário.
		global_position.y -= velocidade_subida * delta


func iniciar_abertura() -> void:
	if subindo:
		return

	subindo = true
