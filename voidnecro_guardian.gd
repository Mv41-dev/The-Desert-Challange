
# THE DESERT CHALLENGE
# Lapis-Lazuli Corrupted Guardian V5
#
# ALL Guardian attacks deal half a heart per hit.
# Two valid hits remove one whole heart.
#
# Normal Void Necromancers are unaffected.
# Guardian HP, attacks, AI and movement are unchanged.

extends "res://voidnecro.gd"

@export_group("Guardian / Special Encounter")
@export_range(10, 150, 1) var guardian_health: int = 40
@export_range(1.0, 2.0, 0.05) var guardian_scale: float = 1.24
@export_range(1.0, 4.0, 0.1) var guardian_slash_length_multiplier: float = 2.25
@export_range(1.0, 3.0, 0.1) var guardian_slash_width_multiplier: float = 1.8

@export_group("Guardian / Light Spears")
@export var guardian_light_spears_enabled: bool = true
@export_range(2.5, 12.0, 0.25) var guardian_spear_cooldown: float = 6.0
@export_range(1, 5, 1) var guardian_spear_count: int = 2
@export_range(0.2, 1.2, 0.05) var guardian_spear_warning: float = 0.75
@export_range(160.0, 800.0, 20.0) var guardian_spear_speed: float = 340.0
@export_range(1, 3, 1) var guardian_spear_damage: int = 1
@export_flags_2d_physics var guardian_spear_terrain_mask: int = 1

@export_group("Guardian / Corruption Proximity")
@export var guardian_corruption_enabled: bool = true
@export_range(30.0, 110.0, 5.0) var guardian_corruption_range: float = 68.0
@export_range(0.4, 2.0, 0.05) var guardian_corruption_charge_time: float = 1.0
@export_range(2.0, 10.0, 0.25) var guardian_corruption_cooldown: float = 4.0
@export_range(1, 3, 1) var guardian_corruption_damage: int = 1

@export_group("Guardian / Half-Heart Damage")
@export_range(0.2, 1.5, 0.05) var guardian_hit_recovery: float = 0.85


class GuardianLightSpear:
	var position: Vector2 = Vector2.ZERO
	var aim: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.DOWN
	var elapsed: float = 0.0
	var delay: float = 0.0
	var warning: float = 0.75
	var aim_lock_time: float = 0.025
	var fade_time: float = 0.24
	var launched: bool = false
	var flight: float = 0.0
	var hit: bool = false
	var trail: Array[Vector2] = []


var guardian_spears: Array[GuardianLightSpear] = []
var guardian_spear_clock: float = 3.2
var guardian_corruption_charge: float = 0.0
var guardian_corruption_clock: float = 1.0
var guardian_aura_clock: float = 0.0
var guardian_corruption_pulse: float = 0.0

var guardian_half_hits: int = 0
var guardian_hit_recovery_remaining: float = 0.0


func _ready() -> void:
	super._ready()

	if not bool(get_meta(&"relic_guardian_special", false)):
		push_warning(
			"Guardian Void Necro: use only through corruptionarea.gd"
		)

	max_hp = guardian_health
	hp = guardian_health

	scale *= guardian_scale

	spawn_warning_seconds = 0.15
	reverse_death_reveal_seconds = 0.24
	slash_timer = 1.4
	pulse_timer = 4.4

	guardian_spear_clock = 3.2
	guardian_corruption_clock = 1.3

	guardian_half_hits = 0
	guardian_hit_recovery_remaining = 0.0

	offscreen_despawn_distance = 3000.0
	offscreen_despawn_delay = 90.0
	spawn_harmless_afterimages = false

	add_to_group(&"relic_corrupted_guardian")
	health_changed.emit(hp, max_hp)

	print(
		"RELIC GUARDIAN: ",
		hp,
		" HP. All attacks use half-heart damage."
	)


# ============================================================
# CENTRAL HALF-HEART DAMAGE
#
# The inherited Void Necro attacks use _damage_player().
# The special Light Spears and proximity attack use it too.
#
# Player HP is currently integer-based:
# 1 hit = 0.5 heart accumulated
# 2 hits = 1 heart actually deducted
#
# We do not alter the ordinary Void Necromancer.
# ============================================================

func _damage_player(
	amount: int,
	origin: Vector2 = Vector2.ZERO
) -> void:

	if amount <= 0:
		return

	if not is_instance_valid(target):
		return

	if state == State.DEAD:
		return

	# Avoid counting the same attack on consecutive frames.
	if guardian_hit_recovery_remaining > 0.0:
		return

	# Respect the existing player's invulnerability.
	var invulnerability: Variant = target.get(
		"tempo_invulneravel_restante"
	)

	if invulnerability is float or invulnerability is int:
		if float(invulnerability) > 0.0:
			return

	guardian_hit_recovery_remaining = guardian_hit_recovery

	# Every Guardian hit is worth half a heart, regardless
	# of which attack originally requested the damage.
	guardian_half_hits += 1

	if guardian_half_hits >= 2:
		guardian_half_hits = 0

		# One complete heart, after two half-heart hits.
		super._damage_player(1, origin)


func _physics_process(delta: float) -> void:

	guardian_hit_recovery_remaining = maxf(
		0.0,
		guardian_hit_recovery_remaining - delta
	)

	super._physics_process(delta)

	if not is_inside_tree():
		return

	if state == State.DEAD:
		guardian_spears.clear()
		guardian_corruption_charge = 0.0
		return

	guardian_aura_clock += delta

	guardian_corruption_pulse = maxf(
		0.0,
		guardian_corruption_pulse - delta
	)

	if state != State.HUNTING or not is_instance_valid(target):
		queue_redraw()
		return

	guardian_spear_clock = maxf(
		0.0,
		guardian_spear_clock - delta
	)

	guardian_corruption_clock = maxf(
		0.0,
		guardian_corruption_clock - delta
	)

	_update_guardian_spears(delta)
	_update_guardian_corruption(delta)

	if guardian_light_spears_enabled and guardian_spear_clock <= 0.0:
		if global_position.distance_to(
			target.global_position
		) <= 550.0:
			_start_guardian_spears()

	queue_redraw()


# ============================================================
# ORIGINAL ENLARGED SLASHES
# ============================================================

func _begin_close_slashes() -> void:
	super._begin_close_slashes()

	for slash in slashes:
		var center: Vector2 = (slash.a + slash.b) * 0.5
		var half_vector: Vector2 = (slash.b - slash.a) * 0.5

		slash.a = center - half_vector * guardian_slash_length_multiplier
		slash.b = center + half_vector * guardian_slash_length_multiplier

		slash.warning = maxf(0.72, slash.warning)


func _slash_hits_player(slash) -> bool:
	if not is_instance_valid(target):
		return false

	var segment: Vector2 = slash.b - slash.a
	var length_squared: float = segment.length_squared()

	if length_squared < 0.001:
		return false

	var fraction: float = clampf(
		(target.global_position - slash.a).dot(segment) /
		length_squared,
		0.0,
		1.0
	)

	var nearest: Vector2 = slash.a + segment * fraction
	var hit_radius: float = 18.0 * guardian_slash_width_multiplier

	return nearest.distance_squared_to(
		target.global_position
	) <= hit_radius * hit_radius


# ============================================================
# KING-STYLE LIGHT SPEARS
# ============================================================

func _guardian_spear_spawn_is_clear(
	world_pos: Vector2
) -> bool:

	var test_shape: CircleShape2D = CircleShape2D.new()
	test_shape.radius = 27.0

	var query: PhysicsShapeQueryParameters2D = (
		PhysicsShapeQueryParameters2D.new()
	)

	query.shape = test_shape
	query.transform = Transform2D(0.0, world_pos)
	query.collision_mask = guardian_spear_terrain_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var excluded: Array[RID] = [get_rid()]

	if is_instance_valid(target):
		excluded.append(target.get_rid())

	query.exclude = excluded

	return get_world_2d().direct_space_state.intersect_shape(
		query, 1
	).is_empty()


func _guardian_spear_hits_terrain(
	from_world: Vector2,
	to_world: Vector2
) -> bool:

	if guardian_spear_terrain_mask == 0:
		return false

	var excluded: Array[RID] = [get_rid()]

	if is_instance_valid(target):
		excluded.append(target.get_rid())

	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			from_world,
			to_world,
			guardian_spear_terrain_mask,
			excluded
		)
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	return not get_world_2d().direct_space_state.intersect_ray(
		query
	).is_empty()


func _start_guardian_spears() -> void:

	guardian_spear_clock = guardian_spear_cooldown

	if not is_instance_valid(target):
		return

	if not guardian_spears.is_empty():
		return

	var number: int = mini(guardian_spear_count, 5)
	var anchor: Vector2 = target.global_position
	var scheduled_time: float = 0.0

	for i: int in range(number):

		var x: float = (
			anchor.x +
			(float(i) - float(number - 1) * 0.5) * 52.0
		)

		var y: float = anchor.y - 105.0
		var candidate: Vector2 = Vector2(x, y)
		var clear: bool = false

		for attempt: int in range(8):

			var side: float = (
				-1.0 if attempt % 2 == 0 else 1.0
			)

			candidate = Vector2(
				x + side * float(attempt / 2) * 22.0,
				y - float(attempt % 3) * 14.0
			)

			if _guardian_spear_spawn_is_clear(candidate):
				clear = true
				break

		if not clear:
			continue

		var blade: GuardianLightSpear = GuardianLightSpear.new()

		blade.position = candidate
		blade.aim = anchor
		blade.direction = blade.position.direction_to(blade.aim)

		if i > 0:
			scheduled_time += randf_range(0.23, 0.30)

		blade.delay = scheduled_time
		blade.warning = guardian_spear_warning
		guardian_spears.append(blade)


func _update_guardian_spears(delta: float) -> void:

	if not is_instance_valid(target):
		guardian_spears.clear()
		return

	for index: int in range(guardian_spears.size() - 1, -1, -1):

		var spear: GuardianLightSpear = guardian_spears[index]
		spear.elapsed += delta

		var age: float = spear.elapsed - spear.delay

		if age < 0.0:
			continue

		if not spear.launched:

			if age < spear.warning - spear.aim_lock_time:
				spear.aim = target.global_position
				spear.direction = spear.position.direction_to(spear.aim)

			if age >= spear.warning:
				spear.launched = true

		else:

			spear.flight += delta
			spear.trail.push_front(spear.position)

			if spear.trail.size() > 13:
				spear.trail.pop_back()

			var old_pos: Vector2 = spear.position
			var next_pos: Vector2 = (
				old_pos +
				spear.direction * guardian_spear_speed * delta
			)

			if _guardian_spear_hits_terrain(
				old_pos,
				next_pos + spear.direction * 30.0
			):
				guardian_spears.remove_at(index)
				continue

			spear.position = next_pos

			var closest: Vector2 = (
				Geometry2D.get_closest_point_to_segment(
					target.global_position,
					old_pos,
					next_pos
				)
			)

			if not spear.hit:
				if closest.distance_squared_to(
					target.global_position
				) < 18.0 * 18.0:

					spear.hit = true

					_damage_player(
						guardian_spear_damage,
						spear.position
					)

			if spear.hit or spear.flight > 2.0:
				guardian_spears.remove_at(index)


# ============================================================
# ORIGINAL PROXIMITY CORRUPTION
# DAMAGE ALSO PASSES THROUGH THE HALF-HEART METHOD.
# ============================================================

func _update_guardian_corruption(delta: float) -> void:

	if not guardian_corruption_enabled or not is_instance_valid(target):
		guardian_corruption_charge = 0.0
		return

	var distance: float = global_position.distance_to(
		target.global_position
	)

	if guardian_corruption_clock > 0.0 or distance > guardian_corruption_range:
		guardian_corruption_charge = maxf(
			0.0,
			guardian_corruption_charge - delta * 2.2
		)
		return

	guardian_corruption_charge = minf(
		guardian_corruption_charge_time,
		guardian_corruption_charge + delta
	)

	if guardian_corruption_charge < guardian_corruption_charge_time:
		return

	guardian_corruption_charge = 0.0
	guardian_corruption_clock = guardian_corruption_cooldown
	guardian_corruption_pulse = 0.55

	_damage_player(
		guardian_corruption_damage,
		global_position
	)

	_guardian_corruption_screen_pulse()


func _guardian_corruption_screen_pulse() -> void:

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "GuardianCorruptionHitFlash"
	layer.layer = 330
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().root.add_child(layer)

	var cover: ColorRect = ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.color = Color(0.0, 0.0, 0.0, 0.29)
	cover.position = Vector2.ZERO
	cover.size = get_viewport().get_visible_rect().size

	layer.add_child(cover)

	var tween: Tween = layer.create_tween()

	tween.tween_property(
		cover,
		"modulate:a",
		0.0,
		0.42
	)

	tween.tween_callback(layer.queue_free)


# ============================================================
# ORIGINAL GUARDIAN VISUALS
# ============================================================

func _draw() -> void:

	super._draw()

	if state != State.HUNTING and state != State.APPEARING:
		return

	for i: int in range(15):

		var t: float = (
			guardian_aura_clock *
			(0.85 + 0.045 * float(i)) +
			float(i) * 2.39996
		)

		var distance: float = 16.0 + float(i % 5) * 5.5

		var point: Vector2 = Vector2(
			cos(t) * distance,
			sin(t * 0.72) * 14.0 -
			fposmod(
				guardian_aura_clock *
				(12.0 + float(i % 4) * 5.0) +
				float(i * 7),
				46.0
			) + 16.0
		)

		var size: float = 2.6 + float(i % 3) * 1.4

		draw_circle(
			point,
			size + 1.8,
			Color(0.16, 0.16, 0.18, 0.32)
		)

		draw_circle(
			point,
			size,
			Color(0.0, 0.0, 0.0, 0.72)
		)

	for slash in slashes:

		if slash.timer < slash.delay:
			continue

		var a: Vector2 = to_local(slash.a)
		var b: Vector2 = to_local(slash.b)

		if not slash.fired:

			var charge: float = clampf(
				(slash.timer - slash.delay) /
				maxf(slash.warning, 0.01),
				0.0,
				1.0
			)

			draw_line(
				a,
				b,
				Color(
					0.37, 0.37, 0.41,
					0.27 + charge * 0.31
				),
				4.5 * guardian_slash_width_multiplier
			)

		else:

			var fade: float = clampf(
				1.0 -
				(slash.timer - slash.delay - slash.warning) / 0.20,
				0.0,
				1.0
			)

			draw_line(
				a,
				b,
				Color(0.16, 0.17, 0.20, fade * 0.85),
				15.0 * guardian_slash_width_multiplier
			)

			draw_line(
				a,
				b,
				Color(0.0, 0.0, 0.0, fade),
				10.0 * guardian_slash_width_multiplier
			)

	for blade: GuardianLightSpear in guardian_spears:

		if blade.elapsed < blade.delay:
			continue

		var local: Vector2 = to_local(blade.position)
		var forward: Vector2 = blade.direction.normalized()
		var side: Vector2 = Vector2(-forward.y, forward.x)

		var opacity: float = clampf(
			(blade.elapsed - blade.delay) /
			blade.fade_time,
			0.0,
			1.0
		)

		var spear_outline: PackedVector2Array = PackedVector2Array([
			local + forward * 31.0,
			local + forward * 4.0 + side * 5.0,
			local - forward * 14.0 + side * 2.2,
			local - forward * 20.0,
			local - forward * 14.0 - side * 2.2,
			local + forward * 4.0 - side * 5.0
		])

		draw_colored_polygon(
			spear_outline,
			Color(0.96, 0.975, 1.0, 0.82 * opacity)
		)

		var spear_groove: PackedVector2Array = PackedVector2Array([
			local + forward * 23.0,
			local + forward * 3.0 + side * 2.2,
			local - forward * 10.0,
			local + forward * 3.0 - side * 2.2
		])

		draw_colored_polygon(
			spear_groove,
			Color(0.08, 0.09, 0.12, 0.60 * opacity)
		)

		draw_line(
			local - forward * 23.0,
			local - forward * 11.0,
			Color(0.86, 0.90, 0.99, 0.66 * opacity),
			2.1,
			true
		)

		for i: int in range(blade.trail.size()):

			var after_point: Vector2 = to_local(
				blade.trail[i]
			)

			var fade: float = pow(
				1.0 - float(i) / 12.0,
				1.6
			) * 0.29

			draw_line(
				after_point - forward * 19.0,
				after_point + forward * 23.0,
				Color(0.82, 0.88, 1.0, fade),
				2.8,
				true
			)

	if (
		guardian_corruption_enabled
		and guardian_corruption_charge > 0.0
		and is_instance_valid(target)
	):

		var progress: float = clampf(
			guardian_corruption_charge /
			maxf(0.01, guardian_corruption_charge_time),
			0.0,
			1.0
		)

		var player_local: Vector2 = to_local(
			target.global_position
		)

		draw_line(
			Vector2.ZERO,
			player_local,
			Color(
				0.27, 0.20, 0.30,
				0.20 + progress * 0.48
			),
			1.0 + progress * 2.0
		)

		draw_arc(
			player_local,
			20.0 + 10.0 * progress,
			0.0,
			TAU,
			38,
			Color(
				0.40, 0.33, 0.43,
				0.25 + progress * 0.65
			),
			1.5 + progress * 2.0
		)

		if progress > 0.72:

			draw_arc(
				player_local,
				15.0,
				0.0,
				TAU * progress,
				28,
				Color(0.05, 0.02, 0.08, 0.8),
				5.0
			)
