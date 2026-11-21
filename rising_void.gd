# RISING VOID V7: phase3startdetection directly starts the final rise.
# The surface becomes visible near the player's view immediately, then
# rises to the user-placed risingvoidphase3 Marker2D and stops precisely.
# RISING VOID V6: rises again toward risingvoidphase3 on the final ascent.
# LEVEL 6 RISING VOID V5 - COMPLETE Godot 4.7 SCRIPT
# A short title-end emergence lifts the whole surface into its editor position,
# then STOPS until the ordinary phase-two ascent is activated.
# FIX: Once the upper 2phaseidentifier is entered, ascend all the way
# to risingvoidphase2 (Marker2D), stop EXACTLY there, never descend.
# Also independently checks the 2phaseidentifier if the King's signal is missed.
# Attach to Level6/RisingVoid (Node2D).
# Required children:
#   VoidSurface (Area2D)
#     CollisionShape2D (RectangleShape2D, as wide as YOUR arena)
#   VoidParticles (GPUParticles2D)
# The CollisionShape2D determines the horizontal width and TOP of the Void.
# The darkness fills that exact width FROM THE TOP DOWN; no StaticBody2D.
# King Necro calls activate_for_title() during the FIRST title and
# begin_rising() on entering 2phaseidentifier. start_boss_climb() only
# enables the platform TileMapLayer; it NEVER starts the rising movement.

extends Node2D
class_name RisingAbyssVoid

@export_group("Damage / Recovery")
@export var player_path: NodePath = NodePath("../Player")
@export_range(1, 10, 1) var damage_per_fall: int = 1
@export_range(0.4, 4.0, 0.1) var fall_cooldown: float = 1.2
@export_range(45.0, 230.0, 5.0) var platform_clearance: float = 90.0
@export_flags_2d_physics var terrain_mask: int = 1
@export var emergency_respawn_marker: NodePath

@export_group("Rise AFTER Phase 2 Detection")
@export var active_at_start: bool = false
@export_range(0.0, 160.0, 1.0) var intro_rise_distance: float = 72.0
@export_range(0.2, 2.0, 0.05) var intro_rise_duration: float = 0.85
@export_range(100.0, 850.0, 10.0) var follow_below_player: float = 430.0 # legacy Inspector value, not used while a stop marker exists
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
var _phase_three_started: bool = false
var _phase_three_warned_missing_marker: bool = false
var _rise_completed: bool = false
var _warned_missing_stop: bool = false
var _intro_original_y: float = 0.0
var _intro_prepared: bool = false
var _intro_rising: bool = false
var _intro_elapsed: float = 0.0
var _active: bool = false
var _rising: bool = false
var _best_player_height: float = INF
var _last_safe_pos: Vector2 = Vector2.ZERO
var _has_last_safe: bool = false
var _hit_cooldown: float = 0.0
var _wave_clock: float = 0.0
var _redraw_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"rising_void")
	z_index = 40
	visible = false
	_player = _find_player()
	_climb_tilemap = _find_climb_tilemap()
	_rise_stop_marker = _find_rise_stop_marker()
	_phase_two_area = _find_phase_two_area()
	_phase_three_area = _find_phase_three_area()
	if is_instance_valid(_phase_three_area):
		if not _phase_three_area.body_entered.is_connected(_on_phase_three_area_entered):
			_phase_three_area.body_entered.connect(_on_phase_three_area_entered)
	if enable_climb_tilemap and is_instance_valid(_climb_tilemap) and not active_at_start:
		_climb_tilemap.enabled = false
	if not is_instance_valid(_surface_shape) or not (_surface_shape.shape is RectangleShape2D):
		push_error("RISING VOID V3: Need RisingVoid/VoidSurface/CollisionShape2D with a RectangleShape2D.")
	if is_instance_valid(_particles):
		_particles.emitting = false
		_particles.visible = false
		if automatically_configure_particles:
			_configure_particles()
	if active_at_start:
		activate_for_title()


func _find_player() -> CharacterBody2D:
	if not player_path.is_empty():
		var by_path: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
		if is_instance_valid(by_path):
			return by_path
	return get_tree().get_first_node_in_group(&"player") as CharacterBody2D


func _find_climb_tilemap() -> TileMapLayer:
	if not climb_tilemap_path.is_empty():
		var by_path: TileMapLayer = get_node_or_null(climb_tilemap_path) as TileMapLayer
		if is_instance_valid(by_path):
			return by_path
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		return scene.find_child("boss2phase", true, false) as TileMapLayer
	return null


func _find_rise_stop_marker() -> Marker2D:
	# Prefer the user-defined, exact scene marker. Global Y is the final
	# height of the Void SURFACE, not the RisingVoid Node2D origin.
	if not rise_stop_marker_path.is_empty():
		var by_path: Marker2D = get_node_or_null(rise_stop_marker_path) as Marker2D
		if is_instance_valid(by_path):
			return by_path
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		for node: Node in scene.find_children("*", "Marker2D", true, false):
			if String(node.name).to_lower().replace("_", "") == "risingvoidphase2":
				return node as Marker2D
	return null


func _find_phase_two_area() -> Area2D:
	if not phase_two_area_path.is_empty():
		var by_path: Area2D = get_node_or_null(phase_two_area_path) as Area2D
		if is_instance_valid(by_path):
			return by_path
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		return scene.find_child("2phaseidentifier", true, false) as Area2D
	return null


func _player_inside_phase_two_area() -> bool:
	if not is_instance_valid(_player):
		return false
	if not is_instance_valid(_phase_two_area):
		_phase_two_area = _find_phase_two_area()
	if not is_instance_valid(_phase_two_area):
		return false
	# Test the actual shape independent of Area2D collision masks,
	# so a missed body_entered signal cannot strand the rising Void.
	for node: Node in _phase_two_area.find_children("*", "CollisionShape2D", true, false):
		var shape_node: CollisionShape2D = node as CollisionShape2D
		if not is_instance_valid(shape_node) or shape_node.disabled or shape_node.shape == null:
			continue
		var local_point: Vector2 = shape_node.to_local(_player.global_position)
		if shape_node.shape is RectangleShape2D:
			var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
			if absf(local_point.x) <= rect.size.x * 0.5 and absf(local_point.y) <= rect.size.y * 0.5:
				return true
		elif shape_node.shape is CircleShape2D:
			var circle: CircleShape2D = shape_node.shape as CircleShape2D
			if local_point.length_squared() <= circle.radius * circle.radius:
				return true
	return _phase_two_area.overlaps_body(_player)


func _find_phase_three_area() -> Area2D:
	if not phase_three_area_path.is_empty():
		var direct: Area2D = get_node_or_null(phase_three_area_path) as Area2D
		if is_instance_valid(direct):
			return direct
	var root: Node = get_tree().current_scene
	if is_instance_valid(root):
		return root.find_child("phase3startdetection", true, false) as Area2D
	return null


func _on_phase_three_area_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and not _phase_three_started:
		begin_phase_three_rising()


func _player_inside_phase_three_area() -> bool:
	if not is_instance_valid(_player):
		return false
	if not is_instance_valid(_phase_three_area):
		_phase_three_area = _find_phase_three_area()
	if not is_instance_valid(_phase_three_area):
		return false
	# Geometry check independent of physics collision layers/masks.
	for node: Node in _phase_three_area.find_children("*", "CollisionShape2D", true, false):
		var collision: CollisionShape2D = node as CollisionShape2D
		if not is_instance_valid(collision) or collision.shape == null or collision.disabled:
			continue
		var local: Vector2 = collision.to_local(_player.global_position)
		if collision.shape is RectangleShape2D:
			var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
			if absf(local.x) <= rectangle.size.x * 0.5 + 14.0 and absf(local.y) <= rectangle.size.y * 0.5 + 18.0:
				return true
		elif collision.shape is CircleShape2D:
			var circle: CircleShape2D = collision.shape as CircleShape2D
			if local.length_squared() <= pow(circle.radius + 18.0, 2.0):
				return true
	return _phase_three_area.overlaps_body(_player)


func _local_surface_rect() -> Rect2:
	# Both corners are transformed into the RisingVoid drawing coordinates.
	# This uses the EXACT width you set in the editor, not a hardcoded width.
	if not is_instance_valid(_surface_shape) or not (_surface_shape.shape is RectangleShape2D):
		return Rect2(-500.0, 0.0, 1000.0, 20.0)
	var shape_rect: RectangleShape2D = _surface_shape.shape as RectangleShape2D
	var half: Vector2 = shape_rect.size * 0.5
	var corner_a: Vector2 = to_local(_surface_shape.to_global(Vector2(-half.x, -half.y)))
	var corner_b: Vector2 = to_local(_surface_shape.to_global(Vector2(half.x, half.y)))
	var left_x: float = minf(corner_a.x, corner_b.x)
	var top_y: float = minf(corner_a.y, corner_b.y)
	return Rect2(left_x, top_y, absf(corner_b.x - corner_a.x), absf(corner_b.y - corner_a.y))


func _world_surface_top() -> float:
	var rect: Rect2 = _local_surface_rect()
	return to_global(rect.position).y


func _world_surface_x_limits() -> Vector2:
	var rect: Rect2 = _local_surface_rect()
	var first: float = to_global(rect.position).x
	var last: float = to_global(rect.position + Vector2(rect.size.x, 0.0)).x
	return Vector2(minf(first, last), maxf(first, last))


# Called by the King when the FIRST black title card appears.
# Activates visuals, particles, and damage, but leaves the surface STATIONARY.
func activate_for_title() -> void:
	if _active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		push_warning("RISING VOID V3: No Player found.")
		return
	_active = true
	_rising = false
	_rise_completed = false
	# Show the Void slightly lower during the blackout. When the title
	# disappears it glides UP to the exact editor-configured surface height.
	_intro_original_y = global_position.y
	_intro_prepared = intro_rise_distance > 0.01
	_intro_rising = false
	_intro_elapsed = 0.0
	if _intro_prepared:
		global_position.y = _intro_original_y + intro_rise_distance
	_warned_missing_stop = false
	_best_player_height = _player.global_position.y
	_last_safe_pos = _player.global_position
	_has_last_safe = _player.is_on_floor()
	_hit_cooldown = 0.0
	visible = true
	if is_instance_valid(_particles):
		_particles.visible = true
		_particles.emitting = true
		_particles.restart()
	queue_redraw()
	print("RISING VOID V3: visible and damaging during FIRST title; rising=false")


# Called only when the FIRST title card is dismissed. This is a brief
# introduction movement, not the long, phase-two climb to risingvoidphase2.
func play_intro_rise() -> void:
	if not _active or not _intro_prepared or _intro_rising:
		return
	_intro_rising = true
	_intro_elapsed = 0.0
	print("RISING VOID V5: title ended, surface emerging into its original height")


# Compatibility: activating the visual does NOT activate rising.
func activate() -> void:
	activate_for_title()


# At the end of King phase one: show platforms, but keep Void stationary.
func start_boss_climb() -> void:
	if enable_climb_tilemap:
		if not is_instance_valid(_climb_tilemap):
			_climb_tilemap = _find_climb_tilemap()
		if is_instance_valid(_climb_tilemap):
			_climb_tilemap.enabled = true
	if not _active:
		activate_for_title()
	print("RISING VOID V3: climbing platforms on; Void still stationary")


# Called by King V56 when the five-second third-ascent countdown finishes.
# Reuses the existing physics move and surface particles; the first phase-two
# rise may have finished already, so reset its completed flag deliberately.
func begin_phase_three_rising() -> void:
	# Called by phase3startdetection, independently of King state.
	# Also safe to call redundantly from the King's reveal event.
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
		var root: Node = get_tree().current_scene
		if is_instance_valid(root):
			marker = root.find_child("risingvoidphase3", true, false) as Marker2D
	if not is_instance_valid(marker):
		if not _phase_three_warned_missing_marker:
			_phase_three_warned_missing_marker = true
			push_warning("RISING VOID V7: risingvoidphase3 Marker2D missing; cannot start final rise")
		return

	# Interrupt the earlier little title animation if it's somehow still running.
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

	# The previous phase can leave the surface THOUSANDS of pixels below
	# the summit. Bring it into view just BELOW the player immediately,
	# then play the visible rise toward the exact third-phase marker.
	# Never move the Void downwards, and never overshoot the stop marker.
	if final_y < before_y:
		var visible_start_y: float = _player.global_position.y + phase_three_enter_view_below_player
		var new_surface_y: float = maxf(final_y + 4.0, minf(before_y, visible_start_y))
		if new_surface_y < before_y:
			global_position.y -= before_y - new_surface_y
		_rising = true
		print("RISING VOID V7: PHASE 3 AREA TOUCHED; visible from y=", _world_surface_top(), " toward y=", final_y)
	else:
		_rising = false
		_rise_completed = true
		print("RISING VOID V7: PHASE 3 AREA TOUCHED; surface already at or above marker")
	queue_redraw()


# Called ONLY when the player enters the upper 2phaseidentifier zone.
func begin_rising() -> void:
	if not _active:
		activate_for_title()
	if _rising or _rise_completed or not _active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		return
	# If the upper fight begins while the intro is still animating, finish
	# the small emergence before calculating the longer climb destination.
	if _intro_rising or _intro_prepared:
		_intro_rising = false
		_intro_prepared = false
		global_position.y = _intro_original_y
	_rise_stop_marker = _find_rise_stop_marker()
	if not is_instance_valid(_rise_stop_marker):
		if not _warned_missing_stop:
			_warned_missing_stop = true
			push_warning("RISING VOID V4: missing risingvoidphase2 Marker2D. Check its name or Rise Stop Marker Path.")
		return
	var current_top_y: float = _world_surface_top()
	var final_top_y: float = _rise_stop_marker.global_position.y
	if final_top_y >= current_top_y:
		_rise_completed = true
		push_warning("RISING VOID V4: stop marker is not ABOVE the Void surface. Move risingvoidphase2 to a smaller Y.")
		return
	_rising = true
	_best_player_height = _player.global_position.y
	print("RISING VOID V4: ascending from y=", current_top_y, " to y=", final_top_y)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if not is_instance_valid(_player):
		return

	_wave_clock += delta
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	# Animate the whole drawn Void, Area2D and particle emitter together.
	# Its final position is EXACTLY where you placed RisingVoid in the editor.
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

	# First-class Phase 3 trigger: no dependence on boss death, his
	# entrance animation, or collision-mask-based body_entered signals.
	if not _phase_three_started and _player_inside_phase_three_area():
		begin_phase_three_rising()
		top_y = _world_surface_top()

	# The King normally calls begin_rising() on upper arena entry.
	# This independent detection covers missing signals / collision masks.
	if not _phase_three_started and not _rising and not _rise_completed:
		if not is_instance_valid(_climb_tilemap):
			_climb_tilemap = _find_climb_tilemap()
		if (not is_instance_valid(_climb_tilemap) or _climb_tilemap.enabled) and _player_inside_phase_two_area():
			begin_rising()

	if _rising:
		if not is_instance_valid(_rise_stop_marker):
			_rise_stop_marker = _find_rise_stop_marker()
		if is_instance_valid(_rise_stop_marker):
			# World Y decreases upwards. Never go below the previous top
			# and never overshoot the user-placed final Marker2D height.
			var destination_y: float = _rise_stop_marker.global_position.y
			if top_y <= destination_y + 0.25:
				_rising = false
				_rise_completed = true
			else:
				var actual_rise_speed: float = phase_three_rise_speed if _phase_three_started else rise_speed
				var new_top_y: float = maxf(destination_y, top_y - actual_rise_speed * delta)
				global_position.y -= (top_y - new_top_y)
				top_y = _world_surface_top()
				if top_y <= destination_y + 0.25:
					_rising = false
					_rise_completed = true
					print("RISING VOID V7: reached final rise marker at y=", top_y)
		else:
			_rising = false
			if not _warned_missing_stop:
				_warned_missing_stop = true
				push_warning("RISING VOID V4: lost stop marker while rising.")

	var limits: Vector2 = _world_surface_x_limits()
	# Save a landed position only if it is fully above the damaging surface.
	if _player.is_on_floor() and _player.global_position.y < top_y - platform_clearance:
		if _player.global_position.x >= limits.x and _player.global_position.x <= limits.y:
			_last_safe_pos = _player.global_position
			_has_last_safe = true

	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.06
		queue_redraw()

	# Damage applies from the surface ALL THE WAY DOWN, but ONLY inside
	# the horizontal length of your existing VoidSurface rectangle.
	var feet_y: float = _player.global_position.y + _player_feet_below_origin()
	if _hit_cooldown <= 0.0 and feet_y >= top_y:
		if _player.global_position.x >= limits.x and _player.global_position.x <= limits.y:
			_on_player_fell_into_void()


func _on_player_fell_into_void() -> void:
	_hit_cooldown = maxf(0.4, fall_cooldown)
	if not is_instance_valid(_player):
		return
	var destination: Vector2 = _choose_safe_platform()
	if _player.has_method(&"tomar_dano"):
		_player.call(&"tomar_dano", maxi(1, damage_per_fall), Vector2(_player.global_position.x, _world_surface_top() + 25.0))
	var current_health: Variant = _player.get("vida")
	if current_health != null and int(current_health) <= 0:
		return # Leave the player's normal death and scene reset untouched.
	_player.global_position = destination
	_player.velocity = Vector2.ZERO
	_player.reset_physics_interpolation()


func _choose_safe_platform() -> Vector2:
	var surface_y: float = _world_surface_top()
	var safe_max_y: float = surface_y - platform_clearance
	if _has_last_safe and _last_safe_pos.y < safe_max_y:
		return _last_safe_pos

	var limits: Vector2 = _world_surface_x_limits()
	var offsets: Array[float] = [0.0, -50.0, 50.0, -100.0, 100.0, -160.0, 160.0, -235.0, 235.0, -320.0, 320.0, -420.0, 420.0]
	var foot: float = _player_feet_below_origin()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var best: Vector2 = Vector2.ZERO
	var best_score: float = INF

	for offset: float in offsets:
		var x: float = _player.global_position.x + offset
		if x < limits.x + 12.0 or x > limits.y - 12.0:
			continue
		var start: Vector2 = Vector2(x, surface_y - 1150.0)
		var end: Vector2 = Vector2(x, safe_max_y - foot - 5.0)
		if start.y >= end.y:
			continue
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, end, terrain_mask)
		query.exclude = [_player.get_rid()]
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		if normal.y > -0.70:
			continue
		var point: Vector2 = hit.get("position", Vector2.ZERO)
		var candidate: Vector2 = point + Vector2(0.0, -foot - 4.0)
		if candidate.y >= safe_max_y:
			continue
		var score: float = candidate.distance_squared_to(_player.global_position)
		if score < best_score:
			best_score = score
			best = candidate

	if best_score < INF:
		_last_safe_pos = best
		_has_last_safe = true
		return best

	if not emergency_respawn_marker.is_empty():
		var marker: Marker2D = get_node_or_null(emergency_respawn_marker) as Marker2D
		if is_instance_valid(marker) and marker.global_position.y < safe_max_y:
			return marker.global_position

	# Emergency fallback. If this happens, add EmergencyRespawn Marker2D
	# above a real platform and assign it in the Inspector.
	return Vector2(clampf(_player.global_position.x, limits.x + 30.0, limits.y - 30.0), surface_y - platform_clearance - 90.0)


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
		height = 2.0 * (body.shape as CircleShape2D).radius
	return maxf(8.0, body.position.y + height * 0.5 * absf(body.scale.y))


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
		var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y: int in range(8):
			for x: int in range(8):
				if Vector2(float(x) - 3.5, float(y) - 3.5).length_squared() < 10.0:
					image.set_pixel(x, y, Color(0.004, 0.004, 0.009, 0.85))
		_particles.texture = ImageTexture.create_from_image(image)


func _draw() -> void:
	if not _active:
		return
	var area: Rect2 = _local_surface_rect()
	var left: float = area.position.x
	var right: float = area.end.x
	var top: float = area.position.y
	# Solid black from the exact Area2D top down. No sprite and no tile gaps.
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
