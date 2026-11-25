
extends Area2D

# Cena configurada no Inspector.
@export_file("*.tscn") var next_scene_path: String = ""

@export_group("Configuracao do Portal")

# 0 = detectar pelo nome da cena.
@export_range(0, 5, 1) var fase_atual: int = 0

# Automatico: compara os numeros das cenas.
# Avancar: sempre exige o artefato da fase.
# Voltar: nao exige artefato.
@export_enum("Automatico", "Avancar", "Voltar")
var modo_portal: int = 0

@export_group("Aviso")
@export var tempo_aviso: float = 2.8

const ARTEFATOS_POR_FASE: Dictionary = {
	1: "escaravelho",
	2: "calice",
	3: "ankh",
	4: "mascara",
	5: "lapislazulidofarao"
}

var _transicao_iniciada: bool = false

var _camada: CanvasLayer
var _painel: Panel
var _texto: Label
var _numero_aviso: int = 0


func _ready() -> void:
	_criar_aviso()

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)


func _on_body_entered(body: Node2D) -> void:
	if _transicao_iniciada:
		return

	if not body.is_in_group("player"):
		return

	if not ResourceLoader.exists(next_scene_path):
		push_error(
			"Portal: cena inexistente: "
			+ next_scene_path
		)
		return

	var origem: int = fase_atual

	if origem == 0:
		var cena: Node = get_tree().current_scene

		if cena != null:
			origem = _identificar_fase(
				cena.scene_file_path
			)

	var destino: int = _identificar_fase(
		next_scene_path
	)

	var eh_retorno: bool = false

	match modo_portal:
		1:
			# Avancar: exige artefato.
			eh_retorno = false

		2:
			# Voltar: entrada livre.
			eh_retorno = true

		_:
			# Automatico.
			# Um destino desconhecido NUNCA
			# ignora a verificacao.
			eh_retorno = (
				origem > 0
				and destino > 0
				and destino <= origem
			)

	print(
		"[PORTAL] Origem: ", origem,
		" | Destino: ", destino,
		" | Retorno: ", eh_retorno
	)

	if not eh_retorno:
		if not ARTEFATOS_POR_FASE.has(origem):
			push_warning(
				"[PORTAL] Fase nao identificada. "
				+ "Configure fase_atual no Inspector."
			)

			_mostrar_aviso(
				"Portal bloqueado!\n"
				+ "Fase atual nao identificada."
			)
			return

		var artefato: String = str(
			ARTEFATOS_POR_FASE[origem]
		)

		var possui: bool = (
			GerenciadorArtefatos.possui_artefato(
				artefato
			)
		)

		print(
			"[PORTAL] Artefato exigido: ",
			artefato
		)

		print(
			"[PORTAL] Possui: ",
			possui
		)

		print(
			"[PORTAL] Artefatos registrados: ",
			GerenciadorArtefatos.coletados
		)

		if not possui:
			_mostrar_aviso(
				"Voce nao pegou o artefato "
				+ "pra poder passar de fase!"
			)
			return

	# Transicao original.
	_transicao_iniciada = true

	set_deferred(
		"monitoring",
		false
	)

	call_deferred(
		"_trocar_fase"
	)


func _identificar_fase(caminho: String) -> int:
	if caminho.is_empty():
		return 0

	var nome: String = (
		caminho.get_file().get_basename()
	)

	var regex := RegEx.new()

	var erro: Error = regex.compile(
		"(?i)(level|fase|nivel)[ _-]*0*([0-9]+)"
	)

	if erro != OK:
		return 0

	var resultado: RegExMatch = regex.search(
		nome
	)

	if resultado == null:
		return 0

	return int(
		resultado.get_string(2)
	)


func _criar_aviso() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 110
	add_child(_camada)

	_painel = Panel.new()

	_painel.set_anchors_preset(
		Control.PRESET_CENTER_TOP
	)

	_painel.offset_left = -330.0
	_painel.offset_right = 330.0
	_painel.offset_top = 35.0
	_painel.offset_bottom = 120.0

	_painel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var estilo := StyleBoxFlat.new()

	estilo.bg_color = Color(
		0.08, 0.06, 0.05, 0.94
	)

	estilo.border_color = Color(
		0.95, 0.72, 0.30
	)

	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)

	_painel.add_theme_stylebox_override(
		"panel",
		estilo
	)

	_camada.add_child(_painel)
	_painel.hide()

	_texto = Label.new()

	_texto.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_texto.offset_left = 15.0
	_texto.offset_right = -15.0

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
		20
	)

	_texto.add_theme_color_override(
		"font_color",
		Color(1.0, 0.91, 0.75)
	)

	_painel.add_child(_texto)


func _mostrar_aviso(mensagem: String) -> void:
	_numero_aviso += 1

	var numero_atual: int = _numero_aviso

	_texto.text = mensagem
	_painel.show()

	await get_tree().create_timer(
		tempo_aviso
	).timeout

	if not is_inside_tree():
		return

	if numero_atual == _numero_aviso:
		_painel.hide()


func _trocar_fase() -> void:
	var erro: Error = (
		get_tree().change_scene_to_file(
			next_scene_path
		)
	)

	if erro != OK:
		push_error(
			"Portal: nao foi possivel carregar "
			+ next_scene_path
		)

		_transicao_iniciada = false

		set_deferred(
			"monitoring",
			true
		)
