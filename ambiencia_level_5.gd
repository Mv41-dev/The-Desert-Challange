
# THE DESERT CHALLENGE
# AMBIENCIA LEVEL 5 - V3
#
# Preserves:
# - Progressive darkness as player moves right
# - Darkness retained when walking back
# - Original soft vignette
#
# Fixes:
# - Compatible with corruptionarea's black flash
# - Detects Necromancer corruption automatically
# - Permanently darkens the environment after corruption
# - Keeps darkness after the Void Guardian dies
# - Uses its own existing ambience renderer
#
# Attach ONLY to AmbienciaLevel5.
# No additional nodes required.

extends Node


@export_group("Progressao horizontal")

@export var encontrar_player_pelo_grupo: bool = true
@export var player_path: NodePath

@export_range(400.0, 9000.0, 50.0)
var distancia_escurecimento: float = 2600.0

@export_range(0.0, 0.65, 0.01)
var escuridao_inicial: float = 0.06

@export_range(0.0, 0.75, 0.01)
var escuridao_final: float = 0.41

@export var manter_escuridao_ao_voltar: bool = true

@export_range(0.5, 8.0, 0.1)
var velocidade_transicao: float = 1.6


@export_group("Vignette")

@export var usar_vignette: bool = true

@export_range(0.0, 0.75, 0.01)
var vignette_maxima: float = 0.43


@export_group("Corrupcao do Necromancer")

@export var detectar_corrupcao: bool = true

@export var corruption_area_path: NodePath = NodePath(
	"../corruptionarea"
)

@export_range(0.0, 0.85, 0.01)
var escuridao_apos_corrupcao: float = 0.55

@export_range(0.0, 1.0, 0.01)
var vignette_apos_corrupcao: float = 0.72


@export_group("Renderizacao")

# Above the level environment, but below the corruption
# area's full-screen black flash on layer 1000.
@export_range(90, 999, 1)
var camada_ambiencia: int = 950

@export var manter_hud_visivel: bool = true
@export var debug_ambiencia: bool = false


var _player: Node2D = null

var _x_inicio: float = 0.0
var _progresso_maior: float = 0.0
var _alpha_atual: float = 0.0

var _camada: CanvasLayer = null
var _sombra: ColorRect = null
var _bordas: TextureRect = null

var _tempo_busca: float = 0.0

var _corruption_area: Area2D = null
var _corrupcao_permanente: bool = false

var _hud: CanvasLayer = null
var _hud_layer_original: int = 0

var _debug_timer: float = 0.0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:

	_criar_camada()
	_procurar_player()
	_procurar_corrupcao()

	if is_instance_valid(_player):
		_x_inicio = _player.global_position.x

	_alpha_atual = escuridao_inicial

	_sombra.color = Color(
		0.0,
		0.0,
		0.0,
		escuridao_inicial
	)

	if manter_hud_visivel:
		_manter_hud_acima()

	set_process(true)

	print("AMBIENCIA LEVEL 5 V3: initialized")


# ============================================================
# MAIN ENVIRONMENT PROCESS
# ============================================================

func _process(delta: float) -> void:

	_tempo_busca += delta

	if _tempo_busca >= 0.5:
		_tempo_busca = 0.0

		if not is_instance_valid(_player):
			_procurar_player()

			if is_instance_valid(_player):
				_x_inicio = _player.global_position.x

		if detectar_corrupcao:
			if not is_instance_valid(_corruption_area):
				_procurar_corrupcao()

			_verificar_estado_corrupcao()

		if manter_hud_visivel:
			_manter_hud_acima()

	# Original horizontal progression.
	var progresso: float = 0.0

	if is_instance_valid(_player):

		progresso = clampf(
			(
				_player.global_position.x -
				_x_inicio
			) / maxf(
				1.0,
				distancia_escurecimento
			),
			0.0,
			1.0
		)

		if manter_escuridao_ao_voltar:
			_progresso_maior = maxf(
				_progresso_maior,
				progresso
			)

			progresso = _progresso_maior

	var progressao_suave: float = smoothstep(
		0.0,
		1.0,
		progresso
	)

	var alvo: float = lerpf(
		escuridao_inicial,
		escuridao_final,
		progressao_suave
	)

	# The horizontal ambience continues normally.
	# Corruption adds a permanent minimum darkness.
	if _corrupcao_permanente:
		alvo = maxf(
			alvo,
			escuridao_apos_corrupcao
		)

	_alpha_atual = move_toward(
		_alpha_atual,
		alvo,
		delta * velocidade_transicao
	)

	if is_instance_valid(_sombra):

		_camada.visible = true
		_sombra.visible = true

		# Important: use ColorRect.color.a.
		# This is the method already used by the original
		# Level 5 ambient renderer.
		_sombra.modulate = Color.WHITE

		_sombra.color = Color(
			0.0,
			0.0,
			0.0,
			_alpha_atual
		)

	if is_instance_valid(_bordas):

		_bordas.visible = usar_vignette

		if usar_vignette:

			var vignette_alvo: float = (
				vignette_maxima *
				progressao_suave
			)

			if _corrupcao_permanente:
				vignette_alvo = maxf(
					vignette_alvo,
					vignette_apos_corrupcao
				)

			_bordas.modulate.a = vignette_alvo

	if debug_ambiencia:

		_debug_timer += delta

		if _debug_timer >= 2.0:
			_debug_timer = 0.0

			print(
				"AMBIENCIA V3 | alpha=",
				snappedf(_alpha_atual, 0.01),
				" | corrupcao=",
				_corrupcao_permanente,
				" | canvas_visible=",
				_camada.is_visible()
			)


# ============================================================
# FIND PLAYER
# ============================================================

func _procurar_player() -> void:

	if not encontrar_player_pelo_grupo:
		if not player_path.is_empty():

			_player = get_node_or_null(
				player_path
			) as Node2D

			if is_instance_valid(_player):
				return

	for node: Node in get_tree().get_nodes_in_group(
		"player"
	):

		if node is Node2D:
			_player = node as Node2D
			return


# ============================================================
# CONNECT TO CORRUPTION AREA
# ============================================================

func _procurar_corrupcao() -> void:

	if not detectar_corrupcao:
		return

	if is_instance_valid(_corruption_area):
		return

	if not corruption_area_path.is_empty():
		_corruption_area = get_node_or_null(
			corruption_area_path
		) as Area2D

	if not is_instance_valid(_corruption_area):

		var scene: Node = get_tree().current_scene

		if is_instance_valid(scene):
			_corruption_area = scene.find_child(
				"corruptionarea",
				true,
				false
			) as Area2D

	if not is_instance_valid(_corruption_area):
		return

	# Connect to the existing corruptionarea signals.
	# No changes to the boss or arena code are needed.

	if _corruption_area.has_signal(
		&"necromante_desapareceu"
	):

		if not _corruption_area.is_connected(
			&"necromante_desapareceu",
			_on_necromante_desapareceu
		):

			_corruption_area.connect(
				&"necromante_desapareceu",
				_on_necromante_desapareceu
			)

	if _corruption_area.has_signal(
		&"corrupcao_finalizada"
	):

		if not _corruption_area.is_connected(
			&"corrupcao_finalizada",
			_on_guardian_spawned
		):

			_corruption_area.connect(
				&"corrupcao_finalizada",
				_on_guardian_spawned
			)

	print(
		"AMBIENCIA LEVEL 5: corruptionarea linked"
	)


# ============================================================
# CORRUPTION STATE
# ============================================================

func _verificar_estado_corrupcao() -> void:

	if _corrupcao_permanente:
		return

	if not is_instance_valid(_corruption_area):
		return

	if not _corruption_area.has_signal(
		&"necromante_desapareceu"
	):
		return

	# Fallback if the signal occurred before the
	# ambient controller connected.

	var ativada: bool = bool(
		_corruption_area.get("ativado")
	)

	var animando: bool = bool(
		_corruption_area.get("em_corrupcao")
	)

	if ativada and not animando:
		_ativar_escuridao_corrompida()


func _on_necromante_desapareceu() -> void:

	_ativar_escuridao_corrompida()


func _on_guardian_spawned(
	_guardian: Node2D
) -> void:

	_ativar_escuridao_corrompida()


func _ativar_escuridao_corrompida() -> void:

	if _corrupcao_permanente:
		return

	_corrupcao_permanente = true

	print(
		"AMBIENCIA LEVEL 5: ",
		"permanent corruption darkness activated"
	)


# ============================================================
# AMBIENCE CANVAS
# ============================================================

func _criar_camada() -> void:

	_camada = CanvasLayer.new()
	_camada.name = "Level5EscurecimentoAmbiente"

	# Higher than scenery, below corruption black flash.
	_camada.layer = camada_ambiencia
	_camada.follow_viewport_enabled = false

	add_child(_camada)

	_sombra = ColorRect.new()
	_sombra.name = "SombraProgressiva"

	_sombra.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_sombra.color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)

	_sombra.modulate = Color.WHITE

	_camada.add_child(_sombra)

	_bordas = TextureRect.new()
	_bordas.name = "VignetteProgressiva"

	_bordas.texture = _criar_vignette()

	_bordas.stretch_mode = (
		TextureRect.STRETCH_SCALE
	)

	_bordas.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_camada.add_child(_bordas)

	_atualizar_tamanhos()

	if not get_viewport().size_changed.is_connected(
		_atualizar_tamanhos
	):

		get_viewport().size_changed.connect(
			_atualizar_tamanhos
		)


# ============================================================
# KEEP HUD VISIBLE
# ============================================================

func _manter_hud_acima() -> void:

	if not manter_hud_visivel:
		return

	if is_instance_valid(_hud):
		_hud.layer = maxi(
			_hud.layer,
			1100
		)
		return

	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	_hud = scene.find_child(
		"HUD",
		true,
		false
	) as CanvasLayer

	if not is_instance_valid(_hud):
		return

	_hud_layer_original = _hud.layer
	_hud.layer = maxi(_hud.layer, 1100)


# ============================================================
# SCREEN RESIZING
# ============================================================

func _atualizar_tamanhos() -> void:

	var tamanho: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	if is_instance_valid(_sombra):
		_sombra.position = Vector2.ZERO
		_sombra.size = tamanho

	if is_instance_valid(_bordas):
		_bordas.position = Vector2.ZERO
		_bordas.size = tamanho


# ============================================================
# ORIGINAL VIGNETTE TEXTURE
# ============================================================

func _criar_vignette() -> Texture2D:

	var imagem: Image = Image.create(
		160,
		90,
		false,
		Image.FORMAT_RGBA8
	)

	for y: int in range(90):
		for x: int in range(160):

			var nx: float = (
				float(x) / 159.0
			) * 2.0 - 1.0

			var ny: float = (
				float(y) / 89.0
			) * 2.0 - 1.0

			var raio: float = Vector2(
				nx * 0.92,
				ny * 1.12
			).length()

			var alpha: float = (
				smoothstep(
					0.39,
					1.05,
					raio
				) * 0.91
			)

			imagem.set_pixel(
				x,
				y,
				Color(
					0.0,
					0.0,
					0.0,
					alpha
				)
			)

	return ImageTexture.create_from_image(
		imagem
	)


# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:

	if get_viewport().size_changed.is_connected(
		_atualizar_tamanhos
	):

		get_viewport().size_changed.disconnect(
			_atualizar_tamanhos
		)

	if is_instance_valid(_hud):
		_hud.layer = _hud_layer_original
