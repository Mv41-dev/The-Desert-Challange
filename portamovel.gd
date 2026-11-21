
# THE DESERT CHALLENGE
# PORTAL MOVEL V3.3 - DIALOGO CINEMATOGRAFICO
#
# NOVO:
# - Caixa com degradê e bordas transparentes.
# - Dois pontos luminosos e filamentos laterais.
# - Fade sincronizado com os dialogos.
#
# PRESERVADO:
# - Todos os cinco artefatos.
# - Rotacao exponencial durante as falas.
# - Porta sobe antes da tempestade.
# - Tempestade de 10 segundos.
# - Desaceleracao e nevoa mundial permanente.
# - Escuridao permanente com fade rapido.
# - Integracao com GerenciadorArtefatos.

extends StaticBody2D


@export_group("Portao")
@export_range(3.0, 15.0, 0.1)
var duracao_abertura: float = 7.0

@export var distancia_subida: float = 500.0


@export_group("Deteccao")
@export var distancia_ativacao: float = 175.0
@export var distancia_mensagem: float = 225.0


@export_group("Ritual")
@export var centro_ritual_offset: Vector2 = Vector2(-185.0, 36.0)
@export var raio_selo: float = 58.0
@export var escala_ritual: float = 1.10

@export_range(0.1, 3.0, 0.05)
var pausa_inicio: float = 1.0

@export_range(0.05, 1.0, 0.05)
var intervalo_saida: float = 0.28

@export_range(0.2, 3.0, 0.05)
var duracao_emergir: float = 1.10

@export_range(0.3, 4.0, 0.05)
var duracao_voo_selo: float = 2.0

@export_range(1.0, 10.0, 0.1)
var duracao_giro: float = 5.2

@export_range(0.05, 3.0, 0.05)
var velocidade_giro_inicial: float = 0.35

@export_range(1.0, 15.0, 0.1)
var velocidade_giro_final: float = 6.5

@export_range(0.2, 3.0, 0.05)
var duracao_colapso: float = 1.1


@export_group("Giro Durante Dialogos")
@export_range(0.1, 5.0, 0.05)
var atraso_giro_apos_alinhamento: float = 1.0

@export_range(2.0, 35.0, 0.5)
var duracao_aceleracao_exponencial: float = 15.0

@export_range(1.0, 3.0, 0.05)
var expoente_aceleracao: float = 1.55


@export_group("Camera Cinematica")
@export var usar_camera_ritual: bool = true

@export_range(0.2, 3.0, 0.05)
var duracao_camera_entrada: float = 1.2

@export_range(1.0, 1.8, 0.01)
var zoom_camera_ritual: float = 1.08

@export_range(0.0, 1.0, 0.05)
var fracao_pan_camera: float = 0.22

@export_range(0.0, 300.0, 5.0)
var pan_maximo_camera: float = 80.0

@export_range(-250.0, 100.0, 5.0)
var offset_vertical_camera: float = -105.0

@export_range(0.2, 3.0, 0.05)
var duracao_camera_saida: float = 1.2

@export_range(0.0, 1.0, 0.05)
var progresso_porta_restaurar_camera: float = 0.32


@export_group("Texto Cinematografico")
@export var tamanho_fonte: int = 20

@export_range(0.1, 1.5, 0.05)
var fade_texto: float = 0.35

@export_range(1.0, 5.0, 0.1)
var tempo_texto: float = 2.7

@export_range(0.0, 1.0, 0.05)
var opacidade_caixa: float = 0.88


@export_group("Tempestade Negra")
@export var ativar_vento_negro: bool = true

@export_range(0.3, 4.0, 0.1)
var atraso_nevoa_apos_abertura: float = 1.6

@export_range(3.0, 20.0, 0.5)
var duracao_rajada_forte: float = 10.0

@export_range(1.0, 8.0, 0.1)
var duracao_acalmar: float = 3.5

@export_range(1.5, 8.0, 0.1)
var tempo_liberar_apos_rajada: float = 3.2

@export_range(200.0, 1000.0, 20.0)
var velocidade_vento: float = 520.0

@export_range(0.2, 1.0, 0.05)
var densidade_vento: float = 0.85

@export_range(0.10, 0.90, 0.01)
var densidade_nevoa_permanente: float = 0.55

@export_range(0.02, 0.40, 0.01)
var velocidade_nevoa_permanente: float = 0.10

@export_range(0.0, 15.0, 0.5)
var forca_tremor_vento: float = 6.0


@export_group("Escuridao Permanente")
@export var ativar_escurecimento_permanente: bool = true

@export_range(0.0, 0.80, 0.01)
var intensidade_escuridao_permanente: float = 0.48

@export_range(0.15, 4.0, 0.05)
var duracao_escurecimento_permanente: float = 0.70

@export_range(0.0, 2.0, 0.05)
var atraso_escurecimento_apos_nevoa: float = 0.0


const CAMADA_ESCURIDAO: int = 1030
const CAMADA_NEVOA: int = 1080
const CAMADA_TEXTOS: int = 1150

const FOG_COLUNAS: int = 11
const FOG_LINHAS: int = 9
const FOG_ESPACAMENTO: Vector2 = Vector2(335.0, 190.0)

const CINZAS_COLUNAS: int = 13
const CINZAS_LINHAS: int = 9
const CINZAS_ESPACAMENTO: Vector2 = Vector2(150.0, 105.0)

const QUANTIDADE_RASTROS: int = 20


const ORDEM_ARTEFATOS: Array[String] = [
	"escaravelho",
	"calice",
	"ankh",
	"mascara",
	"lapislazulidofarao"
]


const TEXTOS_RITUAL: Array[String] = [
	"Os cinco artefatos deixam suas mãos. Você não consegue detê-los.",
	"Você se lembra do Necromancer. A escuridão não o feriu. Ela simplesmente o levou.",
	"Os símbolos se alinham diante da pedra. Os relevos parecem responder a algo que está do outro lado.",
	"As cinco relíquias giram cada vez mais rápido. Você percebe que não estão destrancando uma porta.",
	"Estão rompendo um selo."
]


var player: Node2D = null
var anim_player: AnimatedSprite2D = null

var ritual_ativo: bool = false
var ritual_finalizado: bool = false
var portao_abrindo: bool = false

var player_physics_original: bool = true
var player_process_original: bool = true

var camera_2d: Camera2D = null
var camera_offset_original: Vector2 = Vector2.ZERO
var camera_zoom_original: Vector2 = Vector2.ONE
var camera_estado_salvo: bool = false

var artefatos_visuais: Array[AnimatedSprite2D] = []

var girando: bool = false
var angulo_base: float = -PI / 2.0
var velocidade_angular: float = 0.0
var raio_atual: float = 0.0

var giro_aguardando: bool = false
var giro_colapsando: bool = false
var atraso_giro_restante: float = 0.0
var tempo_giro_decorrido: float = 0.0

var camada_ui: CanvasLayer = null
var caixa_texto: Control = null
var fundo_dialogo: TextureRect = null
var label_texto: Label = null
var label_faltando: Label = null
var mensagem_faltando_visivel: bool = false

var ponto_esquerdo: Polygon2D = null
var ponto_direito: Polygon2D = null
var linha_esquerda: Line2D = null
var linha_direita: Line2D = null
var tempo_brilho_dialogo: float = 0.0

var camada_vento: CanvasLayer = null
var raiz_vento: Control = null
var nuvens: Array[TextureRect] = []
var cinzas: Array[TextureRect] = []
var rastros_vento: Array[ColorRect] = []

var vento_iniciado: bool = false
var tempo_vento: float = 0.0
var deslocamento_vento: float = 0.0
var intensidade_atual_vento: float = 0.0
var fator_velocidade_vento: float = 1.0

var camada_escuridao: CanvasLayer = null
var sombra_permanente: ColorRect = null
var tween_escuridao: Tween = null

var ruptura_agendada: bool = false
var posicao_inicial_porta: Vector2 = Vector2.ZERO

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	collision_layer = 3
	collision_mask = 0

	posicao_inicial_porta = global_position
	rng.randomize()

	_criar_ui()
	_procurar_player()


func _process(delta: float) -> void:
	tempo_brilho_dialogo += delta

	if is_instance_valid(ponto_esquerdo):
		ponto_esquerdo.modulate.a = (
			0.70 + 0.25 * sin(tempo_brilho_dialogo * 2.1)
		)

	if is_instance_valid(ponto_direito):
		ponto_direito.modulate.a = (
			0.70 + 0.25 * sin(
				tempo_brilho_dialogo * 2.1 + 1.6
			)
		)

	# Preserva nevoa permanente depois da abertura.
	if vento_iniciado:
		_atualizar_vento(delta)

	# Inicia giro 1 segundo depois do alinhamento.
	if giro_aguardando:
		atraso_giro_restante = maxf(
			0.0,
			atraso_giro_restante - delta
		)

		if atraso_giro_restante <= 0.0:
			giro_aguardando = false
			girando = true
			tempo_giro_decorrido = 0.0
			velocidade_angular = velocidade_giro_inicial

	if girando:
		_atualizar_giro(delta)

	if ritual_finalizado:
		return

	if not is_instance_valid(player):
		_procurar_player()

		if not is_instance_valid(player):
			return

	if ritual_ativo:
		return

	var distancia: float = global_position.distance_to(
		player.global_position
	)

	if (
		distancia <= distancia_ativacao
		and GerenciadorArtefatos.tem_todos_artefatos()
	):
		if player is CharacterBody2D:
			var personagem: CharacterBody2D = (
				player as CharacterBody2D
			)

			if not personagem.is_on_floor():
				return

		_esconder_faltando()
		_iniciar_ritual()
		return

	if distancia <= distancia_mensagem:
		_mostrar_faltando()
	else:
		_esconder_faltando()


func _centro_ritual() -> Vector2:
	return global_position + centro_ritual_offset


func _procurar_player() -> void:
	for candidato: Node in get_tree().get_nodes_in_group(
		"player"
	):
		if not (candidato is Node2D):
			continue

		player = candidato as Node2D

		anim_player = player.get_node_or_null(
			"AnimatedSprite2D"
		) as AnimatedSprite2D

		return


# ============================================================
# CAMERA CINEMATICA
# ============================================================

func _preparar_camera() -> void:
	if not usar_camera_ritual:
		return

	camera_2d = get_viewport().get_camera_2d()

	if not is_instance_valid(camera_2d):
		return

	camera_offset_original = camera_2d.offset
	camera_zoom_original = camera_2d.zoom
	camera_estado_salvo = true


func _focar_camera_ritual() -> void:
	if not usar_camera_ritual:
		return

	if not is_instance_valid(camera_2d):
		return

	if not is_instance_valid(player):
		return

	var distancia_portao_x: float = (
		global_position.x - player.global_position.x
	)

	var pan_x: float = clampf(
		distancia_portao_x * fracao_pan_camera,
		-pan_maximo_camera,
		pan_maximo_camera
	)

	var alvo_offset: Vector2 = (
		camera_offset_original
		+ Vector2(pan_x, offset_vertical_camera)
	)

	var alvo_zoom: Vector2 = (
		camera_zoom_original * zoom_camera_ritual
	)

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		camera_2d,
		"offset",
		alvo_offset,
		duracao_camera_entrada
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	tween.tween_property(
		camera_2d,
		"zoom",
		alvo_zoom,
		duracao_camera_entrada
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished


func _restaurar_camera() -> void:
	if not camera_estado_salvo:
		return

	if not is_instance_valid(camera_2d):
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		camera_2d,
		"offset",
		camera_offset_original,
		duracao_camera_saida
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	tween.tween_property(
		camera_2d,
		"zoom",
		camera_zoom_original,
		duracao_camera_saida
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


# ============================================================
# NEW CINEMATIC DIALOGUE INTERFACE
# ============================================================

func _criar_ui() -> void:
	camada_ui = CanvasLayer.new()
	camada_ui.name = "DialogoCinematograficoPortao"
	camada_ui.layer = CAMADA_TEXTOS
	add_child(camada_ui)

	# Entire panel fades together.
	caixa_texto = Control.new()
	caixa_texto.name = "PainelDegradeDoSelo"
	caixa_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_texto.modulate.a = 0.0
	camada_ui.add_child(caixa_texto)

	fundo_dialogo = TextureRect.new()
	fundo_dialogo.name = "FundoTranslucido"
	fundo_dialogo.texture = _criar_textura_dialogo()
	fundo_dialogo.stretch_mode = TextureRect.STRETCH_SCALE
	fundo_dialogo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fundo_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_texto.add_child(fundo_dialogo)

	linha_esquerda = Line2D.new()
	linha_esquerda.width = 1.4
	linha_esquerda.default_color = Color(
		0.87, 0.72, 0.95, 0.55
	)
	caixa_texto.add_child(linha_esquerda)

	linha_direita = Line2D.new()
	linha_direita.width = 1.4
	linha_direita.default_color = Color(
		0.87, 0.72, 0.95, 0.55
	)
	caixa_texto.add_child(linha_direita)

	ponto_esquerdo = _criar_ponto_lateral()
	ponto_direito = _criar_ponto_lateral()

	label_texto = Label.new()
	label_texto.name = "TextoCinematografico"
	label_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label_texto.add_theme_font_size_override(
		"font_size",
		tamanho_fonte
	)

	label_texto.add_theme_color_override(
		"font_color",
		Color(0.97, 0.94, 1.0)
	)

	label_texto.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.90)
	)

	label_texto.add_theme_constant_override(
		"shadow_offset_y", 2
	)

	label_texto.modulate.a = 0.0
	caixa_texto.add_child(label_texto)

	# Missing-artifact notice remains independent.
	label_faltando = Label.new()
	label_faltando.position = Vector2(24.0, 24.0)
	label_faltando.size = Vector2(560.0, 220.0)

	label_faltando.add_theme_font_size_override(
		"font_size",
		tamanho_fonte
	)

	label_faltando.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	label_faltando.add_theme_color_override(
		"font_shadow_color",
		Color.BLACK
	)

	label_faltando.add_theme_constant_override(
		"shadow_offset_x", 2
	)

	label_faltando.add_theme_constant_override(
		"shadow_offset_y", 2
	)

	label_faltando.modulate.a = 0.0
	camada_ui.add_child(label_faltando)

	_atualizar_ui()

	if not get_viewport().size_changed.is_connected(
		_atualizar_ui
	):
		get_viewport().size_changed.connect(
			_atualizar_ui
		)


func _criar_ponto_lateral() -> Polygon2D:
	var ponto: Polygon2D = Polygon2D.new()

	ponto.polygon = PackedVector2Array([
		Vector2(0.0, -8.0),
		Vector2(8.0, 0.0),
		Vector2(0.0, 8.0),
		Vector2(-8.0, 0.0)
	])

	ponto.color = Color(0.90, 0.76, 1.0, 0.95)
	caixa_texto.add_child(ponto)

	var halo: Polygon2D = Polygon2D.new()
	halo.polygon = ponto.polygon
	halo.color = Color(0.81, 0.67, 1.0, 0.16)
	halo.scale = Vector2(2.5, 2.5)
	ponto.add_child(halo)

	return ponto


func _criar_textura_dialogo() -> Texture2D:
	var imagem: Image = Image.create(
		256, 80, false, Image.FORMAT_RGBA8
	)

	for y: int in range(80):
		for x: int in range(256):
			var fx: float = float(x) / 255.0
			var fy: float = float(y) / 79.0

			var borda_x: float = (
				smoothstep(0.0, 0.16, fx)
				* (
					1.0 - smoothstep(0.84, 1.0, fx)
				)
			)

			var borda_y: float = (
				smoothstep(0.0, 0.22, fy)
				* (
					1.0 - smoothstep(0.78, 1.0, fy)
				)
			)

			var alpha: float = (
				opacidade_caixa
				* borda_x
				* borda_y
			)

			var brilho: float = (
				0.014 + (1.0 - fy) * 0.022
			)

			imagem.set_pixel(
				x, y,
				Color(
					0.025 + brilho,
					0.015 + brilho * 0.65,
					0.055 + brilho * 0.8,
					alpha
				)
			)

	return ImageTexture.create_from_image(imagem)


func _atualizar_ui() -> void:
	var tela: Vector2 = get_viewport_rect().size

	var largura: float = tela.x * 0.83
	var altura: float = clampf(
		tela.y * 0.20,
		130.0,
		190.0
	)

	caixa_texto.size = Vector2(largura, altura)
	caixa_texto.position = Vector2(
		(tela.x - largura) * 0.5,
		tela.y - altura - 25.0
	)

	fundo_dialogo.position = Vector2.ZERO
	fundo_dialogo.size = caixa_texto.size

	label_texto.position = Vector2(
		largura * 0.075,
		8.0
	)

	label_texto.size = Vector2(
		largura * 0.85,
		altura - 16.0
	)

	var meio_y: float = altura * 0.5

	ponto_esquerdo.position = Vector2(
		largura * 0.045,
		meio_y
	)

	ponto_direito.position = Vector2(
		largura * 0.955,
		meio_y
	)

	linha_esquerda.points = PackedVector2Array([
		Vector2(largura * 0.005, meio_y),
		Vector2(largura * 0.030, meio_y)
	])

	linha_direita.points = PackedVector2Array([
		Vector2(largura * 0.970, meio_y),
		Vector2(largura * 0.995, meio_y)
	])


# ============================================================
# MISSING ARTIFACTS
# ============================================================

func _mostrar_faltando() -> void:
	var faltando: Array[String] = (
		GerenciadorArtefatos.artefatos_faltando()
	)

	if faltando.is_empty():
		_esconder_faltando()
		return

	var mensagem: String = ""

	if faltando.size() == 1:
		mensagem = (
			"Falta: "
			+ GerenciadorArtefatos.nome_artefato(
				faltando[0]
			)
		)
	else:
		mensagem = "Artefatos ausentes:\n"

		for tipo: String in faltando:
			mensagem += (
				"• "
				+ GerenciadorArtefatos.nome_artefato(tipo)
				+ "\n"
			)

	label_faltando.text = mensagem

	if mensagem_faltando_visivel:
		return

	mensagem_faltando_visivel = true

	var tween: Tween = create_tween()
	tween.tween_property(
		label_faltando,
		"modulate:a",
		1.0,
		0.25
	)


func _esconder_faltando() -> void:
	if not mensagem_faltando_visivel:
		return

	mensagem_faltando_visivel = false

	var tween: Tween = create_tween()
	tween.tween_property(
		label_faltando,
		"modulate:a",
		0.0,
		0.20
	)


# ============================================================
# FIVE-ARTIFACT RITUAL
# ============================================================

func _iniciar_ritual() -> void:
	if ritual_ativo:
		return

	ritual_ativo = true

	_congelar_player()
	_preparar_camera()

	if usar_camera_ritual:
		await _focar_camera_ritual()

	await get_tree().create_timer(pausa_inicio).timeout

	if not is_inside_tree():
		return

	_criar_artefatos()

	if artefatos_visuais.size() == 5:
		await _emergir_do_player()
		await _formar_selo()

		_preparar_giro_durante_dialogos()

		# Rotation happens concurrently with dialogue.
		await _mostrar_textos()
		await _aguardar_giro_minimo()

		await _colapsar()
		await _desaparecer()

	else:
		push_warning(
			"PORTAO: SpriteFrames incompletos. "
			+ "O ritual visual foi ignorado."
		)

		await _mostrar_textos()

	await get_tree().create_timer(0.45).timeout

	if not is_inside_tree():
		return

	iniciar_abertura()

	if ativar_vento_negro:
		var espera_total: float = (
			atraso_nevoa_apos_abertura
			+ tempo_liberar_apos_rajada
		)

		await get_tree().create_timer(
			espera_total
		).timeout

	if not is_inside_tree():
		return

	_liberar_player()
	ritual_finalizado = true


func _congelar_player() -> void:
	if not is_instance_valid(player):
		return

	player_physics_original = player.is_physics_processing()
	player_process_original = player.is_processing()

	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO

	if is_instance_valid(anim_player):
		if anim_player.sprite_frames.has_animation("idle"):
			anim_player.play("idle")
		else:
			anim_player.stop()

	player.set_physics_process(false)
	player.set_process(false)


func _liberar_player() -> void:
	if not is_instance_valid(player):
		return

	player.set_physics_process(player_physics_original)
	player.set_process(player_process_original)


func _criar_artefatos() -> void:
	artefatos_visuais.clear()

	var frames: SpriteFrames = (
		GerenciadorArtefatos.sprite_frames_artefatos
	)

	if frames == null or not is_instance_valid(player):
		push_warning(
			"PORTAO: SpriteFrames nao registrados."
		)
		return

	var origem: Vector2 = (
		player.global_position
		+ Vector2(0.0, -14.0)
	)

	for tipo: String in ORDEM_ARTEFATOS:
		if not frames.has_animation(tipo):
			continue

		var visual: AnimatedSprite2D = AnimatedSprite2D.new()
		visual.sprite_frames = frames
		visual.animation = StringName(tipo)
		visual.frame = 0
		visual.stop()

		visual.centered = (
			GerenciadorArtefatos.visual_centered
		)

		visual.offset = (
			GerenciadorArtefatos.offset_visual_artefato
		)

		visual.z_index = 500

		visual.scale = (
			GerenciadorArtefatos.escala_visual_artefato
			* escala_ritual
			* 0.15
		)

		visual.modulate.a = 0.0

		get_tree().current_scene.add_child(visual)
		visual.global_position = origem
		artefatos_visuais.append(visual)


func _emergir_do_player() -> void:
	var origem: Vector2 = (
		player.global_position
		+ Vector2(0.0, -14.0)
	)

	var escala_final: Vector2 = (
		GerenciadorArtefatos.escala_visual_artefato
		* escala_ritual
	)

	for i: int in range(artefatos_visuais.size()):
		var artefato: AnimatedSprite2D = artefatos_visuais[i]
		var proporcao: float = float(i) / 4.0

		var angulo: float = lerpf(
			-PI * 0.82,
			-PI * 0.18,
			proporcao
		)

		var destino: Vector2 = (
			origem
			+ Vector2(cos(angulo), sin(angulo)) * 52.0
		)

		var tween: Tween = create_tween()
		tween.set_parallel(true)

		tween.tween_property(
			artefato,
			"modulate:a",
			1.0,
			duracao_emergir * 0.65
		)

		tween.tween_property(
			artefato,
			"global_position",
			destino,
			duracao_emergir
		).set_trans(Tween.TRANS_SINE).set_ease(
			Tween.EASE_OUT
		)

		tween.tween_property(
			artefato,
			"scale",
			escala_final,
			duracao_emergir
		).set_trans(Tween.TRANS_SINE).set_ease(
			Tween.EASE_OUT
		)

		await get_tree().create_timer(
			intervalo_saida
		).timeout

	await get_tree().create_timer(
		duracao_emergir
	).timeout


func _formar_selo() -> void:
	var centro: Vector2 = _centro_ritual()
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	for i: int in range(artefatos_visuais.size()):
		var angulo: float = (
			-PI / 2.0
			+ TAU / 5.0 * float(i)
		)

		var destino: Vector2 = (
			centro
			+ Vector2(cos(angulo), sin(angulo)) * raio_selo
		)

		tween.tween_property(
			artefatos_visuais[i],
			"global_position",
			destino,
			duracao_voo_selo
		).set_trans(Tween.TRANS_SINE).set_ease(
			Tween.EASE_IN_OUT
		)

	await tween.finished

	raio_atual = raio_selo
	angulo_base = -PI / 2.0


# ============================================================
# EXPONENTIAL SPIN
# ============================================================

func _preparar_giro_durante_dialogos() -> void:
	girando = false
	giro_colapsando = false
	giro_aguardando = true

	atraso_giro_restante = atraso_giro_apos_alinhamento
	tempo_giro_decorrido = 0.0

	velocidade_angular = velocidade_giro_inicial
	raio_atual = raio_selo


func _atualizar_giro(delta: float) -> void:
	if not giro_colapsando:
		tempo_giro_decorrido += delta

		var progresso: float = clampf(
			tempo_giro_decorrido
			/ maxf(0.1, duracao_aceleracao_exponencial),
			0.0,
			1.0
		)

		var curva: float = pow(
			progresso,
			expoente_aceleracao
		)

		var inicial: float = maxf(
			0.01, velocidade_giro_inicial
		)

		var final: float = maxf(
			inicial, velocidade_giro_final
		)

		velocidade_angular = (
			inicial * pow(final / inicial, curva)
		)

		raio_atual = lerpf(
			raio_selo,
			raio_selo * 0.68,
			pow(progresso, 2.0)
		)

	_atualizar_selo(delta)


func _aguardar_giro_minimo() -> void:
	while (
		is_inside_tree()
		and (
			giro_aguardando
			or tempo_giro_decorrido < duracao_giro
		)
	):
		await get_tree().process_frame


func _atualizar_selo(delta: float) -> void:
	angulo_base += velocidade_angular * delta
	var centro: Vector2 = _centro_ritual()

	for i: int in range(artefatos_visuais.size()):
		var artefato: AnimatedSprite2D = artefatos_visuais[i]

		if not is_instance_valid(artefato):
			continue

		var angulo: float = (
			angulo_base + TAU / 5.0 * float(i)
		)

		artefato.global_position = (
			centro
			+ Vector2(cos(angulo), sin(angulo))
			* raio_atual
		)


# ============================================================
# CINEMATIC DIALOGUE FADE
# ============================================================

func _mostrar_textos() -> void:
	# Show the translucent panel with its side markers.
	label_texto.modulate.a = 0.0
	caixa_texto.modulate.a = 0.0

	var caixa_entrada: Tween = create_tween()

	caixa_entrada.tween_property(
		caixa_texto,
		"modulate:a",
		1.0,
		0.48
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)

	await caixa_entrada.finished

	for frase: String in TEXTOS_RITUAL:
		label_texto.text = frase
		label_texto.modulate.a = 0.0

		var entrada: Tween = create_tween()

		entrada.tween_property(
			label_texto,
			"modulate:a",
			1.0,
			fade_texto
		)

		await entrada.finished

		await get_tree().create_timer(
			tempo_texto
		).timeout

		var saida: Tween = create_tween()

		saida.tween_property(
			label_texto,
			"modulate:a",
			0.0,
			fade_texto
		)

		await saida.finished

	var caixa_saida: Tween = create_tween()

	caixa_saida.tween_property(
		caixa_texto,
		"modulate:a",
		0.0,
		0.45
	)

	await caixa_saida.finished


# ============================================================
# SEAL COLLAPSE
# ============================================================

func _colapsar() -> void:
	giro_aguardando = false
	giro_colapsando = true
	girando = true

	var raio_inicio: float = raio_atual
	var velocidade_inicio: float = velocidade_angular
	var tempo: float = 0.0

	while tempo < duracao_colapso:
		var delta: float = get_process_delta_time()
		tempo += delta

		var progresso: float = clampf(
			tempo / duracao_colapso,
			0.0,
			1.0
		)

		var curva: float = pow(progresso, 1.8)

		raio_atual = lerpf(
			raio_inicio,
			4.0,
			curva
		)

		velocidade_angular = lerpf(
			velocidade_inicio,
			maxf(
				velocidade_inicio,
				velocidade_giro_final
			) * 1.55,
			curva
		)

		await get_tree().process_frame

	girando = false
	giro_colapsando = false


func _desaparecer() -> void:
	var centro: Vector2 = _centro_ritual()

	var converge: Tween = create_tween()
	converge.set_parallel(true)

	for artefato: AnimatedSprite2D in artefatos_visuais:
		converge.tween_property(
			artefato,
			"global_position",
			centro,
			0.35
		).set_trans(Tween.TRANS_SINE).set_ease(
			Tween.EASE_IN
		)

	await converge.finished

	_criar_clarao(centro)

	var saida: Tween = create_tween()
	saida.set_parallel(true)

	for i: int in range(artefatos_visuais.size()):
		var artefato: AnimatedSprite2D = artefatos_visuais[i]
		var angulo: float = TAU / 5.0 * float(i)

		var destino: Vector2 = (
			centro
			+ Vector2(cos(angulo), sin(angulo)) * 36.0
		)

		saida.tween_property(
			artefato,
			"global_position",
			destino,
			0.60
		).set_trans(Tween.TRANS_SINE).set_ease(
			Tween.EASE_OUT
		)

		saida.tween_property(
			artefato,
			"scale",
			Vector2.ZERO,
			0.60
		)

		saida.tween_property(
			artefato,
			"modulate:a",
			0.0,
			0.55
		)

	await saida.finished

	_limpar_ritual()


func _criar_clarao(posicao: Vector2) -> void:
	var onda: Polygon2D = Polygon2D.new()
	var pontos: PackedVector2Array = PackedVector2Array()

	for i: int in range(40):
		var angulo: float = TAU * float(i) / 40.0

		var raio: float = 8.0 * (
			1.0
			+ 0.13 * sin(angulo * 7.0)
			+ 0.09 * cos(angulo * 11.0)
		)

		pontos.append(
			Vector2(cos(angulo), sin(angulo)) * raio
		)

	onda.polygon = pontos
	onda.color = Color(0.17, 0.08, 0.24, 0.95)
	onda.z_index = 4095

	get_tree().current_scene.add_child(onda)
	onda.global_position = posicao
	onda.scale = Vector2(0.15, 0.15)

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		onda,
		"scale",
		Vector2(17.0, 17.0),
		0.50
	)

	tween.tween_property(
		onda,
		"modulate:a",
		0.0,
		0.55
	)

	tween.set_parallel(false)
	tween.tween_callback(onda.queue_free)


func _limpar_ritual() -> void:
	for artefato: AnimatedSprite2D in artefatos_visuais:
		if is_instance_valid(artefato):
			artefato.queue_free()

	artefatos_visuais.clear()


# ============================================================
# ORIGINAL DOOR OPENING
# ============================================================

func iniciar_abertura() -> void:
	if portao_abrindo:
		return

	portao_abrindo = true

	if GerenciadorArtefatos.tem_todos_artefatos():
		GerenciadorArtefatos.registrar_abertura_portao()

	var destino: Vector2 = (
		global_position
		+ Vector2(0.0, -distancia_subida)
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		self,
		"global_position",
		destino,
		duracao_abertura
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	var tempo_camera: float = maxf(
		duracao_abertura * progresso_porta_restaurar_camera,
		atraso_nevoa_apos_abertura + 0.85
	)

	var timer_camera: SceneTreeTimer = (
		get_tree().create_timer(tempo_camera)
	)

	timer_camera.timeout.connect(_restaurar_camera)
	tween.finished.connect(_ao_terminar_abertura)

	_sequencia_ruptura_apos_abertura()


func _sequencia_ruptura_apos_abertura() -> void:
	if ruptura_agendada:
		return

	ruptura_agendada = true

	await get_tree().create_timer(
		atraso_nevoa_apos_abertura
	).timeout

	if not is_inside_tree():
		return

	# Storm and darkness remain independent of the dialogue.
	if ativar_vento_negro:
		_iniciar_rajada_escura()
		_mostrar_aviso_vento()

	if ativar_escurecimento_permanente:
		if atraso_escurecimento_apos_nevoa > 0.0:
			await get_tree().create_timer(
				atraso_escurecimento_apos_nevoa
			).timeout

			if not is_inside_tree():
				return

		_iniciar_escurecimento_permanente()


func _ao_terminar_abertura() -> void:
	collision_layer = 0
	set_deferred("collision_mask", 0)

	for child: Node in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred(
				"disabled", true
			)


# ============================================================
# PERMANENT DARKNESS
# ============================================================

func _iniciar_escurecimento_permanente() -> void:
	_criar_camada_escuridao()

	if not is_instance_valid(sombra_permanente):
		return

	if tween_escuridao != null:
		if tween_escuridao.is_running():
			tween_escuridao.kill()

	var alvo: float = clampf(
		intensidade_escuridao_permanente,
		0.0, 0.80
	)

	camada_escuridao.visible = true

	tween_escuridao = create_tween()

	tween_escuridao.tween_property(
		sombra_permanente,
		"color:a",
		alvo,
		duracao_escurecimento_permanente
	).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)


func _criar_camada_escuridao() -> void:
	if is_instance_valid(camada_escuridao):
		return

	camada_escuridao = CanvasLayer.new()
	camada_escuridao.name = "EscuridaoPermanenteAposSelo"
	camada_escuridao.layer = CAMADA_ESCURIDAO
	camada_escuridao.follow_viewport_enabled = false
	add_child(camada_escuridao)

	sombra_permanente = ColorRect.new()
	sombra_permanente.name = "SombraQueNaoDesaparece"
	sombra_permanente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sombra_permanente.color = Color(0.0, 0.0, 0.0, 0.0)
	sombra_permanente.modulate = Color.WHITE
	sombra_permanente.position = Vector2.ZERO
	sombra_permanente.size = get_viewport_rect().size

	camada_escuridao.add_child(sombra_permanente)

	if not get_viewport().size_changed.is_connected(
		_atualizar_layout_escuridao
	):
		get_viewport().size_changed.connect(
			_atualizar_layout_escuridao
		)


func _atualizar_layout_escuridao() -> void:
	if is_instance_valid(sombra_permanente):
		sombra_permanente.position = Vector2.ZERO
		sombra_permanente.size = get_viewport_rect().size


# ============================================================
# NEW STORM DIALOGUE WITH CINEMATIC PANEL
# ============================================================

func _mostrar_aviso_vento() -> void:
	if not is_instance_valid(label_texto):
		return

	label_texto.text = (
		"Da abertura, uma névoa negra irrompe com violência.\n"
		+ "O vento é tão frio que parece arrancar o calor das pedras."
	)

	label_texto.modulate.a = 1.0
	caixa_texto.modulate.a = 0.0

	var entrada: Tween = create_tween()

	entrada.tween_property(
		caixa_texto,
		"modulate:a",
		1.0,
		0.45
	)

	await entrada.finished
	await get_tree().create_timer(2.0).timeout

	if not is_inside_tree():
		return

	var sumir_texto: Tween = create_tween()

	sumir_texto.tween_property(
		label_texto,
		"modulate:a",
		0.0,
		0.22
	)

	await sumir_texto.finished

	label_texto.text = (
		"A névoa se espalha pelas ruínas.\n"
		+ "A escuridão parece estar tomando todo o deserto."
	)

	var voltar_texto: Tween = create_tween()

	voltar_texto.tween_property(
		label_texto,
		"modulate:a",
		1.0,
		0.30
	)

	await voltar_texto.finished
	await get_tree().create_timer(1.4).timeout

	if not is_inside_tree():
		return

	var saida: Tween = create_tween()

	saida.tween_property(
		caixa_texto,
		"modulate:a",
		0.0,
		0.55
	)


# ============================================================
# WORLD-WIDE BLACK FOG
# ============================================================

func _iniciar_rajada_escura() -> void:
	if vento_iniciado:
		return

	_criar_efeito_nevoa()

	vento_iniciado = true
	tempo_vento = 0.0
	deslocamento_vento = 0.0
	intensidade_atual_vento = 0.0
	fator_velocidade_vento = 1.0

	if forca_tremor_vento > 0.0:
		_tremer_camera_vento()


func _criar_efeito_nevoa() -> void:
	if is_instance_valid(raiz_vento):
		return

	camada_vento = CanvasLayer.new()
	camada_vento.name = "NevoaPermanenteDoSelo"
	camada_vento.layer = CAMADA_NEVOA
	camada_vento.follow_viewport_enabled = false
	camada_vento.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada_vento)

	raiz_vento = Control.new()
	raiz_vento.name = "NeblinaNegraDoMundo"
	raiz_vento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz_vento.position = Vector2.ZERO
	raiz_vento.size = get_viewport_rect().size
	camada_vento.add_child(raiz_vento)

	var textura_nevoa: Texture2D = (
		_criar_textura_nevoa_negra()
	)

	for i: int in range(
		FOG_COLUNAS * FOG_LINHAS
	):
		var nuvem: TextureRect = TextureRect.new()
		nuvem.name = "NuvemMundo_" + str(i)
		nuvem.texture = textura_nevoa
		nuvem.stretch_mode = TextureRect.STRETCH_SCALE
		nuvem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		nuvem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nuvem.visible = false

		raiz_vento.add_child(nuvem)
		nuvens.append(nuvem)

	var textura_cinza: Texture2D = (
		_criar_textura_cinza_negra(20)
	)

	for i: int in range(
		CINZAS_COLUNAS * CINZAS_LINHAS
	):
		var cinza: TextureRect = TextureRect.new()
		cinza.name = "CinzaMundo_" + str(i)
		cinza.texture = textura_cinza
		cinza.stretch_mode = TextureRect.STRETCH_SCALE
		cinza.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		cinza.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cinza.visible = false

		raiz_vento.add_child(cinza)
		cinzas.append(cinza)

	for i: int in range(QUANTIDADE_RASTROS):
		var rastro: ColorRect = ColorRect.new()
		rastro.name = "RastroTempestade_" + str(i)
		rastro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rastro.color = Color(0.27, 0.25, 0.32, 0.0)

		raiz_vento.add_child(rastro)
		rastros_vento.append(rastro)

	_atualizar_layout_vento()

	if not get_viewport().size_changed.is_connected(
		_atualizar_layout_vento
	):
		get_viewport().size_changed.connect(
			_atualizar_layout_vento
		)


func _atualizar_layout_vento() -> void:
	if is_instance_valid(raiz_vento):
		raiz_vento.size = get_viewport_rect().size


func _nevoa_seed(
	cx: int,
	cy: int,
	salt: float
) -> float:
	return fposmod(
		sin(
			float(cx) * 127.1
			+ float(cy) * 311.7
			+ salt
		) * 43758.5453,
		1.0
	)


func _atualizar_vento(delta: float) -> void:
	if not is_instance_valid(raiz_vento):
		return

	tempo_vento += delta

	var fim_rajada: float = duracao_rajada_forte
	var fim_acalmar: float = (
		fim_rajada + duracao_acalmar
	)

	var entrada: float = smoothstep(
		0.0, 0.40, tempo_vento
	)

	if tempo_vento <= fim_rajada:
		fator_velocidade_vento = 1.0
		intensidade_atual_vento = (
			densidade_vento * entrada
		)

	elif tempo_vento < fim_acalmar:
		var progresso: float = clampf(
			(tempo_vento - fim_rajada)
			/ maxf(0.01, duracao_acalmar),
			0.0,
			1.0
		)

		var curva: float = smoothstep(
			0.0, 1.0, progresso
		)

		fator_velocidade_vento = lerpf(
			1.0,
			velocidade_nevoa_permanente,
			curva
		)

		intensidade_atual_vento = lerpf(
			densidade_vento,
			densidade_nevoa_permanente,
			curva
		)

	else:
		fator_velocidade_vento = (
			velocidade_nevoa_permanente
		)

		intensidade_atual_vento = (
			densidade_nevoa_permanente
		)

	deslocamento_vento += (
		delta
		* velocidade_vento
		* fator_velocidade_vento
	)

	raiz_vento.size = get_viewport_rect().size

	_atualizar_nuvens_mundo()
	_atualizar_cinzas_mundo()
	_atualizar_rastros_tempestade()


func _atualizar_nuvens_mundo() -> void:
	var tela: Vector2 = get_viewport_rect().size

	var world_to_screen: Transform2D = (
		get_viewport().get_canvas_transform()
	)

	var centro_mundo: Vector2 = (
		world_to_screen.affine_inverse()
		* (tela * 0.5)
	)

	var zoom_x: float = maxf(
		0.15, world_to_screen.x.length()
	)

	var zoom_y: float = maxf(
		0.15, world_to_screen.y.length()
	)

	var grid_x: int = floori(
		(centro_mundo.x + deslocamento_vento)
		/ FOG_ESPACAMENTO.x
	)

	var grid_y: int = floori(
		centro_mundo.y / FOG_ESPACAMENTO.y
	)

	for i: int in range(nuvens.size()):
		var nuvem: TextureRect = nuvens[i]

		var cx: int = (
			grid_x
			+ i % FOG_COLUNAS
			- int(FOG_COLUNAS / 2)
		)

		var cy: int = (
			grid_y
			+ floori(
				float(i) / float(FOG_COLUNAS)
			)
			- int(FOG_LINHAS / 2)
		)

		var s: float = _nevoa_seed(cx, cy, 17.0)
		nuvem.visible = s > 0.13

		if not nuvem.visible:
			continue

		var jitter: Vector2 = Vector2(
			(_nevoa_seed(cx, cy, 31.0) - 0.5) * 170.0,
			(_nevoa_seed(cx, cy, 67.0) - 0.5) * 100.0
		)

		var deriva: Vector2 = Vector2(
			sin(
				tempo_vento * (0.23 + 0.08 * s)
				+ s * TAU
			) * 24.0,

			cos(
				tempo_vento * (0.17 + 0.06 * s)
				+ s * TAU
			) * 19.0
		)

		var posicao_mundo: Vector2 = (
			Vector2(
				float(cx) * FOG_ESPACAMENTO.x
					- deslocamento_vento,
				float(cy) * FOG_ESPACAMENTO.y
			)
			+ jitter
			+ deriva
		)

		var posicao_tela: Vector2 = (
			world_to_screen * posicao_mundo
		)

		var largura: float = 480.0 + s * 100.0
		var altura: float = 190.0 + s * 55.0

		var respiracao: float = (
			1.0 + 0.04 * sin(
				tempo_vento * 0.38 + s * TAU
			)
		)

		nuvem.size = Vector2(
			largura * zoom_x,
			altura * zoom_y
		) * respiracao

		nuvem.position = (
			posicao_tela - nuvem.size * 0.5
		)

		nuvem.modulate = Color(
			1.0, 1.0, 1.0,
			intensidade_atual_vento
			* (0.78 + 0.22 * s)
		)


func _atualizar_cinzas_mundo() -> void:
	if cinzas.is_empty():
		return

	var tela: Vector2 = get_viewport_rect().size

	var world_to_screen: Transform2D = (
		get_viewport().get_canvas_transform()
	)

	var centro_mundo: Vector2 = (
		world_to_screen.affine_inverse()
		* (tela * 0.5)
	)

	var zoom_x: float = maxf(
		0.15, world_to_screen.x.length()
	)

	var zoom_y: float = maxf(
		0.15, world_to_screen.y.length()
	)

	var distancia_cinzas: float = (
		deslocamento_vento * 0.85
	)

	var grid_x: int = floori(
		(centro_mundo.x + distancia_cinzas)
		/ CINZAS_ESPACAMENTO.x
	)

	var grid_y: int = floori(
		centro_mundo.y / CINZAS_ESPACAMENTO.y
	)

	for i: int in range(cinzas.size()):
		var cinza: TextureRect = cinzas[i]

		var cx: int = (
			grid_x
			+ i % CINZAS_COLUNAS
			- int(CINZAS_COLUNAS / 2)
		)

		var cy: int = (
			grid_y
			+ floori(
				float(i) / float(CINZAS_COLUNAS)
			)
			- int(CINZAS_LINHAS / 2)
		)

		var s: float = _nevoa_seed(cx, cy, 109.0)
		cinza.visible = s > 0.24

		if not cinza.visible:
			continue

		var jitter: Vector2 = Vector2(
			(_nevoa_seed(cx, cy, 119.0) - 0.5) * 90.0,
			(_nevoa_seed(cx, cy, 127.0) - 0.5) * 70.0
		)

		var movimento: Vector2 = Vector2(
			sin(
				tempo_vento * (0.45 + s * 0.15)
				+ s * TAU
			) * 18.0,

			45.0 - fposmod(
				tempo_vento * (10.0 + 8.0 * s)
				+ s * 85.0,
				90.0
			)
		)

		var posicao_mundo: Vector2 = (
			Vector2(
				float(cx) * CINZAS_ESPACAMENTO.x
					- distancia_cinzas,
				float(cy) * CINZAS_ESPACAMENTO.y
			)
			+ jitter
			+ movimento
		)

		var posicao_tela: Vector2 = (
			world_to_screen * posicao_mundo
		)

		var tamanho: float = 3.0 + s * 4.5

		cinza.size = Vector2(
			tamanho * zoom_x,
			tamanho * zoom_y
		)

		cinza.position = (
			posicao_tela - cinza.size * 0.5
		)

		cinza.modulate = Color(
			1.0, 1.0, 1.0,
			intensidade_atual_vento
			* (0.35 + 0.25 * s)
		)


func _atualizar_rastros_tempestade() -> void:
	var tela: Vector2 = get_viewport_rect().size

	var forca_rastros: float = clampf(
		(
			fator_velocidade_vento
			- velocidade_nevoa_permanente
		)
		/ maxf(
			0.01,
			1.0 - velocidade_nevoa_permanente
		),
		0.0,
		1.0
	)

	forca_rastros *= smoothstep(
		0.0, 0.40, tempo_vento
	)

	for i: int in range(rastros_vento.size()):
		var rastro: ColorRect = rastros_vento[i]

		var s: float = fposmod(
			sin(float(i) * 29.43) * 8473.1,
			1.0
		)

		var largura: float = 55.0 + 110.0 * s

		var x: float = (
			tela.x + largura
			- fposmod(
				float(i) * 139.0
				+ deslocamento_vento * (1.1 + s),
				tela.x + 500.0
			)
		)

		var y: float = fposmod(
			float(i) * 97.0,
			maxf(1.0, tela.y)
		)

		rastro.position = Vector2(x, y)

		rastro.size = Vector2(
			largura,
			1.0 + s * 1.5
		)

		rastro.color = Color(
			0.30, 0.27, 0.34,
			0.36 * forca_rastros
		)


# ============================================================
# PROCEDURAL BLACK FOG
# ============================================================

func _criar_textura_nevoa_negra() -> Texture2D:
	var largura: int = 192
	var altura: int = 96

	var imagem: Image = Image.create(
		largura, altura, false, Image.FORMAT_RGBA8
	)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 72011
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.024
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

	for y: int in range(altura):
		var fy: float = (
			(float(y) + 0.5) / float(altura)
		)

		var mascara_vertical: float = (
			1.0 - smoothstep(
				0.16, 0.50,
				absf(fy - 0.5)
			)
		)

		for x: int in range(largura):
			var fx: float = (
				(float(x) + 0.5) / float(largura)
			)

			var mascara_lateral: float = (
				smoothstep(0.0, 0.14, fx)
				* (
					1.0 - smoothstep(
						0.86, 1.0, fx
					)
				)
			)

			var valor: float = noise.get_noise_2d(
				float(x), float(y)
			)

			var densidade: float = smoothstep(
				-0.32, 0.24, valor
			)

			var alpha: float = clampf(
				mascara_vertical
				* mascara_lateral
				* (0.18 + 0.82 * densidade),
				0.0, 1.0
			)

			imagem.set_pixel(
				x, y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	return ImageTexture.create_from_image(imagem)


func _criar_textura_cinza_negra(
	tamanho: int
) -> Texture2D:
	var imagem: Image = Image.create(
		tamanho, tamanho,
		false, Image.FORMAT_RGBA8
	)

	var raio: float = float(tamanho) * 0.5

	for y: int in range(tamanho):
		for x: int in range(tamanho):
			var distancia: float = (
				Vector2(
					float(x) - raio,
					float(y) - raio
				).length() / raio
			)

			var alpha: float = pow(
				1.0 - smoothstep(
					0.0, 1.0, distancia
				),
				2.0
			)

			imagem.set_pixel(
				x, y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	return ImageTexture.create_from_image(imagem)


# ============================================================
# CAMERA SHAKE
# ============================================================

func _tremer_camera_vento() -> void:
	var camera: Camera2D = (
		get_viewport().get_camera_2d()
	)

	if not is_instance_valid(camera):
		return

	var offset_inicial: Vector2 = camera.offset
	var duracao: float = 0.75
	var passos: int = 18

	for i: int in range(passos):
		if not is_instance_valid(camera):
			return

		var fator: float = (
			1.0 - float(i) / float(passos)
		)

		camera.offset = (
			offset_inicial
			+ Vector2(
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)
			) * forca_tremor_vento * fator
		)

		await get_tree().create_timer(
			duracao / float(passos)
		).timeout

	if is_instance_valid(camera):
		camera.offset = offset_inicial


# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
	_liberar_player()

	var viewport: Viewport = get_viewport()

	if viewport.size_changed.is_connected(
		_atualizar_ui
	):
		viewport.size_changed.disconnect(
			_atualizar_ui
		)

	if viewport.size_changed.is_connected(
		_atualizar_layout_vento
	):
		viewport.size_changed.disconnect(
			_atualizar_layout_vento
		)

	if viewport.size_changed.is_connected(
		_atualizar_layout_escuridao
	):
		viewport.size_changed.disconnect(
			_atualizar_layout_escuridao
		)

	if tween_escuridao != null:
		if tween_escuridao.is_running():
			tween_escuridao.kill()
