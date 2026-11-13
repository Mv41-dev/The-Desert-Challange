# NORMAL NECROMANCER - V2 wall phasing/platform revival (no king code)
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

enum State { DORMANT, OPENING, SUMMONING, GUARDED, DESCENDING, REVIVING, DEAD }

const SKELETON_SCENE := preload("res://skeletonenemy.tscn")
const SKULL_TEXTURE := preload("res://miniboss/Skeleton head.png")
const REVIVE_ANIMATION := &"spawnenemies2"
const REVIVE_LOOP_FIRST := 4
const REVIVE_LOOP_LAST := 7
const MAX_BUFFED_SKELETONS := 2

@export var max_hp: int = 30
@export var activation_range: float = 280.0
@export_flags_2d_physics var terrain_mask: int = 1
@export_range(1, 2, 1) var skeleton_count: int = 2
@export var revive_seconds: float = 3.6
@export var summon_release_frame: int = 7
@export var between_summons_seconds: float = 0.65
@export var sprite_faces_right_by_default: bool = true
@export var summon_bonus_hp: int = 12
@export var summon_speed_multiplier: float = 1.65
@export var hover_speed: float = 105.0
@export var keep_distance: float = 105.0
@export var arena_roam_distance: float = 155.0
@export var skull_speed: float = 245.0
@export var skull_damage: int = 1

# Platform arena support: fly through solid walls/floors, but land on a REAL
# platform via a downward terrain raycast before reviving a skeleton.
@export_group("Wall Phasing and Platform Revival")
@export var phase_through_walls_while_flying: bool = true
@export_range(360.0, 2000.0, 20.0) var platform_search_depth: float = 900.0
@export_range(1.0, 12.0, 1.0) var revive_floor_clearance: float = 4.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

class SummonSlot:
	var skeleton: CharacterBody2D
	var buffed: bool = false
	var was_summoned: bool = false
	var position: Vector2
	var floor_position: Vector2


class Skull:
	var visual: Sprite2D
	var direction: Vector2
	var lifetime: float = 3.0


var state: State = State.DORMANT
var hp: int
var target: CharacterBody2D
var home: Vector2
var hover_center_x: float
var hover_time: float = 0.0
var slots: Array[SummonSlot] = []
var skulls: Array[Skull] = []
var revive_slot: SummonSlot
var revive_destination: Vector2
var revive_timer: float = 0.0
var revive_preview: Sprite2D
var opening_complete: bool = false
var casting_slot: SummonSlot
var summon_slot_index: int = 0
var summon_gap_remaining: float = 0.0
var cast_released: bool = false
var cast_animation: StringName
var revive_frame_elapsed: float = 0.0
var barrage_timer: float = 1.8
var shots_left: int = 0
var flash_timer: float = 0.0
var hover_side: float = 1.0
var sprite_tint: Color
var original_collision_mask: int = 0


func _set_flight_collision(landing: bool) -> void:
	# Collision LAYER stays unchanged so Kris's attack/hurtbox systems can
	# still detect the Necromancer when its descending/reviving window is open.
	# Only collision MASK is disabled while travelling through terrain.
	if not phase_through_walls_while_flying:
		return
	if state == State.DEAD:
		return
	var wanted_mask: int = original_collision_mask if landing else 0
	if collision_mask != wanted_mask:
		collision_mask = wanted_mask


func _ready() -> void:
	original_collision_mask = collision_mask
	hp = maxi(1, max_hp)
	home = global_position
	hover_center_x = home.x
	_set_flight_collision(false)
	sprite_tint = sprite.self_modulate
	add_to_group(&"inimigo")
	add_to_group(&"enemy")
	add_to_group(&"necromancer")
	_play(&"idle")
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		if target != null:
			add_collision_exception_with(target)
			target.add_collision_exception_with(self)
	if not is_instance_valid(target):
		return
	var dx_to_player := target.global_position.x - global_position.x
	if absf(dx_to_player) > 3.0:
		sprite.flip_h = (dx_to_player > 0.0) != sprite_faces_right_by_default
	flash_timer = maxf(0.0, flash_timer - delta)
	_update_skulls(delta)
	match state:
		State.DORMANT:
			if global_position.distance_to(target.global_position) <= activation_range:
				_begin_encounter()
		State.OPENING:
			_update_opening(delta)
		State.SUMMONING:
			_update_summoning(delta)
		State.GUARDED:
			_update_guarded(delta)
		State.DESCENDING:
			_update_descent(delta)
		State.REVIVING:
			_update_revive(delta)
	if state != State.DORMANT:
		sprite.self_modulate = Color(1.0, 0.44, 0.44) if flash_timer > 0.0 else sprite_tint
		queue_redraw()


func _begin_encounter() -> void:
	# Narrow, separated platforms often have no ground at exactly +/-72px.
	# Sample the nearby ledges before abandoning the summon encounter.
	var desired_count: int = clampi(skeleton_count, 1, 2)
	var offsets: Array[float] = [-72.0, 72.0, -40.0, 40.0, 0.0, -120.0, 120.0]
	for offset: float in offsets:
		if slots.size() >= desired_count:
			break
		var floor_hit: Dictionary = _ground_at(home.x + offset)
		if floor_hit.is_empty():
			continue
		var new_floor: Vector2 = floor_hit["position"]
		var overlaps_slot: bool = false
		for existing: SummonSlot in slots:
			if existing.floor_position.distance_to(new_floor) < 44.0:
				overlaps_slot = true
				break
		if overlaps_slot:
			continue
		var slot := SummonSlot.new()
		slot.floor_position = new_floor
		slots.append(slot)
	if slots.is_empty() and is_instance_valid(target):
		# A boss hovering above a gap can still start its encounter by finding
		# the platform Kris is actually standing on (common in Radiance arenas).
		for offset: float in [0.0, -55.0, 55.0]:
			var floor_hit: Dictionary = _ground_at(
				target.global_position.x + offset,
				target.global_position.y - 85.0
			)
			if floor_hit.is_empty():
				continue
			var slot := SummonSlot.new()
			slot.floor_position = floor_hit["position"]
			slots.append(slot)
			break
	if slots.is_empty():
		return
	state = State.OPENING
	barrage_timer = 0.35
	_play(&"idle")


func _update_opening(delta: float) -> void:
	_update_hover(delta)
	if opening_complete:
		barrage_timer -= delta
		if barrage_timer <= 0.0:
			_begin_summoning()
		return
	_update_barrage(delta)
	if shots_left == 0 and barrage_timer > 2.0:
		opening_complete = true
		barrage_timer = 0.55


func _begin_summoning() -> void:
	_clear_skulls()
	state = State.SUMMONING
	shots_left = 0
	summon_slot_index = 0
	summon_gap_remaining = 0.0
	_next_summon_cast()


func _next_summon_cast() -> void:
	while summon_slot_index < slots.size():
		var slot := slots[summon_slot_index]
		summon_slot_index += 1
		if is_instance_valid(slot.skeleton) and not bool(slot.skeleton.get(&"dead")):
			continue
		casting_slot = slot
		cast_released = false
		cast_animation = &"spawnenemies"
		_play(cast_animation, true)
		return
	_finish_summoning()


func _update_summoning(delta: float) -> void:
	var has_summoned := false
	var living := false
	for slot in slots:
		if slot.was_summoned:
			has_summoned = true
		if is_instance_valid(slot.skeleton) and not bool(slot.skeleton.get(&"dead")):
			living = true
	if has_summoned and not living:
		_begin_descent()
		return
	_update_hover(delta)
	if casting_slot == null:
		summon_gap_remaining -= delta
		if summon_gap_remaining <= 0.0:
			_next_summon_cast()
		return
	var playing_cast := sprite.animation == cast_animation and sprite.is_playing()
	if not cast_released and (not playing_cast or sprite.frame >= summon_release_frame):
		_spawn_skeleton(casting_slot, false)
		cast_released = true
	if not playing_cast:
		if summon_slot_index >= slots.size():
			_finish_summoning()
		else:
			casting_slot = null
			summon_gap_remaining = maxf(0.0, between_summons_seconds)
			_play(&"idle")


func _finish_summoning() -> void:
	casting_slot = null
	state = State.GUARDED
	barrage_timer = 1.1
	_play(&"idle")

func _ground_at(x: float, ray_start_y: float = -INF) -> Dictionary:
	# Raycasting explicitly against the terrain remains functional even when
	# the flying Necromancer has collision_mask = 0. It also finds platforms
	# substantially above/below the original home position when used near a corpse.
	var start_y: float = home.y - 60.0
	if ray_start_y != -INF:
		start_y = ray_start_y
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(x, start_y),
		Vector2(x, start_y + maxf(360.0, platform_search_depth)),
		terrain_mask,
		_excluded_bodies()
	)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector2 = hit["normal"]
		if normal.y < -0.6:
			return hit
	return {}


func _excluded_bodies() -> Array[RID]:
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(target):
		excluded.append(target.get_rid())
	for slot in slots:
		if is_instance_valid(slot.skeleton):
			excluded.append(slot.skeleton.get_rid())
	# In a three-Necromancer arena, other bosses/skeletons should NEVER be
	# mistaken for platforms by a terrain ray (even if their layer overlaps).
	for enemy_node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if enemy_node is CollisionObject2D and enemy_node != self:
			var enemy_rid: RID = (enemy_node as CollisionObject2D).get_rid()
			if not excluded.has(enemy_rid):
				excluded.append(enemy_rid)
	return excluded


func _living_buffed_count() -> int:
	var count := 0
	for slot in slots:
		if slot.buffed and is_instance_valid(slot.skeleton) and not bool(slot.skeleton.get(&"dead")):
			count += 1
	return count


func _spawn_skeleton(slot: SummonSlot, request_buff: bool) -> void:
	var buffed := request_buff and _living_buffed_count() < MAX_BUFFED_SKELETONS
	slot.buffed = buffed
	var skeleton := SKELETON_SCENE.instantiate() as CharacterBody2D
	var collider := skeleton.get_node("hitbox") as CollisionShape2D
	var rectangle := collider.shape as RectangleShape2D
	var feet := collider.position.y + rectangle.size.y * 0.5
	slot.position = slot.floor_position - Vector2(0.0, feet + 1.0)
	if buffed:
		skeleton.set_meta(&"necromancer_buffed", true)
		skeleton.set(&"max_hp", int(skeleton.get(&"max_hp")) + summon_bonus_hp)
		skeleton.set(&"move_speed", float(skeleton.get(&"move_speed")) * summon_speed_multiplier)
		skeleton.set(&"skull_speed", float(skeleton.get(&"skull_speed")) * 1.48)
		skeleton.set(&"skull_attack_cooldown", float(skeleton.get(&"skull_attack_cooldown")) * 0.48)
		skeleton.set(&"skull_aim_duration", float(skeleton.get(&"skull_aim_duration")) * 0.75)
		skeleton.set(&"skull_spawn_gap_min", float(skeleton.get(&"skull_spawn_gap_min")) * 0.65)
		skeleton.set(&"skull_spawn_gap_max", float(skeleton.get(&"skull_spawn_gap_max")) * 0.65)
		skeleton.set(&"ai_skull_intent_chance", 0.42)
		skeleton.set(&"group_skull_max_two", 7)
		skeleton.set(&"group_skull_max_three", 6)
		skeleton.set(&"group_skull_max_four_plus", 5)
		skeleton.set(&"overhead_skull_max_per_volley", 5)
		skeleton.set(&"attack_cooldown", float(skeleton.get(&"attack_cooldown")) * 0.75)
		skeleton.set(&"melee_lunge_speed", float(skeleton.get(&"melee_lunge_speed")) * 1.20)
		skeleton.modulate = Color(1.0, 0.42, 0.46)
	var parent := get_parent()
	if parent is Node2D:
		skeleton.position = parent.to_local(slot.position)
	else:
		skeleton.position = slot.position
	skeleton.set_meta(&"necromancer_summon_owner", get_instance_id())
	slot.was_summoned = true
	slot.skeleton = skeleton
	parent.add_child(skeleton)
	for other_slot in slots:
		var other := other_slot.skeleton
		if other == skeleton or not is_instance_valid(other) or bool(other.get(&"dead")):
			continue
		skeleton.add_collision_exception_with(other)
		other.add_collision_exception_with(skeleton)
	add_collision_exception_with(skeleton)
	skeleton.add_collision_exception_with(self)


func _update_guarded(delta: float) -> void:
	var living_count := 0
	for slot in slots:
		if not is_instance_valid(slot.skeleton):
			continue
		if bool(slot.skeleton.get(&"dead")):
			if slot.skeleton.collision_layer == 0:
				var floor_hit := _ground_at(
					slot.skeleton.global_position.x,
					slot.skeleton.global_position.y - 24.0
				)
				if not floor_hit.is_empty():
					slot.floor_position = floor_hit["position"]
			continue
		living_count += 1
	if living_count == 0:
		_begin_descent()
		return

	_update_hover(delta)
	if living_count >= 2:
		if shots_left > 0 or not skulls.is_empty():
			_clear_skulls()
			shots_left = 0
		barrage_timer = maxf(barrage_timer, 1.1)
		return
	_update_barrage(delta)


func _update_hover(delta: float) -> void:
	var dx := global_position.x - target.global_position.x
	if absf(dx) > 45.0:
		hover_side = signf(dx)
	var desired_x := clampf(target.global_position.x + hover_side * keep_distance, home.x - arena_roam_distance, home.x + arena_roam_distance)
	hover_center_x = move_toward(hover_center_x, desired_x, 65.0 * delta)
	hover_time += delta * 2.2
	var figure_eight := Vector2(sin(hover_time) * 34.0, sin(hover_time * 2.0) * 15.0)
	_fly_toward(Vector2(hover_center_x, home.y) + figure_eight, hover_speed, delta)


func _update_barrage(delta: float) -> void:
	barrage_timer -= delta
	if barrage_timer > 0.0:
		return
	if shots_left > 0:
		_launch_skull()
		shots_left -= 1
		barrage_timer = 0.20 if shots_left > 0 else 2.8
	else:
		_play(&"spawnenemies2", true)
		shots_left = 4
		barrage_timer = 0.60


func _begin_descent() -> void:
	_clear_skulls()
	shots_left = 0
	revive_slot = null
	for slot in slots:
		if not slot.was_summoned:
			continue
		if revive_slot == null or global_position.distance_squared_to(slot.floor_position) < global_position.distance_squared_to(revive_slot.floor_position):
			revive_slot = slot
	if revive_slot == null:
		# Do not access a null revival slot when a platform prevented a cast.
		state = State.GUARDED
		return
	revive_destination = _revive_position()
	state = State.DESCENDING
	_set_flight_collision(false)
	_play(&"walk")


func _revive_position() -> Vector2:
	var rectangle := body_shape.shape as RectangleShape2D
	var feet := body_shape.position.y + rectangle.size.y * 0.5
	var floor_position: Vector2 = revive_slot.floor_position
	var side: float = -1.0 if global_position.x < floor_position.x else 1.0
	for direction in [side, -side]:
		# Probe from the DEAD skeleton's actual platform elevation, not home.y.
		# Another platform below it is not a valid replacement landing spot.
		var ground: Dictionary = _ground_at(
			floor_position.x + float(direction) * 40.0,
			floor_position.y - 54.0
		)
		if ground.is_empty():
			continue
		var candidate: Vector2 = ground["position"]
		if absf(candidate.y - floor_position.y) <= 12.0:
			return candidate - Vector2(0.0, feet + revive_floor_clearance)
	return floor_position - Vector2(0.0, feet + revive_floor_clearance)


func _update_descent(delta: float) -> void:
	var destination: Vector2 = revive_destination
	# If the corpse is on a raised platform, approach ABOVE that platform
	# before dropping onto it, rather than visually rising through its underside.
	if absf(global_position.x - destination.x) > 5.0:
		var approach_y: float = minf(global_position.y, destination.y - 44.0)
		_fly_toward(Vector2(destination.x, approach_y), hover_speed, delta)
	else:
		_fly_toward(destination, hover_speed, delta)
	if global_position.distance_to(destination) <= 6.0:
		# Land EXACTLY above the raycast floor. Restore solid collision only now,
		# otherwise a wall can block the descent before he reaches the corpse.
		global_position = destination
		velocity = Vector2.ZERO
		state = State.REVIVING
		_set_flight_collision(true)
		revive_timer = maxf(0.01, revive_seconds)
		_start_revive_animation()
		_create_revive_preview()


func _update_revive(delta: float) -> void:
	revive_timer = maxf(0.0, revive_timer - delta)
	if revive_timer > 0.0:
		_update_revive_animation(delta)
		if is_instance_valid(revive_preview):
			revive_preview.modulate.a = _revive_progress()
		return
	_clear_revive_preview()
	_spawn_skeleton(revive_slot, true)
	revive_slot = null
	state = State.GUARDED
	_set_flight_collision(false)
	barrage_timer = 2.0
	hover_center_x = global_position.x
	_play(&"idle")


func _revive_progress() -> float:
	return clampf(1.0 - revive_timer / maxf(0.01, revive_seconds), 0.0, 1.0)


func _create_revive_preview() -> void:
	var template := SKELETON_SCENE.instantiate() as CharacterBody2D
	var template_sprite := template.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var collider := template.get_node("hitbox") as CollisionShape2D
	var rectangle := collider.shape as RectangleShape2D
	var feet := collider.position.y + rectangle.size.y * 0.5
	var preview_position := revive_slot.floor_position - Vector2(0.0, feet + 1.0) + template_sprite.position
	revive_preview = Sprite2D.new()
	revive_preview.texture = template_sprite.sprite_frames.get_frame_texture(&"idle", 0)
	revive_preview.centered = template_sprite.centered
	revive_preview.offset = template_sprite.offset
	revive_preview.scale = template_sprite.scale
	revive_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	revive_preview.modulate = Color(1.0, 0.42, 0.46, 0.0)
	revive_preview.top_level = true
	add_child(revive_preview)
	revive_preview.global_position = preview_position
	template.free()


func _clear_revive_preview() -> void:
	if is_instance_valid(revive_preview):
		revive_preview.queue_free()
	revive_preview = null


func _start_revive_animation() -> void:
	revive_frame_elapsed = 0.0
	_play(REVIVE_ANIMATION, true)
	if sprite.animation == REVIVE_ANIMATION:
		sprite.pause()
		sprite.set_frame_and_progress(0, 0.0)


func _update_revive_animation(delta: float) -> void:
	if sprite.animation != REVIVE_ANIMATION:
		return
	var frames := sprite.sprite_frames
	var last := mini(REVIVE_LOOP_LAST, frames.get_frame_count(REVIVE_ANIMATION) - 1)
	if last < 0:
		return
	var first := mini(REVIVE_LOOP_FIRST, last)
	var fps := maxf(1.0, frames.get_animation_speed(REVIVE_ANIMATION))
	var frame := clampi(sprite.frame, 0, last)
	revive_frame_elapsed += delta
	var duration := maxf(0.001, frames.get_frame_duration(REVIVE_ANIMATION, frame) / fps)
	while revive_frame_elapsed >= duration:
		revive_frame_elapsed -= duration
		frame = first if frame >= last else frame + 1
		duration = maxf(0.001, frames.get_frame_duration(REVIVE_ANIMATION, frame) / fps)
	sprite.set_frame_and_progress(frame, revive_frame_elapsed / duration)


func _fly_toward(destination: Vector2, speed: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var movement: Vector2 = (destination - global_position).limit_length(
		maxf(0.0, speed) * delta
	)
	if phase_through_walls_while_flying:
		# Flying movement is intangible; physics still detects the actual platform
		# with _ground_at(), and revival re-enables ground collision when landed.
		global_position += movement
		velocity = Vector2.ZERO
	else:
		velocity = movement / delta
		move_and_slide()


func _launch_skull() -> void:
	var skull := Skull.new()
	var visual := Sprite2D.new()
	visual.texture = SKULL_TEXTURE
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.modulate = Color(1.0, 0.20, 0.26)
	visual.top_level = true
	var texture_size := SKULL_TEXTURE.get_size()
	visual.scale = Vector2.ONE * (18.0 / maxf(texture_size.x, texture_size.y))
	add_child(visual)
	visual.global_position = body_shape.global_position
	var aim := target.global_position
	var player_body := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_body != null:
		aim = player_body.global_position
	skull.direction = visual.global_position.direction_to(aim)
	visual.rotation = skull.direction.angle() + PI
	skull.visual = visual
	skulls.append(skull)


func _update_skulls(delta: float) -> void:
	if skulls.is_empty():
		return
	var excluded := _excluded_bodies()
	excluded.erase(target.get_rid())
	for index in range(skulls.size() - 1, -1, -1):
		var skull := skulls[index]
		var start := skull.visual.global_position
		var finish := start + skull.direction * skull_speed * delta
		var query := PhysicsRayQueryParameters2D.create(start, finish, terrain_mask | target.collision_layer, excluded)
		query.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		skull.lifetime -= delta
		if not hit.is_empty() or skull.lifetime <= 0.0:
			if hit.get("collider") == target and target.has_method(&"tomar_dano"):
				target.call(&"tomar_dano", skull_damage, start)
			skull.visual.queue_free()
			skulls.remove_at(index)
		else:
			skull.visual.global_position = finish


func _clear_skulls() -> void:
	for skull in skulls:
		skull.visual.queue_free()
	skulls.clear()


func can_receive_player_hit() -> bool:
	return state == State.DESCENDING or state == State.REVIVING


func is_reviving() -> bool:
	return state == State.REVIVING


func is_dead() -> bool:
	return state == State.DEAD


func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or not can_receive_player_hit():
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	flash_timer = 0.13
	if hp > 0:
		return
	state = State.DEAD
	_clear_revive_preview()
	velocity = Vector2.ZERO
	_clear_skulls()
	queue_redraw()
	collision_layer = 0
	collision_mask = 0
	died.emit()
	_play(&"death", true)
	var frames := sprite.sprite_frames.get_frame_count(&"death")
	var speed := maxf(1.0, sprite.sprite_frames.get_animation_speed(&"death"))
	get_tree().create_timer(maxf(0.2, float(frames) / speed)).timeout.connect(queue_free)


func _play(animation: StringName, restart: bool = false) -> void:
	if not sprite.sprite_frames.has_animation(animation):
		return
	if restart:
		sprite.stop()
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _draw() -> void:
	if state == State.DEAD:
		return
	if state == State.REVIVING and is_instance_valid(revive_preview):
		var start := body_shape.position
		var finish := to_local(revive_preview.global_position)
		draw_line(start, finish, Color(0.58, 0.16, 0.45, 0.52), 4.0, true)
		draw_line(start, finish, Color(1.0, 0.59, 0.76, 0.85), 1.0, true)
		var flow := _revive_progress() * 12.0
		for index in range(3):
			var point := start.lerp(finish, fposmod(flow + float(index) / 3.0, 1.0))
			draw_circle(point, 2.0, Color(1.0, 0.85, 0.92))
	elif state == State.GUARDED:
		draw_arc(body_shape.position, 25.0, 0.0, TAU, 32, Color(0.60, 0.36, 0.90, 0.48), 1.5)
	if (state == State.GUARDED or state == State.OPENING) and shots_left > 0:
		draw_arc(body_shape.position, 13.0, 0.0, TAU, 24, Color(1.0, 0.23, 0.30, 0.85), 2.0)
