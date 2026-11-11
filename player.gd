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


@export_group("Artifact Abilities")
@export var dash_speed: float = 420.0
@export var dash_duration: float = 0.16
@export var slide_speed: float = 290.0
@export var slide_duration: float = 0.30
@export var wall_cling_fall_speed: float = 35.0
@export var wall_jump_speed: float = 225.0

var dash_remaining: float = 0.0
var dash_direction: float = 1.0
var dash_used: bool = false
var slide_remaining: float = 0.0
var slide_direction: float = 1.0
var standing_shape: RectangleShape2D
var standing_position: Vector2
var wall_jump_lock: float = 0.0


func _register_ability_key(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _update_artifact_movement(delta: float) -> bool:
	if estado != Estado.NORMAL:
		dash_remaining = 0.0
		slide_remaining = 0.0
		_try_stand()
		return false

	var direction := Input.get_axis(&"left", &"right")
	if is_on_floor() and dash_remaining <= 0.0:
		dash_used = false

	if standing_shape != null:
		if slide_remaining > 0.0 and is_on_floor():
			slide_remaining = maxf(0.0, slide_remaining - delta)
			velocity.x = slide_direction * slide_speed
		elif not _try_stand():
			velocity.x = direction * SPEED * 0.45
		if standing_shape != null:
			tempo_buffer_restante = 0.0
			_tocar(&"slide")
			move_and_slide()
			return true

	if dash_remaining <= 0.0 and not dash_used and Input.is_action_just_pressed(&"dash") and GerenciadorArtefatos.possui_artefato("escaravelho"):
		dash_direction = signf(direction) if absf(direction) > 0.01 else (1.0 if olhando_direita else -1.0)
		_virar(dash_direction)
		dash_remaining = dash_duration
		dash_used = true
	if dash_remaining > 0.0:
		velocity = Vector2(dash_direction * dash_speed, 0.0)
		dash_remaining = maxf(0.0, dash_remaining - delta)
		tempo_buffer_restante = 0.0
		_tocar(&"dash")
		move_and_slide()
		if is_on_wall():
			dash_remaining = 0.0
		return true

	if is_on_floor() and absf(direction) > 0.01 and Input.is_action_just_pressed(&"slide") and GerenciadorArtefatos.possui_artefato("ankh"):
		_begin_slide(signf(direction))
		if standing_shape != null:
			velocity.x = slide_direction * slide_speed
			tempo_buffer_restante = 0.0
			_tocar(&"slide")
			move_and_slide()
			return true

	wall_jump_lock = maxf(0.0, wall_jump_lock - delta)
	if wall_jump_lock > 0.0 and not is_on_floor():
		move_and_slide()
		_atualizar_animacao_movimento(direction)
		return true
	if not is_on_floor() and is_on_wall_only() and velocity.y >= 0.0 and GerenciadorArtefatos.possui_artefato("calice"):
		var normal := get_wall_normal()
		if direction * normal.x < -0.01:
			if tempo_buffer_restante > 0.0:
				velocity = Vector2(signf(normal.x) * wall_jump_speed, forca_pulo)
				_virar(velocity.x)
				tempo_buffer_restante = 0.0
				tempo_coyote_restante = 0.0
				wall_jump_lock = 0.10
				_tocar(&"jump")
			else:
				_virar(direction)
				velocity.x = direction * SPEED
				velocity.y = minf(velocity.y, wall_cling_fall_speed)
				_tocar(&"wallhang")
			move_and_slide()
			return true
	return false


func _begin_slide(direction: float) -> void:
	if not colisao_player.shape is RectangleShape2D:
		return
	standing_shape = colisao_player.shape as RectangleShape2D
	standing_position = colisao_player.position
	var low_shape := standing_shape.duplicate() as RectangleShape2D
	low_shape.size.y *= 0.55
	colisao_player.shape = low_shape
	colisao_player.position.y += (standing_shape.size.y - low_shape.size.y) * 0.5 * colisao_player.scale.y
	slide_remaining = slide_duration
	slide_direction = direction
	_virar(direction)


func _try_stand() -> bool:
	if standing_shape == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = standing_shape
	var standing_transform := global_transform * Transform2D(colisao_player.rotation, colisao_player.scale, colisao_player.skew, standing_position)
	standing_transform.origin -= Vector2(0.0, 0.1)
	query.transform = standing_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	_restore_standing_shape()
	return true


func _restore_standing_shape() -> void:
	if standing_shape != null:
		colisao_player.shape = standing_shape
		colisao_player.position = standing_position
		standing_shape = null



var menacing_fight_active: bool = false

# Animation-free boss parry: press F just before an authored sword hit.
@export_group("Menacing Skeleton Parry")
@export var miniboss_parry_window: float = 0.13
@export var miniboss_parry_cooldown: float = 1.50
@export var miniboss_parry_visual_seconds: float = 0.18
@export var miniboss_parry_success_recovery: float = 0.0
@export var miniboss_parry_hitstop_seconds: float = 0.010
var miniboss_parry_timer: float = 0.0
var miniboss_parry_cd: float = 0.0
var miniboss_parry_key_held: bool = false
var miniboss_parry_flash_tween: Tween = null
var miniboss_parry_hitstop_active: bool = false
var miniboss_parry_deadline_usec: int = 0
var miniboss_parry_armed: bool = false
var miniboss_parry_visual: AnimatedSprite2D = null
@export var miniboss_parry_counter_damage: int = 5
@export var miniboss_parry_counter_animation: StringName = &"parry"


func _update_menacing_parry(delta: float) -> void:
	miniboss_parry_cd = maxf(0.0, miniboss_parry_cd - delta)
	var now_usec: int = Time.get_ticks_usec()
	if miniboss_parry_armed and now_usec > miniboss_parry_deadline_usec:
		# Missed parry: 1.5s recovery. Successful parry: no cooldown.
		miniboss_parry_armed = false
		miniboss_parry_timer = 0.0
		miniboss_parry_cd = miniboss_parry_cooldown
	var key_down: bool = Input.is_physical_key_pressed(KEY_F)
	if (
		key_down and not miniboss_parry_key_held
		and menacing_fight_active
		and estado != Estado.MORTO and estado != Estado.FERIDO
		and miniboss_parry_cd <= 0.0
		and not miniboss_parry_armed
	):
		miniboss_parry_armed = true
		miniboss_parry_deadline_usec = now_usec + int(miniboss_parry_window * 1000000.0)
		miniboss_parry_timer = miniboss_parry_window
		# Telegraph that a parry has been pressed, using the player's real
		# authored 'parry' SpriteFrames in a separate overlay sprite.
		_play_menacing_parry_visual(false)
	miniboss_parry_key_held = key_down


func try_parry_menacing_hit(_attack_position: Vector2 = Vector2.ZERO) -> bool:
	if not menacing_fight_active or estado == Estado.MORTO:
		return false
	if not miniboss_parry_armed:
		return false
	if Time.get_ticks_usec() > miniboss_parry_deadline_usec:
		return false
	miniboss_parry_armed = false
	miniboss_parry_timer = 0.0
	miniboss_parry_cd = 0.0
	# Only enough iframes for the successful clash, not free invincibility.
	tempo_invulneravel_restante = maxf(tempo_invulneravel_restante, 0.045)
	_menacing_parry_hitstop()
	_play_menacing_parry_visual(true)
	_flash_menacing_parry(Color(0.75, 1.0, 1.0))
	_spawn_menacing_parry_ring()
	return true


func _play_menacing_parry_visual(perfect: bool) -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(miniboss_parry_counter_animation):
		return
	if miniboss_parry_visual == null or not is_instance_valid(miniboss_parry_visual):
		miniboss_parry_visual = AnimatedSprite2D.new()
		miniboss_parry_visual.name = "ParryEffect"
		miniboss_parry_visual.z_index = 25
		miniboss_parry_visual.sprite_frames = anim.sprite_frames
		add_child(miniboss_parry_visual)
	miniboss_parry_visual.stop()
	miniboss_parry_visual.animation = miniboss_parry_counter_animation
	miniboss_parry_visual.frame = 0
	miniboss_parry_visual.frame_progress = 0.0
	miniboss_parry_visual.position = anim.position
	miniboss_parry_visual.scale = anim.scale
	miniboss_parry_visual.flip_h = anim.flip_h
	miniboss_parry_visual.modulate = Color(0.55, 1.0, 1.0) if perfect else Color(1.0, 1.0, 1.0, 0.65)
	miniboss_parry_visual.speed_scale = 1.35 if perfect else 1.0
	miniboss_parry_visual.visible = true
	miniboss_parry_visual.play()
	# Keep the normal player animation and hitboxes available; parry VFX
	# does not hijack the AnimatedSprite2D state machine.
	var show_time: float = 0.28 if perfect else 0.15
	var counter_sprite: AnimatedSprite2D = miniboss_parry_visual
	get_tree().create_timer(show_time).timeout.connect(
		func() -> void:
			if is_instance_valid(counter_sprite):
				counter_sprite.visible = false
	)


func _menacing_parry_hitstop() -> void:
	if miniboss_parry_hitstop_active:
		return
	miniboss_parry_hitstop_active = true
	# Micro hit-stop using unscaled time: only 10 milliseconds in real time.
	# Keep time_scale above zero so timers and physics continue normally.
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 0.05
	_restore_menacing_parry_time(previous_scale)


func _restore_menacing_parry_time(previous_scale: float) -> void:
	await get_tree().create_timer(
		miniboss_parry_hitstop_seconds, true, false, true
	).timeout
	Engine.time_scale = previous_scale
	miniboss_parry_hitstop_active = false


func _flash_menacing_parry(color: Color) -> void:
	if miniboss_parry_flash_tween != null and miniboss_parry_flash_tween.is_running():
		miniboss_parry_flash_tween.kill()
	anim.self_modulate = color
	miniboss_parry_flash_tween = create_tween()
	miniboss_parry_flash_tween.tween_property(
		anim, "self_modulate", Color.WHITE, miniboss_parry_visual_seconds
	)


func _spawn_menacing_parry_ring() -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.37, 0.96, 1.0, 0.85)
	ring.closed = true
	ring.z_index = 50
	for i in range(20):
		var theta: float = TAU * float(i) / 20.0
		ring.add_point(Vector2.RIGHT.rotated(theta) * 22.0)
	add_child(ring)
	ring.position = Vector2(0.0, -12.0)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ring.queue_free)

func begin_menacing_skeleton_fight(_artifact_count: int = 0) -> void:
	menacing_fight_active = true


func end_menacing_skeleton_fight() -> void:
	menacing_fight_active = false
	miniboss_parry_timer = 0.0
	miniboss_parry_cd = 0.0
	miniboss_parry_armed = false
	if is_instance_valid(miniboss_parry_visual):
		miniboss_parry_visual.visible = false

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

@onready var shared_attack_area := get_node_or_null("AttackArea") as Area2D
@onready var shared_attack_position: Vector2 = shared_attack_area.position if shared_attack_area != null else Vector2.ZERO
@onready var attack_area_j: Area2D = get_node_or_null("AttackAreaJ") as Area2D
@onready var attack_area_k: Area2D = get_node_or_null("AttackAreaK") as Area2D

# =====================================================
# READY
# =====================================================

func _ready() -> void:
	_register_ability_key(&"dash", KEY_Q)
	_register_ability_key(&"slide", KEY_C)
	if attack_area_j == null:
		attack_area_j = shared_attack_area
	if attack_area_k == null:
		attack_area_k = shared_attack_area
	_prepare_action_animations()
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
	_update_menacing_parry(delta)
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
		_update_artifact_movement(delta)
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
		_update_artifact_movement(delta)
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

	if _update_artifact_movement(delta):
		_atualizar_escuridao_queda()
		return

	if tempo_buffer_restante > 0.0:
		if tempo_coyote_restante > 0.0:
			# First jump: original coyote-time jump.
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
	dash_remaining = 0.0
	dash_used = false
	slide_remaining = 0.0
	wall_jump_lock = 0.0
	_restore_standing_shape()
	miniboss_parry_armed = false
	miniboss_parry_cd = 0.0
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
	if shared_attack_area != null and attack_area_j == shared_attack_area and attack_area_k == shared_attack_area:
		shared_attack_area.position.x = shared_attack_position.x * (1.0 if olhando_direita else -1.0)
		shared_attack_area.scale.x = absf(shared_attack_area.scale.x) * (1.0 if olhando_direita else -1.0)
		return
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


func _action_animation(preferred: StringName, fallback: StringName) -> StringName:
	return preferred if anim.sprite_frames.has_animation(preferred) else fallback


func _prepare_action_animations() -> void:
	anim.sprite_frames = anim.sprite_frames.duplicate() as SpriteFrames
	var names: Array[StringName] = [
		_action_animation(&"attack_quick", &"attack1"),
		_action_animation(&"attack_heavy", &"attack2"),
		_action_animation(&"hurt", &"damagetaken"),
		_action_animation(&"death", &"damagetaken"),
	]
	for animation in names:
		if anim.sprite_frames.has_animation(animation):
			anim.sprite_frames.set_animation_loop(animation, false)

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
		and anim.frame >= mini(2, anim.sprite_frames.get_frame_count(anim.animation) - 1)
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
			_action_animation(&"attack_quick", &"attack1")
		)

	else:
		anim.play(
			_action_animation(&"attack_heavy", &"attack2")
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
	if anim.animation != _action_animation(&"attack_quick", &"attack1") and anim.animation != _action_animation(&"attack_heavy", &"attack2"):
		return
	var skull_multiplier: float = skull_defense_attack_speed if _existe_cranio_vindo_na_minha_direcao() else 1.0
	anim.speed_scale = skull_multiplier


func _verificar_acertos() -> void:
	var frame: int = anim.frame


	var ativo: bool = false


	var area: Area2D = attack_area_j


	var dano: int = dano_leve


	if golpe_atual == TipoGolpe.LEVE:
		ativo = (
			frame >= mini(2, anim.sprite_frames.get_frame_count(anim.animation) - 1)
			and frame <= 3
		)

	else:
		ativo = (
			frame >= mini(3, anim.sprite_frames.get_frame_count(anim.animation) - 1)
			and frame <= 5
		)


		area = attack_area_k


		dano = dano_forte


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
		_action_animation(&"hurt", &"damagetaken")
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
		_action_animation(&"death", &"damagetaken")
	)


# =====================================================
# FIM DAS ANIMACOES
# =====================================================

func _ao_terminar_animacao() -> void:
	match estado:
		Estado.ATAQUE:
			if (
				anim.animation == _action_animation(&"attack_quick", &"attack1")
				or anim.animation == _action_animation(&"attack_heavy", &"attack2")
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
			if anim.animation == _action_animation(&"hurt", &"damagetaken"):
				estado = Estado.NORMAL


		Estado.MORTO:
			if anim.animation == _action_animation(&"death", &"damagetaken"):
				Global.reiniciar_vida()


				get_tree().call_deferred(
					"reload_current_scene"
				)
