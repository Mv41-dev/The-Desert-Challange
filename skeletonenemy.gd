extends CharacterBody2D

# ============================================================
# SKELETON ENEMY V10
# Godot 4.x
#
# Attach to the ROOT CharacterBody2D.
#
# Expected scene:
#
# CharacterBody2D
# ├── AnimatedSprite2D
# ├── hitbox
# └── Area2D
#     ├── areattack2
#     ├── areattack
#     └── detectionarea
#
# IMPORTANT V9 CHANGE:
# - YOUR detectionarea decides when the skeleton is close enough
#   to stop chasing and prepare an attack.
# - He no longer runs into/through the player forever.
# - When the player first enters detectionarea:
#       stop
#       short pause
#       attack
# - attack2 has priority when ready.
# - while attack2 is cooling down, attack1 is used every 2 sec.
# - if both are cooling down, skeleton waits in place.
#
# ATTACK 1:
# - frame 6 = 1 damage
# - cooldown = 2 sec
#
# ATTACK 2:
# - frame 6 = 1 damage
# - frame 14 = 1 damage
# - cooldown = 5 sec
#
# HEALTH:
# - 4 HP
# ============================================================


# ============================================================
# NODES
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var attack_container: Area2D = $Area2D

@onready var attack_shape: CollisionShape2D = (
	$Area2D/areattack
)

@onready var attack2_shape: CollisionShape2D = (
	$Area2D/areattack2
)

@onready var attack_detection_shape: CollisionShape2D = (
	$Area2D/detectionarea
)


# ============================================================
# HEALTH
# ============================================================

@export_category("Health")

@export var max_hp: int = 4

var hp: int = 4
var dead: bool = false


# ============================================================
# PLAYER DETECTION
# ============================================================

@export_category("Player Detection")

@export var player_group: StringName = &"player"
@export var player_name_fallback: StringName = &"Player"

# Large awareness range.
@export var detection_radius: float = 430.0

@export_flags_2d_physics var detection_collision_mask: int = 1


# ============================================================
# MOVEMENT
# ============================================================

@export_category("Movement")

@export var move_speed: float = 92.0

@export var gravity: float = 980.0

@export var jump_velocity: float = -330.0

@export var max_fall_speed: float = 720.0


# ============================================================
# ATTACK PREPARE PAUSE
# ============================================================

@export_category("Attack Prepare")

# Short stop before committing to an attack after reaching range.
@export var attack_prepare_pause: float = 0.18

# If the player leaves detectionarea, the pause is cancelled.
var attack_prepare_timer: float = 0.0
var was_target_in_attack_range: bool = false


# ============================================================
# ONE-BLOCK JUMP
# ============================================================

@export_category("One Block Jump")

@export var obstacle_check_distance: float = 30.0

@export var obstacle_low_ray_y: float = -8.0

@export var obstacle_high_ray_y: float = -42.0

@export var obstacle_jump_cooldown: float = 0.22

@export_flags_2d_physics var terrain_collision_mask: int = 1


# ============================================================
# ANIMATIONS
# ============================================================

@export_category("Animations")

@export var idle_animation: StringName = &"idle"

@export var walk_animation: StringName = &"walk"

@export var attack_animation: StringName = &"attack"

@export var attack2_animation: StringName = &"attack2"


# ============================================================
# SPECIAL ATTACK
# ============================================================

func start_special_attack() -> bool:
	if special_attack_active:
		return false

	if attacking:
		return false

	if special_attack_cooldown_timer > 0.0:
		return false

	if not has_animation(
		attack2_animation
	):
		return false

	# Lock direction ONCE.
	# It will not change for the entire 3-second rush.
	if target != null:
		special_attack_direction = signf(
			target.global_position.x
			- global_position.x
		)

	if is_zero_approx(
		special_attack_direction
	):
		special_attack_direction = (
			1.0
			if sprite.flip_h
			else -1.0
		)

	special_attack_active = true
	special_attack_timer = maxf(
		0.01,
		special_attack_duration
	)

	special_attack_cooldown_timer = maxf(
		0.0,
		special_attack_cooldown
	)

	attacking = true
	current_attack = attack2_animation

	attack_damage_done = false
	attack2_first_damage_done = false
	attack2_second_damage_done = false

	# Freeze the visual + attack shapes in the chosen direction.
	var locked_right: bool = (
		special_attack_direction > 0.0
	)

	if sprite_faces_right_by_default:
		sprite.flip_h = not locked_right
	else:
		sprite.flip_h = locked_right

	update_attack_shape_facing(
		locked_right
	)

	start_special_attack2_cycle()

	return true


func update_special_attack(
	delta: float
) -> void:
	if not special_attack_active:
		return

	special_attack_timer = maxf(
		0.0,
		special_attack_timer - delta
	)

	# 25% faster than normal walking speed.
	velocity.x = (
		special_attack_direction
		* move_speed
		* special_speed_multiplier
	)

	# Gravity still works normally.
	# There is deliberately NO jump call here.
	# If he reaches a wall, move_and_slide blocks him and he keeps
	# pressing in the locked direction until the special ends.

	if special_attack_timer <= 0.0:
		finish_special_attack()


func start_special_attack2_cycle() -> void:
	if not special_attack_active:
		return

	attack2_first_damage_done = false
	attack2_second_damage_done = false

	sprite.stop()
	sprite.animation = attack2_animation
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play()


func restart_special_attack2_cycle() -> void:
	if not special_attack_active:
		return

	if special_attack_timer <= 0.0:
		finish_special_attack()
		return

	start_special_attack2_cycle()


func finish_special_attack() -> void:
	if not special_attack_active:
		return

	special_attack_active = false
	special_attack_timer = 0.0

	attacking = false
	current_attack = &""

	attack_damage_done = false
	attack2_first_damage_done = false
	attack2_second_damage_done = false

	velocity.x = 0.0

	# After a 3-second attack2 barrage, do not instantly throw
	# another normal attack2 on the very next frame.
	attack2_cooldown_timer = maxf(
		attack2_cooldown_timer,
		attack2_cooldown
	)

	# Force a fresh short approach/prepare pause after the rush.
	was_target_in_attack_range = false
	attack_prepare_timer = 0.0

	play_idle()


# ============================================================
# ATTACK 1
# ============================================================

@export_category("Attack 1")

@export var attack_damage_frame: int = 6

@export var attack_damage: int = 1

@export var attack_cooldown: float = 2.0

# Tiny forgiveness around your authored attack shape.
@export var attack1_damage_margin: float = 12.0


# ============================================================
# ATTACK 2
# ============================================================

@export_category("Attack 2")

@export var attack2_first_damage_frame: int = 6

@export var attack2_second_damage_frame: int = 14

@export var attack2_damage_per_hit: int = 1

@export var attack2_cooldown: float = 5.0

@export var attack2_damage_margin: float = 6.0


# ============================================================
# SPECIAL ATTACK
# ============================================================

@export_category("Special Attack")

# The rush lasts exactly 3 seconds.
@export var special_attack_duration: float = 3.0

# 0.25 faster than normal = 125% of move_speed.
@export var special_speed_multiplier: float = 1.25

# Separate cooldown so the special does not happen constantly.
# You can tune this freely in the Inspector.
@export var special_attack_cooldown: float = 10.0

# If true, the special has priority whenever it is ready and the
# player is inside detectionarea.
@export var special_attack_has_priority: bool = true


# ============================================================
# ATTACK SHAPE FACING
# ============================================================

@export_category("Attack Shape Facing")

# Your attack shapes appear authored toward the RIGHT.
@export var attack_shapes_authored_to_right: bool = true


# ============================================================
# FACING
# ============================================================

@export_category("Facing")

# Your skeleton sprite art faces LEFT by default.
@export var sprite_faces_right_by_default: bool = false


# ============================================================
# ATTACK QUERY
# ============================================================

@export_category("Attack Query")

@export var target_probe_padding: float = 4.0


# ============================================================
# RUNTIME
# ============================================================

var awareness_area: Area2D
var awareness_shape: CollisionShape2D

var obstacle_low_ray: RayCast2D
var obstacle_high_ray: RayCast2D

var target: Node2D = null

var attack_cooldown_timer: float = 0.0
var attack2_cooldown_timer: float = 0.0

var attacking: bool = false
var current_attack: StringName = &""

var attack_damage_done: bool = false
var attack2_first_damage_done: bool = false
var attack2_second_damage_done: bool = false

var special_attack_active: bool = false
var special_attack_timer: float = 0.0
var special_attack_cooldown_timer: float = 0.0
var special_attack_direction: float = 1.0

var obstacle_jump_timer: float = 0.0

var move_direction_x: float = 0.0

var attack_shape_base_position: Vector2
var attack2_shape_base_position: Vector2
var detection_shape_base_position: Vector2


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	hp = maxi(
		1,
		max_hp
	)

	dead = false

	special_attack_active = false
	special_attack_timer = 0.0
	special_attack_cooldown_timer = 0.0

	attack_shape_base_position = attack_shape.position
	attack2_shape_base_position = attack2_shape.position
	detection_shape_base_position = attack_detection_shape.position

	create_awareness_area()
	create_obstacle_rays()

	if not sprite.frame_changed.is_connected(
		_on_sprite_frame_changed
	):
		sprite.frame_changed.connect(
			_on_sprite_frame_changed
		)

	if not sprite.animation_finished.is_connected(
		_on_sprite_animation_finished
	):
		sprite.animation_finished.connect(
			_on_sprite_animation_finished
		)

	if not sprite.animation_looped.is_connected(
		_on_sprite_animation_looped
	):
		sprite.animation_looped.connect(
			_on_sprite_animation_looped
		)

	play_idle()


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return

	update_timers(
		delta
	)

	update_gravity(
		delta
	)

	validate_target()

	if target == null:
		find_player_fallback()

	# ========================================================
	# SPECIAL RUSH
	# ========================================================
	# During the special:
	# - direction is frozen
	# - no face_target() updates
	# - no obstacle jumping
	# - attack2 animation keeps cycling
	# - horizontal speed stays at 1.25x normal
	if special_attack_active:
		update_special_attack(
			delta
		)

		move_and_slide()
		return

	if target != null:
		face_target()

	if attacking:
		velocity.x = 0.0

	else:
		update_combat_and_movement(
			delta
		)

	update_movement_animation()

	move_and_slide()

func update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = maxf(
			0.0,
			attack_cooldown_timer - delta
		)

	if attack2_cooldown_timer > 0.0:
		attack2_cooldown_timer = maxf(
			0.0,
			attack2_cooldown_timer - delta
		)

	if special_attack_cooldown_timer > 0.0:
		special_attack_cooldown_timer = maxf(
			0.0,
			special_attack_cooldown_timer - delta
		)

	if obstacle_jump_timer > 0.0:
		obstacle_jump_timer = maxf(
			0.0,
			obstacle_jump_timer - delta
		)

func update_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0

		return

	velocity.y = minf(
		max_fall_speed,
		velocity.y + gravity * delta
	)


# ============================================================
# COMBAT + MOVEMENT
# ============================================================

func update_combat_and_movement(
	delta: float
) -> void:
	move_direction_x = 0.0

	if target == null:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			move_speed
		)

		attack_prepare_timer = 0.0
		was_target_in_attack_range = false

		return

	var in_attack_range: bool = (
		shape_reaches_target(
			attack_detection_shape,
			0.0
		)
	)

	# ========================================================
	# PLAYER IS INSIDE YOUR detectionarea
	# ========================================================

	if in_attack_range:
		velocity.x = 0.0

		# First frame entering range:
		# start the little pause.
		if not was_target_in_attack_range:
			was_target_in_attack_range = true
			attack_prepare_timer = maxf(
				0.0,
				attack_prepare_pause
			)

		if attack_prepare_timer > 0.0:
			attack_prepare_timer = maxf(
				0.0,
				attack_prepare_timer - delta
			)

			return

		# SPECIAL has priority when enabled and ready.
		if (
			special_attack_has_priority
			and special_attack_cooldown_timer <= 0.0
		):
			start_special_attack()
			return

		# Normal attack2 has priority whenever ready.
		if attack2_cooldown_timer <= 0.0:
			start_attack2()
			return

		# While attack2 cools down, attack1 fills the gap.
		if attack_cooldown_timer <= 0.0:
			start_attack()
			return

		# BOTH attacks are cooling down:
		# stand here instead of running into/through the player.
		return

	# ========================================================
	# PLAYER LEFT detectionarea
	# ========================================================

	was_target_in_attack_range = false
	attack_prepare_timer = 0.0

	# Keep chasing until detectionarea reaches them again.
	var delta_x: float = (
		target.global_position.x
		- global_position.x
	)

	move_direction_x = signf(
		delta_x
	)

	velocity.x = (
		move_direction_x
		* move_speed
	)

	update_obstacle_rays()

	try_jump_over_one_block()


# ============================================================
# WALK / IDLE
# ============================================================

func update_movement_animation() -> void:
	if attacking:
		return

	if absf(velocity.x) > 1.0:
		play_walk()

	else:
		play_idle()


func play_walk() -> void:
	if not has_animation(
		walk_animation
	):
		return

	if (
		sprite.animation == walk_animation
		and sprite.is_playing()
	):
		return

	sprite.play(
		walk_animation
	)


func play_idle() -> void:
	if not has_animation(
		idle_animation
	):
		return

	if (
		sprite.animation == idle_animation
		and sprite.is_playing()
	):
		return

	sprite.play(
		idle_animation
	)


# ============================================================
# GENERATED LARGE AWARENESS AREA
# ============================================================

func create_awareness_area() -> void:
	awareness_area = Area2D.new()
	awareness_area.name = "GeneratedAwarenessArea"

	awareness_area.collision_layer = 0
	awareness_area.collision_mask = detection_collision_mask
	awareness_area.monitoring = true
	awareness_area.monitorable = false

	add_child(
		awareness_area
	)

	awareness_shape = CollisionShape2D.new()
	awareness_shape.name = "GeneratedAwarenessShape"

	var circle := CircleShape2D.new()

	circle.radius = maxf(
		16.0,
		detection_radius
	)

	awareness_shape.shape = circle

	awareness_area.add_child(
		awareness_shape
	)

	awareness_area.body_entered.connect(
		_on_awareness_body_entered
	)

	awareness_area.body_exited.connect(
		_on_awareness_body_exited
	)

	awareness_area.area_entered.connect(
		_on_awareness_area_entered
	)

	awareness_area.area_exited.connect(
		_on_awareness_area_exited
	)


# ============================================================
# GENERATED OBSTACLE RAYS
# ============================================================

func create_obstacle_rays() -> void:
	obstacle_low_ray = RayCast2D.new()
	obstacle_low_ray.name = "GeneratedObstacleLowRay"

	obstacle_low_ray.enabled = true
	obstacle_low_ray.exclude_parent = true

	obstacle_low_ray.collision_mask = terrain_collision_mask

	obstacle_low_ray.collide_with_bodies = true
	obstacle_low_ray.collide_with_areas = false

	obstacle_low_ray.position = Vector2(
		0.0,
		obstacle_low_ray_y
	)

	add_child(
		obstacle_low_ray
	)

	obstacle_high_ray = RayCast2D.new()
	obstacle_high_ray.name = "GeneratedObstacleHighRay"

	obstacle_high_ray.enabled = true
	obstacle_high_ray.exclude_parent = true

	obstacle_high_ray.collision_mask = terrain_collision_mask

	obstacle_high_ray.collide_with_bodies = true
	obstacle_high_ray.collide_with_areas = false

	obstacle_high_ray.position = Vector2(
		0.0,
		obstacle_high_ray_y
	)

	add_child(
		obstacle_high_ray
	)

	update_obstacle_rays()


func update_obstacle_rays() -> void:
	if not is_instance_valid(
		obstacle_low_ray
	):
		return

	var direction: float = move_direction_x

	if is_zero_approx(
		direction
	):
		if target != null:
			direction = signf(
				target.global_position.x
				- global_position.x
			)

		else:
			direction = -1.0

	var ray_vector := Vector2(
		direction
			* obstacle_check_distance,
		0.0
	)

	obstacle_low_ray.target_position = ray_vector
	obstacle_high_ray.target_position = ray_vector

	obstacle_low_ray.clear_exceptions()
	obstacle_high_ray.clear_exceptions()

	if target is CollisionObject2D:
		obstacle_low_ray.add_exception(
			target as CollisionObject2D
		)

		obstacle_high_ray.add_exception(
			target as CollisionObject2D
		)

	obstacle_low_ray.force_raycast_update()
	obstacle_high_ray.force_raycast_update()


# ============================================================
# ONE-BLOCK JUMP
# ============================================================

func try_jump_over_one_block() -> void:
	if target == null:
		return

	if attacking:
		return

	if obstacle_jump_timer > 0.0:
		return

	if not is_on_floor():
		return

	if is_zero_approx(
		move_direction_x
	):
		return

	# NEVER jump while detectionarea already reaches the player.
	if shape_reaches_target(
		attack_detection_shape,
		0.0
	):
		return

	if not ray_hits_real_level_geometry(
		obstacle_low_ray
	):
		return

	# Both rays hitting means obstacle is too tall.
	if ray_hits_real_level_geometry(
		obstacle_high_ray
	):
		return

	velocity.y = jump_velocity

	obstacle_jump_timer = maxf(
		0.05,
		obstacle_jump_cooldown
	)


func ray_hits_real_level_geometry(
	ray: RayCast2D
) -> bool:
	if not is_instance_valid(
		ray
	):
		return false

	if not ray.is_colliding():
		return false

	var collider: Object = ray.get_collider()

	if collider == null:
		return false

	if collider is Node:
		var collider_node := collider as Node

		# Player is NOT a block.
		if get_player_from_node(
			collider_node
		) != null:
			return false

		# Other enemies / characters are NOT blocks.
		if collider_node is CharacterBody2D:
			return false

		# Trigger / hurtbox areas are NOT blocks.
		if collider_node is Area2D:
			return false

	return true


# ============================================================
# FACING
# ============================================================

func face_target() -> void:
	if target == null:
		return

	var target_is_right: bool = (
		target.global_position.x
		>= global_position.x
	)

	# Source art faces LEFT.
	if sprite_faces_right_by_default:
		sprite.flip_h = not target_is_right

	else:
		sprite.flip_h = target_is_right

	update_attack_shape_facing(
		target_is_right
	)


func update_attack_shape_facing(
	target_is_right: bool
) -> void:
	var direction_sign: float = (
		1.0
		if target_is_right
		else -1.0
	)

	if not attack_shapes_authored_to_right:
		direction_sign *= -1.0

	attack_shape.position = Vector2(
		absf(
			attack_shape_base_position.x
		) * direction_sign,
		attack_shape_base_position.y
	)

	attack2_shape.position = Vector2(
		absf(
			attack2_shape_base_position.x
		) * direction_sign,
		attack2_shape_base_position.y
	)

	attack_detection_shape.position = Vector2(
		absf(
			detection_shape_base_position.x
		) * direction_sign,
		detection_shape_base_position.y
	)


# ============================================================
# ATTACK 1
# ============================================================

func start_attack() -> bool:
	if attacking:
		return false

	if attack_cooldown_timer > 0.0:
		return false

	if not has_animation(
		attack_animation
	):
		return false

	attacking = true
	current_attack = attack_animation

	attack_damage_done = false

	attack_cooldown_timer = maxf(
		0.0,
		attack_cooldown
	)

	velocity.x = 0.0

	sprite.stop()

	sprite.animation = attack_animation
	sprite.frame = 0
	sprite.frame_progress = 0.0

	sprite.play()

	return true


# ============================================================
# ATTACK 2
# ============================================================

func start_attack2() -> bool:
	if attacking:
		return false

	if attack2_cooldown_timer > 0.0:
		return false

	if not has_animation(
		attack2_animation
	):
		return false

	attacking = true
	current_attack = attack2_animation

	attack2_first_damage_done = false
	attack2_second_damage_done = false

	attack2_cooldown_timer = maxf(
		0.0,
		attack2_cooldown
	)

	velocity.x = 0.0

	sprite.stop()

	sprite.animation = attack2_animation
	sprite.frame = 0
	sprite.frame_progress = 0.0

	sprite.play()

	return true


# ============================================================
# EXACT DAMAGE FRAMES
# ============================================================

func _on_sprite_frame_changed() -> void:
	if not attacking:
		return

	# ========================================================
	# ATTACK 1
	# ========================================================

	if current_attack == attack_animation:
		if (
			not attack_damage_done
			and sprite.frame
				== attack_damage_frame
		):
			attack_damage_done = true

			if shape_reaches_target(
				attack_shape,
				attack1_damage_margin
			):
				apply_damage(
					target,
					attack_damage
				)

		return

	# ========================================================
	# ATTACK 2
	# ========================================================

	if current_attack == attack2_animation:
		if (
			not attack2_first_damage_done
			and sprite.frame
				== attack2_first_damage_frame
		):
			attack2_first_damage_done = true

			if shape_reaches_target(
				attack2_shape,
				attack2_damage_margin
			):
				apply_damage(
					target,
					attack2_damage_per_hit
				)

		if (
			not attack2_second_damage_done
			and sprite.frame
				== attack2_second_damage_frame
		):
			attack2_second_damage_done = true

			if shape_reaches_target(
				attack2_shape,
				attack2_damage_margin
			):
				apply_damage(
					target,
					attack2_damage_per_hit
				)


# ============================================================
# SHAPE VS PLAYER
# ============================================================

func shape_reaches_target(
	shape_node: CollisionShape2D,
	margin: float = 0.0
) -> bool:
	if target == null:
		return false

	if not is_instance_valid(
		target
	):
		return false

	if not is_instance_valid(
		shape_node
	):
		return false

	if shape_node.shape == null:
		return false

	var probe_points: Array[Vector2] = (
		get_target_probe_points()
	)

	for point: Vector2 in probe_points:
		if point_inside_expanded_shape(
			shape_node,
			point,
			margin
		):
			return true

	return false


# ============================================================
# TARGET PROBE POINTS
# ============================================================

func get_target_probe_points() -> Array[Vector2]:
	var points: Array[Vector2] = []

	if target == null:
		return points

	# Root / center-ish guesses.
	points.append(
		target.global_position
	)

	points.append(
		target.global_position
			+ Vector2(
				0.0,
				-16.0
			)
	)

	points.append(
		target.global_position
			+ Vector2(
				0.0,
				-32.0
			)
	)

	points.append(
		target.global_position
			+ Vector2(
				0.0,
				-48.0
			)
	)

	# Actual Player CollisionShape2D samples.
	var collision_nodes: Array[Node] = (
		target.find_children(
			"*",
			"CollisionShape2D",
			true,
			false
		)
	)

	for node: Node in collision_nodes:
		if not (
			node is CollisionShape2D
		):
			continue

		var player_shape := (
			node as CollisionShape2D
		)

		if player_shape.disabled:
			continue

		append_collision_shape_probe_points(
			points,
			player_shape
		)

	return points


func append_collision_shape_probe_points(
	points: Array[Vector2],
	player_shape: CollisionShape2D
) -> void:
	points.append(
		player_shape.global_position
	)

	if player_shape.shape == null:
		return

	# --------------------------------------------------------
	# PLAYER RECTANGLE
	# --------------------------------------------------------

	if player_shape.shape is RectangleShape2D:
		var rectangle := (
			player_shape.shape
			as RectangleShape2D
		)

		var half_size: Vector2 = (
			rectangle.size
			* 0.5
		)

		append_local_probe_grid(
			points,
			player_shape,
			half_size.x,
			half_size.y
		)

		return

	# --------------------------------------------------------
	# PLAYER CAPSULE
	# --------------------------------------------------------

	if player_shape.shape is CapsuleShape2D:
		var capsule := (
			player_shape.shape
			as CapsuleShape2D
		)

		append_local_probe_grid(
			points,
			player_shape,
			capsule.radius,
			capsule.height * 0.5
		)

		return

	# --------------------------------------------------------
	# PLAYER CIRCLE
	# --------------------------------------------------------

	if player_shape.shape is CircleShape2D:
		var circle := (
			player_shape.shape
			as CircleShape2D
		)

		append_local_probe_grid(
			points,
			player_shape,
			circle.radius,
			circle.radius
		)


func append_local_probe_grid(
	points: Array[Vector2],
	player_shape: CollisionShape2D,
	half_width: float,
	half_height: float
) -> void:
	var padding: float = maxf(
		0.0,
		target_probe_padding
	)

	var x_value: float = maxf(
		0.0,
		half_width - padding
	)

	var y_value: float = maxf(
		0.0,
		half_height - padding
	)

	var local_points: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-x_value, 0.0),
		Vector2(x_value, 0.0),
		Vector2(0.0, -y_value),
		Vector2(0.0, y_value),
		Vector2(-x_value, -y_value),
		Vector2(x_value, -y_value),
		Vector2(-x_value, y_value),
		Vector2(x_value, y_value)
	]

	for local_point: Vector2 in local_points:
		points.append(
			player_shape.global_transform
			* local_point
		)


# ============================================================
# POINT INSIDE ATTACK SHAPE
# ============================================================

func point_inside_expanded_shape(
	shape_node: CollisionShape2D,
	world_point: Vector2,
	margin: float
) -> bool:
	var local_point: Vector2 = (
		shape_node.global_transform.affine_inverse()
		* world_point
	)

	var safe_margin: float = maxf(
		0.0,
		margin
	)

	# --------------------------------------------------------
	# RECTANGLE
	# --------------------------------------------------------

	if shape_node.shape is RectangleShape2D:
		var rectangle := (
			shape_node.shape
			as RectangleShape2D
		)

		var half_size: Vector2 = (
			rectangle.size
			* 0.5
		)

		return (
			absf(local_point.x)
				<= half_size.x + safe_margin
			and absf(local_point.y)
				<= half_size.y + safe_margin
		)

	# --------------------------------------------------------
	# CIRCLE
	# --------------------------------------------------------

	if shape_node.shape is CircleShape2D:
		var circle := (
			shape_node.shape
			as CircleShape2D
		)

		return (
			local_point.length()
			<= circle.radius + safe_margin
		)

	# --------------------------------------------------------
	# CAPSULE
	# --------------------------------------------------------

	if shape_node.shape is CapsuleShape2D:
		var capsule := (
			shape_node.shape
			as CapsuleShape2D
		)

		var half_width: float = (
			capsule.radius
			+ safe_margin
		)

		var half_height: float = (
			capsule.height * 0.5
			+ safe_margin
		)

		return (
			absf(local_point.x)
				<= half_width
			and absf(local_point.y)
				<= half_height
		)

	# Generic fallback.
	return (
		shape_node.global_position.distance_to(
			world_point
		)
		<= 56.0 + safe_margin
	)


# ============================================================
# DAMAGE PLAYER
# ============================================================

func apply_damage(
	damage_target: Node,
	damage_amount: int
) -> void:
	if damage_target == null:
		return

	if damage_target.has_method(
		&"take_damage"
	):
		damage_target.call(
			&"take_damage",
			damage_amount
		)

		return

	if damage_target.has_method(
		&"receive_damage"
	):
		damage_target.call(
			&"receive_damage",
			damage_amount
		)

		return

	if damage_target.has_method(
		&"damage"
	):
		damage_target.call(
			&"damage",
			damage_amount
		)

		return

	if damage_target.has_method(
		&"hurt"
	):
		damage_target.call(
			&"hurt",
			damage_amount
		)

		return

	if damage_target.has_method(
		&"levar_dano"
	):
		damage_target.call(
			&"levar_dano",
			damage_amount
		)

		return

	if damage_target.has_method(
		&"tomar_dano"
	):
		damage_target.call(
			&"tomar_dano",
			damage_amount
		)

		return

	push_warning(
		(
			"Skeleton reached Player with %d damage, "
			+ "but no compatible damage method was found."
		)
		% damage_amount
	)


# ============================================================
# ATTACK FINISH
# ============================================================

func _on_sprite_animation_finished() -> void:
	if special_attack_active:
		if sprite.animation == attack2_animation:
			restart_special_attack2_cycle()
		return

	if not attacking:
		return

	if sprite.animation != current_attack:
		return

	finish_current_attack()

func _on_sprite_animation_looped() -> void:
	if special_attack_active:
		if sprite.animation == attack2_animation:
			# Looping SpriteFrames do not restart from code automatically,
			# but the two damage gates must reset every loop.
			attack2_first_damage_done = false
			attack2_second_damage_done = false
		return

	if not attacking:
		return

	if sprite.animation != current_attack:
		return

	finish_current_attack()

func finish_current_attack() -> void:
	if special_attack_active:
		return

	attacking = false
	current_attack = &""

	attack_damage_done = false
	attack2_first_damage_done = false
	attack2_second_damage_done = false

	# If player is still inside detectionarea, do not force a new
	# approach pause. The cooldown logic will decide what comes next.
	if not shape_reaches_target(
		attack_detection_shape,
		0.0
	):
		was_target_in_attack_range = false
		attack_prepare_timer = 0.0

	play_idle()


# ============================================================
# AWARENESS CALLBACKS
# ============================================================

func _on_awareness_body_entered(
	body: Node2D
) -> void:
	var found_player: Node2D = (
		get_player_from_node(
			body
		)
	)

	if found_player != null:
		target = found_player


func _on_awareness_body_exited(
	body: Node2D
) -> void:
	if target == null:
		return

	var found_player: Node2D = (
		get_player_from_node(
			body
		)
	)

	if found_player == target:
		target = null


func _on_awareness_area_entered(
	area: Area2D
) -> void:
	var found_player: Node2D = (
		get_player_from_node(
			area
		)
	)

	if found_player != null:
		target = found_player


func _on_awareness_area_exited(
	area: Area2D
) -> void:
	if target == null:
		return

	var found_player: Node2D = (
		get_player_from_node(
			area
		)
	)

	if found_player == target:
		target = null


# ============================================================
# FIND PLAYER
# ============================================================

func get_player_from_node(
	start_node: Node
) -> Node2D:
	var current: Node = start_node

	for _index: int in range(8):
		if current == null:
			break

		if current is Node2D:
			if current.is_in_group(
				player_group
			):
				return current as Node2D

			if current.name == player_name_fallback:
				return current as Node2D

		current = current.get_parent()

	return null


func find_player_fallback() -> void:
	var closest_player: Node2D = null
	var closest_distance: float = INF

	var group_players: Array[Node] = (
		get_tree().get_nodes_in_group(
			player_group
		)
	)

	for candidate: Node in group_players:
		if not (
			candidate is Node2D
		):
			continue

		var player_candidate := (
			candidate as Node2D
		)

		var distance: float = (
			global_position.distance_to(
				player_candidate.global_position
			)
		)

		if distance > detection_radius:
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_player = player_candidate

	if closest_player != null:
		target = closest_player
		return

	var named_player: Node = (
		get_tree().root.find_child(
			String(
				player_name_fallback
			),
			true,
			false
		)
	)

	if named_player is Node2D:
		var named_player_2d := (
			named_player as Node2D
		)

		if (
			global_position.distance_to(
				named_player_2d.global_position
			)
			<= detection_radius
		):
			target = named_player_2d


func validate_target() -> void:
	if target == null:
		return

	if not is_instance_valid(
		target
	):
		target = null
		return

	if (
		global_position.distance_to(
			target.global_position
		)
		> detection_radius + 24.0
	):
		target = null


# ============================================================
# SKELETON HEALTH
# ============================================================

func receive_skeleton_damage(
	damage_amount: int
) -> void:
	if dead:
		return

	if damage_amount <= 0:
		return

	hp = maxi(
		0,
		hp - damage_amount
	)

	if hp <= 0:
		die()


func take_damage(
	damage_amount: int
) -> void:
	receive_skeleton_damage(
		damage_amount
	)


func receive_damage(
	damage_amount: int
) -> void:
	receive_skeleton_damage(
		damage_amount
	)


func hurt(
	damage_amount: int
) -> void:
	receive_skeleton_damage(
		damage_amount
	)


func levar_dano(
	damage_amount: int
) -> void:
	receive_skeleton_damage(
		damage_amount
	)


func tomar_dano(
	damage_amount: int
) -> void:
	receive_skeleton_damage(
		damage_amount
	)


func die() -> void:
	if dead:
		return

	dead = true

	special_attack_active = false
	special_attack_timer = 0.0

	attacking = false
	current_attack = &""

	velocity = Vector2.ZERO

	queue_free()


# ============================================================
# ANIMATION HELPER
# ============================================================

func has_animation(
	animation_name: StringName
) -> bool:
	if sprite == null:
		return false

	if sprite.sprite_frames == null:
		return false

	return sprite.sprite_frames.has_animation(
		animation_name
	)
