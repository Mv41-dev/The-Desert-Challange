extends CharacterBody2D

signal vida_alterada(vida_atual: int, vida_maxima: int)

enum Estado {
	NORMAL,
	ATAQUE,
	FERIDO,
	MORTO
}

enum TipoGolpe {
	LEVE,
	FORTE
}


const SPEED: float = 200.0
const GRAVITY: float = 980.0
const MAX_FALL_SPEED: float = 650.0


# =====================================================
# VIDA E COMBATE
# =====================================================

@export_group("Vida e Combate")

@export_range(1, 20, 1)
var vida_maxima: int = 3

@export_range(1, 10, 1)
var dano_leve: int = 1

@export_range(1, 10, 1)
var dano_forte: int = 2

@export_range(0.2, 3.0, 0.05)
var tempo_invulneravel: float = 0.85

@export_range(0.0, 500.0, 10.0)
var forca_recuo: float = 145.0


# =====================================================
# PULO
# =====================================================

@export_group("Pulo estilo Hollow Knight")

@export_range(-600.0, -200.0, 10.0)
var forca_pulo: float = -350.0

@export_range(0.05, 0.25, 0.01)
var tempo_coyote: float = 0.12

@export_range(0.05, 0.25, 0.01)
var tempo_buffer_pulo: float = 0.12

@export_range(0.2, 0.8, 0.05)
var corte_pulo: float = 0.45

@export_range(1.0, 2.0, 0.05)
var gravidade_queda: float = 1.35

@export_range(1.0, 3.0, 0.1)
var gravidade_pulo_curto: float = 1.8

@export_range(100.0, 3000.0, 50.0)
var aceleracao_chao: float = 1800.0

@export_range(100.0, 2500.0, 50.0)
var aceleracao_ar: float = 1100.0


# =====================================================
# QUEDA PROFUNDA
# =====================================================

@export_group("Queda Profunda")

# Primeiros 2 segundos:
# queda completamente normal.
@export_range(0.5, 5.0, 0.1)
var tempo_antes_queda_profunda: float = 2.0


# Crescimento bem mais lento.
#
# Antes:
# 1.15
#
# Agora:
# 1.10
#
# Continua exponencial, mas demora mais
# para ficar realmente absurdo.
@export_range(1.01, 2.0, 0.01)
var crescimento_exponencial_queda: float = 1.10


# Mantemos um teto alto.
# Ele ainda pode ficar MUITO rapido,
# apenas demora mais para chegar perto dele.
@export_range(1000.0, 6000.0, 100.0)
var velocidade_maxima_queda_profunda: float = 3200.0


# O escurecimento tambem comeca depois
# de 2 segundos de queda.
@export_range(0.5, 5.0, 0.1)
var tempo_antes_escurecer: float = 2.0


# Agora demora bem mais para ficar quase preto.
@export_range(1.0, 12.0, 0.1)
var duracao_escurecimento: float = 6.5


# Curva do escurecimento.
#
# Acima de 1.0:
# escurece devagar no inicio
# e cresce progressivamente depois.
@export_range(1.0, 3.0, 0.05)
var curva_escurecimento: float = 1.35


# DemoEnd ainda completa os ultimos porcentos
# instantaneamente.
@export_range(0.5, 0.99, 0.01)
var escuridao_maxima: float = 0.96


# =====================================================
# ALINHAMENTO
# =====================================================

@export_group("Alinhamento visual")

@export var ajuste_sprite_esquerda: float = -10.0


const OFFSET_J_DIREITA: Vector2 = Vector2(
	29.0,
	14.0
)

const OFFSET_K_DIREITA: Vector2 = Vector2(
	37.0,
	13.0
)


# =====================================================
# ESTADO
# =====================================================

var vida: int = 3

var estado: Estado = Estado.NORMAL

var golpe_atual: TipoGolpe = TipoGolpe.LEVE

var golpe_em_fila: int = -1


var olhando_direita: bool = true

var tempo_invulneravel_restante: float = 0.0

var tempo_coyote_restante: float = 0.0

var tempo_buffer_restante: float = 0.0


var atingidos_no_golpe: Array[Node2D] = []


var posicao_original_sprite: Vector2 = Vector2.ZERO


# =====================================================
# RESPAWN
# =====================================================

var posicao_inicial: Vector2 = Vector2.ZERO


# =====================================================
# QUEDA PROFUNDA
# =====================================================

var tempo_caindo: float = 0.0

var queda_profunda_ativa: bool = false

var escurecimento_ativo: bool = false


var camada_escuridao: CanvasLayer = null

var fundo_escuridao: ColorRect = null


# =====================================================
# NODES
# =====================================================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@onready var colisao_player: CollisionShape2D = $CollisionShape2D

@onready var attack_area_j: Area2D = $AttackAreaJ

@onready var attack_area_k: Area2D = $AttackAreaK


# =====================================================
# READY
# =====================================================

func _ready() -> void:

	add_to_group("player")


	posicao_inicial = global_position


	posicao_original_sprite = anim.position


	olhando_direita = not anim.flip_h


	_atualizar_alinhamento_sprite()


	Global.configurar_vida_maxima(
		vida_maxima
	)


	if Global.vida_atual <= 0:

		Global.reiniciar_vida()


	vida = Global.vida_atual


	vida_alterada.emit(
		vida,
		vida_maxima
	)


	attack_area_j.monitoring = true

	attack_area_k.monitoring = true


	atualizar_areas_ataque()


	if not anim.animation_finished.is_connected(
		_ao_terminar_animacao
	):

		anim.animation_finished.connect(
			_ao_terminar_animacao
		)


	_criar_escuridao_queda()


	_tocar(
		&"idle"
	)


# =====================================================
# PHYSICS
# =====================================================

func _physics_process(
	delta: float
) -> void:

	_atualizar_temporizador_queda(
		delta
	)


	# =====================================================
	# BUFFER DE PULO
	# =====================================================

	if Input.is_action_just_pressed(
		"jump"
	):

		tempo_buffer_restante = (
			tempo_buffer_pulo
		)


	else:

		tempo_buffer_restante = maxf(
			tempo_buffer_restante
			- delta,
			0.0
		)


	# =====================================================
	# COYOTE TIME
	# =====================================================

	if is_on_floor():

		tempo_coyote_restante = (
			tempo_coyote
		)


	else:

		tempo_coyote_restante = maxf(
			tempo_coyote_restante
			- delta,
			0.0
		)


	# =====================================================
	# GRAVIDADE
	# =====================================================

	if not is_on_floor():

		var multiplicador_gravidade: float = 1.0


		if velocity.y < 0.0:

			if not Input.is_action_pressed(
				"jump"
			):

				multiplicador_gravidade = (
					gravidade_pulo_curto
				)


			else:

				multiplicador_gravidade = 1.0


		elif velocity.y > 0.0:

			multiplicador_gravidade = (
				gravidade_queda
			)


		var gravidade_atual: float = (
			GRAVITY
			* multiplicador_gravidade
		)


		var limite_velocidade: float = (
			MAX_FALL_SPEED
		)


		# =================================================
		# QUEDA PROFUNDA
		# =================================================

		if queda_profunda_ativa:

			var tempo_extra: float = maxf(
				0.0,
				tempo_caindo
				- tempo_antes_queda_profunda
			)


			var multiplicador_profundo: float = pow(
				crescimento_exponencial_queda,
				tempo_extra
			)


			gravidade_atual *= (
				multiplicador_profundo
			)


			limite_velocidade = (
				velocidade_maxima_queda_profunda
			)


		velocity.y = minf(
			velocity.y
			+ gravidade_atual
			* delta,
			limite_velocidade
		)


	elif velocity.y > 0.0:

		velocity.y = 0.0


	# =====================================================
	# INVULNERABILIDADE
	# =====================================================

	if tempo_invulneravel_restante > 0.0:

		tempo_invulneravel_restante = maxf(
			tempo_invulneravel_restante
			- delta,
			0.0
		)


		anim.modulate.a = (
			0.4
			if fmod(
				tempo_invulneravel_restante,
				0.16
			) < 0.08
			else 1.0
		)


	else:

		anim.modulate.a = 1.0


	# =====================================================
	# MORTE
	# =====================================================

	if estado == Estado.MORTO:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED * delta * 3.0
		)


		move_and_slide()


		_atualizar_escuridao_queda()


		return


	# =====================================================
	# FERIDO
	# =====================================================

	if estado == Estado.FERIDO:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED * delta * 3.0
		)


		move_and_slide()


		_atualizar_escuridao_queda()


		return


	# =====================================================
	# PULO
	# =====================================================

	if (
		tempo_buffer_restante > 0.0
		and tempo_coyote_restante > 0.0
	):

		velocity.y = forca_pulo


		tempo_buffer_restante = 0.0


		tempo_coyote_restante = 0.0


	if (
		Input.is_action_just_released(
			"jump"
		)
		and velocity.y < 0.0
	):

		velocity.y *= corte_pulo


	# =====================================================
	# MOVIMENTO
	# =====================================================

	var direcao: float = Input.get_axis(
		"left",
		"right"
	)


	if estado == Estado.NORMAL:

		var aceleracao: float = (
			aceleracao_chao
			if is_on_floor()
			else aceleracao_ar
		)


		velocity.x = move_toward(
			velocity.x,
			direcao * SPEED,
			aceleracao * delta
		)


		if absf(
			direcao
		) > 0.01:

			_virar(
				direcao
			)


	else:

		var velocidade_ataque: float = (
			SPEED * 0.30
			if golpe_atual == TipoGolpe.LEVE
			else 0.0
		)


		velocity.x = move_toward(
			velocity.x,
			direcao
			* velocidade_ataque,
			aceleracao_chao
			* delta
		)


	# =====================================================
	# ATAQUES
	# =====================================================

	if Input.is_action_just_pressed(
		"attack_quick"
	):

		solicitar_ataque(
			TipoGolpe.LEVE
		)


	elif Input.is_action_just_pressed(
		"attack_heavy"
	):

		solicitar_ataque(
			TipoGolpe.FORTE
		)


	move_and_slide()


	_atualizar_escuridao_queda()


	if estado == Estado.ATAQUE:

		_verificar_acertos()


	elif estado == Estado.NORMAL:

		_atualizar_animacao_movimento(
			direcao
		)


# =====================================================
# ESCURIDAO
# =====================================================

func _criar_escuridao_queda() -> void:

	camada_escuridao = CanvasLayer.new()


	camada_escuridao.name = (
		"DeepFallDarkness"
	)


	camada_escuridao.layer = 90


	add_child(
		camada_escuridao
	)


	fundo_escuridao = ColorRect.new()


	fundo_escuridao.name = (
		"Darkness"
	)


	fundo_escuridao.color = Color.BLACK


	fundo_escuridao.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	fundo_escuridao.position = Vector2.ZERO


	fundo_escuridao.size = (
		get_viewport_rect().size
	)


	fundo_escuridao.modulate.a = 0.0


	camada_escuridao.add_child(
		fundo_escuridao
	)


	if not get_viewport().size_changed.is_connected(
		_atualizar_tamanho_escuridao
	):

		get_viewport().size_changed.connect(
			_atualizar_tamanho_escuridao
		)


func _atualizar_tamanho_escuridao() -> void:

	if fundo_escuridao == null:
		return


	fundo_escuridao.position = Vector2.ZERO


	fundo_escuridao.size = (
		get_viewport_rect().size
	)


# =====================================================
# TEMPORIZADOR DE QUEDA
# =====================================================

func _atualizar_temporizador_queda(
	delta: float
) -> void:

	if is_on_floor():

		_resetar_queda_profunda()

		return


	if velocity.y <= 0.0:

		return


	tempo_caindo += delta


	# =====================================================
	# ACELERACAO
	# =====================================================

	if (
		not queda_profunda_ativa
		and tempo_caindo
		>= tempo_antes_queda_profunda
	):

		queda_profunda_ativa = true


	# =====================================================
	# ESCURIDAO
	# =====================================================

	if (
		not escurecimento_ativo
		and tempo_caindo
		>= tempo_antes_escurecer
	):

		escurecimento_ativo = true


# =====================================================
# ESCURECIMENTO PROGRESSIVO
# =====================================================

func _atualizar_escuridao_queda() -> void:

	if fundo_escuridao == null:
		return


	if not escurecimento_ativo:

		fundo_escuridao.modulate.a = 0.0

		return


	var tempo_escurecendo: float = maxf(
		0.0,
		tempo_caindo
		- tempo_antes_escurecer
	)


	var progresso: float = clampf(
		tempo_escurecendo
		/ maxf(
			duracao_escurecimento,
			0.01
		),
		0.0,
		1.0
	)


	# =====================================================
	# CURVA EXPONENCIAL SUAVE
	#
	# Exemplo:
	#
	# 0% tempo  -> 0%
	# 25% tempo -> ~15%
	# 50% tempo -> ~39%
	# 75% tempo -> ~68%
	# 100% tempo -> 100%
	#
	# Portanto ele continua escurecendo o tempo inteiro,
	# mas bem devagar no começo.
	# =====================================================

	var progresso_curvado: float = pow(
		progresso,
		curva_escurecimento
	)


	var alpha: float = (
		progresso_curvado
		* escuridao_maxima
	)


	fundo_escuridao.modulate.a = (
		alpha
	)


# =====================================================
# RESET QUEDA
# =====================================================

func _resetar_queda_profunda() -> void:

	tempo_caindo = 0.0


	queda_profunda_ativa = false


	escurecimento_ativo = false


	if fundo_escuridao != null:

		fundo_escuridao.modulate.a = 0.0


# =====================================================
# FORCAR PRETO
# =====================================================

func forcar_tela_preta() -> void:

	if fundo_escuridao == null:
		return


	fundo_escuridao.modulate.a = 1.0


# =====================================================
# RESPAWN
# =====================================================

func resetar_para_inicio() -> void:

	estado = Estado.NORMAL


	golpe_em_fila = -1


	atingidos_no_golpe.clear()


	velocity = Vector2.ZERO


	tempo_coyote_restante = 0.0


	tempo_buffer_restante = 0.0


	_resetar_queda_profunda()


	global_position = (
		posicao_inicial
	)


	reset_physics_interpolation()


	anim.modulate.a = 1.0


	_tocar(
		&"idle"
	)


# =====================================================
# VIRAR
# =====================================================

func _virar(
	direcao: float
) -> void:

	var nova_direcao: bool = (
		direcao > 0.0
	)


	if olhando_direita == nova_direcao:

		return


	olhando_direita = nova_direcao


	anim.flip_h = (
		not olhando_direita
	)


	_atualizar_alinhamento_sprite()


	atualizar_areas_ataque()


# =====================================================
# ALINHAMENTO
# =====================================================

func _atualizar_alinhamento_sprite() -> void:

	if olhando_direita:

		anim.position = (
			posicao_original_sprite
		)


	else:

		anim.position = (
			posicao_original_sprite
			+ Vector2(
				ajuste_sprite_esquerda,
				0.0
			)
		)


# =====================================================
# AREAS DE ATAQUE
# =====================================================

func atualizar_areas_ataque() -> void:

	if olhando_direita:

		attack_area_j.position = (
			OFFSET_J_DIREITA
		)


		attack_area_k.position = (
			OFFSET_K_DIREITA
		)


		attack_area_j.scale.x = 1.0


		attack_area_k.scale.x = 1.0


	else:

		attack_area_j.position = Vector2(
			-OFFSET_J_DIREITA.x,
			OFFSET_J_DIREITA.y
		)


		attack_area_k.position = Vector2(
			-OFFSET_K_DIREITA.x,
			OFFSET_K_DIREITA.y
		)


		attack_area_j.scale.x = -1.0


		attack_area_k.scale.x = -1.0


# =====================================================
# ANIMACAO
# =====================================================

func _atualizar_animacao_movimento(
	direcao: float
) -> void:

	if not is_on_floor():

		if velocity.y < 0.0:

			_tocar(
				&"jump"
			)


		else:

			_tocar(
				&"fall"
			)


	elif absf(
		direcao
	) > 0.01:

		_tocar(
			&"run"
		)


	else:

		_tocar(
			&"idle"
		)


func _tocar(
	nome: StringName
) -> void:

	if (
		anim.sprite_frames.has_animation(
			nome
		)
		and (
			anim.animation != nome
			or not anim.is_playing()
		)
	):

		anim.play(
			nome
		)


# =====================================================
# ATAQUES
# =====================================================

func solicitar_ataque(
	tipo: TipoGolpe
) -> void:

	if estado == Estado.NORMAL:

		_iniciar_ataque(
			tipo
		)


	elif (
		estado == Estado.ATAQUE
		and anim.frame >= 2
	):

		golpe_em_fila = int(
			tipo
		)


func _iniciar_ataque(
	tipo: TipoGolpe
) -> void:

	estado = Estado.ATAQUE


	golpe_atual = tipo


	golpe_em_fila = -1


	atingidos_no_golpe.clear()


	atualizar_areas_ataque()


	if tipo == TipoGolpe.LEVE:

		anim.play(
			&"attack_quick"
		)


	else:

		anim.play(
			&"attack_heavy"
		)


func _verificar_acertos() -> void:

	var frame: int = anim.frame


	var ativo: bool = false


	var area: Area2D = attack_area_j


	var dano: int = dano_leve


	if golpe_atual == TipoGolpe.LEVE:

		ativo = (
			frame >= 2
			and frame <= 3
		)


	else:

		ativo = (
			frame >= 3
			and frame <= 5
		)


		area = attack_area_k


		dano = dano_forte


	if not ativo:

		return


	for corpo in area.get_overlapping_bodies():

		if not is_instance_valid(
			corpo
		):

			continue


		if not corpo.is_in_group(
			"inimigo"
		):

			continue


		if (
			corpo.has_method(
				"tomar_dano"
			)
			and not atingidos_no_golpe.has(
				corpo
			)
		):

			atingidos_no_golpe.append(
				corpo
			)


			corpo.tomar_dano(
				dano,
				global_position
			)


# =====================================================
# DANO
# =====================================================

func tomar_dano(
	quantidade: int,
	origem: Vector2 = Vector2.ZERO
) -> void:

	if (
		quantidade <= 0
		or estado == Estado.MORTO
		or tempo_invulneravel_restante > 0.0
	):

		return


	tempo_invulneravel_restante = (
		tempo_invulneravel
	)


	golpe_em_fila = -1


	Global.tomar_dano(
		quantidade
	)


	vida = Global.vida_atual


	vida_alterada.emit(
		vida,
		vida_maxima
	)


	if vida <= 0:

		morrer()

		return


	estado = Estado.FERIDO


	atingidos_no_golpe.clear()


	var lado: float = (
		-1.0
		if olhando_direita
		else 1.0
	)


	if origem != Vector2.ZERO:

		lado = (
			1.0
			if global_position.x
			>= origem.x
			else -1.0
		)


	velocity.x = (
		lado
		* forca_recuo
	)


	velocity.y = minf(
		velocity.y,
		-100.0
	)


	anim.play(
		&"hurt"
	)


# =====================================================
# MORTE
# =====================================================

func morrer() -> void:

	if estado == Estado.MORTO:

		return


	estado = Estado.MORTO


	golpe_em_fila = -1


	atingidos_no_golpe.clear()


	velocity.x = 0.0


	anim.modulate.a = 1.0


	anim.play(
		&"death"
	)


# =====================================================
# FIM DAS ANIMACOES
# =====================================================

func _ao_terminar_animacao() -> void:

	match estado:

		Estado.ATAQUE:

			if (
				anim.animation
				== &"attack_quick"
				or anim.animation
				== &"attack_heavy"
			):

				estado = Estado.NORMAL


				if golpe_em_fila != -1:

					var proximo: TipoGolpe = (
						TipoGolpe.FORTE
						if golpe_em_fila
						== int(
							TipoGolpe.FORTE
						)
						else TipoGolpe.LEVE
					)


					_iniciar_ataque(
						proximo
					)


		Estado.FERIDO:

			if anim.animation == &"hurt":

				estado = Estado.NORMAL


		Estado.MORTO:

			if anim.animation == &"death":

				Global.reiniciar_vida()


				get_tree().call_deferred(
					"reload_current_scene"
				)
