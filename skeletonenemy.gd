extends CharacterBody2D

enum Intent {
	ATTACK,
	SPACE,
	APPROACH,
	HOLD,
	SKULL
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_hitbox: CollisionShape2D = $hitbox

@onready var attack_area: Area2D = $Area2D
@onready var attack1_shape: CollisionShape2D = $Area2D/areattack
@onready var attack2_shape: CollisionShape2D = $Area2D/areattack2
@onready var detection_shape: CollisionShape2D = $Area2D/detectionarea

@onready var skull_template: Sprite2D = $Sprite2D
@onready var skull_template_shape: CollisionShape2D = $Sprite2D/CollisionShape2D

@export_category("Health")
@export var max_hp: int = 10

@export_category("Damage Reaction")
@export var damage_stun_duration: float = 0.75
@export var damage_flash_step: float = 0.055

@export_category("Player Detection")
@export var player_group: StringName = &"player"
@export var player_name_fallback: StringName = &"Player"
@export var detection_radius: float = 380.0
@export var player_attack_area_j_name: StringName = &"AttackAreaJ"
@export var player_attack_area_k_name: StringName = &"AttackAreaK"

@export_category("Movement")
@export var move_speed: float = 92.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -330.0
@export var max_fall_speed: float = 720.0

@export_category("One Block Jump")

@export var obstacle_check_distance: float = 14.0

@export var obstacle_low_probe_height: float = 7.0

@export var obstacle_max_jump_height: float = 44.0

@export var obstacle_top_clearance: float = 5.0

@export var obstacle_jump_cooldown: float = 0.22
@export_flags_2d_physics var terrain_collision_mask: int = 1

@export_category("High Platform Chase")

@export var high_jump_min_vertical_gap: float = 72.0

@export var high_jump_horizontal_trigger: float = 170.0
@export var high_jump_horizontal_speed: float = 118.0

@export var high_jump_velocity: float = -535.0
@export var high_jump_cooldown: float = 1.35

@export_flags_2d_physics var platform_pass_mask: int = 1

@export_category("Platform Guard")
@export var platform_guard_vertical_gap: float = 72.0
@export var same_level_tolerance: float = 52.0
@export var platform_guard_skull_cooldown: float = 2.5
@export_range(0.0, 1.0, 0.05) var engaged_below_skull_chance: float = 0.40

@export_category("Drop Chase")
@export var drop_chase_speed: float = 150.0
@export var drop_chase_jump_velocity: float = -245.0
@export var drop_chase_max_time: float = 2.4
@export var drop_edge_scan_step: float = 32.0
@export var drop_edge_scan_count: int = 5
@export var drop_chase_decision_cooldown: float = 6.5
@export_range(0.0, 1.0, 0.01) var drop_chase_chance: float = 0.28
@export var drop_chase_retry_delay: float = 1.3
@export var drop_chase_min_clearance: float = 66.0
@export var drop_chase_phase_check_distance: float = 440.0
# Only pass through platforms if they have a separate collision layer.
# With the default platform_pass_mask == terrain_collision_mask (both 1),
# Skeletons take the edge route instead of falling through solid TileMaps.
@export var allow_safe_platform_drop: bool = true

@export_category("Animations")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var attack2_animation: StringName = &"attack2"

@export_category("Attack Timing")
@export var attack_prepare_pause: float = 0.30
@export var melee_warning_flash_speed: float = 14.0
@export_range(0.1, 1.0, 0.05) var attack_first_three_frames_speed: float = 0.55
@export_range(1.0, 3.0, 0.05) var attack_after_frame_two_speed: float = 1.30
@export var melee_lunge_speed: float = 155.0
@export var melee_lunge_start_frame: int = 3
@export var melee_lunge_end_frame: int = 5
@export var combo_warning_pause: float = 0.24
@export_range(0.0, 1.0, 0.05) var combo_two_hit_chance: float = 0.48
@export_range(0.0, 1.0, 0.05) var combo_three_hit_chance: float = 0.18

@export_category("Attack 1")
@export var attack_damage_frame: int = 6
@export var attack_damage: int = 1
@export var attack_cooldown: float = 2.8

@export_category("Attack 2")
@export var attack2_first_damage_frame: int = 6
@export var attack2_second_damage_frame: int = 14
@export var attack2_damage_per_hit: int = 1
@export var attack2_cooldown: float = 5.8

@export_category("Rush Special")
@export var special_speed_multiplier: float = 1.50
@export var special_attack_cooldown: float = 11.0

@export_category("Skull Special")
@export var skull_attack_cooldown: float = 7.0

@export_category("Ground Pursuit Skull Pressure")
# Only applies after this Skeleton has seen the player on roughly its level.
# Remaining far away progressively makes it prefer skull volleys.
@export var pursuit_skull_start_distance: float = 260.0
@export var pursuit_skull_reset_distance: float = 210.0
@export var pursuit_skull_max_chase_distance: float = 850.0
@export var pursuit_skull_max_vertical_gap: float = 70.0
@export var pursuit_skull_ramp_seconds: float = 3.0
@export_range(0.0, 1.0, 0.01) var pursuit_skull_max_chance: float = 0.72
@export var pursuit_skull_start_cooldown: float = 9.0
@export var pursuit_skull_min_cooldown: float = 5.0
@export var skull_back_jump_speed: float = 205.0
@export var skull_back_jump_velocity: float = -355.0
@export var skull_back_jump_max_time: float = 0.95

@export var skull_speed: float = 330.0
@export var skull_aim_duration: float = 1.0
@export var skull_lifetime: float = 5.0
@export var skull_damage: int = 1

@export var skull_spawn_gap_min: float = 0.025
@export var skull_spawn_gap_max: float = 0.070
@export var skull_spawn_spacing: float = 44.0
@export var skull_spawn_min_y: float = -108.0
@export var skull_spawn_max_y: float = -58.0

@export var skull_pullback_min: float = 16.0
@export var skull_pullback_max: float = 30.0
@export var skull_curve_angle_min: float = 5.0
@export var skull_curve_angle_max: float = 15.0
@export var skull_curve_frequency_min: float = 2.3
@export var skull_curve_frequency_max: float = 4.8
@export_range(0.0, 1.0, 0.01) var skull_soft_lock_chance: float = 0.18
@export var skull_soft_lock_turn_speed: float = 28.0
@export var skull_soft_lock_max_angle: float = 18.0
@export var skull_soft_lock_duration: float = 1.0
@export var skull_soft_lock_curve_multiplier: float = 1.18
@export var skull_fallback_radius: float = 18.0

@export var skull_faces_right_by_default: bool = false
@export var skull_rotation_offset_degrees: float = 0.0
# Base skull artwork faces LEFT. Rotate 180 degrees first, then point to target.
# Override skull_rotation_offset_degrees if your sprite asset differs.

@export_category("Multiple Skeleton Skull Balance")
# Only used when 2+ living Skeletons are in this level.
@export var group_skull_cooldown: float = 2.5
@export var group_skull_extra_delay: float = 0.65
@export var group_skull_max_two: int = 4
@export var group_skull_max_three: int = 3
@export var group_skull_max_four_plus: int = 2


@export_category("Skulls From Above")
# These settings apply only when the player is substantially BELOW this Skeleton.
@export var overhead_skull_vertical_gap: float = 72.0
@export var overhead_skull_speed_multiplier: float = 0.56
@export var overhead_skull_max_per_volley: int = 3
# Independent real-time cooldown. Red phase cannot speed this up.
@export var overhead_skull_cooldown: float = 9.0
@export var overhead_skull_spacing: float = 100.0
@export var overhead_skull_spawn_gap_min: float = 0.15
@export var overhead_skull_spawn_gap_max: float = 0.23
@export var overhead_skull_curve_multiplier: float = 0.75
@export_range(0.0, 1.0, 0.01) var overhead_skull_soft_lock_chance: float = 0.05

const SKELETON_GROUP: StringName = &"skeleton_enemies"
const GROUP_SKULL_NEXT_TIME: StringName = &"skeleton_group_next_skull_time_ms"

@export_category("Low HP Enrage")
# 3-4 HP = orange, 1-2 HP = red. Both stages resist damage stun.
@export var enrage_orange_warning: Color = Color(1.0, 0.45, 0.08, 1.0)
@export var enrage_red_warning: Color = Color(1.0, 0.10, 0.10, 1.0)
@export var red_warning_duration: float = 0.44
@export var red_combo_warning_duration: float = 0.36
@export var red_move_speed_multiplier: float = 1.36
@export var red_attack_animation_multiplier: float = 1.60
@export var red_melee_lunge_multiplier: float = 1.20
@export var red_skull_chance: float = 0.34
@export var red_skull_cooldown_multiplier: float = 0.72
@export var red_skull_curve_multiplier: float = 1.12
@export var red_skull_speed_multiplier: float = 1.12
@export var red_skull_lock_chance: float = 0.34
@export var red_overhead_lock_chance: float = 0.09

@export var last_hp_attack_cooldown_multiplier: float = 0.54
@export var last_hp_decision_min_time: float = 0.20
@export var last_hp_decision_max_time: float = 0.40
@export var last_hp_post_attack_min_time: float = 0.10
@export var last_hp_post_attack_max_time: float = 0.24
@export var last_hp_chase_jump_min_height: float = 24.0
@export var last_hp_chase_jump_max_height: float = 72.0
@export var last_hp_chase_jump_max_horizontal: float = 155.0
@export var last_hp_chase_jump_cooldown: float = 1.65

@export_category("Combat Spacing")
@export var preferred_spacing_distance: float = 105.0
@export var spacing_tolerance: float = 14.0
@export_range(0.1, 1.0, 0.05) var spacing_speed_multiplier: float = 0.72

@export_category("Fair Combat AI")
@export var ai_decision_min_time: float = 0.48
@export var ai_decision_max_time: float = 0.95
@export_range(0.0, 1.0, 0.05) var ai_attack_intent_chance: float = 0.88
@export_range(0.0, 1.0, 0.05) var ai_skull_intent_chance: float = 0.16
@export var ai_approach_distance: float = 46.0

@export_category("Facing")
@export var sprite_faces_right_by_default: bool = false
@export var attack_shapes_authored_to_right: bool = true

@export_category("Death")
@export var death_pop_height: float = 14.0
@export var death_tilt_degrees: float = 22.0
@export var death_total_time: float = 0.58

var hp: int = 10
var target: Node2D

var dead := false
var attacking := false
var current_attack: StringName = &""
var rush_active := false
var rush_direction := 1.0

var attack1_cd := 0.0
var attack2_cd := 0.0
var rush_cd := 0.0
var skull_cd := 0.0
var obstacle_jump_cd := 0.0
var high_jump_cd := 0.0
var stun_timer := 0.0
var ai_timer := 0.0
var attack_prepare_timer := 0.0
var melee_warning_active := false
var melee_warning_timer := 0.0
var pending_melee_attack: StringName = &""
var warning_original_self_modulate := Color.WHITE
var melee_warning_duration := 0.30

var combo_active := false
var combo_total := 1
var combo_step := 0
var last_melee_attack: StringName = &""

var attack_hit_done := false
var attack2_hit1_done := false
var attack2_hit2_done := false

var intent: Intent = Intent.APPROACH

var facing_right := false
var attack1_base_pos: Vector2
var attack2_base_pos: Vector2
var detection_base_pos: Vector2

var skull_action_active := false
var skull_backjumping := false
var skull_action_time := 0.0
var skull_backjump_direction := 0.0
var pending_skulls: Array[Dictionary] = []
var active_skulls: Array[Dictionary] = []

var high_jump_active := false
var platform_collision_ignored := false
var base_collision_mask := 0

var platform_engaged := false
var player_collision_exception_set := false

var drop_chase_active := false
var drop_chase_direction := 0.0
var drop_chase_time := 0.0
var drop_chase_start_y := 0.0
var drop_chase_cd := 0.0
var drop_chase_phase_active := false
var drop_chase_left_start_floor := false

var flash_active := false
var flash_time := 0.0
var original_sprite_material: Material
var flash_material: ShaderMaterial

var damage_layer_synced := false
var overhead_skull_cd: float = 0.0
var pursuit_has_seen_player: bool = false
var pursuit_skull_pressure: float = 0.0

func _ready() -> void:
	hp = maxi(1, max_hp)
	base_collision_mask = collision_mask

	attack1_base_pos = attack1_shape.position
	attack2_base_pos = attack2_shape.position
	detection_base_pos = detection_shape.position

	body_hitbox.disabled = false
	skull_template.visible = false
	skull_template_shape.disabled = true

	add_to_group(&"inimigo")
	add_to_group(&"enemy")
	add_to_group(SKELETON_GROUP)

	_make_flash_material()

	if not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)

	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	if not sprite.animation_looped.is_connected(_on_sprite_animation_looped):
		sprite.animation_looped.connect(_on_sprite_animation_looped)

	_find_player()
	face_target()
	play_idle()

func _physics_process(delta: float) -> void:
	if dead:
		return

	_tick_timers(delta)
	_update_flash(delta)
	_update_pending_skulls(delta)
	_update_skulls(delta)
	_find_player()
	_update_pursuit_skull_pressure(delta)

	if target != null:
		if not damage_layer_synced:
			_sync_player_attack_layers()
		if not player_collision_exception_set:
			_set_player_collision_exception()

	_apply_gravity(delta)

	if stun_timer > 0.0:
		velocity.x = 0.0
		face_target()
		move_and_slide()
		return

	if drop_chase_active:
		_update_drop_chase(delta)
		move_and_slide()
		return

	if high_jump_active:
		_update_high_jump()
		move_and_slide()
		return

	if skull_action_active:
		_update_skull_action(delta)
		move_and_slide()
		return

	if rush_active:
		velocity.x = rush_direction * move_speed * special_speed_multiplier
		move_and_slide()
		return

	if melee_warning_active:
		_update_melee_warning(delta)
		move_and_slide()
		return

	if attacking:
		_update_melee_lunge()
		move_and_slide()
		return

	if not _player_in_chase_range():
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		play_idle()
		move_and_slide()
		return

	_update_platform_engagement()
	face_target()
	_update_ai(delta)
	_space_from_summoned_allies()
	_update_move_animation()
	if hp <= 2:
		velocity.x *= red_move_speed_multiplier
	move_and_slide()

func _space_from_summoned_allies() -> void:
	var owner_id := int(get_meta(&"necromancer_summon_owner", 0))
	if owner_id == 0 or not is_on_floor():
		return
	if attacking or melee_warning_active or skull_action_active or rush_active or high_jump_active or drop_chase_active:
		return
	var closest: Node2D
	var distance := 48.0
	for node in get_tree().get_nodes_in_group(SKELETON_GROUP):
		if node == self or not node is Node2D or int(node.get_meta(&"necromancer_summon_owner", 0)) != owner_id:
			continue
		var offset: Vector2 = node.global_position - global_position
		if absf(offset.y) <= 24.0 and absf(offset.x) < distance:
			closest = node
			distance = absf(offset.x)
	if closest == null:
		return
	var dx := global_position.x - closest.global_position.x
	var direction := signf(dx)
	if absf(dx) < 0.1:
		direction = -1.0 if get_instance_id() < closest.get_instance_id() else 1.0
	velocity.x = direction * maxf(25.0, move_speed * (1.0 - distance / 48.0))


func _tick_timers(delta: float) -> void:
	drop_chase_cd = maxf(0.0, drop_chase_cd - delta)
	overhead_skull_cd = maxf(0.0, overhead_skull_cd - delta)
	# Red phase accelerates melee, but still preserves existing shared limits.
	var melee_tick: float = delta
	if hp <= 2:
		melee_tick = delta / maxf(0.25, last_hp_attack_cooldown_multiplier)
	attack1_cd = maxf(0.0, attack1_cd - melee_tick)
	attack2_cd = maxf(0.0, attack2_cd - melee_tick)
	rush_cd = maxf(0.0, rush_cd - delta)
	skull_cd = maxf(0.0, skull_cd - delta / maxf(0.20, red_skull_cooldown_multiplier if hp <= 2 else 1.0))
	obstacle_jump_cd = maxf(0.0, obstacle_jump_cd - delta)
	high_jump_cd = maxf(0.0, high_jump_cd - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	ai_timer = maxf(0.0, ai_timer - delta)

func _find_player() -> void:
	if is_instance_valid(target):
		return

	target = null
	player_collision_exception_set = false

	var grouped := get_tree().get_first_node_in_group(player_group)
	if grouped is Node2D:
		target = grouped
		damage_layer_synced = false
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	var by_name := scene.find_child(String(player_name_fallback), true, false)
	if by_name is Node2D:
		target = by_name
		damage_layer_synced = false

func _set_player_collision_exception() -> void:
	if not (target is PhysicsBody2D):
		return

	var body := target as PhysicsBody2D
	add_collision_exception_with(body)
	body.add_collision_exception_with(self)
	player_collision_exception_set = true

func _vertical_delta_to_player() -> float:
	if not is_instance_valid(target):
		return 0.0
	return target.global_position.y - global_position.y

func _player_below_platform() -> bool:
	return (
		player_is_detected()
		and _vertical_delta_to_player() >= platform_guard_vertical_gap
	)

func _player_same_level() -> bool:
	return (
		player_is_detected()
		and absf(_vertical_delta_to_player()) <= same_level_tolerance
	)

func _update_platform_engagement() -> void:
	if not platform_engaged and _player_same_level():
		platform_engaged = true

func _platform_guard_active() -> bool:
	return (
		not platform_engaged
		and is_on_floor()
		and _player_below_platform()
	)

func _pursuit_same_level() -> bool:
	return (
		is_instance_valid(target)
		and absf(target.global_position.y - global_position.y) <= pursuit_skull_max_vertical_gap
	)

func _player_in_chase_range() -> bool:
	if player_is_detected():
		return true
	return (
		pursuit_has_seen_player
		and _pursuit_same_level()
		and global_position.distance_to(target.global_position) <= pursuit_skull_max_chase_distance
	)

func _update_pursuit_skull_pressure(delta: float) -> void:
	if not is_instance_valid(target):
		pursuit_has_seen_player = false
		pursuit_skull_pressure = 0.0
		return

	var distance: float = global_position.distance_to(target.global_position)

	# The original detection radius is what first establishes aggro.
	# A Skeleton above you cannot accumulate pursuit pressure.
	if player_is_detected() and _pursuit_same_level():
		pursuit_has_seen_player = true

	if not _pursuit_same_level() or distance > pursuit_skull_max_chase_distance:
		pursuit_skull_pressure = 0.0
		if distance > pursuit_skull_max_chase_distance:
			pursuit_has_seen_player = false
		return

	if not pursuit_has_seen_player:
		pursuit_skull_pressure = 0.0
		return

	if distance >= pursuit_skull_start_distance:
		# Standing far away OR continuing to retreat builds pressure.
		pursuit_skull_pressure = minf(
			1.0, pursuit_skull_pressure + delta / maxf(0.1, pursuit_skull_ramp_seconds)
		)
	elif distance <= pursuit_skull_reset_distance:
		pursuit_skull_pressure = maxf(0.0, pursuit_skull_pressure - delta * 1.5)

func _pursuit_skull_active() -> bool:
	return pursuit_has_seen_player and _pursuit_same_level() and pursuit_skull_pressure > 0.0

func player_is_detected() -> bool:
	return (
		is_instance_valid(target)
		and global_position.distance_to(target.global_position) <= detection_radius
	)

func player_is_above() -> bool:
	return (
		player_is_detected()
		and global_position.y - target.global_position.y >= high_jump_min_vertical_gap
	)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(max_fall_speed, velocity.y + gravity * delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _try_platform_chase() -> bool:
	if not player_is_above() or high_jump_cd > 0.0 or not is_on_floor():
		return false

	var dx: float = target.global_position.x - global_position.x

	if absf(dx) > high_jump_horizontal_trigger:
		velocity.x = signf(dx) * move_speed
		_try_small_obstacle_jump()
		return true

	_start_high_jump()
	return true

func _start_high_jump() -> void:
	high_jump_active = true
	high_jump_cd = high_jump_cooldown
	velocity.y = high_jump_velocity

	base_collision_mask = collision_mask
	# Never turn off solid terrain when platform and terrain share a layer.
	# Dedicated one-way platforms may still be passed through from below.
	platform_collision_ignored = (
		platform_pass_mask != 0
		and (platform_pass_mask & terrain_collision_mask) == 0
	)
	if platform_collision_ignored:
		collision_mask = base_collision_mask & ~platform_pass_mask

	play_walk()

func _update_high_jump() -> void:
	if not is_instance_valid(target):
		_finish_high_jump()
		return

	var dx: float = target.global_position.x - global_position.x
	velocity.x = 0.0 if absf(dx) < 12.0 else signf(dx) * high_jump_horizontal_speed
	face_target()

	if velocity.y >= 0.0 and platform_collision_ignored:
		collision_mask = base_collision_mask
		platform_collision_ignored = false

	if is_on_floor() and velocity.y >= 0.0:
		_finish_high_jump()

func _finish_high_jump() -> void:
	if platform_collision_ignored:
		collision_mask = base_collision_mask

	high_jump_active = false
	platform_collision_ignored = false
	velocity.x = 0.0
	ai_timer = randf_range(0.35, 0.70)

func _try_small_obstacle_jump() -> void:
	if (
		not is_on_floor()
		or obstacle_jump_cd > 0.0
		or is_zero_approx(velocity.x)
	):
		return

	var direction: float = signf(velocity.x)
	var half_extents: Vector2 = _body_half_extents()

	var body_center: Vector2 = body_hitbox.global_position
	var feet_y: float = body_center.y + half_extents.y

	var front_x: float = (
		body_center.x
		+ direction
		* (
			half_extents.x
			+ obstacle_check_distance
		)
	)

	var low_y: float = (
		feet_y
		- obstacle_low_probe_height
	)

	var low_from := Vector2(
		body_center.x,
		low_y
	)

	var low_to := Vector2(
		front_x,
		low_y
	)

	if not _terrain_ray(
		low_from,
		low_to
	):
		return

	var top_test_y: float = (
		feet_y
		- obstacle_max_jump_height
		- obstacle_top_clearance
	)

	var top_from := Vector2(
		body_center.x,
		top_test_y
	)

	var top_to := Vector2(
		front_x,
		top_test_y
	)

	if _terrain_ray(
		top_from,
		top_to
	):
		return

	var middle_test_y: float = (
		feet_y
		- obstacle_max_jump_height
		* 0.62
	)

	var middle_from := Vector2(
		body_center.x,
		middle_test_y
	)

	var middle_to := Vector2(
		front_x,
		middle_test_y
	)

	_terrain_ray(
		middle_from,
		middle_to
	)

	velocity.y = jump_velocity
	obstacle_jump_cd = obstacle_jump_cooldown

func _body_half_extents() -> Vector2:
	if not is_instance_valid(body_hitbox):
		return Vector2(
			12.0,
			24.0
		)

	if body_hitbox.shape == null:
		return Vector2(
			12.0,
			24.0
		)

	var scale_abs := Vector2(
		absf(body_hitbox.global_scale.x),
		absf(body_hitbox.global_scale.y)
	)

	var shape: Shape2D = body_hitbox.shape

	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		return Vector2(
			rectangle.size.x
			* scale_abs.x
			* 0.5,
			rectangle.size.y
			* scale_abs.y
			* 0.5
		)

	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return Vector2(
			capsule.radius
			* scale_abs.x,
			capsule.height
			* scale_abs.y
			* 0.5
		)

	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return Vector2(
			circle.radius
			* scale_abs.x,
			circle.radius
			* scale_abs.y
		)

	return Vector2(
		12.0,
		24.0
	)

func _terrain_ray(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = terrain_collision_mask
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _update_ai(delta: float) -> void:
	if _platform_guard_active():
		_update_platform_guard()
		return

	if platform_engaged and _player_below_platform():
		if _handle_engaged_player_below():
			return

	if _try_platform_chase():
		return

	# At 1 HP he may jump at a player just above him, but only occasionally.
	# Tall-platform chasing still uses the existing high-jump system.
	if hp <= 2 and is_on_floor() and high_jump_cd <= 0.0 and is_instance_valid(target):
		var rise: float = global_position.y - target.global_position.y
		var horizontal: float = absf(target.global_position.x - global_position.x)
		if rise >= last_hp_chase_jump_min_height and rise < last_hp_chase_jump_max_height and horizontal <= last_hp_chase_jump_max_horizontal:
			velocity.y = jump_velocity
			high_jump_cd = last_hp_chase_jump_cooldown

	var in_melee_range: bool = _shape_hits_player(detection_shape)

	# While kiting, don't get stuck in an ATTACK intent that only chases.
	# Reevaluate ranged options so skull-pressure can actually take effect.
	if ai_timer <= 0.0 and (intent != Intent.ATTACK or (_pursuit_skull_active() and not in_melee_range)):
		_choose_intent()

	match intent:
		Intent.SKULL:
			if skull_cd <= 0.0 and _player_in_chase_range():
				_start_skull_action()
			else:
				intent = Intent.APPROACH

		Intent.ATTACK:
			if not _melee_option_ready():
				intent = Intent.APPROACH
				ai_timer = randf_range(0.25, 0.50)
				_move_toward_player(0.95)
				return

			if not in_melee_range:
				_move_toward_player(1.08)
				return

			velocity.x = 0.0

			if not melee_warning_active:
				var next_attack: StringName = _choose_ready_melee_attack()

				if next_attack != &"":
					_start_melee_sequence(next_attack)
				else:
					intent = Intent.APPROACH
					ai_timer = randf_range(0.25, 0.50)

		Intent.SPACE:
			if in_melee_range:
				_space_from_player()
			else:
				_move_toward_player(0.82)

		Intent.APPROACH:
			_approach_without_attacking()

		Intent.HOLD:
			velocity.x = 0.0

func _update_platform_guard() -> void:
	velocity.x = 0.0
	face_target()

	if skull_cd <= 0.0:
		_start_skull_action(true)

func _handle_engaged_player_below() -> bool:
	if not is_on_floor():
		return false

	# Give platform guards time to fire, rather than instant repeated dives.
	if drop_chase_cd <= 0.0:
		drop_chase_cd = drop_chase_decision_cooldown
		if randf() < drop_chase_chance:
			_start_drop_chase()
			if drop_chase_active:
				return true

	if skull_cd <= 0.0 and randf() < engaged_below_skull_chance:
		_start_skull_action(false)
		return true

	velocity.x = 0.0
	face_target()
	return true


func _can_phase_drop_safely() -> bool:
	if not allow_safe_platform_drop or not is_instance_valid(target):
		return false
	# NEVER turn off the solid-terrain layer to drop. In the supplied scenes
	# platform and solid terrain both default to layer 1.
	if platform_pass_mask == 0 or (platform_pass_mask & terrain_collision_mask) != 0:
		return false
	if (collision_mask & platform_pass_mask) == 0:
		return false

	# Require a separate solid surface BELOW the thin pass-through platform.
	var from: Vector2 = global_position + Vector2(0.0, drop_chase_min_clearance)
	var to: Vector2 = from + Vector2(0.0, drop_chase_phase_check_distance)
	return _terrain_ray(from, to)


func _start_drop_chase() -> void:
	if drop_chase_active or not is_on_floor() or not is_instance_valid(target):
		return

	drop_chase_active = true
	drop_chase_time = 0.0
	drop_chase_start_y = global_position.y
	drop_chase_left_start_floor = false
	drop_chase_phase_active = _can_phase_drop_safely()
	velocity.y = 0.0

	if drop_chase_phase_active:
		# Drop through a dedicated platform layer, keeping solid ground enabled.
		base_collision_mask = collision_mask
		collision_mask &= ~platform_pass_mask
		drop_chase_direction = 0.0
		velocity.x = 0.0
		velocity.y = 55.0
	else:
		# Ordinary solid platforms: use a real edge.
		drop_chase_direction = _choose_drop_direction()
		if _edge_distance(drop_chase_direction) > drop_edge_scan_step * float(drop_edge_scan_count):
			_finish_drop_chase()
			return
		velocity.x = drop_chase_direction * drop_chase_speed

	play_walk()


func _update_drop_chase(delta: float) -> void:
	drop_chase_time += delta
	face_target()

	if drop_chase_phase_active:
		velocity.x = 0.0
		# Restore collision only once the entire body has cleared the platform.
		var cleared: bool = global_position.y - drop_chase_start_y >= drop_chase_min_clearance
		if cleared:
			collision_mask = base_collision_mask
			drop_chase_phase_active = false
			drop_chase_left_start_floor = true
		elif drop_chase_time >= drop_chase_max_time:
			# A valid platform drop should clear quickly. Restore the mask
			# instead of leaving a ghost Skeleton forever.
			collision_mask = base_collision_mask
			drop_chase_phase_active = false
			_finish_drop_chase()
			return
	else:
		velocity.x = drop_chase_direction * drop_chase_speed
		if not is_on_floor():
			drop_chase_left_start_floor = true
		if drop_chase_left_start_floor and is_on_floor():
			_finish_drop_chase()
			return

	if drop_chase_time >= drop_chase_max_time:
		_finish_drop_chase()


func _finish_drop_chase() -> void:
	if drop_chase_phase_active:
		collision_mask = base_collision_mask
	drop_chase_phase_active = false
	drop_chase_active = false
	drop_chase_time = 0.0
	drop_chase_left_start_floor = false
	velocity.x = 0.0
	ai_timer = randf_range(0.35, 0.70)


func _choose_drop_direction() -> float:
	var right_distance: float = _edge_distance(1.0)
	var left_distance: float = _edge_distance(-1.0)

	if right_distance < left_distance:
		return 1.0
	if left_distance < right_distance:
		return -1.0

	var dx: float = target.global_position.x - global_position.x
	if not is_zero_approx(dx):
		return signf(dx)

	return 1.0 if randf() < 0.5 else -1.0

func _edge_distance(direction: float) -> float:
	var half_extents: Vector2 = _body_half_extents()
	var body_center: Vector2 = body_hitbox.global_position
	var feet_y: float = body_center.y + half_extents.y

	for i in range(1, drop_edge_scan_count + 1):
		var distance: float = drop_edge_scan_step * float(i)
		var x: float = body_center.x + direction * distance
		var from := Vector2(x, feet_y - 4.0)
		var to := Vector2(x, feet_y + 28.0)

		if not _terrain_ray(from, to):
			return distance

	return 99999.0

func _melee_option_ready() -> bool:
	return (
		attack1_cd <= 0.0
		or attack2_cd <= 0.0
		or rush_cd <= 0.0
	)


func _choose_intent() -> void:
	if hp <= 2:
		ai_timer = randf_range(last_hp_decision_min_time, last_hp_decision_max_time)
	else:
		ai_timer = randf_range(ai_decision_min_time, ai_decision_max_time)

	# Red phase rolls skull intent more often. Overhead attacks retain their own longer cooldown.
	var skull_chance: float = red_skull_chance if hp <= 2 else ai_skull_intent_chance
	if _pursuit_skull_active():
		var far_chance: float = pursuit_skull_max_chance
		if hp <= 2:
			far_chance = maxf(far_chance, 0.80)
		skull_chance = lerpf(skull_chance, far_chance, pursuit_skull_pressure)
	if skull_cd <= 0.0 and _player_in_chase_range() and randf() < skull_chance:
		intent = Intent.SKULL
		return

	if _melee_option_ready() and randf() < (0.98 if hp <= 2 else ai_attack_intent_chance):
		intent = Intent.ATTACK
		attack_prepare_timer = 0.0
		return

	var roll: float = randf()

	if roll < 0.05:
		intent = Intent.SPACE
	elif roll < 0.94:
		intent = Intent.APPROACH
	else:
		intent = Intent.HOLD

func _choose_ready_melee_attack() -> StringName:
	var choices: Array[StringName] = []

	if attack1_cd <= 0.0:
		choices.append_array([
			&"attack1",
			&"attack1",
			&"attack1",
			&"attack1",
			&"attack1"
		])

	if attack2_cd <= 0.0:
		choices.append_array([
			&"attack2",
			&"attack2",
			&"attack2",
			&"attack2"
		])

	if choices.is_empty():
		return &""

	return choices[
		randi_range(
			0,
			choices.size() - 1
		)
	]


func _choose_combo_size() -> int:
	var roll: float = randf()

	if roll < combo_three_hit_chance:
		return 3

	if roll < combo_three_hit_chance + combo_two_hit_chance:
		return 2

	return 1


func _start_melee_sequence(attack_name: StringName) -> void:
	combo_total = _choose_combo_size()
	combo_step = 1
	combo_active = combo_total > 1
	_start_melee_warning(attack_name)


func _choose_combo_followup() -> StringName:
	if last_melee_attack == &"attack1":
		return &"attack2" if randf() < 0.58 else &"attack1"

	return &"attack1" if randf() < 0.62 else &"attack2"


func _warning_color() -> Color:
	if hp <= 2:
		return enrage_red_warning
	if hp <= 4:
		return enrage_orange_warning
	if combo_step >= 3:
		return Color(1.0, 0.22, 0.16, 1.0)

	if combo_step == 2:
		return Color(1.0, 0.48, 0.12, 1.0)

	return Color(1.0, 0.86, 0.25, 1.0)


func _reset_combo() -> void:
	combo_active = false
	combo_total = 1
	combo_step = 0


func _start_melee_warning(attack_name: StringName) -> void:
	if melee_warning_active:
		return

	melee_warning_active = true
	melee_warning_duration = (
		combo_warning_pause
		if combo_active and combo_step > 1
		else attack_prepare_pause
	)
	if hp <= 2:
		melee_warning_duration = maxf(
			melee_warning_duration,
			red_combo_warning_duration if combo_active and combo_step > 1 else red_warning_duration
		)
	melee_warning_timer = melee_warning_duration
	pending_melee_attack = attack_name
	warning_original_self_modulate = sprite.self_modulate

	velocity.x = 0.0
	face_target()

	sprite.stop()

	if attack_name == &"attack2":
		sprite.animation = attack2_animation
	else:
		sprite.animation = attack_animation

	sprite.frame = 0
	sprite.frame_progress = 0.0

func _update_melee_warning(delta: float) -> void:
	velocity.x = 0.0
	face_target()

	melee_warning_timer = maxf(
		0.0,
		melee_warning_timer - delta
	)

	var duration: float = maxf(
		0.01,
		melee_warning_duration
	)

	var progress: float = clampf(
		1.0 - melee_warning_timer / duration,
		0.0,
		1.0
	)

	var flash: float = sin(
		progress * TAU * 2.0
	)

	if flash > 0.0:
		sprite.self_modulate = _warning_color()
	else:
		sprite.self_modulate = warning_original_self_modulate

	if melee_warning_timer > 0.0:
		return

	sprite.self_modulate = warning_original_self_modulate

	var attack_to_start: StringName = pending_melee_attack

	melee_warning_active = false
	melee_warning_timer = 0.0
	pending_melee_attack = &""

	if attack_to_start == &"attack2":
		_start_attack2()
	else:
		_start_attack1()

func _cancel_melee_warning() -> void:
	if melee_warning_active:
		melee_warning_active = false
		melee_warning_timer = 0.0
		pending_melee_attack = &""
		sprite.self_modulate = warning_original_self_modulate
		sprite.speed_scale = 1.0

	_reset_combo()

func _start_ready_attack() -> bool:
	var choices: Array[StringName] = []

	if attack1_cd <= 0.0:
		choices.append_array([
			&"attack1",
			&"attack1",
			&"attack1",
			&"attack1",
			&"attack1"
		])

	if attack2_cd <= 0.0:
		choices.append_array([
			&"attack2",
			&"attack2",
			&"attack2",
			&"attack2"
		])

	if rush_cd <= 0.0:
		choices.append(&"rush")

	if choices.is_empty():
		return false

	var choice: StringName = choices[
		randi_range(
			0,
			choices.size() - 1
		)
	]

	if choice == &"attack1":
		_start_attack1()
	elif choice == &"attack2":
		_start_attack2()
	else:
		_start_rush()

	return true

func _move_toward_player(multiplier := 1.0) -> void:
	var dx: float = target.global_position.x - global_position.x
	velocity.x = signf(dx) * move_speed * multiplier
	_try_small_obstacle_jump()

func _approach_without_attacking() -> void:
	var dx: float = target.global_position.x - global_position.x

	if not _shape_hits_player(detection_shape):
		velocity.x = signf(dx) * move_speed * 0.90
		_try_small_obstacle_jump()
		return

	if absf(dx) <= ai_approach_distance:
		velocity.x = 0.0
	else:
		velocity.x = signf(dx) * move_speed * 0.82
		_try_small_obstacle_jump()

func _space_from_player() -> void:
	var dx: float = target.global_position.x - global_position.x

	if not _shape_hits_player(detection_shape):
		velocity.x = signf(dx) * move_speed * 0.82
		_try_small_obstacle_jump()
		return

	var distance: float = absf(dx)
	var min_distance: float = preferred_spacing_distance - spacing_tolerance
	var max_distance: float = preferred_spacing_distance + spacing_tolerance
	var spacing_speed: float = move_speed * spacing_speed_multiplier

	if distance < min_distance:
		velocity.x = -signf(dx) * spacing_speed
	elif distance > max_distance:
		velocity.x = signf(dx) * spacing_speed
		_try_small_obstacle_jump()
	else:
		velocity.x = 0.0

func _start_attack1() -> void:
	attacking = true
	current_attack = attack_animation
	last_melee_attack = &"attack1"
	attack_hit_done = false
	attack1_cd = attack_cooldown
	_play_attack_animation(attack_animation)

func _start_attack2() -> void:
	attacking = true
	current_attack = attack2_animation
	last_melee_attack = &"attack2"
	attack2_hit1_done = false
	attack2_hit2_done = false
	attack2_cd = attack2_cooldown
	_play_attack_animation(attack2_animation)

func _start_rush() -> void:
	var dx: float = target.global_position.x - global_position.x

	_reset_combo()
	rush_active = true
	attacking = true
	current_attack = attack2_animation
	rush_direction = 1.0 if is_zero_approx(dx) else signf(dx)

	attack2_hit1_done = false
	attack2_hit2_done = false

	rush_cd = special_attack_cooldown
	attack2_cd = maxf(attack2_cd, attack2_cooldown)

	facing_right = rush_direction > 0.0
	_apply_facing()
	_play_attack_animation(attack2_animation)

func _play_attack_animation(animation: StringName) -> void:
	sprite.stop()
	sprite.speed_scale = attack_first_three_frames_speed * (red_attack_animation_multiplier if hp <= 2 else 1.0)
	sprite.animation = animation
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play()

func _update_melee_lunge() -> void:
	if rush_active:
		velocity.x = 0.0
		return

	if (
		current_attack != attack_animation
		and current_attack != attack2_animation
	):
		velocity.x = 0.0
		return

	if (
		sprite.frame >= melee_lunge_start_frame
		and sprite.frame <= melee_lunge_end_frame
	):
		var direction: float = 1.0 if facing_right else -1.0
		velocity.x = direction * melee_lunge_speed * (red_melee_lunge_multiplier if hp <= 2 else 1.0)
	else:
		velocity.x = 0.0


func _on_sprite_frame_changed() -> void:
	if not attacking:
		return

	sprite.speed_scale = (
		attack_first_three_frames_speed
		if sprite.frame <= 2
		else attack_after_frame_two_speed
	) * (red_attack_animation_multiplier if hp <= 2 else 1.0)

	if current_attack == attack_animation:
		if sprite.frame == attack_damage_frame and not attack_hit_done:
			attack_hit_done = true
			if _shape_hits_player(attack1_shape):
				_damage_player(attack_damage)

	elif current_attack == attack2_animation:
		if sprite.frame == attack2_first_damage_frame and not attack2_hit1_done:
			attack2_hit1_done = true
			if _shape_hits_player(attack2_shape):
				_damage_player(attack2_damage_per_hit)

		if sprite.frame == attack2_second_damage_frame and not attack2_hit2_done:
			attack2_hit2_done = true
			if _shape_hits_player(attack2_shape):
				_damage_player(attack2_damage_per_hit)

func _on_sprite_animation_finished() -> void:
	if attacking and sprite.animation == current_attack:
		_finish_attack()

func _on_sprite_animation_looped() -> void:
	if attacking and sprite.animation == current_attack:
		_finish_attack()

func _finish_attack() -> void:
	var was_rush: bool = rush_active

	attacking = false
	rush_active = false
	current_attack = &""
	velocity.x = 0.0
	sprite.speed_scale = 1.0
	sprite.self_modulate = warning_original_self_modulate
	attack_prepare_timer = 0.0

	if (
		not was_rush
		and combo_active
		and combo_step < combo_total
		and is_instance_valid(target)
		and _shape_hits_player(detection_shape)
	):
		combo_step += 1
		_start_melee_warning(
			_choose_combo_followup()
		)
		return

	_reset_combo()
	intent = Intent.APPROACH
	if hp <= 2:
		ai_timer = randf_range(last_hp_post_attack_min_time, last_hp_post_attack_max_time)
	else:
		ai_timer = randf_range(0.15, 0.35)
	play_idle()

func _shape_hits_player(shape_node: CollisionShape2D) -> bool:
	if not is_instance_valid(target) or shape_node.disabled or shape_node.shape == null:
		return false

	for player_shape in _player_body_shapes():
		if shape_node.shape.collide(
			shape_node.global_transform,
			player_shape.shape,
			player_shape.global_transform
		):
			return true

	return false

func _player_body_shapes() -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []

	if not is_instance_valid(target):
		return result

	for node in target.find_children("*", "CollisionShape2D", true, false):
		if not node is CollisionShape2D:
			continue

		var shape := node as CollisionShape2D
		if shape.disabled or shape.shape == null:
			continue

		var owner := _nearest_collision_object(shape)
		if owner == target:
			result.append(shape)

	return result

func _nearest_collision_object(node: Node) -> CollisionObject2D:
	var current := node.get_parent()

	while current != null:
		if current is CollisionObject2D:
			return current as CollisionObject2D
		if current == target:
			break
		current = current.get_parent()

	return target as CollisionObject2D if target is CollisionObject2D else null


func _living_skeleton_count() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group(SKELETON_GROUP):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node is CharacterBody2D and not bool(node.get("dead")):
			count += 1
	return count

func _claim_group_skull_turn() -> bool:
	var count: int = _living_skeleton_count()
	# One Skeleton keeps 100% of its original skull behavior.
	if count <= 1:
		return true

	var level: Node = get_tree().current_scene
	if level == null:
		return true

	var now: int = Time.get_ticks_msec()
	var next_time: int = int(level.get_meta(GROUP_SKULL_NEXT_TIME, 0))
	if now < next_time:
		return false

	var delay: float = group_skull_cooldown + float(count - 2) * group_skull_extra_delay
	level.set_meta(GROUP_SKULL_NEXT_TIME, now + int(maxf(0.0, delay) * 1000.0))
	return true

func _start_skull_action(platform_guard: bool = false) -> void:
	if skull_cd > 0.0 or not _player_in_chase_range():
		return

	var overhead_attack: bool = (
		target.global_position.y - global_position.y >= overhead_skull_vertical_gap
	)
	if overhead_attack and overhead_skull_cd > 0.0:
		# Do not delay same-level fire: this timer only gates overhead volleys.
		intent = Intent.APPROACH
		return

	# Check once per volley, not once per projectile.
	if not _claim_group_skull_turn():
		# Let this Skeleton retry later instead of trying every frame.
		skull_cd = 0.5
		intent = Intent.APPROACH
		return

	skull_cd = platform_guard_skull_cooldown if platform_guard else skull_attack_cooldown
	if not overhead_attack and _pursuit_skull_active():
		# Cooldown ramps from 9s down to 5s. Compensate for red phase's
		# accelerated skull timer so this is real elapsed time.
		var real_cooldown: float = lerpf(
			pursuit_skull_start_cooldown,
			pursuit_skull_min_cooldown,
			pursuit_skull_pressure
		)
		skull_cd = real_cooldown / (red_skull_cooldown_multiplier if hp <= 2 else 1.0)
	if overhead_attack:
		overhead_skull_cd = maxf(0.0, overhead_skull_cooldown)
	skull_action_active = true
	skull_action_time = 0.0

	var dx: float = target.global_position.x - global_position.x
	var close: bool = _shape_hits_player(detection_shape)

	if close:
		skull_backjumping = true
		skull_backjump_direction = -signf(dx) if not is_zero_approx(dx) else -1.0
		velocity.x = skull_backjump_direction * skull_back_jump_speed
		velocity.y = skull_back_jump_velocity
		play_walk_backwards()
	else:
		skull_backjumping = false
		velocity.x = 0.0
		play_idle()

	_queue_skull_volley()

func _update_skull_action(delta: float) -> void:
	skull_action_time += delta
	face_target()

	if skull_backjumping:
		velocity.x = skull_backjump_direction * skull_back_jump_speed

		if skull_action_time > 0.14 and is_on_floor() and velocity.y >= 0.0:
			_finish_skull_action()
		elif skull_action_time >= skull_back_jump_max_time:
			_finish_skull_action()
	else:
		velocity.x = 0.0
		if skull_action_time >= 0.32:
			_finish_skull_action()

func _finish_skull_action() -> void:
	skull_action_active = false
	skull_backjumping = false
	velocity.x = 0.0
	ai_timer = randf_range(0.55, 1.0)
	play_idle()

func _choose_skull_count() -> int:
	var r := randf()
	# Red phase makes larger volleys more likely without exceeding multiplayer
	# and overhead caps, leaving playable gaps between overhead projectiles.
	if hp <= 2:
		r = clampf(r + 0.16, 0.0, 0.999)

	if r < 0.10: return 1
	if r < 0.20: return 2
	if r < 0.30: return 3
	if r < 0.40: return 4
	if r < 0.80: return 5
	if r < 0.87: return 6
	if r < 0.91: return 7
	if r < 0.94: return 8
	if r < 0.98: return 9
	return 10

func _queue_skull_volley() -> void:
	var count: int = _choose_skull_count()
	var living: int = _living_skeleton_count()
	if living == 2:
		count = mini(count, maxi(1, group_skull_max_two))
	elif living == 3:
		count = mini(count, maxi(1, group_skull_max_three))
	elif living >= 4:
		count = mini(count, maxi(1, group_skull_max_four_plus))

	# Lock the firing mode for this volley, so jumping during the warning
	# does not suddenly turn slow, readable projectiles into fast ones.
	var from_above: bool = (
		is_instance_valid(target)
		and target.global_position.y - global_position.y >= overhead_skull_vertical_gap
	)
	if from_above:
		count = mini(count, maxi(1, overhead_skull_max_per_volley))

	var slots: Array[float] = [-4.5, -3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5]
	if not from_above:
		slots.shuffle()

	var delay := 0.0
	for i in count:
		if i > 0:
			if from_above:
				delay += randf_range(overhead_skull_spawn_gap_min, overhead_skull_spawn_gap_max)
			else:
				delay += randf_range(skull_spawn_gap_min, skull_spawn_gap_max)

		var horizontal_offset: float
		if from_above:
			# Evenly distributed, rather than a random cluster of skulls.
			horizontal_offset = (float(i) - float(count - 1) * 0.5) * overhead_skull_spacing
		else:
			horizontal_offset = slots[i] * skull_spawn_spacing + randf_range(-4.0, 4.0)

		pending_skulls.append({
			"delay": delay,
			"from_above": from_above,
			"offset": Vector2(horizontal_offset, randf_range(skull_spawn_min_y, skull_spawn_max_y))
		})

func _update_pending_skulls(delta: float) -> void:
	for i in range(pending_skulls.size() - 1, -1, -1):
		pending_skulls[i]["delay"] = float(pending_skulls[i]["delay"]) - delta

		if pending_skulls[i]["delay"] <= 0.0:
			_spawn_skull(global_position + pending_skulls[i]["offset"], bool(pending_skulls[i].get("from_above", false)))
			pending_skulls.remove_at(i)

func _spawn_skull(spawn_position: Vector2, from_above: bool = false) -> void:
	if skull_template.texture == null:
		return

	var root := Area2D.new()
	root.name = "SkeletonSkull"
	root.add_to_group(&"skeleton_skull")
	root.set_meta(&"skeleton_owner", self)
	root.collision_layer = 0
	root.collision_mask = 0
	root.monitoring = false
	root.monitorable = false
	get_tree().current_scene.add_child(root)
	root.global_position = spawn_position

	var visual := Sprite2D.new()
	visual.texture = skull_template.texture
	visual.centered = skull_template.centered
	visual.offset = skull_template.offset
	visual.scale = skull_template.scale
	visual.modulate = skull_template.modulate
	visual.self_modulate = skull_template.self_modulate
	visual.texture_filter = skull_template.texture_filter
	root.add_child(visual)

	var hit_shape := CollisionShape2D.new()

	if skull_template_shape.shape != null:
		hit_shape.shape = skull_template_shape.shape.duplicate()
		hit_shape.position = skull_template_shape.position
		hit_shape.rotation = skull_template_shape.rotation
		hit_shape.scale = skull_template_shape.scale
	else:
		var circle := CircleShape2D.new()
		circle.radius = skull_fallback_radius
		hit_shape.shape = circle

	root.add_child(hit_shape)

	var aim: Vector2 = Vector2.RIGHT

	if is_instance_valid(target):
		aim = root.global_position.direction_to(
			_player_aim_position()
		).normalized()

	_aim_skull_visual(
		visual,
		aim
	)

	# Every skull gets a visible curve; variety comes from frequency/phase.
	var mode: int = randi_range(1, 3)

	var lock_chance: float = overhead_skull_soft_lock_chance if from_above else skull_soft_lock_chance
	if hp <= 2:
		lock_chance = red_overhead_lock_chance if from_above else red_skull_lock_chance
	var soft_lock: bool = randf() < lock_chance

	var curve_angle: float = randf_range(
		skull_curve_angle_min,
		skull_curve_angle_max
	)

	if mode == 0:
		curve_angle *= 0.55
	elif mode == 3:
		curve_angle *= 1.20

	if from_above:
		curve_angle *= overhead_skull_curve_multiplier
	if hp <= 2:
		curve_angle *= red_skull_curve_multiplier

	if soft_lock:
		curve_angle *= skull_soft_lock_curve_multiplier
		mode = maxi(
			mode,
			2
		)

	active_skulls.append({
		"from_above": from_above,
		"root": root,
		"visual": visual,
		"shape": hit_shape,
		"origin": spawn_position,
		"aim_time": 0.0,
		"aim_duration": maxf(
			0.65,
			skull_aim_duration + randf_range(
				-0.12,
				0.18
			)
		),
		"direction": aim,
		"original_direction": aim,
		"pullback": randf_range(
			skull_pullback_min,
			skull_pullback_max
		),
		"hover_phase": randf_range(
			0.0,
			TAU
		),
		"launched": false,
		"life": 0.0,
		"speed_scale": randf_range(
			0.92,
			1.10
		) * (overhead_skull_speed_multiplier if from_above else 1.0) * (red_skull_speed_multiplier if hp <= 2 else 1.0),
		"curve_mode": mode,
		"curve_angle": curve_angle,
		"curve_frequency": randf_range(
			skull_curve_frequency_min,
			skull_curve_frequency_max
		),
		"curve_phase": randf_range(
			0.0,
			TAU
		),
		"soft_lock": soft_lock,
		"reflected": false,
		"reflection_heavy": false,
		"reflection_target": null,
		"reflection_source": null
	})

func _update_skulls(delta: float) -> void:
	for i in range(
		active_skulls.size() - 1,
		-1,
		-1
	):
		var skull: Dictionary = active_skulls[i]
		var root := skull["root"] as Area2D

		if not is_instance_valid(root):
			active_skulls.remove_at(i)
			continue

		var visual := skull["visual"] as Sprite2D

		if bool(skull.get("reflected", false)):
			_update_reflected_skull(i, skull, root, visual, delta)
			continue

		if not bool(skull["launched"]):
			skull["aim_time"] = float(skull["aim_time"]) + delta

			var aim_time: float = float(skull["aim_time"])
			var aim_duration: float = float(skull["aim_duration"])
			var direction := skull["direction"] as Vector2

			if is_instance_valid(target):
				direction = root.global_position.direction_to(
					_player_aim_position()
				).normalized()

			skull["direction"] = direction
			skull["original_direction"] = direction

			var progress: float = clampf(
				aim_time / aim_duration,
				0.0,
				1.0
			)

			var pull: float = (
				sin(progress * PI * 0.5)
				* float(skull["pullback"])
			)

			var perpendicular := Vector2(
				-direction.y,
				direction.x
			)

			var hover: float = sin(
				aim_time * 8.0
				+ float(skull["hover_phase"])
			) * 2.5

			root.global_position = (
				(skull["origin"] as Vector2)
				- direction * pull
				+ perpendicular * hover
			)

			_aim_skull_visual(
				visual,
				direction
			)

			if aim_time >= aim_duration:
				if is_instance_valid(target):
					direction = root.global_position.direction_to(
						_player_aim_position()
					).normalized()

				skull["direction"] = direction
				skull["original_direction"] = direction
				skull["launched"] = true
				skull["life"] = 0.0

			active_skulls[i] = skull
			continue

		skull["life"] = float(skull["life"]) + delta
		var life: float = float(skull["life"])

		if life >= skull_lifetime:
			root.queue_free()
			active_skulls.remove_at(i)
			continue

		var base_direction := skull["direction"] as Vector2

		if (
			bool(skull["soft_lock"])
			and life <= skull_soft_lock_duration
			and is_instance_valid(target)
		):
			var wanted: Vector2 = root.global_position.direction_to(
				_player_aim_position()
			)

			if wanted.length_squared() > 0.0001:
				wanted = wanted.normalized()

				var current_angle: float = base_direction.angle()
				var wanted_angle: float = wanted.angle()
				var max_step: float = (
					deg_to_rad(skull_soft_lock_turn_speed)
					* delta
				)

				var next_angle: float = rotate_toward(
					current_angle,
					wanted_angle,
					max_step
				)

				var original_direction := skull["original_direction"] as Vector2
				var original_angle: float = original_direction.angle()
				var offset: float = angle_difference(
					original_angle,
					next_angle
				)

				var max_offset: float = deg_to_rad(
					skull_soft_lock_max_angle
				)

				offset = clampf(
					offset,
					-max_offset,
					max_offset
				)

				base_direction = Vector2.RIGHT.rotated(
					original_angle + offset
				)

				skull["direction"] = base_direction

		var curve: float = clampf(
			_skull_curve_angle(skull, life),
			-15.0 if bool(skull.get("from_above", false)) else -23.0,
			15.0 if bool(skull.get("from_above", false)) else 23.0
		)

		var movement: Vector2 = base_direction.rotated(
			deg_to_rad(curve)
		)

		root.global_position += (
			movement
			* skull_speed
			* float(skull["speed_scale"])
			* delta
		)

		_aim_skull_visual(
			visual,
			movement
		)

		var skull_shape := skull["shape"] as CollisionShape2D

		if _shape_hits_player(skull_shape):
			_damage_player(
				skull_damage,
				true
			)

			root.queue_free()
			active_skulls.remove_at(i)
			continue

		active_skulls[i] = skull

# Player attacks can reflect the skull while it is aiming or flying.
# The projectile stays owned by its original skeleton, so it can be updated
# using the same active_skulls list without adding any scene nodes or scripts.
func reflect_skull(skull_root: Node2D, heavy: bool, reflector: Node2D) -> bool:
	if dead or not is_instance_valid(skull_root) or not is_instance_valid(reflector):
		return false
	for i in range(active_skulls.size()):
		var skull: Dictionary = active_skulls[i]
		if skull.get("root") != skull_root or bool(skull.get("reflected", false)):
			continue
		var direction: Vector2 = skull_root.global_position - reflector.global_position
		if heavy:
			direction = global_position - skull_root.global_position
		if direction.length_squared() < 0.001:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		skull["reflected"] = true
		skull["reflection_heavy"] = heavy
		skull["reflection_target"] = self if heavy else null
		skull["reflection_source"] = reflector
		skull["direction"] = direction
		skull["launched"] = true
		skull["life"] = 0.0
		active_skulls[i] = skull
		_aim_skull_visual(skull["visual"] as Sprite2D, direction)
		return true
	return false

func _update_reflected_skull(i: int, skull: Dictionary, root: Area2D, visual: Sprite2D, delta: float) -> void:
	skull["life"] = float(skull["life"]) + delta
	if float(skull["life"]) >= skull_lifetime:
		root.queue_free()
		active_skulls.remove_at(i)
		return

	var direction: Vector2 = skull["direction"] as Vector2
	var heavy: bool = bool(skull["reflection_heavy"])
	var destination: Node2D = skull["reflection_target"] as Node2D
	if heavy and is_instance_valid(destination) and not dead:
		direction = root.global_position.direction_to(destination.global_position)
		if direction.length_squared() < 0.001:
			direction = Vector2.RIGHT

	# Reflections travel straight. They never curve back toward the player.
	var travel: float = skull_speed * (1.65 if heavy else 1.25) * delta
	root.global_position += direction * travel
	_aim_skull_visual(visual, direction)
	skull["direction"] = direction

	if heavy and is_instance_valid(destination) and not dead:
		var hit_distance: float = maxf(18.0, _body_half_extents().x + 12.0)
		if root.global_position.distance_to(destination.global_position) <= hit_distance:
			root.queue_free()
			active_skulls.remove_at(i)
			_receive_damage(1)
			if dead:
				var reflector: Node2D = skull["reflection_source"] as Node2D
				if is_instance_valid(reflector) and reflector.has_method(&"on_enemy_killed"):
					reflector.call(&"on_enemy_killed", self)
			return

	active_skulls[i] = skull

func _skull_curve_angle(skull: Dictionary, time: float) -> float:
	var frequency: float = float(
		skull["curve_frequency"]
	)

	var phase: float = float(
		skull["curve_phase"]
	)

	var angle: float = float(
		skull["curve_angle"]
	)

	var main: float = sin(
		time * frequency + phase
	) * angle

	match int(skull["curve_mode"]):
		0:
			return (
				main
				+ sin(
					time * frequency * 0.43
					+ phase * 0.70
				) * angle * 0.22
			)

		1:
			return (
				main
				+ sin(
					time * frequency * 0.52
					+ phase
				) * angle * 0.42
			)

		2:
			return (
				main
				+ sin(
					time * frequency * 1.73
					+ phase * 0.61
				) * angle * 0.68
			)

		_:
			return (
				main
				+ sin(
					time * frequency * 1.91
					+ phase * 1.23
				) * angle * 0.82
				+ cos(
					time * frequency * 0.37
					+ phase * 0.48
				) * angle * 0.38
			)

func _aim_skull_visual(visual: Sprite2D, direction: Vector2) -> void:
	if direction.length_squared() <= 0.0001:
		return

	var dir: Vector2 = direction.normalized()
	# The skull art in this project looks LEFT in its texture. Rotation alone
	# had every skull flying backward, so add 180 degrees to the baseline.
	visual.flip_h = false
	visual.flip_v = false
	visual.rotation = dir.angle() + (0.0 if skull_faces_right_by_default else PI) + deg_to_rad(skull_rotation_offset_degrees)

func _player_aim_position() -> Vector2:
	var shapes := _player_body_shapes()
	return shapes[0].global_position if not shapes.is_empty() else target.global_position

func _clear_skulls() -> void:
	pending_skulls.clear()

	for skull in active_skulls:
		var root = skull.get("root")
		if root is Node and is_instance_valid(root):
			root.queue_free()

	active_skulls.clear()

func _damage_player(amount: int, ignore_iframes := false) -> void:
	if not is_instance_valid(target):
		return

	if ignore_iframes:
		for method in [
			&"take_damage_ignore_iframes",
			&"take_damage_no_iframes",
			&"damage_ignore_iframes",
			&"force_damage"
		]:
			if target.has_method(method):
				target.call(method, amount)
				return

		_clear_common_iframes()

	for method in [&"take_damage", &"receive_damage", &"damage", &"hurt", &"levar_dano", &"tomar_dano"]:
		if target.has_method(method):
			target.call(method, amount)
			return

func _clear_common_iframes() -> void:
	var existing := {}

	for info in target.get_property_list():
		existing[String(info["name"])] = true

	for name in ["invincible", "invulnerable", "is_invincible", "is_invulnerable", "invencivel"]:
		if existing.has(name):
			target.set(name, false)

	for name in [
		"invincibility_timer",
		"invulnerability_timer",
		"iframe_timer",
		"iframes_timer",
		"tempo_invencibilidade",
		"damage_cooldown_timer"
	]:
		if existing.has(name):
			target.set(name, 0.0)

func face_target() -> void:
	if not is_instance_valid(target) or rush_active:
		return

	var dx: float = target.global_position.x - global_position.x
	if not is_zero_approx(dx):
		facing_right = dx > 0.0
		_apply_facing()

func _apply_facing() -> void:
	sprite.flip_h = (
		not facing_right
		if sprite_faces_right_by_default
		else facing_right
	)

	var sign_x: float = 1.0 if facing_right == attack_shapes_authored_to_right else -1.0
	attack1_shape.position = Vector2(absf(attack1_base_pos.x) * sign_x, attack1_base_pos.y)
	attack2_shape.position = Vector2(absf(attack2_base_pos.x) * sign_x, attack2_base_pos.y)
	detection_shape.position = Vector2(absf(detection_base_pos.x) * sign_x, detection_base_pos.y)

func _update_move_animation() -> void:
	if attacking or skull_action_active:
		return

	if absf(velocity.x) < 1.0:
		play_idle()
	elif velocity.x != 0.0 and signf(velocity.x) != (1.0 if facing_right else -1.0):
		play_walk_backwards()
	else:
		play_walk()

func play_idle() -> void:
	if sprite.animation != idle_animation:
		sprite.play(idle_animation)

func play_walk() -> void:
	var wanted: float = red_move_speed_multiplier if hp <= 2 else 1.0
	if sprite.animation != walk_animation or sprite.speed_scale < 0.0:
		sprite.speed_scale = wanted
		sprite.play(walk_animation)
	else:
		sprite.speed_scale = wanted

func play_walk_backwards() -> void:
	var wanted: float = red_move_speed_multiplier if hp <= 2 else 1.0
	if sprite.animation != walk_animation or sprite.speed_scale >= 0.0:
		sprite.play_backwards(walk_animation)
	sprite.speed_scale = -wanted

func _sync_player_attack_layers() -> void:
	if not is_instance_valid(target):
		return

	var mask := 0

	for wanted_name in [player_attack_area_j_name, player_attack_area_k_name]:
		var node := target.find_child(String(wanted_name), true, false)
		if node is Area2D:
			mask |= node.collision_mask

	if mask != 0:
		collision_layer |= mask

	damage_layer_synced = true

func _make_flash_material() -> void:
	original_sprite_material = sprite.material

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float flash_amount = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, vec3(c.a), flash_amount);
	COLOR = c;
}
"""

	flash_material = ShaderMaterial.new()
	flash_material.shader = shader
	flash_material.set_shader_parameter("flash_amount", 0.0)

func _start_flash() -> void:
	flash_active = true
	flash_time = 0.0
	sprite.material = flash_material
	flash_material.set_shader_parameter("flash_amount", 1.0)

func _update_flash(delta: float) -> void:
	if not flash_active:
		return

	flash_time += delta
	var phase: int = int(floor(flash_time / maxf(0.02, damage_flash_step)))

	if phase == 0 or phase == 2:
		flash_material.set_shader_parameter("flash_amount", 1.0)
	elif phase <= 3:
		flash_material.set_shader_parameter("flash_amount", 0.0)
	else:
		_finish_flash()

func _finish_flash() -> void:
	flash_active = false
	flash_time = 0.0

	if flash_material != null:
		flash_material.set_shader_parameter("flash_amount", 0.0)

	sprite.material = original_sprite_material

func tomar_dano(quantidade: int, _origem: Vector2 = Vector2.ZERO) -> void:
	_receive_damage(quantidade)

func take_damage(amount: int, _from_position: Vector2 = Vector2.ZERO, _hit_type: String = "generic") -> void:
	_receive_damage(amount)

func _receive_damage(amount: int) -> void:
	if dead or amount <= 0:
		return

	var already_committed: bool = attacking or rush_active or skull_action_active
	var was_warning: bool = melee_warning_active

	hp = maxi(0, hp - amount)
	_start_flash()

	if hp <= 0:
		die()
		return

	# Necromancer buffs let warnings finish even under repeated hits.
	if bool(get_meta(&"necromancer_buffed", false)):
		stun_timer = 0.0
		if not was_warning and not already_committed and not high_jump_active and not drop_chase_active:
			intent = Intent.ATTACK
			ai_timer = 0.0
		return

	# Orange (3-4) and red (1-2): taking damage does not interrupt attack.
	if hp <= 4:
		stun_timer = 0.0
		if was_warning:
			# The current warning continues, switching color immediately.
			return
		if already_committed:
			return
		# Pursue/attack normally instead of entering damage-stun.
		intent = Intent.ATTACK
		ai_timer = 0.0
		return

	if was_warning:
		_cancel_melee_warning()

	if already_committed:
		return

	if high_jump_active:
		_finish_high_jump()

	if drop_chase_active:
		_finish_drop_chase()

	stun_timer = damage_stun_duration
	velocity.x = 0.0
	attack_prepare_timer = 0.0
	intent = Intent.SPACE
	ai_timer = randf_range(0.60, 1.05)
	sprite.speed_scale = 1.0
	play_idle()

func die() -> void:
	if dead:
		return

	dead = true
	remove_from_group(SKELETON_GROUP)
	_cancel_melee_warning()
	attacking = false
	rush_active = false
	skull_action_active = false
	drop_chase_active = false

	if platform_collision_ignored or drop_chase_phase_active:
		collision_mask = base_collision_mask
	drop_chase_phase_active = false

	velocity = Vector2.ZERO
	_clear_skulls()
	_finish_flash()

	collision_layer = 0
	collision_mask = 0
	body_hitbox.set_deferred("disabled", true)
	attack1_shape.set_deferred("disabled", true)
	attack2_shape.set_deferred("disabled", true)
	detection_shape.set_deferred("disabled", true)
	attack_area.set_deferred("monitoring", false)

	sprite.stop()
	sprite.speed_scale = 1.0

	var start_pos := sprite.position
	var start_scale := sprite.scale
	var start_rot := sprite.rotation
	var tilt: float = 1.0 if sprite.flip_h else -1.0

	var pop_time: float = minf(0.12, death_total_time * 0.25)
	var fall_time: float = maxf(0.18, death_total_time - pop_time)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		sprite,
		"position",
		start_pos + Vector2(0.0, -death_pop_height),
		pop_time
	)

	tween.parallel().tween_property(
		sprite,
		"scale",
		Vector2(start_scale.x * 1.10, start_scale.y * 0.82),
		pop_time
	)

	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(sprite, "position", start_pos + Vector2(0.0, 8.0), fall_time)
	tween.parallel().tween_property(
		sprite,
		"rotation",
		start_rot + deg_to_rad(death_tilt_degrees * tilt),
		fall_time
	)
	tween.parallel().tween_property(
		sprite,
		"scale",
		Vector2(start_scale.x * 0.72, start_scale.y * 0.22),
		fall_time
	)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, fall_time)
	tween.tween_callback(queue_free)
