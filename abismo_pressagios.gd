
extends Node
class_name AbismoPressagiosLevel6

# THE DESERT CHALLENGE
# ABISMO PRESSAGIOS V5.3
#
# NEW:
# - Opening now shows ONLY "PROLOGO / O ABISMO".
# - No thoughts during the opening cutscene.
# - Player stays almost invisible during the title.
# - Fog and ambient particles continue moving.
# - Movement returns after the darkness fades.
# - Intro thoughts now appear while exploring.
#
# PRESERVED:
# - Cinematic gradient dialogue panel.
# - Animated glowing diamonds.
# - Exploration dialogue progression.
# - Void Necro sightings.
# - Void Necro death reactions.
# - Boss encounter protection.
#
# Attach to existing AbismoPressagios node.


const FALAS_EXPLORACAO: Array[String] = [
	"Onde... eu estou?",
	"Eu... ainda estou vivo?",
	"A última coisa de que me lembro... é da escuridão.",
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

@export_range(0.0, 4.0, 0.1)
var silencio_inicial: float = 0.8

@export_range(1.0, 8.0, 0.1)
var duracao_titulo_prologo: float = 2.6

@export_range(1.0, 40.0, 1.0)
var espera_exploracao_apos_intro: float = 3.0


@export_group("Escuridao da Cutscene")

@export_range(0.0, 0.90, 0.01)
var escurecimento_extra_cutscene: float = 0.68

@export_range(0.0, 0.5, 0.01)
var visibilidade_player_cutscene: float = 0.035

@export_range(0.1, 3.0, 0.05)
var duracao_escurecer_cutscene: float = 0.65

@export_range(0.2, 4.0, 0.05)
var duracao_clarear_cutscene: float = 1.5

@export_range(100, 900, 10)
var camada_sombra_cutscene: int = 500


@export_group("Pensamentos de Exploracao")

@export var mostrar_pensamentos: bool = true

@export_range(0.5, 15.0, 0.5)
var atraso_primeiro_pensamento: float = 3.0

@export_range(8.0, 60.0, 1.0)
var intervalo_entre_pensamentos: float = 22.0

@export_range(0.0, 150.0, 10.0)
var movimento_minimo_primeira_fala: float = 40.0

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
# DIALOGUE INTERFACE
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
# CUTSCENE
# ============================================================

var _camada_escura: CanvasLayer = null
var _sombra_extra: ColorRect = null

var _camada_titulo: CanvasLayer = null
var _cartao_prologo: Control = null
var _sombra_prologo: TextureRect = null

var _label_prologo: Label = null
var _label_nome_prologo: Label = null

var _cutscene_ativa: bool = false
var _pausa_anterior: bool = false

var _player_travado: bool = false
var _player_process_original: bool = true
var _player_physics_original: bool = true
var _player_modulate_original: Color = Color.WHITE

var _processos_atmosfera: Array[Node] = []
var _modos_atmosfera: Array[int] = []

var _hud_canvas: CanvasLayer = null
var _hud_layer_original: int = 0
var _hud_layer_alterado: bool = false


# ============================================================
# EXPLORATION
# ============================================================

var _jogador: Node2D = null
var _ultima_posicao: Vector2 = Vector2.ZERO
var _movimento_acumulado: float = 0.0

var _tempo: float = 0.0
var _tempo_verificacao: float = 0.0
var _tempo_ate_normal: float = 0.0

var _indice_pensamento: int = 0
var _dialogo_ativo: bool = false


# ============================================================
# VOID NECRO EVENTS
# ============================================================

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
	process_mode = Node.PROCESS_MODE_ALWAYS

	_criar_interface()
	_criar_escurecimento_cutscene()
	_criar_cartao_prologo()

	_atualizar_layout()
	_procurar_jogador()

	_tempo_ate_normal = atraso_primeiro_pensamento

	if ativar_cutscene_inicial:
		_iniciar_cutscene()


func _process(delta: float) -> void:
	if get_tree().paused and not _cutscene_ativa:
		return

	_tempo += delta
	_animar_painel()

	if _cutscene_ativa:
		return

	if not mostrar_pensamentos:
		return

	if not is_instance_valid(_jogador):
		_procurar_jogador()

	if not is_instance_valid(_jogador):
		return

	_atualizar_movimento()

	if detectar_void_necros:
		_tempo_verificacao += delta

		if _tempo_verificacao >= intervalo_verificacao:
			_tempo_verificacao = 0.0
			_verificar_void_necros()

	if _boss_final_ativo():
		return

	if _dialogo_ativo:
		return

	if not _fila_especiais.is_empty():
		_iniciar_proximo_especial()
		return

	_tempo_ate_normal -= delta

	if _indice_pensamento >= FALAS_EXPLORACAO.size():
		return

	if _tempo_ate_normal > 0.0:
		return

	# Every exploration dialogue requires movement.
	# Even the first one waits until the player
	# actually starts exploring.
	var minimo_movimento: float = (
		movimento_minimo_primeira_fala
		if _indice_pensamento == 0
		else movimento_minimo_entre_falas
	)

	if _movimento_acumulado < minimo_movimento:
		return

	if _ha_void_necro_perto():
		return

	_iniciar_pensamento_normal()


# ============================================================
# TITLE-ONLY INTRO
# ============================================================

func _iniciar_cutscene() -> void:
	if _cutscene_ativa:
		return

	_cutscene_ativa = true
	_pausa_anterior = get_tree().paused

	_preparar_atmosfera_durante_cutscene()

	get_tree().paused = true

	_executar_cutscene()


func _executar_cutscene() -> void:
	var tentativas: int = 0

	while (
		not is_instance_valid(_jogador)
		and tentativas < 60
	):
		_procurar_jogador()

		if is_instance_valid(_jogador):
			break

		tentativas += 1
		await get_tree().process_frame

	if not is_inside_tree():
		return

	if not is_instance_valid(_jogador):
		push_warning(
			"ABISMO: Player nao encontrado."
		)

		_encerrar_cutscene()
		return

	_travar_jogador()

	# Hide the standing player and darken the world.
	# Fog and particles remain above this overlay.
	await _animar_visual_cutscene(
		true,
		duracao_escurecer_cutscene
	)

	if not is_inside_tree():
		return

	await _esperar(silencio_inicial)

	if not is_inside_tree():
		return

	# No intro thoughts.
	# Only the cinematic prologue title.
	await _mostrar_titulo_prologo()

	if not is_inside_tree():
		return

	# Reveal the player's normal appearance.
	await _animar_visual_cutscene(
		false,
		duracao_clarear_cutscene
	)

	if not is_inside_tree():
		return

	_encerrar_cutscene()


# ============================================================
# LOCK AND RESTORE PLAYER
# ============================================================

func _travar_jogador() -> void:
	if not is_instance_valid(_jogador):
		return

	if _player_travado:
		return

	_player_process_original = (
		_jogador.is_processing()
	)

	_player_physics_original = (
		_jogador.is_physics_processing()
	)

	_player_modulate_original = _jogador.modulate

	if _jogador is CharacterBody2D:
		(_jogador as CharacterBody2D).velocity = Vector2.ZERO

	_jogador.set_process(false)
	_jogador.set_physics_process(false)

	_player_travado = true


func _destravar_jogador() -> void:
	if not _player_travado:
		return

	_player_travado = false

	if not is_instance_valid(_jogador):
		return

	_jogador.modulate = _player_modulate_original

	_jogador.set_process(
		_player_process_original
	)

	_jogador.set_physics_process(
		_player_physics_original
	)


# ============================================================
# ATMOSPHERE CONTINUES DURING PAUSE
# ============================================================

func _registrar_no_atmosfera(no: Node) -> void:
	if not is_instance_valid(no):
		return

	if _processos_atmosfera.has(no):
		return

	_processos_atmosfera.append(no)
	_modos_atmosfera.append(no.process_mode)

	no.process_mode = Node.PROCESS_MODE_ALWAYS


func _preparar_atmosfera_durante_cutscene() -> void:
	var cena: Node = get_tree().current_scene

	# SceneTree.current_scene may still be changing
	# during the new level's initialization.
	if not is_instance_valid(cena):
		cena = get_parent()

	if not is_instance_valid(cena):
		return

	for no: Node in cena.find_children(
		"*", "Node", true, false
	):
		if no == self:
			continue

		# Actual Level 6 ambience system.
		if (
			no.has_method("_animar_efeitos")
			and no.has_method("_montar_efeitos")
		):
			_registrar_no_atmosfera(no)

		# Separate atmospheric particle emitters.
		if no is GPUParticles2D or no is CPUParticles2D:
			var nome: String = no.name.to_lower()

			if (
				nome.contains("voidparticles")
				or nome.contains("nevoa")
				or nome.contains("fog")
				or nome.contains("ambient")
				or nome.contains("cinza")
			):
				_registrar_no_atmosfera(no)

	# Level 6 atmosphere can use the HUD CanvasLayer
	# to display its world-anchored fog.
	_hud_canvas = cena.find_child(
		"HUD", true, false
	) as CanvasLayer

	if is_instance_valid(_hud_canvas):
		_hud_layer_original = _hud_canvas.layer

		if _hud_canvas.layer <= camada_sombra_cutscene:
			_hud_canvas.layer = 920
			_hud_layer_alterado = true


func _restaurar_atmosfera() -> void:
	for i: int in range(_processos_atmosfera.size()):
		var no: Node = _processos_atmosfera[i]

		if is_instance_valid(no):
			no.process_mode = _modos_atmosfera[i]

	_processos_atmosfera.clear()
	_modos_atmosfera.clear()

	if _hud_layer_alterado:
		if is_instance_valid(_hud_canvas):
			_hud_canvas.layer = _hud_layer_original

	_hud_layer_alterado = false


# ============================================================
# DARKNESS AND PLAYER FADE
# ============================================================

func _criar_escurecimento_cutscene() -> void:
	_camada_escura = CanvasLayer.new()
	_camada_escura.name = "EscuridaoTemporaria"
	_camada_escura.layer = camada_sombra_cutscene
	_camada_escura.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(_camada_escura)

	_sombra_extra = ColorRect.new()
	_sombra_extra.name = "SombraIntroducao"
	_sombra_extra.color = Color(0.0, 0.0, 0.0, 0.0)
	_sombra_extra.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_camada_escura.add_child(_sombra_extra)


func _animar_visual_cutscene(
	escurecer: bool,
	duracao: float
) -> void:
	var alpha_sombra: float = (
		escurecimento_extra_cutscene
		if escurecer else 0.0
	)

	var cor_player: Color = _player_modulate_original

	if escurecer:
		cor_player.a *= visibilidade_player_cutscene

	var tween: Tween = create_tween()
	tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	tween.tween_property(
		_sombra_extra,
		"color:a",
		alpha_sombra,
		duracao
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	if is_instance_valid(_jogador):
		tween.parallel().tween_property(
			_jogador,
			"modulate",
			cor_player,
			duracao
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_IN_OUT
		)

	await tween.finished


func _encerrar_cutscene() -> void:
	if is_instance_valid(_sombra_extra):
		_sombra_extra.color.a = 0.0

	_destravar_jogador()
	_restaurar_atmosfera()

	get_tree().paused = _pausa_anterior
	_cutscene_ativa = false

	# Exploration dialogue begins AFTER the prologue.
	_tempo_ate_normal = maxf(
		atraso_primeiro_pensamento,
		espera_exploracao_apos_intro
	)

	_movimento_acumulado = 0.0
	_tempo_verificacao = 0.0

	if is_instance_valid(_jogador):
		_ultima_posicao = _jogador.global_position


# ============================================================
# PROLOGUE TITLE
# ============================================================

func _criar_cartao_prologo() -> void:
	_camada_titulo = CanvasLayer.new()
	_camada_titulo.name = "TituloPrologoAbismo"
	_camada_titulo.layer = 1700
	_camada_titulo.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(_camada_titulo)

	_cartao_prologo = Control.new()
	_cartao_prologo.name = "CartaoPrologo"
	_cartao_prologo.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	_cartao_prologo.modulate.a = 0.0

	_camada_titulo.add_child(_cartao_prologo)

	_sombra_prologo = TextureRect.new()
	_sombra_prologo.texture = _criar_textura_degrade()
	_sombra_prologo.stretch_mode = (
		TextureRect.STRETCH_SCALE
	)
	_sombra_prologo.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_cartao_prologo.add_child(_sombra_prologo)

	_label_prologo = Label.new()
	_label_prologo.text = titulo_prologo
	_label_prologo.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_label_prologo.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	_label_prologo.add_theme_font_size_override(
		"font_size", 20
	)
	_label_prologo.add_theme_color_override(
		"font_color",
		Color(0.62, 0.70, 0.87)
	)

	_cartao_prologo.add_child(_label_prologo)

	_label_nome_prologo = Label.new()
	_label_nome_prologo.text = nome_prologo
	_label_nome_prologo.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_label_nome_prologo.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	_label_nome_prologo.add_theme_font_size_override(
		"font_size", 43
	)
	_label_nome_prologo.add_theme_color_override(
		"font_color",
		Color(0.95, 0.96, 1.0)
	)

	_cartao_prologo.add_child(_label_nome_prologo)


func _mostrar_titulo_prologo() -> void:
	if not is_instance_valid(_cartao_prologo):
		return

	_label_prologo.text = titulo_prologo
	_label_nome_prologo.text = nome_prologo

	_cartao_prologo.modulate.a = 0.0

	var entrada: Tween = create_tween()
	entrada.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

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
	saida.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

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


# ============================================================
# PLAYER / MOVEMENT
# ============================================================

func _procurar_jogador() -> void:
	var encontrado: Node = (
		get_tree().get_first_node_in_group("player")
	)

	if encontrado is Node2D:
		_jogador = encontrado as Node2D
		_ultima_posicao = _jogador.global_position
		_movimento_acumulado = 0.0


func _atualizar_movimento() -> void:
	var posicao: Vector2 = _jogador.global_position

	var distancia: float = posicao.distance_to(
		_ultima_posicao
	)

	if distancia < 1500.0:
		_movimento_acumulado += distancia

	_ultima_posicao = posicao


func _boss_final_ativo() -> bool:
	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		return false

	return bool(
		cena.get_meta(
			&"level6_boss_active",
			false
		)
	)


# ============================================================
# EXPLORATION DIALOGUES
# ============================================================

func _iniciar_pensamento_normal() -> void:
	if _indice_pensamento >= FALAS_EXPLORACAO.size():
		return

	var frase: String = (
		FALAS_EXPLORACAO[_indice_pensamento]
	)

	_indice_pensamento += 1
	_movimento_acumulado = 0.0

	var aumento: float = minf(
		float(_indice_pensamento) * 1.5,
		12.0
	)

	_tempo_ate_normal = (
		intervalo_entre_pensamentos + aumento
	)

	_iniciar_dialogo(
		frase,
		tempo_frase,
		false
	)


# ============================================================
# VOID NECRO DETECTION
# ============================================================

func _verificar_void_necros() -> void:
	var inimigos: Array[Node] = (
		get_tree().get_nodes_in_group(
			"void_necromancer_active"
		)
	)

	for inimigo: Node in inimigos:
		if not is_instance_valid(inimigo):
			continue

		if inimigo.is_queued_for_deletion():
			continue

		if not (inimigo is Node2D):
			continue

		var id: int = inimigo.get_instance_id()

		if not _voids_registrados.has(id):
			_voids_registrados[id] = true

			if inimigo.has_signal("died"):
				var callback: Callable = Callable(
					self,
					"_ao_void_necro_morrer"
				).bind(id)

				if not inimigo.is_connected(
					"died",
					callback
				):
					inimigo.connect(
						"died",
						callback
					)

		var estado: Variant = inimigo.get("state")

		# Void Necro V5: HUNTING = 3.
		if not (estado is int):
			continue

		if int(estado) != 3:
			continue

		if _voids_vistos.has(id):
			continue

		if not _inimigo_realmente_visivel(
			inimigo as Node2D
		):
			continue

		_voids_vistos[id] = true
		_total_encontrados += 1

		_ao_ver_void_necro()


func _inimigo_realmente_visivel(
	inimigo: Node2D
) -> bool:
	if not is_instance_valid(_jogador):
		return false

	if not inimigo.visible:
		return false

	if (
		_jogador.global_position.distance_to(
			inimigo.global_position
		) > distancia_maxima_visao
	):
		return false

	var tela: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var canvas: Transform2D = (
		get_viewport().get_canvas_transform()
	)

	var posicao_tela: Vector2 = (
		canvas * inimigo.global_position
	)

	var margem: float = 25.0

	return (
		posicao_tela.x >= -margem
		and posicao_tela.x <= tela.x + margem
		and posicao_tela.y >= -margem
		and posicao_tela.y <= tela.y + margem
	)


func _ha_void_necro_perto() -> bool:
	if not detectar_void_necros:
		return false

	if not is_instance_valid(_jogador):
		return false

	for inimigo: Node in get_tree().get_nodes_in_group(
		"void_necromancer_active"
	):
		if not is_instance_valid(inimigo):
			continue

		if not (inimigo is Node2D):
			continue

		if not (inimigo as Node2D).visible:
			continue

		var estado: Variant = inimigo.get("state")

		if not (estado is int):
			continue

		if int(estado) != 3:
			continue

		if (
			_jogador.global_position.distance_to(
				(inimigo as Node2D).global_position
			) < 360.0
		):
			return true

	return false


# ============================================================
# VOID NECRO ENCOUNTERS
# ============================================================

func _ao_ver_void_necro() -> void:
	if _total_encontrados == 1:
		_agendar_especial(
			"primeiro_void",
			"O que... É AQUILO?!",
			3.3
		)

	elif _total_encontrados == 2:
		_agendar_especial(
			"segundo_void",
			"Outro?! Então não era o único...",
			3.2
		)

	if (
		_total_mortos >= 2
		and not _reaparicao_apos_dois
	):
		_reaparicao_apos_dois = true

		_agendar_especial(
			"reaparicao_apos_dois",
			"Mesmo depois de destruí-los... ainda há mais?",
			3.6
		)


# ============================================================
# VOID NECRO DEATHS
# ============================================================

func _ao_void_necro_morrer(id: int) -> void:
	if _voids_mortos.has(id):
		return

	_voids_mortos[id] = true
	_total_mortos += 1

	match _total_mortos:
		1:
			_agendar_especial(
				"primeira_morte",
				"Ele... se desfez na escuridão?",
				3.4
			)

		2:
			_agendar_especial(
				"segunda_morte",
				"Eles são feitos de escuridão...\nou foram consumidos por ela?",
				4.3,
				true
			)

		4:
			_agendar_especial(
				"quarta_morte",
				"Quantos mais existem...?",
				3.7
			)


# ============================================================
# SPECIAL EVENT QUEUE
# ============================================================

func _agendar_especial(
	id: String,
	frase: String,
	duracao: float,
	prioritario: bool = false
) -> void:
	if _eventos_agendados.has(id):
		return

	_eventos_agendados[id] = true

	var evento: Dictionary = {
		"frase": frase,
		"duracao": duracao
	}

	if prioritario:
		_fila_especiais.push_front(evento)
	else:
		_fila_especiais.append(evento)


func _iniciar_proximo_especial() -> void:
	if _dialogo_ativo:
		return

	if _fila_especiais.is_empty():
		return

	var evento: Dictionary = (
		_fila_especiais.pop_front()
	)

	_tempo_ate_normal = maxf(
		_tempo_ate_normal,
		pausa_normal_apos_evento
	)

	_iniciar_dialogo(
		String(evento["frase"]),
		float(evento["duracao"]),
		true
	)


# ============================================================
# DIALOGUE CONTROLLER
# ============================================================

func _iniciar_dialogo(
	frase: String,
	tempo_visivel: float,
	especial: bool
) -> void:
	if _dialogo_ativo:
		return

	_rodar_dialogo(
		frase,
		tempo_visivel,
		especial
	)


func _rodar_dialogo(
	frase: String,
	tempo_visivel: float,
	especial: bool
) -> void:
	if _dialogo_ativo:
		return

	if not is_instance_valid(_painel):
		return

	_dialogo_ativo = true
	_texto.text = frase

	if especial:
		_texto.add_theme_color_override(
			"font_color",
			Color(1.0, 0.87, 0.92)
		)
	else:
		_texto.add_theme_color_override(
			"font_color",
			Color(0.94, 0.95, 1.0)
		)

	_painel.modulate.a = 0.0

	var entrada: Tween = create_tween()
	entrada.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	entrada.tween_property(
		_painel,
		"modulate:a",
		1.0,
		duracao_fade
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)

	await entrada.finished

	if not is_inside_tree():
		return

	await _esperar(tempo_visivel)

	if not is_inside_tree():
		return

	var saida: Tween = create_tween()
	saida.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	saida.tween_property(
		_painel,
		"modulate:a",
		0.0,
		duracao_fade
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN
	)

	await saida.finished
	_dialogo_ativo = false


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(
		maxf(0.01, segundos),
		true
	).timeout


# ============================================================
# DIALOGUE INTERFACE
# ============================================================

func _criar_interface() -> void:
	_camada = CanvasLayer.new()
	_camada.name = "DialogosCinematicosAbismo"
	_camada.layer = 1600
	_camada.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(_camada)

	_painel = Control.new()
	_painel.name = "PainelTranslucido"
	_painel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	_painel.modulate.a = 0.0

	_camada.add_child(_painel)

	_fundo = TextureRect.new()
	_fundo.name = "DegradeEscuro"
	_fundo.texture = _criar_textura_degrade()
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR
	)
	_fundo.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_painel.add_child(_fundo)

	_linha_esquerda = Line2D.new()
	_linha_esquerda.width = 1.4
	_linha_esquerda.default_color = Color(
		0.62, 0.72, 0.95, 0.52
	)
	_painel.add_child(_linha_esquerda)

	_linha_direita = Line2D.new()
	_linha_direita.width = 1.4
	_linha_direita.default_color = Color(
		0.62, 0.72, 0.95, 0.52
	)
	_painel.add_child(_linha_direita)

	_halo_esquerdo = _criar_losango(
		16.0,
		Color(0.50, 0.65, 1.0, 0.12)
	)

	_halo_direito = _criar_losango(
		16.0,
		Color(0.50, 0.65, 1.0, 0.12)
	)

	_ponto_esquerdo = _criar_losango(
		6.0,
		Color(0.68, 0.80, 1.0, 1.0)
	)

	_ponto_direito = _criar_losango(
		6.0,
		Color(0.68, 0.80, 1.0, 1.0)
	)

	_texto = Label.new()
	_texto.name = "Pensamento"

	_texto.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_texto.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	_texto.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_texto.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_texto.add_theme_font_size_override(
		"font_size",
		tamanho_fonte
	)

	_texto.add_theme_color_override(
		"font_color",
		Color(0.94, 0.95, 1.0)
	)

	_texto.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.9)
	)

	_texto.add_theme_constant_override(
		"shadow_offset_y",
		2
	)

	_painel.add_child(_texto)

	if not get_viewport().size_changed.is_connected(
		_atualizar_layout
	):
		get_viewport().size_changed.connect(
			_atualizar_layout
		)


func _criar_losango(
	raio: float,
	cor: Color
) -> Polygon2D:
	var losango: Polygon2D = Polygon2D.new()

	losango.polygon = PackedVector2Array([
		Vector2(0.0, -raio),
		Vector2(raio, 0.0),
		Vector2(0.0, raio),
		Vector2(-raio, 0.0)
	])

	losango.color = cor
	_painel.add_child(losango)

	return losango


# ============================================================
# GRADIENT TEXTURE
# ============================================================

func _criar_textura_degrade() -> Texture2D:
	var largura: int = 256
	var altura: int = 90

	var imagem: Image = Image.create(
		largura,
		altura,
		false,
		Image.FORMAT_RGBA8
	)

	for y: int in range(altura):
		for x: int in range(largura):
			var fx: float = (
				float(x) / float(largura - 1)
			)

			var fy: float = (
				float(y) / float(altura - 1)
			)

			var horizontal: float = (
				smoothstep(0.0, 0.17, fx)
				* (
					1.0 - smoothstep(
						0.83, 1.0, fx
					)
				)
			)

			var vertical: float = (
				smoothstep(0.0, 0.24, fy)
				* (
					1.0 - smoothstep(
						0.76, 1.0, fy
					)
				)
			)

			var alpha: float = (
				horizontal
				* vertical
				* opacidade_fundo
			)

			var luz: float = (
				0.012
				+ (1.0 - fy) * 0.019
			)

			imagem.set_pixel(
				x, y,
				Color(
					luz,
					luz * 1.05,
					0.038 + luz,
					alpha
				)
			)

	return ImageTexture.create_from_image(imagem)


# ============================================================
# LAYOUT
# ============================================================

func _atualizar_layout() -> void:
	var tela: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	if is_instance_valid(_sombra_extra):
		_sombra_extra.position = Vector2.ZERO
		_sombra_extra.size = tela

	if is_instance_valid(_painel):
		var largura: float = minf(
			tela.x * 0.82,
			1100.0
		)

		var altura: float = clampf(
			tela.y * 0.17,
			115.0,
			170.0
		)

		_painel.size = Vector2(
			largura, altura
		)

		_painel.position = Vector2(
			(tela.x - largura) * 0.5,
			tela.y * 0.72
		)

		_fundo.position = Vector2.ZERO
		_fundo.size = _painel.size

		_texto.position = Vector2(
			largura * 0.10,
			10.0
		)

		_texto.size = Vector2(
			largura * 0.80,
			altura - 20.0
		)

		var meio: float = altura * 0.5

		var esquerda: Vector2 = Vector2(
			largura * 0.055,
			meio
		)

		var direita: Vector2 = Vector2(
			largura * 0.945,
			meio
		)

		_ponto_esquerdo.position = esquerda
		_ponto_direito.position = direita

		_halo_esquerdo.position = esquerda
		_halo_direito.position = direita

		_linha_esquerda.points = PackedVector2Array([
			Vector2(
				largura * 0.01,
				meio
			),
			Vector2(
				largura * 0.037,
				meio
			)
		])

		_linha_direita.points = PackedVector2Array([
			Vector2(
				largura * 0.963,
				meio
			),
			Vector2(
				largura * 0.99,
				meio
			)
		])

	if is_instance_valid(_cartao_prologo):
		var largura_titulo: float = minf(
			tela.x * 0.84,
			950.0
		)

		var altura_titulo: float = 245.0

		_cartao_prologo.position = Vector2(
			(tela.x - largura_titulo) * 0.5,
			(tela.y - altura_titulo) * 0.5
		)

		_cartao_prologo.size = Vector2(
			largura_titulo,
			altura_titulo
		)

		_sombra_prologo.position = Vector2.ZERO
		_sombra_prologo.size = _cartao_prologo.size

		_label_prologo.position = Vector2(
			0.0,
			42.0
		)

		_label_prologo.size = Vector2(
			largura_titulo,
			43.0
		)

		_label_nome_prologo.position = Vector2(
			0.0,
			90.0
		)

		_label_nome_prologo.size = Vector2(
			largura_titulo,
			95.0
		)


func _animar_painel() -> void:
	if not animar_detalhes:
		return

	if is_instance_valid(_ponto_esquerdo):
		_ponto_esquerdo.modulate.a = (
			0.72
			+ 0.22 * sin(_tempo * 2.0)
		)

	if is_instance_valid(_ponto_direito):
		_ponto_direito.modulate.a = (
			0.72
			+ 0.22 * sin(
				_tempo * 2.0 + 1.6
			)
		)

	if is_instance_valid(_halo_esquerdo):
		_halo_esquerdo.scale = Vector2.ONE * (
			1.0
			+ 0.13 * sin(_tempo * 1.5)
		)

	if is_instance_valid(_halo_direito):
		_halo_direito.scale = Vector2.ONE * (
			1.0
			+ 0.13 * sin(
				_tempo * 1.5 + 1.3
			)
		)


# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
	if _cutscene_ativa:
		_destravar_jogador()
		_restaurar_atmosfera()

		get_tree().paused = _pausa_anterior
		_cutscene_ativa = false

	var viewport: Viewport = get_viewport()

	if viewport.size_changed.is_connected(
		_atualizar_layout
	):
		viewport.size_changed.disconnect(
			_atualizar_layout
		)
