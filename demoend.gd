extends Area2D


@export var caminho_menu: String = "res://main_menu.tscn"


var ativado: bool = false

var pode_continuar: bool = false


var overlay: CanvasLayer = null

var fundo: ColorRect = null

var texto: Label = null

var continuar: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)


func _on_body_entered(
	body: Node
) -> void:
	if ativado:
		return


	if not body.is_in_group(
		"player"
	):
		return


	ativado = true


	# =====================================================
	# PRETO INSTANTANEO
	# =====================================================

	if body.has_method(
		"forcar_tela_preta"
	):
		body.forcar_tela_preta()


	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO


	_criar_final()


	# Congela absolutamente todo o resto da fase.
	get_tree().paused = true


	_rodar_final()


func _criar_final() -> void:
	overlay = CanvasLayer.new()

	overlay.name = "DemoEnding"

	overlay.layer = 1000

	overlay.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(
		overlay
	)


	fundo = ColorRect.new()

	fundo.color = Color.BLACK

	fundo.position = Vector2.ZERO

	fundo.size = get_viewport_rect().size

	fundo.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	overlay.add_child(
		fundo
	)


	texto = Label.new()

	texto.position = Vector2.ZERO

	texto.size = get_viewport_rect().size

	texto.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	texto.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	texto.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	texto.add_theme_font_size_override(
		"font_size",
		28
	)

	texto.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	texto.modulate.a = 0.0

	overlay.add_child(
		texto
	)


	continuar = Label.new()

	continuar.position = Vector2(
		0.0,
		get_viewport_rect().size.y
		* 0.78
	)

	continuar.size = Vector2(
		get_viewport_rect().size.x,
		60.0
	)

	continuar.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	continuar.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	continuar.add_theme_font_size_override(
		"font_size",
		17
	)

	continuar.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			1.0,
			1.0,
			0.65
		)
	)

	continuar.modulate.a = 0.0

	overlay.add_child(
		continuar
	)


	get_viewport().size_changed.connect(
		_atualizar_layout
	)


func _atualizar_layout() -> void:
	if fundo != null:
		fundo.position = Vector2.ZERO

		fundo.size = (
			get_viewport_rect().size
		)


	if texto != null:
		texto.position = Vector2.ZERO

		texto.size = (
			get_viewport_rect().size
		)


	if continuar != null:
		continuar.position = Vector2(
			0.0,
			get_viewport_rect().size.y
			* 0.78
		)

		continuar.size = Vector2(
			get_viewport_rect().size.x,
			60.0
		)


func _rodar_final() -> void:
	await _esperar(
		1.8
	)


	await _mostrar_frase(
		"...",
		1.5
	)


	await _esperar(
		1.5
	)


	await _mostrar_frase(
		"A queda foi longa.",
		2.0
	)


	await _mostrar_frase(
		"Longa o bastante para que\nninguém devesse sobreviver.",
		2.8
	)


	await _esperar(
		1.0
	)


	await _mostrar_frase(
		"...",
		1.5
	)


	await _mostrar_frase(
		"Mas o que aconteceu lá embaixo?",
		2.7
	)


	await _mostrar_frase(
		"Você sobreviveu?",
		2.4
	)


	await _esperar(
		1.2
	)


	await _mostrar_frase(
		"Talvez essa não seja\na pergunta mais importante.",
		3.0
	)


	await _mostrar_frase(
		"Você entrou naquelas ruínas\npor um motivo.",
		2.8
	)


	await _mostrar_frase(
		"E ainda não encontrou\no que procurava.",
		3.0
	)


	await _esperar(
		1.4
	)


	await _mostrar_frase(
		"Alguma coisa continua lá.",
		2.6
	)


	await _mostrar_frase(
		"Esperando.",
		2.4
	)


	await _esperar(
		2.0
	)


	await _mostrar_frase(
		"Seu caminho ainda não terminou.",
		3.0
	)


	await _esperar(
		2.0
	)


	await _mostrar_frase(
		"...",
		1.5
	)


	await _mostrar_frase(
		"Por enquanto,\neste é o fim da demo.",
		3.5
	)


	await _esperar(
		1.5
	)


	_liberar_continuacao()


func _mostrar_frase(
	frase: String,
	tempo_visivel: float
) -> void:
	texto.text = frase

	texto.modulate.a = 0.0


	var entrada := create_tween()

	entrada.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	entrada.tween_property(
		texto,
		"modulate:a",
		1.0,
		0.75
	)


	await entrada.finished


	await _esperar(
		tempo_visivel
	)


	var saida := create_tween()

	saida.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	saida.tween_property(
		texto,
		"modulate:a",
		0.0,
		0.75
	)


	await saida.finished


func _esperar(
	tempo: float
) -> void:
	await get_tree().create_timer(
		tempo,
		true
	).timeout


func _liberar_continuacao() -> void:
	pode_continuar = true


	continuar.text = (
		"Pressione qualquer tecla"
	)


	var tween := create_tween()

	tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	tween.tween_property(
		continuar,
		"modulate:a",
		1.0,
		1.0
	)


func _unhandled_input(
	event: InputEvent
) -> void:
	if not pode_continuar:
		return


	if not event.is_pressed():
		return


	pode_continuar = false


	get_tree().paused = false


	Global.reiniciar_vida()


	get_tree().change_scene_to_file(
		caminho_menu
	)
