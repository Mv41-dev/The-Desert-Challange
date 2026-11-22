extends Node2D
class_name RisingAbyssVoid


enum RecoveryState { NONE, WAIT_FOR_SAFE_GROUND, HOLD_BLACK, FADE_OUT }

@export_group("Damage / Recovery")
@export var player_path: NodePath = NodePath("../Player")
@export_range(1, 10, 1) var damage_per_fall: int = 1
@export_range(0.4, 4.0, 0.1) var fall_cooldown: float = 1.2
@export_range(0.0, 100.0, 2.0) var platform_clearance: float = 12.0
@export_flags_2d_physics var terrain_mask: int = 1

@export_group("Phase Checkpoints")
@export var emergency_respawn_marker: NodePath = NodePath("../VoidSafeFloor")
@export var phase_two_safe_marker_path: NodePath = NodePath("../VoidSafeFloorPhase2")
@export var phase_three_safe_marker_path: NodePath = NodePath("../VoidSafeFloorPhase3")
@export var allow_manual_marker_if_no_recorded_floor: bool = false
@export_range(200.0, 2500.0, 50.0) var boss_marker_floor_search_depth: float = 1100.0
@export_range(0.5, 5.0, 0.1) var recovery_grace_seconds: float = 1.8
@export_range(0.5, 8.0, 0.1) var max_wait_for_safe_ground_seconds: float = 2.5
@export_range(20, 500, 10) var remembered_safe_positions: int = 300
@export_range(300.0, 8000.0, 100.0) var platform_search_height: float = 4000.0
@export_range(200.0, 2500.0, 50.0) var platform_search_width: float = 1200.0
@export var print_recovery_debug: bool = true

@export_group("Black-Screen Recovery")
@export_range(0.0, 1.0, 0.01) var black_hold_after_teleport: float = 0.25
@export_range(0.1, 1.5, 0.01) var fade_from_black_seconds: float = 0.58
@export_range(0.5, 3.0, 0.1) var invulnerability_after_teleport: float = 1.0
@export_range(1000, 4000, 100) var black_screen_canvas_layer: int = 2500

@export_group("Rise AFTER Phase 2 Detection")
@export var active_at_start: bool = false
@export_range(0.0, 160.0, 1.0) var intro_rise_distance: float = 72.0
@export_range(0.2, 2.0, 0.05) var intro_rise_duration: float = 0.85
@export_range(100.0, 850.0, 10.0) var follow_below_player: float = 430.0
@export_range(20.0, 450.0, 5.0) var rise_speed: float = 115.0
@export var rise_stop_marker_path: NodePath = NodePath("../risingvoidphase2")
@export var phase_three_rise_marker_path: NodePath = NodePath("../risingvoidphase3")
@export var phase_three_area_path: NodePath = NodePath("../phase3startdetection")
@export_range(180.0, 950.0, 10.0) var phase_three_rise_speed: float = 530.0
@export_range(180.0, 520.0, 10.0) var phase_three_enter_view_below_player: float = 340.0
@export var phase_two_area_path: NodePath = NodePath("../2phaseidentifier")
@export var enable_climb_tilemap: bool = true
@export var climb_tilemap_path: NodePath = NodePath("../boss2phase")

@export_group("Void Visual")
@export var main_color: Color = Color(0.005, 0.005, 0.009, 1.0)
@export var surface_color: Color = Color(0.065, 0.067, 0.076, 0.85)
@export_range(0.0, 8.0, 0.5) var wave_height: float = 3.0
@export_range(1500.0, 100000.0, 1000.0) var draw_depth: float = 40000.0
@export var automatically_configure_particles: bool = true

@onready var _surface: Area2D = get_node_or_null("VoidSurface") as Area2D
@onready var _surface_shape: CollisionShape2D = get_node_or_null("VoidSurface/CollisionShape2D") as CollisionShape2D
@onready var _particles: GPUParticles2D = get_node_or_null("VoidParticles") as GPUParticles2D

var _player: CharacterBody2D = null
var _climb_tilemap: TileMapLayer = null
var _rise_stop_marker: Marker2D = null
var _phase_two_area: Area2D = null
var _phase_three_area: Area2D = null
var _phase_two_started: bool = false
var _phase_three_started: bool = false

@export_group("First Arena Entrance Seal")
@export_range(100.0, 350.0, 10.0) var boss_arena_void_gap_below_player: float = 200.0
@export_range(450.0, 1200.0, 25.0) var boss_arena_void_start_below_player: float = 850.0
@export_range(180.0, 950.0, 10.0) var boss_arena_seal_rise_speed: float = 450.0
var _arena_seal_active: bool = false
var _arena_seal_rising: bool = false
var _arena_seal_destination_y: float = 0.0
var _phase_three_warned_missing_marker: bool = false
var _rise_completed: bool = false
var _warned_missing_stop: bool = false
var _intro_original_y: float = 0.0
var _intro_prepared: bool = false
var _intro_rising: bool = false
var _intro_elapsed: float = 0.0
var _active: bool = false
var _rising: bool = false
var _phase_one_ground: Array[Vector2] = []
var _phase_two_ground: Array[Vector2] = []
var _phase_three_ground: Array[Vector2] = []

var _visited_ground: Array[Dictionary] = []
var _has_warned_no_ground: bool = false
var _hit_cooldown: float = 0.0
var _wave_clock: float = 0.0
var _redraw_timer: float = 0.0
var _missing_rescue_warned: bool = false

var _recovery_state: RecoveryState = RecoveryState.NONE
var _recovery_elapsed: float = 0.0
var _recovery_process_mode_before: int = -1
var _pending_destination: Vector2 = Vector2.ZERO
var _pending_phase: int = 1
var _invulnerability_active: bool = false
var _invulnerability_after_tp_left: float = 0.0
var _teleport_completed: bool = false
var _player_frozen: bool = false
var _player_previous_physics: bool = true
var _black_layer: CanvasLayer = null
var _black_rect: ColorRect = null
var _surface_collision_setup: bool = false
var _surface_contact_pending: bool = false
var _king_final_fall_active: bool = false
var _missing_safe_message_shown: bool = false

func _ready() -> void:
	add_to_group(&"rising_void")
	process_physics_priority = 1000
	z_index = 40
	visible = false
	_player = _find_player()
	_climb_tilemap = _find_climb_tilemap()
	_rise_stop_marker = _find_rise_stop_marker()
	_phase_two_area = _find_phase_two_area()
	_phase_three_area = _find_phase_three_area()
	_configure_void_surface_detection()
	if is_instance_valid(_phase_three_area):
		if not _phase_three_area.body_entered.is_connected(_on_phase_three_area_entered):
			_phase_three_area.body_entered.connect(_on_phase_three_area_entered)
	if enable_climb_tilemap and is_instance_valid(_climb_tilemap) and not active_at_start:
		_climb_tilemap.enabled = false
	if not is_instance_valid(_surface_shape) or not (_surface_shape.shape is RectangleShape2D):
		push_error("RISING VOID V18: VoidSurface needs RectangleShape2D.")
	if is_instance_valid(_particles):
		_particles.emitting = false
		_particles.visible = false
		if automatically_configure_particles:
			_configure_particles()
	_create_black_overlay()
	if active_at_start:
		activate_for_title()

func _configure_void_surface_detection() -> void:
	if not is_instance_valid(_surface):
		push_error("RISING VOID V18: VoidSurface Area2D not found as a child of RisingVoid.")
		return
	_surface.monitoring = true
	if is_instance_valid(_player):
		if (_surface.collision_mask & _player.collision_layer) != _player.collision_layer:
			_surface.collision_mask |= _player.collision_layer
	if not _surface.body_entered.is_connected(_on_void_surface_body_entered):
		_surface.body_entered.connect(_on_void_surface_body_entered)
	_surface_collision_setup = true
	if is_instance_valid(_surface_shape) and _surface_shape.disabled:
		push_warning("RISING VOID V18: VoidSurface/CollisionShape2D is disabled in the scene!")
	if print_recovery_debug:
		print("RISING VOID V18: VoidSurface Area2D connected (mask=", _surface.collision_mask, ").")

func set_king_final_fall_active(active: bool) -> void:
	_king_final_fall_active = active
	if active:
		if _recovery_state != RecoveryState.NONE:
			_recovery_state = RecoveryState.NONE
			_recovery_elapsed = 0.0
			_release_player_gravity()
			_end_unpausable_recovery()
		_surface_contact_pending = false
		_hit_cooldown = maxf(_hit_cooldown, 99999.0)
		if is_instance_valid(_surface):
			_surface.monitoring = false
		if is_instance_valid(_particles):
			_particles.emitting = false
			_particles.visible = false
		visible = false
		if is_instance_valid(_black_rect):
			_black_rect.color.a = 0.0
		print("RISING VOID V21: King collapse active; fall hazard disabled")


func _on_void_surface_body_entered(body: Node2D) -> void:
	if _king_final_fall_active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if body != _player:
		return
	if not _active or _hit_cooldown > 0.0:
		return
	if _recovery_state != RecoveryState.NONE or _invulnerability_active:
		return
	_surface_contact_pending = true
	if print_recovery_debug:
		print("RISING VOID V18: PLAYER ENTERED VOID SURFACE Area2D")

func _player_touching_void_surface() -> bool:
	if not is_instance_valid(_surface) or not is_instance_valid(_player):
		return false
	return _surface.overlaps_body(_player)

func _create_black_overlay() -> void:
	_black_layer = CanvasLayer.new()
	_black_layer.name = "VoidRecoveryBlackout"
	_black_layer.layer = black_screen_canvas_layer
	_black_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		scene.add_child.call_deferred(_black_layer)
	else:
		get_tree().root.add_child.call_deferred(_black_layer)
	_black_rect = ColorRect.new()
	_black_rect.name = "BlackScreen"
	_black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_rect.visible = true
	_black_layer.add_child(_black_rect)
	_black_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_resize_black_overlay()
	if not get_viewport().size_changed.is_connected(_resize_black_overlay):
		get_viewport().size_changed.connect(_resize_black_overlay)

func _resize_black_overlay() -> void:
	if is_instance_valid(_black_rect):
		_black_rect.position = Vector2.ZERO
		_black_rect.size = get_viewport().get_visible_rect().size

func _black_alpha(value: float) -> void:
	if is_instance_valid(_black_rect):
		_black_rect.color = Color(0.0, 0.0, 0.0, clampf(value, 0.0, 1.0))

func _freeze_player_gravity() -> void:
	if not is_instance_valid(_player) or _player_frozen:
		return
	_player_previous_physics = _player.is_physics_processing()
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_player_frozen = true

func _release_player_gravity() -> void:
	if not _player_frozen:
		return
	_player_frozen = false
	if is_instance_valid(_player):
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(_player_previous_physics)

func _give_full_invulnerability() -> void:
	_invulnerability_active = true
	_teleport_completed = false
	_invulnerability_after_tp_left = 0.0
	if is_instance_valid(_player):
		_player.set("tempo_invulneravel_restante", 9999.0)

func _stop_full_invulnerability() -> void:
	if not _invulnerability_active:
		return
	_invulnerability_active = false
	_invulnerability_after_tp_left = 0.0
	if is_instance_valid(_player):
		_player.set("tempo_invulneravel_restante", 0.0)

func _advance_invulnerability(delta: float) -> void:
	if not _invulnerability_active:
		return
	if _teleport_completed:
		_invulnerability_after_tp_left = maxf(0.0, _invulnerability_after_tp_left - delta)
		if _invulnerability_after_tp_left <= 0.0:
			_stop_full_invulnerability()
			return
	if is_instance_valid(_player):
		_player.set("tempo_invulneravel_restante", 9999.0)

func _begin_unpausable_recovery() -> void:
	if _recovery_process_mode_before < 0:
		_recovery_process_mode_before = int(process_mode)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _end_unpausable_recovery() -> void:
	if _recovery_process_mode_before >= 0:
		process_mode = _recovery_process_mode_before
		_recovery_process_mode_before = -1

func _advance_recovery(delta: float) -> void:
	_advance_invulnerability(delta)
	if _recovery_state == RecoveryState.NONE:
		return
	_recovery_elapsed += delta
	match _recovery_state:
		RecoveryState.WAIT_FOR_SAFE_GROUND:
			_black_alpha(1.0)
			var retry: Dictionary = _choose_grounded_rescue()
			if retry.has("position"):
				_teleport_to_safe_floor(retry["position"], _current_phase())
				_recovery_state = RecoveryState.HOLD_BLACK
				_recovery_elapsed = 0.0
			elif _recovery_elapsed >= max_wait_for_safe_ground_seconds:
				_recover_from_missing_floor()
		RecoveryState.HOLD_BLACK:
			_black_alpha(1.0)
			if _recovery_elapsed >= black_hold_after_teleport:
				_recovery_state = RecoveryState.FADE_OUT
				_recovery_elapsed = 0.0
		RecoveryState.FADE_OUT:
			var p: float = clampf(_recovery_elapsed / maxf(0.01, fade_from_black_seconds), 0.0, 1.0)
			_black_alpha(1.0 - smoothstep(0.0, 1.0, p))
			if p >= 1.0:
				_black_alpha(0.0)
				_recovery_state = RecoveryState.NONE
				_recovery_elapsed = 0.0
				_release_player_gravity()
				_end_unpausable_recovery()

func _recover_from_missing_floor() -> void:
	_black_alpha(0.0)
	_recovery_state = RecoveryState.NONE
	_recovery_elapsed = 0.0
	_surface_contact_pending = false
	_active = false
	_hit_cooldown = 99999.0
	_release_player_gravity()
	_stop_full_invulnerability()
	_end_unpausable_recovery()
	push_error("RisingVoid: no valid solid floor above the Void for this phase; restarting Level 6 instead of holding a permanent black screen.")
	get_tree().paused = false
	Global.reiniciar_vida()
	get_tree().call_deferred("reload_current_scene")


func _teleport_to_safe_floor(destination: Vector2, phase: int) -> void:
	if not is_instance_valid(_player):
		return
	_player.global_position = destination
	_player.velocity = Vector2.ZERO
	if _player.has_method(&"_resetar_queda_profunda"):
		_player.call(&"_resetar_queda_profunda")
	_player.reset_physics_interpolation()
	_player.apply_floor_snap()
	_append_checkpoint(phase, destination)
	_teleport_completed = true
	_invulnerability_after_tp_left = invulnerability_after_teleport
	if print_recovery_debug:
		print("RISING VOID V22: PHASE ", phase, " | INSTANT TELEPORT TO VERIFIED GROUND: ", destination, " | blackout active; invulnerable +1s")

func _find_player() -> CharacterBody2D:
	if not player_path.is_empty():
		var found: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
		if is_instance_valid(found):
			return found
	return get_tree().get_first_node_in_group(&"player") as CharacterBody2D

func _find_climb_tilemap() -> TileMapLayer:
	if not climb_tilemap_path.is_empty():
		var found: TileMapLayer = get_node_or_null(climb_tilemap_path) as TileMapLayer
		if is_instance_valid(found):
			return found
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		return scene.find_child("boss2phase", true, false) as TileMapLayer
	return null

func _find_rise_stop_marker() -> Marker2D:
	if not rise_stop_marker_path.is_empty():
		var found: Marker2D = get_node_or_null(rise_stop_marker_path) as Marker2D
		if is_instance_valid(found):
			return found
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		for node: Node in scene.find_children("*", "Marker2D", true, false):
			if String(node.name).to_lower().replace("_", "") == "risingvoidphase2":
				return node as Marker2D
	return null

func _find_phase_two_area() -> Area2D:
	if not phase_two_area_path.is_empty():
		var found: Area2D = get_node_or_null(phase_two_area_path) as Area2D
		if is_instance_valid(found):
			return found
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		return scene.find_child("2phaseidentifier", true, false) as Area2D
	return null

func _find_phase_three_area() -> Area2D:
	if not phase_three_area_path.is_empty():
		var found: Area2D = get_node_or_null(phase_three_area_path) as Area2D
		if is_instance_valid(found):
			return found
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		return scene.find_child("phase3startdetection", true, false) as Area2D
	return null

func _find_safe_marker(phase: int) -> Marker2D:
	var path: NodePath = emergency_respawn_marker
	var marker_name: String = "VoidSafeFloor"
	match phase:
		2:
			path = phase_two_safe_marker_path
			marker_name = "VoidSafeFloorPhase2"
		3:
			path = phase_three_safe_marker_path
			marker_name = "VoidSafeFloorPhase3"
	if not path.is_empty():
		var found: Marker2D = get_node_or_null(path) as Marker2D
		if is_instance_valid(found):
			return found
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		return scene.find_child(marker_name, true, false) as Marker2D
	return null

func _current_phase() -> int:
	if _phase_three_started:
		return 3
	if _phase_two_started:
		return 2
	return 1

func _history_for_phase(phase: int) -> Array[Vector2]:
	match phase:
		3:
			return _phase_three_ground
		2:
			return _phase_two_ground
		_:
			return _phase_one_ground

func _append_checkpoint(phase: int, position: Vector2) -> void:
	var history: Array[Vector2] = _history_for_phase(phase)
	if history.is_empty():
		history.append(position)
	elif history[history.size() - 1].distance_to(position) >= 15.0:
		history.append(position)
	else:
		history[history.size() - 1] = position
	while history.size() > remembered_safe_positions:
		history.remove_at(0)

func _floor_contact_under_player(pos: Vector2, max_floor_gap: float = 8.0) -> bool:
	if not is_instance_valid(_player):
		return false
	var feet: float = _player_feet_below_origin()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		pos + Vector2(0.0, feet - 5.0),
		pos + Vector2(0.0, feet + max_floor_gap),
		_player.collision_mask | terrain_mask
	)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return false
	var floor_normal: Vector2 = hit.get("normal", Vector2.ZERO)
	return floor_normal.y <= -0.7

func _save_ground_for_phase(phase: int) -> void:
	if not is_instance_valid(_player) or _recovery_state != RecoveryState.NONE:
		return

	var grounded: bool = _player.is_on_floor()
	var pos: Vector2 = _player.global_position
	if not grounded and absf(_player.velocity.y) < 25.0:
		grounded = _floor_contact_under_player(pos)
	if not grounded:
		return

	if _active and _player_touching_void_surface():
		return

	var ground_foot_y: float = pos.y + _player_feet_below_origin()
	var entry: Dictionary = {
		"position": pos,
		"ground_foot_y": ground_foot_y,
		"phase": phase
	}
	if _visited_ground.is_empty():
		_visited_ground.append(entry)
		if print_recovery_debug:
			print("RISING VOID V18: FIRST ACTUAL GROUND SAVED: ", pos)
	else:
		var last: Dictionary = _visited_ground[_visited_ground.size() - 1]
		var last_pos: Vector2 = last["position"]
		if last_pos.distance_to(pos) >= 8.0 or int(last.get("phase", 1)) != phase:
			_visited_ground.append(entry)
		else:
			_visited_ground[_visited_ground.size() - 1] = entry

	while _visited_ground.size() > remembered_safe_positions:
		_visited_ground.remove_at(0)

	_append_checkpoint(phase, pos)

func _record_grounded_position() -> void:
	_save_ground_for_phase(_current_phase())

func _above_void(pos: Vector2) -> bool:
	return pos.y + _player_feet_below_origin() < _world_surface_top() - platform_clearance

func _previous_real_floor_still_safe(entry: Dictionary) -> bool:
	var old_position: Vector2 = entry["position"]
	return _above_void(old_position) and _floor_contact_under_player(old_position, 15.0)

func _marker_is_on_real_floor(marker: Marker2D) -> bool:
	if not is_instance_valid(marker):
		return false
	if marker.global_position.y + _player_feet_below_origin() >= _world_surface_top() - 2.0:
		return false
	return _floor_contact_under_player(marker.global_position, 15.0)

func _player_inside_area(area: Area2D) -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(area):
		return false
	for node: Node in area.find_children("*", "CollisionShape2D", true, false):
		var collision: CollisionShape2D = node as CollisionShape2D
		if not is_instance_valid(collision) or collision.disabled or collision.shape == null:
			continue
		var point: Vector2 = collision.to_local(_player.global_position)
		if collision.shape is RectangleShape2D:
			var rect: RectangleShape2D = collision.shape as RectangleShape2D
			if absf(point.x) <= rect.size.x * 0.5 + 14.0 and absf(point.y) <= rect.size.y * 0.5 + 18.0:
				return true
		elif collision.shape is CircleShape2D:
			var circle: CircleShape2D = collision.shape as CircleShape2D
			if point.length_squared() <= pow(circle.radius + 18.0, 2.0):
				return true
	return area.overlaps_body(_player)

func _player_inside_phase_two_area() -> bool:
	if not is_instance_valid(_phase_two_area):
		_phase_two_area = _find_phase_two_area()
	return _player_inside_area(_phase_two_area)

func _player_inside_phase_three_area() -> bool:
	if not is_instance_valid(_phase_three_area):
		_phase_three_area = _find_phase_three_area()
	return _player_inside_area(_phase_three_area)

func _on_phase_three_area_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and not _phase_three_started:
		begin_phase_three_rising()

func _local_surface_rect() -> Rect2:
	if not is_instance_valid(_surface_shape) or not (_surface_shape.shape is RectangleShape2D):
		return Rect2(-500.0, 0.0, 1000.0, 20.0)
	var shape_rect: RectangleShape2D = _surface_shape.shape as RectangleShape2D
	var half: Vector2 = shape_rect.size * 0.5
	var a: Vector2 = to_local(_surface_shape.to_global(Vector2(-half.x, -half.y)))
	var b: Vector2 = to_local(_surface_shape.to_global(Vector2(half.x, half.y)))
	return Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(b.x - a.x), absf(b.y - a.y))

func _world_surface_top() -> float:
	return to_global(_local_surface_rect().position).y

func _world_surface_x_limits() -> Vector2:
	var rect: Rect2 = _local_surface_rect()
	var a: float = to_global(rect.position).x
	var b: float = to_global(rect.position + Vector2(rect.size.x, 0.0)).x
	return Vector2(minf(a, b), maxf(a, b))

func _player_feet_below_origin() -> float:
	if not is_instance_valid(_player):
		return 20.0
	var body: CollisionShape2D = _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(body) or body.shape == null:
		return 22.0
	var height: float = 44.0
	if body.shape is RectangleShape2D:
		height = (body.shape as RectangleShape2D).size.y
	elif body.shape is CapsuleShape2D:
		height = (body.shape as CapsuleShape2D).height
	elif body.shape is CircleShape2D:
		height = (body.shape as CircleShape2D).radius * 2.0
	return maxf(8.0, body.position.y + height * 0.5 * absf(body.scale.y))

func activate_for_title() -> void:
	if _active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		push_warning("RISING VOID V18: Player not found.")
		return
	_save_ground_for_phase(1)
	_active = true
	_rising = false
	_rise_completed = false
	_intro_original_y = global_position.y
	_intro_prepared = intro_rise_distance > 0.01
	_intro_rising = false
	_intro_elapsed = 0.0
	if _intro_prepared:
		global_position.y = _intro_original_y + intro_rise_distance
	_warned_missing_stop = false
	_hit_cooldown = 0.0
	visible = true
	if is_instance_valid(_particles):
		_particles.visible = true
		_particles.emitting = true
		_particles.restart()
	queue_redraw()

func seal_boss_arena_entrance(arena_player: Node2D) -> void:
	if _arena_seal_active or _phase_two_started or _phase_three_started:
		return
	if not is_instance_valid(arena_player):
		return
	if not _active:
		activate_for_title()
	if not _active:
		return
	_intro_prepared = false
	_intro_rising = false
	_arena_seal_active = true
	_arena_seal_rising = false
	_rising = false
	_rise_completed = false
	var top_y: float = _world_surface_top()
	var player_y: float = arena_player.global_position.y
	var start_top_y: float = player_y + boss_arena_void_start_below_player
	if top_y > start_top_y:
		global_position.y -= top_y - start_top_y
		top_y = _world_surface_top()
	_arena_seal_destination_y = player_y + boss_arena_void_gap_below_player
	_arena_seal_rising = top_y > _arena_seal_destination_y + 2.0
	visible = true
	if is_instance_valid(_particles):
		_particles.visible = true
		_particles.emitting = true
		_particles.restart()
	print("RISING VOID V19: first arena sealed, current=", top_y,
		" target=", _arena_seal_destination_y, " no phase flags changed")
	queue_redraw()


func play_intro_rise() -> void:
	if not _active or not _intro_prepared or _intro_rising:
		return
	_intro_rising = true
	_intro_elapsed = 0.0

func activate() -> void:
	activate_for_title()

func start_boss_climb() -> void:
	if enable_climb_tilemap:
		if not is_instance_valid(_climb_tilemap):
			_climb_tilemap = _find_climb_tilemap()
		if is_instance_valid(_climb_tilemap):
			_climb_tilemap.enabled = true
	if not _active:
		activate_for_title()

func begin_rising() -> void:
	_arena_seal_active = false
	_arena_seal_rising = false
	if not _active:
		activate_for_title()
	if _rising or _rise_completed or not _active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		return
	if _intro_rising or _intro_prepared:
		_intro_rising = false
		_intro_prepared = false
		global_position.y = _intro_original_y
	_rise_stop_marker = _find_rise_stop_marker()
	if not is_instance_valid(_rise_stop_marker):
		if not _warned_missing_stop:
			_warned_missing_stop = true
			push_warning("RISING VOID V18: phase 2 marker missing.")
		return
	var current_y: float = _world_surface_top()
	var target_y: float = _rise_stop_marker.global_position.y
	if target_y >= current_y:
		_rise_completed = true
		push_warning("RISING VOID V18: phase 2 marker must be above Void.")
		return
	_save_ground_for_phase(2)
	_phase_two_started = true
	_rising = true

func begin_phase_three_rising() -> void:
	if _phase_three_started:
		return
	if not _active:
		activate_for_title()
	if not _active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		return
	var marker: Marker2D = get_node_or_null(phase_three_rise_marker_path) as Marker2D
	if not is_instance_valid(marker):
		var scene: Node = get_tree().current_scene
		if is_instance_valid(scene):
			marker = scene.find_child("risingvoidphase3", true, false) as Marker2D
	if not is_instance_valid(marker):
		if not _phase_three_warned_missing_marker:
			_phase_three_warned_missing_marker = true
			push_warning("RISING VOID V18: phase 3 marker missing.")
		return
	_save_ground_for_phase(3)
	_intro_prepared = false
	_intro_rising = false
	var before_y: float = _world_surface_top()
	var final_y: float = marker.global_position.y
	_rise_stop_marker = marker
	_phase_three_started = true
	_rise_completed = false
	visible = true
	if is_instance_valid(_particles):
		_particles.visible = true
		_particles.emitting = true
		_particles.restart()
	if final_y < before_y:
		var visible_y: float = _player.global_position.y + phase_three_enter_view_below_player
		var start_y: float = maxf(final_y + 4.0, minf(before_y, visible_y))
		if start_y < before_y:
			global_position.y -= before_y - start_y
		_rising = true
	else:
		_rising = false
		_rise_completed = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _king_final_fall_active:
		return
	_advance_recovery(delta)
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		return
	_record_grounded_position()
	if bool(_player.get_meta(&"king_artifact_rescue_active", false)):
		return
	if not _active:
		return
	_wave_clock += delta
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if _intro_rising:
		_intro_elapsed = minf(intro_rise_duration, _intro_elapsed + delta)
		var fraction: float = clampf(_intro_elapsed / maxf(0.05, intro_rise_duration), 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - fraction, 3.0)
		global_position.y = lerpf(_intro_original_y + intro_rise_distance, _intro_original_y, ease_out)
		if fraction >= 1.0:
			_intro_rising = false
			_intro_prepared = false
			global_position.y = _intro_original_y
	var top_y: float = _world_surface_top()
	if _arena_seal_rising and not _phase_two_started and not _phase_three_started:
		var next_top_y: float = maxf(_arena_seal_destination_y,
			top_y - boss_arena_seal_rise_speed * delta)
		global_position.y -= top_y - next_top_y
		top_y = _world_surface_top()
		if top_y <= _arena_seal_destination_y + 0.25:
			_arena_seal_rising = false
	if not _phase_three_started and _player_inside_phase_three_area():
		begin_phase_three_rising()
		top_y = _world_surface_top()
	if not _arena_seal_active and not _phase_three_started and not _rising and not _rise_completed:
		if not is_instance_valid(_climb_tilemap):
			_climb_tilemap = _find_climb_tilemap()
		if (not is_instance_valid(_climb_tilemap) or _climb_tilemap.enabled) and _player_inside_phase_two_area():
			begin_rising()
	if _rising:
		if not is_instance_valid(_rise_stop_marker):
			_rise_stop_marker = _find_rise_stop_marker()
		if is_instance_valid(_rise_stop_marker):
			var destination_y: float = _rise_stop_marker.global_position.y
			if top_y <= destination_y + 0.25:
				_rising = false
				_rise_completed = true
			else:
				var speed: float = phase_three_rise_speed if _phase_three_started else rise_speed
				var next_y: float = maxf(destination_y, top_y - speed * delta)
				global_position.y -= top_y - next_y
				top_y = _world_surface_top()
				if top_y <= destination_y + 0.25:
					_rising = false
					_rise_completed = true
		else:
			_rising = false
			if not _warned_missing_stop:
				_warned_missing_stop = true
				push_warning("RISING VOID V18: lost rise marker.")
	_record_grounded_position()
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.06
		queue_redraw()
	if not _surface_collision_setup:
		_configure_void_surface_detection()
	if is_instance_valid(_surface) and is_instance_valid(_player):
		if (_surface.collision_mask & _player.collision_layer) != _player.collision_layer:
			_surface.collision_mask |= _player.collision_layer
	if _recovery_state != RecoveryState.NONE or _invulnerability_active:
		return
	if _hit_cooldown > 0.0:
		return
	if _surface_contact_pending or _player_touching_void_surface():
		_surface_contact_pending = false
		_on_player_fell_into_void()

func _on_player_fell_into_void() -> void:
	if _king_final_fall_active or not _active or not is_instance_valid(_player):
		return
	if _recovery_state != RecoveryState.NONE or _invulnerability_active:
		return
	_hit_cooldown = maxf(fall_cooldown, recovery_grace_seconds)
	var phase: int = _current_phase()
	var rescue: Dictionary = _choose_grounded_rescue()
	var health_before: Variant = _player.get("vida")

	if _player.has_method(&"tomar_dano"):
		_player.call(&"tomar_dano", maxi(1, damage_per_fall), Vector2(_player.global_position.x, _world_surface_top() + 25.0))
	if not is_instance_valid(_player):
		return
	if bool(_player.get_meta(&"king_artifact_rescue_active", false)):
		return
	var health: Variant = _player.get("vida")
	if health != null and int(health) <= 0:
		return

	if not rescue.has("position"):
		_begin_unpausable_recovery()
		_black_alpha(1.0)
		_give_full_invulnerability()
		_freeze_player_gravity()
		_recovery_state = RecoveryState.WAIT_FOR_SAFE_GROUND
		_recovery_elapsed = 0.0
		if not _missing_safe_message_shown:
			_missing_safe_message_shown = true
			push_error("RISING VOID V22: no solid floor above Void found for Phase " + str(phase) + ". Check the King boss spawn Marker2Ds and TileMap collision. Blackout protection active.")
		return

	_missing_safe_message_shown = false
	var destination: Vector2 = rescue["position"]

	_begin_unpausable_recovery()
	_black_alpha(1.0)
	_give_full_invulnerability()
	_freeze_player_gravity()

	_teleport_to_safe_floor(destination, phase)

	_recovery_state = RecoveryState.HOLD_BLACK
	_recovery_elapsed = 0.0
	if print_recovery_debug:
		print("RISING VOID V18: HIT via VoidSurface; phase=", phase, " HP ", health_before, " -> ", health, " | black NOW, instant floor teleport to ", destination, " | ", rescue.get("source", "saved ground"))

func _find_last_ground_actually_visited() -> Dictionary:
	for i: int in range(_visited_ground.size() - 1, -1, -1):
		var entry: Dictionary = _visited_ground[i]
		if _previous_real_floor_still_safe(entry):
			return {
				"position": entry["position"],
				"source": "LAST FLOOR ACTUALLY STOOD ON (phase " + str(entry["phase"]) + ")"
			}
	return {}

func _find_marker_ground(phase: int) -> Dictionary:
	var marker: Marker2D = _find_safe_marker(phase)
	if not _marker_is_on_real_floor(marker):
		return {}
	return {
		"position": marker.global_position,
		"source": "VERIFIED SOLID FLOOR MARKER phase " + str(phase)
	}


func _latest_usable_ground_in_phase(phase: int) -> Dictionary:
	for i: int in range(_visited_ground.size() - 1, -1, -1):
		var entry: Dictionary = _visited_ground[i]
		if int(entry.get("phase", 0)) != phase:
			continue
		if _previous_real_floor_still_safe(entry):
			return {
				"position": entry["position"],
				"phase": phase,
				"source": "CURRENT-PHASE LAST SOLID FLOOR"
			}
	return {}

func _grounded_landing_below_boss_marker(marker: Marker2D) -> Dictionary:
	if not is_instance_valid(marker) or not is_instance_valid(_player):
		return {}

	var feet: float = _player_feet_below_origin()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var mask: int = _player.collision_mask | terrain_mask
	var offsets: Array[float] = [0.0, -30.0, 30.0, -65.0, 65.0, -100.0, 100.0]

	for dx: float in offsets:
		var x: float = marker.global_position.x + dx
		var start: Vector2 = Vector2(x, marker.global_position.y - 70.0)
		var finish: Vector2 = Vector2(x,
			marker.global_position.y + boss_marker_floor_search_depth)
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			start, finish, mask)
		ray.exclude = [_player.get_rid()]
		ray.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		if normal.y > -0.7:
			continue
		var collider: Object = hit.get("collider", null)
		if collider is TileMapLayer and not (collider as TileMapLayer).enabled:
			continue
		var floor_point: Vector2 = hit.get("position", Vector2.ZERO)
		var landing: Vector2 = Vector2(x, floor_point.y - feet - 2.0)
		if not _above_void(landing):
			continue
		return {"position": landing, "marker": String(marker.name)}
	return {}

func _nearest_usable_boss_marker_ground(phase: int) -> Dictionary:
	if phase not in [1, 2, 3]:
		return {}
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene) or not is_instance_valid(_player):
		return {}

	var marker_prefix: String = "1phasespawns" if phase == 1 else ("2phasebo" if phase == 2 else "3phasebo")
	var closest_score: float = INF
	var closest: Dictionary = {}
	for node: Node in scene.find_children("*", "Marker2D", true, false):
		var marker: Marker2D = node as Marker2D
		if not is_instance_valid(marker):
			continue
		var marker_name: String = String(marker.name).to_lower()
		if not marker_name.begins_with(marker_prefix) or not marker_name.contains("spawn"):
			continue
		var distance: float = marker.global_position.distance_squared_to(_player.global_position)
		if distance >= closest_score:
			continue
		var landing: Dictionary = _grounded_landing_below_boss_marker(marker)
		if not landing.has("position"):
			continue
		closest_score = distance
		closest = {
			"position": landing["position"],
			"phase": phase,
			"source": "NEAREST PHASE " + str(phase) + " BOSS MARKER: " + String(marker.name)
		}
	return closest

func _arena_ground_from_exploration_areas() -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return {}

	var area_names: Array[String] = ["wanderarea2", "wanderarea1", "bossarena"]
	var areas: Array[Area2D] = []
	for area_name: String in area_names:
		var area: Area2D = scene.find_child(area_name, true, false) as Area2D
		if is_instance_valid(area):
			areas.append(area)

	var best_distance: float = INF
	var best: Dictionary = {}
	for area: Area2D in areas:
		var probes: Array[Vector2] = [area.global_position]
		for child: Node in area.find_children("*", "CollisionShape2D", true, false):
			var cs: CollisionShape2D = child as CollisionShape2D
			if is_instance_valid(cs) and cs.shape is RectangleShape2D:
				var w: float = (cs.shape as RectangleShape2D).size.x * 0.35
				probes.append(cs.to_global(Vector2(-w, 0.0)))
				probes.append(cs.to_global(Vector2(w, 0.0)))
		for probe: Vector2 in probes:
			var landing: Dictionary = _floor_below_arena_position(probe)
			if not landing.has("position"):
				continue
			var candidate: Vector2 = landing["position"]
			var distance: float = candidate.distance_squared_to(_player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = {"position": landing["position"], "phase": 1, "source": "GROUNDED BOSS ARENA"}
	return best


func _floor_below_arena_position(point: Vector2) -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var feet: float = _player_feet_below_origin()
	var mask: int = _player.collision_mask | terrain_mask
	for dx: float in [0.0, -45.0, 45.0, -90.0, 90.0]:
		var x: float = point.x + dx
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			Vector2(x, point.y - 320.0),
			Vector2(x, point.y + boss_marker_floor_search_depth), mask)
		ray.exclude = [_player.get_rid()]
		ray.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or (hit.get("normal", Vector2.ZERO) as Vector2).y > -0.7:
			continue
		var collider: Object = hit.get("collider", null)
		if collider is TileMapLayer and not (collider as TileMapLayer).enabled:
			continue
		var floor_point: Vector2 = hit.get("position", Vector2.ZERO)
		var destination: Vector2 = Vector2(x, floor_point.y - feet - 2.0)
		if _above_void(destination):
			return {"position": destination}
	return {}


func get_artifact_rescue_checkpoint() -> Dictionary:
	var chosen: Dictionary = _choose_grounded_rescue()
	if chosen.has("position"):
		chosen["phase"] = _current_phase()
	return chosen

func _choose_grounded_rescue() -> Dictionary:
	var phase: int = _current_phase()

	if phase == 2 or phase == 3:
		var recent: Dictionary = _latest_usable_ground_in_phase(phase)
		if recent.has("position"):
			return recent
		var boss_marker: Dictionary = _nearest_usable_boss_marker_ground(phase)
		if boss_marker.has("position"):
			if print_recovery_debug:
				print("RISING VOID V22: phase ", phase,
					" swallowed last checkpoint; rescue by ", boss_marker["source"],
					" -> ", boss_marker["position"])
			return boss_marker
		var phase_safe_marker: Dictionary = _find_marker_ground(phase)
		if phase_safe_marker.has("position"):
			return phase_safe_marker
		return {}

	var result: Dictionary = _find_last_ground_actually_visited()
	if result.has("position"):
		return result
	result = _nearest_usable_boss_marker_ground(1)
	if result.has("position"):
		return result
	result = _arena_ground_from_exploration_areas()
	if result.has("position"):
		return result
	if allow_manual_marker_if_no_recorded_floor:
		result = _find_marker_ground(1)
		if result.has("position"):
			return result
	return {}

func _configure_particles() -> void:
	if not is_instance_valid(_particles):
		return
	var rect: Rect2 = _local_surface_rect()
	_particles.position = rect.position + Vector2(rect.size.x * 0.5, 0.0)
	_particles.amount = clampi(int(rect.size.x / 20.0), 32, 180)
	_particles.lifetime = 2.2
	_particles.explosiveness = 0.0
	_particles.randomness = 0.55
	_particles.visibility_rect = Rect2(-rect.size.x * 0.5, -240.0, rect.size.x, 280.0)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(rect.size.x * 0.5, 2.0, 0.0)
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 30.0
	mat.gravity = Vector3(0.0, -8.0, 0.0)
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 36.0
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	_particles.process_material = mat
	if _particles.texture == null:
		var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for y: int in range(8):
			for x: int in range(8):
				if Vector2(float(x) - 3.5, float(y) - 3.5).length_squared() < 10.0:
					img.set_pixel(x, y, Color(0.004, 0.004, 0.009, 0.85))
		_particles.texture = ImageTexture.create_from_image(img)

func _draw() -> void:
	if not _active:
		return
	var area: Rect2 = _local_surface_rect()
	var left: float = area.position.x
	var right: float = area.end.x
	var top: float = area.position.y
	draw_rect(Rect2(left, top, area.size.x, draw_depth), main_color, true)
	if wave_height <= 0.01:
		draw_line(Vector2(left, top), Vector2(right, top), surface_color, 2.0, true)
		return
	var edge: PackedVector2Array = PackedVector2Array()
	var segments: int = maxi(12, int(area.size.x / 24.0))
	for i: int in range(segments + 1):
		var x: float = lerpf(left, right, float(i) / float(segments))
		var wave: float = sin(x * 0.026 + _wave_clock * 1.8) * wave_height
		edge.append(Vector2(x, top + wave))
	draw_polyline(edge, surface_color, 2.0, true)

func _exit_tree() -> void:
	if is_instance_valid(_surface) and _surface.body_entered.is_connected(_on_void_surface_body_entered):
		_surface.body_entered.disconnect(_on_void_surface_body_entered)
	_release_player_gravity()
	_stop_full_invulnerability()
	var viewport: Viewport = get_viewport()
	if is_instance_valid(viewport) and viewport.size_changed.is_connected(_resize_black_overlay):
		viewport.size_changed.disconnect(_resize_black_overlay)
	if is_instance_valid(_black_layer):
		_black_layer.queue_free()
