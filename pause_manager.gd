
extends Node

const ARQUIVO_CONTROLES: String = "user://controles.cfg"

const NOMES_ACOES: Dictionary = {
	"move_left": "Andar para esquerda",
	"move_right": "Andar para direita",
	"left": "Andar para esquerda",
	"right": "Andar para direita",
	"jump": "Pular",
	"attack": "Atacar",
	"dash": "Dash",
	"shield": "Escudo",
	"defend": "Defender",
	"interact": "Interagir",
	"inventory": "Inventário",
	"run": "Correr",
	"climb": "Escalar",
	"wall_climb": "Agarrar na parede"
}

var camada: CanvasLayer
var pagina_principal: VBoxContainer
var pagina_controles: VBoxContainer
var lista_controles: VBoxContainer
var instrucao: Label

var botoes_teclado: Dictionary = {}
var botoes_mouse: Dictionary = {}
var controles_padrao: Dictionary = {}

var menu_aberto: bool = false
var acao_capturada: StringName = &""
var captura_mouse: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Diagnostico original.
	print("CENA ATUAL: ", get_path())
	print("FILHOS DO PAUSEMANAGER:")

	for child in get_children():
		print(child.name)

	print("PROCURANDO PAUSEMENU:")
	print(get_node_or_null("PauseMenu"))

	_guardar_padroes()
	_carregar_controles()
	_criar_menu()


func _input(event: InputEvent) -> void:
	if acao_capturada != &"":
		_processar_captura(event)
		return

	if not event is InputEventKey:
		return

	var tecla := event as InputEventKey

	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode != KEY_ESCAPE:
		return

	if menu_aberto:
		if pagina_controles.visible:
			_mostrar_principal()
		else:
			_continuar()
	else:
		# Nao abre por cima de um pergaminho
		# ou cutscene que ja pausou o jogo.
		if get_tree().paused:
			return

		_abrir_menu()

	get_viewport().set_input_as_handled()


func _abrir_menu() -> void:
	menu_aberto = true
	camada.show()
	_mostrar_principal()
	get_tree().paused = true


func _continuar() -> void:
	menu_aberto = false
	acao_capturada = &""
	camada.hide()
	get_tree().paused = false


func _mostrar_principal() -> void:
	acao_capturada = &""
	pagina_controles.hide()
	pagina_principal.show()


func _mostrar_controles() -> void:
	pagina_principal.hide()
	pagina_controles.show()

	instrucao.text = (
		"Selecione uma ação para mudar seu controle."
	)

	_atualizar_botoes()


func _criar_menu() -> void:
	camada = CanvasLayer.new()
	camada.name = "MenuPausaDinamico"
	camada.layer = 120
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)

	var raiz := Control.new()
	camada.add_child(raiz)
	raiz.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP

	var fundo := ColorRect.new()
	raiz.add_child(fundo)
	fundo.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	fundo.color = Color(0.02, 0.018, 0.014, 0.85)

	var centro := CenterContainer.new()
	raiz.add_child(centro)
	centro.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var painel := PanelContainer.new()
	centro.add_child(painel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.14, 0.11, 0.075)
	estilo.border_color = Color(0.76, 0.56, 0.29)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)

	painel.add_theme_stylebox_override(
		"panel", estilo
	)

	var tamanho: Vector2 = get_viewport().get_visible_rect().size

	painel.custom_minimum_size = Vector2(
		minf(740.0, maxf(320.0, tamanho.x - 32.0)),
		minf(550.0, maxf(260.0, tamanho.y - 32.0))
	)

	var margens := MarginContainer.new()
	painel.add_child(margens)

	for lado: String in [
		"margin_left",
		"margin_right",
		"margin_top",
		"margin_bottom"
	]:
		margens.add_theme_constant_override(lado, 18)

	var corpo := VBoxContainer.new()
	margens.add_child(corpo)
	corpo.add_theme_constant_override("separation", 15)

	var titulo := Label.new()
	titulo.text = "THE DESERT CHALLENGE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override(
		"font_color", Color(0.97, 0.86, 0.61)
	)
	corpo.add_child(titulo)

	pagina_principal = VBoxContainer.new()
	pagina_principal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pagina_principal.add_theme_constant_override(
		"separation", 14
	)
	corpo.add_child(pagina_principal)

	var subtitulo := Label.new()
	subtitulo.text = "JOGO PAUSADO"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 20)
	pagina_principal.add_child(subtitulo)

	_criar_botao(
		pagina_principal,
		"Continuar",
		Callable(self, "_continuar")
	)

	_criar_botao(
		pagina_principal,
		"Configurar controles",
		Callable(self, "_mostrar_controles")
	)

	_criar_botao(
		pagina_principal,
		"Sair do jogo",
		Callable(self, "_sair")
	)

	var dica := Label.new()
	dica.text = "ESC para continuar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagina_principal.add_child(dica)

	pagina_controles = VBoxContainer.new()
	pagina_controles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(pagina_controles)

	instrucao = Label.new()
	instrucao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instrucao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pagina_controles.add_child(instrucao)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pagina_controles.add_child(rolagem)

	lista_controles = VBoxContainer.new()
	lista_controles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_controles.add_theme_constant_override(
		"separation", 8
	)
	rolagem.add_child(lista_controles)

	_criar_lista_controles()

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 10)
	pagina_controles.add_child(rodape)

	_criar_botao(
		rodape,
		"Restaurar padrões",
		Callable(self, "_restaurar_padroes")
	)

	_criar_botao(
		rodape,
		"Voltar",
		Callable(self, "_mostrar_principal")
	)

	pagina_controles.hide()
	camada.hide()


func _criar_botao(
	pai: Control,
	nome: String,
	acao: Callable
) -> Button:
	var botao := Button.new()
	botao.text = nome
	botao.custom_minimum_size.y = 42
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.pressed.connect(acao)
	pai.add_child(botao)

	return botao


func _acoes_do_jogo() -> Array[StringName]:
	var resultado: Array[StringName] = []

	for acao: StringName in InputMap.get_actions():
		# Preserva os controles internos da interface.
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
			NOMES_ACOES.get(
				str(acao),
				str(acao).replace("_", " ").capitalize()
			)
		)
		nome.custom_minimum_size.x = 160
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)

		var teclado := Button.new()
		teclado.custom_minimum_size.x = 150
		linha.add_child(teclado)

		teclado.pressed.connect(
			_iniciar_captura.bind(acao, false)
		)

		var mouse := Button.new()
		mouse.custom_minimum_size.x = 125
		linha.add_child(mouse)

		mouse.pressed.connect(
			_iniciar_captura.bind(acao, true)
		)

		botoes_teclado[acao] = teclado
		botoes_mouse[acao] = mouse

	_atualizar_botoes()


func _iniciar_captura(
	acao: StringName,
	usar_mouse: bool
) -> void:
	acao_capturada = acao
	captura_mouse = usar_mouse

	if captura_mouse:
		instrucao.text = (
			"Clique com o novo botão do mouse. "
			+ "ESC para cancelar."
		)
	else:
		instrucao.text = (
			"Pressione a nova tecla. "
			+ "ESC para cancelar."
		)

	_atualizar_botoes()


func _processar_captura(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey

		if not tecla.pressed or tecla.echo:
			return

		if tecla.keycode == KEY_ESCAPE:
			_cancelar_captura()
			get_viewport().set_input_as_handled()
			return

		if captura_mouse:
			return

		var novo := InputEventKey.new()

		if tecla.physical_keycode != 0:
			novo.physical_keycode = tecla.physical_keycode
		else:
			novo.keycode = tecla.keycode

		novo.shift_pressed = tecla.shift_pressed
		novo.ctrl_pressed = tecla.ctrl_pressed
		novo.alt_pressed = tecla.alt_pressed
		novo.meta_pressed = tecla.meta_pressed

		_definir_controle(novo)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var clique := event as InputEventMouseButton

		if not clique.pressed or not captura_mouse:
			return

		if clique.button_index not in [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_XBUTTON1,
			MOUSE_BUTTON_XBUTTON2
		]:
			return

		var novo := InputEventMouseButton.new()
		novo.button_index = clique.button_index

		_definir_controle(novo)
		get_viewport().set_input_as_handled()


func _cancelar_captura() -> void:
	acao_capturada = &""
	instrucao.text = "Alteração cancelada."
	_atualizar_botoes()


func _definir_controle(evento_novo: InputEvent) -> void:
	var acao: StringName = acao_capturada
	var mouse: bool = evento_novo is InputEventMouseButton

	for evento: InputEvent in InputMap.action_get_events(acao):
		if mouse and evento is InputEventMouseButton:
			InputMap.action_erase_event(acao, evento)

		elif not mouse and evento is InputEventKey:
			InputMap.action_erase_event(acao, evento)

	InputMap.action_add_event(acao, evento_novo)

	acao_capturada = &""

	_salvar_controles()
	_atualizar_botoes()

	instrucao.text = "Controle alterado e salvo!"


func _atualizar_botoes() -> void:
	for acao: StringName in botoes_teclado.keys():
		var botao_teclado: Button = botoes_teclado[acao]
		var botao_mouse: Button = botoes_mouse[acao]

		botao_teclado.text = (
			"Tecla: " + _nome_controle(acao, false)
		)

		botao_mouse.text = (
			"Mouse: " + _nome_controle(acao, true)
		)

		if acao == acao_capturada:
			if captura_mouse:
				botao_mouse.text = "Clique agora..."
			else:
				botao_teclado.text = "Aperte tecla..."


func _nome_controle(
	acao: StringName,
	mouse: bool
) -> String:
	var nomes: PackedStringArray = PackedStringArray()

	for evento: InputEvent in InputMap.action_get_events(acao):
		if mouse and evento is InputEventMouseButton:
			var clique := evento as InputEventMouseButton

			match clique.button_index:
				MOUSE_BUTTON_LEFT:
					nomes.append("Esquerdo")
				MOUSE_BUTTON_RIGHT:
					nomes.append("Direito")
				MOUSE_BUTTON_MIDDLE:
					nomes.append("Meio")
				_:
					nomes.append(clique.as_text())

		elif not mouse and evento is InputEventKey:
			nomes.append(evento.as_text())

	if nomes.is_empty():
		return "Nenhum"

	return ", ".join(nomes)


func _guardar_padroes() -> void:
	for acao: StringName in _acoes_do_jogo():
		var eventos: Array[InputEvent] = []

		for evento: InputEvent in InputMap.action_get_events(acao):
			eventos.append(
				evento.duplicate(true) as InputEvent
			)

		controles_padrao[acao] = eventos


func _restaurar_padroes() -> void:
	for acao: StringName in controles_padrao.keys():
		InputMap.action_erase_events(acao)

		var eventos: Array = controles_padrao[acao]

		for evento: InputEvent in eventos:
			InputMap.action_add_event(
				acao,
				evento.duplicate(true) as InputEvent
			)

	_salvar_controles()
	_atualizar_botoes()

	instrucao.text = "Controles restaurados!"


func _salvar_controles() -> void:
	var arquivo := ConfigFile.new()

	for acao: StringName in _acoes_do_jogo():
		var registros: Array[Dictionary] = []

		for evento: InputEvent in InputMap.action_get_events(acao):
			if evento is InputEventKey:
				var tecla := evento as InputEventKey

				registros.append({
					"tipo": "tecla",
					"fisica": int(tecla.physical_keycode),
					"codigo": int(tecla.keycode),
					"shift": tecla.shift_pressed,
					"ctrl": tecla.ctrl_pressed,
					"alt": tecla.alt_pressed,
					"meta": tecla.meta_pressed
				})

			elif evento is InputEventMouseButton:
				var clique := evento as InputEventMouseButton

				registros.append({
					"tipo": "mouse",
					"botao": int(clique.button_index)
				})

		arquivo.set_value(
			"controles",
			str(acao),
			registros
		)

	var erro: Error = arquivo.save(ARQUIVO_CONTROLES)

	if erro != OK:
		push_warning(
			"Não foi possível salvar os controles."
		)


func _carregar_controles() -> void:
	var arquivo := ConfigFile.new()

	if arquivo.load(ARQUIVO_CONTROLES) != OK:
		return

	for acao: StringName in _acoes_do_jogo():
		if not arquivo.has_section_key(
			"controles", str(acao)
		):
			continue

		var registros: Variant = arquivo.get_value(
			"controles", str(acao), []
		)

		if not registros is Array:
			continue

		# Remove apenas teclado e mouse.
		# Controles de gamepad ficam intactos.
		for evento: InputEvent in InputMap.action_get_events(acao):
			if evento is InputEventKey \
			or evento is InputEventMouseButton:
				InputMap.action_erase_event(acao, evento)

		for registro: Variant in registros:
			if not registro is Dictionary:
				continue

			var tipo: String = str(
				registro.get("tipo", "")
			)

			if tipo == "tecla":
				var tecla := InputEventKey.new()
				tecla.physical_keycode = int(
					registro.get("fisica", 0)
				)
				tecla.keycode = int(
					registro.get("codigo", 0)
				)
				tecla.shift_pressed = bool(
					registro.get("shift", false)
				)
				tecla.ctrl_pressed = bool(
					registro.get("ctrl", false)
				)
				tecla.alt_pressed = bool(
					registro.get("alt", false)
				)
				tecla.meta_pressed = bool(
					registro.get("meta", false)
				)

				InputMap.action_add_event(acao, tecla)

			elif tipo == "mouse":
				var clique := InputEventMouseButton.new()
				clique.button_index = int(
					registro.get("botao", 0)
				)

				if clique.button_index > 0:
					InputMap.action_add_event(acao, clique)


func _sair() -> void:
	get_tree().paused = false
	get_tree().quit()
