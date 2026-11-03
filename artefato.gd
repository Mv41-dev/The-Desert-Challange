extends Area2D

const CENA_PERGAMINHO: PackedScene = preload("res://pergaminho.tscn")

@export_group("Fase")
@export_range(0, 5) var fase: int = 0

@export_group("Flutuacao")
@export var altura_flutuacao: float = 6.0
@export var velocidade_flutuacao: float = 2.0

@export_group("Coleta")
@export var altura_subida_coleta: float = 20.0
@export var duracao_coleta: float = 0.35

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D

var coletado: bool = false
var tempo: float = 0.0
var posicao_original: Vector2
var tipo_artefato: String = ""

const ARTEFATOS_POR_FASE: Dictionary = {
	1: "escaravelho",
	2: "calice",
	3: "ankh",
	4: "mascara",
	5: "lapislazulidofarao"
}

func _ready() -> void:
	posicao_original = sprite.position

	var fase_atual: int = fase
	if fase_atual == 0:
		fase_atual = _detectar_fase()

	tipo_artefato = str(ARTEFATOS_POR_FASE.get(fase_atual, "escaravelho"))

	if sprite.sprite_frames.has_animation(tipo_artefato):
		sprite.play(tipo_artefato)
		sprite.stop()
		sprite.frame = 0

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if GerenciadorArtefatos.possui_artefato(tipo_artefato):
		queue_free()
		return

func _process(delta: float) -> void:
	if coletado:
		return

	tempo += delta
	sprite.position.y = posicao_original.y + sin(tempo * velocidade_flutuacao) * altura_flutuacao

func _detectar_fase() -> int:
	var cena: Node = get_tree().current_scene
	if cena == null:
		return 1

	var nome: String = cena.scene_file_path.get_file().get_basename().to_lower()

	if nome.is_empty():
		nome = cena.name.to_lower()

	nome = nome.replace("_", "")

	if nome.begins_with("level"):
		var numero_texto: String = nome.trim_prefix("level")
		if numero_texto.is_valid_int():
			var numero: int = int(numero_texto)
			if numero >= 1 and numero <= 5:
				return numero

	return 1

func _on_body_entered(body: Node2D) -> void:
	if coletado:
		return

	if not body.is_in_group("player"):
		return

	_coletar()

func _coletar() -> void:
	if coletado:
		return

	coletado = true
	GerenciadorArtefatos.coletar_artefato(tipo_artefato)

	if colisao:
		colisao.set_deferred("disabled", true)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		sprite,
		"position:y",
		sprite.position.y - altura_subida_coleta,
		duracao_coleta
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		sprite,
		"modulate:a",
		0.0,
		duracao_coleta
	)

	tween.set_parallel(false)
	tween.tween_callback(_abrir_pergaminho_e_remover)

func _abrir_pergaminho_e_remover() -> void:
	var pergaminho: Node = CENA_PERGAMINHO.instantiate()
	pergaminho.call("configurar_por_artefato", tipo_artefato)
	get_tree().root.add_child(pergaminho)
	queue_free()
