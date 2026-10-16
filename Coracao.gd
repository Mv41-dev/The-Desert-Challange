extends Control

# O sprite perde vida em tres quadros: cheio -> meio -> vazio.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var cheio_atual: bool = true
var inicializado: bool = false


func _ready() -> void:
	sprite.animation_finished.connect(_ao_terminar_animacao)


func definir_estado(cheio: bool, animar: bool = true) -> void:
	if not inicializado:
		inicializado = true
		cheio_atual = cheio
		sprite.play("cheio" if cheio else "vazio")
		return

	if cheio == cheio_atual:
		return
	cheio_atual = cheio
	if not animar:
		sprite.play("cheio" if cheio else "vazio")
	elif cheio:
		sprite.play("recuperando")
	else:
		sprite.play("perdendo")


func _ao_terminar_animacao() -> void:
	sprite.play("cheio" if cheio_atual else "vazio")
