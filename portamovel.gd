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


@export_group("Desafio Educacional")
@export_range(200.0, 600.0, 10.0) var distancia_para_rearmar: float = 290.0
@export_range(2.0, 12.0, 0.5) var velocidade_roda_selecao: float = 5.0


@export_group("Camera Cinematica")
@export var usar_camera_ritual: bool = true

@export_range(0.2, 3.0, 0.05) var duracao_camera_entrada: float = 1.2
@export_range(1.0, 1.8, 0.01) var zoom_camera_ritual: float = 1.08

@export_range(0.0, 1.0, 0.05) var fracao_pan_camera: float = 0.22
@export_range(0.0, 300.0, 5.0) var pan_maximo_camera: float = 80.0
@export_range(-250.0, 100.0, 5.0) var offset_vertical_camera: float = -105.0

@export_range(0.2, 3.0, 0.05) var duracao_camera_saida: float = 1.2
@export_range(0.0, 1.0, 0.05) var progresso_porta_restaurar_camera: float = 0.32


@export_group("Pensamento em tela preta")
@export_range(0.015, 0.12, 0.005) var intervalo_letra_pensamento: float = 0.048
@export_range(0.05, 0.7, 0.01) var pausa_pontuacao_pensamento: float = 0.25
@export_range(0.1, 2.0, 0.05) var espera_apos_pensamento: float = 0.75
@export_range(20, 52, 1) var tamanho_fonte_pensamento: int = 30

@export_group("Ruptura - vento e neblina")
@export var efeitos_ruptura_ativos: bool = true
@export_range(0.1, 1.0, 0.05) var escurecimento_choque: float = 0.72
@export_range(0.0, 18.0, 0.5) var tremor_ruptura_pixels: float = 9.0
@export var som_vento_ruptura: AudioStream

@export_group("Ambiencia Level 6 apos abrir o portao")
@export var neblina_mundial_apos_portao: bool = true
@export_range(0.6, 8.0, 0.1) var tempo_neblina_tomar_mapa: float = 3.4
@export_range(0.0, 0.85, 0.01) var escurecimento_mapa_aberto: float = 0.53
@export_range(0.15, 0.85, 0.01) var opacidade_neblina_level6: float = 0.48
@export_range(0.1, 0.95, 0.01) var opacidade_vinheta_level6: float = 0.65
@export_range(0.2, 3.0, 0.05) var velocidade_neblina_level6: float = 1.0
@export var cinzas_level6_apos_portao: bool = true

@export_group("Texto")
@export var tamanho_fonte: int = 20
@export_range(0.1, 1.5, 0.05) var fade_texto: float = 0.35
@export_range(1.0, 5.0, 0.1) var tempo_texto: float = 2.7
@export_range(0.0, 1.0, 0.05) var opacidade_caixa: float = 0.86


var player: Node2D = null
var anim_player: AnimatedSprite2D = null

var ritual_ativo: bool = false
var ritual_finalizado: bool = false
var desafio_concluido: bool = false
var decisao_confirmada: bool = false
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
var caixa_texto: PanelContainer = null
var label_texto: Label = null
var label_faltando: Label = null
var mensagem_faltando_visivel: bool = false

enum EtapaDesafio {
	INATIVO,
	PREPARANDO,
	MENU,
	INTRODUCAO,
	FORMANDO_RODA,
	PERGUNTA,
	CONFIRMACAO,
	RESULTADO,
	CONCLUINDO,
	DECISAO_FINAL,
	REFLEXAO_FINAL,
	SAINDO
}

var etapa_desafio: EtapaDesafio = EtapaDesafio.INATIVO
var aguardar_player_afastar: bool = false
var pergunta_atual: int = 0
var ultima_resposta_correta: bool = false
var indice_selecionado: int = 0
var angulo_roda: float = -PI / 2.0
var angulo_alvo_roda: float = -PI / 2.0
var tempo_roda: float = 0.0

var perguntas_rodada: Array[Dictionary] = []
var ultimas_variantes: Dictionary = {}
var gerador_perguntas: RandomNumberGenerator = RandomNumberGenerator.new()

var painel_desafio: PanelContainer = null
var caixa_desafio: VBoxContainer = null
var seta_escolha: Polygon2D = null

var pensamento_camada: CanvasLayer = null
var pensamento_raiz: Control = null
var pensamento_fundo: ColorRect = null
var pensamento_texto: Label = null
var pensamento_opcoes: HBoxContainer = null
var pensamento_botoes: Array[Button] = []
var pensamento_conteudo: String = ""
var pensamento_letras: int = 0
var pensamento_timer: float = 0.0
var pensamento_espera: float = -1.0
var pensamento_escolhas_visiveis: bool = false
var pensamento_indice_opcao: int = 0
var pensamento_fechando: bool = false

var _textura_fumaca_portao: Texture2D = null
var _textura_vento_portao: Texture2D = null

const COLUNAS_NEBLINA_PORTAO_L6: int = 7
const LINHAS_NEBLINA_PORTAO_L6: int = 5
const ESPACAMENTO_NEBLINA_PORTAO_L6: Vector2 = Vector2(420.0, 250.0)
const COLUNAS_CINZAS_PORTAO_L6: int = 11
const LINHAS_CINZAS_PORTAO_L6: int = 7
const ESPACAMENTO_CINZAS_PORTAO_L6: Vector2 = Vector2(160.0, 125.0)

var _ambiencia_l6_ativa: bool = false
var _ambiencia_l6_forca: float = 0.0
var _ambiencia_l6_tempo: float = 0.0
var _ambiencia_l6_camada: CanvasLayer = null
var _ambiencia_l6_raiz: Control = null
var _ambiencia_l6_sombra: ColorRect = null
var _ambiencia_l6_nuvens: Array[TextureRect] = []
var _ambiencia_l6_cinzas: Array[TextureRect] = []
var _ambiencia_l6_vinheta: TextureRect = null


const BANCO_PERGUNTAS: Dictionary = {
	"escaravelho": [
		{"pergunta": "Qual amuleto egípcio era ligado a Khepri, deus do sol nascente?", "explicacao": "O escaravelho estava associado a Khepri e ao nascer diário do sol."},
		{"pergunta": "Qual relíquia simboliza proteção e renascimento, inspirada em um inseto sagrado?", "explicacao": "Os egípcios usavam escaravelhos como amuletos de proteção e renovação."},
		{"pergunta": "Que amuleto representa a renovação diária do sol, segundo a tradição de Khepri?", "explicacao": "Khepri e o escaravelho remetiam ao sol que renasce a cada amanhecer."},
		{"pergunta": "Qual objeto era um amuleto de renascimento relacionado ao deus Khepri?", "explicacao": "O escaravelho é um símbolo egípcio de renascimento e proteção."},
		{"pergunta": "Um artesão precisa de um amuleto ligado ao nascer do sol e à proteção. Qual relíquia escolhe?", "explicacao": "Os escaravelhos eram amuletos protetores relacionados a Khepri e ao sol nascente."},
		{"pergunta": "Uma inscrição cita Khepri e o ciclo diário do sol. Qual das cinco relíquias melhor corresponde à ideia?", "explicacao": "Na religião egípcia, Khepri e o escaravelho estavam associados à renovação diária do sol."},
		{"pergunta": "Qual peça traz a figura de um animal sagrado que representa transformação e renascimento?", "explicacao": "O escaravelho é uma representação de um inseto associado à renovação e ao renascimento."}
	],
	"calice": [
		{"pergunta": "Qual relíquia de alabastro encontrada na tumba de Tutancâmon evoca a flor de lótus?", "explicacao": "O Cálice de Lótus, feito de alabastro, foi encontrado na tumba de Tutancâmon."},
		{"pergunta": "Qual objeto guarda o simbolismo da flor de lótus, associada à renovação da vida?", "explicacao": "O Cálice de Lótus carrega a simbologia egípcia do renascimento."},
		{"pergunta": "Entre as relíquias, qual é o recipiente cerimonial ligado à flor de lótus?", "explicacao": "O Cálice de Lótus é um recipiente cujo motivo floral evoca renovação."},
		{"pergunta": "Qual tesouro de Tutancâmon é conhecido por seu formato inspirado em uma flor?", "explicacao": "O Cálice de Lótus foi encontrado na tumba de Tutancâmon."},
		{"pergunta": "Em uma exposição, há um recipiente de alabastro encontrado na tumba de Tutancâmon. Qual é a relíquia?", "explicacao": "O Cálice de Lótus era feito de alabastro e foi encontrado na tumba de Tutancâmon."},
		{"pergunta": "Qual relíquia une a forma de um recipiente à simbologia de uma flor ligada à renovação?", "explicacao": "O Cálice de Lótus era um recipiente cujo motivo floral remetia à renovação da vida."},
		{"pergunta": "Uma pista descreve uma peça cerimonial ligada à flor de lótus, em vez de um amuleto. Qual é?", "explicacao": "O Cálice de Lótus corresponde ao objeto com referências à flor de lótus."}
	],
	"ankh": [
		{"pergunta": "Qual símbolo egípcio representa a vida e aparece nas mãos dos deuses?", "explicacao": "O Ankh simbolizava a vida e aparecia nas mãos das divindades."},
		{"pergunta": "Qual relíquia é um sinal de vida frequente em pinturas religiosas egípcias?", "explicacao": "O Ankh era um dos principais sinais de vida no Egito Antigo."},
		{"pergunta": "Que símbolo os deuses egípcios costumavam segurar para representar a vida?", "explicacao": "O Ankh era representado nas mãos de muitos deuses egípcios."},
		{"pergunta": "Qual amuleto é conhecido como um dos grandes símbolos de vida no Egito Antigo?", "explicacao": "O Ankh está associado à vida e à iconografia religiosa egípcia."},
		{"pergunta": "Um mural mostra uma divindade segurando um sinal que simboliza a vida. Qual relíquia é essa?", "explicacao": "O Ankh era frequentemente retratado nas mãos das divindades como símbolo de vida."},
		{"pergunta": "Qual dos cinco objetos representa diretamente a vida, e não a identidade de um morto?", "explicacao": "O Ankh era o símbolo egípcio da vida; a máscara funerária estava relacionada à identidade do morto."},
		{"pergunta": "Que sinal egípcio, muitas vezes representado nas mãos dos deuses, tem formato semelhante a uma cruz com alça?", "explicacao": "O Ankh tem forma de cruz com alça e é associado à vida."}
	],
	"mascara": [
		{"pergunta": "Qual relíquia cobria o rosto de algumas múmias e preservava a identidade do falecido?", "explicacao": "A máscara funerária era ligada à identidade do morto e ao além."},
		{"pergunta": "Que objeto funerário estava ligado às crenças sobre a vida após a morte?", "explicacao": "Máscaras funerárias faziam parte de práticas e crenças relacionadas à morte."},
		{"pergunta": "Qual artefato era colocado sobre o rosto de certos mortos no antigo Egito?", "explicacao": "A máscara funerária podia cobrir o rosto do falecido."},
		{"pergunta": "Qual relíquia remete diretamente à identidade de um morto e aos ritos funerários?", "explicacao": "As máscaras funerárias estavam ligadas aos rituais e à identidade do falecido."},
		{"pergunta": "Um arqueólogo encontra uma peça feita para cobrir o rosto de um falecido. Qual relíquia foi encontrada?", "explicacao": "Máscaras funerárias podiam cobrir o rosto de algumas múmias egípcias."},
		{"pergunta": "Qual artefato melhor representa as crenças sobre reconhecer o falecido no mundo dos mortos?", "explicacao": "A máscara funerária estava associada à identidade da pessoa falecida e às crenças sobre o além."},
		{"pergunta": "Qual das cinco peças está mais diretamente ligada ao rosto e à identidade de uma múmia?", "explicacao": "As máscaras funerárias eram associadas à identidade de alguns falecidos e cobriam seu rosto."}
	],
	"lapislazulidofarao": [
		{"pergunta": "Qual pedra azul importada era usada em joias e amuletos egípcios?", "explicacao": "O lápis-lazúli era uma pedra importada e valorizada em joias e amuletos."},
		{"pergunta": "Qual relíquia é um mineral precioso trazido de terras distantes?", "explicacao": "O lápis-lazúli chegava ao Egito por rotas de comércio de longa distância."},
		{"pergunta": "Qual material azul era empregado em ornamentos e objetos religiosos?", "explicacao": "O lápis-lazúli aparece em joias, amuletos e objetos religiosos."},
		{"pergunta": "Entre estas relíquias, qual não é um símbolo ou recipiente, mas uma pedra ornamental?", "explicacao": "O lápis-lazúli é uma pedra ornamental muito valorizada pelos egípcios."},
		{"pergunta": "Qual artefato mostra que os egípcios obtinham materiais preciosos de regiões distantes?", "explicacao": "O lápis-lazúli era importado de regiões distantes para a fabricação de joias e objetos religiosos."},
		{"pergunta": "Um joalheiro precisa de uma pedra azul importada para produzir um amuleto. Qual escolhe?", "explicacao": "O lápis-lazúli é uma pedra azul que era usada em joias e amuletos egípcios."},
		{"pergunta": "Qual peça da coleção era um material mineral empregado em ornamentos, e não um objeto funerário completo?", "explicacao": "O lápis-lazúli era uma matéria-prima mineral usada em joias e objetos religiosos."}
	]
}


const SIGNIFICADO_DAS_RELIQUIAS: Dictionary = {
	"escaravelho": "O escaravelho era um amuleto de proteção e renascimento, associado a Khepri e ao nascer do sol.",
	"calice": "O Cálice de Lótus era um recipiente de alabastro associado à flor de lótus e à renovação da vida.",
	"ankh": "O Ankh era o símbolo da vida, representado nas mãos de divindades egípcias.",
	"mascara": "A máscara funerária cobria o rosto de algumas múmias e se relacionava à identidade e à vida após a morte.",
	"lapislazulidofarao": "O lápis-lazúli era uma pedra azul importada, utilizada em joias, amuletos e objetos religiosos."
}


const ORDEM_ARTEFATOS: Array[String] = [
	"escaravelho",
	"calice",
	"ankh",
	"mascara",
	"lapislazulidofarao"
]


const TEXTOS_RITUAL: Array[String] = [
    "As cinco relíquias reconhecem sua sabedoria.\nSua magia desperta na pedra, e a passagem começa a se revelar."
]


func _ready() -> void:
	gerador_perguntas.randomize()
	collision_layer = 3
	collision_mask = 0

	_criar_ui()
	_criar_ui_desafio()
	_procurar_player()
	if neblina_mundial_apos_portao:
		_montar_ambiencia_level6_portao()


func _process(delta: float) -> void:
	if _ambiencia_l6_ativa:
		_atualizar_ambiencia_level6_portao(delta)
	if ritual_finalizado:
		return

	if etapa_desafio in [EtapaDesafio.DECISAO_FINAL, EtapaDesafio.REFLEXAO_FINAL]:
		_atualizar_pensamento(delta)

	if player == null:
		_procurar_player()
		return

	if not is_instance_valid(player):
		player = null
		return

	if etapa_desafio in [EtapaDesafio.PERGUNTA, EtapaDesafio.CONFIRMACAO, EtapaDesafio.RESULTADO]:
		_atualizar_roda_escolha(delta)

	if girando:
		_atualizar_selo(delta)

	if ritual_ativo:
		return

	var distancia: float = global_position.distance_to(player.global_position)

	if aguardar_player_afastar:
		if distancia >= maxf(distancia_para_rearmar, distancia_ativacao + 60.0):
			aguardar_player_afastar = false
		else:
			return

	if distancia <= distancia_ativacao and GerenciadorArtefatos.tem_todos_artefatos():
		if player is CharacterBody2D:
			var personagem: CharacterBody2D = player as CharacterBody2D
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

	caixa_texto = PanelContainer.new()
	caixa_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_texto.modulate.a = 0.0
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.027, 0.045, 0.95)
	estilo.border_color = Color(0.76, 0.61, 0.32, 0.95)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(14)
	caixa_texto.add_theme_stylebox_override("panel", estilo)
	camada_ui.add_child(caixa_texto)

	label_texto = Label.new()
	label_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_texto.add_theme_font_size_override("font_size", tamanho_fonte)
	label_texto.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74))
	label_texto.modulate.a = 0.0
	camada_ui.add_child(label_texto)

	label_faltando = Label.new()
	label_faltando.position = Vector2(24.0, 24.0)
	label_faltando.size = Vector2(560.0, 220.0)
	label_faltando.add_theme_font_size_override("font_size", tamanho_fonte)
	label_faltando.add_theme_color_override("font_color", Color.WHITE)
	label_faltando.add_theme_color_override("font_shadow_color", Color.BLACK)
	label_faltando.add_theme_constant_override("shadow_offset_x", 2)
	label_faltando.add_theme_constant_override("shadow_offset_y", 2)
	label_faltando.modulate.a = 0.0
	camada_ui.add_child(label_faltando)

	_atualizar_ui()
	if not get_viewport().size_changed.is_connected(_atualizar_ui):
		get_viewport().size_changed.connect(_atualizar_ui)


func _atualizar_ui() -> void:
	var tela: Vector2 = get_viewport_rect().size
	var altura_caixa: float = minf(175.0, tela.y * 0.32)
	var largura_caixa: float = minf(820.0, tela.x - 32.0)

	caixa_texto.position = Vector2(
		(tela.x - largura_caixa) * 0.5,
		tela.y - altura_caixa - 16.0
	)

	caixa_texto.size = Vector2(
		largura_caixa,
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

	_ajustar_painel_desafio()


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
	etapa_desafio = EtapaDesafio.PREPARANDO
	pergunta_atual = 0
	indice_selecionado = 0
	decisao_confirmada = false

	_congelar_player()
	_preparar_camera()

	if usar_camera_ritual:
		await _focar_camera_ritual()

	if not is_inside_tree() or not is_instance_valid(player) or etapa_desafio != EtapaDesafio.PREPARANDO:
		return

	await get_tree().create_timer(pausa_inicio).timeout

	if not is_inside_tree() or etapa_desafio != EtapaDesafio.PREPARANDO:
		return

	_criar_artefatos()

	if artefatos_visuais.size() != 5:
		push_warning("PORTAO: o puzzle precisa das cinco animacoes de artefatos.")
		_limpar_ritual()
		_restaurar_camera()
		_liberar_player()
		ritual_ativo = false
		etapa_desafio = EtapaDesafio.INATIVO
		aguardar_player_afastar = true
		return

	await _emergir_do_player()

	if not is_inside_tree() or etapa_desafio != EtapaDesafio.PREPARANDO:
		return

	etapa_desafio = EtapaDesafio.MENU
	_mostrar_painel_desafio()


func _continuar_ritual_apos_puzzle() -> void:
	if etapa_desafio != EtapaDesafio.CONCLUINDO:
		return

	_ocultar_painel_desafio()
	if is_instance_valid(seta_escolha):
		seta_escolha.visible = false

	angulo_base = angulo_roda
	raio_atual = raio_selo
	await _mostrar_textos()
	if not is_inside_tree():
		return

	await _girar()
	await _colapsar()
	await _desaparecer()
	if not is_inside_tree():
		return

	_iniciar_pensamento_final()


func _iniciar_pensamento_final() -> void:
	etapa_desafio = EtapaDesafio.DECISAO_FINAL
	pensamento_fechando = false
	_mostrar_pensamento(
        "Será que eu realmente deveria ter feito isso?\n\n"
		+ "E se abrir esta porta for um erro...?\n"
		+ "Será que eu devo continuar?"
	)


func _debug_completar_desafio() -> void:
	if not ritual_ativo or desafio_concluido:
		return
	if etapa_desafio not in [
		EtapaDesafio.PREPARANDO,
		EtapaDesafio.MENU,
		EtapaDesafio.INTRODUCAO,
		EtapaDesafio.FORMANDO_RODA,
		EtapaDesafio.PERGUNTA,
		EtapaDesafio.CONFIRMACAO,
		EtapaDesafio.RESULTADO
	]:
		return

	desafio_concluido = true
	pergunta_atual = 0
	girando = false
	_ocultar_painel_desafio()
	if is_instance_valid(seta_escolha):
		seta_escolha.visible = false
	_limpar_ritual()
	_iniciar_pensamento_final()
	print("PORTAO DEBUG: 1 -> quiz concluido; pensamento final iniciado.")


func _hesitar_antes_portao() -> void:
	if etapa_desafio != EtapaDesafio.DECISAO_FINAL:
		return
	if not pensamento_escolhas_visiveis or pensamento_fechando:
		return
	etapa_desafio = EtapaDesafio.REFLEXAO_FINAL
	_mostrar_pensamento(
        "Não...\n\n"
		+ "Eu já fui longe demais para desistir agora.\n"
		+ "Preciso descobrir o que existe além desta porta."
	)


func _abrir_portao_apos_decisao() -> void:
	if etapa_desafio not in [EtapaDesafio.DECISAO_FINAL, EtapaDesafio.REFLEXAO_FINAL]:
		return
	if not desafio_concluido or decisao_confirmada:
		return
	if not pensamento_escolhas_visiveis or pensamento_fechando:
		return

	decisao_confirmada = true
	pensamento_fechando = true
	etapa_desafio = EtapaDesafio.CONCLUINDO
	_ocultar_painel_desafio()

	if is_instance_valid(pensamento_camada):
		var saida: Tween = create_tween()
		saida.tween_property(pensamento_raiz, "modulate:a", 0.0, 0.45)
		await saida.finished
		if not is_inside_tree():
			return
		pensamento_camada.queue_free()
		pensamento_camada = null
		pensamento_raiz = null
		pensamento_fundo = null
		pensamento_texto = null
		pensamento_opcoes = null
		pensamento_botoes.clear()

	iniciar_abertura()
	_liberar_player()
	ritual_finalizado = true
	etapa_desafio = EtapaDesafio.INATIVO


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
		if etapa_desafio != EtapaDesafio.PREPARANDO or not ritual_ativo:
			return
		if i >= artefatos_visuais.size():
			return
		var artefato := (
			artefatos_visuais[i]
		)
		if not is_instance_valid(artefato):
			return

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


func iniciar_abertura() -> void:
	if not desafio_concluido or not decisao_confirmada:
		return

	if portao_abrindo:
		return

	GerenciadorArtefatos.registrar_abertura_portao()
	portao_abrindo = true

	if efeitos_ruptura_ativos:
		_explodir_vento_e_neblina()

	if neblina_mundial_apos_portao:
		_ativar_ambiencia_level6_portao()

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


func _criar_ui_desafio() -> void:
	painel_desafio = PanelContainer.new()
	painel_desafio.name = "PainelQuizPortao"
	painel_desafio.visible = false
	painel_desafio.mouse_filter = Control.MOUSE_FILTER_STOP

	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.027, 0.045, 0.95)
	estilo.border_color = Color(0.76, 0.61, 0.32, 0.95)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(14)
	painel_desafio.add_theme_stylebox_override("panel", estilo)

	camada_ui.add_child(painel_desafio)

	var margem: MarginContainer = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 20)
	margem.add_theme_constant_override("margin_right", 20)
	margem.add_theme_constant_override("margin_top", 15)
	margem.add_theme_constant_override("margin_bottom", 15)
	painel_desafio.add_child(margem)

	caixa_desafio = VBoxContainer.new()
	caixa_desafio.add_theme_constant_override("separation", 9)
	margem.add_child(caixa_desafio)

	_ajustar_painel_desafio()

	seta_escolha = Polygon2D.new()
	seta_escolha.name = "SetaSelecaoArtefato"
	seta_escolha.color = Color(1.0, 0.83, 0.35, 1.0)
	seta_escolha.polygon = PackedVector2Array([
		Vector2(-13.0, -12.0),
		Vector2(13.0, -12.0),
		Vector2(0.0, 8.0)
	])
	seta_escolha.z_index = 1000
	seta_escolha.visible = false
	get_tree().current_scene.add_child(seta_escolha)


func _ajustar_painel_desafio() -> void:
	if not is_instance_valid(painel_desafio):
		return

	var tela: Vector2 = get_viewport_rect().size
	var largura: float = minf(820.0, tela.x - 32.0)
	var altura: float = minf(255.0, tela.y * 0.46)
	if etapa_desafio == EtapaDesafio.RESULTADO and not ultima_resposta_correta:
		largura = minf(900.0, tela.x - 32.0)
		altura = minf(365.0, tela.y * 0.70)
	painel_desafio.position = Vector2(
		(tela.x - largura) * 0.5,
		tela.y - altura - 16.0
	)
	painel_desafio.size = Vector2(largura, altura)


func _limpar_conteudo_desafio() -> void:
	if not is_instance_valid(caixa_desafio):
		return
	for child: Node in caixa_desafio.get_children():
		caixa_desafio.remove_child(child)
		child.queue_free()


func _novo_texto_desafio(texto: String, fonte: int, cor: Color) -> Label:
	var label: Label = Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", fonte)
	label.add_theme_color_override("font_color", cor)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa_desafio.add_child(label)
	return label


func _nova_linha_botoes() -> HBoxContainer:
	var linha: HBoxContainer = HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 14)
	caixa_desafio.add_child(linha)
	return linha


func _novo_botao_desafio(linha: HBoxContainer, titulo: String, chamada: Callable) -> Button:
	var botao: Button = Button.new()
	botao.text = titulo
	botao.custom_minimum_size = Vector2(175.0, 42.0)
	botao.focus_mode = Control.FOCUS_NONE
	botao.add_theme_font_size_override("font_size", 16)
	linha.add_child(botao)
	botao.pressed.connect(chamada)
	return botao


func _mostrar_painel_desafio() -> void:
	if not is_instance_valid(painel_desafio):
		return
	if etapa_desafio in [EtapaDesafio.PERGUNTA, EtapaDesafio.RESULTADO]:
		if pergunta_atual < 0 or pergunta_atual >= perguntas_rodada.size():
			return

	_limpar_conteudo_desafio()
	var dourado: Color = Color(1.0, 0.85, 0.54)
	var claro: Color = Color(0.95, 0.94, 0.89)

	match etapa_desafio:
		EtapaDesafio.MENU:
			_novo_texto_desafio("O PORTÃO DAS CINCO RELÍQUIAS", 24, dourado)
			_novo_texto_desafio(
				"Os cinco artefatos despertam diante da porta. Você deseja investigar o selo?",
				18, claro
			)
			var botoes_menu: HBoxContainer = _nova_linha_botoes()
			_novo_botao_desafio(botoes_menu, "Começar puzzle", Callable(self, "_menu_comecar"))
			_novo_botao_desafio(botoes_menu, "Sair", Callable(self, "_sair_do_desafio"))
			_novo_texto_desafio("ENTER: começar   •   ESC: sair", 14, dourado)

		EtapaDesafio.INTRODUCAO:
			_novo_texto_desafio("A PORTA REAGE", 24, dourado)
			_novo_texto_desafio(
                "Os artefatos parecem interagir com a porta, mas a pedra não se move. "
				+ "Antes de atravessar, prove que sabe interpretar o significado das relíquias. "
				+ "São cinco respostas corretas; um erro reinicia a tentativa.",
				17, claro
			)
			var botoes_intro: HBoxContainer = _nova_linha_botoes()
			_novo_botao_desafio(botoes_intro, "Continuar", Callable(self, "_iniciar_perguntas"))
			_novo_botao_desafio(botoes_intro, "Sair", Callable(self, "_sair_do_desafio"))

		EtapaDesafio.PERGUNTA:
			var pergunta: Dictionary = perguntas_rodada[pergunta_atual]
			_novo_texto_desafio(
				"DESAFIO DO SELO  •  " + str(pergunta_atual + 1) + "/5",
				22, dourado
			)
			_novo_texto_desafio(String(pergunta["pergunta"]), 18, claro)
			_novo_texto_desafio(
				"◀ A    D ▶  Girar roda     •     Selecionado: " + _nome_selecionado(),
				16, dourado
			)
			var botoes_pergunta: HBoxContainer = _nova_linha_botoes()
			_novo_botao_desafio(botoes_pergunta, "Selecionar [ENTER]", Callable(self, "_perguntar_confirmacao"))
			_novo_botao_desafio(botoes_pergunta, "Sair", Callable(self, "_sair_do_desafio"))

		EtapaDesafio.CONFIRMACAO:
			_novo_texto_desafio("CONFIRMAR RELÍQUIA", 24, dourado)
			_novo_texto_desafio(
				"Tem certeza que deseja selecionar " + _nome_selecionado() + "?",
				20, claro
			)
			var botoes_confirmacao: HBoxContainer = _nova_linha_botoes()
			_novo_botao_desafio(botoes_confirmacao, "Sim, confirmar", Callable(self, "_confirmar_escolha"))
			_novo_botao_desafio(botoes_confirmacao, "Não, voltar", Callable(self, "_voltar_pergunta"))
			_novo_texto_desafio("ENTER: confirmar   •   ESC: voltar", 14, dourado)

		EtapaDesafio.RESULTADO:
			var pergunta_resultado: Dictionary = perguntas_rodada[pergunta_atual]
			if ultima_resposta_correta:
				_novo_texto_desafio("RESPOSTA CORRETA", 24, Color(0.60, 1.0, 0.68))
				_novo_texto_desafio(String(pergunta_resultado["explicacao"]), 18, claro)
			else:
				var tipo_marcado: String = ORDEM_ARTEFATOS[indice_selecionado]
				var tipo_certo: String = String(pergunta_resultado["resposta"])
				_novo_texto_desafio("O SELO SE DESFAZ", 23, Color(1.0, 0.67, 0.57))
				_novo_texto_desafio(
					"Você escolheu " + GerenciadorArtefatos.nome_artefato(tipo_marcado) + ".",
					17, claro
				)
				_novo_texto_desafio(
					"O que ela representa: " + String(SIGNIFICADO_DAS_RELIQUIAS[tipo_marcado]),
					16, claro
				)
				_novo_texto_desafio(
					"A pista indicava " + GerenciadorArtefatos.nome_artefato(tipo_certo)
					+ ". " + String(pergunta_resultado["explicacao"]),
					16, Color(1.0, 0.88, 0.62)
				)
				_novo_texto_desafio(
					"A tentativa recomeça na pergunta 1, com novas pistas.", 14, claro
				)

			var botoes_resultado: HBoxContainer = _nova_linha_botoes()
			if ultima_resposta_correta:
				if pergunta_atual == perguntas_rodada.size() - 1:
					_novo_botao_desafio(botoes_resultado, "Prosseguir", Callable(self, "_proxima_etapa"))
				else:
					_novo_botao_desafio(botoes_resultado, "Próxima pergunta", Callable(self, "_proxima_etapa"))
			else:
				_novo_botao_desafio(botoes_resultado, "Recomeçar do início", Callable(self, "_proxima_etapa"))

	painel_desafio.visible = true
	_ajustar_painel_desafio()


func _criar_tela_pensamento() -> void:
	if is_instance_valid(pensamento_camada):
		return

	pensamento_camada = CanvasLayer.new()
	pensamento_camada.name = "PensamentoInternoPortao"
	pensamento_camada.layer = 1100
	pensamento_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pensamento_camada)

	pensamento_raiz = Control.new()
	pensamento_raiz.name = "TelaPensamentoRaiz"
	pensamento_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	pensamento_camada.add_child(pensamento_raiz)

	pensamento_fundo = ColorRect.new()
	pensamento_fundo.name = "TelaTotalmentePreta"
	pensamento_fundo.color = Color.BLACK
	pensamento_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	pensamento_raiz.add_child(pensamento_fundo)

	pensamento_texto = Label.new()
	pensamento_texto.name = "TextoPensamento"
	pensamento_texto.text = ""
	pensamento_texto.visible_characters = 0
	pensamento_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pensamento_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pensamento_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pensamento_texto.add_theme_font_size_override("font_size", tamanho_fonte_pensamento)
	pensamento_texto.add_theme_color_override("font_color", Color.WHITE)
	pensamento_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pensamento_raiz.add_child(pensamento_texto)

	pensamento_opcoes = HBoxContainer.new()
	pensamento_opcoes.name = "EscolhasPensamento"
	pensamento_opcoes.alignment = BoxContainer.ALIGNMENT_CENTER
	pensamento_opcoes.add_theme_constant_override("separation", 90)
	pensamento_opcoes.visible = false
	pensamento_raiz.add_child(pensamento_opcoes)

	for i: int in range(2):
		var botao: Button = Button.new()
		botao.focus_mode = Control.FOCUS_NONE
		botao.flat = true
		botao.custom_minimum_size = Vector2(125.0, 55.0)
		botao.add_theme_font_size_override("font_size", 25)
		botao.add_theme_color_override("font_color", Color.WHITE)
		botao.add_theme_color_override("font_hover_color", Color.WHITE)
		botao.add_theme_color_override("font_pressed_color", Color.WHITE)
		pensamento_opcoes.add_child(botao)
		pensamento_botoes.append(botao)
		botao.pressed.connect(_escolher_pensamento.bind(i))

	_atualizar_layout_pensamento()
	if not get_viewport().size_changed.is_connected(_atualizar_layout_pensamento):
		get_viewport().size_changed.connect(_atualizar_layout_pensamento)


func _atualizar_layout_pensamento() -> void:
	if not is_instance_valid(pensamento_camada):
		return
	var tela: Vector2 = get_viewport_rect().size
	pensamento_raiz.position = Vector2.ZERO
	pensamento_raiz.size = tela
	pensamento_fundo.position = Vector2.ZERO
	pensamento_fundo.size = tela
	pensamento_texto.position = Vector2(tela.x * 0.12, tela.y * 0.23)
	pensamento_texto.size = Vector2(tela.x * 0.76, tela.y * 0.46)
	pensamento_opcoes.position = Vector2(tela.x * 0.20, tela.y * 0.74)
	pensamento_opcoes.size = Vector2(tela.x * 0.60, 70.0)


func _mostrar_pensamento(conteudo: String) -> void:
	_ocultar_painel_desafio()
	_criar_tela_pensamento()
	pensamento_raiz.modulate.a = 1.0
	pensamento_conteudo = conteudo
	pensamento_texto.text = conteudo
	pensamento_texto.visible_characters = 0
	pensamento_letras = 0
	pensamento_timer = 0.24
	pensamento_espera = -1.0
	pensamento_escolhas_visiveis = false
	pensamento_indice_opcao = 0
	pensamento_opcoes.visible = false
	pensamento_botoes[1].visible = (etapa_desafio == EtapaDesafio.DECISAO_FINAL)
	_atualizar_botoes_pensamento()


func _atualizar_pensamento(delta: float) -> void:
	if not is_instance_valid(pensamento_texto):
		return
	if pensamento_escolhas_visiveis or pensamento_fechando:
		return

	if pensamento_letras < pensamento_conteudo.length():
		pensamento_timer -= delta
		while pensamento_timer <= 0.0 and pensamento_letras < pensamento_conteudo.length():
			var letra: String = pensamento_conteudo.substr(pensamento_letras, 1)
			pensamento_letras += 1
			pensamento_texto.visible_characters = pensamento_letras
			pensamento_timer += intervalo_letra_pensamento
			if letra in [".", "?", "!", ",", ":", ";"]:
				pensamento_timer += pausa_pontuacao_pensamento
			elif letra == "\n":
				pensamento_timer += 0.10

		if pensamento_letras >= pensamento_conteudo.length():
			pensamento_espera = espera_apos_pensamento
		return

	if pensamento_espera >= 0.0:
		pensamento_espera -= delta
		if pensamento_espera < 0.0:
			pensamento_escolhas_visiveis = true
			pensamento_opcoes.visible = true
			_atualizar_botoes_pensamento()


func _revelar_pensamento_inteiro() -> void:
	if not is_instance_valid(pensamento_texto):
		return
	pensamento_letras = pensamento_conteudo.length()
	pensamento_texto.visible_characters = -1
	pensamento_espera = espera_apos_pensamento
	pensamento_timer = 0.0


func _atualizar_botoes_pensamento() -> void:
	if pensamento_botoes.size() < 2:
		return
	var nomes: Array[String] = ["Sim", "Não"]
	if etapa_desafio == EtapaDesafio.REFLEXAO_FINAL:
		nomes = ["Continuar", ""]
	for i: int in range(2):
		pensamento_botoes[i].text = (
			"› " + nomes[i] + " ‹" if i == pensamento_indice_opcao else nomes[i]
		)


func _escolher_pensamento(indice: int) -> void:
	if not pensamento_escolhas_visiveis or pensamento_fechando:
		return
	if etapa_desafio == EtapaDesafio.REFLEXAO_FINAL:
		_abrir_portao_apos_decisao()
	elif etapa_desafio == EtapaDesafio.DECISAO_FINAL:
		if indice == 0:
			_abrir_portao_apos_decisao()
		else:
			_hesitar_antes_portao()


func _ocultar_painel_desafio() -> void:
	if is_instance_valid(painel_desafio):
		painel_desafio.visible = false


func _nome_selecionado() -> String:
	return GerenciadorArtefatos.nome_artefato(
		ORDEM_ARTEFATOS[indice_selecionado]
	)


func _menu_comecar() -> void:
	if etapa_desafio != EtapaDesafio.MENU:
		return
	etapa_desafio = EtapaDesafio.INTRODUCAO
	_mostrar_painel_desafio()


func _montar_rodada_perguntas() -> void:
	perguntas_rodada.clear()

	var tipos: Array[String] = ORDEM_ARTEFATOS.duplicate()
	for i: int in range(tipos.size() - 1, 0, -1):
		var j: int = gerador_perguntas.randi_range(0, i)
		var temporario: String = tipos[i]
		tipos[i] = tipos[j]
		tipos[j] = temporario
	tipos.pop_back()
	var repetido: String = tipos[gerador_perguntas.randi_range(0, tipos.size() - 1)]
	tipos.append(repetido)

	var usados_nesta_rodada: Dictionary = {}
	for tipo: String in tipos:
		var variacoes: Array = BANCO_PERGUNTAS[tipo]
		var usados: Array = usados_nesta_rodada.get(tipo, [])
		var candidatos: Array[int] = []
		for variante: int in range(variacoes.size()):
			if not usados.has(variante):
				candidatos.append(variante)

		var anterior: int = int(ultimas_variantes.get(tipo, -1))
		if candidatos.size() > 1 and candidatos.has(anterior):
			candidatos.erase(anterior)

		var escolhido: int = candidatos[gerador_perguntas.randi_range(0, candidatos.size() - 1)]
		usados.append(escolhido)
		usados_nesta_rodada[tipo] = usados
		ultimas_variantes[tipo] = escolhido
		var dados: Dictionary = variacoes[escolhido]
		perguntas_rodada.append({
			"pergunta": String(dados["pergunta"]),
			"resposta": tipo,
			"explicacao": String(dados["explicacao"])
		})

	for i: int in range(perguntas_rodada.size() - 1, 0, -1):
		var j: int = gerador_perguntas.randi_range(0, i)
		var temporaria: Dictionary = perguntas_rodada[i]
		perguntas_rodada[i] = perguntas_rodada[j]
		perguntas_rodada[j] = temporaria

func _iniciar_perguntas() -> void:
	if etapa_desafio != EtapaDesafio.INTRODUCAO:
		return

	etapa_desafio = EtapaDesafio.FORMANDO_RODA
	_ocultar_painel_desafio()
	_formar_roda_e_comecar()


func _formar_roda_e_comecar() -> void:
	await _formar_selo()
	if not is_inside_tree() or etapa_desafio != EtapaDesafio.FORMANDO_RODA:
		return

	indice_selecionado = 0
	angulo_roda = -PI / 2.0
	angulo_alvo_roda = angulo_roda
	tempo_roda = 0.0
	pergunta_atual = 0
	_montar_rodada_perguntas()

	etapa_desafio = EtapaDesafio.PERGUNTA
	seta_escolha.visible = true
	_atualizar_roda_escolha(0.0)
	_mostrar_painel_desafio()


func _sair_do_desafio() -> void:
	if etapa_desafio not in [
		EtapaDesafio.MENU,
		EtapaDesafio.INTRODUCAO,
		EtapaDesafio.PERGUNTA,
		EtapaDesafio.CONFIRMACAO,
		EtapaDesafio.RESULTADO
	]:
		return

	etapa_desafio = EtapaDesafio.SAINDO
	_ocultar_painel_desafio()
	if is_instance_valid(seta_escolha):
		seta_escolha.visible = false

	_sair_e_rearmar_portao()


func _sair_e_rearmar_portao() -> void:
	girando = false
	var destino: Vector2 = player.global_position + Vector2(0.0, -14.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for visual: AnimatedSprite2D in artefatos_visuais:
		if not is_instance_valid(visual):
			continue
		tween.tween_property(visual, "global_position", destino, 0.48)
		tween.tween_property(visual, "scale", Vector2.ZERO, 0.48)
		tween.tween_property(visual, "modulate:a", 0.0, 0.40)

	if not artefatos_visuais.is_empty():
		await tween.finished

	if not is_inside_tree():
		return

	_limpar_ritual()
	_restaurar_camera()
	_liberar_player()

	ritual_ativo = false
	etapa_desafio = EtapaDesafio.INATIVO
	aguardar_player_afastar = true


func _atualizar_roda_escolha(delta: float) -> void:
	tempo_roda += delta
	angulo_roda = move_toward(
		angulo_roda,
		angulo_alvo_roda,
		velocidade_roda_selecao * delta
	)
	var centro: Vector2 = _centro_ritual()
	for i: int in range(artefatos_visuais.size()):
		var artefato: AnimatedSprite2D = artefatos_visuais[i]
		if not is_instance_valid(artefato):
			continue
		var a: float = angulo_roda + TAU / 5.0 * float(i)
		artefato.global_position = centro + Vector2(cos(a), sin(a)) * raio_selo
		artefato.rotation = 0.0

	if is_instance_valid(seta_escolha):
		seta_escolha.global_position = centro + Vector2(
			0.0,
			-raio_selo - 34.0 + sin(tempo_roda * 3.0) * 2.0
		)


func _girar_selecao(direcao: int) -> void:
	if etapa_desafio != EtapaDesafio.PERGUNTA:
		return
	if absf(angulo_alvo_roda - angulo_roda) > 0.02:
		return

	indice_selecionado = posmod(
		indice_selecionado + direcao,
		ORDEM_ARTEFATOS.size()
	)
	angulo_alvo_roda -= (TAU / 5.0) * float(direcao)
	_mostrar_painel_desafio()


func _perguntar_confirmacao() -> void:
	if etapa_desafio != EtapaDesafio.PERGUNTA:
		return
	if absf(angulo_alvo_roda - angulo_roda) > 0.02:
		return
	etapa_desafio = EtapaDesafio.CONFIRMACAO
	_mostrar_painel_desafio()


func _voltar_pergunta() -> void:
	if etapa_desafio != EtapaDesafio.CONFIRMACAO:
		return
	etapa_desafio = EtapaDesafio.PERGUNTA
	_mostrar_painel_desafio()


func _confirmar_escolha() -> void:
	if etapa_desafio != EtapaDesafio.CONFIRMACAO:
		return
	if pergunta_atual < 0 or pergunta_atual >= perguntas_rodada.size():
		return
	if indice_selecionado < 0 or indice_selecionado >= ORDEM_ARTEFATOS.size():
		return

	ultima_resposta_correta = (
		ORDEM_ARTEFATOS[indice_selecionado]
		== String(perguntas_rodada[pergunta_atual]["resposta"])
	)
	etapa_desafio = EtapaDesafio.RESULTADO
	_mostrar_painel_desafio()


func _proxima_etapa() -> void:
	if etapa_desafio != EtapaDesafio.RESULTADO:
		return

	if not ultima_resposta_correta:
		pergunta_atual = 0
		_montar_rodada_perguntas()
		etapa_desafio = EtapaDesafio.PERGUNTA
		_mostrar_painel_desafio()
		return

	pergunta_atual += 1
	if pergunta_atual >= perguntas_rodada.size():
		desafio_concluido = true
		etapa_desafio = EtapaDesafio.CONCLUINDO
		_continuar_ritual_apos_puzzle()
		return

	etapa_desafio = EtapaDesafio.PERGUNTA
	_mostrar_painel_desafio()


func _input(event: InputEvent) -> void:
	if not ritual_ativo:
		return
	if not event is InputEventKey:
		return

	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	if key.keycode in [KEY_1, KEY_KP_1] or key.physical_keycode == KEY_1:
		if etapa_desafio in [
			EtapaDesafio.PREPARANDO,
			EtapaDesafio.MENU,
			EtapaDesafio.INTRODUCAO,
			EtapaDesafio.FORMANDO_RODA,
			EtapaDesafio.PERGUNTA,
			EtapaDesafio.CONFIRMACAO,
			EtapaDesafio.RESULTADO
		]:
			_debug_completar_desafio()
			get_viewport().set_input_as_handled()
			return

	var handled: bool = true
	match etapa_desafio:
		EtapaDesafio.MENU:
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_menu_comecar()
			elif key.keycode == KEY_ESCAPE:
				_sair_do_desafio()
			else:
				handled = false

		EtapaDesafio.INTRODUCAO:
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_iniciar_perguntas()
			elif key.keycode == KEY_ESCAPE:
				_sair_do_desafio()
			else:
				handled = false

		EtapaDesafio.PERGUNTA:
			if key.keycode == KEY_A:
				_girar_selecao(-1)
			elif key.keycode == KEY_D:
				_girar_selecao(1)
			elif key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_perguntar_confirmacao()
			elif key.keycode == KEY_ESCAPE:
				_sair_do_desafio()
			else:
				handled = false

		EtapaDesafio.CONFIRMACAO:
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Y]:
				_confirmar_escolha()
			elif key.keycode in [KEY_ESCAPE, KEY_N]:
				_voltar_pergunta()
			else:
				handled = false

		EtapaDesafio.RESULTADO:
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_proxima_etapa()
			elif key.keycode == KEY_ESCAPE:
				_sair_do_desafio()
			else:
				handled = false

		EtapaDesafio.DECISAO_FINAL, EtapaDesafio.REFLEXAO_FINAL:
			if not pensamento_escolhas_visiveis:
				if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
					_revelar_pensamento_inteiro()
				else:
					handled = false
			elif key.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D] and etapa_desafio == EtapaDesafio.DECISAO_FINAL:
				pensamento_indice_opcao = 1 - pensamento_indice_opcao
				_atualizar_botoes_pensamento()
			elif key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_escolher_pensamento(pensamento_indice_opcao)
			elif key.keycode in [KEY_Y] and etapa_desafio == EtapaDesafio.DECISAO_FINAL:
				_escolher_pensamento(0)
			elif key.keycode in [KEY_ESCAPE, KEY_N] and etapa_desafio == EtapaDesafio.DECISAO_FINAL:
				_escolher_pensamento(1)
			else:
				handled = false

		_:
			handled = false

	if handled:
		get_viewport().set_input_as_handled()


func _criar_textura_neblina_portao() -> Texture2D:
	if _textura_fumaca_portao != null:
		return _textura_fumaca_portao
	var imagem: Image = Image.create(112, 112, false, Image.FORMAT_RGBA8)
	var ruido: FastNoiseLite = FastNoiseLite.new()
	ruido.seed = 91746
	ruido.frequency = 0.072
	for y: int in range(112):
		for x: int in range(112):
			var p: Vector2 = (Vector2(float(x), float(y)) - Vector2(55.5, 55.5)) / 55.5
			var r: float = p.length()
			var n: float = ruido.get_noise_2d(float(x), float(y))
			var alfa: float = pow(clampf(1.0 - r, 0.0, 1.0), 1.35)
			alfa *= clampf(0.70 + n * 0.52, 0.10, 1.0)
			imagem.set_pixel(x, y, Color(1.0, 1.0, 1.0, alfa))
	_textura_fumaca_portao = ImageTexture.create_from_image(imagem)
	return _textura_fumaca_portao


func _criar_textura_vento_portao() -> Texture2D:
	if _textura_vento_portao != null:
		return _textura_vento_portao
	var imagem: Image = Image.create(110, 10, false, Image.FORMAT_RGBA8)
	for y: int in range(10):
		for x: int in range(110):
			var px: float = absf(float(x) - 54.5) / 54.5
			var py: float = absf(float(y) - 4.5) / 4.5
			var alfa: float = pow(1.0 - px, 0.68) * pow(1.0 - py, 1.8) * 0.75
			imagem.set_pixel(x, y, Color(1.0, 1.0, 1.0, alfa))
	_textura_vento_portao = ImageTexture.create_from_image(imagem)
	return _textura_vento_portao


func _criar_neblina_ruptura(origem: Vector2, sentido: Vector2) -> CPUParticles2D:
	var particulas: CPUParticles2D = CPUParticles2D.new()
	particulas.name = "NeblinaNegraDaPorta"
	particulas.emitting = false
	particulas.one_shot = false
	particulas.amount = 140
	particulas.lifetime = 4.8
	particulas.explosiveness = 0.17
	particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particulas.emission_rect_extents = Vector2(30.0, 175.0)
	particulas.direction = sentido
	particulas.spread = 53.0
	particulas.gravity = Vector2(0.0, -32.0)
	particulas.initial_velocity_min = 80.0
	particulas.initial_velocity_max = 245.0
	particulas.scale_amount_min = 1.4
	particulas.scale_amount_max = 3.9
	particulas.color = Color(0.025, 0.022, 0.037, 0.84)
	particulas.texture = _criar_textura_neblina_portao()
	particulas.z_index = 1700
	get_tree().current_scene.add_child(particulas)
	particulas.global_position = origem
	particulas.emitting = true
	return particulas


func _criar_vento_ruptura(origem: Vector2, sentido: Vector2) -> CPUParticles2D:
	var particulas: CPUParticles2D = CPUParticles2D.new()
	particulas.name = "RajadasDeVentoDaPorta"
	particulas.emitting = false
	particulas.one_shot = false
	particulas.amount = 95
	particulas.lifetime = 0.72
	particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particulas.emission_rect_extents = Vector2(18.0, 155.0)
	particulas.direction = sentido
	particulas.spread = 13.0
	particulas.gravity = Vector2.ZERO
	particulas.initial_velocity_min = 660.0
	particulas.initial_velocity_max = 1320.0
	particulas.scale_amount_min = 0.75
	particulas.scale_amount_max = 1.80
	particulas.color = Color(0.65, 0.69, 0.78, 0.65)
	particulas.texture = _criar_textura_vento_portao()
	particulas.z_index = 1750
	get_tree().current_scene.add_child(particulas)
	particulas.global_position = origem
	particulas.emitting = true
	return particulas


func _explodir_vento_e_neblina() -> void:
	if not is_inside_tree():
		return

	var origem: Vector2 = global_position + Vector2(0.0, -32.0)
	var emissores: Array[CPUParticles2D] = []
	emissores.append(_criar_neblina_ruptura(origem, Vector2(-1.0, -0.10)))
	emissores.append(_criar_neblina_ruptura(origem, Vector2(1.0, -0.10)))
	emissores.append(_criar_vento_ruptura(origem, Vector2.LEFT))
	emissores.append(_criar_vento_ruptura(origem, Vector2.RIGHT))
	_desligar_emissores_depois(emissores)
	_pulso_sombras_abertura()
	_sacudir_camera_abertura()

	if som_vento_ruptura != null:
		var audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		audio.name = "SomVentoAbertura"
		audio.stream = som_vento_ruptura
		audio.volume_db = 0.0
		get_tree().current_scene.add_child(audio)
		audio.global_position = origem
		audio.play()
		audio.finished.connect(audio.queue_free)
		_limitar_duracao_audio_vento(audio)


func _limitar_duracao_audio_vento(audio: AudioStreamPlayer2D) -> void:
	await get_tree().create_timer(9.0).timeout
	if is_instance_valid(audio):
		audio.stop()
		audio.queue_free()


func _desligar_emissores_depois(emissores: Array[CPUParticles2D]) -> void:
	await get_tree().create_timer(3.0).timeout
	for p: CPUParticles2D in emissores:
		if is_instance_valid(p):
			p.emitting = false
	await get_tree().create_timer(6.0).timeout
	for p: CPUParticles2D in emissores:
		if is_instance_valid(p):
			p.queue_free()


func _pulso_sombras_abertura() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SombraDaRuptura"
	layer.layer = 230
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(layer)

	var escuridao: ColorRect = ColorRect.new()
	escuridao.color = Color(0.01, 0.008, 0.016, 0.0)
	escuridao.position = Vector2.ZERO
	escuridao.size = get_viewport_rect().size
	escuridao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(escuridao)

	var tween: Tween = create_tween()
	tween.tween_property(escuridao, "color:a", escurecimento_choque, 0.14)
	tween.tween_property(escuridao, "color:a", 0.20, 0.90)
	tween.tween_property(escuridao, "color:a", 0.0, 2.65)
	tween.tween_callback(layer.queue_free)


func _sacudir_camera_abertura() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if not is_instance_valid(cam) or tremor_ruptura_pixels <= 0.0:
		return

	var base: Vector2 = cam.offset
	for passo: int in range(39):
		if not is_instance_valid(cam) or not is_inside_tree():
			return
		var peso: float = 1.0 - float(passo) / 39.0
		cam.offset = base + Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * tremor_ruptura_pixels * peso
		await get_tree().create_timer(0.028).timeout
	if is_instance_valid(cam):
		cam.offset = base


func _montar_ambiencia_level6_portao() -> void:
	if is_instance_valid(_ambiencia_l6_camada):
		return

	_ambiencia_l6_camada = CanvasLayer.new()
	_ambiencia_l6_camada.name = "FogMundialLevel6AposPortao"
	_ambiencia_l6_camada.layer = 190
	add_child(_ambiencia_l6_camada)

	_ambiencia_l6_raiz = Control.new()
	_ambiencia_l6_raiz.name = "RaizFogMundialAposAbertura"
	_ambiencia_l6_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambiencia_l6_raiz.visible = false
	_ambiencia_l6_camada.add_child(_ambiencia_l6_raiz)

	_ambiencia_l6_sombra = ColorRect.new()
	_ambiencia_l6_sombra.name = "EscuridaoLevel6MapaTodo"
	_ambiencia_l6_sombra.color = Color(0.0, 0.0, 0.0, 0.0)
	_ambiencia_l6_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambiencia_l6_raiz.add_child(_ambiencia_l6_sombra)

	var tex_neblina: Texture2D = _ambiencia_l6_textura_neblina()
	for i: int in range(COLUNAS_NEBLINA_PORTAO_L6 * LINHAS_NEBLINA_PORTAO_L6):
		var nuvem: TextureRect = _ambiencia_l6_novo_retangulo("NeblinaLevel6_" + str(i), tex_neblina)
		nuvem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		nuvem.visible = false
		_ambiencia_l6_nuvens.append(nuvem)

	var tex_cinza: Texture2D = _ambiencia_l6_textura_poeira(18)
	var tex_fumaca: Texture2D = _ambiencia_l6_textura_poeira(30)
	for i: int in range(COLUNAS_CINZAS_PORTAO_L6 * LINHAS_CINZAS_PORTAO_L6):
		var fumaca: bool = i % 8 == 0
		var textura: Texture2D = tex_fumaca if fumaca else tex_cinza
		var cinza: TextureRect = _ambiencia_l6_novo_retangulo("CinzaLevel6_" + str(i), textura)
		cinza.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		cinza.visible = false
		_ambiencia_l6_cinzas.append(cinza)

	_ambiencia_l6_vinheta = _ambiencia_l6_novo_retangulo(
		"VignetteLevel6Persistente", _ambiencia_l6_textura_vinheta()
	)
	_ambiencia_l6_vinheta.modulate.a = 0.0
	_ambiencia_l6_redimensionar()
	if not get_viewport().size_changed.is_connected(_ambiencia_l6_redimensionar):
		get_viewport().size_changed.connect(_ambiencia_l6_redimensionar)


func _ambiencia_l6_novo_retangulo(nome: String, textura: Texture2D) -> TextureRect:
	var ret: TextureRect = TextureRect.new()
	ret.name = nome
	ret.texture = textura
	ret.stretch_mode = TextureRect.STRETCH_SCALE
	ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambiencia_l6_raiz.add_child(ret)
	return ret


func _ambiencia_l6_redimensionar() -> void:
	if not is_instance_valid(_ambiencia_l6_raiz):
		return
	var tela: Vector2 = get_viewport_rect().size
	_ambiencia_l6_raiz.position = Vector2.ZERO
	_ambiencia_l6_raiz.size = tela
	if is_instance_valid(_ambiencia_l6_sombra):
		_ambiencia_l6_sombra.position = Vector2.ZERO
		_ambiencia_l6_sombra.size = tela
	if is_instance_valid(_ambiencia_l6_vinheta):
		_ambiencia_l6_vinheta.position = Vector2.ZERO
		_ambiencia_l6_vinheta.size = tela


func _ativar_ambiencia_level6_portao() -> void:
	if _ambiencia_l6_ativa:
		return
	if not is_instance_valid(_ambiencia_l6_raiz):
		_montar_ambiencia_level6_portao()
	if not is_instance_valid(_ambiencia_l6_raiz):
		return
	_ambiencia_l6_ativa = true
	_ambiencia_l6_forca = 0.0
	_ambiencia_l6_raiz.visible = true
	print("PORTAO: neblina negra, cinzas, sombra e vignette do Level 6 espalhando pelo mapa.")


func _ambiencia_l6_semente(cx: int, cy: int, sal: float) -> float:
	return fposmod(sin(float(cx) * 127.1 + float(cy) * 311.7 + sal) * 43758.5453, 1.0)


func _atualizar_ambiencia_level6_portao(delta: float) -> void:
	if not is_instance_valid(_ambiencia_l6_raiz):
		return
	_ambiencia_l6_tempo += delta * velocidade_neblina_level6
	_ambiencia_l6_forca = minf(
		1.0, _ambiencia_l6_forca + delta / maxf(0.1, tempo_neblina_tomar_mapa)
	)
	var aparicao: float = smoothstep(0.0, 1.0, _ambiencia_l6_forca)

	var tela: Vector2 = get_viewport_rect().size
	_ambiencia_l6_raiz.size = tela
	_ambiencia_l6_sombra.color = Color(0.0, 0.0, 0.0, escurecimento_mapa_aberto * aparicao)

	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var inversa: Transform2D = canvas.affine_inverse()
	var centro_mundo: Vector2 = inversa * (tela * 0.5)
	var zoom: Vector2 = Vector2(
		maxf(0.1, canvas.x.length()),
		maxf(0.1, canvas.y.length())
	)

	var gx: int = floori(centro_mundo.x / ESPACAMENTO_NEBLINA_PORTAO_L6.x)
	var gy: int = floori(centro_mundo.y / ESPACAMENTO_NEBLINA_PORTAO_L6.y)
	for i: int in range(_ambiencia_l6_nuvens.size()):
		var nuvem: TextureRect = _ambiencia_l6_nuvens[i]
		var cx: int = gx + i % COLUNAS_NEBLINA_PORTAO_L6 - 3
		var cy: int = gy + floori(float(i) / float(COLUNAS_NEBLINA_PORTAO_L6)) - 2
		var s: float = _ambiencia_l6_semente(cx, cy, 17.0)
		nuvem.visible = s > 0.18
		if not nuvem.visible:
			continue
		var deslocamento: Vector2 = Vector2(
			(_ambiencia_l6_semente(cx, cy, 33.0) - 0.5) * 180.0,
			(_ambiencia_l6_semente(cx, cy, 66.0) - 0.5) * 110.0
		)
		var deriva: Vector2 = Vector2(
			sin(_ambiencia_l6_tempo * (0.48 + s * 0.12) + s * TAU) * 65.0,
			cos(_ambiencia_l6_tempo * (0.27 + s * 0.12) + s * TAU) * 26.0
		)
		var pos_mundo: Vector2 = (
			Vector2(float(cx) * ESPACAMENTO_NEBLINA_PORTAO_L6.x,
					float(cy) * ESPACAMENTO_NEBLINA_PORTAO_L6.y)
			+ deslocamento + deriva
		)
		var pos_tela: Vector2 = canvas * pos_mundo
		var largura: float = 510.0 + s * 100.0
		var altura: float = 210.0 + s * 42.0
		nuvem.size = Vector2(largura * zoom.x, altura * zoom.y)
		nuvem.position = pos_tela - nuvem.size * 0.5
		nuvem.modulate = Color(
			1.0, 1.0, 1.0,
			opacidade_neblina_level6 * aparicao * (0.76 + 0.24 * s)
		)

	var ax: int = floori(centro_mundo.x / ESPACAMENTO_CINZAS_PORTAO_L6.x)
	var ay: int = floori(centro_mundo.y / ESPACAMENTO_CINZAS_PORTAO_L6.y)
	for i: int in range(_ambiencia_l6_cinzas.size()):
		var cinza: TextureRect = _ambiencia_l6_cinzas[i]
		var cx: int = ax + i % COLUNAS_CINZAS_PORTAO_L6 - 5
		var cy: int = ay + floori(float(i) / float(COLUNAS_CINZAS_PORTAO_L6)) - 3
		var s: float = _ambiencia_l6_semente(cx, cy, 109.0)
		cinza.visible = cinzas_level6_apos_portao and s > 0.28
		if not cinza.visible:
			continue
		var deslocamento: Vector2 = Vector2(
			(_ambiencia_l6_semente(cx, cy, 119.0) - 0.5) * 105.0,
			(_ambiencia_l6_semente(cx, cy, 127.0) - 0.5) * 78.0
		)
		var movimento: Vector2 = Vector2(
			sin(_ambiencia_l6_tempo * (0.55 + 0.15 * s) + s * TAU) * 19.0,
			52.0 - fposmod(_ambiencia_l6_tempo * (13.0 + 9.0 * s) + s * 79.0, 104.0)
		)
		var pos_mundo: Vector2 = (
			Vector2(float(cx) * ESPACAMENTO_CINZAS_PORTAO_L6.x,
					float(cy) * ESPACAMENTO_CINZAS_PORTAO_L6.y)
			+ deslocamento + movimento
		)
		var pos_tela: Vector2 = canvas * pos_mundo
		var fumaca: bool = i % 8 == 0
		var diametro: float = (15.0 + s * 7.0) if fumaca else (3.5 + s * 3.0)
		cinza.size = Vector2(diametro * zoom.x, diametro * zoom.y)
		cinza.position = pos_tela - cinza.size * 0.5
		cinza.modulate.a = (0.34 if fumaca else 0.46) * aparicao

	if is_instance_valid(_ambiencia_l6_vinheta):
		_ambiencia_l6_vinheta.position = Vector2.ZERO
		_ambiencia_l6_vinheta.size = tela
		_ambiencia_l6_vinheta.modulate.a = opacidade_vinheta_level6 * aparicao


func _ambiencia_l6_textura_neblina() -> Texture2D:
	var img: Image = Image.create(192, 96, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 72011
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.024
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	for y: int in range(96):
		for x: int in range(192):
			var nx: float = (float(x) + 0.5) / 192.0
			var ny: float = (float(y) + 0.5) / 96.0
			var bordas: float = smoothstep(0.0, 0.16, nx) * (1.0 - smoothstep(0.84, 1.0, nx))
			var centro: float = 1.0 - smoothstep(0.19, 0.50, absf(ny - 0.5))
			var densidade: float = smoothstep(-0.31, 0.27, noise.get_noise_2d(float(x), float(y)))
			var alpha: float = clampf(bordas * centro * (0.15 + 0.85 * densidade), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return ImageTexture.create_from_image(img)


func _ambiencia_l6_textura_poeira(tamanho: int) -> Texture2D:
	var img: Image = Image.create(tamanho, tamanho, false, Image.FORMAT_RGBA8)
	var raio: float = float(tamanho) * 0.5
	for y: int in range(tamanho):
		for x: int in range(tamanho):
			var d: float = Vector2(float(x) - raio, float(y) - raio).length() / raio
			var alpha: float = pow(1.0 - smoothstep(0.0, 1.0, d), 2.0)
			img.set_pixel(x, y, Color(0.035, 0.035, 0.043, alpha))
	return ImageTexture.create_from_image(img)


func _ambiencia_l6_textura_vinheta() -> Texture2D:
	var img: Image = Image.create(192, 108, false, Image.FORMAT_RGBA8)
	for y: int in range(108):
		for x: int in range(192):
			var nx: float = (float(x) + 0.5) / 192.0 * 2.0 - 1.0
			var ny: float = (float(y) + 0.5) / 108.0 * 2.0 - 1.0
			var r: float = Vector2(nx * 0.90, ny * 1.05).length()
			var alpha: float = smoothstep(0.38, 1.03, r) * 0.92
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return ImageTexture.create_from_image(img)
