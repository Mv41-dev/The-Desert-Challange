
extends Node

# THE DESERT CHALLENGE
# AMBIENCIA LEVEL 6 V2 - ABISMO MAIS ESCURO
#
# Preserva neblina e cinzas ancoradas no mundo.
# Preserva integracao visual com o HUD e King Necro.
# Aumenta a escuridao, vignette e densidade da neblina.
#
# Adicionar em Level6/AmbienciaLevel6.

@export_group("Escuridao inicial")
@export_range(0.0, 0.85, 0.01)
var escuridao_no_inicio: float = 0.50

@export_range(0.0, 0.85, 0.01)
var escuridao_apos_subida: float = 0.68

@export_range(300.0, 6000.0, 50.0)
var altura_para_escuridao_maxima: float = 2100.0

# O King Necro adiciona sombras proprias.
@export_range(0.0, 0.5, 0.01)
var escuridao_durante_boss_final: float = 0.18

@export_range(0.2, 3.0, 0.05)
var suavidade_escurecimento: float = 1.1


@export_group("Neblina mundial")
@export var mostrar_neblina: bool = true

@export_range(0.15, 0.85, 0.01)
var opacidade_neblina_inicial: float = 0.43

@export_range(0.15, 0.85, 0.01)
var opacidade_neblina_alto: float = 0.60

@export_range(0.2, 3.0, 0.05)
var velocidade_neblina: float = 1.0


@export_group("Particulas e vignette")
@export var mostrar_particulas: bool = true
@export var mostrar_vignette: bool = true

@export_range(0.1, 0.95, 0.01)
var opacidade_vignette_inicio: float = 0.58

@export_range(0.1, 0.95, 0.01)
var opacidade_vignette_alto: float = 0.76


const COLUNAS_NEBLINA: int = 7
const LINHAS_NEBLINA: int = 5
const ESPACAMENTO_NEBLINA: Vector2 = Vector2(420.0, 250.0)

const COLUNAS_CINZAS: int = 11
const LINHAS_CINZAS: int = 7
const ESPACAMENTO_CINZAS: Vector2 = Vector2(160.0, 125.0)


var _jogador: Node2D = null
var _boss: Node = null

var _y_inicial: float = 0.0
var _menor_y: float = INF
var _busca_timer: float = 0.0
var _tempo: float = 0.0
var _escuridao_atual: float = 0.0

var _camada_base: CanvasLayer = null
var _sombra: ColorRect = null

var _camada_reserva: CanvasLayer = null
var _raiz_efeitos: Control = null
var _vignette: TextureRect = null

var _neblinas: Array[TextureRect] = []
var _cinzas: Array[TextureRect] = []

var _hospedeiro_hud: CanvasLayer = null


func _ready() -> void:
	_procurar_jogador()
	_procurar_boss()

	if is_instance_valid(_jogador):
		_y_inicial = _jogador.global_position.y
		_menor_y = _y_inicial

	_montar_base()
	_montar_efeitos()

	_escuridao_atual = escuridao_no_inicio

	_sombra.color = Color(
		0.0, 0.0, 0.0, escuridao_no_inicio
	)

	print("AMBIENCIA LEVEL 6 V2: Abismo escurecido.")


func _process(delta: float) -> void:
	_tempo += delta * velocidade_neblina
	_busca_timer += delta

	if _busca_timer >= 1.0:
		_busca_timer = 0.0

		if not is_instance_valid(_jogador):
			_procurar_jogador()

			if is_instance_valid(_jogador):
				_y_inicial = _jogador.global_position.y
				_menor_y = _y_inicial

		if not is_instance_valid(_boss):
			_procurar_boss()

		_tentar_usar_hud_visivel()

	var progresso: float = 0.0

	if is_instance_valid(_jogador):
		_menor_y = minf(
			_menor_y,
			_jogador.global_position.y
		)

		progresso = clampf(
			(_y_inicial - _menor_y)
			/ maxf(1.0, altura_para_escuridao_maxima),
			0.0,
			1.0
		)

	progresso = smoothstep(0.0, 1.0, progresso)

	var fase: int = _fase_atual_boss()

	var alvo: float = lerpf(
		escuridao_no_inicio,
		escuridao_apos_subida,
		progresso
	)

	# Conserva a logica de protecao visual durante o boss,
	# com valores um pouco mais escuros que antes.
	if fase >= 14:
		alvo = escuridao_durante_boss_final

	elif fase >= 13:
		alvo = minf(alvo, 0.36)

	elif fase == 4 or fase == 8:
		alvo = minf(alvo, 0.42)

	_escuridao_atual = move_toward(
		_escuridao_atual,
		alvo,
		delta * suavidade_escurecimento
	)

	if is_instance_valid(_sombra):
		_sombra.color = Color(
			0.0, 0.0, 0.0, _escuridao_atual
		)

	var mostrar_visuais: bool = (
		fase != 11
		and fase != 12
		and fase < 16
	)

	if is_instance_valid(_raiz_efeitos):
		_raiz_efeitos.visible = mostrar_visuais

	if not mostrar_visuais:
		return

	_animar_efeitos(progresso, fase)


func _procurar_jogador() -> void:
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			_jogador = node as Node2D
			return


func _procurar_boss() -> void:
	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		return

	for node: Node in cena.find_children(
		"*",
		"CharacterBody2D",
		true,
		false
	):
		if node.has_method(
			"_level6_update_void_atmosphere"
		):
			_boss = node
			return


func _fase_atual_boss() -> int:
	if not is_instance_valid(_boss):
		return -1

	var valor: Variant = _boss.get("level6_stage")

	if valor is int:
		return int(valor)

	return -1


# ============================================================
# BASE DARKNESS
# ============================================================

func _montar_base() -> void:
	_camada_base = CanvasLayer.new()
	_camada_base.name = "Level6EscuridaoBase"
	_camada_base.layer = 90

	add_child(_camada_base)

	_sombra = ColorRect.new()
	_sombra.name = "PretoDesdeOInicio"
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_camada_base.add_child(_sombra)
	_atualizar_tamanho_base()

	if not get_viewport().size_changed.is_connected(
		_atualizar_tamanho_base
	):
		get_viewport().size_changed.connect(
			_atualizar_tamanho_base
		)


func _atualizar_tamanho_base() -> void:
	if is_instance_valid(_sombra):
		_sombra.position = Vector2.ZERO
		_sombra.size = get_viewport().get_visible_rect().size


# ============================================================
# WORLD ATMOSPHERE
# ============================================================

func _montar_efeitos() -> void:
	_camada_reserva = CanvasLayer.new()
	_camada_reserva.name = "Level6EfeitosReserva"
	_camada_reserva.layer = 920

	add_child(_camada_reserva)

	_raiz_efeitos = Control.new()
	_raiz_efeitos.name = "NeblinaAncoradaNoMundo"
	_raiz_efeitos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz_efeitos.size = (
		get_viewport().get_visible_rect().size
	)

	_camada_reserva.add_child(_raiz_efeitos)

	var textura_neblina: Texture2D = (
		_criar_textura_neblina()
	)

	for i: int in range(
		COLUNAS_NEBLINA * LINHAS_NEBLINA
	):
		var nuvem: TextureRect = _novo_retangulo(
			"Neblina_" + str(i),
			textura_neblina
		)

		nuvem.texture_filter = (
			CanvasItem.TEXTURE_FILTER_LINEAR
		)

		_neblinas.append(nuvem)

	var textura_cinza: Texture2D = (
		_criar_textura_poeira(18)
	)

	var textura_fumaca: Texture2D = (
		_criar_textura_poeira(30)
	)

	for i: int in range(
		COLUNAS_CINZAS * LINHAS_CINZAS
	):
		var fumaca: bool = (i % 8 == 0)

		var pontinho: TextureRect = _novo_retangulo(
			"Fumaca_" + str(i)
			if fumaca else "Cinza_" + str(i),

			textura_fumaca
			if fumaca else textura_cinza
		)

		pontinho.texture_filter = (
			CanvasItem.TEXTURE_FILTER_LINEAR
		)

		_cinzas.append(pontinho)

	_vignette = _novo_retangulo(
		"VignetteAbismo",
		_criar_textura_vignette()
	)

	_tentar_usar_hud_visivel()


func _novo_retangulo(
	nome: String,
	textura: Texture2D
) -> TextureRect:
	var ret: TextureRect = TextureRect.new()
	ret.name = nome
	ret.texture = textura
	ret.stretch_mode = TextureRect.STRETCH_SCALE
	ret.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_raiz_efeitos.add_child(ret)
	return ret


func _tentar_usar_hud_visivel() -> void:
	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		return

	var hud: CanvasLayer = cena.find_child(
		"HUD", true, false
	) as CanvasLayer

	if not is_instance_valid(hud):
		return

	if hud == _hospedeiro_hud:
		return

	if (
		is_instance_valid(_raiz_efeitos)
		and _raiz_efeitos.get_parent() != hud
	):
		_raiz_efeitos.reparent(hud, false)
		hud.move_child(_raiz_efeitos, 0)
		_raiz_efeitos.position = Vector2.ZERO

		_hospedeiro_hud = hud

		print(
			"AMBIENCIA LEVEL 6: efeitos no HUD visivel."
		)


func _semente(
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


func _animar_efeitos(
	progresso: float,
	fase: int
) -> void:
	if not is_instance_valid(_raiz_efeitos):
		return

	var tela: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	_raiz_efeitos.size = tela

	var canvas: Transform2D = (
		get_viewport().get_canvas_transform()
	)

	var inv: Transform2D = canvas.affine_inverse()

	var centro_mundo: Vector2 = (
		inv * (tela * 0.5)
	)

	var zoom: Vector2 = Vector2(
		maxf(0.1, canvas.x.length()),
		maxf(0.1, canvas.y.length())
	)

	# O King cria mais neblina ao chegar ao final.
	var multiplicador_boss: float = (
		0.62 if fase >= 15 else 1.0
	)

	var opacidade: float = (
		lerpf(
			opacidade_neblina_inicial,
			opacidade_neblina_alto,
			progresso
		) * multiplicador_boss
	)

	var gx: int = floori(
		centro_mundo.x / ESPACAMENTO_NEBLINA.x
	)

	var gy: int = floori(
		centro_mundo.y / ESPACAMENTO_NEBLINA.y
	)

	for i: int in range(_neblinas.size()):
		var nuvem: TextureRect = _neblinas[i]

		var cx: int = (
			gx + i % COLUNAS_NEBLINA - 3
		)

		var cy: int = (
			gy
			+ floori(
				float(i) / float(COLUNAS_NEBLINA)
			) - 2
		)

		var s: float = _semente(cx, cy, 17.0)

		nuvem.visible = (
			mostrar_neblina and s > 0.18
		)

		if not nuvem.visible:
			continue

		var deslocamento: Vector2 = Vector2(
			(_semente(cx, cy, 33.0) - 0.5) * 180.0,
			(_semente(cx, cy, 66.0) - 0.5) * 110.0
		)

		var deriva: Vector2 = Vector2(
			sin(
				_tempo * (0.48 + s * 0.12)
				+ s * TAU
			) * 65.0,

			cos(
				_tempo * (0.27 + s * 0.12)
				+ s * TAU
			) * 26.0
		)

		var pos_mundo: Vector2 = (
			Vector2(
				float(cx) * ESPACAMENTO_NEBLINA.x,
				float(cy) * ESPACAMENTO_NEBLINA.y
			)
			+ deslocamento
			+ deriva
		)

		var pos_tela: Vector2 = (
			canvas * pos_mundo
		)

		var largura: float = 510.0 + s * 100.0
		var altura: float = 210.0 + s * 42.0

		nuvem.size = Vector2(
			largura * zoom.x,
			altura * zoom.y
		)

		nuvem.position = (
			pos_tela - nuvem.size * 0.5
		)

		nuvem.modulate = Color(
			1.0, 1.0, 1.0,
			opacidade * (0.76 + 0.24 * s)
		)

	var ax: int = floori(
		centro_mundo.x / ESPACAMENTO_CINZAS.x
	)

	var ay: int = floori(
		centro_mundo.y / ESPACAMENTO_CINZAS.y
	)

	for i: int in range(_cinzas.size()):
		var cinza: TextureRect = _cinzas[i]

		var cx: int = (
			ax + i % COLUNAS_CINZAS - 5
		)

		var cy: int = (
			ay
			+ floori(
				float(i) / float(COLUNAS_CINZAS)
			) - 3
		)

		var s: float = _semente(cx, cy, 109.0)

		cinza.visible = (
			mostrar_particulas and s > 0.28
		)

		if not cinza.visible:
			continue

		var deslocamento: Vector2 = Vector2(
			(_semente(cx, cy, 119.0) - 0.5) * 105.0,
			(_semente(cx, cy, 127.0) - 0.5) * 78.0
		)

		var movimento: Vector2 = Vector2(
			sin(
				_tempo * (0.55 + 0.15 * s)
				+ s * TAU
			) * 19.0,

			52.0 - fposmod(
				_tempo * (13.0 + 9.0 * s)
				+ s * 79.0,
				104.0
			)
		)

		var pos_mundo: Vector2 = (
			Vector2(
				float(cx) * ESPACAMENTO_CINZAS.x,
				float(cy) * ESPACAMENTO_CINZAS.y
			)
			+ deslocamento
			+ movimento
		)

		var pos_tela: Vector2 = (
			canvas * pos_mundo
		)

		var fumaca: bool = (i % 8 == 0)

		var diametro: float = (
			(15.0 + s * 7.0)
			if fumaca
			else (3.5 + s * 3.0)
		)

		cinza.size = Vector2(
			diametro * zoom.x,
			diametro * zoom.y
		)

		cinza.position = (
			pos_tela - cinza.size * 0.5
		)

		cinza.modulate.a = (
			(0.34 if fumaca else 0.46)
			* (0.7 + progresso * 0.3)
		)

	if is_instance_valid(_vignette):
		_vignette.visible = mostrar_vignette
		_vignette.position = Vector2.ZERO
		_vignette.size = tela

		_vignette.modulate.a = lerpf(
			opacidade_vignette_inicio,
			opacidade_vignette_alto,
			progresso
		)


# ============================================================
# PROCEDURAL ATMOSPHERE TEXTURES
# ============================================================

func _criar_textura_neblina() -> Texture2D:
	var img: Image = Image.create(
		192, 96, false, Image.FORMAT_RGBA8
	)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 72011
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.024
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

	for y: int in range(96):
		for x: int in range(192):
			var nx: float = (
				(float(x) + 0.5) / 192.0
			)

			var ny: float = (
				(float(y) + 0.5) / 96.0
			)

			var bordas: float = (
				smoothstep(0.0, 0.16, nx)
				* (
					1.0
					- smoothstep(0.84, 1.0, nx)
				)
			)

			var centro: float = (
				1.0
				- smoothstep(
					0.19,
					0.50,
					absf(ny - 0.5)
				)
			)

			var densidade: float = smoothstep(
				-0.31,
				0.27,
				noise.get_noise_2d(
					float(x),
					float(y)
				)
			)

			var alpha: float = clampf(
				bordas * centro
				* (0.15 + 0.85 * densidade),
				0.0, 1.0
			)

			img.set_pixel(
				x, y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	return ImageTexture.create_from_image(img)


func _criar_textura_poeira(
	tamanho: int
) -> Texture2D:
	var img: Image = Image.create(
		tamanho,
		tamanho,
		false,
		Image.FORMAT_RGBA8
	)

	var raio: float = float(tamanho) * 0.5

	for y: int in range(tamanho):
		for x: int in range(tamanho):
			var d: float = (
				Vector2(
					float(x) - raio,
					float(y) - raio
				).length() / raio
			)

			var alpha: float = pow(
				1.0 - smoothstep(0.0, 1.0, d),
				2.0
			)

			img.set_pixel(
				x, y,
				Color(
					0.035,
					0.035,
					0.043,
					alpha
				)
			)

	return ImageTexture.create_from_image(img)


func _criar_textura_vignette() -> Texture2D:
	var img: Image = Image.create(
		192, 108, false, Image.FORMAT_RGBA8
	)

	for y: int in range(108):
		for x: int in range(192):
			var nx: float = (
				(float(x) + 0.5) / 192.0
				* 2.0 - 1.0
			)

			var ny: float = (
				(float(y) + 0.5) / 108.0
				* 2.0 - 1.0
			)

			var r: float = Vector2(
				nx * 0.90,
				ny * 1.05
			).length()

			var alpha: float = (
				smoothstep(0.38, 1.03, r)
				* 0.92
			)

			img.set_pixel(
				x, y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	return ImageTexture.create_from_image(img)


func _exit_tree() -> void:
	var viewport: Viewport = get_viewport()

	if viewport.size_changed.is_connected(
		_atualizar_tamanho_base
	):
		viewport.size_changed.disconnect(
			_atualizar_tamanho_base
		)
