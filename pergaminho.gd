
extends Area2D

@export var titulo: String = "Curiosidade do Deserto"
@export_multiline var conteudo: String = "Os desertos recebem pouca chuva ao longo do ano. Muitas plantas e animais possuem adaptações especiais para sobreviver à falta de água."

const PERGAMINHO_UI = preload("res://pergaminho_ui.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var jogador_detectado := false
var utilizado := false
var abrindo := false


func _ready() -> void:
	sprite.play("fechado")
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("jogador"):
		return

	if utilizado or abrindo:
		return

	jogador_detectado = true
	abrindo = true

	# Impede que o pergaminho seja ativado novamente.
	utilizado = true

	# Inicia a animação de abertura.
	sprite.play("abrindo")


func _on_animation_finished() -> void:
	if sprite.animation != "abrindo":
		return

	# Esconde o objeto no cenário após a abertura.
	sprite.visible = false

	# Cria a interface do pergaminho.
	var interface = PERGAMINHO_UI.instantiate()

	get_tree().root.add_child(interface)

	# Envia o conteúdo educativo para a interface.
	interface.configurar(titulo, conteudo)

	# Pausa o mundo enquanto o texto está aberto.
	get_tree().paused = true
