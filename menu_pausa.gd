
extends CanvasLayer

const ARQUIVO_CONFIG: String = "user://controles.cfg"

const NOMES: Dictionary = {
	"move_left": "Andar para esquerda",
	"move_right": "Andar para direita",
	"left": "Andar para esquerda",
	"right": "Andar para direita",
	"jump": "Pular",
	"attack": "Atacar",
	"dash": "Dash",
	"shield": "Escudo",
	"defend": "Defender",
	"wall_climb": "Agarrar na parede",
	"climb": "Escalar",
	"interact": "Interagir",
	"inventory": "Inventário",
	"crouch": "Agachar",
	"run": "Correr"
}

var tela: Control
var pagina_principal: VBoxContainer
var pagina_controles: VBoxContainer
var lista_controles: VBoxContainer
var instrucao: Label

var botoes_teclado: Dictionary = {}
var botoes_mouse: Dictionary = {}
var controles_originais: Dictionary = {}

var acao_captura: StringName = &""
var capturando_mouse: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_guardar_controles_originais()
	_carregar_controles()
	_criar_menu()

	visible = false


func _input(event: InputEvent) -> void:
	# Enquanto o jogador escolhe um botão,
	# o próximo comando será registrado.
	if acao_captura != &"":
		if event is InputEventKey:
			var tecla := event as InputEventKey

			if not tecla.pressed or tecla.echo:
				return

			if tecla.keycode == KEY_ESCAPE:
				_cancelar_captura()
				get_viewport().set_input_as_handled()
				return

			if not capturando_mouse:
				var codigo: int = tecla.physical_keycode

				if codigo == 0:
					codigo = tecla.keycode

				if codigo != 0:
					_definir_controle(
						acao_captura,
						codigo,
						false
					)

				get_viewport().set_input_as_handled()
				return

		if event is InputEventMouseButton:
			var clique := event as InputEventMouseButton

			if not clique.pressed:
				return

			if capturando_mouse:
				_definir_controle(
					acao_captura,
					clique.button_index,
					true
				)

				get_viewport().set_input_as_handled()
				return

		return

	# ESC abre ou fecha o menu.
	if event is InputEventKey:
		var tecla := event as InputEventKey

		if not tecla.pressed or tecla.echo:
			return

		if tecla.keycode != KEY_ESCAPE:
			return

		get_viewport().set_input_as_handled()

		if visible:
			if pagina_controles.visible:
				_abrir_pagina_principal()
			else:
				_continuar_jogo()
		else:
			# Não interfere no pergaminho ou
			# em outras cutscenes que pausam o jogo.
			if not get_tree().paused:
				_abrir_menu()


func _abrir_menu() -> void:
	visible = true
	_abrir_pagina_principal()
	get_tree().paused = true


func _continuar_jogo() -> void:
	visible = false
	acao_captura = &""
	get_tree().paused = false


func _abrir_pagina_principal() -> void:
	acao_captura = &""

	pagina_principal.show()
	pagina_controles.hide()


func _abrir_pagina_controles() -> void:
	pagina_principal.hide()
	pagina_controles.show()

	instrucao.text = (
		"Clique no controle que deseja alterar."
	)

	_atualizar_botoes()


func _criar_menu() -> void:
	tela = Control.new()
	tela.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	tela.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tela)

	# Fundo escurecido.
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	fundo.color = Color(0.025, 0.02, 0.015, 0.83)
	tela.add_child(fundo)

	var centralizador := CenterContainer.new()
	centralizador.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	tela.add_child(centralizador)

	var painel := PanelContainer.new()

	var largura: float = minf(
		760.0,
		float(get_viewport().size.x) - 32.0
	)

	var altura: float = minf(
		550.0,
		float(get_viewport().size.y) - 32.0
	)

	painel.custom_minimum_size = Vector2(
		maxf(largura, 300.0),
		maxf(altura, 240.0)
	)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.13, 0.105, 0.075)
	estilo.border_color = Color(0.73, 0.55, 0.28)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(12)

	painel.add_theme_stylebox_override(
		"panel", estilo
	)

	centralizador.add_child(painel)

	var margens := MarginContainer.new()

	for lado in [
		"margin_left",
		"margin_right",
		"margin_top",
		"margin_bottom"
	]:
		margens.add_theme_constant_override(
			lado, 18
		)

	painel.add_child(margens)

	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override(
		"separation", 12
	)
	margens.add_child(corpo)

	var titulo := Label.new()
	titulo.text = "THE DESERT CHALLENGE"
	titulo.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	titulo.add_theme_font_size_override(
		"font_size", 25
	)
	titulo.add_theme_color_override(
		"font_color",
		Color(0.97, 0.85, 0.61)
	)
	corpo.add_child(titulo)

	pagina_principal = VBoxContainer.new()
	pagina_principal.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	pagina_principal.add_theme_constant_override(
		"separation", 15
	)
	corpo.add_child(pagina_principal)

	var legenda := Label.new()
	legenda.text = "JOGO PAUSADO"
	legenda.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	legenda.add_theme_font_size_override(
		"font_size", 19
	)
	pagina_principal.add_child(legenda)

	_adicionar_botao(
		pagina_principal,
		"Continuar jogo",
		_continuar_jogo
	)

	_adicionar_botao(
		pagina_principal,
		"Configurar controles",
		_abrir_pagina_controles
	)

	_adicionar_botao(
		pagina_principal,
		"Sair do jogo",
		_sair_do_jogo
	)

	var dica := Label.new()
	dica.text = "ESC para continuar"
	dica.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	pagina_principal.add_child(dica)

	# Segunda página: configurações.
	pagina_controles = VBoxContainer.new()
	pagina_controles.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	corpo.add_child(pagina_controles)

	instrucao = Label.new()
	instrucao.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	instrucao.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	pagina_controles.add_child(instrucao)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	pagina_controles.add_child(rolagem)

	lista_controles = VBoxContainer.new()
	lista_controles.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	lista_controles.add_theme_constant_override(
		"separation", 8
	)
	rolagem.add_child(lista_controles)

	_criar_lista_controles()

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override(
		"separation", 12
	)
	pagina_controles.add_child(rodape)

	_adicionar_botao(
		rodape,
		"Restaurar padrões",
		_restaurar_padroes
	)

	_adicionar_botao(
		rodape,
		"Voltar",
		_abrir_pagina_principal
	)

	pagina_controles.hide()


func _adicionar_botao(
	pai: Node,
	nome: String,
	acao: Callable
) -> void:
	var botao := Button.new()
	botao.text = nome
	botao.custom_minimum_size.y = 45
	botao.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	botao.pressed.connect(acao)
	pai.add_child(botao)


func _acoes_do_jogo() -> Array[StringName]:
	var resultado: Array[StringName] = []

	for acao: StringName in InputMap.get_actions():
		# Não altera as ações internas da interface.
		if str(acao).begins_with("ui_"):
			continue

		resultado.append(acao)

	return resultado


func _criar_lista_controles() -> void:
	for acao: StringName in _acoes_do_jogo():
		var linha := HBoxContainer.new()
		lista_controles.add_child(linha)

		var nome := Label.new()

		nome.text = str(
			NOMES.get(
				str(acao),
				str(acao).replace("_", " ").capitalize()
			)
		)

		nome.custom_minimum_size.x = 180
		nome.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		linha.add_child(nome)

		var teclado := Button.new()
		teclado.custom_minimum_size.x = 165
		linha.add_child(teclado)

		teclado.pressed.connect(
			_iniciar_captura.bind(acao, false)
		)

		var mouse := Button.new()
		mouse.custom_minimum_size.x = 135
		linha.add_child(mouse)

		mouse.pressed.connect(
			_iniciar_captura.bind(acao, true)
		)

		botoes_teclado[acao] = teclado
		botoes_mouse[acao] = mouse

	_atualizar_botoes()


func _iniciar_captura(
	acao: StringName,
	mouse: bool
) -> void:
	acao_captura = acao
	capturando_mouse = mouse

	instrucao.text = (
		"Pressione o novo botão. ESC cancela."
	)

	_atualizar_botoes()


func _cancelar_captura() -> void:
	acao_captura = &""

	instrucao.text = (
		"Alteração cancelada."
	)

	_atualizar_botoes()


func _definir_controle(
	acao: StringName,
	codigo: int,
	mouse: bool
) -> void:
	_trocar_entrada(acao, codigo, mouse)

	acao_captura = &""

	_salvar_controles()
	_atualizar_botoes()

	instrucao.text = "Controle alterado e salvo!"


func _trocar_entrada(
	acao: StringName,
	codigo: int,
	mouse: bool
) -> void:
	# Remove somente os controles do tipo escolhido.
	# Assim, trocar uma tecla não apaga o mouse.
	for evento: InputEvent in InputMap.action_get_events(
		acao
	):
		if mouse and evento is InputEventMouseButton:
			InputMap.action_erase_event(
				acao, evento
			)

		elif not mouse and evento is InputEventKey:
			InputMap.action_erase_event(
				acao, evento
			)

	if codigo <= 0:
		return

	if mouse:
		var novo_mouse := InputEventMouseButton.new()
		novo_mouse.button_index = codigo

		InputMap.action_add_event(
			acao, novo_mouse
		)

	else:
		var nova_tecla := InputEventKey.new()
		nova_tecla.physical_keycode = codigo

		InputMap.action_add_event(
			acao, nova_tecla
		)


func _atualizar_botoes() -> void:
	for acao: StringName in botoes_teclado.keys():
		var botao_teclado: Button = (
			botoes_teclado[acao]
		)

		var botao_mouse: Button = (
			botoes_mouse[acao]
		)

		botao_teclado.text = (
			"Tecla: " + _nome_tecla(acao)
		)

		botao_mouse.text = (
			"Mouse: " + _nome_mouse(acao)
		)

		if acao == acao_captura:
			if capturando_mouse:
				botao_mouse.text = "Clique agora..."
			else:
				botao_teclado.text = "Aperte tecla..."


func _nome_tecla(acao: StringName) -> String:
	for evento: InputEvent in InputMap.action_get_events(
		acao
	):
		if evento is InputEventKey:
			return evento.as_text()

	return "Nenhuma"


func _nome_mouse(acao: StringName) -> String:
	for evento: InputEvent in InputMap.action_get_events(
		acao
	):
		if evento is InputEventMouseButton:
			var clique := evento as InputEventMouseButton

			match clique.button_index:
				MOUSE_BUTTON_LEFT:
					return "Esquerdo"
				MOUSE_BUTTON_RIGHT:
					return "Direito"
				MOUSE_BUTTON_MIDDLE:
					return "Meio"

			return evento.as_text()

	return "Nenhum"


func _codigo_atual(
	acao: StringName,
	mouse: bool
) -> int:
	for evento: InputEvent in InputMap.action_get_events(
		acao
	):
		if mouse and evento is InputEventMouseButton:
			return (
				evento as InputEventMouseButton
			).button_index

		if not mouse and evento is InputEventKey:
			var tecla := evento as InputEventKey

			if tecla.physical_keycode != 0:
				return tecla.physical_keycode

			return tecla.keycode

	return -1


func _guardar_controles_originais() -> void:
	for acao: StringName in _acoes_do_jogo():
		var copia: Array[InputEvent] = []

		for evento: InputEvent in InputMap.action_get_events(
			acao
		):
			copia.append(
				evento.duplicate() as InputEvent
			)

		controles_originais[acao] = copia


func _restaurar_padroes() -> void:
	for acao: StringName in controles_originais.keys():
		InputMap.action_erase_events(acao)

		var eventos: Array = controles_originais[acao]

		for evento: InputEvent in eventos:
			InputMap.action_add_event(
				acao,
				evento.duplicate() as InputEvent
			)

	_salvar_controles()
	_atualizar_botoes()

	instrucao.text = "Controles restaurados!"


func _salvar_controles() -> void:
	var config := ConfigFile.new()

	for acao: StringName in _acoes_do_jogo():
		config.set_value(
			"teclado",
			str(acao),
			_codigo_atual(acao, false)
		)

		config.set_value(
			"mouse",
			str(acao),
			_codigo_atual(acao, true)
		)

	var erro: Error = config.save(
		ARQUIVO_CONFIG
	)

	if erro != OK:
		push_warning(
			"Não foi possível salvar os controles."
		)


func _carregar_controles() -> void:
	var config := ConfigFile.new()

	if config.load(ARQUIVO_CONFIG) != OK:
		return

	for acao: StringName in _acoes_do_jogo():
		if config.has_section_key(
			"teclado", str(acao)
		):
			_trocar_entrada(
				acao,
				int(config.get_value(
					"teclado", str(acao)
				)),
				false
			)

		if config.has_section_key(
			"mouse", str(acao)
		):
			_trocar_entrada(
				acao,
				int(config.get_value(
					"mouse", str(acao)
				)),
				true
			)


func _sair_do_jogo() -> void:
	get_tree().paused = false
	get_tree().quit()
