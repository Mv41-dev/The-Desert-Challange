# V15 - King Necromancer summon integration without artifact-mode side effects
extends CharacterBody2D
# Menacing Skeleton miniboss, Godot 4.x.
# Scene children (exact): AnimatedSprite2D, CollisionShape2D,
# Area2D/frontswing, Area2D/downswing, Area2D/upswing.
# IMPORTANT: the screenshot calls the middle attack "side swing" in SpriteFrames,
# but the hitbox tree calls it "upswing". This script deliberately supports both.

signal fight_started
signal died
signal health_changed(current: int, maximum: int)

enum Mode { DORMANT, CHASE, WARNING, STRIKE, RECOVER, STUNNED, DEAD, EXHAUSTED, OBSTACLE_JUMP, JUMP_SLAM, EVADE }
enum Slash { FRONT, SIDE, DOWN }

@export_group("Combat")
@export var max_hp: int = 50
@export var damage_per_hit: int = 1
@export var activation_radius: float = 165.0
@export var pursuit_speed: float = 92.0
@export var gravity: float = 980.0
@export var maximum_fall_speed: float = 680.0
@export var melee_reach: float = 105.0
@export var attack_interval: float = 0.80
@export var attack_interval_random: float = 0.10

@export_group("Sword Attacks")
@export var dash_attack_distance: float = 310.0
@export var attack_warning_seconds: float = 0.58
@export var attack_warning_color: Color = Color(1.0, 0.72, 0.32)
@export var combo_swing_seconds: float = 0.19
@export var combo_followup_pause: float = 0.025
@export var combo_dash_seconds: float = 0.10
@export var combo_dash_distance: float = 52.0
@export var point_blank_distance: float = 60.0
@export var point_blank_warning_seconds: float = 0.82
@export var point_blank_commit_seconds: float = 0.13
@export var point_blank_followup_pause: float = 0.12
@export var point_blank_swing_seconds: float = 0.23
@export_range(0.0, 1.0) var alternate_combo_chance: float = 0.30
@export var endlag: float = 1.50
@export_range(0.0, 1.0) var advancing_slam_chance: float = 0.18
@export var advancing_slam_warning_seconds: float = 0.72
@export var advancing_slam_distance: float = 104.0
@export var advancing_slam_seconds: float = 0.30

@export_group("Jump Slam and Evasion")
@export_range(0.0, 1.0) var jump_slam_chance: float = 0.30
@export var jump_slam_range: float = 155.0
@export var jump_slam_warning_seconds: float = 0.55
@export var jump_slam_launch_speed: float = 305.0
@export var jump_slam_move_speed: float = 235.0
@export_range(0.0, 1.0) var evade_chance: float = 0.24
@export var evade_distance: float = 42.0
@export var evade_speed: float = 230.0
@export var evade_cooldown_seconds: float = 2.4

@export_group("Long Lunge")
@export_range(0.0, 1.0) var close_lunge_chance: float = 0.23
@export var lunge_warning_seconds: float = 0.78
@export var lunge_retreat_distance: float = 34.0
@export var lunge_retreat_speed: float = 160.0
@export var lunge_speed: float = 850.0
@export var lunge_min_distance: float = 115.0
@export var lunge_max_distance: float = 320.0
@export var lunge_past_target: float = 36.0

@export_group("Parry")
@export var parry_cancel_recovery: float = 1.50
@export var parry_counter_damage: int = 5

@export_group("Damage Stun")
@export var stun_duration: float = 0.65
@export var stun_immunity_period: float = 4.5

@export_group("Platform Waiting")
@export var unreachable_vertical_gap: float = 78.0
@export var platform_wait_horizontal_tolerance: float = 65.0
@export var wait_patrol_radius: float = 32.0

@export_group("Facing / Animations")
@export var sprite_faces_right_by_default: bool = true
@export var sprite_alignment_x: float = 27.0
# Body bounds in the centered sprite frame, before scale and facing.
@export var body_damage_rect: Rect2 = Rect2(-61.0, -38.0, 60.0, 60.0)
@export var frontswing_body_shift_x: float = 26.0
@export var upswing_body_shift_x: float = 16.0
@export var rear_torso_rect: Rect2 = Rect2(-50.0, -29.0, 29.0, 47.0)
@export_range(0.0, 8.0, 0.5) var sword_contact_margin: float = 3.0
@export var show_damage_hitbox: bool = false
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
@export var slash_active_extra_frames: int = 1

@export_group("Dash Barrages / Fatigue")
@export var fatigue_after_min_attacks: int = 9
@export var fatigue_after_max_attacks: int = 12
@export var fatigue_duration_min: float = 2.6
@export var fatigue_duration_max: float = 3.8
@export var exhausted_flash_color: Color = Color(0.65, 0.76, 0.92, 1.0)

@export_group("Low HP Desperation")
@export_range(0.05, 0.95, 0.01) var desperation_hp_ratio: float = 0.25
@export var desperation_walk_multiplier: float = 1.34
@export var desperation_fatigue_min_attacks: int = 15
@export var desperation_fatigue_max_attacks: int = 20
@export var desperation_fatigue_min_seconds: float = 0.65
@export var desperation_fatigue_max_seconds: float = 1.15
@export var desperation_attack_cd_multiplier: float = 0.55

@export_group("Obstacle Jumps")
@export_flags_2d_physics var solid_terrain_mask: int = 1
@export var wall_check_distance: float = 22.0
@export var small_obstacle_height: float = 42.0
@export var tall_obstacle_height: float = 105.0
@export var obstacle_jump_cooldown: float = 1.25
@export var small_jump_velocity: float = -350.0
@export var tall_jump_velocity: float = -535.0
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

var hp: int = 55
var target: Node2D = null
var mode: Mode = Mode.DORMANT
var engaged: bool = false
var facing_right: bool = true
var starting_position: Vector2
var active_slash: Slash = Slash.FRONT
var attack_hit_done: bool = false
var dash_direction: float = 0.0
var attack_cd: float = 0.0
var stun_cd: float = 0.0
var stun_remaining: float = 0.0
var recovery_remaining: float = 0.0
var combo_index: int = 0
var original_sprite_color: Color = Color.WHITE
var registered_player_hit: bool = false
var attacks_since_fatigue: int = 0
var fatigue_threshold: int = 10
var fatigue_remaining: float = 0.0
var strike_dash_distance: float = 0.0
var strike_dash_seconds: float = 0.0
var strike_elapsed: float = 0.0
var strike_duration: float = 0.0
var strike_first_frame: int = 0
var lunge_attack: bool = false
var advancing_slam: bool = false
var warning_duration: float = 0.0
var warning_frame_count: int = 0
var strike_commit_remaining: float = 0.0
var combo_order: Array[Slash] = [Slash.DOWN, Slash.SIDE, Slash.FRONT]
var combo_pause_remaining: float = 0.0
var death_animation_playing: bool = false
var authored_attack_area_transform: Transform2D
var authored_sprite_transform: Transform2D
var facing_pivot_x: float = 0.0
var committed_target_x: float = 0.0
var point_blank_attack: bool = false
var jump_slam: bool = false
var jump_slam_airborne: bool = false
var jump_slam_elapsed: float = 0.0
var evade_cd: float = 0.0
var hurtbox := RectangleShape2D.new()
var lunge_backstep_remaining: float = 0.0
var lunge_backstep_direction: float = 0.0
var obstacle_jump_cd: float = 0.0
var obstacle_jump_time: float = 0.0
var obstacle_jump_direction: float = 0.0
var obstacle_tall_jump: bool = false
var obstacle_was_airborne: bool = false
var obstacle_jump_start_y: float = 0.0
var obstacle_jump_committed: bool = false
var pass_through_player: PhysicsBody2D = null
var low_hp_phase_seen: bool = false

func _ready() -> void:
	hp = maxi(1, max_hp)
	starting_position = global_position
	add_to_group(&"inimigo")
	add_to_group(&"enemy")
	add_to_group(&"menacing_skeleton")
	# We use collisions through shape geometry, not touch damage.
	attack_area.monitoring = true
	original_sprite_color = sprite.self_modulate
	authored_attack_area_transform = attack_area.transform
	authored_sprite_transform = sprite.transform
	authored_sprite_transform.origin.x += sprite_alignment_x
	facing_pivot_x = body_shape.position.x
	hurtbox.size = body_damage_rect.size
	_apply_facing()
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if not sprite.animation_looped.is_connected(_on_animation_finished):
		sprite.animation_looped.connect(_on_animation_finished)
	_set_animation(animation_idle)
	_find_player()
	_ensure_player_pass_through()
	health_changed.emit(hp, max_hp)
	fatigue_threshold = randi_range(fatigue_after_min_attacks, fatigue_after_max_attacks)

func _physics_process(delta: float) -> void:
	if mode == Mode.DEAD:
		return
	_find_player()
	_ensure_player_pass_through()
	attack_cd = maxf(0.0, attack_cd - delta)
	evade_cd = maxf(0.0, evade_cd - delta)
	stun_cd = maxf(0.0, stun_cd - delta)
	obstacle_jump_cd = maxf(0.0, obstacle_jump_cd - delta)
	if _is_desperate() and not low_hp_phase_seen:
		low_hp_phase_seen = true
		attacks_since_fatigue = 0
		fatigue_threshold = _roll_fatigue_threshold()
		if mode == Mode.EXHAUSTED:
			fatigue_remaining = minf(fatigue_remaining, desperation_fatigue_max_seconds)
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
			_update_attack_warning(delta)
		Mode.STRIKE:
			_update_strike(delta)
		Mode.RECOVER:
			_update_recovery(delta)
		Mode.STUNNED:
			_update_stun(delta)
		Mode.EXHAUSTED:
			_update_exhausted(delta)
		Mode.JUMP_SLAM:
			_update_jump_slam(delta)
		Mode.EVADE:
			_update_evade(delta)
		Mode.OBSTACLE_JUMP:
			_update_obstacle_jump(delta)
		_:
			velocity.x = 0.0
	move_and_slide()
	if mode == Mode.STRIKE:
		_check_strike_hit_window()
	if show_damage_hitbox:
		queue_redraw()

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

func _ensure_player_pass_through() -> void:
	# Separate the two BODY colliders without touching any authored
	# Area2D sword hitboxes or the player attack hitboxes.
	var body: PhysicsBody2D = target as PhysicsBody2D if target is PhysicsBody2D else null
	if body == pass_through_player:
		return
	if is_instance_valid(pass_through_player):
		remove_collision_exception_with(pass_through_player)
		pass_through_player.remove_collision_exception_with(self)
	pass_through_player = body
	if is_instance_valid(pass_through_player):
		add_collision_exception_with(pass_through_player)
		pass_through_player.add_collision_exception_with(self)


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
	# King's summons are elite guards, not independent artifact minibosses.
	# Their attacks/parry behavior stays intact without changing Kris's buffs.
	if not bool(get_meta(&"king_necromancer_summon", false)):
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
	var direction := signf(dx)
	var grounded := is_on_floor()
	if absf(dx) > melee_reach * 0.72:
		if grounded and _try_start_obstacle_jump(direction):
			return
		velocity.x = direction * pursuit_speed * (desperation_walk_multiplier if _is_desperate() else 1.0)
		if grounded and not _has_ground_ahead(direction):
			velocity.x = 0.0
		_set_animation(animation_walk if absf(velocity.x) > 0.0 else animation_idle)
	else:
		velocity.x = 0.0
		_set_animation(animation_idle)
	if attack_cd > 0.0 or not grounded or absf(dy) > unreachable_vertical_gap:
		return
	if absf(dx) <= dash_attack_distance and _warning_visible_at(global_position):
		if not _try_evade():
			_start_attack_pattern()


func _body_half_size() -> Vector2:
	var rectangle := body_shape.shape as RectangleShape2D
	if rectangle == null:
		return Vector2(12.0, 20.0)
	return rectangle.size * body_shape.global_scale.abs() * 0.5


func _has_ground_ahead(direction: float) -> bool:
	var center := body_shape.global_position
	var half_width := _body_half_size().x
	var probe := Vector2(center.x + direction * (half_width + 8.0), center.y)
	return not _terrain_hit(probe, probe + Vector2(0.0, 65.0)).is_empty()

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
	var half_width := _body_half_size().x
	var dx := direction * (half_width + wall_check_distance)
	var low_y := center.y + maxf(2.0, _body_half_size().y - 5.0)
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
	velocity.x = obstacle_jump_direction * pursuit_speed
	if not is_on_floor():
		obstacle_was_airborne = true
	# Require actual flight followed by landing, not the starting floor.
	if obstacle_was_airborne and is_on_floor() and velocity.y >= 0.0:
		_finish_obstacle_jump()
		return
	if obstacle_jump_time >= jump_timeout:
		_finish_obstacle_jump()


func _finish_obstacle_jump() -> void:
	mode = Mode.CHASE
	velocity.x = 0.0


func _target_in_melee_range() -> bool:
	if not is_instance_valid(target):
		return false
	var offset: Vector2 = target.global_position - global_position
	return absf(offset.x) <= melee_reach and absf(offset.y) <= unreachable_vertical_gap


func _target_at_point_blank() -> bool:
	return _target_in_melee_range() and absf(target.global_position.x - global_position.x) <= point_blank_distance


func _start_attack_pattern() -> void:
	mode = Mode.WARNING
	combo_index = 0
	combo_pause_remaining = 0.0
	point_blank_attack = _target_at_point_blank()
	var gap := absf(target.global_position.x - global_position.x)
	jump_slam = gap <= jump_slam_range and randf() < jump_slam_chance and not test_move(global_transform, Vector2(0.0, -48.0))
	lunge_attack = not jump_slam and (not _target_in_melee_range() or (not point_blank_attack and randf() < close_lunge_chance))
	advancing_slam = not jump_slam and not lunge_attack and not point_blank_attack and randf() < advancing_slam_chance
	combo_order.assign([Slash.DOWN, Slash.SIDE, Slash.FRONT])
	if not jump_slam and not point_blank_attack and not lunge_attack and not advancing_slam and randf() < alternate_combo_chance:
		if randf() < 0.5:
			combo_order.assign([Slash.DOWN, Slash.FRONT, Slash.SIDE])
		else:
			combo_order.assign([Slash.SIDE, Slash.DOWN, Slash.FRONT])
	velocity.x = 0.0
	lunge_backstep_remaining = 0.0
	_face_player()
	committed_target_x = target.global_position.x

	if lunge_attack:
		var direction := 1.0 if facing_right else -1.0
		var retreat := clampf(lunge_max_distance - gap - lunge_past_target, 0.0, lunge_retreat_distance)
		lunge_backstep_direction = -direction
		lunge_backstep_remaining = _safe_backstep_distance(lunge_backstep_direction, retreat)
		warning_duration = lunge_warning_seconds
		warning_frame_count = 1 if _pose_attack(Slash.FRONT) else 0
		sprite.self_modulate = attack_warning_color
	else:
		var opener := combo_order[0]
		if point_blank_attack and not jump_slam:
			opener = [Slash.DOWN, Slash.SIDE, Slash.FRONT][randi_range(0, 2)]
			combo_order[0] = opener
		warning_duration = advancing_slam_warning_seconds if advancing_slam else attack_warning_seconds
		if jump_slam:
			warning_duration = jump_slam_warning_seconds
		if point_blank_attack:
			warning_duration = maxf(warning_duration, point_blank_warning_seconds)
		warning_frame_count = 0
		if _pose_attack(opener):
			var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
			warning_frame_count = clampi(_hit_frame(opener), 0, frame_count - 1)
		sprite.self_modulate = original_sprite_color
	recovery_remaining = maxf(0.01, warning_duration)

func _warning_visible_at(world_position: Vector2) -> bool:
	var visible_area := get_viewport_rect().grow(-12.0)
	return visible_area.has_point(get_canvas_transform() * (world_position + Vector2(0.0, -12.0)))


func _safe_backstep_distance(direction: float, distance: float) -> float:
	# Keep the retreat on screen and on supported terrain.
	for fraction in [1.0, 0.66, 0.33]:
		var offset := Vector2(direction * distance * float(fraction), 0.0)
		if not _warning_visible_at(global_position + offset) or test_move(global_transform, offset):
			continue
		var destination := global_transform
		destination.origin += offset
		var floor_hit := KinematicCollision2D.new()
		if test_move(destination, Vector2(0.0, 8.0), floor_hit):
			if floor_hit.get_normal().dot(up_direction) >= cos(floor_max_angle):
				return absf(offset.x)
	return 0.0


func _update_attack_warning(delta: float) -> void:
	velocity.x = 0.0
	recovery_remaining -= delta
	if recovery_remaining > 0.0:
		if lunge_backstep_remaining > 0.0 and is_on_floor() and not is_on_wall():
			var step := minf(lunge_backstep_remaining, lunge_retreat_speed * delta)
			velocity.x = lunge_backstep_direction * step / delta
			lunge_backstep_remaining -= step
		if not lunge_attack and warning_frame_count > 0:
			var progress := 1.0 - recovery_remaining / maxf(0.01, warning_duration)
			_update_strike_frame(progress, 0, warning_frame_count)
		return
	if jump_slam:
		_start_jump_slam()
	else:
		_begin_strike(Slash.FRONT if lunge_attack else combo_order[0])


func _try_evade() -> bool:
	if not _target_at_point_blank() or evade_cd > 0.0:
		return false
	if not target.has_method(&"is_swinging") or not bool(target.call(&"is_swinging")):
		return false
	evade_cd = evade_cooldown_seconds
	if randf() >= evade_chance:
		return false
	lunge_backstep_direction = -1.0 if facing_right else 1.0
	lunge_backstep_remaining = _safe_backstep_distance(lunge_backstep_direction, evade_distance)
	if lunge_backstep_remaining <= 0.0:
		return false
	mode = Mode.EVADE
	velocity.x = 0.0
	_set_animation(animation_walk)
	return true


func _update_evade(delta: float) -> void:
	velocity.x = 0.0
	if lunge_backstep_remaining <= 0.0 or not is_on_floor():
		attack_cd = maxf(attack_cd, 0.28)
		mode = Mode.CHASE
		_set_animation(animation_idle)
		return
	var step := minf(lunge_backstep_remaining, maxf(1.0, evade_speed) * delta)
	velocity.x = lunge_backstep_direction * step / delta
	lunge_backstep_remaining -= step


func _start_jump_slam() -> void:
	mode = Mode.JUMP_SLAM
	jump_slam_airborne = false
	jump_slam_elapsed = 0.0
	velocity = Vector2(0.0, -absf(jump_slam_launch_speed))
	if warning_frame_count > 0:
		sprite.set_frame_and_progress(warning_frame_count - 1, 0.0)


func _update_jump_slam(delta: float) -> void:
	jump_slam_elapsed += delta
	if is_on_floor() and jump_slam_airborne:
		_begin_strike(Slash.DOWN)
		return
	if jump_slam_elapsed >= jump_timeout:
		_finish_attack_pattern()
		return
	if not is_on_floor():
		jump_slam_airborne = true
	var direction := 1.0 if facing_right else -1.0
	var gap := maxf(0.0, (committed_target_x - global_position.x) * direction)
	velocity.x = direction * minf(jump_slam_move_speed, gap / delta)


func _pose_attack(slash: Slash) -> bool:
	var animation := _slash_animation(slash)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return false
	if sprite.sprite_frames.get_frame_count(animation) == 0:
		return false
	sprite.play(animation)
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)
	return true


func _begin_strike(slash: Slash) -> void:
	active_slash = slash
	attack_hit_done = false
	strike_elapsed = 0.0
	strike_commit_remaining = 0.0
	velocity.x = 0.0
	# All swings use the facing chosen when the windup began.
	dash_direction = 1.0 if facing_right else -1.0
	if not _pose_attack(slash):
		_finish_attack_pattern()
		return

	mode = Mode.STRIKE
	sprite.self_modulate = original_sprite_color
	var close_swing := point_blank_attack
	strike_duration = maxf(0.06, point_blank_swing_seconds if close_swing else combo_swing_seconds)
	strike_dash_seconds = minf(strike_duration, combo_dash_seconds)
	strike_dash_distance = combo_dash_distance
	strike_first_frame = warning_frame_count if combo_index == 0 else 0
	if advancing_slam:
		strike_duration = maxf(0.06, advancing_slam_seconds)
		strike_dash_seconds = strike_duration
		strike_dash_distance = advancing_slam_distance
	if lunge_attack:
		var gap := maxf(0.0, (committed_target_x - global_position.x) * dash_direction)
		var distance := clampf(gap + lunge_past_target, lunge_min_distance, maxf(lunge_min_distance, lunge_max_distance))
		var wall_hit := KinematicCollision2D.new()
		if test_move(global_transform, Vector2(dash_direction * distance, 0.0), wall_hit):
			distance = clampf(wall_hit.get_travel().x * dash_direction, 0.0, distance)
		strike_dash_distance = distance
		strike_duration = maxf(0.22, distance / maxf(1.0, lunge_speed))
		strike_dash_seconds = strike_duration
		strike_first_frame = mini(1, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
	if jump_slam or close_swing or (not lunge_attack and _target_at_point_blank()):
		strike_dash_distance = 0.0
	strike_first_frame = clampi(strike_first_frame, 0, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
	if close_swing and not jump_slam and combo_index == 0:
		strike_commit_remaining = maxf(0.0, point_blank_commit_seconds)
	var pose_frame := maxi(0, strike_first_frame - 1) if strike_commit_remaining > 0.0 else strike_first_frame
	sprite.set_frame_and_progress(pose_frame, 0.0)


func _update_strike(delta: float) -> void:
	if strike_commit_remaining > 0.0:
		strike_commit_remaining = maxf(0.0, strike_commit_remaining - delta)
		velocity.x = 0.0
		return
	if strike_elapsed >= strike_duration:
		_end_strike()
		return
	var previous_time := strike_elapsed
	strike_elapsed = minf(strike_duration, strike_elapsed + delta)
	var dash_time := minf(strike_elapsed, strike_dash_seconds) - minf(previous_time, strike_dash_seconds)
	velocity.x = 0.0
	if strike_dash_seconds > 0.0:
		velocity.x = dash_direction * strike_dash_distance * dash_time / (strike_dash_seconds * delta)
	_update_strike_frame(strike_elapsed / strike_duration, strike_first_frame, sprite.sprite_frames.get_frame_count(sprite.animation))


func _update_strike_frame(progress: float, first_frame: int, frame_end: int) -> void:
	var frames := sprite.sprite_frames
	var animation := sprite.animation
	var weight := 0.0
	for index in range(first_frame, frame_end):
		weight += frames.get_frame_duration(animation, index)
	var cursor := progress * weight
	for index in range(first_frame, frame_end):
		var frame_weight := frames.get_frame_duration(animation, index)
		if cursor < frame_weight or index == frame_end - 1:
			sprite.set_frame_and_progress(index, clampf(cursor / maxf(0.001, frame_weight), 0.0, 1.0))
			return
		cursor -= frame_weight


func _hit_frame(slash: Slash) -> int:
	match slash:
		Slash.FRONT:
			return front_hit_frame
		Slash.SIDE:
			return side_hit_frame
		_:
			return down_hit_frame


func _check_strike_hit_window() -> void:
	if attack_hit_done or mode != Mode.STRIKE or strike_commit_remaining > 0.0:
		return
	if not lunge_attack:
		var wanted := clampi(_hit_frame(active_slash), 0, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
		if sprite.frame < wanted or sprite.frame > wanted + maxi(0, slash_active_extra_frames):
			return
	# The lunge can connect once along its committed path, through the sword shape.
	if _try_attack_hit():
		attack_hit_done = true


func _on_animation_finished() -> void:
	if mode == Mode.DEAD and death_animation_playing and sprite.animation == animation_death:
		death_animation_playing = false
		queue_free()


func _end_strike() -> void:
	velocity.x = 0.0
	combo_index += 1
	attacks_since_fatigue += 1
	if jump_slam or point_blank_attack or lunge_attack or advancing_slam or combo_index >= combo_order.size():
		_finish_attack_pattern()
		return
	var followup_pause := point_blank_followup_pause if point_blank_attack else combo_followup_pause
	combo_pause_remaining = maxf(0.01, followup_pause)
	mode = Mode.RECOVER


func _finish_attack_pattern() -> void:
	sprite.self_modulate = original_sprite_color
	if attacks_since_fatigue >= fatigue_threshold:
		_start_exhausted()
		return
	mode = Mode.RECOVER
	recovery_remaining = endlag
	attack_cd = (attack_interval + randf_range(0.0, attack_interval_random)) * (desperation_attack_cd_multiplier if _is_desperate() else 1.0)
	_set_animation(animation_idle)


func _start_exhausted() -> void:
	mode = Mode.EXHAUSTED
	combo_pause_remaining = 0.0
	attacks_since_fatigue = 0
	fatigue_threshold = _roll_fatigue_threshold()
	fatigue_remaining = (randf_range(desperation_fatigue_min_seconds, desperation_fatigue_max_seconds)
		if _is_desperate() else randf_range(fatigue_duration_min, fatigue_duration_max))
	attack_cd = 0.35
	velocity.x = 0.0
	sprite.speed_scale = 1.0
	sprite.self_modulate = exhausted_flash_color
	_set_animation(animation_idle)


func _update_exhausted(delta: float) -> void:
	velocity.x = 0.0
	fatigue_remaining -= delta
	# A short repeated flicker during exhaustion.
	sprite.self_modulate = exhausted_flash_color.lerp(
		original_sprite_color, 0.35 + sin(fatigue_remaining * 8.0) * 0.15
	)
	if fatigue_remaining <= 0.0:
		sprite.self_modulate = original_sprite_color
		mode = Mode.CHASE


func _update_recovery(delta: float) -> void:
	velocity.x = 0.0
	if combo_pause_remaining > 0.0:
		combo_pause_remaining = maxf(0.0, combo_pause_remaining - delta)
		if combo_pause_remaining <= 0.0:
			_continue_attack_pattern()
		return
	recovery_remaining -= delta
	if recovery_remaining <= 0.0:
		mode = Mode.CHASE
		sprite.self_modulate = original_sprite_color


func _continue_attack_pattern() -> void:
	_begin_strike(combo_order[combo_index])


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
	var dx: float = target.global_position.x - body_shape.global_position.x
	if absf(dx) <= 3.0:
		return
	var next_facing_right := dx > 0.0
	if next_facing_right == facing_right:
		return
	facing_right = next_facing_right
	_apply_facing()
	sprite.reset_physics_interpolation()
	attack_area.reset_physics_interpolation()


func _apply_facing() -> void:
	# Reflect both the basis and the offset around the fixed body collider.
	var reflection := Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(2.0 * facing_pivot_x, 0.0))
	sprite.transform = authored_sprite_transform if facing_right == sprite_faces_right_by_default else reflection * authored_sprite_transform
	attack_area.transform = authored_attack_area_transform if facing_right == attack_hitboxes_face_right_by_default else reflection * authored_attack_area_transform
	if show_damage_hitbox:
		queue_redraw()

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
	if not is_instance_valid(target):
		return
	if target.has_method(&"try_parry_menacing_hit"):
		if bool(target.call(&"try_parry_menacing_hit", global_position)):
			_on_parried()
			return
	if target.has_method(&"tomar_dano"):
		target.call(&"tomar_dano", damage_per_hit, global_position)
	elif target.has_method(&"take_damage"):
		target.call(&"take_damage", damage_per_hit, global_position)


func _on_parried() -> void:
	# A perfect F clash CANCELS the authored sword attack immediately.
	if mode == Mode.DEAD:
		return
	velocity.x = 0.0
	attack_hit_done = true
	# Retaliation damages the boss, but cannot cause another regular stun.
	var amount: int = parry_counter_damage
	if target != null:
		var possible_damage: Variant = target.get("miniboss_parry_counter_damage")
		if possible_damage is int:
			amount = maxi(1, int(possible_damage))
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()
		return
	mode = Mode.RECOVER
	recovery_remaining = parry_cancel_recovery
	combo_index = 0
	combo_pause_remaining = 0.0
	attack_cd = maxf(attack_cd, 0.24)
	sprite.speed_scale = 1.0
	sprite.self_modulate = Color(0.55, 0.97, 1.0)
	_set_animation(animation_hurt)


func _is_desperate() -> bool:
	return hp > 0 and float(hp) <= float(max_hp) * desperation_hp_ratio


func _roll_fatigue_threshold() -> int:
	if _is_desperate():
		return randi_range(maxi(2, desperation_fatigue_min_attacks), maxi(desperation_fatigue_min_attacks, desperation_fatigue_max_attacks))
	return randi_range(maxi(2, fatigue_after_min_attacks), maxi(fatigue_after_min_attacks, fatigue_after_max_attacks))


func _current_body_damage_rect() -> Rect2:
	var rect := body_damage_rect
	# These atlas animations shift the torso inside the frame.
	if sprite.animation == animation_front:
		rect.position.x += frontswing_body_shift_x
	elif sprite.animation == animation_side:
		rect.position.x += upswing_body_shift_x
	return rect


func _world_bounds(rect: Rect2, pose: Transform2D) -> Rect2:
	var bounds := Rect2(pose * rect.position, Vector2.ZERO)
	bounds = bounds.expand(pose * Vector2(rect.end.x, rect.position.y))
	bounds = bounds.expand(pose * Vector2(rect.position.x, rect.end.y))
	return bounds.expand(pose * rect.end)


func _rear_torso_bounds() -> Rect2:
	return _world_bounds(rear_torso_rect, sprite.global_transform).grow(sword_contact_margin)


func _damage_contact_bounds() -> Rect2:
	return _world_bounds(_current_body_damage_rect(), sprite.global_transform).grow(sword_contact_margin)


func _draw() -> void:
	if show_damage_hitbox and mode != Mode.DEAD:
		var bounds := _damage_contact_bounds()
		draw_set_transform_matrix(global_transform.affine_inverse())
		draw_rect(bounds, Color(0.2, 1.0, 0.5, 0.9), false, 1.0)
		if sprite.animation == animation_front or sprite.animation == animation_side:
			draw_rect(_rear_torso_bounds(), Color(0.2, 1.0, 0.5, 0.9), false, 1.0)


func attack_shape_hits_hurtbox(attack_shape: CollisionShape2D) -> bool:
	if mode == Mode.DEAD or attack_shape.disabled or attack_shape.shape == null:
		return false
	var rectangle := attack_shape.shape as RectangleShape2D
	if rectangle != null:
		# Compare the world bounds directly so reflected and scaled sprites
		# use the same contact test on both sides.
		var sword := _world_bounds(Rect2(-rectangle.size * 0.5, rectangle.size), attack_shape.global_transform)
		if sword.intersects(_damage_contact_bounds(), true):
			return true
		# The swing pose shifts the front box, but the rear torso stays hittable.
		return (sprite.animation == animation_front or sprite.animation == animation_side) and sword.intersects(_rear_torso_bounds(), true)
	var hurtbox_transform := sprite.global_transform * Transform2D(0.0, _current_body_damage_rect().get_center())
	return attack_shape.shape.collide(attack_shape.global_transform, hurtbox, hurtbox_transform)

func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	_apply_damage(amount)


func take_damage(amount: int, origin: Vector2 = Vector2.ZERO) -> void:
	tomar_dano(amount, origin)


func is_dead() -> bool:
	return mode == Mode.DEAD


func _apply_damage(amount: int) -> void:
	if mode == Mode.DEAD or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()
		return
	# Always takes damage, but stun is limited by the configured immunity window.
	if mode == Mode.EXHAUSTED or (mode == Mode.RECOVER and combo_pause_remaining <= 0.0):
		return
	if stun_cd <= 0.0:
		stun_cd = stun_immunity_period
		stun_remaining = stun_duration
		mode = Mode.STUNNED
		combo_index = 0
		combo_pause_remaining = 0.0
		velocity.x = 0.0
		sprite.self_modulate = original_sprite_color
		sprite.speed_scale = 1.0
		_set_animation(animation_hurt)

func _die() -> void:
	if mode == Mode.DEAD:
		return
	mode = Mode.DEAD
	if show_damage_hitbox:
		queue_redraw()
	engaged = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	body_shape.set_deferred("disabled", true)
	attack_area.set_deferred("monitoring", false)
	sprite.self_modulate = original_sprite_color
	sprite.speed_scale = 1.0
	sprite.stop()
	if is_instance_valid(target):
		if not bool(get_meta(&"king_necromancer_summon", false)):
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
