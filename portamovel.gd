extends StaticBody2D


@export_group("Portao")
@export_range(3.0, 15.0, 0.1) var duracao_abertura: float = 7.0
@export var distancia_subida: float = 500.0


@export_group("Deteccao")
@export var distancia_ativacao: float = 175.0
@export var distancia_mensagem: float = 225.0


@export_group("Ritual")
@export var centro_ritual_offset: Vector2 = Vector2(-185.0, 36.0)
@export var raio_selo: float = 58.0
@export var escala_ritual: float = 1.10

@export_range(0.1, 3.0, 0.05) var pausa_inicio: float = 1.0
@export_range(0.05, 1.0, 0.05) var intervalo_saida: float = 0.28
@export_range(0.2, 3.0, 0.05) var duracao_emergir: float = 1.10
@export_range(0.3, 4.0, 0.05) var duracao_voo_selo: float = 2.0
@export_range(1.0, 10.0, 0.1) var duracao_giro: float = 5.2

@export var velocidade_giro_inicial: float = 0.35
@export var velocidade_giro_final: float = 6.5

@export_range(0.2, 3.0, 0.05) var duracao_colapso: float = 1.1


@export_group("Camera Cinematica")
@export var usar_camera_ritual: bool = true

@export_range(0.2, 3.0, 0.05) var duracao_camera_entrada: float = 1.2
@export_range(1.0, 1.8, 0.01) var zoom_camera_ritual: float = 1.08

@export_range(0.0, 1.0, 0.05) var fracao_pan_camera: float = 0.22
@export_range(0.0, 300.0, 5.0) var pan_maximo_camera: float = 80.0
@export_range(-250.0, 100.0, 5.0) var offset_vertical_camera: float = -105.0

@export_range(0.2, 3.0, 0.05) var duracao_camera_saida: float = 1.2
@export_range(0.0, 1.0, 0.05) var progresso_porta_restaurar_camera: float = 0.32


@export_group("Texto")
@export var tamanho_fonte: int = 20
@export_range(0.1, 1.5, 0.05) var fade_texto: float = 0.35
@export_range(1.0, 5.0, 0.1) var tempo_texto: float = 2.7
@export_range(0.0, 1.0, 0.05) var opacidade_caixa: float = 0.86


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

var camada_ui: CanvasLayer = null
var caixa_texto: ColorRect = null
var label_texto: Label = null
var label_faltando: Label = null
var mensagem_faltando_visivel: bool = false


const ORDEM_ARTEFATOS: Array[String] = [
	"escaravelho",
	"calice",
	"ankh",
	"mascara",
	"lapislazulidofarao"
]


const TEXTOS_RITUAL: Array[String] = [
	"Os cinco objetos se alinham diante da passagem.",

	"Na arquitetura egípcia, eixos, simetria e alinhamentos ajudavam a organizar a transição entre diferentes espaços monumentais e cerimoniais.",

	"Aqui, as cinco relíquias deixam de agir como objetos separados. Sua disposição transforma o conjunto em uma única chave.",

	"O mecanismo é uma interpretação fantástica, mas parte de uma ideia real: arquitetura, objetos rituais e símbolos podiam fazer parte de um mesmo programa religioso.",

	"A pedra responde ao alinhamento."
]


func _ready() -> void:
	collision_layer = 3
	collision_mask = 0

	_criar_ui()
	_procurar_player()


func _process(delta: float) -> void:
	if ritual_finalizado:
		return

	if player == null:
		_procurar_player()
		return

	if not is_instance_valid(player):
		player = null
		return

	if girando:
		_atualizar_selo(delta)

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
			var personagem := player as CharacterBody2D

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
	var jogadores: Array[Node] = get_tree().get_nodes_in_group(
		"player"
	)

	for candidato in jogadores:
		if not candidato is Node2D:
			continue

		player = candidato as Node2D

		anim_player = player.get_node_or_null(
			"AnimatedSprite2D"
		) as AnimatedSprite2D

		return


func _preparar_camera() -> void:
	if not usar_camera_ritual:
		return

	camera_2d = get_viewport().get_camera_2d()

	if camera_2d == null:
		return

	camera_offset_original = camera_2d.offset
	camera_zoom_original = camera_2d.zoom
	camera_estado_salvo = true


func _focar_camera_ritual() -> void:
	if not usar_camera_ritual:
		return

	if camera_2d == null:
		return

	if player == null:
		return

	var distancia_portao_x: float = (
		global_position.x
		- player.global_position.x
	)

	var pan_x: float = clampf(
		distancia_portao_x * fracao_pan_camera,
		-pan_maximo_camera,
		pan_maximo_camera
	)

	var alvo_offset: Vector2 = (
		camera_offset_original
		+ Vector2(
			pan_x,
			offset_vertical_camera
		)
	)

	var alvo_zoom: Vector2 = (
		camera_zoom_original
		* zoom_camera_ritual
	)

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		camera_2d,
		"offset",
		alvo_offset,
		duracao_camera_entrada
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	tween.tween_property(
		camera_2d,
		"zoom",
		alvo_zoom,
		duracao_camera_entrada
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished


func _restaurar_camera() -> void:
	if not camera_estado_salvo:
		return

	if camera_2d == null:
		return

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		camera_2d,
		"offset",
		camera_offset_original,
		duracao_camera_saida
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	tween.tween_property(
		camera_2d,
		"zoom",
		camera_zoom_original,
		duracao_camera_saida
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)


func _criar_ui() -> void:
	camada_ui = CanvasLayer.new()
	camada_ui.layer = 200
	add_child(camada_ui)

	caixa_texto = ColorRect.new()

	caixa_texto.color = Color(
		0.0,
		0.0,
		0.0,
		opacidade_caixa
	)

	caixa_texto.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	caixa_texto.modulate.a = 0.0

	camada_ui.add_child(
		caixa_texto
	)

	label_texto = Label.new()

	label_texto.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	label_texto.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	label_texto.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	label_texto.add_theme_font_size_override(
		"font_size",
		tamanho_fonte
	)

	label_texto.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	label_texto.modulate.a = 0.0

	camada_ui.add_child(
		label_texto
	)

	label_faltando = Label.new()

	label_faltando.position = Vector2(
		24.0,
		24.0
	)

	label_faltando.size = Vector2(
		560.0,
		220.0
	)

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
		"shadow_offset_x",
		2
	)

	label_faltando.add_theme_constant_override(
		"shadow_offset_y",
		2
	)

	label_faltando.modulate.a = 0.0

	camada_ui.add_child(
		label_faltando
	)

	_atualizar_ui()

	if not get_viewport().size_changed.is_connected(
		_atualizar_ui
	):
		get_viewport().size_changed.connect(
			_atualizar_ui
		)


func _atualizar_ui() -> void:
	var tela: Vector2 = get_viewport_rect().size
	var altura_caixa: float = 175.0

	caixa_texto.position = Vector2(
		22.0,
		tela.y - altura_caixa - 22.0
	)

	caixa_texto.size = Vector2(
		tela.x - 44.0,
		altura_caixa
	)

	label_texto.position = (
		caixa_texto.position
		+ Vector2(
			20.0,
			10.0
		)
	)

	label_texto.size = (
		caixa_texto.size
		- Vector2(
			40.0,
			20.0
		)
	)


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

		for tipo in faltando:
			mensagem += (
				"• "
				+ GerenciadorArtefatos.nome_artefato(
					tipo
				)
				+ "\n"
			)

	label_faltando.text = mensagem

	if mensagem_faltando_visivel:
		return

	mensagem_faltando_visivel = true

	var tween := create_tween()

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

	var tween := create_tween()

	tween.tween_property(
		label_faltando,
		"modulate:a",
		0.0,
		0.2
	)


func _iniciar_ritual() -> void:
	if ritual_ativo:
		return

	ritual_ativo = true

	_congelar_player()
	_preparar_camera()

	if usar_camera_ritual:
		await _focar_camera_ritual()

	await get_tree().create_timer(
		pausa_inicio
	).timeout

	_criar_artefatos()

	if artefatos_visuais.size() != 5:
		push_warning(
			"PORTAO: nao foi possivel criar os cinco artefatos."
		)

		await _mostrar_textos()

		# A porta comeca a abrir.
		iniciar_abertura()

		# CONTROLE VOLTA IMEDIATAMENTE.
		_liberar_player()

		ritual_finalizado = true
		return

	await _emergir_do_player()
	await _formar_selo()
	await _mostrar_textos()
	await _girar()
	await _colapsar()
	await _desaparecer()

	await get_tree().create_timer(
		0.45
	).timeout

	# =================================================
	# A CUTSCENE ACABOU.
	#
	# A porta comeca a subir, mas NAO seguramos mais
	# o Player esperando ela terminar.
	# =================================================

	iniciar_abertura()

	_liberar_player()

	ritual_finalizado = true


func _congelar_player() -> void:
	if player == null:
		return

	player_physics_original = (
		player.is_physics_processing()
	)

	player_process_original = (
		player.is_processing()
	)

	if player is CharacterBody2D:
		var personagem := (
			player as CharacterBody2D
		)

		personagem.velocity = Vector2.ZERO

	if anim_player != null:
		if anim_player.sprite_frames.has_animation(
			"idle"
		):
			anim_player.play(
				"idle"
			)
		else:
			anim_player.stop()

	player.set_physics_process(
		false
	)

	player.set_process(
		false
	)


func _liberar_player() -> void:
	if player == null:
		return

	if not is_instance_valid(
		player
	):
		return

	player.set_physics_process(
		player_physics_original
	)

	player.set_process(
		player_process_original
	)


func _criar_artefatos() -> void:
	artefatos_visuais.clear()

	var frames: SpriteFrames = (
		GerenciadorArtefatos.sprite_frames_artefatos
	)

	if frames == null:
		push_warning(
			"PORTAO: SpriteFrames nao registrados."
		)
		return

	var origem: Vector2 = (
		player.global_position
		+ Vector2(
			0.0,
			-14.0
		)
	)

	for tipo in ORDEM_ARTEFATOS:
		if not frames.has_animation(
			tipo
		):
			continue

		var visual := AnimatedSprite2D.new()

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

		get_tree().current_scene.add_child(
			visual
		)

		visual.global_position = origem

		artefatos_visuais.append(
			visual
		)


func _emergir_do_player() -> void:
	var origem: Vector2 = (
		player.global_position
		+ Vector2(
			0.0,
			-14.0
		)
	)

	var escala_final: Vector2 = (
		GerenciadorArtefatos.escala_visual_artefato
		* escala_ritual
	)

	for i in range(
		artefatos_visuais.size()
	):
		var artefato := (
			artefatos_visuais[i]
		)

		var proporcao: float = (
			float(i) / 4.0
		)

		var angulo: float = lerpf(
			-PI * 0.82,
			-PI * 0.18,
			proporcao
		)

		var destino: Vector2 = (
			origem
			+ Vector2(
				cos(angulo),
				sin(angulo)
			)
			* 52.0
		)

		var tween := create_tween()

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
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_OUT
		)

		tween.tween_property(
			artefato,
			"scale",
			escala_final,
			duracao_emergir
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_OUT
		)

		await get_tree().create_timer(
			intervalo_saida
		).timeout

	await get_tree().create_timer(
		duracao_emergir
	).timeout


func _formar_selo() -> void:
	var centro: Vector2 = (
		_centro_ritual()
	)

	var tween := create_tween()

	tween.set_parallel(true)

	for i in range(
		artefatos_visuais.size()
	):
		var angulo: float = (
			-PI / 2.0
			+ TAU / 5.0
			* float(i)
		)

		var destino: Vector2 = (
			centro
			+ Vector2(
				cos(angulo),
				sin(angulo)
			)
			* raio_selo
		)

		tween.tween_property(
			artefatos_visuais[i],
			"global_position",
			destino,
			duracao_voo_selo
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_IN_OUT
		)

	await tween.finished

	raio_atual = raio_selo
	angulo_base = -PI / 2.0


func _mostrar_textos() -> void:
	var caixa_entrada := create_tween()

	caixa_entrada.tween_property(
		caixa_texto,
		"modulate:a",
		1.0,
		0.3
	)

	await caixa_entrada.finished

	for frase in TEXTOS_RITUAL:
		label_texto.text = frase
		label_texto.modulate.a = 0.0

		var entrada := create_tween()

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

		var saida := create_tween()

		saida.tween_property(
			label_texto,
			"modulate:a",
			0.0,
			fade_texto
		)

		await saida.finished

	var caixa_saida := create_tween()

	caixa_saida.tween_property(
		caixa_texto,
		"modulate:a",
		0.0,
		0.3
	)

	await caixa_saida.finished


func _girar() -> void:
	girando = true
	velocidade_angular = velocidade_giro_inicial

	var tempo: float = 0.0

	while tempo < duracao_giro:
		var delta: float = (
			get_process_delta_time()
		)

		tempo += delta

		var progresso: float = clampf(
			tempo / duracao_giro,
			0.0,
			1.0
		)

		var curva: float = pow(
			progresso,
			2.0
		)

		velocidade_angular = lerpf(
			velocidade_giro_inicial,
			velocidade_giro_final,
			curva
		)

		raio_atual = lerpf(
			raio_selo,
			raio_selo * 0.68,
			curva
		)

		await get_tree().process_frame


func _atualizar_selo(
	delta: float
) -> void:
	angulo_base += (
		velocidade_angular
		* delta
	)

	var centro: Vector2 = (
		_centro_ritual()
	)

	for i in range(
		artefatos_visuais.size()
	):
		var angulo: float = (
			angulo_base
			+ TAU / 5.0
			* float(i)
		)

		artefatos_visuais[i].global_position = (
			centro
			+ Vector2(
				cos(angulo),
				sin(angulo)
			)
			* raio_atual
		)


func _colapsar() -> void:
	var raio_inicio: float = (
		raio_atual
	)

	var tempo: float = 0.0

	while tempo < duracao_colapso:
		var delta: float = (
			get_process_delta_time()
		)

		tempo += delta

		var progresso: float = clampf(
			tempo / duracao_colapso,
			0.0,
			1.0
		)

		var curva: float = pow(
			progresso,
			1.8
		)

		raio_atual = lerpf(
			raio_inicio,
			4.0,
			curva
		)

		velocidade_angular = lerpf(
			velocidade_giro_final,
			velocidade_giro_final * 1.55,
			curva
		)

		await get_tree().process_frame

	girando = false


func _desaparecer() -> void:
	var centro: Vector2 = (
		_centro_ritual()
	)

	var converge := create_tween()

	converge.set_parallel(true)

	for artefato in artefatos_visuais:
		converge.tween_property(
			artefato,
			"global_position",
			centro,
			0.35
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_IN
		)

	await converge.finished

	_criar_clarao(
		centro
	)

	var saida := create_tween()

	saida.set_parallel(true)

	for i in range(
		artefatos_visuais.size()
	):
		var artefato := (
			artefatos_visuais[i]
		)

		var angulo: float = (
			TAU / 5.0
			* float(i)
		)

		var destino: Vector2 = (
			centro
			+ Vector2(
				cos(angulo),
				sin(angulo)
			)
			* 36.0
		)

		saida.tween_property(
			artefato,
			"global_position",
			destino,
			0.60
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
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


func _criar_clarao(
	posicao: Vector2
) -> void:
	var clarao := Polygon2D.new()
	var pontos := PackedVector2Array()

	for i in range(40):
		var angulo: float = (
			TAU * float(i) / 40.0
		)

		pontos.append(
			Vector2(
				cos(angulo),
				sin(angulo)
			)
			* 8.0
		)

	clarao.polygon = pontos

	clarao.color = Color(
		1.0,
		0.94,
		0.65,
		1.0
	)

	clarao.z_index = 4095

	get_tree().current_scene.add_child(
		clarao
	)

	clarao.global_position = posicao
	clarao.scale = Vector2(
		0.15,
		0.15
	)

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		clarao,
		"scale",
		Vector2(
			15.0,
			15.0
		),
		0.45
	)

	tween.tween_property(
		clarao,
		"modulate:a",
		0.0,
		0.50
	)

	await tween.finished

	if is_instance_valid(
		clarao
	):
		clarao.queue_free()


func _limpar_ritual() -> void:
	for artefato in artefatos_visuais:
		if is_instance_valid(
			artefato
		):
			artefato.queue_free()

	artefatos_visuais.clear()


# =====================================================
# ABRIR PORTAO
#
# IMPORTANTE:
# Essa funcao agora e NAO-BLOQUEANTE.
#
# O Player recupera o controle assim que a cutscene
# acaba, enquanto a pedra continua subindo.
# =====================================================

func iniciar_abertura() -> void:
	if portao_abrindo:
		return

	portao_abrindo = true

	var destino: Vector2 = (
		global_position
		+ Vector2(
			0.0,
			-distancia_subida
		)
	)

	var tween := create_tween()

	tween.tween_property(
		self,
		"global_position",
		destino,
		duracao_abertura
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	var timer_camera := get_tree().create_timer(
		duracao_abertura
		* progresso_porta_restaurar_camera
	)

	timer_camera.timeout.connect(
		_restaurar_camera
	)

	tween.finished.connect(
		_ao_terminar_abertura
	)


func _ao_terminar_abertura() -> void:
	collision_layer = 0
