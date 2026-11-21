
extends Node
class_name AbismoPressagiosLevel6

# THE DESERT CHALLENGE
# ABISMO PRESSAGIOS V5
#
# NEW:
# - Intro cutscene when Level 6 begins.
# - Player and game world pause during intro.
# - Three introductory thoughts.
# - Cinematic PROLOGUE / THE ABYSS title.
# - Gameplay resumes automatically.
# - Exploration dialogue starts AFTER the intro.
#
# PRESERVED:
# - Existing exploration thoughts, without intro repeats.
# - Special dialogue for Void Necro encounters.
# - Death counting through the "died" signal.
# - World-space enemy visibility detection.
# - Gradient dialogue panel and luminous diamonds.
# - King Necro boss protection.
#
# Attach to the EXISTING AbismoPressagios node.
# No modifications required in Player or enemy scripts.

const FALAS_EXPLORACAO: Array[String] = [
	"Isto não se parece com as ruínas de cima.",
	"Quem construiria algo tão fundo?",
	"Há caminhos demais para um lugar esquecido.",
	"Aquela armadilha... alguém a colocou ali.",
	"Mas por que ela me trouxe até aqui?",
	"Se o selo existia para manter algo preso... onde estou agora?",
	"Há marcas nas pedras. Alguém passou por aqui.",
	"Quanto mais eu subo, menos isso parece uma saída.",
	"Será que a passagem ainda está aberta?",
	"Eu preciso voltar. Antes que seja tarde."
]


@export_group("Cutscene Inicial")
@export var ativar_cutscene_inicial: bool = true

@export var titulo_prologo: String = "PRÓLOGO"
@export var nome_prologo: String = "O ABISMO"

@export_range(0.5, 5.0, 0.1)
var silencio_inicial: float = 1.0

@export_range(1.0, 6.0, 0.1)
var duracao_pensamento_intro: float = 2.1

@export_range(0.0, 3.0, 0.1)
var pausa_entre_pensamentos_intro: float = 0.55

@export_range(1.0, 8.0, 0.1)
var duracao_titulo_prologo: float = 2.4

@export_range(5.0, 40.0, 1.0)
var espera_exploracao_apos_intro: float = 17.0


@export_group("Pensamentos de Exploracao")
@export var mostrar_pensamentos: bool = true

@export_range(0.5, 15.0, 0.5)
var atraso_primeiro_pensamento: float = 3.0

@export_range(8.0, 60.0, 1.0)
var intervalo_entre_pensamentos: float = 22.0

@export_range(0.0, 500.0, 10.0)
var movimento_minimo_entre_falas: float = 110.0

@export_range(1.0, 8.0, 0.1)
var tempo_frase: float = 3.2

@export_range(1.0, 8.0, 0.1)
var tempo_frase_especial: float = 3.5


@export_group("Deteccao Void Necro")
@export var detectar_void_necros: bool = true

@export_range(100.0, 1200.0, 20.0)
var distancia_maxima_visao: float = 650.0

@export_range(0.05, 0.5, 0.05)
var intervalo_verificacao: float = 0.15

@export_range(0.0, 15.0, 0.5)
var pausa_normal_apos_evento: float = 8.0


@export_group("Aparencia")
@export_range(18, 38, 1)
var tamanho_fonte: int = 25

@export_range(0.3, 1.0, 0.01)
var opacidade_fundo: float = 0.82

@export_range(0.15, 1.5, 0.05)
var duracao_fade: float = 0.60

@export var animar_detalhes: bool = true


# ============================================================
# UI VARIABLES
# ============================================================

var _camada: CanvasLayer = null

var _painel: Control = null
var _fundo: TextureRect = null
var _texto: Label = null

var _ponto_esquerdo: Polygon2D = null
var _ponto_direito: Polygon2D = null

var _halo_esquerdo: Polygon2D = null
var _halo_direito: Polygon2D = null

var _linha_esquerda: Line2D = null
var _linha_direita: Line2D = null


# ============================================================
# PROLOGUE TITLE VARIABLES
# ============================================================

var _cartao_prologo: Control = null
var _sombra_prologo: TextureRect = null

var _label_prologo: Label = null
var _label_nome_prologo: Label = null

var _linha_titulo_esquerda: Line2D = null
var _linha_titulo_direita: Line2D = null

var _cutscene_ativa: bool = false
var _pausa_anterior: bool = false

var _player_process_original: bool = true
var _player_physics_original: bool = true
var _player_travado: bool = false


# ============================================================
# GAMEPLAY VARIABLES
# ============================================================

var _jogador: Node2D = null
var _ultima_posicao: Vector2 = Vector2.ZERO
var _movimento_acumulado: float = 0.0

var _tempo: float = 0.0
var _tempo_verificacao: float = 0.0
var _tempo_ate_normal: float = 0.0

var _indice_pensamento: int = 0
var _dialogo_ativo: bool = false

var _voids_registrados: Dictionary = {}
var _voids_vistos: Dictionary = {}
var _voids_mortos: Dictionary = {}
var _eventos_agendados: Dictionary = {}

var _total_encontrados: int = 0
var _total_mortos: int = 0

var _reaparicao_apos_dois: bool = false
var _fila_especiais: Array[Dictionary] = []


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	# Essential: this script must continue processing
	# while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_criar_interface()
	_criar_cartao_prologo()
	_procurar_jogador()

	_tempo_ate_normal = atraso_primeiro_pensamento

	if ativar_cutscene_inicial:
		_iniciar_cutscene()


func _process(delta: float) -> void:
	# Normal dialogue logic must not advance when
	# the player pauses the game.
	if get_tree().paused and not _cutscene_ativa:
		return

	_tempo += delta

	_animar_painel()

	# Do not show exploration thoughts or Void
	# reactions during the opening cutscene.
	if _cutscene_ativa:
		return

	if not mostrar_pensamentos:
		return

	if not is_instance_valid(_jogador):
		_procurar_jogador()

	if not is_instance_valid(_jogador):
		return

	_atualizar_movimento()

	# Register enemies and connect real death signals.
	if detectar_void_necros:
		_tempo_verificacao += delta

		if _tempo_verificacao >= intervalo_verificacao:
			_tempo_verificacao = 0.0
			_verificar_void_necros()

	# Avoid dialogue during the King's final phases.
	if _boss_final_ativo():
		return

	if _dialogo_ativo:
		return

	# Special reactions always come first.
	if not _fila_especiais.is_empty():
		_iniciar_proximo_especial()
		return

	_tempo_ate_normal -= delta

	if _indice_pensamento >= FALAS_EXPLORACAO.size():
		return

	if _tempo_ate_normal > 0.0:
		return

	if (
		_indice_pensamento > 0
		and _movimento_acumulado
		< movimento_minimo_entre_falas
	):
		return

	if _ha_void_necro_perto():
		return

	_iniciar_pensamento_normal()


# ============================================================
# INTRO CUTSCENE
# ============================================================

func _iniciar_cutscene() -> void:
	if _cutscene_ativa:
		return

	_cutscene_ativa = true
	_pausa_anterior = get_tree().paused

	_travar_jogador()

	# Pauses the enemies and all regular gameplay.
	# The dialogue UI continues because it uses
	# PROCESS_MODE_ALWAYS and pause-aware tweens.
	get_tree().paused = true

	_rodar_cutscene()


func _travar_jogador() -> void:
	if not is_instance_valid(_jogador):
		return

	_player_process_original = _jogador.is_processing()
	_player_physics_original = (
		_jogador.is_physics_processing()
	)

	if _jogador is CharacterBody2D:
		var personagem: CharacterBody2D = (
			_jogador as CharacterBody2D
		)
		personagem.velocity = Vector2.ZERO

	_jogador.set_process(false)
	_jogador.set_physics_process(false)

	_player_travado = true


func _destravar_jogador() -> void:
	if not _player_travado:
		return

	_player_travado = false

	if not is_instance_valid(_jogador):
		return

	_jogador.set_process(_player_process_original)
	_jogador.set_physics_process(
		_player_physics_original
	)


func _rodar_cutscene() -> void:
	await _esperar(silencio_inicial)

	if not is_inside_tree():
		return

	# Waking up after the fall.
	await _rodar_dialogo(
		"Eu... ainda estou vivo?",
		duracao_pensamento_intro,
		false
	)

	await _esperar(pausa_entre_pensamentos_intro)

	if not is_inside_tree():
		return

	# Memories of the corruption.
	await _rodar_dialogo(
		"A última coisa de que me lembro...\né da escuridão.",
		duracao_pensamento_intro + 0.4,
		false
	)

	await _esperar(pausa_entre_pensamentos_intro + 0.4)

	if not is_inside_tree():
		return

	# The final question leads into the title.
	await _rodar_dialogo(
		"Onde... eu estou?",
		duracao_pensamento_intro,
		false
	)

	await _esperar(0.8)

	if not is_inside_tree():
		return

	# Reveal the prologue title.
	await _mostrar_titulo_prologo()

	if not is_inside_tree():
		return

	_encerrar_cutscene()


func _mostrar_titulo_prologo() -> void:
	if not is_instance_valid(_cartao_prologo):
		return

	_label_prologo.text = titulo_prologo
	_label_nome_prologo.text = nome_prologo

	_cartao_prologo.modulate.a = 0.0

	var entrada: Tween = create_tween()
	entrada.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	entrada.tween_property(
		_cartao_prologo,
		"modulate:a",
		1.0,
		0.75
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)

	await entrada.finished

	await _esperar(duracao_titulo_prologo)

	if not is_inside_tree():
		return

	var saida: Tween = create_tween()
	saida.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	saida.tween_property(
		_cartao_prologo,
		"modulate:a",
		0.0,
		0.80
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN
	)

	await saida.finished


func _encerrar_cutscene() -> void:
	_des travar_jogador_placeholder()


func _des travar_jogador_placeholder() -> void:
	# Replaced below through the final safe-release method.
	pass
