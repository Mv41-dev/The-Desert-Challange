# V5: no spawns inside nospawnarea/bossarena; phase-2 boss starts with no Void enemies.
# VOID NECROMANCER V4 - No passive contact damage, clearer attacks / The Abyss
# V3 shared cooldown, auto-spawning, afterimages and chase all preserved.
# Individual Void Necromancers may attack at the same time.
# Place ONE instance of this scene in the level, anywhere (even in a corner).
# That invisible instance becomes the shared spawner/director, and generates
# new Void Necromancers near the player ONE AT A TIME with a shared cooldown.
# Maximum 3 simultaneously active, including their appearance warnings.
# Afterimages are genuinely translucent, stationary and face the player.
# 10 HP, dark silhouette, 22 -> 95 px/s in one second, no summoning/revival.
# Requires the existing AnimatedSprite2D and CollisionShape2D.
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

enum State { HIDDEN, SPAWN_WARNING, APPEARING, HUNTING, DEAD }

const VOID_HP: int = 10

@export_group("One Shared Spawn Director")
# Only the FIRST placed Void Necro manages these timers.
# Generated Necros DO NOT control the spawn timer or create copies.
@export_range(0.5, 15.0, 0.5) var first_spawn_delay_min: float = 2.5
@export_range(1.0, 20.0, 0.5) var first_spawn_delay_max: float = 4.5
@export_range(1.0, 20.0, 0.5) var global_spawn_cooldown_min: float = 4.0
@export_range(1.0, 30.0, 0.5) var global_spawn_cooldown_max: float = 6.5
@export var source_scene_override: PackedScene  # Optional; normally detected automatically.
@export_range(400.0, 1800.0, 50.0) var offscreen_despawn_distance: float = 850.0
@export_range(0.5, 8.0, 0.5) var offscreen_despawn_delay: float = 2.0
@export_range(1, 12, 1) var max_active_void_necros: int = 3
@export_range(80.0, 350.0, 10.0) var spawn_min_distance: float = 180.0
@export_range(170.0, 600.0, 10.0) var spawn_max_distance: float = 320.0
@export_range(20.0, 110.0, 5.0) var spawn_screen_margin: float = 50.0
@export_range(10.0, 60.0, 5.0) var spawn_clearance: float = 26.0
@export_flags_2d_physics var spawn_terrain_mask: int = 1
@export_range(0.2, 1.2, 0.05) var spawn_warning_seconds: float = 0.45
@export_range(0.2, 1.5, 0.05) var reverse_death_reveal_seconds: float = 0.58

@export_group("Shadow Speed - First Second")
# New export names so old V1 Inspector overrides (140/225) cannot carry over.
@export_range(5.0, 50.0, 1.0) var emergence_speed: float = 22.0
@export_range(50.0, 130.0, 1.0) var maximum_shadow_speed: float = 95.0
@export_range(0.4, 3.0, 0.05) var time_to_full_speed: float = 1.0
@export_range(100.0, 1600.0, 50.0) var aerial_acceleration: float = 430.0
@export var face_right_by_default: bool = true

@export_group("Harmless Shadow Afterimages")
@export var spawn_harmless_afterimages: bool = true
@export_range(2.0, 20.0, 0.5) var afterimage_interval_min: float = 6.5
@export_range(3.0, 25.0, 0.5) var afterimage_interval_max: float = 11.0
@export_range(1, 8, 1) var max_afterimages_visible: int = 3
@export_range(70.0, 300.0, 10.0) var afterimage_min_distance: float = 110.0
@export_range(130.0, 550.0, 10.0) var afterimage_max_distance: float = 300.0
@export_range(25.0, 110.0, 5.0) var afterimage_disappear_distance: float = 58.0
@export_range(0.05, 0.6, 0.05) var afterimage_opacity: float = 0.24
@export_range(2.0, 15.0, 0.5) var afterimage_stay_seconds: float = 8.0

@export_group("Close Black Slashes")
@export_range(40.0, 160.0, 5.0) var slash_activation_distance: float = 82.0
@export_range(55.0, 200.0, 5.0) var slash_length: float = 110.0
@export_range(0.2, 1.2, 0.05) var slash_warning_seconds: float = 0.72
@export_range(1.0, 6.0, 0.1) var slash_cooldown_seconds: float = 3.2
@export_range(1, 5, 1) var slash_damage: int = 1

@export_group("Void Pulse - Rare Close-range Attack")
@export_range(35.0, 125.0, 5.0) var pulse_radius: float = 65.0
@export_range(0.25, 1.5, 0.05) var pulse_warning_seconds: float = 0.85
@export_range(4.0, 18.0, 0.5) var pulse_cooldown_seconds: float = 8.5
@export_range(1, 5, 1) var pulse_damage: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

class ShadowSlash:
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var delay: float = 0.0
	var timer: float = 0.0
	var warning: float = 0.72
	var fired: bool = false

var max_hp: int = VOID_HP
var hp: int = VOID_HP
var state: State = State.HIDDEN
var target: CharacterBody2D = null
var initial_collision_layer: int = 0
var director_spawn_left: float = 0.0
var far_away_time: float = 0.0
var spawn_warning_left: float = 0.0
var afterimage_spawn_left: float = 0.0
var appearing_time_left: float = 0.0
var appearance_has_death_animation: bool = false
var chase_time: float = 0.0
var aura_time: float = 0.0
var slash_timer: float = 1.0
var pulse_timer: float = 5.0
var pulse_charge_timer: float = 0.0
var pulse_impact_visual: float = 0.0
var damage_flash_timer: float = 0.0
var slashes: Array[ShadowSlash] = []
var void_material: ShaderMaterial = null


func _void_king_phase_two_active() -> bool:
	var root: Node = get_tree().current_scene
	return root != null and bool(root.get_meta(&"level6_boss_active", false))


func _void_spawn_in_protected_area(point: Vector2) -> bool:
	# Exclusion zones: your nospawnarea and bossarena Area2D rectangles.
	# This is a position test; Area2D monitoring alone will NOT reject spawn points.
	var level: Node = get_tree().current_scene
	if level == null:
		return false
	var area_nodes: Array[Node] = []
	for area_name: String in ["nospawnarea", "bossarena"]:
		var named: Node = level.find_child(area_name, true, false)
		if named != null and not area_nodes.has(named):
			area_nodes.append(named)
	for named: Node in get_tree().get_nodes_in_group(&"void_no_spawn"):
		if named is Area2D and not area_nodes.has(named):
			area_nodes.append(named)
	for item: Node in area_nodes:
		var area: Area2D = item as Area2D
		if area == null:
			continue
		for child: Node in area.find_children("*", "CollisionShape2D", true, false):
			var collider: CollisionShape2D = child as CollisionShape2D
			if collider == null or collider.disabled or collider.shape == null:
				continue
			var local: Vector2 = collider.to_local(point)
			var scale_abs: Vector2 = collider.global_scale.abs()
			var margin_x: float = spawn_clearance / maxf(0.05, scale_abs.x)
			var margin_y: float = spawn_clearance / maxf(0.05, scale_abs.y)
			if collider.shape is RectangleShape2D:
				var size2: Vector2 = (collider.shape as RectangleShape2D).size * 0.5
				if absf(local.x) <= size2.x + margin_x and absf(local.y) <= size2.y + margin_y:
					return true
			elif collider.shape is CircleShape2D:
				var radius: float = (collider.shape as CircleShape2D).radius + maxf(margin_x, margin_y)
				if local.length_squared() <= radius * radius:
					return true
	return false


func _ready() -> void:
	# The editor may have retained the original Necro HP. This variant is
	# ALWAYS 10 HP, even if the original scene was duplicated.
	max_hp = VOID_HP
	hp = VOID_HP
	initial_collision_layer = collision_layer
	director_spawn_left = randf_range(
		first_spawn_delay_min,
		maxf(first_spawn_delay_min, first_spawn_delay_max)
	)
	afterimage_spawn_left = randf_range(
		afterimage_interval_min,
		maxf(afterimage_interval_min, afterimage_interval_max)
	)
	slash_timer = randf_range(0.8, 1.5)
	pulse_timer = randf_range(4.0, maxf(4.1, pulse_cooldown_seconds))
	collision_layer = 0
	collision_mask = 0  # Fly through cliffs and platforms.
	visible = false
	velocity = Vector2.ZERO
	add_to_group(&"inimigo")
	add_to_group(&"enemy")
	add_to_group(&"void_necromancer")
	# Avoid joining the original Necromancer's summoning and revival logic.
	if is_in_group(&"necromancer"):
		remove_from_group(&"necromancer")

	var generated: bool = bool(get_meta(&"void_necro_generated", false))
	if generated:
		# Copies never become a director, even when their source inherited groups.
		remove_from_group(&"void_necro_director")
	elif get_tree().get_nodes_in_group(&"void_necro_director").is_empty():
		# The first placed instance is an invisible, permanent spawn manager.
		add_to_group(&"void_necro_director")
		remove_from_group(&"inimigo")
		remove_from_group(&"enemy")
		remove_from_group(&"void_necromancer")
	else:
		# Extra manually placed instances are kept hidden and disabled.
		# One is enough; this prevents simultaneous independent spawners.
		remove_from_group(&"inimigo")
		remove_from_group(&"enemy")
		remove_from_group(&"void_necromancer")
		set_physics_process(false)

	_prepare_shadow_sprite()
	target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if generated:
		_ignore_physical_player_collision()
	health_changed.emit(hp, max_hp)


func _prepare_shadow_sprite() -> void:
	# No red detection: eyes, staff, highlights, ALL pixels become dark.
	# Original transparent pixels remain transparent.
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float fade_alpha = 1.0;
uniform float hit_flash = 0.0;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 shadow = mix(vec3(0.003, 0.004, 0.007),
                      vec3(0.045, 0.047, 0.055),
                      clamp(luminance * 0.75, 0.0, 1.0));
    shadow = mix(shadow, vec3(0.22, 0.23, 0.27), hit_flash);
    COLOR = vec4(shadow, tex.a * fade_alpha);
}
"""
	void_material = ShaderMaterial.new()
	void_material.shader = shader
	sprite.material = void_material
	sprite.self_modulate = Color.WHITE
	if sprite.sprite_frames != null:
		# Only modify this instance's SpriteFrames. A copied scene may share
		# the same SpriteFrames resource with regular Necromancers.
		sprite.sprite_frames = sprite.sprite_frames.duplicate() as SpriteFrames
		if sprite.sprite_frames.has_animation(&"death"):
			sprite.sprite_frames.set_animation_loop(&"death", false)
	_play(&"idle")


func _physics_process(delta: float) -> void:
	# The King has reached phase 2: clear prior Void shadows and stop new ones.
	if _void_king_phase_two_active():
		if is_in_group(&"void_necro_director"):
			for shadow_node: Node in get_tree().get_nodes_in_group(&"void_necromancer_active"):
				if is_instance_valid(shadow_node) and not shadow_node.is_queued_for_deletion():
					shadow_node.queue_free()
			for shadow_ghost: Node in get_tree().get_nodes_in_group(&"void_necro_afterimage"):
				if is_instance_valid(shadow_ghost) and not shadow_ghost.is_queued_for_deletion():
					shadow_ghost.queue_free()
		else:
			queue_free()
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		if not is_in_group(&"void_necro_director"):
			_ignore_physical_player_collision()
	if not is_instance_valid(target):
		return

	# IMPORTANT: One shared clock for every real Necro. No per-copy timers.
	if is_in_group(&"void_necro_director"):
		_update_director(delta)
		if spawn_harmless_afterimages:
			_update_harmless_afterimages(delta)
		return

	if state == State.DEAD:
		return

	match state:
		State.HIDDEN:
			# A generated enemy is activated by its director at a safe spot.
			return
		State.SPAWN_WARNING:
			spawn_warning_left -= delta
			queue_redraw()
			if spawn_warning_left <= 0.0:
				_begin_appearance()
			return
		State.APPEARING:
			_update_appearance(delta)
			return
		State.HUNTING:
			_update_hunt(delta)


func _update_director(delta: float) -> void:
	# This node stays invisible. Its only job is to generate real enemies
	# at independent times and to manage harmless ghost sightings.
	director_spawn_left -= delta
	if director_spawn_left > 0.0:
		return

	# Consume a cooldown even if the spawn attempt fails or the cap is hit.
	# Prevents several spawns on the very next frame when a slot frees up.
	director_spawn_left = randf_range(
		global_spawn_cooldown_min,
		maxf(global_spawn_cooldown_min, global_spawn_cooldown_max)
	)
	if _active_necro_count() >= max_active_void_necros:
		return

	var spots: Array[Vector2] = _find_visible_spawn(
		spawn_min_distance, spawn_max_distance
	)
	if spots.is_empty():
		return

	var new_enemy: CharacterBody2D = _make_void_necro_copy()
	if new_enemy == null:
		return

	# Set metadata BEFORE add_child, because _ready() runs at add_child.
	new_enemy.set_meta(&"void_necro_generated", true)
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_parent()
	level.add_child(new_enemy)
	new_enemy.global_position = spots[0]
	new_enemy.call(&"_begin_spawn_warning", spots[0])


func _make_void_necro_copy() -> CharacterBody2D:
	var source: PackedScene = source_scene_override
	if source == null and not scene_file_path.is_empty():
		source = load(scene_file_path) as PackedScene
	if source != null:
		var spawned: Node = source.instantiate()
		if spawned is CharacterBody2D:
			return spawned as CharacterBody2D
		spawned.queue_free()

	# If the enemy has no saved scene path, try cloning the placed node.
	# A separately saved void_necro.tscn is preferable for reliability.
	var cloned: Node = duplicate()
	if cloned is CharacterBody2D:
		return cloned as CharacterBody2D
	cloned.queue_free()
	push_warning("Void Necro: save the enemy as its own .tscn scene for auto-spawning.")
	return null

# =============================================================
# RANDOM ON-SCREEN MATERIALIZATION
# =============================================================
func _active_necro_count() -> int:
	return get_tree().get_nodes_in_group(&"void_necromancer_active").size()


func _begin_spawn_warning(at_world: Vector2) -> void:
	if state != State.HIDDEN:
		return
	global_position = at_world
	velocity = Vector2.ZERO
	state = State.SPAWN_WARNING
	spawn_warning_left = maxf(0.2, spawn_warning_seconds)
	visible = true
	sprite.visible = false
	add_to_group(&"void_necromancer_active")
	queue_redraw()


func _find_visible_spawn(min_distance: float, max_distance: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not is_instance_valid(target):
		return result

	var camera: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = target.global_position
	var half_size: Vector2 = get_viewport_rect().size * 0.5
	if is_instance_valid(camera):
		center = camera.get_screen_center_position()
		half_size /= Vector2(maxf(0.01, absf(camera.zoom.x)),
			maxf(0.01, absf(camera.zoom.y)))
	var safe_half: Vector2 = half_size - Vector2.ONE * spawn_screen_margin
	if safe_half.x < 35.0 or safe_half.y < 35.0:
		return result
	var visible_region: Rect2 = Rect2(center - safe_half, safe_half * 2.0)

	for attempt: int in range(36):
		var distance: float = randf_range(min_distance, maxf(min_distance, max_distance))
		var offset: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * distance
		var candidate: Vector2 = target.global_position + offset
		if not visible_region.has_point(candidate):
			continue
		if _void_spawn_in_protected_area(candidate):
			continue
		if _blocked_by_terrain(candidate):
			continue
		var too_close: bool = false
		for enemy: Node in get_tree().get_nodes_in_group(&"void_necromancer_active"):
			if enemy is Node2D and (enemy as Node2D).global_position.distance_squared_to(candidate) < 90.0 * 90.0:
				too_close = true
				break
		if too_close:
			continue
		result.append(candidate)
		return result
	return result


func _blocked_by_terrain(candidate: Vector2) -> bool:
	# Circle query: avoid emerging within a wall or floating platform.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = spawn_clearance
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = spawn_terrain_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return not space.intersect_shape(query, 1).is_empty()


# =============================================================
# STATIONARY GHOSTS - PURELY VISUAL, NO COLLISION/DAMAGE
# =============================================================
func _update_harmless_afterimages(delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"void_necro_afterimage"):
		var ghost: Node2D = node as Node2D
		if ghost == null or not is_instance_valid(ghost):
			continue
		# Never move the illusion; only flip it to stare at the player.
		var figure: AnimatedSprite2D = ghost.get_node_or_null("DarkStillFigure") as AnimatedSprite2D
		if figure != null:
			figure.flip_h = (target.global_position.x > ghost.global_position.x) != face_right_by_default
		if bool(ghost.get_meta(&"already_fading", false)):
			continue
		if ghost.global_position.distance_squared_to(target.global_position) <= afterimage_disappear_distance * afterimage_disappear_distance:
			_fade_afterimage(ghost)

	afterimage_spawn_left -= delta
	if afterimage_spawn_left > 0.0:
		return
	afterimage_spawn_left = randf_range(
		afterimage_interval_min, maxf(afterimage_interval_min, afterimage_interval_max)
	)
	# These are occasional harmless sightings, not an endless stream.
	if randf() > 0.60:
		return
	if get_tree().get_nodes_in_group(&"void_necro_afterimage").size() >= max_afterimages_visible:
		return
	var places: Array[Vector2] = _find_visible_spawn(afterimage_min_distance, afterimage_max_distance)
	if places.is_empty():
		return
	_create_afterimage(places[0])


func _create_afterimage(at_world: Vector2) -> void:
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_parent()
	var ghost: Node2D = Node2D.new()
	ghost.name = "HarmlessVoidAfterimage"
	ghost.z_index = z_index
	level.add_child(ghost)
	ghost.global_position = at_world
	ghost.add_to_group(&"void_necro_afterimage")

	var figure: AnimatedSprite2D = AnimatedSprite2D.new()
	figure.name = "DarkStillFigure"
	figure.sprite_frames = sprite.sprite_frames
	figure.position = sprite.position
	figure.scale = sprite.scale
	figure.offset = sprite.offset
	figure.centered = sprite.centered
	figure.flip_h = (target.global_position.x > at_world.x) != face_right_by_default
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		figure.animation = &"idle"
		figure.frame = 0
	figure.stop()  # Absolutely stationary; no attack, collision or movement.

	# Use an INDEPENDENT shader uniform for the transparency. The old V2
	# only tweened Node2D.modulate, which the fragment shader could ignore.
	var ghost_material: ShaderMaterial = void_material.duplicate() as ShaderMaterial
	ghost_material.set_shader_parameter("hit_flash", 0.0)
	ghost_material.set_shader_parameter("fade_alpha", 0.0)
	figure.material = ghost_material
	ghost.add_child(figure)
	ghost.set_meta(&"ghost_material", ghost_material)

	var fade: Tween = ghost.create_tween()
	fade.tween_method(_set_ghost_alpha.bind(ghost_material), 0.0, afterimage_opacity, 0.80)
	fade.tween_interval(afterimage_stay_seconds)
	fade.tween_method(_set_ghost_alpha.bind(ghost_material), afterimage_opacity, 0.0, 0.55)
	fade.tween_callback(ghost.queue_free)
	ghost.set_meta(&"fade_tween", fade)


func _set_ghost_alpha(value: float, material: ShaderMaterial) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("fade_alpha", clampf(value, 0.0, 1.0))


func _fade_afterimage(ghost: Node2D) -> void:
	ghost.set_meta(&"already_fading", true)
	var active_tween: Variant = ghost.get_meta(&"fade_tween", null)
	if active_tween is Tween:
		(active_tween as Tween).kill()
	var material: ShaderMaterial = ghost.get_meta(&"ghost_material", null) as ShaderMaterial
	if material == null:
		ghost.queue_free()
		return
	var current_alpha: float = float(material.get_shader_parameter("fade_alpha"))
	var fade: Tween = ghost.create_tween()
	fade.tween_method(_set_ghost_alpha.bind(material), current_alpha, 0.0, 0.25)
	fade.tween_callback(ghost.queue_free)

func _ignore_physical_player_collision() -> void:
	# It can TOUCH and hurt the player, but cannot push/launch them.
	if is_instance_valid(target):
		add_collision_exception_with(target)
		target.add_collision_exception_with(self)


func _begin_appearance() -> void:
	if state != State.SPAWN_WARNING:
		return
	state = State.APPEARING
	visible = true
	sprite.visible = true
	velocity = Vector2.ZERO
	appearing_time_left = maxf(0.20, reverse_death_reveal_seconds)
	appearance_has_death_animation = (
		sprite.sprite_frames != null
		and sprite.sprite_frames.has_animation(&"death")
	)
	if appearance_has_death_animation:
		var frames: SpriteFrames = sprite.sprite_frames
		var total: float = 0.0
		var count: int = frames.get_frame_count(&"death")
		var fps: float = maxf(1.0, frames.get_animation_speed(&"death"))
		for index: int in range(count):
			total += frames.get_frame_duration(&"death", index) / fps
		var playback_multiplier: float = maxf(0.1, total / appearing_time_left)
		sprite.play(&"death", -playback_multiplier, true)
		void_material.set_shader_parameter("fade_alpha", 1.0)
	else:
		_play(&"idle", true)
		void_material.set_shader_parameter("fade_alpha", 0.0)


func _update_appearance(delta: float) -> void:
	appearing_time_left = maxf(0.0, appearing_time_left - delta)
	if not appearance_has_death_animation:
		var ratio: float = 1.0 - appearing_time_left / maxf(0.20, reverse_death_reveal_seconds)
		void_material.set_shader_parameter("fade_alpha", clampf(ratio, 0.0, 1.0))
	if appearing_time_left > 0.0:
		return
	state = State.HUNTING
	collision_layer = initial_collision_layer
	void_material.set_shader_parameter("fade_alpha", 1.0)
	sprite.speed_scale = 1.0
	_play(&"idle", true)


func _update_hunt(delta: float) -> void:
	# On a very long vertical climb, recycle an enemy left far behind so
	# its active slot can be filled by a new visible spawn later.
	if global_position.distance_squared_to(target.global_position) > offscreen_despawn_distance * offscreen_despawn_distance:
		far_away_time += delta
		if far_away_time >= offscreen_despawn_delay:
			remove_from_group(&"void_necromancer_active")
			queue_free()
			return
	else:
		far_away_time = 0.0
	chase_time += delta
	aura_time += delta
	slash_timer = maxf(0.0, slash_timer - delta)
	pulse_timer = maxf(0.0, pulse_timer - delta)
	pulse_impact_visual = maxf(0.0, pulse_impact_visual - delta)
	damage_flash_timer = maxf(0.0, damage_flash_timer - delta)
	void_material.set_shader_parameter("hit_flash", clampf(damage_flash_timer * 6.0, 0.0, 1.0))

	# Smooth ease-in over ~1s, then stays at the MUCH slower cap.
	var t: float = clampf(chase_time / maxf(0.1, time_to_full_speed), 0.0, 1.0)
	var ease: float = t * t * (3.0 - 2.0 * t)
	var chase_speed: float = lerpf(
		emergence_speed, maximum_shadow_speed, ease
	)
	var to_player: Vector2 = target.global_position - global_position
	if absf(to_player.x) > 5.0:
		sprite.flip_h = (to_player.x > 0.0) != face_right_by_default

	# Continuous flying pursuit; ignores terrain, like an Abyss shade.
	var desired_velocity: Vector2 = to_player.normalized() * chase_speed
	if to_player.length() < 8.0:
		desired_velocity = Vector2.ZERO
	if pulse_charge_timer > 0.0 or not slashes.is_empty():
		# Hold position for the warning so the attack reads clearly.
		desired_velocity = Vector2.ZERO
	velocity = velocity.move_toward(desired_velocity, aerial_acceleration * delta)
	global_position += velocity * delta

	_update_slashes(delta)
	_update_pulse(delta)

	# Don't stack slash and pulse from the SAME Necro. Different Necros
	# can still attack simultaneously; there's no shared attack cooldown.
	if pulse_charge_timer <= 0.0 and slashes.is_empty():
		var range_to_player: float = global_position.distance_to(target.global_position)
		if pulse_timer <= 0.0 and range_to_player <= pulse_radius + 12.0:
			_begin_void_pulse()
		elif slash_timer <= 0.0 and range_to_player <= minf(slash_activation_distance, 82.0):
			_begin_close_slashes()

	if sprite.animation != &"idle":
		_play(&"idle")
	queue_redraw()


func _damage_player(amount: int, from_position: Vector2) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method(&"tomar_dano"):
		target.call(&"tomar_dano", amount, from_position)
	elif target.has_method(&"take_damage"):
		target.call(&"take_damage", amount, from_position)


func _begin_close_slashes() -> void:
	# Enforce V4's readability even if V3 export values persist in Inspector.
	slash_timer = maxf(3.2, slash_cooldown_seconds)
	# Lock the attack to the CURRENT location; no surprise leading.
	var center: Vector2 = target.global_position
	var x_pattern: bool = randf() < 0.25
	var count: int = 2 if x_pattern else 1
	var first_angle: float = PI * 0.25 if randf() < 0.5 else PI * 0.75
	for i: int in range(count):
		var angle: float = first_angle if i == 0 else PI - first_angle
		# Short slashes only. Nothing crosses the entire camera or arena.
		var vector: Vector2 = Vector2.RIGHT.rotated(angle) * (minf(slash_length, 110.0) * 0.5)
		var shot: ShadowSlash = ShadowSlash.new()
		shot.a = center - vector
		shot.b = center + vector
		shot.delay = float(i) * 0.36
		shot.warning = maxf(0.72, slash_warning_seconds)
		slashes.append(shot)


func _update_slashes(delta: float) -> void:
	for index: int in range(slashes.size() - 1, -1, -1):
		var slash: ShadowSlash = slashes[index]
		slash.timer += delta
		var fire_at: float = slash.delay + slash.warning
		if not slash.fired and slash.timer >= fire_at:
			slash.fired = true
			if _slash_hits_player(slash):
				_damage_player(slash_damage, (slash.a + slash.b) * 0.5)
		if slash.timer >= fire_at + 0.20:
			slashes.remove_at(index)


func _slash_hits_player(slash: ShadowSlash) -> bool:
	# Cheap distance-to-segment test instead of constructing long Physics
	# rectangle shapes every frame (the old Necro's expensive pattern).
	var a_to_b: Vector2 = slash.b - slash.a
	var length_squared: float = a_to_b.length_squared()
	if length_squared <= 0.0001:
		return false
	var t: float = clampf((target.global_position - slash.a).dot(a_to_b) / length_squared, 0.0, 1.0)
	var nearest_point: Vector2 = slash.a + a_to_b * t
	return nearest_point.distance_squared_to(target.global_position) <= 18.0 * 18.0


func _begin_void_pulse() -> void:
	pulse_timer = maxf(8.5, pulse_cooldown_seconds)
	pulse_charge_timer = maxf(0.85, pulse_warning_seconds)
	# Pulse is a weaker, local zone denial attack, never a screen-wide beam.


func _update_pulse(delta: float) -> void:
	if pulse_charge_timer <= 0.0:
		return
	pulse_charge_timer = maxf(0.0, pulse_charge_timer - delta)
	if pulse_charge_timer > 0.0:
		return
	pulse_impact_visual = 0.28
	if global_position.distance_squared_to(target.global_position) <= pulse_radius * pulse_radius:
		_damage_player(pulse_damage, global_position)


func can_receive_player_hit() -> bool:
	return state == State.HUNTING


func is_dead() -> bool:
	return state == State.DEAD


func is_reviving() -> bool:
	# This Void variant never resurrects, and never resurrects minions.
	return false


func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or not can_receive_player_hit():
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp > 0:
		damage_flash_timer = 0.13
		return
	_die()


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	remove_from_group(&"void_necromancer_active")
	remove_from_group(&"void_necromancer")
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	slashes.clear()
	pulse_charge_timer = 0.0
	pulse_impact_visual = 0.0
	void_material.set_shader_parameter("hit_flash", 0.0)
	queue_redraw()
	died.emit()
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"death"):
		queue_free()
		return
	sprite.speed_scale = 1.0
	sprite.play(&"death", 1.0, false)
	var frames: SpriteFrames = sprite.sprite_frames
	var seconds: float = 0.0
	var fps: float = maxf(1.0, frames.get_animation_speed(&"death"))
	for index: int in range(frames.get_frame_count(&"death")):
		seconds += frames.get_frame_duration(&"death", index) / fps
	get_tree().create_timer(maxf(0.20, seconds)).timeout.connect(queue_free)


func _play(animation: StringName, restart: bool = false) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return
	if restart:
		sprite.stop()
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _draw() -> void:
	if state == State.SPAWN_WARNING:
		var p: float = 1.0 - clampf(spawn_warning_left / maxf(0.1, spawn_warning_seconds), 0.0, 1.0)
		# Faint, readable telegraph BEFORE the real Necro materializes.
		draw_arc(Vector2.ZERO, 18.0 + p * 12.0, 0.0, TAU, 24,
			Color(0.32, 0.34, 0.40, 0.42 * (1.0 - p * 0.35)), 2.0)
		draw_circle(Vector2.ZERO, 5.0 + p * 5.0,
			Color(0.11, 0.12, 0.16, 0.18 + p * 0.20))
		return
	if state != State.HUNTING and state != State.APPEARING:
		return
	# Cheap, soft void motes. A faint grey edge keeps them readable against
	# the almost-black Abyss background. Sprite is drawn over these motes.
	var opacity: float = 0.85 if state == State.HUNTING else 0.45
	for i: int in range(7):
		var theta: float = aura_time * (0.70 + float(i) * 0.065) + float(i) * 2.399
		var offset: Vector2 = Vector2(cos(theta) * (20.0 + float(i % 3) * 6.0),
			sin(theta * 0.76) * (15.0 + float(i % 2) * 8.0))
		var radius: float = float(4 + i % 3)
		draw_circle(offset, radius + 1.0, Color(0.23, 0.24, 0.30, opacity * 0.14))
		draw_circle(offset, radius, Color(0.008, 0.009, 0.015, opacity * 0.50))

	for slash: ShadowSlash in slashes:
		if slash.timer < slash.delay:
			continue
		var a: Vector2 = to_local(slash.a)
		var b: Vector2 = to_local(slash.b)
		if not slash.fired:
			var charge: float = clampf((slash.timer - slash.delay) / slash.warning, 0.0, 1.0)
			draw_line(a, b, Color(0.35, 0.37, 0.43, 0.20 + charge * 0.42), 3.0)
			draw_line(a, b, Color(0.08, 0.09, 0.13, 0.20 + charge * 0.32), 8.0)
		else:
			var alpha: float = clampf(1.0 - (slash.timer - slash.delay - slash.warning) / 0.20, 0.0, 1.0)
			draw_line(a, b, Color(0.33, 0.34, 0.41, alpha * 0.75), 14.0)
			draw_line(a, b, Color(0.005, 0.006, 0.012, alpha), 10.0)

	if pulse_charge_timer > 0.0:
		var progress: float = clampf(pulse_charge_timer / maxf(0.85, pulse_warning_seconds), 0.0, 1.0)
		draw_arc(Vector2.ZERO, pulse_radius * (0.55 + 0.45 * (1.0 - progress)),
			0.0, TAU, 30, Color(0.40, 0.42, 0.48, 0.32 + (1.0 - progress) * 0.25), 2.0)
	elif pulse_impact_visual > 0.0:
		var progress: float = 1.0 - pulse_impact_visual / 0.28
		draw_arc(Vector2.ZERO, pulse_radius * (0.5 + 0.5 * progress),
			0.0, TAU, 30, Color(0.22, 0.24, 0.30, 0.72 * (1.0 - progress)), 5.0)
