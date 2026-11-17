# V23 - keep massive King visually above/outside guard fights; exposed slash storm; preserve V16 damage
# V22 - keep boss high, compact shield visuals, active post-shield attacks, verified V16 damage
# V21 - restored verified V16 damage/hurtbox path, with high natural guard hover
# V16 - independent King patrol (no player X/Y tracking); fixed-position guard retreat
# V15 - King retreats to the far edge while his Menacing guards fight; no new teleports or player changes
# V14 - 1% royal ward with hit repulsion; slash-heavy Last Stand; slower rarer skull volleys
# King Necromancer V13: guaranteed Last Stand after first purple guard, King revival casting animation, bigger skulls
# King Necromancer V12: one purple guard at a time, no King spells during revival/fight, properly spaced revivals
# King Necromancer V11: repeated in-place royal resurrection; real hitbox-width slashes; active king
# King Necromancer V10: true sword damage, post-shield Radiance combat, single purple resurrected Menacing
# King Necromancer V9.8: independent guard roles + readable warning overrides
# V9.7 - timed shield at 10s, two Menacing guards, automatic shield shatter, rare attacks while guards fight, HUD on first encounter
# V9.6 - safer distant spectral skull spawns, delayed and eased tracking
# V9.5 - HUD visibility, immediate black-hit feedback, global post-attack 1s pause
# V9.4 - slower skull spawn rhythm, smaller King, clearer damage feedback
# V9.3 - stronger spectral skull tracking; remove unreachable directional skull walls
# V9.2 - Fix shield pulse reference after V9.1 rename
# V9.1 - Fix duplicate local pulse declaration in shield drawing
# V9 - two-stage Grave Monarch: unshielded solo, black hit flash; single buffed Menacing shield phase; shield break then defenseless execution; larger skulls
# V8 - rapid slashes, 4-wave Radiance-style skull walls with guaranteed safe gaps, Menacing 25HP + readable tells
# V7 - King hittable at all active times; arena-spanning thick purple slashes; orbiting spectral skulls with 0.5s warnings and 15s volley cooldown
# V6 - royal slash telegraphs, fast expansion/fade, two Radiance-like attack patterns
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
@export_range(3.5, 7.0, 0.1) var king_visual_scale: float = 4.6
@export_range(1.0, 2.0, 0.05) var king_hover_speed_multiplier: float = 1.45
@export_range(1.0, 2.0, 0.05) var king_skull_speed_multiplier: float = 1.18
@export_range(0.85, 8.0, 0.05) var king_gravefall_cooldown: float = 1.75
@export_range(0.35, 2.0, 0.05) var king_gravefall_warning_time: float = 0.85
@export_range(8, 32, 1) var king_max_live_skulls: int = 24
@export_range(0.5, 3.0, 0.05) var king_exposed_after_attack: float = 1.65
@export_group("Royal Slash FX + Hit Detection")
@export_range(12.0, 60.0, 1.0) var king_slash_hitbox_width: float = 34.0
@export_range(0.03, 0.15, 0.01) var king_slash_expand_seconds: float = 0.055
@export_range(0.12, 0.55, 0.01) var king_slash_fade_seconds: float = 0.28
@export_range(0.10, 0.7, 0.05) var king_slash_hit_cooldown: float = 0.34

@export_group("King Global Attack Recovery")
@export_range(0.5, 3.0, 0.1) var king_post_attack_pause: float = 1.0

@export_group("King Spectral Skull Volleys")
@export_range(0.8, 2.5, 0.05) var king_skull_spawn_interval: float = 1.35
@export_range(10.0, 40.0, 0.5) var king_skull_volley_cooldown: float = 20.0
@export_range(0.25, 0.8, 0.05) var king_skull_charge_duration: float = 0.50
@export_range(1.0, 4.0, 0.1) var king_skull_terrain_phase_time: float = 2.0
# Stronger but still rate-limited pursuit: no instantaneous 180-degree turns.
@export_range(0.7, 5.0, 0.1) var king_skull_turn_rate: float = 2.15
@export_range(170.0, 420.0, 10.0) var king_skull_min_spawn_distance: float = 260.0
@export_range(0.0, 0.8, 0.05) var king_skull_tracking_delay: float = 0.30
@export_range(0.1, 1.2, 0.05) var king_skull_tracking_ramp: float = 0.45
@export_range(140.0, 340.0, 10.0) var king_skull_flight_speed: float = 235.0

@export_group("King Skull Walls")
@export_range(0.5, 2.0, 0.05) var king_wall_warning_time: float = 0.9
@export_range(180.0, 550.0, 10.0) var king_wall_speed: float = 340.0
@export_range(70.0, 150.0, 5.0) var king_wall_safe_gap: float = 110.0
@export_range(0.35, 1.25, 0.05) var king_wall_wave_interval: float = 0.85

@export_group("King's Menacing Skeleton Guards")
# Drag your existing Menacing Skeleton .tscn here. V4 also checks common paths.
@export var king_menacing_skeleton_scene: PackedScene
@export var king_elite_total_waves: int = 2
# The first two guards are NORMAL Menacing Skeletons. Only the one revived
# after shield break becomes the purple, high-powered version.
@export_range(15, 80, 5) var king_normal_guard_hp: int = 25
@export_range(50, 200, 5) var king_reborn_guard_hp: int = 110
@export_range(4.0, 20.0, 0.5) var king_revival_after_shield_seconds: float = 7.0
@export_range(3.0, 20.0, 0.5) var king_reborn_boss_spell_interval: float = 5.8
@export_range(1, 8, 1) var king_max_total_resurrections: int = 4
# V12 caps active resurrected guards at one, even if a saved scene overrides this value.
@export_range(1, 3, 1) var king_max_active_purple_guards: int = 1
@export_range(6.0, 30.0, 0.5) var king_repeat_revival_delay: float = 16.0
@export_range(25, 120, 5) var king_elite_hp: int = 55 # legacy setting, no longer forces normal guards to be elite
@export_range(5.0, 15.0, 0.5) var king_shield_appear_delay: float = 10.0
@export_range(6.0, 20.0, 0.5) var king_guard_attack_interval: float = 10.0
@export_range(0.0, 15.0, 0.5) var king_first_elite_delay: float = 1.0
@export_range(5.0, 30.0, 0.5) var king_elite_resummon_delay: float = 11.0

@export_group("King Shield Final Phase")
@export_range(0.15, 0.60, 0.05) var king_shield_trigger_hp_ratio: float = 0.35
@export_range(0.35, 1.5, 0.05) var king_shield_break_duration: float = 0.85
@export_range(0.1, 0.6, 0.05) var king_shield_hit_pulse_duration: float = 0.30
@export_range(0.05, 0.25, 0.01) var king_black_hit_flash_duration: float = 0.12
@export_range(32.0, 96.0, 2.0) var king_spectral_skull_size: float = 60.0
@export_range(38.0, 76.0, 2.0) var king_wall_skull_size: float = 52.0

@export_group("King Last Stand (After First Purple Guard)")
@export_range(0.35, 0.70, 0.05) var king_last_stand_heal_ratio: float = 0.50
@export_range(1.0, 4.0, 0.1) var king_last_stand_intro_seconds: float = 2.0
@export_range(0.35, 1.0, 0.05) var king_last_stand_spell_cooldown_factor: float = 0.50
@export_range(18.0, 40.0, 0.5) var king_last_stand_skull_volley_cooldown: float = 27.0
@export_range(0.60, 0.95, 0.05) var king_last_stand_warning_factor: float = 0.78
@export_group("King Standoff While Guards Fight")
# Guard encounters should feel like a fight against the skeletons, not a
# simultaneous melee with the King's enormous shield/hurtbox.
@export_range(260.0, 650.0, 10.0) var king_guard_standoff_distance: float = 400.0
@export_range(140.0, 600.0, 10.0) var king_guard_retreat_speed: float = 290.0
@export_range(2.0, 8.0, 0.5) var king_guard_retarget_cooldown: float = 4.5
@export_group("King Independent Hover")
@export_range(25.0, 190.0, 5.0) var king_patrol_horizontal_radius: float = 120.0
@export_range(12.0, 100.0, 5.0) var king_patrol_vertical_radius: float = 35.0
# Guard-only movement: does NOT modify the working sword-hit logic.
@export_range(0.08, 0.28, 0.01) var king_guard_height_ratio: float = 0.14
@export_range(180.0, 400.0, 10.0) var king_guard_chase_distance: float = 235.0
@export_range(180.0, 1100.0, 20.0) var king_guard_flight_acceleration: float = 520.0
@export_range(0.18, 0.42, 0.01) var king_solo_hover_height_ratio: float = 0.30
@export_range(0.07, 0.28, 0.01) var king_guard_hover_height_ratio: float = 0.13
@export_range(5, 9, 1) var king_exposed_spells_before_revival: int = 5

@export_group("King 1% Royal Ward")
@export_range(35.0, 160.0, 5.0) var king_ward_repel_distance: float = 95.0
@export_range(0.4, 2.0, 0.1) var king_ward_repel_cooldown: float = 0.85

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
	var spectral: bool = false
	var charge_elapsed: float = 0.0
	var flight_elapsed: float = 0.0
	var orbit_sign: float = 1.0
	var wobble_seed: float = 0.0
	var base_scale: Vector2 = Vector2.ONE


class SkullWall:
	var from_side: bool = true
	var sign: float = 1.0
	var safe_center: float = 0.0
	var timer: float = 0.0
	var travel: float = 0.0
	var hit_done: bool = false
	var warned_view: Rect2 = Rect2()

class RoyalSlash:
	var from_world: Vector2 = Vector2.ZERO
	var to_world: Vector2 = Vector2.ZERO
	var delay: float = 0.0
	var warning: float = 0.85
	var elapsed: float = 0.0
	var fired: bool = false



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
var king_gravefall_cooldown_timer: float = 1.4
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
var king_elite_guards: Array[CharacterBody2D] = []
var king_elite_waves_spawned: int = 0
var king_elite_timer: float = 4.0
var king_elite_missing_scene_warned: bool = false
var king_elite_scene_lookup_exhausted: bool = false
var king_desperation_started: bool = false
var king_crown_root: Node2D = null
var king_base_sprite_scale: Vector2 = Vector2.ONE
var king_elite_revival_pending: bool = false
var king_royal_slashes: Array[RoyalSlash] = []
var king_slash_hit_cooldown_remaining: float = 0.0
var king_crown_burst_remaining: float = 0.0
var king_skull_volley_timer: float = 1.2
var king_skull_interval_timer: float = 0.0
var king_skull_spawns_remaining: int = 0
var king_skull_walls: Array[SkullWall] = []
var king_wall_spawn_remaining: int = 0
var king_wall_spawn_timer: float = 0.0
var king_wall_from_side: bool = true
var king_wall_round: int = 0

# Phase flow: SOLO -> SHIELDED (2 normal guards) -> BREAKING -> EXPOSED.
# EXPOSED is NOT passive: full spells resume and the King can take damage.
# A SINGLE purple Menacing can be revived after a short delay.
enum KingShieldPhase { SOLO, SHIELDED, BREAKING, EXPOSED }
var king_shield_phase: KingShieldPhase = KingShieldPhase.SOLO
var king_shield_hit_fx: float = 0.0
var king_shield_break_fx: float = 0.0
var king_black_flash_timer: float = 0.0
var king_post_attack_timer: float = 0.0
var king_shield_spawn_retry: float = 0.0
var king_shield_elite_spawned: bool = false
var king_shield_animation_time: float = 0.0
var king_shield_countdown: float = -1.0
var king_guard_attack_timer: float = 10.0
var king_revival_timer: float = -1.0
var king_revival_started: bool = false
var king_revival_completed: bool = false
var king_reborn_guard: CharacterBody2D = null
var king_dead_guard_position: Vector2 = Vector2.ZERO
var king_dead_guard_position_known: bool = false
var king_revival_attempt_cooldown: float = 0.0
var king_total_resurrections: int = 0
var king_reborn_guards: Array[CharacterBody2D] = []
var king_revival_cast_fx: float = 0.0
var king_last_revived_id: int = -1
var king_was_purple_guard_active: bool = false
# The King cannot be finished before the first purple guard is defeated;
# then he recovers HP and enters a real final spell phase.
var king_last_stand_started: bool = false
var king_last_stand_intro_timer: float = 0.0
var king_revival_cast_total: float = 0.0
var king_ward_repel_timer: float = 0.0
var king_guard_standoff_side: float = 0.0
var king_guard_standoff_active: bool = false
var king_guard_standoff_anchor: Vector2 = Vector2.ZERO
var king_guard_retarget_timer: float = 0.0
var king_guard_flight_velocity: Vector2 = Vector2.ZERO
var king_solo_hover_anchor: Vector2 = Vector2.ZERO
var king_solo_hover_anchor_set: bool = false
var king_exposed_spells_since_break: int = 0


func _activate_king_mode() -> void:
	if is_king:
		return
	is_king = true
	king_desperation_started = false
	king_shield_phase = KingShieldPhase.SOLO
	king_shield_hit_fx = 0.0
	king_shield_break_fx = 0.0
	king_black_flash_timer = 0.0
	king_post_attack_timer = 0.0
	king_shield_elite_spawned = false
	king_elite_total_waves = 2
	king_elite_guards.clear()
	king_shield_countdown = -1.0
	king_guard_attack_timer = king_guard_attack_interval
	king_revival_timer = -1.0
	king_revival_started = false
	king_revival_completed = false
	king_reborn_guard = null
	king_reborn_guards.clear()
	king_total_resurrections = 0
	king_revival_cast_fx = 0.0
	king_last_revived_id = -1
	king_was_purple_guard_active = false
	king_last_stand_started = false
	king_last_stand_intro_timer = 0.0
	king_revival_cast_total = 0.0
	king_ward_repel_timer = 0.0
	king_guard_standoff_side = 0.0
	king_guard_standoff_active = false
	king_guard_standoff_anchor = Vector2.ZERO
	king_guard_retarget_timer = 0.0
	king_guard_flight_velocity = Vector2.ZERO
	king_solo_hover_anchor_set = false
	king_solo_hover_anchor = Vector2.ZERO
	king_exposed_spells_since_break = 0
	king_dead_guard_position_known = false
	add_to_group(&"king_necromancer")
	king_skull_volley_timer = 1.2
	king_skull_spawns_remaining = 0
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
	# Respect a smaller boss size even if level_5.tscn retained its old
	# Inspector value (5.2) from V9.3. This version caps the effective scale.
	sprite.scale = king_base_sprite_scale * clampf(king_visual_scale, 3.5, 4.6)
	body_shape.scale *= 1.30
	sprite_tint = Color(0.92, 0.61, 1.0, 1.0)
	sprite.self_modulate = sprite_tint
	_build_king_crown()
	king_gravefall_cooldown_timer = 0.30
	king_elite_timer = 0.0 # Not summoned during the solo phase.
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


func _king_visual_half_width() -> float:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return 90.0
	if not sprite.sprite_frames.has_animation(&"idle"):
		return 90.0
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return 90.0
	return maxf(80.0, texture.get_size().x * absf(sprite.global_scale.x) * 0.50)


func _king_visible_bottom_offset() -> float:
	# Difference between the King's root and the BOTTOM of the actual art.
	# The old guard anchor ignored the huge sprite's bottom half and placed
	# the art down in the same floor lane as the purple Menacing Skeleton.
	return sprite.global_position.y - global_position.y + _king_visual_half_height()


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
	# Put the HUD directly under the tree root, above any scene CanvasLayers.
	# Parenting it to the level allowed later scene overlays to hide it.
	king_hud.layer = 110
	get_tree().root.add_child(king_hud)
	king_hud.visible = true
	var frame := VBoxContainer.new()
	frame.name = "BossHeader"
	frame.visible = true
	frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
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
	# Godot's standard ProgressBar shows the actual percent lost. This makes
	# confirmed damage immediately visible without a hurt animation.
	king_hud_bar.show_percentage = true
	king_hud_bar.visible = true
	king_hud_bar.modulate = Color.WHITE
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
	print("KING HUD CREATED: ", king_hud.get_path(), " layer=", king_hud.layer)


func _update_king_hp_label() -> void:
	if is_king and not is_instance_valid(king_hud) and is_inside_tree():
		_create_king_boss_hud()
	if is_instance_valid(king_hud):
		king_hud.visible = true
	if is_instance_valid(king_hp_label):
		king_hp_label.text = "KING  %d/%d" % [hp, max_hp]
	if is_instance_valid(king_hud_bar):
		king_hud_bar.max_value = float(max_hp)
		king_hud_bar.value = float(hp)
		king_hud_bar.tooltip_text = "KING HP: %d / %d" % [hp, max_hp]
	if is_instance_valid(king_hud_status):
		if king_elite_missing_scene_warned and king_menacing_skeleton_scene == null:
			king_hud_status.text = "ASSIGN MENACING SKELETON .tscn IN KING INSPECTOR"
		elif king_shield_phase == KingShieldPhase.SHIELDED:
			king_hud_status.text = "ROYAL SHIELD  |  DEFEAT BOTH MENACING GUARDS (%d/2 LEFT)" % _king_elites_alive_count()
		elif king_shield_phase == KingShieldPhase.BREAKING:
			king_hud_status.text = "THE CROWN SHATTERS"
		elif king_revival_cast_fx > 0.0:
			king_hud_status.text = "ROYAL NECROMANCY  |  A PURPLE GUARD IS RISING"
		elif _king_purple_ward_active():
			king_hud_status.text = "ROYAL WARD  |  KING AT 1%  |  DEFEAT THE PURPLE GUARD"
		elif king_last_stand_intro_timer > 0.0:
			king_hud_status.text = "FINAL PHASE  |  THE KING ABSORBS THE FALLEN GUARD"
		elif king_shield_phase == KingShieldPhase.EXPOSED and _king_active_purple_count() > 0:
			king_hud_status.text = "PURPLE GUARD ACTIVE  |  DEFEAT IT TO REACH THE LAST STAND"
		elif king_last_stand_started:
			king_hud_status.text = "LAST STAND  |  THE GRAVE MONARCH UNLEASHED"
		elif king_shield_phase == KingShieldPhase.EXPOSED and hp <= 1:
			king_hud_status.text = "THE KING CLINGS TO LIFE  |  PURPLE REVIVAL INCOMING"
		elif king_shield_phase == KingShieldPhase.EXPOSED:
			king_hud_status.text = "SHIELD SHATTERED  |  THE KING KEEPS FIGHTING"
		elif king_special_kind == 1:
			king_hud_status.text = "ROYAL GRAVEFALL  |  Dodge the marked columns"
		elif king_special_kind == 2:
			king_hud_status.text = "PHANTOM PROCESSION  |  Find the open lane"
		elif king_special_kind == 3:
			king_hud_status.text = "CROWN OF SKULLS  |  Wide fan incoming"
		elif king_special_kind == 4:
			king_hud_status.text = "HEAVEN'S LANCES  |  Three staggered strikes"
		elif king_special_kind == 5:
			king_hud_status.text = "ECLIPSE JUDGMENT  |  Dodge the crossing light"
		elif king_special_kind == 6:
			king_hud_status.text = "GRAVE SHEARS  |  Staggered diagonal blades"
		elif king_special_kind == 7:
			king_hud_status.text = "ROYAL SPEARFALL  |  Shift between the columns"
		elif king_special_kind == 8:
			king_hud_status.text = "ROYAL CROSSWEAVE  |  Dodge the staggered blades"
		elif king_exposure_timer > 0.0:
			king_hud_status.text = "SHIELD BROKEN  |  STRIKE NOW"
		else:
			king_hud_status.text = "ROYAL GUARDS ARRIVING SOON" if king_shield_countdown >= 0.0 else "THE DEAD ANSWER THEIR KING"


func _clear_king_gravefall() -> void:
	king_gravefall_active = false
	king_special_kind = 0
	king_gravefall_warning_timer = 0.0
	king_gravefall_columns.clear()
	king_sweep_y.clear()
	queue_redraw()


func _queue_king_slash(
	from_world: Vector2,
	to_world: Vector2,
	warning_time: float,
	delay_time: float = 0.0
) -> void:
	var slash: RoyalSlash = RoyalSlash.new()
	slash.from_world = from_world
	slash.to_world = to_world
	# In Last Stand, a faster warning is fair because the blade lane is exact.
	# Each line still has at least 0.52s to react before it can deal damage.
	slash.warning = maxf(0.52, warning_time * minf(0.78, king_last_stand_warning_factor)) if king_last_stand_started else maxf(0.34, warning_time)
	slash.delay = maxf(0.0, delay_time)
	king_royal_slashes.append(slash)


func _king_royal_slash_hits_player(slash: RoyalSlash) -> bool:
	if not is_instance_valid(target):
		return false
	var v: Vector2 = slash.to_world - slash.from_world
	if v.length_squared() < 1.0:
		return false
	var beam: RectangleShape2D = RectangleShape2D.new()
	beam.size = Vector2(v.length(), maxf(3.0, king_slash_hitbox_width))
	var beam_pose: Transform2D = Transform2D(v.angle(), (slash.from_world + slash.to_world) * 0.5)
	# Compare the true, rotated beam against the player's active body shape.
	for node: Node in target.get_children():
		if not node is CollisionShape2D:
			continue
		var player_shape: CollisionShape2D = node as CollisionShape2D
		if player_shape.disabled or player_shape.shape == null:
			continue
		if beam.collide(beam_pose, player_shape.shape, player_shape.global_transform):
			return true
	return false


func _king_royal_slash_deal_damage(slash: RoyalSlash) -> void:
	if king_slash_hit_cooldown_remaining > 0.0:
		return
	if not _king_royal_slash_hits_player(slash):
		return
	king_slash_hit_cooldown_remaining = maxf(0.1, king_slash_hit_cooldown)
	var impact_origin: Vector2 = (slash.from_world + slash.to_world) * 0.5
	if target.has_method(&"tomar_dano"):
		target.call(&"tomar_dano", skull_damage, impact_origin)
	elif target.has_method(&"take_damage"):
		target.call(&"take_damage", skull_damage, impact_origin)


func _update_king_royal_slashes(delta: float) -> void:
	king_slash_hit_cooldown_remaining = maxf(0.0, king_slash_hit_cooldown_remaining - delta)
	king_crown_burst_remaining = maxf(0.0, king_crown_burst_remaining - delta)
	var was_slashing: bool = not king_royal_slashes.is_empty()
	for index: int in range(king_royal_slashes.size() - 1, -1, -1):
		var slash: RoyalSlash = king_royal_slashes[index]
		slash.elapsed += delta
		var attack_at: float = slash.delay + slash.warning
		if not slash.fired and slash.elapsed >= attack_at:
			slash.fired = true
			# One precisely timed hit; the remaining glow is only an afterimage.
			_king_royal_slash_deal_damage(slash)
		var stop_at: float = attack_at + king_slash_expand_seconds + king_slash_fade_seconds
		if slash.elapsed > stop_at:
			king_royal_slashes.remove_at(index)
	# All warning, impact, expansion and fade-out frames must be over before
	# any other attack can start its own warning.
	if was_slashing and king_royal_slashes.is_empty():
		king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)


func _draw_king_royal_slashes() -> void:
	for slash: RoyalSlash in king_royal_slashes:
		if slash.elapsed < slash.delay:
			continue
		var a: Vector2 = to_local(slash.from_world)
		var b: Vector2 = to_local(slash.to_world)
		var v: Vector2 = b - a
		if v.length_squared() < 1.0:
			continue
		var normal: Vector2 = Vector2(-v.y, v.x).normalized()
		var active_time: float = slash.elapsed - slash.delay
		if not slash.fired:
			# Fade in while the warning builds. First faint, then bright and
			# pulsating. No damage whatsoever during the telegraph.
			var t: float = clampf(active_time / maxf(0.01, slash.warning), 0.0, 1.0)
			var fade_in: float = clampf(t / 0.30, 0.0, 1.0)
			var breathe: float = 0.86 + 0.14 * sin(t * TAU * 5.0)
			var alpha: float = fade_in * breathe * (0.45 + 0.40 * t)
			# The warning's visible danger band is the SAME width as the actual
			# collision rectangle. The extra halo is faint and only 15% wider.
			draw_line(a, b, Color(0.48, 0.05, 0.90, alpha * 0.22), king_slash_hitbox_width * 1.15, true)
			draw_line(a, b, Color(0.85, 0.31, 1.0, alpha * 0.78), king_slash_hitbox_width, true)
			draw_line(a, b, Color(1.0, 0.84, 1.0, alpha * 0.75), maxf(1.5, king_slash_hitbox_width * 0.18), true)
			continue
		# On the damage frame the slash EXPANDS in ~60ms, then quickly
		# shrinks and fades, instead of vanishing abruptly.
		var after_hit: float = maxf(0.0, active_time - slash.warning)
		var expand_time: float = maxf(0.01, king_slash_expand_seconds)
		var fade_time: float = maxf(0.01, king_slash_fade_seconds)
		var width: float = 1.0
		var alpha: float = 1.0
		if after_hit < expand_time:
			var grow: float = clampf(after_hit / expand_time, 0.0, 1.0)
			width = lerpf(king_slash_hitbox_width * 0.88, king_slash_hitbox_width * 1.08, grow)
		else:
			var shrink: float = clampf((after_hit - expand_time) / fade_time, 0.0, 1.0)
			width = lerpf(king_slash_hitbox_width * 1.08, 0.4, shrink * shrink * (3.0 - 2.0 * shrink))
			alpha = pow(1.0 - shrink, 1.25)
		draw_line(a, b, Color(0.58, 0.06, 0.95, alpha * 0.24), width * 1.15, true)
		draw_line(a, b, Color(0.88, 0.34, 1.0, alpha * 0.90), width, true)
		draw_line(a, b, Color(1.0, 0.95, 1.0, alpha), maxf(0.6, width * 0.30), true)
		# Small shimmering cross sparks along the blade: zero extra nodes.
		for spark_i: int in range(1, 6):
			var p: Vector2 = a.lerp(b, float(spark_i) / 6.0)
			var spark_size: float = maxf(0.0, width * 0.65)
			draw_line(p - normal * spark_size, p + normal * spark_size,
				Color(1.0, 0.78, 1.0, alpha * 0.56), 1.4, true)


func _king_visible_world_rect() -> Rect2:
	# Use real camera viewport in world space, not fixed pixel guesses.
	var viewport_size: Vector2 = get_viewport_rect().size
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var top_left: Vector2 = inverse * Vector2.ZERO
	var bottom_right: Vector2 = inverse * viewport_size
	return Rect2(top_left, bottom_right - top_left).abs()


func _start_king_gravefall() -> void:
	king_special_kind = 1
	king_gravefall_active = true
	king_gravefall_warning_timer = maxf(0.65, king_gravefall_warning_time)
	king_gravefall_columns.clear()
	var view: Rect2 = _king_visible_world_rect()
	# Full-screen rows of purple blades, with navigable corridors in between.
	var center_x: float = clampf(target.global_position.x, view.position.x + 120.0, view.end.x - 120.0)
	for offset: float in [-330.0, -165.0, 0.0, 165.0, 330.0]:
		var x: float = center_x + offset
		if x < view.position.x - 20.0 or x > view.end.x + 20.0:
			continue
		king_gravefall_columns.append(x)
		_queue_king_slash(Vector2(x, view.position.y - 500.0),
			Vector2(x, view.end.y + 500.0), king_gravefall_warning_timer)
	queue_redraw()


func _start_king_sweep() -> void:
	king_special_kind = 2
	king_gravefall_active = true
	king_gravefall_warning_timer = 0.92
	king_sweep_y.clear()
	var view: Rect2 = _king_visible_world_rect()
	var player_y: float = clampf(target.global_position.y, view.position.y + 110.0, view.end.y - 110.0)
	# Full-width blades. The separation remains large enough to dodge.
	for offset: float in [-220.0, -110.0, 0.0, 110.0, 220.0]:
		var y: float = player_y + offset
		if y < view.position.y - 20.0 or y > view.end.y + 20.0:
			continue
		king_sweep_y.append(y)
		_queue_king_slash(Vector2(view.position.x - 500.0, y),
			Vector2(view.end.x + 500.0, y), king_gravefall_warning_timer)
	queue_redraw()


func _start_king_crown() -> void:
	king_special_kind = 3
	king_gravefall_active = true
	king_gravefall_warning_timer = 0.72
	queue_redraw()


func _start_king_heavens_lances() -> void:
	king_special_kind = 4
	king_gravefall_active = true
	king_gravefall_warning_timer = 1.8
	var view: Rect2 = _king_visible_world_rect()
	var center_x: float = target.global_position.x
	for wave: int in range(3):
		var offset_shift: float = float(wave) * 44.0
		for offset: float in [-130.0, 130.0]:
			var x: float = center_x + offset + (offset_shift if wave % 2 == 0 else -offset_shift)
			if x < view.position.x + 20.0 or x > view.end.x - 20.0:
				continue
			_queue_king_slash(Vector2(x, view.position.y - 500.0),
					Vector2(x, view.end.y + 500.0), 0.95, float(wave) * 0.32)
	queue_redraw()


func _start_king_eclipse_judgment() -> void:
	king_special_kind = 5
	king_gravefall_active = true
	king_gravefall_warning_timer = 1.72
	var view: Rect2 = _king_visible_world_rect()
	var center: Vector2 = view.get_center()
	var reach: float = view.size.length() * 1.40
	for i: int in range(2):
		var angle: float = deg_to_rad(35.0 if i == 0 else 145.0)
		var ray: Vector2 = Vector2.RIGHT.rotated(angle) * reach
		_queue_king_slash(center - ray, center + ray, 0.95, 0.45 * float(i))
	queue_redraw()


func _start_king_royal_crossweave() -> void:
	# Four staggered diagonal blades. Each has a true hit lane matching the
	# warning and at least 0.82 seconds before its own damage frame.
	# Unlike the old Crown pulse this is a real attack, not decorative FX.
	king_special_kind = 8
	king_gravefall_active = true
	king_gravefall_warning_timer = 2.55
	var view: Rect2 = _king_visible_world_rect()
	var center: Vector2 = view.get_center()
	if is_instance_valid(target):
		center = Vector2(
			clampf(target.global_position.x, view.position.x + 180.0, view.end.x - 180.0),
			clampf(target.global_position.y, view.position.y + 120.0, view.end.y - 120.0)
		)
	var reach: float = view.size.length() * 1.30 + 500.0
	for wave: int in range(4):
		var theta: float = deg_to_rad(35.0 if wave % 2 == 0 else 145.0)
		var direction: Vector2 = Vector2.RIGHT.rotated(theta)
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		var lane_offset: float = -86.0 if wave < 2 else 86.0
		var lane_center: Vector2 = center + normal * lane_offset
		_queue_king_slash(lane_center - direction * reach,
			lane_center + direction * reach, 0.85, float(wave) * 0.38)
	queue_redraw()


func _start_king_grave_shears() -> void:
	# LAST STAND: three staggered diagonal cuts, not simultaneous crosses.
	# Each warning belongs to the exact collision blade, with time to move.
	king_special_kind = 6
	king_gravefall_active = true
	king_gravefall_warning_timer = 1.90
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = view.size.length() * 1.2 + 500.0
	var center: Vector2 = view.get_center()
	for wave: int in range(3):
		var theta: float = deg_to_rad(-37.0 if wave % 2 == 0 else 37.0)
		var direction: Vector2 = Vector2.RIGHT.rotated(theta)
		var offset: Vector2 = Vector2(0.0, float(wave - 1) * 92.0)
		_queue_king_slash(center + offset - direction * reach,
			center + offset + direction * reach, 0.82, float(wave) * 0.45)
	queue_redraw()


func _start_king_royal_spearfall() -> void:
	# LAST STAND: three staggered vertical waves. Gaps are wide enough for
	# normal-speed movement; each wave has its own independent warning.
	king_special_kind = 7
	king_gravefall_active = true
	king_gravefall_warning_timer = 1.95
	var view: Rect2 = _king_visible_world_rect()
	var anchor_x: float = clampf(target.global_position.x,
		view.position.x + 130.0, view.end.x - 130.0)
	for wave: int in range(3):
		var shift: float = 0.0 if wave % 2 == 0 else 90.0
		for offset: float in [-260.0, -130.0, 130.0, 260.0]:
			var x: float = anchor_x + offset + shift
			if x < view.position.x - 18.0 or x > view.end.x + 18.0:
				continue
			_queue_king_slash(Vector2(x, view.position.y - 500.0),
				Vector2(x, view.end.y + 500.0), 0.82, float(wave) * 0.44)
	queue_redraw()


func _fire_king_gravefall() -> void:
	# V6: actual animated purple slashes own the damage now. Do not also
	# spawn overlapping invisible skull hits in the same warned lanes.
	_finish_king_spell()


func _fire_king_sweep() -> void:
	_finish_king_spell()


func _fire_king_crown() -> void:
	# Skull volleys have an independent 15-second cooldown; never bypass it.
	king_crown_burst_remaining = 0.34
	_finish_king_spell()


func _finish_king_spell() -> void:
	king_exposure_timer = maxf(king_exposure_timer, king_exposed_after_attack)
	# This spell finishes its warning/damage phase here. If its animated
	# slashes remain, the shared pause starts when their final fade ends.
	if king_royal_slashes.is_empty():
		king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
	_clear_king_gravefall()
	_update_king_hp_label()


func _update_king_specials(delta: float) -> void:
	if king_shield_phase == KingShieldPhase.BREAKING or king_last_stand_intro_timer > 0.0:
		return
	if not is_king or not is_instance_valid(target):
		return
	# The King attacks rarely while both Menacing guards occupy the player.
	# Existing, fully warned slash attack can continue to completion.
	if king_shield_phase == KingShieldPhase.SHIELDED and not king_gravefall_active:
		if not king_shield_elite_spawned or not _king_elite_is_alive():
			return
		if king_post_attack_timer > 0.0 or not king_royal_slashes.is_empty():
			return
		king_guard_attack_timer -= delta
		if king_guard_attack_timer <= 0.0:
			king_guard_attack_timer = maxf(7.0, king_guard_attack_interval)
			_start_king_gravefall()
		return
	# V12: a purple Menacing is its OWN boss encounter. The King pauses ALL
	# new spells while the corpse reanimates and until that purple guard dies.
	# The existing spell sequence resumes after the guard is defeated.
	if king_shield_phase == KingShieldPhase.EXPOSED and _king_active_purple_count() > 0:
		return
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
				4, 5, 6, 7, 8:
					_finish_king_spell()
				_:
					_clear_king_gravefall()
		_update_king_hp_label()
		return
	# An entire skull volley counts as one attack; it may not overlap
	# the Royal Slash patterns, and the shared recovery is mandatory.
	if king_skull_spawns_remaining > 0 or not king_royal_slashes.is_empty():
		return
	if king_post_attack_timer > 0.0:
		return
	king_gravefall_cooldown_timer -= delta
	if king_gravefall_cooldown_timer <= 0.0:
		king_special_round += 1
		if king_shield_phase == KingShieldPhase.EXPOSED and king_total_resurrections == 0:
			king_exposed_spells_since_break += 1
		if (king_shield_phase == KingShieldPhase.EXPOSED
			and king_total_resurrections == 0):
			# The King is genuinely dangerous without his army: five complete
			# damaging slash patterns before the first purple resurrection.
			# Skull volleys are disabled in this interval, not mixed between slashes.
			match king_exposed_spells_since_break % 5:
				1:
					_start_king_grave_shears()
				2:
					_start_king_royal_spearfall()
				3:
					_start_king_royal_crossweave()
				4:
					_start_king_heavens_lances()
				_:
					_start_king_eclipse_judgment()
		elif king_last_stand_started:
			# Slash-heavy finale, no wall of skulls or hollow warning-only attacks.
			# The full 1s global rest still applies AFTER each complete pattern.
			match king_special_round % 9:
				1:
					_start_king_gravefall()
				2:
					_start_king_grave_shears()
				3:
					_start_king_sweep()
				4:
					_start_king_royal_spearfall()
				5:
					_start_king_heavens_lances()
				6:
					_start_king_eclipse_judgment()
				7:
					_start_king_grave_shears()
				8:
					_start_king_royal_crossweave()
				_:
					_start_king_sweep()
		else:
			# Preserve the readable pre-finale attack cycle.
			match king_special_round % 7:
				1:
					_start_king_gravefall()
				2:
					_start_king_sweep()
				3:
					_start_king_grave_shears()
				4:
					_start_king_heavens_lances()
				5:
					_start_king_sweep()
				6:
					_start_king_eclipse_judgment()
				_:
					_start_king_gravefall()
		var spell_factor: float = (
			minf(king_last_stand_spell_cooldown_factor, 0.50)
			if king_last_stand_started
			else (0.78 if hp <= max_hp / 2 else 1.0)
		)
		if king_shield_phase == KingShieldPhase.EXPOSED and king_total_resurrections == 0:
			# Global one-second post-attack pause already ensures a readable break.
			# Do not add another 1+ second spell delay on top of that.
			king_gravefall_cooldown_timer = 0.10
		elif king_last_stand_started:
			king_gravefall_cooldown_timer = 0.20
		else:
			king_gravefall_cooldown_timer = maxf(1.0, king_gravefall_cooldown * spell_factor)
	_update_king_hp_label()




func _start_king_skull_walls(from_side: bool) -> void:
	# Four successive formations. Every wall has ONE full-sized real gap;
	# its location is locked at telegraph time, never tracks the player.
	king_wall_from_side = from_side
	king_wall_spawn_remaining = 4
	king_wall_spawn_timer = 0.0
	king_wall_round += 1
	_spawn_king_skull_wall()


func _spawn_king_skull_wall() -> void:
	if not is_instance_valid(target):
		return
	var wall: SkullWall = SkullWall.new()
	wall.from_side = king_wall_from_side
	wall.sign = -1.0 if king_wall_round % 2 == 0 else 1.0
	wall.warned_view = _king_visible_world_rect()
	var view: Rect2 = wall.warned_view
	var low: float = (view.position.y if wall.from_side else view.position.x) + 65.0
	var high: float = (view.end.y if wall.from_side else view.end.x) - 65.0
	if high < low:
		low = (low + high) * 0.5
		high = low
	var player_axis: float = target.global_position.y if wall.from_side else target.global_position.x
	# Alternates a centered safe gap with a predictable shift, not an
	# impossible reposition across the entire screen between successive walls.
	var shift: float = float((king_wall_spawn_remaining % 3) - 1) * 56.0
	wall.safe_center = clampf(player_axis + shift, low, high)
	king_skull_walls.append(wall)
	king_wall_spawn_remaining -= 1
	king_wall_spawn_timer = king_wall_wave_interval


func _update_king_skull_walls(delta: float) -> void:
	if king_wall_spawn_remaining > 0:
		king_wall_spawn_timer -= delta
		if king_wall_spawn_timer <= 0.0:
			_spawn_king_skull_wall()
	for i: int in range(king_skull_walls.size() - 1, -1, -1):
		var wall: SkullWall = king_skull_walls[i]
		wall.timer += delta
		if wall.timer < king_wall_warning_time:
			continue
		wall.travel += king_wall_speed * delta
		var v: Rect2 = wall.warned_view
		var axis: float = (v.position.x - 40.0 + wall.travel) if wall.sign > 0.0 else (v.end.x + 40.0 - wall.travel)
		var crossed: bool = wall.from_side and (axis > v.end.x + 90.0 or axis < v.position.x - 90.0)
		if not wall.from_side:
			axis = v.position.y - 40.0 + wall.travel
			crossed = axis > v.end.y + 90.0
		if not crossed and is_instance_valid(target):
			var p: Vector2 = target.global_position
			var contact: bool = (absf(p.x - axis) <= 30.0) if wall.from_side else (absf(p.y - axis) <= 30.0)
			var within_view: bool = v.grow(30.0).has_point(p)
			var gap_axis: float = p.y if wall.from_side else p.x
			if contact and within_view and absf(gap_axis - wall.safe_center) > king_wall_safe_gap * 0.5 - 8.0 and not wall.hit_done:
				wall.hit_done = true
				if target.has_method(&"tomar_dano"):
					target.call(&"tomar_dano", skull_damage, global_position)
		if crossed:
			king_skull_walls.remove_at(i)
	if not king_skull_walls.is_empty():
		queue_redraw()


func _draw_king_skull_walls() -> void:
	var tex: Texture2D = SKULL_TEXTURE
	if tex == null:
		return
	for wall: SkullWall in king_skull_walls:
		var v: Rect2 = wall.warned_view
		var warning_t: float = clampf(wall.timer / maxf(0.01, king_wall_warning_time), 0.0, 1.0)
		var warned: bool = wall.timer < king_wall_warning_time
		var alpha: float = (warning_t * 0.68) if warned else 1.0
		var advance: float = wall.travel if not warned else 0.0
		var axis: float = (v.position.x - 40.0 + advance) if wall.sign > 0.0 else (v.end.x + 40.0 - advance)
		if not wall.from_side:
			axis = v.position.y - 40.0 + advance
		var min_axis: float = v.position.y if wall.from_side else v.position.x
		var max_axis: float = v.end.y if wall.from_side else v.end.x
		# Skulls overlap slightly to make the wall visually continuous.
		var coord: float = min_axis
		while coord <= max_axis:
			if absf(coord - wall.safe_center) > king_wall_safe_gap * 0.5 + 14.0:
				var world: Vector2 = Vector2(axis, coord) if wall.from_side else Vector2(coord, axis)
				var center: Vector2 = to_local(world)
				var scale_val: float = lerpf(0.28, 1.0, warning_t) if warned else 1.0
				var size: Vector2 = Vector2.ONE * king_wall_skull_size * scale_val
				draw_texture_rect(tex, Rect2(center - size * 0.5, size), false, Color(0.96, 0.56, 1.0, alpha))
			coord += king_wall_skull_size * 0.86
		# Bright paired edges distinguish the intentionally safe corridor.
		for edge: float in [-1.0, 1.0]:
			var bound: float = wall.safe_center + edge * king_wall_safe_gap * 0.5
			var edge_world: Vector2 = Vector2(axis, bound) if wall.from_side else Vector2(bound, axis)
			draw_circle(to_local(edge_world), 5.0, Color(1.0, 0.88, 1.0, alpha))

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


func _king_elites_alive_count() -> int:
	var count: int = 0
	for guard: CharacterBody2D in king_elite_guards:
		if not is_instance_valid(guard) or guard.is_queued_for_deletion():
			continue
		if guard.has_method(&"is_dead") and bool(guard.call(&"is_dead")):
			continue
		if guard.get(&"dead") == true:
			continue
		count += 1
	return count


func _king_elite_is_alive() -> bool:
	return _king_elites_alive_count() > 0


func _try_spawn_king_elite() -> bool:
	if king_elite_waves_spawned >= king_elite_total_waves:
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
	# Keep the two guards on opposite sides when the arena permits.
	var preferred_side: float = -1.0 if king_elite_waves_spawned == 0 else 1.0
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
		if offset * preferred_side < 0.0:
			score += 180.0
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
	# Stable combat personalities: first pursues, second flanks/backpedals.
	elite.set_meta(&"king_guard_index", king_elite_waves_spawned)
	# V10: first summons are NORMAL 25-HP Menacing Skeletons, untinted.
	# Keep only the enlarged activation radius and independent patrol roles.
	elite.set("max_hp", maxi(1, king_normal_guard_hp))
	elite.set("activation_radius", 900.0)
	elite.set("attack_warning_seconds", 1.08)
	elite.set("point_blank_warning_seconds", 1.20)
	elite.set("lunge_warning_seconds", 1.14)
	elite.set("jump_slam_warning_seconds", 1.10)
	elite.set("advancing_slam_warning_seconds", 1.15)
	elite.set("tactical_retreat_chance", 0.22 if king_elite_waves_spawned == 0 else 0.50)
	elite.set_meta(&"king_guard_buffed", false)
	elite.set("debug_grant_all_artifact_buffs_on_engage", false)
	var rect: RectangleShape2D = collider.shape as RectangleShape2D
	var feet: float = collider.position.y + rect.size.y * 0.5 * absf(collider.scale.y)
	var spawn_world: Vector2 = target.global_position + Vector2(130.0 * preferred_side, -100.0)
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
	# The Menacing queues itself for deletion after its death animation.
	# Capture the actual death position while the node still exists, so the
	# King can perform a real-looking resurrection at the fallen guard's spot.
	if elite.has_signal(&"died"):
		elite.connect(&"died", Callable(self, &"_on_king_guard_died").bind(elite))
	add_collision_exception_with(elite)
	elite.add_collision_exception_with(self)
	king_elite = elite
	king_elite_guards.append(elite)
	king_elite_waves_spawned += 1
	king_elite_timer = maxf(5.0, king_elite_resummon_delay)
	king_exposure_timer = 0.0
	print("GRAVE MONARCH V9.7: shield guard ", king_elite_waves_spawned, "/2 summoned")
	return true


func _update_king_elite_reinforcements(delta: float) -> void:
	# The shield does not shatter until both individual guards have died.
	if not is_king or king_shield_phase != KingShieldPhase.SHIELDED:
		return
	if king_elite_waves_spawned >= king_elite_total_waves:
		king_shield_elite_spawned = true
		if not _king_elite_is_alive():
			_begin_king_shield_break()
		return
	king_shield_spawn_retry = maxf(0.0, king_shield_spawn_retry - delta)
	if king_shield_spawn_retry <= 0.0:
		# Summon exactly TWO guards, without an 11-second resummon delay.
		while king_elite_waves_spawned < king_elite_total_waves:
			if not _try_spawn_king_elite():
				king_shield_spawn_retry = 1.8
				break
		if king_elite_waves_spawned >= king_elite_total_waves:
			king_shield_elite_spawned = true
		_update_king_hp_label()

func _on_king_guard_died(guard: CharacterBody2D) -> void:
	if not is_instance_valid(guard):
		return
	# All royal minions stay at their actual death position. A revived
	# purple guard can become a corpse and be resurrected again later.
	king_dead_guard_position = guard.global_position
	king_dead_guard_position_known = true
	print("GRAVE MONARCH: royal guard fell at ", king_dead_guard_position)


func _king_active_purple_count() -> int:
	var count: int = 0
	for guard: CharacterBody2D in king_elite_guards:
		if not is_instance_valid(guard) or guard.is_queued_for_deletion():
			continue
		if bool(guard.get_meta(&"king_royal_reviving", false)):
			count += 1
		elif bool(guard.get_meta(&"king_reborn_elite", false)) and guard.has_method(&"is_dead") and not bool(guard.call(&"is_dead")):
			count += 1
	return count

func _begin_king_elite_revive() -> bool:
	# Remote resurrection: the King NEVER lands or interrupts his spells.
	if king_shield_phase != KingShieldPhase.EXPOSED or king_total_resurrections >= king_max_total_resurrections:
		return false
	# Hard gameplay cap: only ONE revived purple Menacing can be active,
	# regardless of an older kingnecro.tscn Inspector override.
	if _king_active_purple_count() > 0:
		return false
	var best_guard: CharacterBody2D = null
	var best_score: float = INF
	for guard: CharacterBody2D in king_elite_guards:
		if not is_instance_valid(guard) or guard.is_queued_for_deletion():
			continue
		if not guard.has_method(&"can_be_royally_revived") or not bool(guard.call(&"can_be_royally_revived")):
			continue
		# Alternate corpses where possible to keep two different fighters.
		var used_count: int = int(guard.get_meta(&"king_royal_revive_count", 0))
		var repeated_penalty: float = 250.0 if guard.get_instance_id() == king_last_revived_id else 0.0
		var score: float = float(used_count) * 800.0 + repeated_penalty
		if is_instance_valid(target):
			score += guard.global_position.distance_to(target.global_position) * 0.12
		if score < best_score:
			best_score = score
			best_guard = guard
	if best_guard == null:
		return false
	# Finish any ongoing spell/projectile BEFORE the resurrection begins.
	# This prevents a queued volley or a fading slash from hitting the player
	# during the solo purple-guard encounter.
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	_clear_king_gravefall()
	king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
	if not bool(best_guard.call(&"begin_royal_resurrection", king_reborn_guard_hp)):
		return false
	king_last_revived_id = best_guard.get_instance_id()
	king_total_resurrections += 1
	king_revival_started = true
	king_revival_completed = true
	king_reborn_guard = best_guard
	if not king_reborn_guards.has(best_guard):
		king_reborn_guards.append(best_guard)
	# Keep the King's authored resurrection/summoning animation alive for
	# the entire ghost + hold + reverse-death sequence of THIS guard.
	king_revival_cast_total = (
		float(best_guard.get("royal_revive_ghost_seconds"))
		+ float(best_guard.get("royal_revive_hold_seconds"))
		+ float(best_guard.get("royal_revive_reverse_seconds"))
	)
	king_revival_cast_fx = maxf(0.5, king_revival_cast_total)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(REVIVE_ANIMATION):
		_play(REVIVE_ANIMATION, true)
	# The cooldown is measured AFTER the revived guard is defeated, not
	# simultaneously with the time that guard is alive.
	king_revival_timer = maxf(6.0, king_repeat_revival_delay)
	king_guard_attack_timer = maxf(3.0, king_reborn_boss_spell_interval)
	print("GRAVE MONARCH V11: REMOTE RESURRECTION ", king_total_resurrections,
		"/", king_max_total_resurrections, " at ", best_guard.global_position)
	_update_king_hp_label()
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


func _begin_king_shield_phase() -> void:
	if king_shield_phase != KingShieldPhase.SOLO:
		return
	king_shield_phase = KingShieldPhase.SHIELDED
	king_shield_elite_spawned = false
	king_shield_spawn_retry = 0.0
	king_shield_hit_fx = king_shield_hit_pulse_duration
	king_elite_waves_spawned = 0
	king_elite_total_waves = 2
	king_elite_guards.clear()
	king_guard_attack_timer = maxf(7.0, king_guard_attack_interval)
	king_black_flash_timer = 0.0
	# Remove old projectiles, giving the player time to see the shield arrive.
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	king_skull_walls.clear()
	king_wall_spawn_remaining = 0
	_clear_king_gravefall()
	_update_king_hp_label()
	queue_redraw()
	print("GRAVE MONARCH V9.7: SHIELD PHASE, SUMMON TWO ROYAL MENACING GUARDS")


func _begin_king_shield_break() -> void:
	if king_shield_phase != KingShieldPhase.SHIELDED:
		return
	if king_elite_waves_spawned < king_elite_total_waves or _king_elite_is_alive():
		return
	king_shield_phase = KingShieldPhase.BREAKING
	king_shield_break_fx = maxf(0.2, king_shield_break_duration)
	king_shield_hit_fx = 0.0
	# Freeze spells ONLY while the shield shatters. Afterwards the King
	# resumes all his normal Radiance patterns and CAN be hit continuously.
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	king_skull_walls.clear()
	king_wall_spawn_remaining = 0
	_clear_king_gravefall()
	velocity = Vector2.ZERO
	state = State.GUARDED
	king_revival_timer = maxf(3.0, king_revival_after_shield_seconds)
	king_exposed_spells_since_break = 0
	king_gravefall_cooldown_timer = 0.10
	# Skull volleys are too long and turn the post-shield duel into dead air.
	# The exposed phase will use real slash patterns until the first revival.
	king_skull_volley_timer = maxf(24.0, king_skull_volley_timer)
	king_solo_hover_anchor_set = false
	_play(&"idle", true)
	_update_king_hp_label()
	queue_redraw()
	print("GRAVE MONARCH V10: SHIELD SHATTERING; FULL MAGIC RETURNS AFTER BREAK")


func _update_king_revival_cast_pose() -> void:
	# The King must visibly CAST while the skeleton is being resurrected.
	# Loop the authored spawnenemies2 channel frames 4-7. The animation
	# is driven by elapsed cast time, not by a SpriteFrames looping flag.
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(REVIVE_ANIMATION):
		return
	if king_revival_cast_fx <= 0.0:
		return
	var frame_total: int = sprite.sprite_frames.get_frame_count(REVIVE_ANIMATION)
	if frame_total <= 0:
		return
	var first_loop: int = mini(REVIVE_LOOP_FIRST, frame_total - 1)
	var last_loop: int = mini(REVIVE_LOOP_LAST, frame_total - 1)
	var fps: float = maxf(1.0, sprite.sprite_frames.get_animation_speed(REVIVE_ANIMATION))
	var elapsed: float = maxf(0.0, king_revival_cast_total - king_revival_cast_fx)
	var animation_frame: int = maxi(0, int(floor(elapsed * fps)))
	if animation_frame > last_loop:
		animation_frame = first_loop + (animation_frame - first_loop) % (last_loop - first_loop + 1)
	sprite.animation = REVIVE_ANIMATION
	sprite.stop()
	sprite.set_frame_and_progress(animation_frame, 0.0)


func _begin_king_last_stand() -> void:
	# One-time phase after defeating the FIRST revived purple Menacing.
	# Prevents a 1-HP king from dying immediately when the guard falls.
	if king_last_stand_started or king_shield_phase != KingShieldPhase.EXPOSED:
		return
	king_last_stand_started = true
	king_last_stand_intro_timer = king_last_stand_intro_seconds
	king_revival_cast_fx = 0.0
	king_revival_cast_total = 0.0
	hp = maxi(hp, int(ceil(float(max_hp) * king_last_stand_heal_ratio)))
	sprite_tint = Color(1.0, 0.47, 0.98, 1.0)
	# Clear all leftover projectiles; the player can read the phase change.
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	_clear_king_gravefall()
	king_post_attack_timer = maxf(king_post_attack_timer, king_last_stand_intro_seconds)
	king_gravefall_cooldown_timer = maxf(king_gravefall_cooldown_timer, 1.4)
	king_skull_volley_timer = maxf(king_skull_volley_timer, 19.0) # Slashes first, skulls much later.
	_play(&"idle", true)
	health_changed.emit(hp, max_hp)
	_update_king_hp_label()
	queue_redraw()
	print("GRAVE MONARCH V13: LAST STAND begins! HP ", hp, "/", max_hp)


func _update_king_phase_visuals(delta: float) -> void:
	king_shield_animation_time += delta
	king_ward_repel_timer = maxf(0.0, king_ward_repel_timer - delta)
	if king_shield_phase == KingShieldPhase.SOLO and king_shield_countdown >= 0.0:
		king_shield_countdown -= delta
		if king_shield_countdown <= 0.0:
			king_shield_countdown = -1.0
			_begin_king_shield_phase()
	king_black_flash_timer = maxf(0.0, king_black_flash_timer - delta)
	king_shield_hit_fx = maxf(0.0, king_shield_hit_fx - delta)
	if king_shield_phase == KingShieldPhase.BREAKING:
		king_shield_break_fx = maxf(0.0, king_shield_break_fx - delta)
		if king_shield_break_fx <= 0.0:
			king_shield_phase = KingShieldPhase.EXPOSED
			king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
			king_guard_attack_timer = maxf(5.0, king_reborn_boss_spell_interval)
			_update_king_hp_label()
	# Revival animation is as long as the skeleton's actual resurrection.
	var was_revival_casting: bool = king_revival_cast_fx > 0.0
	king_revival_cast_fx = maxf(0.0, king_revival_cast_fx - delta)
	if king_revival_cast_fx > 0.0:
		_update_king_revival_cast_pose()
	elif was_revival_casting:
		_play(&"idle", true)
	king_last_stand_intro_timer = maxf(0.0, king_last_stand_intro_timer - delta)
	# V12 revival rhythm: cooldown stops through the purple guard's fight.
	if king_shield_phase == KingShieldPhase.EXPOSED:
		var purple_present: bool = _king_active_purple_count() > 0
		if purple_present:
			king_was_purple_guard_active = true
		elif king_was_purple_guard_active:
			king_was_purple_guard_active = false
			# First purple victory triggers a separate King final combat phase.
			_begin_king_last_stand()
			king_revival_timer = maxf(king_revival_timer, king_repeat_revival_delay)
			king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
			king_gravefall_cooldown_timer = maxf(king_gravefall_cooldown_timer, king_post_attack_pause)
		if (not purple_present
			and king_total_resurrections < king_max_total_resurrections
			and king_exposed_spells_since_break >= maxi(5, king_exposed_spells_before_revival)):
			# Finish a meaningful stretch of Radiance-style fighting before revival.
			king_revival_timer -= delta
			king_revival_attempt_cooldown = maxf(0.0, king_revival_attempt_cooldown - delta)
			if king_revival_timer <= 0.0 and king_revival_attempt_cooldown <= 0.0:
				if not _begin_king_elite_revive():
					king_revival_attempt_cooldown = 0.75
	if is_instance_valid(sprite):
		var hit_black: bool = king_black_flash_timer > 0.0
		sprite.self_modulate = Color.BLACK if hit_black else sprite_tint
		sprite.modulate = Color.BLACK if hit_black else Color.WHITE


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# The HUD is never gated by the player's existence or a previous death.
	if is_king:
		if not is_instance_valid(king_hud):
			_create_king_boss_hud()
		_update_king_hp_label()
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
	king_post_attack_timer = maxf(0.0, king_post_attack_timer - delta)
	_update_king_phase_visuals(delta)
	if king_shield_phase == KingShieldPhase.BREAKING:
		# Pause only for the animated shield shatter.
		velocity = Vector2.ZERO
		_play(&"idle")
		_update_king_crown(delta)
		queue_redraw()
		return
	_update_skulls(delta)
	if is_king:
		_update_king_royal_slashes(delta)
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
		if not is_instance_valid(king_hud):
			_create_king_boss_hud()
		_update_king_hp_label()
	if state != State.DORMANT:
		# The King's ONLY phase-1 hit animation is a fast black flash.
		var hit_black: bool = king_black_flash_timer > 0.0
		sprite.self_modulate = Color.BLACK if hit_black else sprite_tint
		sprite.modulate = Color.BLACK if hit_black else Color.WHITE
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
		king_elite_timer = 0.0 # No guard during phase one.
		king_shield_countdown = clampf(king_shield_appear_delay, 5.0, 15.0)
		_create_king_boss_hud()
		_update_king_hp_label()
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
		if king_shield_phase == KingShieldPhase.BREAKING:
			velocity = Vector2.ZERO
			return
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
	if not is_king:
		_fly_toward(home, hover_speed, delta)
		return
	if (king_shield_phase == KingShieldPhase.SHIELDED
		or _king_active_purple_count() > 0 or king_revival_cast_fx > 0.0):
		_update_king_guard_standoff(delta)
		return
	king_guard_standoff_active = false
	king_guard_flight_velocity = Vector2.ZERO
	var view: Rect2 = _king_visible_world_rect()
	if view.size.x < 20.0 or view.size.y < 20.0:
		return
	# Solo: hovering is high, but low enough that the player's sword can
	# still reach the boss using arena platforms. No following player X/Y.
	if (not king_solo_hover_anchor_set
		or king_solo_hover_anchor.x < view.position.x - 90.0
		or king_solo_hover_anchor.x > view.end.x + 90.0):
		king_solo_hover_anchor_set = true
		var side: float = 1.0 if target.global_position.x < view.get_center().x else -1.0
		king_solo_hover_anchor = Vector2(
			view.position.x + view.size.x * (0.73 if side > 0.0 else 0.27),
			view.position.y + view.size.y * 0.49 - _king_visible_bottom_offset()
		)
	hover_time += delta
	var goal: Vector2 = king_solo_hover_anchor + Vector2(
		sin(hover_time * 0.47) * 7.0,
		sin(hover_time * 0.63) * 8.0
	)
	_fly_toward(goal, hover_speed * 1.30, delta)
	hover_center_x = global_position.x


func _update_king_guard_standoff(delta: float) -> void:
	# The KING and his huge sprite must be visually far away from the active
	# Menacing's melee lane. V22 put the ROOT at the top but left the sprite
	# hanging into the floor fight. This positions the visible bottom instead.
	var view: Rect2 = _king_visible_world_rect()
	if view.size.x <= 20.0 or view.size.y <= 20.0:
		return
	king_guard_retarget_timer = maxf(0.0, king_guard_retarget_timer - delta)
	var half_art_width: float = _king_visual_half_width()
	var outer_margin: float = minf(46.0, half_art_width * 0.22)
	var left_x: float = view.position.x + outer_margin
	var right_x: float = view.end.x - outer_margin
	# King's visible FEET stay in the top ~20% of the camera while guards
	# fight below. Part of the boss remains visible along the far side.
	var safe_visual_bottom: float = (
		view.position.y + clampf(view.size.y * 0.19, 96.0, 138.0)
	)
	var high_root_y: float = safe_visual_bottom - _king_visible_bottom_offset()
	var need_anchor: bool = not king_guard_standoff_active
	var chased: bool = false
	if king_guard_standoff_active and king_guard_retarget_timer <= 0.0:
		# Change sides only if the player really climbs toward the king.
		chased = is_instance_valid(target) and (
			sprite.global_position.distance_to(target.global_position) < 150.0
		)
		var camera_moved_far: bool = (
			king_guard_standoff_anchor.x < view.position.x - half_art_width
			or king_guard_standoff_anchor.x > view.end.x + half_art_width
		)
		need_anchor = chased or camera_moved_far
	if need_anchor:
		var was_anchored: bool = king_guard_standoff_active
		king_guard_standoff_active = true
		if chased and was_anchored and king_guard_standoff_side != 0.0:
			king_guard_standoff_side = -king_guard_standoff_side
		elif not was_anchored or king_guard_standoff_side == 0.0:
			king_guard_standoff_side = (
				1.0 if target.global_position.x < view.get_center().x else -1.0
			)
		king_guard_standoff_anchor = Vector2(
			right_x if king_guard_standoff_side > 0.0 else left_x,
			high_root_y
		)
		king_guard_retarget_timer = maxf(3.0, king_guard_retarget_cooldown)
	else:
		# Don't track the player's jump/camera Y every frame. Only adjust
		# the long-lived anchor when the camera has genuinely changed floors.
		if absf(king_guard_standoff_anchor.y - high_root_y) > view.size.y * 0.24:
			king_guard_standoff_anchor.y = high_root_y
	hover_time += delta
	var goal: Vector2 = king_guard_standoff_anchor + Vector2(
		0.0, sin(hover_time * 0.62) * 4.0
	)
	var offset: Vector2 = goal - global_position
	# Immediately prioritise rising away from a skeleton when entering this
	# phase, but interpolate velocity rather than teleport or snap.
	var flight_speed: float = king_guard_retreat_speed
	if global_position.y > high_root_y + 95.0:
		flight_speed = maxf(flight_speed, 455.0)
	var desired_velocity: Vector2 = Vector2.ZERO
	if offset.length_squared() > 0.01:
		desired_velocity = offset.normalized() * minf(flight_speed, offset.length() * 3.6)
	king_guard_flight_velocity = king_guard_flight_velocity.move_toward(
		desired_velocity, maxf(king_guard_flight_acceleration, 720.0) * delta
	)
	global_position += king_guard_flight_velocity * delta
	velocity = Vector2.ZERO
	hover_center_x = global_position.x


func _update_barrage(delta: float) -> void:
	if is_king and (king_shield_phase in [KingShieldPhase.SHIELDED, KingShieldPhase.BREAKING]
		or _king_active_purple_count() > 0 or king_last_stand_intro_timer > 0.0
		or (king_shield_phase == KingShieldPhase.EXPOSED and king_total_resurrections == 0)):
		# The King does not fire skulls while a purple guard is reanimating
		# or attacking the player.
		return
	if is_king:
		# Slow, infrequent skull volleys. Last Stand is slash-focused;
		# never mix these volleys with an active Royal Slash pattern.
		if king_skull_spawns_remaining <= 0:
			king_skull_volley_timer -= delta
			if (king_skull_volley_timer <= 0.0
				and king_post_attack_timer <= 0.0
				and not king_gravefall_active
				and king_royal_slashes.is_empty()):
				king_skull_spawns_remaining = 3 if king_last_stand_started else 4
				king_skull_interval_timer = 0.0
				king_skull_volley_timer = (
					maxf(27.0, king_last_stand_skull_volley_cooldown)
					if king_last_stand_started
					else maxf(20.0, king_skull_volley_cooldown)
				)
		if king_skull_spawns_remaining > 0:
			king_skull_interval_timer -= delta
			if king_skull_interval_timer <= 0.0:
				_spawn_king_spectral_skull()
				king_skull_spawns_remaining -= 1
				if king_skull_spawns_remaining == 0:
					king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
				# 1.35s minimum, even if Level 5's Inspector serialized 0.85s.
				king_skull_interval_timer = maxf(1.35, king_skull_spawn_interval)
		return
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
	# King's reanimation is remote, keeping him above the guards.
	# Ground descent is only for legacy non-King NPC logic.
	if is_king:
		state = State.GUARDED
		return
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
	# The King never enters this legacy ground-revival state. Ordinary
	# skeleton revival is retained for non-King compatibility only.
	if not is_king:
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
	revive_preview.modulate = Color(0.68, 0.26, 1.0, 0.0)
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
	visual.scale = Vector2.ONE * ((maxf(60.0, king_spectral_skull_size) if is_king else 18.0) / maxf(texture_size.x, texture_size.y))
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


func _spawn_king_spectral_skull() -> void:
	if king_shield_phase == KingShieldPhase.BREAKING:
		return
	if not is_king or not is_instance_valid(target):
		return
	var view: Rect2 = _king_visible_world_rect()
	var skull := Skull.new()
	var visual := Sprite2D.new()
	visual.texture = SKULL_TEXTURE
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.modulate = Color(0.82, 0.34, 1.0, 0.0)
	visual.top_level = true
	var texture_size: Vector2 = SKULL_TEXTURE.get_size()
	# Minimum size overrides older Level 5 Inspector values (formerly 44px).
	var size_multiplier: float = maxf(60.0, king_spectral_skull_size) / maxf(texture_size.x, texture_size.y)
	skull.base_scale = Vector2.ONE * size_multiplier
	visual.scale = skull.base_scale * 0.10
	add_child(visual)
	# Spawn at a meaningful distance from the player. If the camera is too
	# small to fit the requested distance, choose the farthest valid position.
	var safe_view: Rect2 = view.grow(-50.0)
	if safe_view.size.x < 20.0 or safe_view.size.y < 20.0:
		safe_view = view
	var chosen: Vector2 = safe_view.get_center()
	var best_distance: float = -1.0
	for attempt: int in range(28):
		var candidate: Vector2 = Vector2(
			randf_range(safe_view.position.x, safe_view.end.x),
			randf_range(safe_view.position.y, safe_view.end.y)
		)
		var distance: float = candidate.distance_to(target.global_position)
		if distance > best_distance:
			best_distance = distance
			chosen = candidate
		if (distance >= king_skull_min_spawn_distance
			and candidate.distance_to(global_position) >= 105.0):
			chosen = candidate
			break
	visual.global_position = chosen
	skull.direction = chosen.direction_to(target.global_position)
	skull.visual = visual
	skull.spectral = true
	skull.speed = king_skull_flight_speed
	skull.damage = skull_damage
	skull.lifetime = maxf(4.2, king_skull_charge_duration + king_skull_terrain_phase_time + 1.7)
	skull.orbit_sign = -1.0 if randf() < 0.5 else 1.0
	skull.wobble_seed = randf_range(0.0, TAU)
	skulls.append(skull)


func _update_skulls(delta: float) -> void:
	if skulls.is_empty() or not is_instance_valid(target):
		return
	var excluded: Array[RID] = _excluded_bodies()
	excluded.erase(target.get_rid())
	for index: int in range(skulls.size() - 1, -1, -1):
		var skull: Skull = skulls[index]
		if not is_instance_valid(skull.visual):
			skulls.remove_at(index)
			continue
		if skull.spectral and skull.charge_elapsed < king_skull_charge_duration:
			# Appear stationary, growing and fading in over precisely half a second.
			skull.charge_elapsed = minf(king_skull_charge_duration, skull.charge_elapsed + delta)
			var t: float = clampf(skull.charge_elapsed / maxf(0.01, king_skull_charge_duration), 0.0, 1.0)
			var eased: float = t * t * (3.0 - 2.0 * t)
			skull.visual.scale = skull.base_scale * lerpf(0.10, 1.0, eased)
			skull.visual.modulate.a = eased
			# Keep the launch direction telegraphed during the charge. The skull
			# won't snap its facing to the player's newest position every frame.
			skull.visual.rotation = skull.direction.angle() + PI
			continue
		var start: Vector2 = skull.visual.global_position
		if skull.spectral:
			skull.flight_elapsed += delta
			# First fly straight, then smoothly ramp the homing strength up.
			# This makes a jump or direction change effective without eliminating
			# the circling/curved pursuit during the rest of the flight.
			var tracking_age: float = skull.flight_elapsed - king_skull_tracking_delay
			if tracking_age > 0.0:
				var tracking_factor: float = clampf(
					tracking_age / maxf(0.05, king_skull_tracking_ramp), 0.0, 1.0
				)
				var orbit_phase: float = skull.flight_elapsed * 1.6 + skull.wobble_seed
				var distance_to_player: float = start.distance_to(target.global_position)
				var orbit_strength: float = clampf(
					(distance_to_player - 45.0) / 210.0, 0.0, 1.0
				)
				var sideways: Vector2 = Vector2(-skull.direction.y, skull.direction.x)
				var orbit_offset: float = sin(orbit_phase) * 32.0 * skull.orbit_sign * orbit_strength
				var desired_point: Vector2 = target.global_position + sideways * orbit_offset
				var desired: Vector2 = start.direction_to(desired_point)
				if desired.length_squared() > 0.001:
					var angle_delta: float = angle_difference(skull.direction.angle(), desired.angle())
					var turn_limit: float = king_skull_turn_rate * tracking_factor * delta
					skull.direction = skull.direction.rotated(clampf(
						angle_delta, -turn_limit, turn_limit
					)).normalized()
			skull.visual.rotation = skull.direction.angle() + PI
		var finish: Vector2 = start + skull.direction * skull.speed * delta
		# For the first 2s after launch: passes through walls/floors.
		# Afterward: the terrain becomes solid and destroys it on contact.
		var collision_bits: int = target.collision_layer
		if not skull.spectral or skull.flight_elapsed >= king_skull_terrain_phase_time:
			collision_bits |= terrain_mask
		var query := PhysicsRayQueryParameters2D.create(start, finish, collision_bits, excluded)
		query.hit_from_inside = true
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
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


func _king_purple_hp_floor() -> int:
	return maxi(1, int(ceil(float(max_hp) * 0.01)))


func _king_purple_ward_active() -> bool:
	return (king_shield_phase == KingShieldPhase.EXPOSED
		and _king_active_purple_count() > 0
		and hp <= _king_purple_hp_floor())


func _king_repel_player_from_ward() -> void:
	# Triggered by a genuine player sword hit, not simply by being nearby.
	# Push with the player's own CharacterBody2D collision, so we won't
	# teleport them into a wall or through a floor. No health damage.
	if king_ward_repel_timer > 0.0 or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > 135.0:
		return
	king_ward_repel_timer = maxf(0.4, king_ward_repel_cooldown)
	var side: float = signf(target.global_position.x - global_position.x)
	if absf(side) < 0.01:
		side = 1.0
	target.move_and_collide(Vector2(side * king_ward_repel_distance, -34.0))
	target.velocity.y = minf(target.velocity.y, -155.0)
	king_shield_hit_fx = maxf(king_shield_hit_fx, king_shield_hit_pulse_duration)
	queue_redraw()


func can_receive_player_hit() -> bool:
	# King can be hurt throughout the encounter, including while hovering.
	# A first legitimate sword hit can also wake a dormant King. Before this,
	# a visually connecting strike was silently ignored until activation.
	return state != State.DEAD


func is_reviving() -> bool:
	return state == State.REVIVING


func is_dead() -> bool:
	return state == State.DEAD


func attack_shape_hits_hurtbox(attack_shape: CollisionShape2D) -> bool:
	if not can_receive_player_hit() or not is_instance_valid(attack_shape):
		return false
	if attack_shape.disabled or attack_shape.shape == null or not is_instance_valid(sprite):
		return false
	# The King intentionally phases through terrain, so his physics movement
	# collision mask cannot also be his weapon hurtbox. Use the visual body.
	var texture: Texture2D = null
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
		if count > 0:
			texture = sprite.sprite_frames.get_frame_texture(sprite.animation, clampi(sprite.frame, 0, count - 1))
	var local_size: Vector2 = texture.get_size() if texture != null else Vector2(28.0, 40.0)
	var actual_scale: Vector2 = sprite.global_transform.get_scale().abs()
	var body := RectangleShape2D.new()
	body.size = Vector2(maxf(44.0, local_size.x * actual_scale.x * 0.59),
		maxf(58.0, local_size.y * actual_scale.y * 0.70))
	var center: Vector2 = sprite.global_position + Vector2(0.0, -body.size.y * 0.05)
	return attack_shape.shape.collide(attack_shape.global_transform, body,
		Transform2D(0.0, center))


func take_damage(amount: int, origin: Vector2 = Vector2.ZERO) -> void:
	tomar_dano(amount, origin)


func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or not can_receive_player_hit():
		return
	if state == State.DORMANT:
		_begin_encounter()
	match king_shield_phase:
		KingShieldPhase.SOLO:
			# Ordinary damage, no hurt animation or stagger. Blink BLACK only.
			var old_hp: int = hp
			hp = maxi(1, hp - amount)
			king_black_flash_timer = maxf(0.22, king_black_hit_flash_duration)
			sprite.self_modulate = Color.BLACK
			sprite.modulate = Color.BLACK
			print("KING NECROMANCER HIT: -", old_hp - hp, " HP | ", hp, "/", max_hp)
			health_changed.emit(hp, max_hp)
			# The shield is TIME-triggered, not HP-triggered.
			# Leave 1 HP until the guards are defeated so the finale remains playable.
			_update_king_hp_label()
		KingShieldPhase.SHIELDED:
			# The elite protects the King. Attacks ripple on the shield only.
			king_shield_hit_fx = maxf(0.1, king_shield_hit_pulse_duration)
			# Shield breaks automatically when BOTH guards die, without needing a hit.
			if king_shield_elite_spawned and not _king_elite_is_alive():
				_begin_king_shield_break()
		KingShieldPhase.BREAKING:
			# The shield is visibly shattering; damage resumes afterward.
			pass
		KingShieldPhase.EXPOSED:
			# During Last Stand intro the King has a brief transformation window.
			if king_last_stand_intro_timer > 0.0:
				return
			var purple_alive: bool = _king_active_purple_count() > 0
			var hp_floor: int = (_king_purple_hp_floor() if purple_alive
				else (0 if king_last_stand_started else 1))
			if purple_alive and hp <= hp_floor:
				# One-percent last-chance ward: no damage while the purple guard lives.
				king_shield_hit_fx = maxf(0.1, king_shield_hit_pulse_duration)
				_king_repel_player_from_ward()
				_update_king_hp_label()
				return
			var old_hp_exposed: int = hp
			hp = maxi(hp_floor, hp - amount)
			king_black_flash_timer = maxf(0.22, king_black_hit_flash_duration)
			sprite.self_modulate = Color.BLACK
			sprite.modulate = Color.BLACK
			print("KING NECROMANCER HIT (EXPOSED): -", old_hp_exposed - hp, " HP | ", hp, "/", max_hp)
			health_changed.emit(hp, max_hp)
			if purple_alive and hp <= hp_floor:
				_king_repel_player_from_ward()
			_update_king_hp_label()
			if hp <= 0:
				_die_king_v9()
	queue_redraw()


func _exit_tree() -> void:
	# CanvasLayer is parented to SceneTree.root, so explicitly dispose it
	# when the level is reloaded; otherwise old HUDs can cover the new one.
	if is_instance_valid(king_hud):
		king_hud.queue_free()


func _die_king_v9() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_clear_king_gravefall()
	king_royal_slashes.clear()
	king_skull_walls.clear()
	_clear_revive_preview()
	if is_instance_valid(king_hp_label):
		king_hp_label.queue_free()
	if is_instance_valid(king_hud):
		king_hud.queue_free()
	if is_instance_valid(king_crown_root):
		king_crown_root.queue_free()
	# A royal summon cannot continue attacking after its monarch dies.
	for royal_guard: CharacterBody2D in king_elite_guards:
		if is_instance_valid(royal_guard) and not royal_guard.is_queued_for_deletion():
			royal_guard.queue_free()
	velocity = Vector2.ZERO
	_clear_skulls()
	collision_layer = 0
	collision_mask = 0
	died.emit()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		_play(&"death", true)
		var frames: int = sprite.sprite_frames.get_frame_count(&"death")
		var fps: float = maxf(1.0, sprite.sprite_frames.get_animation_speed(&"death"))
		get_tree().create_timer(maxf(0.2, float(frames) / fps)).timeout.connect(queue_free)
	else:
		queue_free()

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
		# Ambient aura is a subtle fill, never a permanent WARNING ring.
		draw_circle(center, 72.0 + 4.0 * pulse, Color(0.45, 0.08, 0.80, 0.055))
		if king_gravefall_active and king_special_kind == 3:
			var progress: float = clampf(1.0 - king_gravefall_warning_timer / 0.72, 0.0, 1.0)
			var alpha: float = clampf(progress / 0.30, 0.0, 1.0) * (0.48 + 0.42 * progress)
			draw_arc(center, 130.0 - 25.0 * progress, 0.0, TAU, 60,
				Color(1.0, 0.33, 0.89, alpha), 8.0, true)
			for ray_index: int in range(7):
				var angle: float = TAU * float(ray_index) / 7.0
				var ray: Vector2 = Vector2.RIGHT.rotated(angle)
				draw_line(center + ray * 35.0, center + ray * 123.0,
					Color(0.90, 0.39, 1.0, alpha), 3.0, true)
		if king_crown_burst_remaining > 0.0:
			var b: float = 1.0 - king_crown_burst_remaining / 0.34
			var radius: float = (125.0 + 75.0 * b) if b < 0.25 else (145.0 - 50.0 * (b - 0.25) / 0.75)
			draw_arc(center, radius, 0.0, TAU, 60,
				Color(0.97, 0.72, 1.0, pow(1.0 - b, 1.25)), maxf(0.5, 18.0 * (1.0 - b)), true)
		# V9.7 shield appears 10 seconds after encounter start; both normal and
		# breaking-state animation are drawn without new textures or nodes.
		var shield_origin: Vector2 = body_shape.position
		if king_shield_phase == KingShieldPhase.SHIELDED:
			var wave: float = 0.5 + 0.5 * sin(king_shield_animation_time * 4.6)
			var shield_impact_pulse: float = king_shield_hit_fx / maxf(0.01, king_shield_hit_pulse_duration)
			var radius: float = 83.0 + 5.0 * wave + 12.0 * shield_impact_pulse
			draw_circle(shield_origin, radius, Color(0.22, 0.06, 0.62, 0.12 + 0.13 * shield_impact_pulse))
			draw_arc(shield_origin, radius, 0.0, TAU, 72,
				Color(0.78, 0.53, 1.0, 0.76 + 0.23 * shield_impact_pulse), 6.0 + shield_impact_pulse * 8.0, true)
			draw_arc(shield_origin, radius - 11.0, 0.0, TAU, 64,
				Color(0.95, 0.80, 1.0, 0.45 + 0.40 * shield_impact_pulse), 2.0, true)
			for rune_i: int in range(8):
				var angle: float = float(rune_i) * TAU / 8.0 + king_shield_animation_time * 0.45
				var mark: Vector2 = shield_origin + Vector2.RIGHT.rotated(angle) * radius
				draw_circle(mark, 4.0 + shield_impact_pulse * 2.0, Color(0.90, 0.69, 1.0, 0.85))
		elif king_shield_phase == KingShieldPhase.BREAKING:
			var t: float = 1.0 - king_shield_break_fx / maxf(0.01, king_shield_break_duration)
			var alpha: float = maxf(0.0, 1.0 - t)
			for piece_i: int in range(18):
				var angle: float = TAU * float(piece_i) / 18.0
				var tangent: Vector2 = Vector2.RIGHT.rotated(angle)
				var middle: Vector2 = shield_origin + tangent * (85.0 + 70.0 * t)
				draw_line(middle - tangent.rotated(PI / 2.0) * (13.0 - t * 10.0),
					middle + tangent.rotated(PI / 2.0) * (13.0 - t * 10.0),
					Color(0.93, 0.74, 1.0, alpha), maxf(0.6, 7.0 * alpha), true)
		elif _king_purple_ward_active():
			# Only visible at the final 1% HP while a purple Menacing guards him.
			var ward_pulse: float = 0.5 + 0.5 * sin(king_shield_animation_time * 6.0)
			var ward_hit: float = king_shield_hit_fx / maxf(0.01, king_shield_hit_pulse_duration)
			var ward_radius: float = 75.0 + 5.0 * ward_pulse + 10.0 * ward_hit
			draw_circle(shield_origin, ward_radius, Color(0.34, 0.06, 0.56, 0.15))
			draw_arc(shield_origin, ward_radius, 0.0, TAU, 64,
				Color(0.92, 0.52, 1.0, 0.72 + 0.26 * ward_hit), 5.0 + 7.0 * ward_hit, true)
			draw_arc(shield_origin, ward_radius - 8.0, 0.0, TAU, 64,
				Color(0.64, 0.18, 0.95, 0.35 + 0.28 * ward_hit), 2.0, true)
		_draw_king_royal_slashes()
		# A short, non-damaging Last Stand eruption, not a permanent warning.
		if king_last_stand_intro_timer > 0.0:
			var last_stand_progress: float = clampf(
				1.0 - king_last_stand_intro_timer / maxf(0.1, king_last_stand_intro_seconds),
				0.0, 1.0
			)
			var blast_alpha: float = 0.75 * (1.0 - last_stand_progress)
			for last_stand_ray: int in range(12):
				var angle: float = TAU * float(last_stand_ray) / 12.0 + last_stand_progress * 1.5
				var ray: Vector2 = Vector2.RIGHT.rotated(angle)
				draw_line(body_shape.position + ray * 65.0,
					body_shape.position + ray * (100.0 + 150.0 * last_stand_progress),
					Color(1.0, 0.32, 0.96, blast_alpha), 5.0 * (1.0 - last_stand_progress) + 1.0, true)
		if king_revival_cast_fx > 0.0 and is_instance_valid(king_reborn_guard):
			var cast_alpha: float = clampf(king_revival_cast_fx / 1.1, 0.0, 1.0)
			var cast_start: Vector2 = body_shape.position
			var cast_end: Vector2 = to_local(king_reborn_guard.global_position + Vector2(0.0, -16.0))
			draw_line(cast_start, cast_end, Color(0.69, 0.22, 0.93, 0.35 * cast_alpha), 5.0, true)
			draw_line(cast_start, cast_end, Color(0.94, 0.72, 1.0, 0.75 * cast_alpha), 1.5, true)

	if state == State.REVIVING and is_instance_valid(revive_preview):
		var start := body_shape.position
		var finish := to_local(revive_preview.global_position)
		draw_line(start, finish, Color(0.58, 0.16, 0.45, 0.52), 4.0, true)
		draw_line(start, finish, Color(1.0, 0.59, 0.76, 0.85), 1.0, true)
		var flow := _revive_progress() * 12.0
		for index in range(3):
			var point := start.lerp(finish, fposmod(flow + float(index) / 3.0, 1.0))
			draw_circle(point, 2.0, Color(1.0, 0.85, 0.92))
	# No 24/7 circular warning in the neutral GUARDED state.
	if (state == State.GUARDED or state == State.OPENING) and shots_left > 0:
		draw_arc(body_shape.position, 13.0, 0.0, TAU, 24, Color(1.0, 0.23, 0.30, 0.85), 2.0)
