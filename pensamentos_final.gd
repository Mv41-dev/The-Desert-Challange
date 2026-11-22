extends Node

@export_group("Cena final")
@export var player_path: NodePath = ^"../Player"
@export_range(1.0, 15.0, 0.5) var tempo_observando: float = 6.0
@export_range(0.4, 4.0, 0.1) var duracao_escurecer: float = 1.8
@export_range(0.2, 4.0, 0.1) var silencio_no_escuro: float = 1.4

@export_group("Texto")
@export_range(20, 42, 1) var tamanho_fonte: int = 29
@export_range(0.01, 0.12, 0.005) var intervalo_letra: float = 0.04
@export_range(0.5, 6.0, 0.1) var tempo_leitura: float = 2.1
@export_range(0.1, 2.0, 0.05) var duracao_desaparecer: float = 0.55
@export_range(1.0, 8.0, 0.5) var pausa_antes_do_fim: float = 5.0
@export_range(0.0, 5.0, 0.1) var pausa_entre_falas: float = 1.9

const FALAS: Array[String] = [
	"Eu... escapei?",
	"Esse é mesmo o céu?",
	"Eu achei que não ia sair de lá.",
	"...",
	"Por que aquelas relíquias eram tão bem guardadas?",
	"No começo, achei que fossem só coisas antigas.",
	"Mas elas me salvaram. Mais de uma vez.",
	"Naquela queda... elas apareceram de novo.",
	"...",
	"Será que tinham mesmo algum tipo de magia?",
	"E aqueles monstros? Como foi que eu consegui lutar contra eles?",
	"Eu mal conseguia encarar aquelas sombras.",
	"Mesmo assim, meus golpes funcionavam.",
	"Sem as relíquias, talvez a primeira sombra já tivesse dado conta de mim.",
	"...",
	"Eu não sei o que tinha naquele lugar.",
	"E não vou voltar pra descobrir.",
	"Mas eu saí. Estou aqui.",
	"E agora...?"
]
enum Etapa {
	ESPERANDO_BRANCO,
	OBSERVANDO,
	ESCURECENDO,
	SILENCIO,
	DIGITANDO,
	LENDO,
	SUMINDO,
	PAUSA_ENTRE_FALAS,
	ESPERANDO_FIM,
	MOSTRANDO_FIM,
	CONCLUIDO
}

var _etapa: Etapa = Etapa.ESPERANDO_BRANCO
var _tempo: float = 0.0
var _relogio_letras: float = 0.0
var _indice_fala: int = 0
var _letras: int = 0
var _pausa_atual: float = 0.0
var _fala_anterior: String = ""
var _player: CharacterBody2D = null
var _camada: CanvasLayer = null
var _fundo: ColorRect = null
var _fala: Label = null
var _final: Label = null
var _interface_pronta: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_congelar_player()
	call_deferred("_criar_interface")


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_congelar_player()
	if not _interface_pronta:
		return

	match _etapa:
		Etapa.ESPERANDO_BRANCO:
			_tempo += delta
			if not _tela_branca_anterior_visivel():
				_mudar_etapa(Etapa.OBSERVANDO)
			elif _tempo >= 12.0:
				var camada_presa: Node = get_tree().root.get_node_or_null(^"KingFiveArtifactsWhiteRescue")
				if is_instance_valid(camada_presa):
					camada_presa.queue_free()
				_mudar_etapa(Etapa.OBSERVANDO)

		Etapa.OBSERVANDO:
			_tempo += delta
			if _tempo >= tempo_observando:
				_mudar_etapa(Etapa.ESCURECENDO)

		Etapa.ESCURECENDO:
			_tempo += delta
			_fundo.color.a = clampf(_tempo / maxf(duracao_escurecer, 0.01), 0.0, 1.0)
			if _tempo >= duracao_escurecer:
				_fundo.color.a = 1.0
				_mudar_etapa(Etapa.SILENCIO)

		Etapa.SILENCIO:
			_tempo += delta
			if _tempo >= silencio_no_escuro:
				_comecar_proxima_fala()

		Etapa.DIGITANDO:
			_atualizar_digitacao(delta)

		Etapa.LENDO:
			_tempo += delta
			if _tempo >= tempo_leitura:
				_mudar_etapa(Etapa.SUMINDO)

		Etapa.SUMINDO:
			_tempo += delta
			_fala.modulate.a = 1.0 - clampf(_tempo / maxf(duracao_desaparecer, 0.01), 0.0, 1.0)
			if _tempo >= duracao_desaparecer:
				_fala.text = ""
				_fala.modulate.a = 0.0
				if _indice_fala >= FALAS.size():
					_mudar_etapa(Etapa.ESPERANDO_FIM)
				else:
					_pausa_atual = pausa_entre_falas
					if _fala_anterior == "...":
						_pausa_atual += 2.0
					_mudar_etapa(Etapa.PAUSA_ENTRE_FALAS)

		Etapa.PAUSA_ENTRE_FALAS:
			_tempo += delta
			if _tempo >= _pausa_atual:
				_comecar_proxima_fala()

		Etapa.ESPERANDO_FIM:
			_tempo += delta
			if _tempo >= pausa_antes_do_fim:
				_mudar_etapa(Etapa.MOSTRANDO_FIM)
				_final.visible = true
				_final.modulate.a = 0.0

		Etapa.MOSTRANDO_FIM:
			_tempo += delta
			_final.modulate.a = clampf(_tempo / 2.0, 0.0, 1.0)
			if _tempo >= 2.0:
				_mudar_etapa(Etapa.CONCLUIDO)

		Etapa.CONCLUIDO:
			pass


func _congelar_player() -> void:
	var candidato: Node = get_node_or_null(player_path)
	if not candidato is CharacterBody2D:
		candidato = get_tree().get_first_node_in_group(&"player")
	if not candidato is CharacterBody2D:
		return
	_player = candidato as CharacterBody2D
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_player.set_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_player.set_process_unhandled_key_input(false)

	var hud: Node = get_node_or_null(^"../HUD")
	if hud is CanvasItem:
		(hud as CanvasItem).hide()


func _tela_branca_anterior_visivel() -> bool:
	var camada_branca: Node = get_tree().root.get_node_or_null(^"KingFiveArtifactsWhiteRescue")
	return is_instance_valid(camada_branca) and not camada_branca.is_queued_for_deletion()


func _criar_interface() -> void:
	if _interface_pronta or not is_inside_tree():
		return

	_camada = CanvasLayer.new()
	_camada.name = "EpilogoFinal"
	_camada.layer = 7000
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada)

	_fundo = ColorRect.new()
	_fundo.color = Color(0.0, 0.0, 0.0, 0.0)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_camada.add_child(_fundo)

	_fala = Label.new()
	_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fala.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.add_theme_font_size_override("font_size", tamanho_fonte)
	_fala.add_theme_color_override("font_color", Color.WHITE)
	_fala.visible_characters = 0
	_fala.modulate.a = 0.0
	_fala.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_fala)

	_final = Label.new()
	_final.text = "FIM DE JOGO"
	_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_final.add_theme_font_size_override("font_size", 38)
	_final.add_theme_color_override("font_color", Color.WHITE)
	_final.visible = false
	_final.modulate.a = 0.0
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_final)

	_atualizar_layout()
	if not get_viewport().size_changed.is_connected(_atualizar_layout):
		get_viewport().size_changed.connect(_atualizar_layout)
	_interface_pronta = true


func _atualizar_layout() -> void:
	if not _interface_pronta and not is_instance_valid(_fundo):
		return
	var tamanho: Vector2 = get_viewport().get_visible_rect().size
	if is_instance_valid(_fundo):
		_fundo.position = Vector2.ZERO
		_fundo.size = tamanho
	if is_instance_valid(_fala):
		_fala.position = Vector2(tamanho.x * 0.10, tamanho.y * 0.31)
		_fala.size = Vector2(tamanho.x * 0.80, tamanho.y * 0.38)
	if is_instance_valid(_final):
		_final.position = Vector2(tamanho.x * 0.10, tamanho.y * 0.37)
		_final.size = Vector2(tamanho.x * 0.80, tamanho.y * 0.26)


func _mudar_etapa(nova_etapa: Etapa) -> void:
	_etapa = nova_etapa
	_tempo = 0.0


func _comecar_proxima_fala() -> void:
	if _indice_fala >= FALAS.size():
		_mudar_etapa(Etapa.ESPERANDO_FIM)
		return
	var texto_atual: String = FALAS[_indice_fala]
	_indice_fala += 1
	_fala_anterior = texto_atual
	_fala.text = texto_atual
	_fala.visible_characters = 0
	_fala.modulate.a = 1.0
	_letras = 0
	_relogio_letras = 0.0
	_mudar_etapa(Etapa.DIGITANDO)


func _atualizar_digitacao(delta: float) -> void:
	_relogio_letras -= delta
	var passos: int = 0
	while _relogio_letras <= 0.0 and _letras < _fala.text.length() and passos < 10:
		var letra: String = _fala.text.substr(_letras, 1)
		_letras += 1
		_fala.visible_characters = _letras
		_relogio_letras += intervalo_letra + _pausa_da_letra(letra)
		passos += 1
	if _letras >= _fala.text.length():
		_mudar_etapa(Etapa.LENDO)


func _pausa_da_letra(letra: String) -> float:
	if letra in [".", "?", "!"]:
		return 0.16
	if letra in [",", ":", ";"]:
		return 0.09
	if letra == "\n":
		return 0.16
	return 0.0
