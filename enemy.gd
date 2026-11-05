extends CharacterBody2D

# COBRA
#
# - Patrulha quando nao enxerga o player.
# - Durante patrulha NAO cai de plataformas.
# - Durante perseguicao PODE cair de plataformas.
# - Nao pula e nao sobe blocos.
# - Quando esta caindo perseguindo o player, continua usando RUN.
# - Quando morre, NAO atravessa o chao.
# - A animacao de morte acontece parada no lugar.

enum Estado {
	PARADO,
	PATRULHANDO,
	PERSEGUINDO,
	ATACANDO,
	FERIDO,
	MORTO
}


const GRAVITY: float = 980.0
const MAX_FALL_SPEED: float = 650.0


@export_group("Movimento")

@export_range(0.0, 300.0, 5.0)
var speed: float = 60.0

@export_range(15.0, 300.0, 5.0)
var distancia_patrulha: float = 100.0


@export_group("Combate")

@export_range(1, 20, 1)
var vida: int = 2

@export_range(1, 10, 1)
var dano: int = 1

@export_range(0.2, 5.0, 0.05)
var intervalo_dano: float = 1.1

@export_range(15.0, 70.0, 1.0)
var alcance_ataque: float = 29.0

@export_range(0, 10, 1)
var quadro_do_golpe: int = 2


@export_group("Perseguicao")

@export var perseguir_jogador: bool = true

@export_range(20.0, 200.0, 5.0)
var limite_player_acima: float = 65.0


@export_group("Patrulha")

@export_range(10.0, 60.0, 1.0)
var distancia_detector_borda: float = 22.0


var player: Node2D = null

var estado: Estado = Estado.PATRULHANDO

var posicao_inicial: Vector2

var direcao_patrulha: float = -1.0

var direcao_olhar: float = -1.0

var tempo_ate_atacar: float = 0.0

var ja_aplicou_golpe: bool = false

var morto: bool = false


# Guarda a mascara original para nao destruir
# a colisao com o cenario ao morrer.
var collision_layer_original: int
var collision_mask_original: int


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var detection_area: Area2D = $DetectionArea

@onready var floor_check: RayCast2D = $FloorCheck


func _ready() -> void:
	add_to_group("inimigo")

	remove_from_group("player")


	posicao_inicial = global_position


	collision_layer_original = collision_layer

	collision_mask_original = collision_mask


	estado = Estado.PATRULHANDO


	if not sprite.animation_finished.is_connected(
		_on_animated_sprite_2d_animation_finished
	):
		sprite.animation_finished.connect(
			_on_animated_sprite_2d_animation_finished
		)


	if not sprite.frame_changed.is_connected(
		_quando_trocar_quadro
	):
		sprite.frame_changed.connect(
			_quando_trocar_quadro
		)


	_animar_movimento()


func _physics_process(delta: float) -> void:
	# =================================================
	# MORTO
	#
	# Ainda processamos gravidade para garantir que,
	# caso tenha morrido no ar, ele caia ate o chao.
	#
	# MAS ele continua colidindo com o piso.
	# =================================================

	if estado == Estado.MORTO:
		_processar_morte(delta)
		return


	# =================================================
	# GRAVIDADE NORMAL
	# =================================================

	if not is_on_floor():
		velocity.y = minf(
			velocity.y
			+ GRAVITY * delta,
			MAX_FALL_SPEED
		)

	else:
		if velocity.y > 0.0:
			velocity.y = 0.0


	tempo_ate_atacar = maxf(
		tempo_ate_atacar - delta,
		0.0
	)


	# =================================================
	# ATACANDO / FERIDO
	# =================================================

	if (
		estado == Estado.ATACANDO
		or estado == Estado.FERIDO
	):
		if estado == Estado.ATACANDO:
			velocity.x = 0.0

		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				500.0 * delta
			)


		move_and_slide()

		return


	# =================================================
	# PLAYER VALIDO
	# =================================================

	var jogador_valido: bool = (
		perseguir_jogador
		and is_instance_valid(player)
		and player.is_in_group("player")
	)


	if jogador_valido:
		_processar_perseguicao()

	else:
		_processar_patrulha()


	move_and_slide()


	# =================================================
	# PAREDE
	# =================================================

	if (
		is_on_wall()
		and estado == Estado.PATRULHANDO
	):
		direcao_patrulha *= -1.0


		velocity.x = (
			direcao_patrulha
			* speed
		)


		_virar(
			direcao_patrulha
		)


func _processar_morte(delta: float) -> void:
	# Se morreu no ar, cai normalmente ate o piso.
	if not is_on_floor():
		velocity.y = minf(
			velocity.y
			+ GRAVITY * delta,
			MAX_FALL_SPEED
		)

	else:
		velocity.y = 0.0


	# Nao desliza horizontalmente depois de morrer.
	velocity.x = move_toward(
		velocity.x,
		0.0,
		800.0 * delta
	)


	move_and_slide()


func _processar_perseguicao() -> void:
	if not is_instance_valid(player):
		return


	var diferenca: Vector2 = (
		player.global_position
		- global_position
	)


	# =================================================
	# ATAQUE
	# =================================================

	if (
		absf(diferenca.y) <= 36.0
		and absf(diferenca.x) <= alcance_ataque
	):
		velocity.x = 0.0


		_virar(
			diferenca.x
		)


		if tempo_ate_atacar <= 0.0:
			_iniciar_ataque()

		else:
			estado = Estado.PARADO

			_animar_movimento()


		return


	# =================================================
	# PERSEGUICAO
	# =================================================

	estado = Estado.PERSEGUINDO


	var direcao: float = signf(
		diferenca.x
	)


	_virar(
		direcao
	)


	# Player abaixo ou aproximadamente na mesma altura:
	# cobra continua correndo e pode sair da plataforma.
	if diferenca.y >= -limite_player_acima:
		velocity.x = (
			direcao
			* speed
		)

	else:
		# Player muito acima:
		# cobra nao tenta escalar o bloco.
		velocity.x = 0.0


	# IMPORTANTE:
	#
	# Nenhum FloorCheck aqui.
	# Perseguindo = pode cair da plataforma.


	_animar_movimento()


func _processar_patrulha() -> void:
	estado = Estado.PATRULHANDO


	var distancia_do_inicio: float = (
		global_position.x
		- posicao_inicial.x
	)


	if distancia_do_inicio >= distancia_patrulha:
		direcao_patrulha = -1.0

	elif distancia_do_inicio <= -distancia_patrulha:
		direcao_patrulha = 1.0


	velocity.x = (
		direcao_patrulha
		* speed
	)


	_virar(
		direcao_patrulha
	)


	_evitar_borda_patrulha()


	_animar_movimento()


func _evitar_borda_patrulha() -> void:
	if not is_on_floor():
		return


	if direcao_patrulha == 0.0:
		return


	floor_check.position.x = (
		distancia_detector_borda
		* direcao_patrulha
	)


	floor_check.force_raycast_update()


	if not floor_check.is_colliding():
		velocity.x = 0.0


		direcao_patrulha *= -1.0


		_virar(
			direcao_patrulha
		)


func _virar(direcao: float) -> void:
	if direcao == 0.0:
		return


	direcao_olhar = direcao


	# Sprite original olha para a esquerda.
	sprite.flip_h = (
		direcao > 0.0
	)


func _tocar(nome: StringName) -> void:
	if not sprite.sprite_frames.has_animation(
		nome
	):
		return


	if (
		sprite.animation != nome
		or not sprite.is_playing()
	):
		sprite.play(
			nome
		)


func _animar_movimento() -> void:
	# =================================================
	# PERSEGUINDO NO AR
	#
	# Continua usando RUN mesmo durante a queda.
	# =================================================

	if estado == Estado.PERSEGUINDO:
		if sprite.sprite_frames.has_animation(
			"run"
		):
			_tocar(
				"run"
			)

		else:
			_tocar(
				"walk"
			)

		return


	# =================================================
	# MOVIMENTO NORMAL
	# =================================================

	if absf(velocity.x) > 0.5:
		if sprite.sprite_frames.has_animation(
			"run"
		):
			_tocar(
				"run"
			)

		else:
			_tocar(
				"walk"
			)

	else:
		_tocar(
			"idle"
		)


func _iniciar_ataque() -> void:
	if (
		estado == Estado.MORTO
		or estado == Estado.FERIDO
		or estado == Estado.ATACANDO
	):
		return


	estado = Estado.ATACANDO


	velocity.x = 0.0


	ja_aplicou_golpe = false


	tempo_ate_atacar = (
		intervalo_dano
	)


	if sprite.sprite_frames.has_animation(
		"attack"
	):
		sprite.play(
			"attack"
		)


func _quando_trocar_quadro() -> void:
	if (
		estado != Estado.ATACANDO
		or sprite.animation != "attack"
		or ja_aplicou_golpe
	):
		return


	if sprite.frame < quadro_do_golpe:
		return


	ja_aplicou_golpe = true


	if not is_instance_valid(player):
		return


	if not player.has_method(
		"tomar_dano"
	):
		return


	var distancia: Vector2 = (
		player.global_position
		- global_position
	)


	if (
		absf(distancia.x)
		<= alcance_ataque + 8.0
		and absf(distancia.y) <= 36.0
	):
		player.tomar_dano(
			dano,
			global_position
		)


func _on_detection_area_body_entered(
	body: Node2D
) -> void:
	if body.is_in_group(
		"player"
	):
		player = body


func _on_detection_area_body_exited(
	body: Node2D
) -> void:
	if body != player:
		return


	player = null


	if estado != Estado.MORTO:
		estado = Estado.PATRULHANDO


		if direcao_olhar != 0.0:
			direcao_patrulha = direcao_olhar


func tomar_dano(
	quantidade: int,
	origem: Vector2 = Vector2.ZERO
) -> void:
	if (
		morto
		or quantidade <= 0
	):
		return


	vida = maxi(
		vida - quantidade,
		0
	)


	if vida == 0:
		morrer()

		return


	estado = Estado.FERIDO


	if origem != Vector2.ZERO:
		velocity.x = (
			90.0
			if global_position.x >= origem.x
			else -90.0
		)

	else:
		velocity.x = 0.0


	if sprite.sprite_frames.has_animation(
		"hurt"
	):
		sprite.play(
			"hurt"
		)

	else:
		estado = Estado.PATRULHANDO


func morrer() -> void:
	if morto:
		return


	morto = true


	estado = Estado.MORTO


	# Para o movimento horizontal.
	velocity.x = 0.0


	# =================================================
	# NAO ZERAMOS COLLISION_MASK
	#
	# Assim ele continua batendo no chao.
	# =================================================

	# Desliga deteccao do player.
	detection_area.set_deferred(
		"monitoring",
		false
	)


	# Caso esteja no chao, garante que nao tenha
	# velocidade vertical residual.
	if is_on_floor():
		velocity.y = 0.0


	if sprite.sprite_frames.has_animation(
		"death"
	):
		sprite.play(
			"death"
		)

	else:
		queue_free()


func _on_animated_sprite_2d_animation_finished() -> void:
	if (
		estado == Estado.MORTO
		and sprite.animation == "death"
	):
		queue_free()


	elif (
		estado == Estado.ATACANDO
		and sprite.animation == "attack"
	):
		if is_instance_valid(player):
			estado = Estado.PERSEGUINDO

		else:
			estado = Estado.PATRULHANDO


		_animar_movimento()


	elif (
		estado == Estado.FERIDO
		and sprite.animation == "hurt"
	):
		if is_instance_valid(player):
			estado = Estado.PERSEGUINDO

		else:
			estado = Estado.PATRULHANDO


		_animar_movimento()
