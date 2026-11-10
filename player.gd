extends CharacterBody2D


signal vida_alterada(
	vida_atual: int,
	vida_maxima: int
)


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
# queda normal.
@export_range(0.5, 5.0, 0.1)
var tempo_antes_queda_profunda: float = 2.0


# Crescimento exponencial suave.
@export_range(1.01, 2.0, 0.01)
var crescimento_exponencial_queda: float = 1.10


# NOVO LIMITE MAXIMO.
#
# Antes estava extremamente rapido.
# Agora ainda acelera bastante,
# mas fica muito mais controlavel.
@export_range(800.0, 3000.0, 50.0)
var velocidade_maxima_queda_profunda: float = 1400.0


# =====================================================
# ESCURECIMENTO
# =====================================================

# Comeca junto com a queda profunda.
@export_range(0.5, 5.0, 0.1)
var tempo_antes_escurecer: float = 2.0


# NOVO:
#
# Como a queda agora dura mais por causa
# do teto de 1400, o escurecimento tambem
# demora mais.
@export_range(1.0, 15.0, 0.1)
var duracao_escurecimento: float = 8.5


# NOVO:
#
# Quanto maior, mais devagar fica o inicio
# do escurecimento e mais forte ele fica
# perto do fim.
@export_range(1.0, 3.0, 0.05)
var curva_escurecimento: float = 1.45


# Quase totalmente preto.
@export_range(0.5, 0.99, 0.01)
var escuridao_maxima: float = 0.96


# =====================================================
# ALINHAMENTO VISUAL
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
var inimigos_recompensados: Dictionary = {}
var brilho_verde_tempo: float = 0.0
var brilho_verde_material_original: Material = null
var brilho_verde_material: ShaderMaterial = null

# Emergency defense: 3x melee animation speed while an approaching
# hostile flying skull is present.
@export_group("Skull Defense")
@export var skull_defense_attack_speed: float = 3.0
@export var skull_defense_detection_range: float = 850.0
@export_range(0.0, 1.0, 0.05) var skull_defense_approach_dot: float = 0.55


# Menacing Skeleton bonuses are enabled ONLY during the boss encounter.
# The boss provides a count of collected artifacts on encounter start.
@export_group("Menacing Skeleton Artifact Buffs")
@export var miniboss_movement_buff_per_artifact: float = 0.07
@export var miniboss_attack_speed_buff_per_artifact: float = 0.12
@export var miniboss_protection_recharge: float = 15.0
var miniboss_buffs_active: bool = false
var miniboss_artifact_count: int = 0
var miniboss_protection_charges: int = 0
var miniboss_protection_timer: float = 0.0
@export var giant_artifact_required_count: int = 4
@export var giant_artifact_scale_multiplier: float = 1.25
@export var giant_artifact_power_multiplier: float = 2.0
@export var giant_artifact_move_multiplier: float = 1.45
@export var giant_artifact_jump_multiplier: float = 1.65
var giant_artifact_active: bool = false
var pre_giant_max_health: int = 3
var pre_giant_visual_scale: Vector2 = Vector2.ONE


func _activate_giant_artifact() -> void:
	if giant_artifact_active:
		return
	giant_artifact_active = true
	pre_giant_max_health = Global.vida_maxima
	pre_giant_visual_scale = scale
	scale = pre_giant_visual_scale * giant_artifact_scale_multiplier
	Global.vida_maxima = pre_giant_max_health * 2
	Global.vida_atual = mini(Global.vida_maxima, Global.vida_atual * 2)
	vida_maxima = Global.vida_maxima
	vida = Global.vida_atual
	Global.vida_alterada.emit(Global.vida_atual)
	vida_alterada.emit(vida, vida_maxima)


func _deactivate_giant_artifact() -> void:
	if not giant_artifact_active:
		return
	giant_artifact_active = false
	scale = pre_giant_visual_scale
	Global.vida_maxima = maxi(1, pre_giant_max_health)
	Global.vida_atual = clampi(ceili(float(Global.vida_atual) / 2.0), 0, Global.vida_maxima)
	vida_maxima = Global.vida_maxima
	vida = Global.vida_atual
	Global.vida_alterada.emit(Global.vida_atual)
	vida_alterada.emit(vida, vida_maxima)


func _giant_jump_multiplier() -> float:
	return giant_artifact_jump_multiplier if giant_artifact_active else 1.0


func _giant_damage_multiplier() -> int:
	return 2 if giant_artifact_active else 1


func begin_menacing_skeleton_fight(artifact_count: int) -> void:
	miniboss_buffs_active = true
	miniboss_artifact_count = clampi(artifact_count, 0, 4)
	# Third collected artifact: regenerating one-hit protection.
	miniboss_protection_charges = 1 if miniboss_artifact_count >= 3 else 0
	miniboss_protection_timer = 0.0
	if miniboss_artifact_count >= giant_artifact_required_count:
		_activate_giant_artifact()

func end_menacing_skeleton_fight() -> void:
	_deactivate_giant_artifact()
	miniboss_buffs_active = false
	miniboss_artifact_count = 0
	miniboss_protection_charges = 0
	miniboss_protection_timer = 0.0

func _miniboss_attack_multiplier() -> float:
	if giant_artifact_active:
		return giant_artifact_power_multiplier
	if not miniboss_buffs_active or miniboss_artifact_count < 2:
		return 1.0
	return 1.0 + miniboss_attack_speed_buff_per_artifact * float(miniboss_artifact_count - 1)

func _miniboss_move_multiplier() -> float:
	if giant_artifact_active:
		return giant_artifact_move_multiplier
	if not miniboss_buffs_active or miniboss_artifact_count < 1:
		return 1.0
	return 1.0 + miniboss_movement_buff_per_artifact * float(miniboss_artifact_count)

func _tick_miniboss_protection(delta: float) -> void:
	if not miniboss_buffs_active or miniboss_artifact_count < 3:
		return
	if miniboss_protection_charges > 0:
		return
	miniboss_protection_timer -= delta
	if miniboss_protection_timer <= 0.0:
		miniboss_protection_charges = 1
		miniboss_protection_timer = 0.0


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

@onready var anim: AnimatedSprite2D = (
	$AnimatedSprite2D
)

@onready var colisao_player: CollisionShape2D = (
	$CollisionShape2D
)

@onready var attack_area_j: Area2D = (
	$AttackAreaJ
)

@onready var attack_area_k: Area2D = (
	$AttackAreaK
)


# =====================================================
# READY
# =====================================================

func _ready() -> void:
	add_to_group(
		"player"
	)


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
	_configurar_brilho_verde()


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
	_atualizar_brilho_verde(delta)
	_tick_miniboss_protection(delta)
	_atualizar_velocidade_defesa_cranio()


	# =================================================
	# BUFFER DE PULO
	# =================================================

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


	# =================================================
	# COYOTE TIME
	# =================================================

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


	# =================================================
	# GRAVIDADE
	# =================================================

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


		# =============================================
		# QUEDA PROFUNDA
		# =============================================

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


	# =================================================
	# INVULNERABILIDADE
	# =================================================

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


	# =================================================
	# MORTE
	# =================================================

	if estado == Estado.MORTO:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
			* delta
			* 3.0
		)


		move_and_slide()


		_atualizar_escuridao_queda()


		return


	# =================================================
	# FERIDO
	# =================================================

	if estado == Estado.FERIDO:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
			* delta
			* 3.0
		)


		move_and_slide()


		_atualizar_escuridao_queda()


		return


	# =================================================
	# PULO
	# =================================================

	if (
		tempo_buffer_restante > 0.0
		and tempo_coyote_restante > 0.0
	):
		velocity.y = forca_pulo * _giant_jump_multiplier()


		tempo_buffer_restante = 0.0

		tempo_coyote_restante = 0.0


	if (
		Input.is_action_just_released(
			"jump"
		)
		and velocity.y < 0.0
	):
		velocity.y *= corte_pulo


	# =================================================
	# MOVIMENTO
	# =================================================

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
			direcao * SPEED * _miniboss_move_multiplier(),
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


	# =================================================
	# ATAQUES
	# =================================================

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


	# =================================================
	# ACELERACAO
	# =================================================

	if (
		not queda_profunda_ativa
		and tempo_caindo
		>= tempo_antes_queda_profunda
	):
		queda_profunda_ativa = true


	# =================================================
	# ESCURECIMENTO
	# =================================================

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


	# =================================================
	# CURVA PROGRESSIVA
	#
	# A tela fica pouco mais escura no começo
	# e vai ganhando intensidade aos poucos.
	#
	# Com 1.45:
	#
	# 25% do tempo -> ~13%
	# 50% do tempo -> ~36%
	# 75% do tempo -> ~66%
	# 100%          -> 100%
	#
	# Isso evita aquele "de repente ficou preto".
	# =================================================

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
	_deactivate_giant_artifact()
	estado = Estado.NORMAL


	golpe_em_fila = -1


	atingidos_no_golpe.clear()
	inimigos_recompensados.clear()
	_finalizar_brilho_verde()

	velocity = Vector2.ZERO


	tempo_coyote_restante = 0.0


	tempo_buffer_restante = 0.0


	_resetar_queda_profunda()


	global_position = posicao_inicial


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

	_atualizar_velocidade_defesa_cranio()


func _existe_cranio_vindo_na_minha_direcao() -> bool:
	for cranio in get_tree().get_nodes_in_group(&"skeleton_skull"):
		if not cranio is Node2D or not is_instance_valid(cranio):
			continue
		if cranio.is_queued_for_deletion():
			continue
		# Aiming skulls and already reflected skulls do not activate it.
		if not bool(cranio.get_meta(&"skull_in_flight", false)):
			continue
		if bool(cranio.get_meta(&"skull_reflected", false)):
			continue
		var movimento: Vector2 = cranio.get_meta(&"skull_movement_direction", Vector2.ZERO)
		if movimento.length_squared() < 0.001:
			continue
		var ate_jogador: Vector2 = global_position - cranio.global_position
		if ate_jogador.length_squared() > skull_defense_detection_range * skull_defense_detection_range:
			continue
		if ate_jogador.length_squared() < 0.001:
			return true
		if movimento.normalized().dot(ate_jogador.normalized()) >= skull_defense_approach_dot:
			return true
	return false


func _atualizar_velocidade_defesa_cranio() -> void:
	if estado != Estado.ATAQUE:
		if not is_equal_approx(anim.speed_scale, 1.0):
			anim.speed_scale = 1.0
		return
	if anim.animation != &"attack_quick" and anim.animation != &"attack_heavy":
		return
	var skull_multiplier: float = skull_defense_attack_speed if _existe_cranio_vindo_na_minha_direcao() else 1.0
	anim.speed_scale = skull_multiplier * _miniboss_attack_multiplier()


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

	dano *= _giant_damage_multiplier()

	if not ativo:
		return


	_verificar_reflexao_cranios(area, golpe_atual == TipoGolpe.FORTE)

	# Menacing Skeleton may not share the collision mask used by regular
	# enemies. Use the player's existing AttackAreaJ/K shapes against its
	# existing BODY collision shape, without adding fake damage zones.
	_verificar_acertos_miniboss(area, dano)

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

			if _inimigo_morreu(corpo):
				on_enemy_killed(corpo)


func _verificar_acertos_miniboss(area: Area2D, dano: int) -> void:
	for boss_node in get_tree().get_nodes_in_group(&"menacing_skeleton"):
		if not boss_node is CharacterBody2D or not is_instance_valid(boss_node):
			continue
		if atingidos_no_golpe.has(boss_node):
			continue
		if boss_node.has_method(&"is_dead") and bool(boss_node.call(&"is_dead")):
			continue
		var corpo_shape: CollisionShape2D = boss_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if corpo_shape == null or corpo_shape.disabled or corpo_shape.shape == null:
			continue
		var acertou: bool = false
		for shape_node in area.find_children("*", "CollisionShape2D", true, false):
			if not shape_node is CollisionShape2D:
				continue
			var ataque_shape: CollisionShape2D = shape_node as CollisionShape2D
			if ataque_shape.disabled or ataque_shape.shape == null:
				continue
			if ataque_shape.shape.collide(
				ataque_shape.global_transform,
				corpo_shape.shape,
				corpo_shape.global_transform
			):
				acertou = true
				break
		if acertou and boss_node.has_method(&"tomar_dano"):
			atingidos_no_golpe.append(boss_node)
			boss_node.call(&"tomar_dano", dano, global_position)
			# The miniboss calls on_enemy_killed on its own death.


# =====================================================
# SKULL REFLECTION + HEAL ON KILL
# =====================================================
func _verificar_reflexao_cranios(area: Area2D, forte: bool) -> void:
	# The Skull Area2D has collision_layer=0, so overlapping_areas() alone
	# cannot find it. Check actual CollisionShape2D geometry instead.
	for cranio in get_tree().get_nodes_in_group(&"skeleton_skull"):
		if not cranio is Node2D or not is_instance_valid(cranio):
			continue
		if cranio.is_queued_for_deletion():
			continue
		var origem: Variant = cranio.get_meta(&"skeleton_owner", null)
		if not origem is Node2D or not is_instance_valid(origem):
			continue
		var encontrou: bool = false
		for area_shape in area.find_children("*", "CollisionShape2D", true, false):
			if not area_shape is CollisionShape2D or area_shape.disabled or area_shape.shape == null:
				continue
			for skull_shape in cranio.find_children("*", "CollisionShape2D", true, false):
				if not skull_shape is CollisionShape2D or skull_shape.disabled or skull_shape.shape == null:
					continue
				if area_shape.shape.collide(area_shape.global_transform, skull_shape.shape, skull_shape.global_transform):
					encontrou = true
					break
			if encontrou:
				break
		if encontrou and origem.has_method(&"reflect_skull"):
			origem.call(&"reflect_skull", cranio, forte, self)

func _inimigo_morreu(corpo: Node) -> bool:
	if not is_instance_valid(corpo):
		return false
	if corpo.is_queued_for_deletion():
		return true
	for campo in ["dead", "is_dead", "morto"]:
		for dado in corpo.get_property_list():
			if String(dado["name"]) == campo and bool(corpo.get(campo)):
				return true
	for campo in ["hp", "vida", "current_health", "vida_atual"]:
		for dado in corpo.get_property_list():
			if String(dado["name"]) == campo:
				return int(corpo.get(campo)) <= 0
	return false

func on_enemy_killed(corpo: Node) -> void:
	if not is_instance_valid(corpo):
		return
	var id: int = corpo.get_instance_id()
	if inimigos_recompensados.has(id):
		return
	inimigos_recompensados[id] = true
	# Use the Global heal method so its vida_alterada signal refreshes the HUD.
	Global.curar(1)
	vida = Global.vida_atual
	vida_alterada.emit(vida, vida_maxima)
	_iniciar_brilho_verde()

func _configurar_brilho_verde() -> void:
	brilho_verde_material_original = anim.material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float glow_strength = 0.0;
void fragment() {
    vec4 tex = texture(TEXTURE, UV) * COLOR;
    float gradient = 0.45 + 0.55 * (1.0 - UV.y);
    vec3 green = mix(vec3(0.14, 0.95, 0.25), vec3(0.65, 1.0, 0.42), UV.x);
    tex.rgb = mix(tex.rgb, green * tex.a, clamp(glow_strength * gradient, 0.0, 1.0));
    COLOR = tex;
}
"""
	brilho_verde_material = ShaderMaterial.new()
	brilho_verde_material.shader = shader

func _iniciar_brilho_verde() -> void:
	brilho_verde_tempo = 0.45
	anim.material = brilho_verde_material

func _atualizar_brilho_verde(delta: float) -> void:
	if brilho_verde_tempo <= 0.0:
		return
	brilho_verde_tempo = maxf(0.0, brilho_verde_tempo - delta)
	if brilho_verde_tempo <= 0.0:
		_finalizar_brilho_verde()
	else:
		brilho_verde_material.set_shader_parameter("glow_strength", minf(1.0, brilho_verde_tempo * 4.0))

func _finalizar_brilho_verde() -> void:
	brilho_verde_tempo = 0.0
	if is_instance_valid(anim):
		anim.material = brilho_verde_material_original

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

	# A third artifact grants one shield hit every recharge interval.
	if miniboss_buffs_active and miniboss_artifact_count >= 3 and miniboss_protection_charges > 0:
		miniboss_protection_charges = 0
		miniboss_protection_timer = miniboss_protection_recharge
		tempo_invulneravel_restante = maxf(tempo_invulneravel_restante, 0.30)
		_iniciar_brilho_verde()
		return

	tempo_invulneravel_restante = (
		tempo_invulneravel
	)
	if miniboss_buffs_active and miniboss_artifact_count >= 4:
		tempo_invulneravel_restante += 0.24

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
	anim.speed_scale = 1.0


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
	anim.speed_scale = 1.0


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
				anim.animation == &"attack_quick"
				or anim.animation == &"attack_heavy"
			):
				estado = Estado.NORMAL
				anim.speed_scale = 1.0


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
