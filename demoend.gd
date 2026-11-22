extends Area2D


@export_group("Destino")
@export_file("*.tscn") var caminho_fase_6: String = "res://level_6.tscn"

@export_group("Narracao")
@export_range(0.010, 0.085, 0.002) var tempo_letra: float = 0.052
@export_range(0.0, 0.22, 0.01) var pausa_espaco: float = 0.045
@export_range(0.0, 0.6, 0.02) var pausa_pontuacao: float = 0.34
@export var permitir_acelerar_texto: bool = true
@export var pedir_tecla_ao_final: bool = false

var ativado: bool = false
var pode_continuar: bool = false
var acelerando: bool = false

var overlay: CanvasLayer = null
var fundo: ColorRect = null
var texto: Label = null
var continuar: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if ativado or not body.is_in_group("player"):
		return
	ativado = true
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO
	_criar_tela()
	get_tree().paused = true
	_rodar_queda()


func _criar_tela() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "QuedaSemFim"
	overlay.layer = 1200
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	fundo = ColorRect.new()
	fundo.color = Color(0.015, 0.012, 0.021, 1.0)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(fundo)

	texto = Label.new()
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", 26)
	texto.add_theme_color_override("font_color", Color(0.94, 0.93, 0.96))
	texto.modulate.a = 0.0
	texto.visible_characters = 0
	overlay.add_child(texto)

	continuar = Label.new()
	continuar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continuar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continuar.text = "Pressione uma tecla para despertar"
	continuar.add_theme_font_size_override("font_size", 17)
	continuar.add_theme_color_override("font_color", Color(0.70, 0.68, 0.73))
	continuar.modulate.a = 0.0
	overlay.add_child(continuar)

	_atualizar_layout()
	if not get_viewport().size_changed.is_connected(_atualizar_layout):
		get_viewport().size_changed.connect(_atualizar_layout)


func _atualizar_layout() -> void:
	var tela: Vector2 = get_viewport_rect().size
	if is_instance_valid(fundo):
		fundo.position = Vector2.ZERO
		fundo.size = tela
	if is_instance_valid(texto):
		texto.position = Vector2(tela.x * 0.08, tela.y * 0.12)
		texto.size = Vector2(tela.x * 0.84, tela.y * 0.74)
	if is_instance_valid(continuar):
		continuar.position = Vector2(0.0, tela.y * 0.82)
		continuar.size = Vector2(tela.x, 58.0)


func _rodar_queda() -> void:
	await _esperar(3.30)
	await _frase("...", 1.84)
	await _esperar(3.30)

	await _frase("Eu... ainda estou caindo?", 2.58)
	await _esperar(1.50)
	await _frase("Já era pra eu ter batido no chão.", 2.45)
	await _esperar(2.04)
	await _frase("Não consigo ver nada.", 2.31)
	await _esperar(1.80)

	await _frase("...", 1.77)
	await _esperar(2.64)

	await _frase("Eu lembro do portão.", 2.11)
	await _esperar(1.44)
	await _frase("Tinha alguma coisa vindo atrás de mim.", 2.38)
	await _esperar(1.50)
	await _frase("Eu corri...", 2.24)
	await _esperar(1.62)
	await _frase("E aí o chão cedeu.", 2.18)
	await _pulsar_queda()
	await _esperar(2.28)

	await _frase("A luz lá em cima foi ficando menor.", 2.52)
	await _esperar(1.80)
	await _frase("Depois... desapareceu.", 2.24)
	await _esperar(2.52)

	await _frase("...", 2.24)
	await _esperar(3.00)

	await _frase("Nem o vento eu escuto mais.", 2.58)
	await _esperar(2.10)
	await _frase("Eu não sei quanto tempo passou.", 2.52)
	await _esperar(2.40)
	await _frase("Será que eu já cheguei ao fundo...?", 2.79)
	await _esperar(2.22)

	await _frase("...", 2.11)
	await _esperar(3.12)

	await _frase("Tem alguma coisa aqui.", 2.11)
	await _esperar(1.86)
	await _frase("Na escuridão.", 2.11)
	await _esperar(1.92)
	await _frase("Está chegando perto.", 2.38)
	await _esperar(2.22)

	await _frase("...", 2.18)
	await _esperar(4.00)

	await _frase("Você ainda não conseguiu o que queria.", 3.10)
	await _esperar(2.30)
	await _frase("ACORDE!", 2.24, true)
	await _esperar(1.92)

	if pedir_tecla_ao_final:
		pode_continuar = true
		var entrada: Tween = create_tween()
		entrada.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		entrada.tween_property(continuar, "modulate:a", 1.0, 0.55)
	else:
		_entrar_no_abismo()


func _frase(frase: String, tempo_apos: float, urgente: bool = false) -> void:
	if not is_instance_valid(texto):
		return
	texto.text = frase
	texto.visible_characters = 0
	texto.modulate.a = 1.0
	acelerando = false

	if urgente:
		texto.add_theme_font_size_override("font_size", 39)
		texto.add_theme_color_override("font_color", Color(1.0, 0.93, 0.94))
	else:
		texto.add_theme_font_size_override("font_size", 26)
		texto.add_theme_color_override("font_color", Color(0.94, 0.93, 0.96))

	for i: int in range(frase.length()):
		texto.visible_characters = i + 1
		if acelerando:
			continue
		var caractere: String = frase.substr(i, 1)
		var pausa: float = maxf(tempo_letra, 0.045)
		if caractere == " ":
			pausa += maxf(pausa_espaco, 0.04)
		elif caractere in [".", "!", "?", ":", ";"]:
			pausa += maxf(pausa_pontuacao, 0.30)
		elif caractere == ",":
			pausa += maxf(pausa_pontuacao, 0.30) * 0.58
		elif caractere == "\n":
			pausa += maxf(pausa_pontuacao, 0.30) * 0.9
		await _esperar(pausa)

	texto.visible_characters = -1
	await _esperar(tempo_apos)
	var saida: Tween = create_tween()
	saida.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	saida.tween_property(texto, "modulate:a", 0.0, 0.70)
	await saida.finished
	await _esperar(0.50)


func _pulsar_queda() -> void:
	if not is_instance_valid(fundo):
		return
	var pulso: Tween = create_tween()
	pulso.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulso.tween_property(fundo, "color", Color(0.17, 0.13, 0.15, 1.0), 0.08)
	pulso.tween_property(fundo, "color", Color(0.0, 0.0, 0.0, 1.0), 0.32)
	await pulso.finished


func _esperar(tempo: float) -> void:
	await get_tree().create_timer(tempo, true).timeout


func _input(event: InputEvent) -> void:
	if not ativado or not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).is_echo():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if pode_continuar:
		pode_continuar = false
		get_viewport().set_input_as_handled()
		_entrar_no_abismo()
	elif permitir_acelerar_texto:
		acelerando = true
		get_viewport().set_input_as_handled()


func _entrar_no_abismo() -> void:
	get_tree().paused = false
	if has_node("/root/Global"):
		Global.reiniciar_vida()
	var erro: Error = get_tree().change_scene_to_file(caminho_fase_6)
	if erro != OK:
		push_error("DEMOEND: cena de destino nao encontrada: " + caminho_fase_6)
