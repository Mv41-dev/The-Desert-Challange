# KING NECROMANCER - Independent boss scene, no Level 5 auto-detection
# Attach ONLY to the kingnecro.tscn root CharacterBody2D.
# Preserves V5 Grave Monarch combat, Menacing-only guards and platform revival.
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

# This script is ONLY for the kingnecro.tscn scene; every instance is the King.
# Normal necromancers continue using necromancer.gd and never become Kings.
@export_group("King Necromancer")
@export_range(40, 300, 5) var king_max_hp: int = 140
# Multiplies this scene's original sprite scale to make the King imposing.
@export_range(3.5, 7.0, 0.1) var king_visual_scale: float = 5.2
@export_range(1.0, 2.0, 0.05) var king_hover_speed_multiplier: float = 1.45
@export_range(1.0, 2.0, 0.05) var king_skull_speed_multiplier: float = 1.18
@export_range(2.0, 8.0, 0.1) var king_gravefall_cooldown: float = 3.50
@export_range(0.35, 2.0, 0.05) var king_gravefall_warning_time: float = 0.85
@export_range(8, 32, 1) var king_max_live_skulls: int = 24
@export_range(0.5, 3.0, 0.05) var king_exposed_after_attack: float = 1.65

@export_group("King's Menacing Skeleton Guards")
# Drag your existing Menacing Skeleton .tscn here. V4 also checks common paths.
@export var king_menacing_skeleton_scene: PackedScene
@export_range(1, 3, 1) var king_elite_total_waves: int = 2
@export_range(15, 100, 5) var king_elite_hp: int = 55
@export_range(0.0, 15.0, 0.5) var king_first_elite_delay: float = 1.0
@export_range(5.0, 30.0, 0.5) var king_elite_resummon_delay: float = 11.0

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
	var speed: float = 245.0
	var damage: int = 1


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

# The King shares the same skeleton/revival logic as regular Necromancers.
var is_king: bool = false
var king_barrage_count: int = 0
var king_barrage_is_fan: bool = false
var king_exposure_timer: float = 0.0
var king_gravefall_cooldown_timer: float = 4.0
var king_gravefall_active: bool = false
var king_gravefall_warning_timer: float = 0.0
var king_gravefall_columns: Array[float] = []
var king_gravefall_top_y: float = 0.0
var king_gravefall_bottom_y: float = 0.0
var king_hp_label: Label = null
var king_hud: CanvasLayer = null
var king_hud_bar: ProgressBar = null
var king_hud_status: Label = null
var king_special_kind: int = 0  # 0 none, 1 gravefall, 2 royal sweep, 3 crown burst
var king_special_round: int = 0
var king_sweep_y: Array[float] = []
var king_sweep_spawn_x: float = 0.0
var king_sweep_direction: Vector2 = Vector2.RIGHT
var king_elite: CharacterBody2D = null
var king_elite_waves_spawned: int = 0
var king_elite_timer: float = 4.0
var king_elite_missing_scene_warned: bool = false
var king_elite_scene_lookup_exhausted: bool = false
var king_desperation_started: bool = false
var king_crown_root: Node2D = null
var king_base_sprite_scale: Vector2 = Vector2.ONE
var king_elite_revival_pending: bool = false


func _activate_king_mode() -> void:
	if is_king:
		return
	is_king = true
	king_desperation_started = false
	add_to_group(&"king_necromancer")
	# Guarantee this dedicated boss scene starts with proper boss HP.
	max_hp = maxi(maxi(max_hp, king_max_hp), 140)
	hp = max_hp
	activation_range = maxf(activation_range, 600.0)
	hover_speed *= king_hover_speed_multiplier
	arena_roam_distance = maxf(arena_roam_distance, 280.0)
	# NEVER spawn skeletonenemy.tscn from the King. All of his guards
	# are the actual Menacing Skeleton scene, managed separately below.
	skeleton_count = 1 # compatibility only; King doesn't run normal slot summons.
	slots.clear()
	king_base_sprite_scale = sprite.scale
	# Scale the ART independently from physics so the giant can hover above
	# narrow Radiance-like platforms without an enormous invisible collider.
	sprite.scale = king_base_sprite_scale * maxf(5.2, king_visual_scale)
	body_shape.scale *= 1.65
	sprite_tint = Color(0.92, 0.61, 1.0, 1.0)
	sprite.self_modulate = sprite_tint
	_build_king_crown()
	king_gravefall_cooldown_timer = 0.30
	king_elite_timer = maxf(0.65, minf(1.5, king_first_elite_delay))
	king_elite_waves_spawned = 0
	king_elite_revival_pending = false
	_create_king_boss_hud()
	_update_king_hp_label()
	health_changed.emit(hp, max_hp)
	queue_redraw()
	print("GRAVE MONARCH: KING SCENE ACTIVE at ", get_path(),
		" | visual scale=", sprite.scale, " | ONLY Menacing Skeleton guards")


func _king_visual_half_height() -> float:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return 100.0
	if not sprite.sprite_frames.has_animation(&"idle"):
		return 100.0
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return 100.0
	return maxf(80.0, texture.get_size().y * absf(sprite.scale.y) * 0.45)


func _build_king_crown() -> void:
	# A real foreground crown, not a _draw() polygon hidden BEHIND the sprite.
	if is_instance_valid(king_crown_root):
		return
	king_crown_root = Node2D.new()
	king_crown_root.name = "GraveMonarchCrown"
	king_crown_root.z_as_relative = false
	king_crown_root.z_index = 55
	add_child(king_crown_root)
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-54.0, 9.0), Vector2(-49.0, -30.0),
		Vector2(-30.0, -12.0), Vector2(-18.0, -50.0),
		Vector2(0.0, -21.0), Vector2(18.0, -50.0),
		Vector2(30.0, -12.0), Vector2(49.0, -30.0),
		Vector2(54.0, 9.0)
	])
	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = Color(0.23, 0.05, 0.37, 0.94)
	king_crown_root.add_child(fill)
	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 4.0
	outline.default_color = Color(1.0, 0.75, 0.97)
	king_crown_root.add_child(outline)
	for gem_pos: Vector2 in [Vector2(-28.0, -12.0), Vector2(0.0, -9.0), Vector2(28.0, -12.0)]:
		var gem := Polygon2D.new()
		gem.polygon = PackedVector2Array([
			gem_pos + Vector2(0, -8), gem_pos + Vector2(7, 0),
			gem_pos + Vector2(0, 8), gem_pos + Vector2(-7, 0)
		])
		gem.color = Color(1.0, 0.35, 0.95)
		king_crown_root.add_child(gem)
	_update_king_crown(0.0)


func _update_king_crown(_delta: float) -> void:
	if not is_king or not is_instance_valid(king_crown_root):
		return
	king_crown_root.position = sprite.position + Vector2(
		0.0,
		-_king_visual_half_height() - 16.0 + sin(hover_time * 2.0) * 4.0
	)
	king_crown_root.modulate.a = 0.93 + 0.07 * sin(hover_time * 3.8)


func _create_king_boss_hud() -> void:
	if is_instance_valid(king_hud):
		return
	king_hud = CanvasLayer.new()
	king_hud.name = "GraveMonarchBossHUD"
	king_hud.layer = 16
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(king_hud)
	var frame := VBoxContainer.new()
	frame.name = "BossHeader"
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.offset_left = -240.0
	frame.offset_right = 240.0
	frame.offset_top = 16.0
	frame.offset_bottom = 91.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	king_hud.add_child(frame)
	var title := Label.new()
	title.text = "THE GRAVE MONARCH  |  KING NECROMANCER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.97, 0.79, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.01, 0.11))
	title.add_theme_constant_override("outline_size", 5)
	frame.add_child(title)
	king_hud_bar = ProgressBar.new()
	king_hud_bar.name = "KingHP"
	king_hud_bar.custom_minimum_size = Vector2(470, 18)
	king_hud_bar.min_value = 0.0
	king_hud_bar.max_value = float(max_hp)
	king_hud_bar.value = float(hp)
	king_hud_bar.show_percentage = false
	king_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.07, 0.02, 0.12, 0.94)
	bar_bg.border_color = Color(0.80, 0.37, 0.98)
	bar_bg.set_border_width_all(2)
	king_hud_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.71, 0.21, 0.91)
	king_hud_bar.add_theme_stylebox_override("fill", bar_fill)
	frame.add_child(king_hud_bar)
	king_hud_status = Label.new()
	king_hud_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	king_hud_status.add_theme_font_size_override("font_size", 13)
	king_hud_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.96))
	frame.add_child(king_hud_status)


func _update_king_hp_label() -> void:
	if is_instance_valid(king_hp_label):
		king_hp_label.text = "KING  %d/%d" % [hp, max_hp]
	if is_instance_valid(king_hud_bar):
		king_hud_bar.max_value = float(max_hp)
		king_hud_bar.value = float(hp)
	if is_instance_valid(king_hud_status):
		if king_elite_missing_scene_warned and king_menacing_skeleton_scene == null:
			king_hud_status.text = "ASSIGN MENACING SKELETON .tscn IN KING INSPECTOR"
		elif king_special_kind == 1:
			king_hud_status.text = "ROYAL GRAVEFALL  |  Dodge the marked columns"
		elif king_special_kind == 2:
			king_hud_status.text = "PHANTOM PROCESSION  |  Find the open lane"
		elif king_special_kind == 3:
			king_hud_status.text = "CROWN OF SKULLS  |  Wide fan incoming"
		elif king_exposure_timer > 0.0:
			king_hud_status.text = "SHIELD BROKEN  |  STRIKE NOW"
		else:
			king_hud_status.text = "PHASE II" if hp <= max_hp / 2 else "THE DEAD ANSWER THEIR KING"


func _clear_king_gravefall() -> void:
	king_gravefall_active = false
	king_special_kind = 0
	king_gravefall_warning_timer = 0.0
	king_gravefall_columns.clear()
	king_sweep_y.clear()
	queue_redraw()


func _start_king_gravefall() -> void:
	king_special_kind = 1
	king_gravefall_active = true
	king_gravefall_warning_timer = maxf(0.45, king_gravefall_warning_time)
	king_gravefall_columns.clear()
	# Positions lock at warning start. They do not aim again after the player moves.
	for offset: float in [-112.0, 0.0, 112.0]:
		king_gravefall_columns.append(target.global_position.x + offset)
	king_gravefall_top_y = target.global_position.y - 280.0
	king_gravefall_bottom_y = target.global_position.y + 120.0
	queue_redraw()


func _start_king_sweep() -> void:
	king_special_kind = 2
	king_gravefall_active = true
	king_gravefall_warning_timer = 0.85
	king_sweep_y.clear()
	var player_y: float = target.global_position.y
	# Four horizontal rows but a broad gap near the player's initial height.
	for offset: float in [-136.0, -78.0, 76.0, 136.0]:
		king_sweep_y.append(player_y + offset)
	var side: float = -1.0 if king_special_round % 2 == 0 else 1.0
	king_sweep_spawn_x = target.global_position.x + side * 360.0
	king_sweep_direction = Vector2(-side, 0.0)
	queue_redraw()


func _start_king_crown() -> void:
	king_special_kind = 3
	king_gravefall_active = true
	king_gravefall_warning_timer = 0.72
	queue_redraw()


func _fire_king_gravefall() -> void:
	for x: float in king_gravefall_columns:
		_launch_skull(0.0, Vector2(x, king_gravefall_top_y), Vector2.DOWN, 1.35)
	_finish_king_spell()


func _fire_king_sweep() -> void:
	for y: float in king_sweep_y:
		_launch_skull(0.0, Vector2(king_sweep_spawn_x, y), king_sweep_direction, 1.38)
	_finish_king_spell()


func _fire_king_crown() -> void:
	for angle_degrees: float in [-54.0, -36.0, -18.0, 0.0, 18.0, 36.0, 54.0]:
		_launch_skull(deg_to_rad(angle_degrees), body_shape.global_position, Vector2.ZERO, 1.35)
	_finish_king_spell()


func _finish_king_spell() -> void:
	king_exposure_timer = maxf(king_exposure_timer, king_exposed_after_attack)
	_clear_king_gravefall()
	_update_king_hp_label()


func _update_king_specials(delta: float) -> void:
	if not is_king or not is_instance_valid(target):
		return
	if hp <= max_hp / 2 and not king_desperation_started:
		king_desperation_started = true
		sprite_tint = Color(1.0, 0.34, 0.64)
		hover_speed *= 1.15
		print("GRAVE MONARCH: DESPERATION PHASE")
	king_exposure_timer = maxf(0.0, king_exposure_timer - delta)
	if king_gravefall_active:
		king_gravefall_warning_timer -= delta
		if king_gravefall_warning_timer <= 0.0:
			match king_special_kind:
				1:
					_fire_king_gravefall()
				2:
					_fire_king_sweep()
				3:
					_fire_king_crown()
				_:
					_clear_king_gravefall()
		_update_king_hp_label()
		return
	king_gravefall_cooldown_timer -= delta
	if king_gravefall_cooldown_timer <= 0.0:
		king_special_round += 1
		match king_special_round % 3:
			1:
				_start_king_gravefall()
			2:
				_start_king_sweep()
			_:
				_start_king_crown()
		king_gravefall_cooldown_timer = maxf(
			1.75, king_gravefall_cooldown * (0.72 if hp <= max_hp / 2 else 0.86)
			)
	_update_king_hp_label()


func _resolve_king_menacing_scene() -> PackedScene:
	if king_menacing_skeleton_scene != null:
		return king_menacing_skeleton_scene
	# Don't rescan the whole project every two seconds if no scene exists.
	if king_elite_scene_lookup_exhausted:
		return null
	king_elite_scene_lookup_exhausted = true
	# Try the most likely filenames. Unknown projects should use the export field.
	for candidate: String in [
		"res://menacingskeleton.tscn",
		"res://menacing_skeleton.tscn",
		"res://miniboss/menacingskeleton.tscn",
		"res://miniboss/menacing_skeleton.tscn",
		"res://miniboss/MenacingSkeleton.tscn",
		"res://miniboss/Menacing Skeleton.tscn"
	]:
		if ResourceLoader.exists(candidate):
			var loaded: Resource = load(candidate)
			if loaded is PackedScene:
				king_menacing_skeleton_scene = loaded as PackedScene
				return loaded as PackedScene
	# Find scenes in an unfamiliar project layout (once, not every frame).
	var discovered: PackedScene = _find_menacing_scene_in_folder("res://", 0)
	if discovered != null:
		king_menacing_skeleton_scene = discovered
	return discovered


func _find_menacing_scene_in_folder(folder_path: String, depth: int) -> PackedScene:
	if depth > 4:
		return null
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		return null
	if dir.list_dir_begin() != OK:
		return null
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			var full_path: String = folder_path.path_join(file_name)
			if dir.current_is_dir():
				var nested: PackedScene = _find_menacing_scene_in_folder(full_path, depth + 1)
				if nested != null:
					dir.list_dir_end()
					return nested
			else:
				var lower: String = file_name.to_lower()
				if lower.ends_with(".tscn") and lower.contains("menac") and lower.contains("skeleton"):
					var resource: Resource = load(full_path)
					if resource is PackedScene:
						dir.list_dir_end()
						return resource as PackedScene
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


func _king_elite_is_alive() -> bool:
	if not is_instance_valid(king_elite) or king_elite.is_queued_for_deletion():
		return false
	if king_elite.has_method(&"is_dead"):
		return not bool(king_elite.call(&"is_dead"))
	return true


func _try_spawn_king_elite() -> bool:
	if _king_elite_is_alive() or king_elite_waves_spawned >= king_elite_total_waves:
		return false
	var scene: PackedScene = _resolve_king_menacing_scene()
	if scene == null:
		if not king_elite_missing_scene_warned:
			push_error("GRAVE MONARCH: Menacing Skeleton scene NOT FOUND! In your kingnecro.tscn, select the root CharacterBody2D and drag the actual Menacing Skeleton .tscn into King's Menacing Skeleton Guards > King Menacing Skeleton Scene. King will NEVER spawn normal skeletons instead.")
			king_elite_missing_scene_warned = true
			_update_king_hp_label()
		return false
	if not is_instance_valid(target):
		return false
	var spawn_floor: Dictionary = {}
	var player_pos: Vector2 = target.global_position
	var best_score: float = INF
	for offset: float in [-125.0, 125.0, -75.0, 75.0, -35.0, 35.0, 0.0]:
		var ground: Dictionary = _ground_at(player_pos.x + offset, player_pos.y - 95.0)
		if ground.is_empty():
			continue
		var ground_pos: Vector2 = ground["position"]
		var height_gap: float = absf(ground_pos.y - (player_pos.y + 30.0))
		if height_gap > 145.0:
			continue
		var score: float = height_gap * 2.0 + absf(absf(offset) - 90.0) * 0.35
		if score < best_score:
			best_score = score
			spawn_floor = ground
	# If a narrow moving platform defeats the ray sampler, materialize just
	# above the player's position. The elite's existing gravity lands it on the
	# actual platform beneath the player. NEVER silently skip the summon forever.
	var summoned: Node = scene.instantiate()
	if not summoned is CharacterBody2D:
		push_warning("King Necromancer: Menacing Skeleton scene root must be CharacterBody2D.")
		summoned.free()
		return false
	var elite: CharacterBody2D = summoned as CharacterBody2D
	var collider: CollisionShape2D = elite.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null or not collider.shape is RectangleShape2D:
		push_warning("King Necromancer: Menacing Skeleton scene needs a rectangular CollisionShape2D.")
		elite.free()
		return false
	# Set BEFORE add_child so the minion's _ready() sees its new stats and tag.
	elite.set_meta(&"king_necromancer_summon", true)
	elite.set_meta(&"necromancer_summon_owner", get_instance_id())
	elite.set("max_hp", king_elite_hp)
	elite.set("activation_radius", 900.0)
	elite.set("pursuit_speed", 112.0)
	elite.set("attack_interval", 0.72)
	elite.set("debug_grant_all_artifact_buffs_on_engage", false)
	var rect: RectangleShape2D = collider.shape as RectangleShape2D
	var feet: float = collider.position.y + rect.size.y * 0.5 * absf(collider.scale.y)
	var spawn_world: Vector2 = target.global_position + Vector2(78.0, -100.0)
	if not spawn_floor.is_empty():
		spawn_world = (spawn_floor["position"] as Vector2) - Vector2(0.0, feet + 3.0)
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent is Node2D:
		elite.position = (parent as Node2D).to_local(spawn_world)
	else:
		elite.position = spawn_world
	parent.add_child(elite)
	add_collision_exception_with(elite)
	elite.add_collision_exception_with(self)
	king_elite = elite
	king_elite_waves_spawned += 1
	king_elite_timer = maxf(5.0, king_elite_resummon_delay)
	king_exposure_timer = maxf(king_exposure_timer, 1.0)
	print("GRAVE MONARCH: summoned Menacing Skeleton wave ", king_elite_waves_spawned)
	return true


func _update_king_elite_reinforcements(delta: float) -> void:
	if not is_king or king_elite_waves_spawned >= king_elite_total_waves:
		return
	if _king_elite_is_alive():
		return
	# Wave 2 only appears in the desperate half of the fight.
	if king_elite_waves_spawned > 0 and hp > max_hp / 2:
		return
	king_elite_timer -= delta
	if king_elite_timer <= 0.0:
		if king_elite_waves_spawned > 0:
			# In the second half, the King actually descends to a ledge and casts
			# the Menacing Skeleton revival, giving the player a damage window.
			if not _begin_king_elite_revive():
				king_elite_timer = 2.0
		elif not _try_spawn_king_elite():
			king_elite_timer = 2.0


func _begin_king_elite_revive() -> bool:
	if not is_instance_valid(target) or _resolve_king_menacing_scene() == null:
		return false
	var best_ground: Dictionary = {}
	var best_score: float = INF
	for offset: float in [-80.0, 80.0, -40.0, 40.0, 0.0]:
		var hit: Dictionary = _ground_at(target.global_position.x + offset, target.global_position.y - 95.0)
		if hit.is_empty():
			continue
		var p: Vector2 = hit["position"]
		var score: float = absf(p.y - target.global_position.y - 25.0) + absf(absf(offset) - 80.0) * 0.1
		if score < best_score:
			best_score = score
			best_ground = hit
	if best_ground.is_empty():
		return false
	revive_slot = SummonSlot.new()
	revive_slot.floor_position = best_ground["position"]
	revive_destination = _revive_position()
	king_elite_revival_pending = true
	state = State.DESCENDING
	_clear_skulls()
	shots_left = 0
	_clear_king_gravefall()
	_set_flight_collision(false)
	_play(&"walk", true)
	print("GRAVE MONARCH: DESCENDING TO REVIVE MENACING SKELETON")
	return true


func _set_flight_collision(landing: bool) -> void:
	# Collision LAYER stays unchanged so the player's attack/hurtbox systems can
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
	# Dedicated King scene: activate now, no level-name or group selection needed.
	_activate_king_mode()


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
	if is_king and state not in [State.DORMANT, State.DESCENDING, State.REVIVING, State.DEAD]:
		_update_king_specials(delta)
		_update_king_elite_reinforcements(delta)
	if is_king:
		_update_king_crown(delta)
	if state != State.DORMANT:
		sprite.self_modulate = Color(1.0, 0.44, 0.44) if flash_timer > 0.0 else sprite_tint
		queue_redraw()


func _begin_encounter() -> void:
	if is_king:
		# True boss mode: enter immediately instead of spending 5+ seconds
		# summoning NORMAL skeletons before its first actual royal attack.
		state = State.GUARDED
		opening_complete = true
		slots.clear()
		barrage_timer = 0.7
		king_gravefall_cooldown_timer = 0.30
		king_elite_timer = maxf(0.65, minf(1.5, king_first_elite_delay))
		_play(&"idle")
		print("GRAVE MONARCH: START BOSS PATTERN / MENACING ONLY")
		return
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
		# the platform the player is actually standing on (common in Radiance arenas).
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
	if is_king:
		state = State.GUARDED
		return
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
	if is_king:
		# Never instantiate skeletonenemy.tscn from the King, including revival.
		push_warning("GRAVE MONARCH V5: blocked legacy normal-skeleton spawn")
		return
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
	if is_king:
		_update_hover(delta)
		_update_barrage(delta)
		return
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
	if living_count >= 2 and not is_king:
		if shots_left > 0 or not skulls.is_empty():
			_clear_skulls()
			shots_left = 0
		barrage_timer = maxf(barrage_timer, 1.1)
		return
	# V4: King's pressure NEVER shuts off just because guards are alive.
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
		if is_king and king_barrage_is_fan:
			# Crown of Skulls: one readable cast, then a 5-skull spread.
			for angle_degrees: float in [-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]:
				_launch_skull(deg_to_rad(angle_degrees))
			shots_left = 0
		else:
			_launch_skull()
			shots_left -= 1
		if is_king and shots_left == 0:
			king_exposure_timer = maxf(king_exposure_timer, king_exposed_after_attack)
		barrage_timer = (0.19 if is_king else 0.20) if shots_left > 0 else (1.95 if is_king else 2.8)
	else:
		_play(&"spawnenemies2", true)
		if is_king:
			king_barrage_count += 1
			king_barrage_is_fan = king_barrage_count % 2 == 0
			shots_left = 1 if king_barrage_is_fan else 4
		else:
			shots_left = 4
		barrage_timer = 0.60


func _begin_descent() -> void:
	_clear_king_gravefall()
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
	var feet := body_shape.position.y + rectangle.size.y * 0.5 * absf(body_shape.scale.y)
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
	if is_king and king_elite_revival_pending:
		king_elite_revival_pending = false
		if not _try_spawn_king_elite():
			king_elite_timer = 2.0
	else:
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
	var preview_scene: PackedScene = SKELETON_SCENE
	if is_king and king_elite_revival_pending:
		preview_scene = _resolve_king_menacing_scene()
	if preview_scene == null:
		return
	var template := preview_scene.instantiate() as CharacterBody2D
	if template == null:
		return
	var template_sprite := template.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var collider_name: String = "CollisionShape2D" if is_king else "hitbox"
	var collider := template.get_node_or_null(collider_name) as CollisionShape2D
	if template_sprite == null or collider == null or not collider.shape is RectangleShape2D:
		template.free()
		return
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


func _launch_skull(
	angle_offset: float = 0.0,
	spawn_override: Vector2 = Vector2.ZERO,
	forced_direction: Vector2 = Vector2.ZERO,
	speed_multiplier: float = 1.0
) -> void:
	if not is_instance_valid(target):
		return
	if is_king:
		while skulls.size() >= maxi(3, king_max_live_skulls):
			var oldest: Skull = skulls.pop_front()
			if is_instance_valid(oldest.visual):
				oldest.visual.queue_free()
	var skull := Skull.new()
	var visual := Sprite2D.new()
	visual.texture = SKULL_TEXTURE
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.modulate = Color(0.85, 0.35, 1.0) if is_king else Color(1.0, 0.20, 0.26)
	visual.top_level = true
	var texture_size := SKULL_TEXTURE.get_size()
	visual.scale = Vector2.ONE * ((34.0 if is_king else 18.0) / maxf(texture_size.x, texture_size.y))
	add_child(visual)
	visual.global_position = spawn_override if spawn_override != Vector2.ZERO else body_shape.global_position
	var aim := target.global_position
	var player_body := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_body != null:
		aim = player_body.global_position
	var base_direction: Vector2 = visual.global_position.direction_to(aim)
	if forced_direction.length_squared() > 0.01:
		base_direction = forced_direction.normalized()
	skull.direction = base_direction.rotated(angle_offset).normalized()
	visual.rotation = skull.direction.angle() + PI
	skull.visual = visual
	skull.speed = skull_speed * (king_skull_speed_multiplier if is_king else 1.0) * speed_multiplier
	skull.damage = skull_damage
	skull.lifetime = 3.3 if is_king else 3.0
	skulls.append(skull)


func _update_skulls(delta: float) -> void:
	if skulls.is_empty() or not is_instance_valid(target):
		return
	var excluded := _excluded_bodies()
	excluded.erase(target.get_rid())
	for index in range(skulls.size() - 1, -1, -1):
		var skull := skulls[index]
		if not is_instance_valid(skull.visual):
			skulls.remove_at(index)
			continue
		var start := skull.visual.global_position
		var finish := start + skull.direction * skull.speed * delta
		# The King's spectral skulls fly THROUGH platforms like their master.
		# Ordinary necromancer skulls continue colliding with the terrain.
		var collision_bits: int = target.collision_layer if is_king else (terrain_mask | target.collision_layer)
		var query := PhysicsRayQueryParameters2D.create(start, finish, collision_bits, excluded)
		query.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		skull.lifetime -= delta
		if not hit.is_empty() or skull.lifetime <= 0.0:
			if hit.get("collider") == target and target.has_method(&"tomar_dano"):
				target.call(&"tomar_dano", skull.damage, start)
			skull.visual.queue_free()
			skulls.remove_at(index)
		else:
			skull.visual.global_position = finish


func _clear_skulls() -> void:
	for skull in skulls:
		skull.visual.queue_free()
	skulls.clear()


func can_receive_player_hit() -> bool:
	return (
		state == State.DESCENDING
		or state == State.REVIVING
		or (is_king and state not in [State.DEAD, State.DORMANT] and king_exposure_timer > 0.0)
	)


func is_reviving() -> bool:
	return state == State.REVIVING


func is_dead() -> bool:
	return state == State.DEAD


func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or not can_receive_player_hit():
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	_update_king_hp_label()
	flash_timer = 0.13
	if hp > 0:
		return
	state = State.DEAD
	_clear_king_gravefall()
	_clear_revive_preview()
	if is_instance_valid(king_hp_label):
		king_hp_label.queue_free()
	if is_instance_valid(king_hud):
		king_hud.queue_free()
	if is_instance_valid(king_crown_root):
		king_crown_root.queue_free()
	if is_instance_valid(king_elite):
		king_elite.queue_free()
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
	if is_king:
		# Giant aura behind the sprite. Crown is an actual foreground child.
		# Aura has no collision geometry.
		var center: Vector2 = body_shape.position
		var pulse: float = 0.5 + 0.5 * sin(hover_time * 3.0)
		draw_circle(center, 112.0 + 8.0 * pulse, Color(0.45, 0.08, 0.80, 0.13))
		draw_arc(center, 120.0 + 8.0 * pulse, 0.0, TAU, 56, Color(0.83, 0.36, 1.0, 0.80), 5.0, true)
		draw_arc(center, 150.0 - 5.0 * pulse, 0.0, TAU, 56, Color(0.70, 0.18, 1.0, 0.40), 4.0, true)
		if king_exposure_timer > 0.0:
			draw_arc(center, 82.0, 0.0, TAU, 48, Color(1.0, 0.89, 0.32, 0.97), 5.0, true)
		if king_gravefall_active:
			var progress: float = clampf(1.0 - king_gravefall_warning_timer / maxf(0.01, king_gravefall_warning_time), 0.0, 1.0)
			var alpha: float = 0.42 + 0.55 * progress
			if king_special_kind == 1:
				for x: float in king_gravefall_columns:
					var top: Vector2 = to_local(Vector2(x, king_gravefall_top_y))
					var bottom: Vector2 = to_local(Vector2(x, king_gravefall_bottom_y))
					draw_line(top, bottom, Color(0.97, 0.25, 0.94, alpha), 7.0, true)
					draw_circle(bottom, 9.0, Color(1.0, 0.79, 0.98, alpha))
			elif king_special_kind == 2:
				for y: float in king_sweep_y:
					var start: Vector2 = to_local(Vector2(king_sweep_spawn_x, y))
					var end: Vector2 = to_local(Vector2(king_sweep_spawn_x, y) + king_sweep_direction * 730.0)
					draw_line(start, end, Color(0.96, 0.29, 0.87, alpha), 6.0, true)
			elif king_special_kind == 3:
				draw_arc(center, 130.0 - 25.0 * progress, 0.0, TAU, 60, Color(1.0, 0.33, 0.89, alpha), 8.0, true)
				for ray_index: int in range(7):
					var angle: float = TAU * float(ray_index) / 7.0
					var ray: Vector2 = Vector2.RIGHT.rotated(angle)
					draw_line(center + ray * 35.0, center + ray * 123.0, Color(0.90, 0.39, 1.0, alpha), 3.0, true)
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
