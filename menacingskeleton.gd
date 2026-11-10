extends CharacterBody2D
# Menacing Skeleton miniboss, Godot 4.x.
# Scene children (exact): AnimatedSprite2D, CollisionShape2D,
# Area2D/frontswing, Area2D/downswing, Area2D/upswing.
# IMPORTANT: the screenshot calls the middle attack "side swing" in SpriteFrames,
# but the hitbox tree calls it "upswing". This script deliberately supports both.

signal fight_started
signal died
signal health_changed(current: int, maximum: int)

enum Mode { DORMANT, CHASE, WARNING, STRIKE, RECOVER, STUNNED, DEAD, EXHAUSTED, OBSTACLE_JUMP }
enum Slash { FRONT, SIDE, DOWN }

@export_group("Combat")
@export var max_hp: int = 30
@export var damage_per_hit: int = 1
@export var activation_radius: float = 165.0
@export var pursuit_speed: float = 92.0
@export var gravity: float = 980.0
@export var maximum_fall_speed: float = 680.0
@export var melee_reach: float = 105.0
@export var attack_interval: float = 0.22
@export var attack_interval_random: float = 0.18
@export var combo_chance: float = 0.87
@export var three_hit_combo_chance: float = 0.56
@export var max_combo: int = 5

@export_group("Dash Slashes")
@export var dash_speed: float = 1550.0
@export var dash_duration: float = 0.075
@export var dash_cooldown: float = 0.08
@export var dash_chance: float = 0.94
@export var dash_stop_distance: float = 16.0
@export var dash_attack_distance: float = 185.0

@export_group("Fair Warnings")
@export var front_warning: float = 0.70
@export var side_warning: float = 0.78
@export var down_warning: float = 0.84
@export var combo_warning: float = 0.48
@export var warning_flash_rate: float = 4.0
@export var combo_initial_warning_duration: float = 0.95
@export var combo_warning_flashes: int = 3
@export var fast_chain_gap: float = 0.045
@export var attack_animation_multiplier: float = 1.85
@export var front_animation_multiplier: float = 2.10
@export var endlag: float = 0.13
@export var combo_gap: float = 0.12

@export_group("Damage Stun")
@export var stun_duration: float = 1.0
@export var stun_immunity_period: float = 2.0

@export_group("Platform Waiting")
@export var unreachable_vertical_gap: float = 78.0
@export var platform_wait_horizontal_tolerance: float = 65.0
@export var wait_patrol_radius: float = 32.0

@export_group("Facing / Animations")
@export var sprite_faces_right_by_default: bool = true
@export var attack_hitboxes_face_right_by_default: bool = true
@export var animation_idle: StringName = &"idle"
@export var animation_walk: StringName = &"walk"
@export var animation_front: StringName = &"frontswing"
@export var animation_side: StringName = &"side swing"
@export var animation_down: StringName = &"downswing"
@export var animation_hurt: StringName = &"damagetaken"
@export var animation_death: StringName = &"new_animation"
@export var death_fade_seconds: float = 0.35
@export var front_hit_frame: int = 1
@export var side_hit_frame: int = 2
@export var down_hit_frame: int = 3
@export var slash_active_extra_frames: int = 2

@export_group("Dash Barrages / Fatigue")
@export var fatigue_after_min_attacks: int = 5
@export var fatigue_after_max_attacks: int = 8
@export var fatigue_duration_min: float = 6.0
@export var fatigue_duration_max: float = 9.0
@export var exhausted_flash_color: Color = Color(0.65, 0.76, 0.92, 1.0)
@export var combo_dash_min_distance: float = 12.0
@export var dash_overshoot: float = 20.0
@export var dash_max_distance: float = 116.0
@export_group("Obstacle Jumps")
@export_flags_2d_physics var solid_terrain_mask: int = 1
@export var wall_check_distance: float = 22.0
@export var small_obstacle_height: float = 42.0
@export var tall_obstacle_height: float = 105.0
@export var obstacle_jump_cooldown: float = 1.25
@export var small_jump_velocity: float = -350.0
@export var tall_jump_velocity: float = -535.0
@export var air_dash_speed: float = 515.0
@export var air_dash_max_duration: float = 0.31
@export var air_dash_chance: float = 0.65
@export var air_dash_slash_chance: float = 0.55
@export var air_dash_wait_time: float = 0.20
@export var jump_timeout: float = 1.85
@export var obstacle_detection_cooldown_when_blocked: float = 0.65
# Never change collision_mask to pass through terrain.


@export_group("Artifact Buff Integration")
# 0 is the default until you connect artifact pickup to Global's metadata.
# Your artifact pickups should increment Global.set_meta("artifacts_collected", count).
# An Inspector override is available if you want to test all buffs immediately.
@export_range(-1, 4, 1) var test_artifact_count_override: int = -1
# DEBUG: Activate all four artifact benefits automatically when this boss
# spots and engages the player, regardless of collected artifacts.
# Set to false later to restore the normal artifact progression.
@export var debug_grant_all_artifact_buffs_on_engage: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $Area2D
@onready var front_hitbox: CollisionShape2D = $Area2D/frontswing
@onready var down_hitbox: CollisionShape2D = $Area2D/downswing
@onready var side_hitbox: CollisionShape2D = $Area2D/upswing

var hp: int = 30
var target: Node2D = null
var mode: Mode = Mode.DORMANT
var engaged: bool = false
var facing_right: bool = true
var starting_position: Vector2
var warning_remaining: float = 0.0
var warning_elapsed: float = 0.0
var active_slash: Slash = Slash.FRONT
var attack_hit_done: bool = false
var strike_dash_remaining: float = 0.0
var dash_direction: float = 0.0
var dash_cd: float = 0.0
var attack_cd: float = 0.0
var stun_cd: float = 0.0
var stun_remaining: float = 0.0
var recovery_remaining: float = 0.0
var combo_total: int = 1
var combo_index: int = 0
var combo_pending: bool = false
var warning_original_color: Color = Color.WHITE
var last_slash: Slash = Slash.FRONT
var registered_player_hit: bool = false
var attacks_since_fatigue: int = 0
var fatigue_threshold: int = 6
var fatigue_remaining: float = 0.0
var attack_frame_timer: float = 0.0
var slash_window_done: bool = false
var dash_travel_elapsed: float = 0.0
var strike_animation_finished: bool = false
var death_animation_playing: bool = false
var face_sign_at_strike: float = 1.0
var authored_attack_area_scale: Vector2 = Vector2.ONE
var obstacle_jump_cd: float = 0.0
var obstacle_jump_time: float = 0.0
var obstacle_jump_direction: float = 0.0
var obstacle_tall_jump: bool = false
var obstacle_air_dash_remaining: float = 0.0
var obstacle_air_dash_used: bool = false
var obstacle_air_slash_pending: bool = false
var obstacle_was_airborne: bool = false
var obstacle_jump_start_y: float = 0.0
var obstacle_jump_committed: bool = false

func _ready() -> void:
	hp = maxi(1, max_hp)
	starting_position = global_position
	add_to_group(&"inimigo")
	add_to_group(&"enemy")
	add_to_group(&"menacing_skeleton")
	# We use collisions through shape geometry, not touch damage.
	attack_area.monitoring = true
	warning_original_color = sprite.self_modulate
	authored_attack_area_scale = attack_area.scale
	if not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if not sprite.animation_looped.is_connected(_on_animation_finished):
		sprite.animation_looped.connect(_on_animation_finished)
	_set_animation(animation_idle)
	health_changed.emit(hp, max_hp)
	fatigue_threshold = randi_range(fatigue_after_min_attacks, fatigue_after_max_attacks)

func _physics_process(delta: float) -> void:
	if mode == Mode.DEAD:
		return
	_find_player()
	attack_cd = maxf(0.0, attack_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	stun_cd = maxf(0.0, stun_cd - delta)
	obstacle_jump_cd = maxf(0.0, obstacle_jump_cd - delta)
	if not is_on_floor():
		velocity.y = minf(maximum_fall_speed, velocity.y + gravity * delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if not engaged:
		velocity.x = 0.0
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= activation_radius:
			_begin_fight()
		else:
			_set_animation(animation_idle)
		move_and_slide()
		return

	match mode:
		Mode.CHASE:
			_update_chase(delta)
		Mode.WARNING:
			_update_warning(delta)
		Mode.STRIKE:
			_update_strike(delta)
		Mode.RECOVER:
			_update_recovery(delta)
		Mode.STUNNED:
			_update_stun(delta)
		Mode.EXHAUSTED:
			_update_exhausted(delta)
		Mode.OBSTACLE_JUMP:
			_update_obstacle_jump(delta)
		_:
			velocity.x = 0.0
	move_and_slide()
	# Hitboxes are checked after movement so ultra-fast dashes do not
	# resolve their hit a physics tick before reaching the player.
	if mode == Mode.STRIKE:
		_check_strike_hit_window()

func _find_player() -> void:
	if is_instance_valid(target):
		return
	var found: Node = get_tree().get_first_node_in_group(&"player")
	if found is Node2D:
		target = found
		return
	var scene: Node = get_tree().current_scene
	if scene != null:
		var fallback: Node = scene.find_child("Player", true, false)
		if fallback is Node2D:
			target = fallback

func _get_collected_artifacts() -> int:
	if test_artifact_count_override >= 0:
		return test_artifact_count_override
	# The project has no artifact-state API attached to this script, so use a
	# stable single metadata key that can be written by the pickup logic.
	return clampi(int(Global.get_meta("artifacts_collected", 0)), 0, 4)

func _begin_fight() -> void:
	engaged = true
	mode = Mode.CHASE
	attack_cd = 0.60
	if is_instance_valid(target) and target.has_method(&"begin_menacing_skeleton_fight"):
		target.call(
			&"begin_menacing_skeleton_fight",
			4 if debug_grant_all_artifact_buffs_on_engage else _get_collected_artifacts()
		)
	fight_started.emit()

func _update_chase(_delta: float) -> void:
	if not is_instance_valid(target):
		velocity.x = 0.0
		_set_animation(animation_idle)
		return
	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y - global_position.y
	_face_player()
	# Never jump. Never wiggle below an unreachable player.
	if dy < -unreachable_vertical_gap:
		velocity.x = 0.0
		_set_animation(animation_idle)
		return
	if absf(dx) > melee_reach * 0.72:
		velocity.x = signf(dx) * pursuit_speed
		_set_animation(animation_walk)
		# Jumps only when a real solid object blocks the route.
		# This never causes idle hopping or a 60 Hz vibration below platforms.
		# Flat boss arena: deliberate ground-only movement.
		# The legacy obstacle helpers remain available but are not auto-triggered.
	else:
		velocity.x = 0.0
		_set_animation(animation_idle)
	if attack_cd > 0.0 or not is_on_floor():
		return
	if absf(dy) > unreachable_vertical_gap:
		return
	if absf(dx) <= dash_attack_distance:
		combo_total = 1
		if randf() < combo_chance:
			combo_total = 2
			if randf() < three_hit_combo_chance:
				combo_total = 3
		# Lace-style rush: several short dashes, each separately warned.
		if combo_total >= 3 and randf() < 0.65:
			combo_total += randi_range(1, 2)
		combo_total = mini(max_combo, combo_total)
		combo_index = 0
		_start_warning(_choose_slash(), false)

# ============================================================
# OBSTACLE PATHING
# ============================================================

func _terrain_hit(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = solid_terrain_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


func _try_start_obstacle_jump(direction: float) -> bool:
	if obstacle_jump_cd > 0.0 or not is_on_floor():
		return false
	if not is_instance_valid(target) or absf(direction) < 0.5:
		return false
	# Query ahead at feet, torso, and above the head. A wall above the
	# tallest jump is not a jumpable block, so the boss stays on the ground.
	var center := body_shape.global_position
	var dx := direction * wall_check_distance
	var low_y := center.y + 9.0
	var low := _terrain_hit(Vector2(center.x, low_y), Vector2(center.x + dx, low_y))
	if low.is_empty():
		return false
	var small_y := center.y - small_obstacle_height
	var small := _terrain_hit(Vector2(center.x, small_y), Vector2(center.x + dx, small_y))
	var high_y := center.y - tall_obstacle_height
	var high := _terrain_hit(Vector2(center.x, high_y), Vector2(center.x + dx, high_y))
	if not high.is_empty():
		obstacle_jump_cd = obstacle_detection_cooldown_when_blocked
		velocity.x = 0.0
		return false
	# Prevent jumping into a ceiling immediately above the boss.
	var overhead := _terrain_hit(
		Vector2(center.x, center.y - 21.0),
		Vector2(center.x, center.y - (tall_obstacle_height if not small.is_empty() else small_obstacle_height))
	)
	if not overhead.is_empty():
		obstacle_jump_cd = obstacle_detection_cooldown_when_blocked
		return false
	obstacle_tall_jump = not small.is_empty()
	obstacle_jump_cd = obstacle_jump_cooldown
	obstacle_jump_time = 0.0
	obstacle_jump_direction = direction
	obstacle_air_dash_remaining = 0.0
	obstacle_air_dash_used = false
	obstacle_air_slash_pending = false
	obstacle_was_airborne = false
	obstacle_jump_start_y = global_position.y
	obstacle_jump_committed = false
	velocity.y = tall_jump_velocity if obstacle_tall_jump else small_jump_velocity
	velocity.x = 0.0 if obstacle_tall_jump else direction * pursuit_speed
	mode = Mode.OBSTACLE_JUMP
	_set_animation(animation_idle if obstacle_tall_jump else animation_walk)
	return true


func _update_obstacle_jump(delta: float) -> void:
	obstacle_jump_time += delta
	if not is_instance_valid(target):
		_finish_obstacle_jump()
		return
	# On higher blocks, jump vertically first, then attack-dash forward at
	# the apex. For small blocks just keep moving forward normally.
	if not obstacle_tall_jump:
		velocity.x = obstacle_jump_direction * pursuit_speed
	else:
		if obstacle_air_dash_remaining > 0.0:
			obstacle_air_dash_remaining = maxf(0.0, obstacle_air_dash_remaining - delta)
			velocity.x = obstacle_jump_direction * air_dash_speed
		else:
			velocity.x = 0.0
			var sufficiently_high := global_position.y < obstacle_jump_start_y - small_obstacle_height
			var near_apex := velocity.y >= -100.0
			if not obstacle_air_dash_used and sufficiently_high and near_apex and obstacle_jump_time >= air_dash_wait_time:
				obstacle_air_dash_used = true
				obstacle_air_dash_remaining = air_dash_max_duration if randf() < air_dash_chance else 0.0
				if obstacle_air_dash_remaining > 0.0:
					velocity.x = obstacle_jump_direction * air_dash_speed
					# If the player is actually near the dash trajectory, schedule
					# the regular warned slash after landing. No unwarned hits.
					obstacle_air_slash_pending = randf() < air_dash_slash_chance
	if not is_on_floor():
		obstacle_was_airborne = true
	# Require actual flight followed by landing, not the starting floor.
	if obstacle_was_airborne and is_on_floor() and velocity.y >= 0.0:
		_finish_obstacle_jump()
		return
	if obstacle_jump_time >= jump_timeout:
		_finish_obstacle_jump()


func _finish_obstacle_jump() -> void:
	var wants_slash: bool = obstacle_air_slash_pending
	mode = Mode.CHASE
	obstacle_air_dash_remaining = 0.0
	obstacle_air_slash_pending = false
	velocity.x = 0.0
	if wants_slash and is_instance_valid(target):
		var dx := absf(target.global_position.x - global_position.x)
		var dy := absf(target.global_position.y - global_position.y)
		if dx <= dash_attack_distance and dy <= unreachable_vertical_gap:
			combo_total = 1
			combo_index = 0
			_start_warning(_choose_slash(), false)


func _choose_slash() -> Slash:
	# No consecutive identical attacks. This also holds across combos.
	var options: Array[int] = [Slash.FRONT, Slash.SIDE, Slash.DOWN]
	options.erase(last_slash)
	return options[randi_range(0, options.size() - 1)]


func _start_warning(slash: Slash, combo_followup: bool) -> void:
	mode = Mode.WARNING
	active_slash = slash
	warning_elapsed = 0.0
	warning_remaining = front_warning if slash == Slash.FRONT else (side_warning if slash == Slash.SIDE else down_warning)
	if not combo_followup and combo_total > 1:
		warning_remaining = maxf(combo_initial_warning_duration, warning_remaining)
	elif combo_followup:
		warning_remaining = maxf(0.02, fast_chain_gap)
	velocity.x = 0.0
	strike_dash_remaining = 0.0
	attack_hit_done = false
	_face_player()
	# Freeze the first frame, then telegraph with flashes before dash/slash.
	sprite.stop()
	sprite.animation = _slash_animation(slash)
	sprite.frame = 0
	sprite.frame_progress = 0.0

func _update_warning(delta: float) -> void:
	velocity.x = 0.0
	_face_player()
	warning_remaining = maxf(0.0, warning_remaining - delta)
	warning_elapsed += delta
	# Longer, readable warning precedes every actual high-speed dash.
	# Three strong warning pulses for a combo opener.
	var full_warning: float = maxf(0.01, warning_elapsed + warning_remaining)
	var pulses: float = float(combo_warning_flashes if combo_total > 1 and combo_index == 0 else 1)
	var progress: float = clampf(warning_elapsed / full_warning, 0.0, 1.0)
	var flash: bool = sin(progress * TAU * pulses) > 0.0
	sprite.self_modulate = Color(1.0, 0.40, 0.10, 1.0) if flash else warning_original_color
	if warning_remaining <= 0.0:
		_begin_strike()

func _begin_strike() -> void:
	mode = Mode.STRIKE
	sprite.self_modulate = warning_original_color
	attack_hit_done = false
	slash_window_done = false
	attack_frame_timer = 0.0
	dash_travel_elapsed = 0.0
	strike_animation_finished = false
	strike_dash_remaining = 0.0
	if is_instance_valid(target):
		var dx: float = target.global_position.x - global_position.x
		_face_player()
		var can_dash: bool = dash_cd <= 0.0 and absf(dx) > combo_dash_min_distance
		if can_dash and (combo_index > 0 or randf() < dash_chance):
			dash_direction = signf(dx)
			strike_dash_remaining = dash_duration
			dash_cd = dash_cooldown
	velocity.x = 0.0
	sprite.speed_scale = front_animation_multiplier if active_slash == Slash.FRONT else attack_animation_multiplier
	sprite.play(_slash_animation(active_slash))
	sprite.frame = 0
	sprite.frame_progress = 0.0


func _update_strike(delta: float) -> void:
	attack_frame_timer += delta
	if strike_dash_remaining > 0.0:
		strike_dash_remaining = maxf(0.0, strike_dash_remaining - delta)
		dash_travel_elapsed += delta
		velocity.x = dash_direction * dash_speed
		# A single burst travels only about one body-length.
		# It cannot cross the entire arena even if the target moves away.
		if dash_travel_elapsed * dash_speed >= dash_max_distance:
			strike_dash_remaining = 0.0
			velocity.x = 0.0
		if is_instance_valid(target):
			var dx: float = target.global_position.x - global_position.x
			# Stop after a small overshoot, never chase through an entire screen.
			if signf(dx) != dash_direction and absf(dx) > dash_overshoot:
				strike_dash_remaining = 0.0
	else:
		velocity.x = 0.0
	if strike_animation_finished and strike_dash_remaining <= 0.0:
		_end_strike()


func _on_frame_changed() -> void:
	# The animation event may happen BEFORE the physics step/dash displacement.
	# Do not consume the hit here. The current/next frames stay active and
	# are evaluated after move_and_slide().
	pass


func _check_strike_hit_window() -> void:
	if attack_hit_done or mode != Mode.STRIKE:
		return
	var wanted: int = front_hit_frame if active_slash == Slash.FRONT else (side_hit_frame if active_slash == Slash.SIDE else down_hit_frame)
	if sprite.frame < wanted:
		return
	if sprite.frame > wanted + maxi(0, slash_active_extra_frames) and not strike_animation_finished:
		return
	# Only count a hit once. If out of range on hit frame, retry for 2 frames.
	if _try_attack_hit():
		attack_hit_done = true


func _on_animation_finished() -> void:
	if mode == Mode.DEAD:
		if death_animation_playing and sprite.animation == animation_death:
			death_animation_playing = false
			queue_free()
		return
	if mode != Mode.STRIKE:
		return
	if sprite.animation != _slash_animation(active_slash):
		return
	# Preserve the complete physical dash even when the animation finishes
	# before the travel time is over.
	_check_strike_hit_window()
	strike_animation_finished = true
	sprite.stop()
	if strike_dash_remaining <= 0.0:
		_end_strike()


func _end_strike() -> void:
	last_slash = active_slash
	strike_dash_remaining = 0.0
	velocity.x = 0.0
	sprite.speed_scale = 1.0
	sprite.self_modulate = warning_original_color
	combo_index += 1
	attacks_since_fatigue += 1
	# Finish the full rapid sequence, then force a meaningful breathing window.
	if attacks_since_fatigue >= fatigue_threshold:
		_start_exhausted()
		return
	if combo_index < combo_total and is_instance_valid(target):
		# One three-flash warning, then rapid alternating dash/slash hits.
		var next_slash: Slash = _choose_slash()
		active_slash = next_slash
		_begin_strike()
		return
	mode = Mode.RECOVER
	recovery_remaining = endlag
	attack_cd = attack_interval + randf_range(0.0, attack_interval_random)
	_set_animation(animation_idle)


func _start_exhausted() -> void:
	mode = Mode.EXHAUSTED
	attacks_since_fatigue = 0
	fatigue_threshold = randi_range(
		maxi(2, fatigue_after_min_attacks),
		maxi(fatigue_after_min_attacks, fatigue_after_max_attacks)
	)
	fatigue_remaining = randf_range(fatigue_duration_min, fatigue_duration_max)
	attack_cd = 0.35
	velocity.x = 0.0
	strike_dash_remaining = 0.0
	sprite.speed_scale = 1.0
	sprite.self_modulate = exhausted_flash_color
	_set_animation(animation_idle)


func _update_exhausted(delta: float) -> void:
	velocity.x = 0.0
	fatigue_remaining -= delta
	# A short repeated exhausted flicker, very distinct from orange telegraphs.
	sprite.self_modulate = exhausted_flash_color.lerp(
		warning_original_color, 0.35 + sin(fatigue_remaining * 8.0) * 0.15
	)
	if fatigue_remaining <= 0.0:
		sprite.self_modulate = warning_original_color
		mode = Mode.CHASE


func _update_recovery(delta: float) -> void:
	velocity.x = 0.0
	recovery_remaining -= delta
	if recovery_remaining <= 0.0:
		mode = Mode.CHASE


func _update_stun(delta: float) -> void:
	velocity.x = 0.0
	stun_remaining -= delta
	if stun_remaining <= 0.0:
		mode = Mode.CHASE
		attack_cd = maxf(attack_cd, 0.30)
		_set_animation(animation_idle)


func _slash_animation(slash: Slash) -> StringName:
	match slash:
		Slash.FRONT:
			return animation_front
		Slash.SIDE:
			return animation_side
		_:
			return animation_down

func _set_animation(name: StringName) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(name):
		return
	if sprite.animation != name or not sprite.is_playing():
		sprite.speed_scale = 1.0
		sprite.play(name)

func _face_player() -> void:
	if not is_instance_valid(target):
		return
	var dx: float = target.global_position.x - global_position.x
	if absf(dx) <= 1.0:
		return
	facing_right = dx > 0.0
	sprite.flip_h = not facing_right if sprite_faces_right_by_default else facing_right
	# Mirror the ENTIRE authored Area2D so frontswing, downswing and
	# upswing keep their original shapes/offsets and all flip together.
	var mirror: float = 1.0 if facing_right == attack_hitboxes_face_right_by_default else -1.0
	attack_area.scale.x = absf(authored_attack_area_scale.x) * mirror

func _try_attack_hit() -> bool:
	if not is_instance_valid(target):
		return false
	var hitbox: CollisionShape2D = front_hitbox if active_slash == Slash.FRONT else (side_hitbox if active_slash == Slash.SIDE else down_hitbox)
	if not is_instance_valid(hitbox) or hitbox.disabled or hitbox.shape == null:
		return false
	# Check the authored attack hitboxes against the player's body hitbox.
	for child in target.find_children("*", "CollisionShape2D", true, false):
		if not child is CollisionShape2D:
			continue
		var other: CollisionShape2D = child as CollisionShape2D
		if other.disabled or other.shape == null or other.get_parent() != target:
			continue
		if hitbox.shape.collide(hitbox.global_transform, other.shape, other.global_transform):
			_apply_player_hit()
			return true

	return false


func _apply_player_hit() -> void:
	if target.has_method(&"tomar_dano"):
		target.call(&"tomar_dano", damage_per_hit, global_position)
	elif target.has_method(&"take_damage"):
		target.call(&"take_damage", damage_per_hit, global_position)


func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	_apply_damage(amount)

func take_damage(amount: int, _origin: Vector2 = Vector2.ZERO, _type: String = "") -> void:
	_apply_damage(amount)

func _apply_damage(amount: int) -> void:
	if mode == Mode.DEAD or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()
		return
	# Always takes damage, but cannot be stunned more than once per 2 seconds.
	if stun_cd <= 0.0:
		stun_cd = stun_immunity_period
		stun_remaining = stun_duration
		mode = Mode.STUNNED
		combo_index = 0
		strike_dash_remaining = 0.0
		obstacle_air_dash_remaining = 0.0
		obstacle_air_slash_pending = false
		velocity.x = 0.0
		sprite.self_modulate = warning_original_color
		sprite.speed_scale = 1.0
		_set_animation(animation_hurt)

func _die() -> void:
	if mode == Mode.DEAD:
		return
	mode = Mode.DEAD
	engaged = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	body_shape.set_deferred("disabled", true)
	attack_area.set_deferred("monitoring", false)
	sprite.self_modulate = warning_original_color
	sprite.speed_scale = 1.0
	sprite.stop()
	if is_instance_valid(target):
		if target.has_method(&"end_menacing_skeleton_fight"):
			target.call(&"end_menacing_skeleton_fight")
		if target.has_method(&"on_enemy_killed"):
			target.call(&"on_enemy_killed", self)
	died.emit()
	# In the screenshot the death animation was still named "new_animation".
	# If renamed to "death", switch automatically.
	if sprite.sprite_frames != null:
		var death_name: StringName = animation_death
		if not sprite.sprite_frames.has_animation(death_name):
			death_name = &"death"
		if sprite.sprite_frames.has_animation(death_name):
			animation_death = death_name
			sprite.play(death_name)
			death_animation_playing = true
			# Backup for a looping animation.
			var frames: int = sprite.sprite_frames.get_frame_count(death_name)
			var fps: float = maxf(1.0, sprite.sprite_frames.get_animation_speed(death_name))
			get_tree().create_timer(float(frames) / fps + 0.15).timeout.connect(
				func() -> void:
					if is_instance_valid(self) and mode == Mode.DEAD:
						queue_free()
			)
			return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, death_fade_seconds)
	tween.tween_callback(queue_free)
