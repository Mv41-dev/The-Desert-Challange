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
const LEVEL6_SKULL_MAX: int = 4
const LEVEL6_SKULL_STAGGER_SECONDS: float = 0.75

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

@export_group("King Necromancer")
@export_range(40, 600, 5) var king_max_hp: int = 340
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
@export_range(0.0, 0.6, 0.01) var king_extra_laser_warning_seconds: float = 0.22

@export_group("King Global Attack Recovery")
@export_range(0.5, 3.0, 0.1) var king_post_attack_pause: float = 1.0

@export_group("King Spectral Skull Volleys")
@export_range(0.8, 2.5, 0.05) var king_skull_spawn_interval: float = 1.35
@export_range(10.0, 40.0, 0.5) var king_skull_volley_cooldown: float = 20.0
@export_range(0.25, 0.8, 0.05) var king_skull_charge_duration: float = 0.50
@export_range(0.5, 4.0, 0.1) var king_skull_terrain_phase_time: float = 1.0
@export_range(0.7, 5.0, 0.1) var king_skull_turn_rate: float = 2.15
@export_range(170.0, 420.0, 10.0) var king_skull_min_spawn_distance: float = 260.0
@export_range(0.0, 0.8, 0.05) var king_skull_tracking_delay: float = 0.30
@export_range(0.1, 1.2, 0.05) var king_skull_tracking_ramp: float = 0.45
@export_range(1.15, 2.5, 0.05) var level6_skull_tracking_delay: float = 1.15
@export_range(0.85, 2.0, 0.05) var level6_skull_tracking_ramp: float = 0.85
@export_range(0.50, 2.20, 0.05) var level6_skull_turn_rate_v48: float = 1.35
@export_range(140.0, 340.0, 10.0) var king_skull_flight_speed: float = 235.0

@export_group("King Skull Walls")
@export_range(0.5, 2.0, 0.05) var king_wall_warning_time: float = 0.9
@export_range(180.0, 550.0, 10.0) var king_wall_speed: float = 340.0
@export_range(70.0, 150.0, 5.0) var king_wall_safe_gap: float = 110.0
@export_range(0.35, 1.25, 0.05) var king_wall_wave_interval: float = 0.85

@export_group("King's Menacing Skeleton Guards")
@export var king_menacing_skeleton_scene: PackedScene
@export var king_elite_total_waves: int = 2
@export_range(15, 80, 5) var king_normal_guard_hp: int = 25
@export_range(45, 130, 5) var king_reborn_guard_hp: int = 70
@export_range(4.0, 20.0, 0.5) var king_revival_after_shield_seconds: float = 7.0
@export_range(3.0, 20.0, 0.5) var king_reborn_boss_spell_interval: float = 5.8
@export_range(1, 8, 1) var king_max_total_resurrections: int = 4
@export_range(1, 3, 1) var king_max_active_purple_guards: int = 1
@export_range(6.0, 30.0, 0.5) var king_repeat_revival_delay: float = 11.5
@export_range(25, 120, 5) var king_elite_hp: int = 55
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
@export_range(0.0, 1.0, 0.05) var king_repeat_revival_chance: float = 0.80
@export_range(3.0, 9.0, 0.25) var king_guard_teleport_interval: float = 5.5
@export_group("King Standoff While Guards Fight")
@export_range(260.0, 650.0, 10.0) var king_guard_standoff_distance: float = 400.0
@export_range(140.0, 600.0, 10.0) var king_guard_retreat_speed: float = 290.0
@export_range(2.0, 8.0, 0.5) var king_guard_retarget_cooldown: float = 4.5
@export_group("King Independent Hover")
@export_range(25.0, 190.0, 5.0) var king_patrol_horizontal_radius: float = 120.0
@export_range(12.0, 100.0, 5.0) var king_patrol_vertical_radius: float = 35.0
@export_range(0.08, 0.28, 0.01) var king_guard_height_ratio: float = 0.14
@export_range(180.0, 400.0, 10.0) var king_guard_chase_distance: float = 235.0
@export_range(180.0, 1100.0, 20.0) var king_guard_flight_acceleration: float = 520.0
@export_range(0.18, 0.42, 0.01) var king_solo_hover_height_ratio: float = 0.30
@export_range(0.07, 0.28, 0.01) var king_guard_hover_height_ratio: float = 0.13
@export_range(5, 9, 1) var king_exposed_spells_before_revival: int = 5
@export_group("King Aerial Prowl and Ricochet")
@export_range(115.0, 300.0, 5.0) var king_solo_travel_speed: float = 205.0
@export_range(2.5, 5.5, 0.1) var king_solo_reposition_seconds: float = 3.5
@export_range(0.70, 1.1, 0.05) var king_ricochet_warning_seconds: float = 0.90
@export_group("King Radiance Teleportation")
@export_range(2.0, 6.0, 0.25) var king_teleport_hold_seconds: float = 4.0
@export_range(0.12, 0.65, 0.01) var king_teleport_vanish_seconds: float = 0.26
@export_range(0.20, 0.80, 0.01) var king_teleport_reappear_seconds: float = 0.42
@export_range(3, 8, 1) var king_ricochet_bounces: int = 5
@export_range(2.0, 5.0, 0.25) var king_laser_screen_reach_multiplier: float = 3.0
@export_group("Royal Casting Before Laser Waves")
@export_range(0.40, 1.30, 0.05) var king_attack_cast_seconds: float = 0.75

@export_group("King 1% Royal Ward")
@export_range(35.0, 160.0, 5.0) var king_ward_repel_distance: float = 95.0
@export_range(0.4, 2.0, 0.1) var king_ward_repel_cooldown: float = 0.85

@export_group("Wall Phasing and Platform Revival")
@export var phase_through_walls_while_flying: bool = true
@export_range(360.0, 2000.0, 20.0) var platform_search_depth: float = 900.0
@export_range(1.0, 12.0, 1.0) var revive_floor_clearance: float = 4.0

@export_group("Level 6: Multi-Phase Arena")
@export var level6_boss_sequence_enabled: bool = true
@export_range(0.5, 8.0, 0.1) var level6_entrance_delay: float = 3.8
@export_range(1.0, 4.0, 0.1) var level6_entrance_shake_v37_seconds: float = 2.0
@export_range(0.0, 20.0, 0.5) var level6_entrance_shake_v37_strength: float = 11.0
@export_range(2.5, 4.0, 0.1) var level6_marker_hold_seconds: float = 3.7
@export_range(20, 500, 10) var level6_first_phase_hp_v37: int = 150
@export_range(20, 500, 10) var level6_second_phase_hp_v37: int = 150
@export_range(0, 300, 5) var level6_phase_hp_bonus_v48: int = 75
@export_range(0.5, 5.0, 0.1) var level6_phase2_entrance_delay: float = 2.0
@export_range(25, 150, 5) var level6_buffed_guard_health: int = 70
@export_range(8.0, 30.0, 1.0) var level6_guard_spell_interval: float = 14.0
@export_range(0.5, 4.0, 0.1) var level6_dissolve_seconds: float = 1.4
@export_range(100.0, 650.0, 10.0) var level6_upper_trigger_radius: float = 340.0
@export_range(0.0, 100.0, 5.0) var level6_marker_raise_pixels: float = 46.0
@export_range(0.5, 4.0, 0.1) var level6_title_display_seconds: float = 1.8
@export_range(90.0, 260.0, 5.0) var level6_spear_height_above_player: float = 145.0
@export var level6_boss_area_path: NodePath = NodePath("../bossarena")
@export var level6_platforms_path: NodePath = NodePath("../boss2phase")
@export var level6_second_identifier_path: NodePath = NodePath("../2phaseidentifier")

@export_group("Level 6: Third Phase / Final Climb")
@export var level6_third_identifier_path: NodePath = NodePath("../phase3startdetection")
@export var level6_third_platforms_path: NodePath = NodePath("../boss3phase")
@export_range(1, 30, 1) var level6_third_phase_sword_hits: int = 10
@export_range(3.0, 8.0, 0.25) var level6_phase3_laser_start_delay: float = 5.0
@export_range(0.9, 3.0, 0.1) var level6_climb_laser_gap: float = 1.55
@export_range(0.5, 2.0, 0.1) var level6_climb_laser_warning: float = 0.85
@export_range(3.0, 9.0, 0.25) var level6_final_animation_seconds: float = 5.75

@export_group("V87 - Final Collapse After King Death")
@export_range(2.0, 12.0, 0.25) var level6_collapse_rumble_seconds: float = 5.0
@export_range(7.0, 15.0, 0.25) var level6_collapse_fall_seconds: float = 10.0
@export_range(1.0, 8.0, 0.25) var level6_collapse_hide_tiles_seconds: float = 5.0
@export_range(6.0, 48.0, 1.0) var level6_collapse_max_shake: float = 30.0
@export_range(2000.0, 20000.0, 100.0) var level6_collapse_fallback_fall_distance: float = 6200.0
@export var level6_collapse_optional_ground_marker: NodePath = NodePath("")
@export_file("*.tscn") var level6_collapse_level7_scene: String = "res://level_7.tscn"

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
	var velocity: Vector2 = Vector2.ZERO
	var cruise_speed: float = 0.0


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
	var ricochet: bool = false
	var bounce_impact: bool = false
	var width_override: float = -1.0
	var phase3_pulsing_warning: bool = false


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
var king_special_kind: int = 0
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
var king_solo_attacks_since_guard: int = 0
var king_solo_reposition_timer: float = 0.0
var king_solo_flight_velocity: Vector2 = Vector2.ZERO
var king_solo_perch_index: int = -1
var king_tp_phase: int = 0
var king_tp_elapsed: float = 0.0
var king_tp_hold_remaining: float = 4.0
var king_tp_destination: Vector2 = Vector2.ZERO
var king_tp_guard_mode: bool = false
var king_tp_last_perch: int = -1
var king_tp_failed_attempts: int = 0
var king_tp_guard_perch_locked: bool = false
var king_no_spawn_shapes: Array[CollisionShape2D] = []
var king_no_spawn_scanned: bool = false
var king_guard_perch_clock: float = 0.0
var king_attack_cast_remaining: float = 0.0
var king_attack_cast_total: float = 0.0
var king_final_pattern_round: int = 0


enum Level6Stage {
	HIDDEN, WAITING, SHAKING, REVEAL, PHASE_ONE,
	DISSOLVE_ONE, CLIMB, SECOND_WAIT, PHASE_TWO, DISSOLVE_TWO, PHASE_THREE_PENDING,
	INTRO_TITLE, SECOND_TITLE,
	PHASE_THREE_CLIMB, THIRD_REVEAL, PHASE_THREE, THIRD_DEATH, COMPLETE
}
var level6_mode: bool = false
var level6_stage: Level6Stage = Level6Stage.HIDDEN
var level6_stage_timer: float = 0.0

@export_group("Level 6 - King Exploration Entrance")
@export var level6_wander_entrance_enabled: bool = true
@export var level6_wander_area1_path: NodePath = NodePath("../wanderarea1")
@export var level6_wander_area2_path: NodePath = NodePath("../wanderarea2")
@export_range(3.0, 16.0, 0.5) var level6_wander_awakening_delay: float = 9.0
@export_range(2.0, 9.0, 0.25) var level6_wander_pre_shake_seconds: float = 5.5
@export_range(0.0, 20.0, 0.5) var level6_wander_pre_shake_strength: float = 8.5
@export_range(2.0, 7.0, 0.25) var level6_wander_final_shake_seconds: float = 3.5
@export_range(0.5, 3.0, 0.1) var level6_wander_reveal_seconds: float = 1.2
@export_range(15.0, 70.0, 1.0) var level6_wander_letters_per_second: float = 33.0
@export var level6_wander_block_retreat: bool = true
@export_range(70.0, 350.0, 10.0) var level6_wander_retreat_wall_distance: float = 150.0
@export_range(500.0, 200000.0, 100.0) var level6_wander_retreat_wall_height: float = 200000.0
@export_range(1.0, 6.0, 0.1) var level6_wander_dialogue_hold: float = 2.0
var _level6_wander_area1: Area2D = null
var _level6_wander_area2: Area2D = null
var _level6_wander_active: bool = false
var _level6_wander_2_inside_last: bool = false
var _level6_wander_1_inside_last: bool = false
var _level6_wander_2_first_visit: bool = false
var _level6_wander_first_contact: Vector2 = Vector2.ZERO
var _level6_wander_left_first_contact: bool = false
var _level6_wander_retreat_wall: StaticBody2D = null
var _level6_wander_opposite_wall: StaticBody2D = null
var _level6_wander_1_visited: bool = false
var _level6_wander_completed: bool = false
var _level6_wander_dialogue_layer: CanvasLayer = null
var _level6_wander_dialogue_panel: Control = null
var _level6_wander_dialogue_text: Label = null
var _level6_wander_dialogue_glyph_left: Label = null
var _level6_wander_dialogue_glyph_right: Label = null
var _level6_wander_dialogue_queue: Array[String] = []
var _level6_wander_dialogue_line: String = ""
var _level6_wander_dialogue_elapsed: float = 0.0
var _level6_wander_dialogue_showing: bool = false


@export_group("Level 6 - Artifact Mercy")
@export var level6_artifact_mercy_enabled: bool = true
@export_range(1, 5, 1) var level6_artifact_mercy_max_saves: int = 3
@export_range(1.0, 5.0, 0.1) var level6_artifact_black_hold: float = 2.8
@export_range(0.0, 4.0, 0.1) var level6_artifact_silent_black_seconds: float = 1.4
@export_range(0.0, 3.0, 0.1) var level6_artifact_after_rescue_black_seconds: float = 1.2
@export_range(0.5, 4.0, 0.1) var level6_artifact_safe_grace: float = 2.5
@export_range(15.0, 90.0, 1.0) var level6_artifact_text_speed: float = 34.0

var _level6_artifact_saves_used: int = 0
var _level6_artifact_rescue_active: bool = false
var _level6_artifact_bound_player: CharacterBody2D = null
var _level6_artifact_prev_tree_paused: bool = false
var _level6_artifact_overlay: CanvasLayer = null
var _level6_artifact_screen: ColorRect = null
var _level6_artifact_label: Label = null
var _level6_artifact_message: String = ""
var _level6_artifact_awaiting_restart: bool = false

var level6_perch_timer: float = 0.0
var level6_guard_started: bool = false
var level6_guard_retry: float = 0.0
var level6_guard_summon_timer: float = 0.0
var level6_attack_timer: float = 1.8
var level6_attack_round: int = 0
var level6_second_identifier: Area2D = null
var level6_screen_layer: CanvasLayer = null
var level6_screen_root: Control = null
var level6_screen_shadow: ColorRect = null
var level6_player_hud_layer: CanvasLayer = null
var level6_player_hud_previous_layer: int = 0
var level6_title_layer: CanvasLayer = null
var level6_title_black: ColorRect = null
var level6_title_text: Label = null
var level6_title_king_text: Label = null
var level6_darkness_now: float = 0.0
var level6_world_darkness: CanvasModulate = null
var level6_world_darkness_original: Color = Color.WHITE
var level6_world_darkness_owned: bool = false
var level6_blackout_layer: CanvasLayer = null
var level6_blackout_rect: ColorRect = null
var level6_blackout_log_timer: float = 0.0
var level6_title_world_dim: ColorRect = null
var level6_void_fog_rect: ColorRect = null
var level6_void_fog_material: ShaderMaterial = null
var level6_void_vignette_rect: ColorRect = null
var level6_void_vignette_material: ShaderMaterial = null
var level6_void_smoke_particles: GPUParticles2D = null
var level6_void_ash_particles: GPUParticles2D = null
var level6_void_ambient_intensity: float = 0.0
var level6_void_atmosphere_ready: bool = false
var level6_void_visual_layer: CanvasLayer = null
var level6_void_fog_banks: Array[Sprite2D] = []
var level6_void_fog_places: Array[Vector2] = []
var level6_void_cpu_smoke: CPUParticles2D = null
var level6_void_cpu_ash: CPUParticles2D = null
var level6_void_vignette_sprite: Sprite2D = null
var level6_void_fog_time: float = 0.0
var level6_void_viewport_size: Vector2 = Vector2.ZERO
var level6_fx_root_v73: Control = null
var level6_fog_panels_v73: Array[TextureRect] = []
var level6_fog_homes_v73: Array[Vector2] = []
var level6_ash_motes_v73: Array[TextureRect] = []
var level6_mote_velocities_v73: Array[Vector2] = []
var level6_mote_opacities_v73: Array[float] = []
var level6_vignette_v73: TextureRect = null
var level6_particle_test_signal_v73: ColorRect = null


var level6_dark_test_mode: int = 0
var level6_dark_test_ui_layer: CanvasLayer = null
var level6_dark_test_label: Label = null
var level6_dark_test_test_layer: CanvasLayer = null
var level6_dark_test_test_rect: ColorRect = null
var level6_dark_test_layout_layer: CanvasLayer = null
var level6_dark_test_layout_root: Control = null
var level6_dark_test_layout_rect: ColorRect = null
var level6_dark_test_high_layer: CanvasLayer = null
var level6_dark_test_high_rect: ColorRect = null
var level6_dark_test_title_rect: ColorRect = null
var level6_dark_test_intro_reminder: bool = false
var level6_test_fog: bool = false
var level6_test_particles: bool = false
var level6_test_vignette: bool = false
var level6_dark_test_backing_v74: ColorRect = null
var level6_fx_parent_is_hud_v74: bool = false
var level6_preview_all_v76: bool = false
var level6_void_auto_fog_power_v79: float = 0.0
var level6_void_auto_vignette_power_v79: float = 0.0
var level6_void_guard_cue_logged_v79: bool = false
var level6_void_final_cue_logged_v79: bool = false
@export_range(0.40, 0.90, 0.01) var level6_void_manual_fog_alpha_v79: float = 0.77
@export_range(0.40, 0.85, 0.01) var level6_void_max_auto_fog_alpha_v79: float = 0.70
@export_range(0.50, 2.00, 0.05) var level6_void_fog_motion_speed_v79: float = 1.0
@export_range(0.25, 0.75, 0.01) var level6_phase3_fog_floor_v80: float = 0.55
@export var level6_artifact_epilogue_enabled_v80: bool = false
var level6_artifact_epilogue_started_v80: bool = false
const LEVEL6_FOG_COLS_V76: int = 9
const LEVEL6_FOG_ROWS_V76: int = 7
const LEVEL6_FOG_SPACING_V76: Vector2 = Vector2(365.0, 205.0)
const LEVEL6_ASH_COLS_V76: int = 13
const LEVEL6_ASH_ROWS_V76: int = 9
const LEVEL6_ASH_SPACING_V76: Vector2 = Vector2(150.0, 105.0)


var level6_aura_sprite: Sprite2D = null
var level6_aura_texture: Texture2D = null
var level6_void_shader: ShaderMaterial = null
var level6_first_markers: Array[Marker2D] = []
var level6_second_markers: Array[Marker2D] = []
var level6_third_markers: Array[Marker2D] = []
var level6_third_identifier: Area2D = null
var level6_current_marker: Marker2D = null
var level6_arena: Area2D = null
var level6_climb_layer: TileMapLayer = null
var level6_third_climb_layer: TileMapLayer = null
var level6_original_cam_offset: Vector2 = Vector2.ZERO
var level6_shake_cam: Camera2D = null
var level6_camera_base_zoom: Vector2 = Vector2.ONE
var level6_camera_initialized: bool = false
@export_range(0.65, 1.0, 0.01) var level6_camera_zoom_factor: float = 0.87
@export_range(0.0, 200.0, 5.0) var level6_camera_upward_pixels: float = 95.0
var level6_hud_gradient_bar: ColorRect = null
var level6_hud_gradient_material: ShaderMaterial = null
var level6_void_walls: Array[VoidWall] = []
var level6_aura_particles: CPUParticles2D = null
var level6_particle_texture: Texture2D = null
var level6_last_burst_at: Vector2 = Vector2.ZERO
var level6_hit_lock: float = 0.0
var level6_player_swing_seen: bool = false
var level6_player_swing_frame: int = -1
var level6_fallback_hit_for_swing: bool = false
var level6_guard_flash_timers: Dictionary = {}
var level6_guard_previous_hp: Dictionary = {}
var level6_void_swords: Array[VoidSword] = []
@export var level6_debug_skip_phase_one_with_1: bool = true
var level6_debug_one_was_down: bool = false
@export var level6_debug_skip_phase_two_with_2: bool = true
var level6_debug_two_was_down: bool = false
var level6_dash_echoes: Array[VoidDashEcho] = []
var level6_skull_shot_timer: float = 0.0
var level6_skull_shots_left: int = 0
var level6_skull_spawn_serial: int = 0
var level6_skull_spawn_rotation: int = 0
var level6_last_skull_spawn: Vector2 = Vector2(INF, INF)
var level6_departure_target: Vector2 = Vector2.ZERO
signal level6_phase_two_finished
signal level6_final_victory
var level6_third_attack_timer: float = 1.5
var level6_third_attack_round: int = 0
var level6_third_laser_timer: float = 1.2
var level6_climb_slash_round: int = 0
var level6_third_warnings: Array[VoidRainLaser] = []
var level6_third_fx_timer: float = 0.0
var level6_third_fx_original_scale: Vector2 = Vector2.ONE
var level6_third_fx_particles: Array[Sprite2D] = []
var level6_third_completion_label: Label = null
var level6_final_shake_camera: Camera2D = null
var level6_final_camera_offset: Vector2 = Vector2.ZERO

var _collapse_step: int = 0
var _collapse_level7_transition_started: bool = false
var _collapse_elapsed: float = 0.0
var _collapse_total_elapsed: float = 0.0
var _collapse_tiles: Array[Dictionary] = []
var _collapse_tiles_restored: bool = true
var _collapse_player_physics: bool = true
var _collapse_player_mask: int = 1
var _collapse_player_process: bool = true
var _collapse_player_start_y: float = 0.0
var _collapse_player_goal_y: float = 0.0
var _collapse_expected_ground_y: float = 0.0
var _collapse_player_start_x: float = 0.0
var _collapse_ui: CanvasLayer = null
var _collapse_fog_root: Control = null
var _collapse_white_shroud: ColorRect = null
var _collapse_white_fog: Array[TextureRect] = []
var _collapse_fog_texture: Texture2D = null
var _collapse_wind_texture: Texture2D = null
var _collapse_fog_clock: float = 0.0
var _collapse_debris_timer: float = 0.0
var _collapse_burst_timer: float = 0.0
var _collapse_white_particle_count: int = 0
var _collapse_emitters: Array[CPUParticles2D] = []
var _collapse_relics: Array[AnimatedSprite2D] = []
var _collapse_flash: CanvasLayer = null
var _collapse_flash_bg: ColorRect = null
var _collapse_flash_label: Label = null

class VoidRainLaser:
	var x: float = 0.0
	var head_y: float = 0.0
	var start_y: float = 0.0
	var end_y: float = 0.0
	var elapsed: float = 0.0
	var warning: float = 0.85
	var speed: float = 510.0
	var length: float = 210.0
	var struck: bool = false

class VoidSword:
	var position: Vector2 = Vector2.ZERO
	var aim: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.DOWN
	var elapsed: float = 0.0
	var delay: float = 0.0
	var warning: float = 0.75
	var fade_time: float = 0.24
	var aim_lock_time: float = 0.025
	var launched: bool = false
	var flight: float = 0.0
	var trail: Array[Vector2] = []
	var hit: bool = false

class VoidWall:
	var start_x: float = 0.0
	var end_x: float = 0.0
	var elapsed: float = 0.0
	var warning: float = 1.30
	var travel: float = 3.30
	var width: float = 58.0
	var last_damage_time: float = -1.0
	var dashed_through: bool = false
	var sweep_history: Array[float] = []

class VoidDashEcho:
	var start: Vector2 = Vector2.ZERO
	var end: Vector2 = Vector2.ZERO
	var elapsed: float = 0.0
	var delay: float = 0.0
	var warn: float = 0.68
	var travel: float = 0.23
	var hit: bool = false


func _level6_detect_scene() -> bool:
	if not level6_boss_sequence_enabled:
		return false
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_parent()
	if level == null:
		return false
	var name_text: String = String(level.name).to_lower().replace("_", "")
	var file_text: String = String(level.scene_file_path).get_file().get_basename().to_lower().replace("_", "")
	return name_text == "level6" or file_text == "level6"


func _level6_initialize() -> void:
	level6_mode = _level6_detect_scene()
	if not level6_mode:
		return
	collision_layer = 0
	collision_mask = 0
	level6_stage = Level6Stage.HIDDEN
	level6_skull_spawn_serial = 0
	level6_skull_spawn_rotation = randi_range(0, 7)
	level6_first_markers.clear()
	level6_second_markers.clear()
	level6_third_markers.clear()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root != null:
		for node: Node in scene_root.find_children("*", "Marker2D", true, false):
			var marker2: Marker2D = node as Marker2D
			if marker2 == null:
				continue
			var lower_name: String = String(marker2.name).to_lower()
			if lower_name.begins_with("1phasespawns"):
				level6_first_markers.append(marker2)
			elif lower_name.begins_with("2phasebo") and "spawn" in lower_name:
				level6_second_markers.append(marker2)
			elif lower_name.begins_with("3phasebo") and "spawn" in lower_name:
				level6_third_markers.append(marker2)
	if not level6_boss_area_path.is_empty():
		level6_arena = get_node_or_null(level6_boss_area_path) as Area2D
	if level6_arena == null and scene_root != null:
		level6_arena = scene_root.find_child("bossarena", true, false) as Area2D
	if level6_arena != null:
		if not level6_arena.body_entered.is_connected(_level6_on_boss_area_entered):
			level6_arena.body_entered.connect(_level6_on_boss_area_entered)
	else:
		push_warning("KING V37: bossarena Area2D missing; phase 1 cannot auto-start.")
	if not level6_wander_area1_path.is_empty():
		_level6_wander_area1 = get_node_or_null(level6_wander_area1_path) as Area2D
	if not level6_wander_area2_path.is_empty():
		_level6_wander_area2 = get_node_or_null(level6_wander_area2_path) as Area2D
	if scene_root != null:
		if not is_instance_valid(_level6_wander_area1):
			_level6_wander_area1 = scene_root.find_child("wanderarea1", true, false) as Area2D
		if not is_instance_valid(_level6_wander_area2):
			_level6_wander_area2 = scene_root.find_child("wanderarea2", true, false) as Area2D
	_level6_wander_active = (level6_wander_entrance_enabled
		and is_instance_valid(_level6_wander_area1)
		and is_instance_valid(_level6_wander_area2))
	if level6_wander_entrance_enabled and not _level6_wander_active:
		push_warning("KING ENTRANCE V81: wanderarea1 or wanderarea2 missing; using original bossarena trigger.")
	if not level6_second_identifier_path.is_empty():
		level6_second_identifier = get_node_or_null(level6_second_identifier_path) as Area2D
	if level6_second_identifier == null and scene_root != null:
		level6_second_identifier = scene_root.find_child("2phaseidentifier", true, false) as Area2D
	if not level6_third_identifier_path.is_empty():
		level6_third_identifier = get_node_or_null(level6_third_identifier_path) as Area2D
	if level6_third_identifier == null and scene_root != null:
		level6_third_identifier = scene_root.find_child("phase3startdetection", true, false) as Area2D
	if level6_second_identifier != null:
		if not level6_second_identifier.body_entered.is_connected(_level6_on_second_area_entered):
			level6_second_identifier.body_entered.connect(_level6_on_second_area_entered)
	else:
		push_warning("KING V37: 2phaseidentifier Area2D missing; phase 2 requires it.")
	if not level6_platforms_path.is_empty():
		level6_climb_layer = get_node_or_null(level6_platforms_path) as TileMapLayer
	if level6_climb_layer == null and scene_root != null:
		level6_climb_layer = scene_root.find_child("boss2phase", true, false) as TileMapLayer
	if level6_climb_layer != null:
		level6_climb_layer.enabled = false
	else:
		push_warning("KING V36: boss2phase TileMapLayer not found.")
	level6_third_climb_layer = _level6_find_third_climb_layer()
	if is_instance_valid(level6_third_climb_layer):
		level6_third_climb_layer.enabled = false
	else:
		push_warning("VOID KING V57: boss3phase TileMapLayer not found. Check its node name or Third Platforms Path.")
	print("VOID KING V46: Level6 markers found: phase 1=", level6_first_markers.size(),
		", phase 2=", level6_second_markers.size())
	if level6_first_markers.is_empty() or level6_second_markers.is_empty():
		push_warning("VOID KING V46: missing Marker2D nodes (accepts both 2phasebosspawns and 2phasebossspawns).")
	max_hp = maxi(20, level6_first_phase_hp_v37 + level6_phase_hp_bonus_v48)
	hp = max_hp
	king_shield_phase = KingShieldPhase.SOLO
	king_shield_countdown = -1.0
	king_elite_total_waves = 1
	king_elite_waves_spawned = 0
	king_elite_guards.clear()
	king_max_total_resurrections = 0
	king_post_attack_timer = 1.0
	sprite.visible = false
	if is_instance_valid(king_crown_root):
		king_crown_root.visible = false
		king_crown_root.queue_free()
		king_crown_root = null
	if is_instance_valid(king_hud):
		king_hud.visible = false
	var void_shader := Shader.new()
	void_shader.code = """shader_type canvas_item;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float red_pixel = step(0.29, tex.r) * step(tex.g * 1.50, tex.r) * step(tex.b * 1.35, tex.r);
	vec3 dark_body = vec3(0.021, 0.022, 0.029) + tex.rgb * 0.032;
	vec3 col = mix(dark_body, vec3(1.0, 1.0, 1.0), red_pixel);
	// Modulate cannot flash this shader when COLOR is overwritten; use a uniform.
	col = mix(col, vec3(1.0, 1.0, 1.0), hit_flash);
	COLOR = vec4(col, tex.a);
} """
	var void_material := ShaderMaterial.new()
	void_material.shader = void_shader
	sprite.material = void_material
	level6_void_shader = void_material
	sprite.self_modulate = Color.WHITE
	sprite.modulate = Color.WHITE
	sprite_tint = Color.WHITE
	_level6_create_aura()
	_level6_create_screen_darkness()
	_level6_dark_test_setup()
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.emitting = false
		level6_aura_particles.visible = false
	if is_instance_valid(level6_aura_sprite):
		level6_aura_sprite.visible = false
	_update_king_hp_label()
	if is_instance_valid(king_hud):
		king_hud.visible = false


func _level6_accepted_hit(previous_hp: int) -> void:
	if hp >= previous_hp:
		return
	king_black_flash_timer = 0.105
	if is_instance_valid(target) and target.has_method(&"is_swinging") and bool(target.call(&"is_swinging")):
		level6_player_swing_seen = true
		level6_fallback_hit_for_swing = true
		var player_anim: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if player_anim != null:
			level6_player_swing_frame = player_anim.frame
	if is_instance_valid(level6_void_shader):
		level6_void_shader.set_shader_parameter("hit_flash", 1.0)
	_level6_hit_particles()
	print("VOID KING HIT: ", previous_hp, " -> ", hp, " / ", max_hp)


func _level6_hit_particles() -> void:
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.name = "VoidKingHitSparks"
	fx.texture = _level6_get_particle_texture()
	fx.one_shot = true
	fx.amount = 14
	fx.explosiveness = 1.0
	fx.lifetime = 0.32
	fx.direction = Vector2.UP
	fx.spread = 155.0
	fx.initial_velocity_min = 42.0
	fx.initial_velocity_max = 115.0
	fx.gravity = Vector2(0.0, 90.0)
	fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fx.emission_rect_extents = Vector2(17.0, 23.0)
	fx.color = Color(0.83, 0.85, 0.92, 0.8)
	fx.z_index = 81
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(fx)
	fx.global_position = sprite.global_position
	fx.emitting = true
	get_tree().create_timer(0.55).timeout.connect(fx.queue_free)


func _level6_sword_fallback() -> void:
	if not is_instance_valid(target) or not target.has_method(&"is_swinging"):
		level6_player_swing_seen = false
		return
	if not bool(target.call(&"is_swinging")):
		level6_player_swing_seen = false
		level6_fallback_hit_for_swing = false
		level6_player_swing_frame = -1
		return
	var sword_sprite: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sword_sprite == null:
		return
	var frame: int = sword_sprite.frame
	if not level6_player_swing_seen or frame < level6_player_swing_frame:
		level6_fallback_hit_for_swing = false
	level6_player_swing_seen = true
	level6_player_swing_frame = frame
	if level6_fallback_hit_for_swing or level6_hit_lock > 0.0:
		return
	if frame < 2 or frame > 4:
		return
	if global_position.distance_squared_to(target.global_position) > 320.0 * 320.0:
		return
	var sword_area: Area2D = target.get_node_or_null("AttackAreaJ") as Area2D
	if sword_area == null:
		sword_area = target.get_node_or_null("AttackArea") as Area2D
	if sword_area == null:
		return
	for shape_node: Node in sword_area.find_children("*", "CollisionShape2D", true, false):
		var sword_shape: CollisionShape2D = shape_node as CollisionShape2D
		if sword_shape == null or sword_shape.disabled or sword_shape.shape == null:
			continue
		if attack_shape_hits_hurtbox(sword_shape):
			var damage: int = 1
			var proposed: Variant = target.get("dano_do_golpe")
			if proposed is int:
				damage = maxi(1, int(proposed))
			level6_fallback_hit_for_swing = true
			tomar_dano(damage, target.global_position)
			return


func _level6_get_particle_texture() -> Texture2D:
	if level6_particle_texture != null:
		return level6_particle_texture
	var img: Image = Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	for px: int in range(1, 6):
		for py: int in range(1, 6):
			var edge: bool = px == 1 or px == 5 or py == 1 or py == 5
			img.set_pixel(px, py, Color(1.0, 1.0, 1.0, 0.55 if edge else 1.0))
	level6_particle_texture = ImageTexture.create_from_image(img)
	return level6_particle_texture


func _level6_get_aura_texture() -> Texture2D:
	if level6_aura_texture != null:
		return level6_aura_texture
	var image: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y: int in range(128):
		for x: int in range(128):
			var uv: Vector2 = (Vector2(float(x), float(y)) - Vector2(63.5, 63.5)) / 63.5
			var theta: float = atan2(uv.y, uv.x)
			var distance: float = uv.length()
			var ripple: float = sin(theta * 7.0 + distance * 8.0) * 0.075 + sin(theta * 13.0 - distance * 11.0) * 0.038
			var opacity: float = pow(clampf((1.0 + ripple - distance) / 0.83, 0.0, 1.0), 2.8) * 0.47
			image.set_pixel(x, y, Color(0.017, 0.018, 0.025, opacity))
	level6_aura_texture = ImageTexture.create_from_image(image)
	return level6_aura_texture


func _level6_create_aura() -> void:
	if not is_instance_valid(level6_aura_sprite):
		level6_aura_sprite = Sprite2D.new()
		level6_aura_sprite.name = "SoftVoidAura"
		level6_aura_sprite.texture = _level6_get_aura_texture()
		level6_aura_sprite.scale = Vector2(2.05, 2.20)
		level6_aura_sprite.position = Vector2(0.0, -14.0)
		level6_aura_sprite.z_index = -4
		level6_aura_sprite.show_behind_parent = true
		add_child(level6_aura_sprite)
	if is_instance_valid(level6_aura_particles):
		return
	level6_aura_particles = CPUParticles2D.new()
	level6_aura_particles.name = "KingSoftVoidSmoke"
	level6_aura_particles.texture = _level6_get_particle_texture()
	level6_aura_particles.amount = 19
	level6_aura_particles.lifetime = 1.8
	level6_aura_particles.emitting = true
	level6_aura_particles.direction = Vector2.UP
	level6_aura_particles.spread = 80.0
	level6_aura_particles.initial_velocity_min = 13.0
	level6_aura_particles.initial_velocity_max = 29.0
	level6_aura_particles.gravity = Vector2(0.0, -6.0)
	level6_aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	level6_aura_particles.emission_rect_extents = Vector2(22.0, 32.0)
	level6_aura_particles.color = Color(0.028, 0.029, 0.045, 0.28)
	level6_aura_particles.z_index = -3
	level6_aura_particles.show_behind_parent = true
	add_child(level6_aura_particles)


func _level6_keep_hud_above_darkness() -> void:
	if not is_instance_valid(level6_player_hud_layer):
		var scene: Node = get_tree().current_scene
		if is_instance_valid(scene):
			var candidate: CanvasLayer = scene.find_child("HUD", true, false) as CanvasLayer
			if is_instance_valid(candidate):
				level6_player_hud_layer = candidate
				level6_player_hud_previous_layer = candidate.layer
	if is_instance_valid(level6_player_hud_layer):
		level6_player_hud_layer.layer = 930
	if is_instance_valid(king_hud):
		king_hud.layer = 930


func _level6_create_screen_darkness() -> void:
	if is_instance_valid(level6_screen_layer) and is_instance_valid(level6_screen_shadow):
		return
	level6_screen_layer = CanvasLayer.new()
	level6_screen_layer.name = "VoidKingDarknessBaseV72"
	level6_screen_layer.layer = 100
	level6_screen_layer.follow_viewport_enabled = false
	get_tree().root.add_child.call_deferred(level6_screen_layer)
	level6_screen_shadow = ColorRect.new()
	level6_screen_shadow.name = "AutomaticDarknessKey4V71"
	level6_screen_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level6_screen_shadow.position = Vector2.ZERO
	level6_screen_shadow.size = get_viewport_rect().size
	level6_screen_shadow.color = Color(0.0, 0.0, 0.0, 0.0)
	level6_screen_layer.add_child(level6_screen_shadow)
	_level6_keep_hud_above_darkness()
	_level6_create_void_atmosphere()
	print("VOID KING V79: proven darkness + more mobile world-anchored fog initialized")


func _level6_apply_world_darkness(alpha: float) -> void:
	if not is_instance_valid(level6_screen_shadow):
		_level6_create_screen_darkness()
	if not is_instance_valid(level6_screen_shadow):
		return
	var darkness: float = clampf(alpha, 0.0, 1.0)
	var black_alpha: float = lerpf(darkness * 0.48, darkness, smoothstep(0.75, 1.0, darkness))
	level6_screen_layer.visible = true
	level6_screen_shadow.visible = true
	if level6_dark_test_mode == 0:
		level6_screen_shadow.modulate.a = 1.0
		level6_screen_shadow.color = Color(0.0, 0.0, 0.0, black_alpha)
	else:
		level6_screen_shadow.modulate.a = 1.0
		level6_screen_shadow.color = Color(0.0, 0.0, 0.0, 0.0)
	_level6_update_void_atmosphere(darkness)


func _level6_guard_hp_ratio() -> float:
	for guard: CharacterBody2D in king_elite_guards:
		if not is_instance_valid(guard) or guard.is_queued_for_deletion():
			continue
		if guard.has_method(&"is_dead") and bool(guard.call(&"is_dead")):
			continue
		var fields: Dictionary = {}
		for property_info: Dictionary in guard.get_property_list():
			fields[String(property_info.get("name", ""))] = true
		var current_name: String = "hp" if fields.has("hp") else ("vida" if fields.has("vida") else "")
		var maximum_name: String = "max_hp" if fields.has("max_hp") else ("vida_maxima" if fields.has("vida_maxima") else "")
		if not current_name.is_empty() and not maximum_name.is_empty():
			return clampf(float(guard.get(current_name)) / maxf(1.0, float(guard.get(maximum_name))), 0.0, 1.0)
	return 1.0


func _level6_update_screen_darkness(delta: float) -> void:
	if not is_instance_valid(level6_screen_shadow):
		_level6_create_screen_darkness()
	if not is_instance_valid(level6_screen_shadow):
		return
	level6_screen_layer.visible = true
	level6_screen_shadow.visible = true
	var viewport_size: Vector2 = get_viewport_rect().size
	if not level6_screen_shadow.size.is_equal_approx(viewport_size):
		level6_screen_shadow.size = viewport_size
	var target_alpha: float = 0.0
	if level6_stage == Level6Stage.PHASE_ONE:
		if king_shield_phase == KingShieldPhase.SOLO:
			var hp_danger: float = 1.0 - float(hp) / maxf(1.0, float(max_hp))
			target_alpha = 0.035 + 0.53 * pow(clampf(hp_danger, 0.0, 1.0), 1.15)
		elif king_shield_phase == KingShieldPhase.SHIELDED:
			var guard_danger: float = 1.0 - _level6_guard_hp_ratio()
			target_alpha = 0.56 + 0.17 * clampf(guard_danger, 0.0, 1.0)
		else:
			target_alpha = 0.73
	elif level6_stage == Level6Stage.PHASE_TWO:
		target_alpha = 0.10 + 0.51 * (1.0 - float(hp) / maxf(1.0, float(max_hp)))
	elif level6_stage == Level6Stage.PHASE_THREE_CLIMB:
		target_alpha = 0.28
	elif level6_stage == Level6Stage.THIRD_REVEAL:
		target_alpha = 0.49
	elif level6_stage == Level6Stage.PHASE_THREE:
		var final_damage_fraction: float = 1.0 - float(hp) / maxf(1.0, float(max_hp))
		target_alpha = 0.49 + 0.36 * pow(clampf(final_damage_fraction, 0.0, 1.0), 0.73)
		if hp <= 3:
			target_alpha += 0.023 * sin(hover_time * TAU * 0.78)
	elif level6_stage == Level6Stage.THIRD_DEATH:
		target_alpha = 0.61 + 0.07 * sin(_collapse_total_elapsed * 0.7)
	elif level6_stage == Level6Stage.COMPLETE:
		target_alpha = 0.0
	elif level6_stage in [Level6Stage.DISSOLVE_ONE, Level6Stage.DISSOLVE_TWO]:
		target_alpha = 0.73
	var darkness_response: float = 2.5 if level6_stage in [Level6Stage.THIRD_REVEAL, Level6Stage.PHASE_THREE] else 1.05
	level6_darkness_now = move_toward(level6_darkness_now, target_alpha, delta * darkness_response)
	var darkness_cap: float = 0.88 if level6_stage == Level6Stage.PHASE_THREE else (0.68 if level6_stage == Level6Stage.THIRD_DEATH else (1.0 if level6_stage == Level6Stage.COMPLETE else 0.75))
	var output_alpha: float = clampf(level6_darkness_now, 0.0, darkness_cap)
	_level6_apply_world_darkness(output_alpha)
	if level6_stage in [Level6Stage.PHASE_THREE, Level6Stage.THIRD_DEATH, Level6Stage.COMPLETE]:
		level6_blackout_log_timer += delta
		if level6_blackout_log_timer >= 4.0:
			level6_blackout_log_timer = 0.0
			print("VOID KING V71: dark stage=", level6_stage,
				" base_alpha=", level6_screen_shadow.color.a,
				" fog=", level6_void_ambient_intensity,
				" visible=", level6_screen_shadow.is_visible_in_tree())


func _level6_rebind_upper_nodes() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		return
	if not is_instance_valid(level6_second_identifier):
		level6_second_identifier = scene_root.find_child("2phaseidentifier", true, false) as Area2D
		if is_instance_valid(level6_second_identifier):
			if not level6_second_identifier.body_entered.is_connected(_level6_on_second_area_entered):
				level6_second_identifier.body_entered.connect(_level6_on_second_area_entered)
	if level6_second_markers.is_empty():
		for node: Node in scene_root.find_children("*", "Marker2D", true, false):
			var marker: Marker2D = node as Marker2D
			if marker != null and (String(marker.name).to_lower().begins_with("2phasebo") and "spawn" in String(marker.name).to_lower()):
				level6_second_markers.append(marker)
		if not level6_second_markers.is_empty():
			print("VOID KING V46: recovered ", level6_second_markers.size(), " upper markers: ",
				level6_second_markers[0].name)
	for index: int in range(level6_second_markers.size() - 1, -1, -1):
		if not is_instance_valid(level6_second_markers[index]):
			level6_second_markers.remove_at(index)


func _level6_upper_arena_reached() -> bool:
	if not is_instance_valid(target):
		return false
	if is_instance_valid(level6_second_identifier):
		if level6_second_identifier.overlaps_body(target):
			return true
		var body_points: Array[Vector2] = [
			target.global_position,
			target.global_position + Vector2(0.0, -22.0),
			target.global_position + Vector2(0.0, 22.0)
		]
		for point: Vector2 in body_points:
			if _level6_point_inside_area(level6_second_identifier, point):
				return true
	if level6_second_markers.is_empty():
		return false
	var left: float = INF
	var right: float = -INF
	var top: float = INF
	var bottom: float = -INF
	for marker: Marker2D in level6_second_markers:
		if not is_instance_valid(marker):
			continue
		left = minf(left, marker.global_position.x)
		right = maxf(right, marker.global_position.x)
		top = minf(top, marker.global_position.y)
		bottom = maxf(bottom, marker.global_position.y)
	if left == INF:
		return false
	var margin_x: float = maxf(130.0, level6_upper_trigger_radius * 0.55)
	var margin_y: float = maxf(100.0, level6_upper_trigger_radius * 0.40)
	var p: Vector2 = target.global_position
	return (
		p.x >= left - margin_x and p.x <= right + margin_x
		and p.y >= top - margin_y and p.y <= bottom + margin_y
	)


func _level6_marker_position(marker: Marker2D) -> Vector2:
	return marker.global_position + Vector2(0.0, -level6_marker_raise_pixels)


func _level6_phase_two_framing() -> bool:
	return level6_stage in [
		Level6Stage.SECOND_TITLE, Level6Stage.SECOND_WAIT,
		Level6Stage.PHASE_TWO, Level6Stage.DISSOLVE_TWO
	] or (level6_stage == Level6Stage.REVEAL and level6_second_reveal)


func _level6_create_title_overlay() -> void:
	if is_instance_valid(level6_title_layer):
		return
	level6_title_layer = CanvasLayer.new()
	level6_title_layer.name = "VoidKingTitleScreen"
	level6_title_layer.layer = 520
	get_tree().root.add_child.call_deferred(level6_title_layer)
	level6_title_black = ColorRect.new()
	level6_title_black.name = "FullBlack"
	level6_title_black.color = Color.BLACK
	level6_title_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level6_title_layer.add_child(level6_title_black)
	level6_title_text = Label.new()
	level6_title_text.name = "VoidTitleUpper"
	level6_title_text.text = "VOID"
	level6_title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level6_title_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level6_title_text.add_theme_color_override("font_color", Color.WHITE)
	level6_title_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level6_title_layer.add_child(level6_title_text)

	level6_title_king_text = Label.new()
	level6_title_king_text.name = "KingTitleLower"
	level6_title_king_text.text = "KING"
	level6_title_king_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level6_title_king_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level6_title_king_text.add_theme_color_override("font_color", Color.WHITE)
	level6_title_king_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level6_title_layer.add_child(level6_title_king_text)

	level6_title_black.visible = false
	level6_title_text.visible = false
	level6_title_king_text.visible = false
	level6_title_layer.visible = true
	_level6_title_resize()


func _level6_title_resize() -> void:
	if not is_instance_valid(level6_title_layer):
		return
	var screen: Vector2 = get_viewport_rect().size
	level6_title_black.position = Vector2.ZERO
	level6_title_black.size = screen
	if is_instance_valid(level6_title_world_dim):
		level6_title_world_dim.size = screen
	if is_instance_valid(level6_title_text):
		level6_title_text.position = Vector2(0.0, screen.y * 0.14)
		level6_title_text.size = Vector2(screen.x, screen.y * 0.37)
		level6_title_text.add_theme_font_size_override(
			"font_size", maxi(34, int(minf(screen.y * 0.35, screen.x * 0.28)))
		)
	if is_instance_valid(level6_title_king_text):
		level6_title_king_text.position = Vector2(0.0, screen.y * 0.42)
		level6_title_king_text.size = Vector2(screen.x, screen.y * 0.48)
		level6_title_king_text.add_theme_font_size_override(
			"font_size", maxi(59, int(minf(screen.y * 0.51, screen.x * 0.39)))
		)


func _level6_begin_title(second: bool) -> void:
	if second:
		_level6_end_title()
		level6_stage = Level6Stage.SECOND_WAIT
		level6_stage_timer = maxf(1.0, level6_phase2_shake_duration)
		return
	_level6_create_title_overlay()
	for void_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if void_node.has_method(&"activate_for_title"):
			void_node.call(&"activate_for_title")
	level6_stage = Level6Stage.INTRO_TITLE
	level6_stage_timer = maxf(1.8, level6_title_display_seconds)
	level6_title_layer.layer = 550
	level6_title_layer.visible = true
	level6_title_black.visible = true
	level6_title_text.visible = true
	level6_title_king_text.visible = true
	_level6_title_resize()
	sprite.visible = false
	if is_instance_valid(king_hud):
		king_hud.visible = false
	var camera: Camera2D = _level6_find_battle_camera()
	if is_instance_valid(camera):
		if not level6_camera_initialized:
			level6_camera_initialized = true
			level6_original_cam_offset = camera.offset
			level6_camera_base_zoom = camera.zoom
		camera.zoom = level6_camera_base_zoom * level6_camera_zoom_factor
		camera.offset = Vector2.ZERO if second else level6_original_cam_offset + Vector2(0.0, -level6_camera_upward_pixels)
		camera.reset_smoothing()


func _level6_end_title() -> void:
	if level6_stage == Level6Stage.INTRO_TITLE:
		for void_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
			if void_node.has_method(&"play_intro_rise"):
				void_node.call(&"play_intro_rise")
	if is_instance_valid(level6_title_layer):
		level6_title_layer.layer = 520
		level6_title_layer.visible = true
		if is_instance_valid(level6_title_black):
			level6_title_black.visible = false
		if is_instance_valid(level6_title_text):
			level6_title_text.visible = false
		if is_instance_valid(level6_title_king_text):
			level6_title_king_text.visible = false


func _level6_find_battle_camera() -> Camera2D:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not is_instance_valid(camera) and is_instance_valid(target):
		camera = target.find_child("Camera2D", true, false) as Camera2D
	return camera


func _level6_upper_height_reached() -> bool:
	if not is_instance_valid(target):
		return false
	var upper_bottom: float = -INF
	var upper_left: float = INF
	var upper_right: float = -INF
	for marker: Marker2D in level6_second_markers:
		if not is_instance_valid(marker):
			continue
		upper_bottom = maxf(upper_bottom, marker.global_position.y)
		upper_left = minf(upper_left, marker.global_position.x)
		upper_right = maxf(upper_right, marker.global_position.x)
	if upper_bottom == -INF:
		return false
	var trigger_y: float = upper_bottom + 340.0
	var lower_top: float = INF
	for marker: Marker2D in level6_first_markers:
		if is_instance_valid(marker):
			lower_top = minf(lower_top, marker.global_position.y)
	if lower_top < INF and lower_top > upper_bottom:
		trigger_y = minf(trigger_y, upper_bottom + maxf(100.0, (lower_top - upper_bottom) * 0.45))
	var player_at: Vector2 = target.global_position
	return (
		player_at.y <= trigger_y
		and player_at.x >= upper_left - 450.0
		and player_at.x <= upper_right + 450.0
	)


func _process(delta: float) -> void:
	if not level6_mode:
		return
	_level6_dark_test_tick()
	_level6_wander_update(delta)
	if level6_stage not in [Level6Stage.CLIMB, Level6Stage.SECOND_TITLE, Level6Stage.SECOND_WAIT, Level6Stage.REVEAL]:
		return
	if level6_stage == Level6Stage.REVEAL and not level6_second_reveal:
		return

	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D

	if level6_stage == Level6Stage.CLIMB:
		level6_climb_elapsed += delta
		level6_upper_check_log_timer += delta
		_level6_rebind_upper_nodes()
		var inside_upper: bool = _level6_upper_arena_reached() or _level6_upper_height_reached()
		if inside_upper and is_instance_valid(target):
			print("VOID KING V44: upper platform detected, starting phase-two shake at ", target.global_position)
			_level6_on_second_area_entered(target)
		elif level6_upper_check_log_timer >= 5.0:
			level6_upper_check_log_timer = 0.0
			print("VOID KING V44: STILL CLIMBING: player=", target.global_position if is_instance_valid(target) else Vector2.ZERO,
				" 2nd_area=", is_instance_valid(level6_second_identifier), " upper_markers=", level6_second_markers.size())
		return

	if level6_stage == Level6Stage.SECOND_TITLE:
		_level6_title_resize()
		level6_stage_timer -= delta
		if level6_stage_timer <= 0.0:
			_level6_end_title()
			level6_stage = Level6Stage.SECOND_WAIT
			level6_stage_timer = level6_phase2_shake_duration
		return

	if level6_stage == Level6Stage.SECOND_WAIT:
		level6_stage_timer -= delta
		if not is_instance_valid(level6_shake_cam):
			level6_shake_cam = _level6_find_battle_camera()
		if is_instance_valid(level6_shake_cam):
			var progress: float = 1.0 - clampf(level6_stage_timer / maxf(0.2, level6_phase2_shake_duration), 0.0, 1.0)
			var power: float = level6_phase2_shake_max_pixels * pow(progress, 2.0)
			level6_shake_cam.offset = Vector2(randf_range(-power, power), randf_range(-power, power))
		if level6_stage_timer <= 0.0:
			_level6_stop_shake()
			_level6_rebind_upper_nodes()
			var upper_marker: Marker2D = _level6_phase2_marker_near_player()
			if is_instance_valid(upper_marker):
				king_tp_phase = 0
				level6_current_marker = upper_marker
				global_position = _level6_marker_position(upper_marker)
				king_tp_destination = global_position
				reset_physics_interpolation()
				_level6_start_second_phase()
				print("VOID KING V44: phase-two REVEAL started at ", upper_marker.name, " / ", global_position)
			else:
				push_error("VOID KING V44: no upper Marker2D found; check node names 2phasebosspawns...")
				level6_stage_timer = 1.0
		return

	if level6_stage == Level6Stage.REVEAL and level6_second_reveal:
		level6_stage_timer -= delta
		var progress: float = 1.0 - clampf(level6_stage_timer / maxf(0.30, king_teleport_reappear_seconds), 0.0, 1.0)
		_king_set_teleport_death_frame(1.0 - progress)
		sprite.visible = true
		if level6_stage_timer <= 0.0:
			level6_second_reveal = false
			level6_stage = Level6Stage.PHASE_TWO
			level6_perch_timer = maxf(2.5, level6_marker_hold_seconds)
			king_tp_hold_remaining = 4.0
			king_tp_phase = 0
			_level6_secure_second_marker()
			_play(&"idle", true)
			if not is_instance_valid(king_hud):
				_create_king_boss_hud()
			if is_instance_valid(king_hud):
				king_hud.visible = true
			_update_king_hp_label()
			print("VOID KING V44: PHASE TWO ACTIVE / hp=", hp, "/", max_hp, " / location=", global_position)
		queue_redraw()


func _level6_on_second_area_entered(body: Node2D) -> void:
	if not level6_mode or level6_stage != Level6Stage.CLIMB or not body.is_in_group(&"player"):
		return
	if level6_second_markers.is_empty():
		_level6_rebind_upper_nodes()
	if level6_second_markers.is_empty():
		if not level6_phase2_missing_markers_warned:
			level6_phase2_missing_markers_warned = true
			push_warning("VOID KING V46: zero upper markers found. Expected 2phasebosspawns(2...7) or 2phasebossspawns.")
		return
	level6_phase2_missing_markers_warned = false
	for void_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if void_node.has_method(&"begin_rising"):
			void_node.call(&"begin_rising")
	level6_phase2_shake_duration = maxf(1.0, level6_phase2_shake_seconds)
	_level6_end_title()
	level6_stage = Level6Stage.SECOND_WAIT
	level6_stage_timer = level6_phase2_shake_duration
	print("VOID KING V48: upper arena reached; no title, just crescendo shake and boss reveal")
	level6_shake_cam = _level6_find_battle_camera()
	if is_instance_valid(level6_shake_cam):
		if not level6_camera_initialized:
			level6_camera_initialized = true
			level6_original_cam_offset = level6_shake_cam.offset
			level6_camera_base_zoom = level6_shake_cam.zoom
		level6_shake_cam.zoom = level6_camera_base_zoom * level6_camera_zoom_factor
		level6_shake_cam.offset = Vector2.ZERO
		level6_shake_cam.reset_smoothing()
	level6_second_reveal = false
	level6_phase2_start_logged = true
	king_tp_phase = 0
	sprite.visible = false
	if is_instance_valid(king_hud):
		king_hud.visible = false
	print("VOID KING V43: UPPER ARENA TRIGGERED; starting 2-second shake. Player=", body.global_position, " markers=", level6_second_markers.size(), " area=", is_instance_valid(level6_second_identifier))
	if not is_instance_valid(level6_shake_cam):
		push_warning("VOID KING V43: no Camera2D found; timer/reveal continue without shake")


func _level6_point_inside_area(area: Area2D, world_point: Vector2) -> bool:
	if not is_instance_valid(area):
		return false
	for node: Node in area.find_children("*", "CollisionShape2D", true, false):
		var shape_node: CollisionShape2D = node as CollisionShape2D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var relative: Vector2 = shape_node.global_transform.affine_inverse() * world_point
		if shape_node.shape is RectangleShape2D:
			var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
			if absf(relative.x) <= rect.size.x * 0.5 + 14.0 and absf(relative.y) <= rect.size.y * 0.5 + 18.0:
				return true
		elif shape_node.shape is CircleShape2D:
			var circle: CircleShape2D = shape_node.shape as CircleShape2D
			if relative.length_squared() <= pow(circle.radius + 18.0, 2.0):
				return true
		elif shape_node.shape is CapsuleShape2D:
			var capsule: CapsuleShape2D = shape_node.shape as CapsuleShape2D
			var limit_y: float = maxf(0.0, capsule.height * 0.5 - capsule.radius)
			var dist: float = (relative - Vector2(0.0, clampf(relative.y, -limit_y, limit_y))).length()
			if dist <= capsule.radius + 16.0:
				return true
	return false


func _level6_phase2_marker_near_player() -> Marker2D:
	var best: Marker2D = null
	var best_score: float = INF
	var view: Rect2 = _king_visible_world_rect()
	for marker: Marker2D in level6_second_markers:
		if not is_instance_valid(marker):
			continue
		var spawn_at: Vector2 = _level6_marker_position(marker)
		var score: float = spawn_at.distance_squared_to(target.global_position) if is_instance_valid(target) else 0.0
		if view.grow(-60.0).has_point(spawn_at):
			score *= 0.18
		if score < best_score:
			best_score = score
			best = marker
	return best


func _level6_artifact_bind_player() -> void:
	if not level6_mode or not level6_artifact_mercy_enabled:
		return
	if not is_instance_valid(target):
		return
	if _level6_artifact_bound_player == target:
		return
	if is_instance_valid(_level6_artifact_bound_player):
		var old_callback: Callable = Callable(self, "_level6_artifact_on_health_changed")
		if _level6_artifact_bound_player.is_connected(&"vida_alterada", old_callback):
			_level6_artifact_bound_player.disconnect(&"vida_alterada", old_callback)
	_level6_artifact_bound_player = target
	if target.has_signal(&"vida_alterada"):
		var callback: Callable = Callable(self, "_level6_artifact_on_health_changed")
		if not target.is_connected(&"vida_alterada", callback):
			target.connect(&"vida_alterada", callback)


func _level6_artifact_fight_has_begun() -> bool:
	return level6_mode and level6_stage in [
		Level6Stage.PHASE_ONE, Level6Stage.DISSOLVE_ONE,
		Level6Stage.CLIMB, Level6Stage.SECOND_WAIT,
		Level6Stage.PHASE_TWO, Level6Stage.DISSOLVE_TWO,
		Level6Stage.PHASE_THREE_PENDING, Level6Stage.PHASE_THREE_CLIMB,
		Level6Stage.THIRD_REVEAL, Level6Stage.PHASE_THREE
	]


func _level6_artifact_rescue_floor() -> Dictionary:
	for abyss: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if abyss.has_method(&"get_artifact_rescue_checkpoint"):
			var floor_result: Variant = abyss.call(&"get_artifact_rescue_checkpoint")
			if floor_result is Dictionary:
				var grounded_rescue: Dictionary = floor_result
				if grounded_rescue.has("position"):
					return grounded_rescue
	return {}


func _level6_artifact_on_health_changed(current_hp: int, _maximum_hp: int) -> void:
	if current_hp > 0 or not level6_artifact_mercy_enabled:
		return
	if _collapse_step != 0 and level6_stage == Level6Stage.THIRD_DEATH:
		return
	if _level6_artifact_rescue_active or not _level6_artifact_fight_has_begun():
		return
	if not is_instance_valid(target):
		return

	var used_all_saves: bool = _level6_artifact_saves_used >= level6_artifact_mercy_max_saves
	var checkpoint: Dictionary = {}
	if not used_all_saves:
		checkpoint = _level6_artifact_rescue_floor()
		if not checkpoint.has("position"):
			push_warning("KING MERCY: no grounded checkpoint in RisingVoid; normal Level 6 death will proceed.")
			return

	_level6_artifact_rescue_active = true
	_level6_artifact_awaiting_restart = used_all_saves
	if not used_all_saves:
		_level6_artifact_saves_used += 1
	Global.curar(999)
	if int(Global.vida_atual) <= 0:
		Global.reiniciar_vida()
	target.set("vida", int(Global.vida_atual))
	target.set("tempo_invulneravel_restante", 9999.0)
	target.set_meta(&"king_artifact_rescue_active", true)
	target.velocity = Vector2.ZERO

	_level6_artifact_prev_tree_paused = get_tree().paused
	_level6_artifact_create_screen()
	get_tree().paused = true

	if used_all_saves:
		_level6_artifact_message = "...\nDesta vez, nenhuma relíquia respondeu."
	else:
		match _level6_artifact_saves_used:
			1:
				_level6_artifact_message = "...\nAs relíquias te protegeram desta vez."
			2:
				_level6_artifact_message = "...\nElas ainda não te deixaram partir."
			_:
				_level6_artifact_message = "...\nO último brilho está se apagando."
	_level6_artifact_run_scene(checkpoint)
	print("VOID KING ARTIFACT MERCY: save ", _level6_artifact_saves_used,
		"/", level6_artifact_mercy_max_saves, " / restart=", used_all_saves)


func _level6_artifact_create_screen() -> void:
	if is_instance_valid(_level6_artifact_overlay):
		return
	_level6_artifact_overlay = CanvasLayer.new()
	_level6_artifact_overlay.name = "KingArtifactMercyScreen"
	_level6_artifact_overlay.layer = 3500
	_level6_artifact_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_level6_artifact_overlay)
	_level6_artifact_screen = ColorRect.new()
	_level6_artifact_screen.color = Color.BLACK
	_level6_artifact_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_level6_artifact_overlay.add_child(_level6_artifact_screen)
	_level6_artifact_label = Label.new()
	_level6_artifact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level6_artifact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level6_artifact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level6_artifact_label.add_theme_font_size_override("font_size", 30)
	_level6_artifact_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.93))
	_level6_artifact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level6_artifact_overlay.add_child(_level6_artifact_label)
	_level6_artifact_resize_screen()
	if not get_viewport().size_changed.is_connected(_level6_artifact_resize_screen):
		get_viewport().size_changed.connect(_level6_artifact_resize_screen)


func _level6_artifact_resize_screen() -> void:
	if not is_instance_valid(_level6_artifact_screen):
		return
	var screen_size: Vector2 = get_viewport_rect().size
	_level6_artifact_screen.position = Vector2.ZERO
	_level6_artifact_screen.size = screen_size
	_level6_artifact_label.position = Vector2(screen_size.x * 0.10, screen_size.y * 0.28)
	_level6_artifact_label.size = Vector2(screen_size.x * 0.80, screen_size.y * 0.42)


func _level6_artifact_run_scene(checkpoint: Dictionary) -> void:
	_level6_artifact_label.text = _level6_artifact_message
	_level6_artifact_label.visible_characters = 0
	await get_tree().create_timer(level6_artifact_silent_black_seconds, true).timeout
	if not is_instance_valid(_level6_artifact_label):
		return
	var amount: int = _level6_artifact_message.length()
	for i: int in range(amount):
		if not is_instance_valid(_level6_artifact_label):
			return
		_level6_artifact_label.visible_characters = i + 1
		var c: String = _level6_artifact_message.substr(i, 1)
		var speed: float = maxf(1.0, level6_artifact_text_speed)
		var interval: float = 1.0 / speed
		if c in [".", "!", "?", ":"]:
			interval += 0.18
		await get_tree().create_timer(interval, true).timeout
	await get_tree().create_timer(level6_artifact_black_hold, true).timeout

	if _level6_artifact_awaiting_restart:
		get_tree().paused = false
		Global.reiniciar_vida()
		get_tree().reload_current_scene()
		return

	if is_instance_valid(target) and checkpoint.has("position"):
		target.global_position = checkpoint["position"]
		target.velocity = Vector2.ZERO
		if target.has_method(&"_resetar_queda_profunda"):
			target.call(&"_resetar_queda_profunda")
		target.reset_physics_interpolation()
		target.apply_floor_snap()

	_level6_clear_attacks()
	level6_third_warnings.clear()
	if is_instance_valid(target):
		target.set("vida", int(Global.vida_atual))
		target.set("estado", 0)
		target.set("tempo_invulneravel_restante", level6_artifact_safe_grace)
		target.set_meta(&"king_artifact_rescue_active", false)
		if target.has_signal(&"vida_alterada"):
			target.emit_signal(&"vida_alterada", int(target.get("vida")), int(target.get("vida_maxima")))

	await get_tree().create_timer(level6_artifact_after_rescue_black_seconds, true).timeout
	if not is_instance_valid(_level6_artifact_screen) or not is_instance_valid(_level6_artifact_label):
		return
	var fade: Tween = create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_parallel(true)
	fade.tween_property(_level6_artifact_screen, "color:a", 0.0, 0.65)
	fade.tween_property(_level6_artifact_label, "modulate:a", 0.0, 0.55)
	await fade.finished

	get_tree().paused = _level6_artifact_prev_tree_paused
	_level6_artifact_rescue_active = false
	if is_instance_valid(_level6_artifact_overlay):
		_level6_artifact_overlay.queue_free()
	_level6_artifact_overlay = null
	_level6_artifact_screen = null
	_level6_artifact_label = null


func _level6_on_boss_area_entered(body: Node2D) -> void:
	if _level6_wander_active:
		return
	if level6_mode and level6_stage == Level6Stage.HIDDEN and body.is_in_group(&"player"):
		level6_stage = Level6Stage.WAITING
		level6_stage_timer = maxf(3.8, level6_entrance_delay)


func _level6_wander_update(delta: float) -> void:
	if not _level6_wander_active or not level6_mode:
		return
	_level6_wander_dialogue_tick(delta)
	if _level6_wander_completed or level6_stage != Level6Stage.HIDDEN:
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if not is_instance_valid(target):
		return
	var inside_2: bool = (_level6_wander_area2.overlaps_body(target)
		or _level6_point_inside_area(_level6_wander_area2, target.global_position))
	var inside_1: bool = (_level6_wander_area1.overlaps_body(target)
		or _level6_point_inside_area(_level6_wander_area1, target.global_position))

	if _level6_wander_2_first_visit and target.global_position.distance_to(
		_level6_wander_first_contact) > 170.0:
		_level6_wander_left_first_contact = true
	var returned_to_start: bool = (_level6_wander_2_first_visit
		and _level6_wander_1_visited and _level6_wander_left_first_contact
		and target.global_position.distance_to(_level6_wander_first_contact) < 65.0)
	if (inside_2 and not _level6_wander_2_inside_last) or returned_to_start:
		if not _level6_wander_2_first_visit:
			_level6_wander_2_first_visit = true
			_level6_wander_first_contact = target.global_position
			_level6_wander_seal_retreat()
			_level6_wander_queue_lines([
				"A subida termina aqui. Não há mais caminho.",
                "As relíquias abriram este lugar. Mas para quê?"
			])
			print("KING ENTRANCE: wanderarea2 first visit; Void seals retreat")
		elif _level6_wander_1_visited:
			_level6_wander_completed = true
			level6_stage = Level6Stage.WAITING
			level6_stage_timer = maxf(9.0, level6_wander_awakening_delay)
			_level6_wander_queue_lines([
				"A passagem por onde entrei... sumiu.",
                "Então era isso que estavam tentando manter fechado."
			])
			print("KING ENTRANCE: W2 -> W1 -> W2 completed; awakening countdown started")
	_level6_wander_2_inside_last = inside_2

	if (inside_1 and _level6_wander_2_first_visit and not _level6_wander_1_visited
		and target.global_position.distance_to(_level6_wander_first_contact) > 140.0):
		_level6_wander_1_visited = true
		_level6_wander_queue_lines([
			"As marcas nas paredes são as mesmas das relíquias.",
            "Não fizeram esta sala para receber alguém."
		])
		print("KING ENTRANCE: wanderarea1 visited; return to wanderarea2")
	_level6_wander_1_inside_last = inside_1


func _level6_wander_seal_retreat() -> void:
	if level6_wander_block_retreat:
		_level6_wander_make_retreat_wall()
	for abyss_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if abyss_node.has_method(&"seal_boss_arena_entrance"):
			abyss_node.call(&"seal_boss_arena_entrance", target)
		else:
			push_warning("KING ENTRANCE: RisingVoid needs V19 for first-arena seal rise.")


func _level6_wander_make_retreat_wall() -> void:
	if is_instance_valid(_level6_wander_retreat_wall) or not is_instance_valid(target):
		return
	var arena_direction: float = 1.0
	if is_instance_valid(_level6_wander_area1) and is_instance_valid(_level6_wander_area2):
		var from_entry_to_far: float = (
			_level6_wander_area1.global_position.x
			- _level6_wander_area2.global_position.x
		)
		if absf(from_entry_to_far) >= 24.0:
			arena_direction = signf(from_entry_to_far)
		elif absf(global_position.x - _level6_wander_area2.global_position.x) >= 24.0:
			arena_direction = signf(global_position.x - _level6_wander_area2.global_position.x)

	var entry_edges: Vector2 = _level6_wander_area_x_bounds(_level6_wander_area2)
	var far_edges: Vector2 = _level6_wander_area_x_bounds(_level6_wander_area1)
	var retreat_outer_edge: float
	if arena_direction > 0.0:
		retreat_outer_edge = minf(entry_edges.x, far_edges.x)
	else:
		retreat_outer_edge = maxf(entry_edges.y, far_edges.y)

	var collision_height: float = maxf(200000.0, level6_wander_retreat_wall_height)
	var collision_width: float = 112.0
	_level6_wander_retreat_wall = StaticBody2D.new()
	_level6_wander_retreat_wall.name = "KingArenaSealedEntrance"
	var player_mask: int = target.collision_mask
	_level6_wander_retreat_wall.collision_layer = player_mask if player_mask != 0 else 1
	_level6_wander_retreat_wall.collision_mask = 0

	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var wall_rect: RectangleShape2D = RectangleShape2D.new()
	wall_rect.size = Vector2(collision_width, collision_height)
	wall_shape.shape = wall_rect
	_level6_wander_retreat_wall.add_child(wall_shape)

	var wall_visual: Polygon2D = Polygon2D.new()
	var visual_half_height: float = minf(collision_height * 0.5, 10000.0)
	var visual_half_width: float = collision_width * 0.5
	wall_visual.polygon = PackedVector2Array([
		Vector2(-visual_half_width, -visual_half_height),
		Vector2(visual_half_width, -visual_half_height),
		Vector2(visual_half_width, visual_half_height),
		Vector2(-visual_half_width, visual_half_height)
	])
	wall_visual.color = Color(0.005, 0.006, 0.011, 0.77)
	wall_visual.z_index = 35
	_level6_wander_retreat_wall.add_child(wall_visual)

	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		scene_root = get_parent()
	scene_root.add_child(_level6_wander_retreat_wall)
	_level6_wander_retreat_wall.add_to_group("king_arena_seal")
	var outside_margin: float = maxf(35.0, level6_wander_retreat_wall_distance)
	var barrier_center_x: float = (
		retreat_outer_edge - arena_direction * (
			collision_width * 0.5 + outside_margin
		)
	)
	var minimum_player_clearance: float = collision_width * 0.5 + 80.0
	if arena_direction > 0.0:
		barrier_center_x = minf(
			barrier_center_x, target.global_position.x - minimum_player_clearance
		)
	else:
		barrier_center_x = maxf(
			barrier_center_x, target.global_position.x + minimum_player_clearance
		)
	_level6_wander_retreat_wall.global_position = Vector2(
		barrier_center_x, target.global_position.y - 60.0
	)
	print(
		"KING ENTRANCE: solid seal OUTSIDE arena at x=", barrier_center_x,
		" | entrance side=", "left" if arena_direction > 0.0 else "right"
	)

	_level6_wander_create_opposite_wall(
		arena_direction, entry_edges, far_edges,
		collision_width, collision_height, outside_margin,
		minimum_player_clearance, scene_root, player_mask
	)


func _level6_wander_create_opposite_wall(
	original_arena_direction: float,
	entry_edges: Vector2,
	far_edges: Vector2,
	collision_width: float,
	collision_height: float,
	outside_margin: float,
	minimum_player_clearance: float,
	scene_root: Node,
	player_mask: int
) -> void:
	if is_instance_valid(_level6_wander_opposite_wall):
		return
	if not is_instance_valid(target) or not is_instance_valid(scene_root):
		return

	var opposite_direction: float = -original_arena_direction
	var outer_edge: float = (
		minf(entry_edges.x, far_edges.x)
		if opposite_direction > 0.0
		else maxf(entry_edges.y, far_edges.y)
	)
	var opposite_x: float = (
		outer_edge - opposite_direction * (collision_width * 0.5 + outside_margin)
	)
	if opposite_direction > 0.0:
		opposite_x = minf(
			opposite_x, target.global_position.x - minimum_player_clearance
		)
	else:
		opposite_x = maxf(
			opposite_x, target.global_position.x + minimum_player_clearance
		)

	var wall: StaticBody2D = StaticBody2D.new()
	wall.name = (
        "KingArenaSealedLeft"
		if opposite_direction > 0.0
		else "KingArenaSealedRight"
	)
	wall.collision_layer = player_mask if player_mask != 0 else 1
	wall.collision_mask = 0

	var solid_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(collision_width, collision_height)
	solid_shape.shape = rectangle
	wall.add_child(solid_shape)

	var visual: Polygon2D = Polygon2D.new()
	var half_height: float = minf(collision_height * 0.5, 10000.0)
	var half_width: float = collision_width * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height)
	])
	visual.color = Color(0.005, 0.006, 0.011, 0.77)
	visual.z_index = 35
	wall.add_child(visual)

	scene_root.add_child(wall)
	wall.add_to_group("king_arena_seal")
	wall.global_position = Vector2(
		opposite_x, target.global_position.y - 60.0
	)
	_level6_wander_opposite_wall = wall
	print(
		"KING ENTRANCE V86: restored ",
		"LEFT" if opposite_direction > 0.0 else "RIGHT",
		" barrier at x=", opposite_x,
        " | both arena boundaries now sealed"
	)


func _level6_wander_area_x_bounds(arena_area: Area2D) -> Vector2:
	if not is_instance_valid(arena_area):
		return Vector2(target.global_position.x, target.global_position.x)

	var left_edge: float = INF
	var right_edge: float = -INF
	for child_node: Node in arena_area.find_children(
		"*", "CollisionShape2D", true, false
	):
		var collision_node: CollisionShape2D = child_node as CollisionShape2D
		if collision_node == null or collision_node.disabled or collision_node.shape == null:
			continue
		if collision_node.shape is RectangleShape2D:
			var rectangle: RectangleShape2D = collision_node.shape as RectangleShape2D
			var half_size: Vector2 = rectangle.size * 0.5
			for horizontal_sign: float in [-1.0, 1.0]:
				for vertical_sign: float in [-1.0, 1.0]:
					var corner: Vector2 = collision_node.to_global(Vector2(
						horizontal_sign * half_size.x,
						vertical_sign * half_size.y
					))
					left_edge = minf(left_edge, corner.x)
					right_edge = maxf(right_edge, corner.x)
		elif collision_node.shape is CircleShape2D:
			var circle: CircleShape2D = collision_node.shape as CircleShape2D
			var half_width: float = circle.radius * maxf(
				absf(collision_node.global_transform.x.x),
				absf(collision_node.global_transform.y.x)
			)
			left_edge = minf(left_edge, collision_node.global_position.x - half_width)
			right_edge = maxf(right_edge, collision_node.global_position.x + half_width)
		else:
			left_edge = minf(left_edge, collision_node.global_position.x)
			right_edge = maxf(right_edge, collision_node.global_position.x)

	if left_edge == INF or right_edge == -INF:
		return Vector2(arena_area.global_position.x, arena_area.global_position.x)
	return Vector2(left_edge, right_edge)

func _level6_wander_queue_lines(lines: Array) -> void:
	for line_text: Variant in lines:
		_level6_wander_dialogue_queue.append(String(line_text))
	_level6_wander_create_dialogue()


func _level6_wander_create_dialogue() -> void:
	if is_instance_valid(_level6_wander_dialogue_layer):
		return
	_level6_wander_dialogue_layer = CanvasLayer.new()
	_level6_wander_dialogue_layer.name = "KingEntranceDialogue"
	_level6_wander_dialogue_layer.layer = 800
	add_child(_level6_wander_dialogue_layer)

	_level6_wander_dialogue_panel = Control.new()
	_level6_wander_dialogue_panel.name = "ArrivalStyleTextFade"
	_level6_wander_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level6_wander_dialogue_layer.add_child(_level6_wander_dialogue_panel)

	_level6_wander_dialogue_text = Label.new()
	_level6_wander_dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level6_wander_dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level6_wander_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level6_wander_dialogue_text.add_theme_font_size_override("font_size", 27)
	_level6_wander_dialogue_text.add_theme_color_override(
		"font_color", Color(0.84, 0.84, 0.88)
	)
	_level6_wander_dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level6_wander_dialogue_panel.add_child(_level6_wander_dialogue_text)

	_level6_wander_dialogue_glyph_left = Label.new()
	_level6_wander_dialogue_glyph_left.text = "─◆"
	_level6_wander_dialogue_glyph_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level6_wander_dialogue_glyph_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level6_wander_dialogue_glyph_left.add_theme_font_size_override("font_size", 19)
	_level6_wander_dialogue_glyph_left.add_theme_color_override(
		"font_color", Color(0.36, 0.45, 0.62, 0.78)
	)
	_level6_wander_dialogue_glyph_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level6_wander_dialogue_panel.add_child(_level6_wander_dialogue_glyph_left)

	_level6_wander_dialogue_glyph_right = Label.new()
	_level6_wander_dialogue_glyph_right.text = "◆─"
	_level6_wander_dialogue_glyph_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level6_wander_dialogue_glyph_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level6_wander_dialogue_glyph_right.add_theme_font_size_override("font_size", 19)
	_level6_wander_dialogue_glyph_right.add_theme_color_override(
		"font_color", Color(0.36, 0.45, 0.62, 0.78)
	)
	_level6_wander_dialogue_glyph_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level6_wander_dialogue_panel.add_child(_level6_wander_dialogue_glyph_right)

	_level6_wander_layout_dialogue()
	if not get_viewport().size_changed.is_connected(_level6_wander_layout_dialogue):
		get_viewport().size_changed.connect(_level6_wander_layout_dialogue)
	_level6_wander_dialogue_panel.visible = false
	_level6_wander_dialogue_panel.modulate.a = 0.0


func _level6_wander_layout_dialogue() -> void:
	if not is_instance_valid(_level6_wander_dialogue_panel):
		return
	var view_size: Vector2 = get_viewport_rect().size
	_level6_wander_dialogue_panel.position = Vector2.ZERO
	_level6_wander_dialogue_panel.size = view_size

	_level6_wander_dialogue_text.position = Vector2(
		view_size.x * 0.10, view_size.y * 0.70
	)
	_level6_wander_dialogue_text.size = Vector2(
		view_size.x * 0.80, view_size.y * 0.19
	)
	var glyph_y: float = view_size.y * 0.755
	if is_instance_valid(_level6_wander_dialogue_glyph_left):
		_level6_wander_dialogue_glyph_left.position = Vector2(
			view_size.x * 0.065, glyph_y
		)
		_level6_wander_dialogue_glyph_left.size = Vector2(view_size.x * 0.095, 48.0)
	if is_instance_valid(_level6_wander_dialogue_glyph_right):
		_level6_wander_dialogue_glyph_right.position = Vector2(
			view_size.x * 0.84, glyph_y
		)
		_level6_wander_dialogue_glyph_right.size = Vector2(view_size.x * 0.095, 48.0)

func _level6_wander_dialogue_tick(delta: float) -> void:
	if not _level6_wander_dialogue_showing:
		if _level6_wander_dialogue_queue.is_empty():
			_level6_wander_hide_dialogue()
			return
		_level6_wander_dialogue_line = _level6_wander_dialogue_queue.pop_front()
		_level6_wander_dialogue_elapsed = 0.0
		_level6_wander_dialogue_showing = true
		_level6_wander_create_dialogue()
		_level6_wander_dialogue_text.text = _level6_wander_dialogue_line
		_level6_wander_dialogue_text.visible_characters = 0
		_level6_wander_dialogue_panel.visible = true
		_level6_wander_dialogue_panel.modulate.a = 0.0
		return
	_level6_wander_dialogue_elapsed += delta
	var total_chars: int = _level6_wander_dialogue_line.length()
	var printed_chars: int = mini(total_chars,
		int(_level6_wander_dialogue_elapsed * level6_wander_letters_per_second))
	_level6_wander_dialogue_text.visible_characters = printed_chars
	var display_duration: float = float(total_chars) / maxf(1.0, level6_wander_letters_per_second)
	var total_duration: float = display_duration + level6_wander_dialogue_hold
	var fade_in: float = clampf(_level6_wander_dialogue_elapsed / 0.42, 0.0, 1.0)
	var fade_out: float = clampf((total_duration - _level6_wander_dialogue_elapsed) / 0.48, 0.0, 1.0)
	_level6_wander_dialogue_panel.modulate.a = minf(fade_in, fade_out)
	if _level6_wander_dialogue_elapsed >= total_duration:
		_level6_wander_dialogue_showing = false
		if _level6_wander_dialogue_queue.is_empty():
			_level6_wander_hide_dialogue()


func _level6_wander_hide_dialogue() -> void:
	if is_instance_valid(_level6_wander_dialogue_panel):
		_level6_wander_dialogue_panel.visible = false


func _level6_wander_early_earthquake() -> void:
	if not _level6_wander_active or not _level6_wander_completed:
		return
	var lead: float = maxf(0.1, level6_wander_pre_shake_seconds)
	if level6_stage_timer > lead:
		return
	var camera: Camera2D = _level6_find_battle_camera()
	if not is_instance_valid(camera):
		return
	var progress: float = clampf(1.0 - maxf(0.0, level6_stage_timer) / lead, 0.0, 1.0)
	var power: float = level6_wander_pre_shake_strength * pow(progress, 1.7)
	camera.offset = level6_original_cam_offset + Vector2(
		randf_range(-power, power), randf_range(-power, power))


func _level6_camera_tick(delta: float) -> void:
	var cam: Camera2D = _level6_find_battle_camera()
	if not is_instance_valid(cam):
		return
	if not level6_camera_initialized:
		level6_camera_initialized = true
		level6_original_cam_offset = cam.offset
		level6_camera_base_zoom = cam.zoom
	var boss_framing: bool = level6_stage in [
		Level6Stage.INTRO_TITLE, Level6Stage.SECOND_TITLE,
		Level6Stage.SHAKING, Level6Stage.REVEAL, Level6Stage.PHASE_ONE,
		Level6Stage.SECOND_WAIT, Level6Stage.PHASE_TWO, Level6Stage.DISSOLVE_TWO,
		Level6Stage.THIRD_REVEAL, Level6Stage.PHASE_THREE, Level6Stage.THIRD_DEATH
	]
	var phase2_centered: bool = _level6_phase_two_framing() or level6_stage in [
		Level6Stage.THIRD_REVEAL, Level6Stage.PHASE_THREE, Level6Stage.THIRD_DEATH]
	if level6_stage == Level6Stage.THIRD_DEATH and _collapse_step >= 2:
		boss_framing = false
		phase2_centered = false
	var desired_offset: Vector2 = (Vector2.ZERO if phase2_centered else
		(level6_original_cam_offset + Vector2(0.0, -level6_camera_upward_pixels) if boss_framing else level6_original_cam_offset))
	var desired_zoom: Vector2 = level6_camera_base_zoom * (level6_camera_zoom_factor if boss_framing else 1.0)
	cam.zoom = cam.zoom.lerp(desired_zoom, minf(1.0, delta * 2.0))
	if level6_stage not in [Level6Stage.SHAKING, Level6Stage.SECOND_WAIT]:
		cam.offset = cam.offset.lerp(desired_offset, minf(1.0, delta * 3.0))


func _level6_begin_shake() -> void:
	level6_stage = Level6Stage.SHAKING
	level6_stage_timer = (
		maxf(level6_entrance_shake_v37_seconds, level6_wander_final_shake_seconds)
		if _level6_wander_active and _level6_wander_completed
		else maxf(0.5, level6_entrance_shake_v37_seconds)
	)
	level6_shake_cam = get_viewport().get_camera_2d()
	if is_instance_valid(level6_shake_cam) and not level6_camera_initialized:
		level6_camera_initialized = true
		level6_original_cam_offset = level6_shake_cam.offset
		level6_camera_base_zoom = level6_shake_cam.zoom


func _level6_stop_shake() -> void:
	if is_instance_valid(level6_shake_cam):
		level6_shake_cam.offset = Vector2.ZERO if _level6_phase_two_framing() else level6_original_cam_offset + Vector2(0.0, -level6_camera_upward_pixels)
	level6_shake_cam = null


func _level6_center_phase_one_marker() -> Marker2D:
	if level6_first_markers.is_empty():
		return null
	var average_x: float = 0.0
	for marker2: Marker2D in level6_first_markers:
		average_x += marker2.global_position.x
	average_x /= float(level6_first_markers.size())
	var best: Marker2D = level6_first_markers[0]
	for marker2: Marker2D in level6_first_markers:
		if absf(marker2.global_position.x - average_x) < absf(best.global_position.x - average_x):
			best = marker2
	return best


func _level6_reveal_phase_one() -> void:
	_level6_stop_shake()
	level6_stage = Level6Stage.REVEAL
	level6_stage_timer = (
		maxf(king_teleport_reappear_seconds, level6_wander_reveal_seconds)
		if _level6_wander_active and _level6_wander_completed
		else maxf(0.30, king_teleport_reappear_seconds)
	)
	var center_marker: Marker2D = _level6_center_phase_one_marker()
	if is_instance_valid(center_marker):
		global_position = _level6_marker_position(center_marker)
		level6_current_marker = center_marker
	else:
		push_warning("KING V36: No phase-one markers, appearing at placed boss position.")
	reset_physics_interpolation()
	sprite.visible = true
	if is_instance_valid(king_crown_root):
		king_crown_root.visible = true
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.visible = true
		level6_aura_particles.emitting = true
	if is_instance_valid(level6_aura_sprite):
		level6_aura_sprite.visible = true
	_king_set_teleport_death_frame(1.0)
	_update_king_hp_label()
	if is_instance_valid(king_hud):
		king_hud.visible = true


func _level6_begin_phase_one() -> void:
	level6_stage = Level6Stage.PHASE_ONE
	level6_perch_timer = maxf(2.5, level6_marker_hold_seconds)
	state = State.GUARDED
	max_hp = maxi(20, level6_first_phase_hp_v37 + level6_phase_hp_bonus_v48)
	hp = max_hp
	king_shield_phase = KingShieldPhase.SOLO
	king_shield_countdown = -1.0
	level6_attack_timer = 1.5
	level6_attack_round = 0
	_play(&"idle", true)
	_update_king_hp_label()
	health_changed.emit(hp, max_hp)


func _level6_begin_guard() -> void:
	if level6_guard_started:
		return
	level6_guard_started = true
	king_shield_phase = KingShieldPhase.SHIELDED
	king_shield_hit_fx = king_shield_hit_pulse_duration
	king_elite_total_waves = 1
	king_elite_waves_spawned = 0
	king_elite_guards.clear()
	king_shield_elite_spawned = false
	level6_guard_retry = 0.0
	level6_guard_summon_timer = 1.1
	king_guard_attack_timer = maxf(10.0, level6_guard_spell_interval)
	level6_attack_timer = maxf(9.0, level6_guard_spell_interval)
	king_shield_countdown = -1.0
	king_post_attack_timer = 2.0
	_level6_clear_attacks()
	_play(&"idle", true)
	_update_king_hp_label()
	queue_redraw()


func _level6_try_guard_spawn() -> void:
	if king_elite_waves_spawned >= 1:
		return
	if _try_spawn_king_elite():
		king_shield_elite_spawned = true
		king_guard_attack_timer = maxf(10.0, level6_guard_spell_interval)
		level6_attack_timer = maxf(9.0, level6_guard_spell_interval)
		_play(&"idle", true)
	else:
		level6_guard_retry = 1.25


func _level6_clear_attacks() -> void:
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	king_skull_walls.clear()
	king_wall_spawn_remaining = 0
	level6_void_swords.clear()
	level6_void_walls.clear()
	level6_dash_echoes.clear()
	level6_skull_shots_left = 0
	_clear_king_gravefall()
	level6_attack_timer = 2.0
	king_attack_cast_remaining = 0.0
	king_gravefall_active = false


func _level6_start_dissolving(first: bool) -> void:
	level6_stage = Level6Stage.DISSOLVE_ONE if first else Level6Stage.DISSOLVE_TWO
	level6_stage_timer = maxf(2.50 if first else 2.25, level6_dissolve_seconds)
	_level6_clear_attacks()
	king_tp_phase = 0
	velocity = Vector2.ZERO
	king_shield_phase = KingShieldPhase.EXPOSED
	_level6_emit_burst()
	sprite.visible = true
	_play(&"death", true)
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.emitting = false
	if is_instance_valid(level6_aura_sprite):
		level6_aura_sprite.visible = false
	if is_instance_valid(king_crown_root):
		king_crown_root.visible = false
	queue_redraw()


func _level6_emit_burst() -> void:
	var parent2: Node = get_parent()
	if parent2 == null:
		parent2 = get_tree().current_scene
	if parent2 == null:
		return
	var origin: Vector2 = global_position
	var arrival: Vector2 = origin + Vector2(0.0, -680.0)
	if level6_stage == Level6Stage.DISSOLVE_ONE and not level6_second_markers.is_empty():
		var sum_positions: Vector2 = Vector2.ZERO
		for point: Marker2D in level6_second_markers:
			sum_positions += point.global_position
		arrival = sum_positions / float(level6_second_markers.size()) + Vector2(0.0, -95.0)
	elif level6_stage == Level6Stage.DISSOLVE_TWO and not level6_third_markers.is_empty():
		var third_sum: Vector2 = Vector2.ZERO
		var third_count: int = 0
		for point: Marker2D in level6_third_markers:
			if is_instance_valid(point):
				third_sum += point.global_position
				third_count += 1
		if third_count > 0:
			arrival = third_sum / float(third_count) + Vector2(0.0, -70.0)
	level6_departure_target = arrival
	var tex: Texture2D = _level6_get_particle_texture()
	for i: int in range(56):
		var mote: Sprite2D = Sprite2D.new()
		mote.texture = tex
		mote.z_index = 82
		mote.modulate = Color(0.70, 0.72, 0.80, randf_range(0.40, 0.85)) if i % 6 == 0 else Color(0.015, 0.016, 0.023, 0.98)
		mote.scale = Vector2.ONE * randf_range(0.8, 2.6)
		parent2.add_child(mote)
		mote.global_position = origin + Vector2(randf_range(-22.0, 22.0), randf_range(-24.0, 24.0))
		var angle: float = TAU * float(i) / 56.0 + randf_range(-0.16, 0.16)
		var stop_point: Vector2 = origin + Vector2.RIGHT.rotated(angle) * randf_range(90.0, 240.0)
		var final_point: Vector2 = arrival + Vector2(randf_range(-70.0, 70.0), randf_range(-36.0, 36.0))
		var tween: Tween = mote.create_tween()
		tween.tween_property(mote, "global_position", stop_point, randf_range(0.48, 0.67)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.42)
		tween.tween_property(mote, "global_position", final_point, randf_range(0.85, 1.05)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(mote, "modulate:a", 0.0, 0.75).set_delay(0.20)
		tween.tween_callback(mote.queue_free)


func _level6_enable_climb() -> void:
	level6_stage = Level6Stage.CLIMB
	level6_climb_elapsed = 0.0
	level6_upper_check_log_timer = 0.0
	level6_phase2_start_logged = false
	king_tp_phase = 0
	sprite.visible = false
	_level6_rebind_upper_nodes()
	print("VOID KING V43: CLIMB BEGINS; 2phaseidentifier=", is_instance_valid(level6_second_identifier), " upper markers=", level6_second_markers.size())
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.visible = false
	if is_instance_valid(level6_aura_sprite):
		level6_aura_sprite.visible = false
	if is_instance_valid(king_hud):
		king_hud.visible = false
	if level6_climb_layer != null:
		level6_climb_layer.enabled = true
	for void_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if void_node.has_method(&"start_boss_climb"):
			void_node.call(&"start_boss_climb")
		elif void_node.has_method(&"activate"):
			void_node.call(&"activate")
	if not level6_second_markers.is_empty():
		global_position = _level6_marker_position(level6_second_markers[0])
		level6_current_marker = level6_second_markers[0]
		reset_physics_interpolation()
	queue_redraw()


func _level6_start_second_phase() -> void:
	for void_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if void_node.has_method(&"begin_rising"):
			void_node.call(&"begin_rising")
	level6_stage = Level6Stage.PHASE_TWO
	var level_root: Node = get_tree().current_scene
	if level_root != null:
		level_root.set_meta(&"level6_boss_active", true)
	level6_stage_timer = 0.0
	level6_perch_timer = maxf(2.5, level6_marker_hold_seconds)
	hp = maxi(20, level6_second_phase_hp_v37 + level6_phase_hp_bonus_v48)
	max_hp = hp
	king_shield_phase = KingShieldPhase.EXPOSED
	king_shield_countdown = -1.0
	king_elite_total_waves = 0
	king_max_total_resurrections = 0
	king_total_resurrections = 0
	king_revival_timer = -1.0
	king_revival_started = false
	king_revival_completed = true
	king_revival_cast_fx = 0.0
	king_last_stand_started = true
	king_last_stand_intro_timer = 0.0
	king_final_pattern_round = 0
	king_gravefall_cooldown_timer = 1.2
	level6_attack_timer = 2.1
	level6_attack_round = 0
	_level6_clear_attacks()
	level6_attack_timer = 2.1
	king_post_attack_timer = 1.3
	king_skull_volley_timer = 15.0
	king_tp_phase = 0
	var arrival_marker: Marker2D = _level6_phase2_marker_near_player()
	if is_instance_valid(arrival_marker):
		level6_current_marker = arrival_marker
		global_position = _level6_marker_position(arrival_marker)
		king_tp_destination = global_position
		reset_physics_interpolation()
	else:
		push_error("VOID KING V43: phase-two Marker2D list is empty!")
	king_tp_destination = global_position
	king_tp_hold_remaining = 4.0
	state = State.GUARDED
	sprite.visible = true
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.visible = true
		level6_aura_particles.emitting = true
	if is_instance_valid(level6_aura_sprite):
		level6_aura_sprite.visible = true
	if is_instance_valid(king_crown_root):
		king_crown_root.visible = false
	if is_instance_valid(king_hud):
		king_hud.visible = true
	_king_set_teleport_death_frame(1.0)
	sprite.visible = true
	level6_stage = Level6Stage.REVEAL
	level6_stage_timer = maxf(0.30, king_teleport_reappear_seconds)
	level6_second_reveal = true
	_update_king_hp_label()
	health_changed.emit(hp, max_hp)


var level6_second_reveal: bool = false
var level6_climb_elapsed: float = 0.0
var level6_upper_check_log_timer: float = 0.0
var level6_phase2_start_logged: bool = false
var level6_phase2_missing_markers_warned: bool = false
@export_range(1.0, 4.0, 0.1) var level6_phase2_shake_seconds: float = 2.0
@export_range(0.0, 25.0, 0.5) var level6_phase2_shake_max_pixels: float = 12.0
var level6_phase2_shake_duration: float = 2.0


func _level6_secure_second_marker() -> void:
	if not level6_mode or level6_stage != Level6Stage.PHASE_TWO:
		return
	var valid_points: Array[Marker2D] = []
	for marker: Marker2D in level6_second_markers:
		if is_instance_valid(marker):
			valid_points.append(marker)
	if valid_points.is_empty():
		return
	if not is_instance_valid(level6_current_marker) or not valid_points.has(level6_current_marker):
		level6_current_marker = _level6_phase2_marker_near_player()
	if not is_instance_valid(level6_current_marker):
		level6_current_marker = valid_points[0]
	var destination_ok: bool = false
	for marker: Marker2D in valid_points:
		if king_tp_destination.distance_squared_to(_level6_marker_position(marker)) < 9.0:
			destination_ok = true
			break
	if not destination_ok:
		king_tp_destination = _level6_marker_position(level6_current_marker)
	if king_tp_phase == 0:
		var body_on_marker: bool = false
		for marker: Marker2D in valid_points:
			if global_position.distance_squared_to(_level6_marker_position(marker)) < 36.0:
				body_on_marker = true
				level6_current_marker = marker
				break
		if not body_on_marker:
			global_position = _level6_marker_position(level6_current_marker)
			reset_physics_interpolation()


func _level6_choose_marker() -> void:
	if level6_stage not in [Level6Stage.PHASE_ONE, Level6Stage.PHASE_TWO, Level6Stage.PHASE_THREE]:
		return
	var choices: Array[Marker2D] = []
	if level6_stage == Level6Stage.PHASE_THREE:
		_level6_refresh_third_nodes()
		choices = level6_third_markers
	elif level6_stage == Level6Stage.PHASE_TWO:
		choices = level6_second_markers
	else:
		choices = level6_first_markers
	if choices.is_empty():
		if level6_stage == Level6Stage.PHASE_THREE:
			push_warning("VOID KING V61: Phase-three Marker2D nodes not found; boss will stay in the summit center.")
		return
	var possible: Array[Marker2D] = []
	for m: Marker2D in choices:
		if is_instance_valid(m) and m != level6_current_marker:
			possible.append(m)
	if possible.is_empty():
		possible = choices
	var chosen: Marker2D = possible.pick_random()
	if chosen == null:
		return
	level6_current_marker = chosen
	king_tp_destination = _level6_marker_position(chosen)
	king_tp_phase = 1
	king_tp_elapsed = 0.0
	level6_perch_timer = clampf(level6_marker_hold_seconds, 2.5, 4.0)
	_king_set_teleport_death_frame(0.0)


func _level6_perch_tick(delta: float) -> void:
	if king_tp_phase != 0:
		_update_king_teleport_animation(delta)
		return
	level6_perch_timer -= delta
	if level6_perch_timer <= 0.0:
		_level6_choose_marker()


func _level6_debug_warp_player_to_upper_arena() -> void:
	if not is_instance_valid(target):
		return
	_level6_rebind_upper_nodes()
	if level6_second_markers.is_empty():
		return
	var center: Vector2 = Vector2.ZERO
	for marker: Marker2D in level6_second_markers:
		center += marker.global_position
	center /= float(level6_second_markers.size())
	if is_instance_valid(level6_second_identifier):
		for node: Node in level6_second_identifier.find_children("*", "CollisionShape2D", true, false):
			if node is CollisionShape2D:
				center = (node as CollisionShape2D).global_position
				break

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var found: bool = false
	var landing: Vector2 = center + Vector2(0.0, -90.0)
	var x_offsets: Array[float] = [0.0, 90.0, -90.0, 165.0, -165.0, 250.0, -250.0]
	for dx: float in x_offsets:
		var begin: Vector2 = center + Vector2(dx, -260.0)
		var finish: Vector2 = center + Vector2(dx, 450.0)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(begin, finish, terrain_mask)
		query.exclude = [target.get_rid(), get_rid()]
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		if normal.y > -0.65:
			continue
		var hit_point: Vector2 = hit.get("position", center)
		landing = hit_point + Vector2(0.0, -32.0)
		found = true
		break
	target.global_position = landing
	target.velocity = Vector2.ZERO
	target.reset_physics_interpolation()
	if not found:
		push_warning("VOID KING V53: no upper platform found for debug teleport; check TileMap collisions.")


func _level6_debug_skip_to_phase_two() -> void:
	if level6_stage != Level6Stage.PHASE_ONE:
		return
	_level6_rebind_upper_nodes()
	if level6_second_markers.is_empty():
		push_warning("VOID KING V53: debug skip needs phase-two Marker2D positions.")
		return
	_level6_clear_attacks()
	for guard: CharacterBody2D in king_elite_guards:
		if is_instance_valid(guard) and not guard.is_queued_for_deletion():
			guard.queue_free()
	king_elite_guards.clear()
	king_tp_phase = 0
	level6_stage = Level6Stage.DISSOLVE_ONE
	_level6_emit_burst()
	_level6_enable_climb()
	_level6_debug_warp_player_to_upper_arena()
	_level6_start_second_phase()
	print("VOID KING V53: DEBUG 1 -> PHASE TWO (no climb/shake wait)")


func _level6_debug_skip_to_phase_three() -> void:
	if level6_stage != Level6Stage.PHASE_TWO:
		return
	hp = 0
	health_changed.emit(hp, max_hp)
	_level6_start_dissolving(false)
	level6_stage = Level6Stage.PHASE_THREE_PENDING
	level6_stage_timer = 0.0
	_level6_begin_final_climb()
	print("VOID KING V58: DEBUG 2 -> FINAL ASCENT (phase-three platforms enabled)")


func _level6_update(delta: float) -> void:
	if collision_layer != 0:
		collision_layer = 0
	if collision_mask != 0:
		collision_mask = 0
	_level6_camera_tick(delta)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	_level6_artifact_bind_player()
	var one_down: bool = Input.is_physical_key_pressed(KEY_1)
	if level6_debug_skip_phase_one_with_1 and one_down and not level6_debug_one_was_down:
		_level6_debug_skip_to_phase_two()
	level6_debug_one_was_down = one_down
	var two_down: bool = Input.is_physical_key_pressed(KEY_2)
	if level6_debug_skip_phase_two_with_2 and two_down and not level6_debug_two_was_down:
		_level6_debug_skip_to_phase_three()
	level6_debug_two_was_down = two_down
	_level6_update_screen_darkness(delta)
	if level6_stage in [Level6Stage.PHASE_THREE_CLIMB, Level6Stage.PHASE_THREE]:
		_level6_update_falling_lasers(delta)
	if level6_stage == Level6Stage.HIDDEN:
		if is_instance_valid(level6_arena) and is_instance_valid(target):
			if level6_arena.overlaps_body(target) or _level6_point_inside_area(level6_arena, target.global_position):
				_level6_on_boss_area_entered(target)
		return
	if level6_stage == Level6Stage.WAITING:
		level6_stage_timer -= delta
		_level6_wander_early_earthquake()
		if level6_stage_timer <= 0.0 and (not _level6_wander_active
			or (not _level6_wander_dialogue_showing and _level6_wander_dialogue_queue.is_empty())):
			_level6_wander_hide_dialogue()
			_level6_begin_title(false)
		return
	if level6_stage == Level6Stage.INTRO_TITLE:
		_level6_title_resize()
		level6_stage_timer -= delta
		if level6_stage_timer <= 0.0:
			_level6_end_title()
			_level6_begin_shake()
		return
	if level6_stage == Level6Stage.SHAKING:
		level6_stage_timer -= delta
		if is_instance_valid(level6_shake_cam):
			var full_shake_seconds: float = (
				maxf(level6_entrance_shake_v37_seconds, level6_wander_final_shake_seconds)
				if _level6_wander_active and _level6_wander_completed
				else maxf(0.1, level6_entrance_shake_v37_seconds)
			)
			var progress: float = 1.0 - clampf(level6_stage_timer / full_shake_seconds, 0.0, 1.0)
			var strength: float = level6_entrance_shake_v37_strength * pow(progress, 2.0)
			level6_shake_cam.offset = level6_original_cam_offset + Vector2(0.0, -level6_camera_upward_pixels) + Vector2(
				randf_range(-strength, strength), randf_range(-strength, strength))
		if level6_stage_timer <= 0.0:
			_level6_reveal_phase_one()
		return
	if level6_stage == Level6Stage.REVEAL:
		if level6_second_reveal:
			return
		level6_stage_timer -= delta
		var reveal_seconds: float = (
			maxf(king_teleport_reappear_seconds, level6_wander_reveal_seconds)
			if _level6_wander_active and _level6_wander_completed
			else maxf(0.3, king_teleport_reappear_seconds)
		)
		var fraction: float = 1.0 - clampf(level6_stage_timer / reveal_seconds, 0.0, 1.0)
		_king_set_teleport_death_frame(1.0 - fraction)
		if level6_stage_timer <= 0.0:
			if level6_second_reveal:
				level6_second_reveal = false
				level6_stage = Level6Stage.PHASE_TWO
				level6_perch_timer = maxf(2.5, level6_marker_hold_seconds)
				king_tp_hold_remaining = 4.0
				sprite.visible = true
				_level6_secure_second_marker()
				_play(&"idle", true)
				_update_king_hp_label()
				print("VOID KING V43: upper battle ACTIVE @ ", global_position, " (", level6_second_markers.size(), " upper markers)")
			else:
				_level6_begin_phase_one()
		queue_redraw()
		return
	if level6_stage == Level6Stage.DISSOLVE_ONE or level6_stage == Level6Stage.DISSOLVE_TWO:
		level6_stage_timer -= delta
		if level6_stage_timer <= 0.0:
			if level6_stage == Level6Stage.DISSOLVE_ONE:
				_level6_enable_climb()
			else:
				level6_stage = Level6Stage.PHASE_THREE_PENDING
				level6_stage_timer = maxf(0.25, level6_phase3_laser_start_delay - maxf(2.25, level6_dissolve_seconds))
				sprite.visible = false
				if is_instance_valid(king_hud):
					king_hud.visible = false
				level6_phase_two_finished.emit()
		queue_redraw()
		return
	if level6_stage in [Level6Stage.CLIMB, Level6Stage.SECOND_WAIT, Level6Stage.SECOND_TITLE]:
		return
	if level6_stage == Level6Stage.PHASE_THREE_PENDING:
		level6_stage_timer -= delta
		if level6_stage_timer <= 0.0:
			_level6_begin_final_climb()
		return
	if level6_stage == Level6Stage.PHASE_THREE_CLIMB:
		_level6_update_final_climb(delta)
		return
	if level6_stage == Level6Stage.THIRD_REVEAL:
		_level6_update_third_reveal(delta)
		return
	if level6_stage == Level6Stage.PHASE_THREE:
		_level6_update_third_fight(delta)
		return
	if level6_stage == Level6Stage.THIRD_DEATH:
		_level6_update_final_death(delta)
		return
	if level6_stage == Level6Stage.COMPLETE:
		return
	if level6_stage != Level6Stage.PHASE_ONE and level6_stage != Level6Stage.PHASE_TWO:
		return
	if not is_instance_valid(target):
		return
	if level6_stage == Level6Stage.PHASE_TWO and king_tp_phase == 0 and not level6_second_markers.is_empty():
		var marker_ok: bool = false
		for point: Marker2D in level6_second_markers:
			if is_instance_valid(point) and global_position.distance_to(_level6_marker_position(point)) < 5.0:
				marker_ok = true
				level6_current_marker = point
				break
		if not marker_ok:
			var nearest: Marker2D = level6_second_markers[0]
			for point: Marker2D in level6_second_markers:
				if is_instance_valid(point) and _level6_marker_position(point).distance_squared_to(global_position) < _level6_marker_position(nearest).distance_squared_to(global_position):
					nearest = point
			level6_current_marker = nearest
			global_position = _level6_marker_position(nearest)
			reset_physics_interpolation()

	var dx: float = target.global_position.x - global_position.x
	if absf(dx) > 3.0:
		sprite.flip_h = (dx > 0.0) != sprite_faces_right_by_default
	velocity = Vector2.ZERO
	hover_time += delta
	king_shield_animation_time += delta
	king_black_flash_timer = maxf(0.0, king_black_flash_timer - delta)
	level6_hit_lock = maxf(0.0, level6_hit_lock - delta)
	if is_instance_valid(level6_void_shader):
		level6_void_shader.set_shader_parameter("hit_flash", 1.0 if king_black_flash_timer > 0.0 else 0.0)
	king_shield_hit_fx = maxf(0.0, king_shield_hit_fx - delta)
	king_post_attack_timer = maxf(0.0, king_post_attack_timer - delta)
	king_attack_cast_remaining = maxf(0.0, king_attack_cast_remaining - delta)
	king_exposure_timer = maxf(0.0, king_exposure_timer - delta)
	_level6_secure_second_marker()
	_level6_perch_tick(delta)
	_level6_secure_second_marker()
	_level6_update_void_walls(delta)
	_level6_sword_fallback()
	_level6_update_guard_visuals(delta)
	_level6_update_void_swords(delta)
	_level6_update_dash_echoes(delta)
	_update_skulls(delta)
	_update_king_royal_slashes(delta)

	if is_instance_valid(king_crown_root):
		king_crown_root.visible = false
	if level6_stage == Level6Stage.PHASE_ONE and king_shield_phase == KingShieldPhase.SHIELDED:
		if king_elite_waves_spawned < 1:
			if level6_guard_summon_timer > 0.0:
				level6_guard_summon_timer -= delta
			else:
				level6_guard_retry -= delta
				if level6_guard_retry <= 0.0:
					_level6_try_guard_spawn()
		else:
			for guard: CharacterBody2D in king_elite_guards:
				if not is_instance_valid(guard) or guard.is_queued_for_deletion():
					continue
				if guard.has_method(&"is_dead") and bool(guard.call(&"is_dead")):
					continue
				if guard.global_position.y > target.global_position.y + 680.0:
					if guard.has_method(&"tomar_dano"):
						guard.call(&"tomar_dano", 999999, global_position)
					if is_instance_valid(guard) and not guard.is_queued_for_deletion():
						guard.queue_free()
			if _king_elites_alive_count() == 0:
				_begin_king_shield_break()
	if level6_stage == Level6Stage.PHASE_ONE and king_shield_phase == KingShieldPhase.BREAKING:
		king_shield_break_fx = maxf(0.0, king_shield_break_fx - delta)
		if king_shield_break_fx <= 0.0:
			king_shield_phase = KingShieldPhase.EXPOSED
			level6_attack_timer = 20.0
			king_post_attack_timer = 1.5
			_update_king_hp_label()
	_level6_update_attack_patterns(delta)
	_update_king_attack_cast_pose(delta)
	_update_king_crown(delta)
	sprite.self_modulate = Color.WHITE
	sprite.modulate = Color.WHITE
	_update_king_hp_label()
	queue_redraw()


func _level6_find_third_climb_layer() -> TileMapLayer:
	if not level6_third_platforms_path.is_empty():
		var direct: TileMapLayer = get_node_or_null(level6_third_platforms_path) as TileMapLayer
		if is_instance_valid(direct):
			return direct
	var root: Node = get_tree().current_scene
	if not is_instance_valid(root):
		root = get_parent()
	if is_instance_valid(root):
		return root.find_child("boss3phase", true, false) as TileMapLayer
	return null


func _level6_enable_third_climb() -> void:
	if not is_instance_valid(level6_third_climb_layer):
		level6_third_climb_layer = _level6_find_third_climb_layer()
	if not is_instance_valid(level6_third_climb_layer):
		push_warning("VOID KING V57: Could not enable boss3phase. Expected a TileMapLayer called boss3phase.")
		return
	level6_third_climb_layer.set_deferred("enabled", true)
	print("VOID KING V57: boss3phase platforms and collisions ACTIVATED")


func _level6_refresh_third_nodes() -> void:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return
	if not is_instance_valid(level6_third_identifier):
		level6_third_identifier = scene.find_child("phase3startdetection", true, false) as Area2D
	if level6_third_markers.is_empty():
		for node: Node in scene.find_children("*", "Marker2D", true, false):
			var mark: Marker2D = node as Marker2D
			if is_instance_valid(mark):
				var n: String = String(mark.name).to_lower()
				if n.begins_with("3phasebo") and "spawn" in n:
					level6_third_markers.append(mark)


func _level6_choose_third_marker() -> Marker2D:
	_level6_refresh_third_nodes()
	if level6_third_markers.is_empty():
		return null
	var chosen: Marker2D = null
	var best_score: float = INF
	for marker: Marker2D in level6_third_markers:
		if not is_instance_valid(marker):
			continue
		var score: float = marker.global_position.distance_squared_to(target.global_position) if is_instance_valid(target) else 0.0
		if score < best_score:
			best_score = score
			chosen = marker
	return chosen


func _level6_begin_final_climb() -> void:
	_level6_enable_third_climb()
	level6_stage = Level6Stage.PHASE_THREE_CLIMB
	level6_third_laser_timer = 0.85
	level6_climb_slash_round = 0
	level6_third_warnings.clear()
	king_royal_slashes.clear()
	king_attack_cast_remaining = 0.0
	king_attack_cast_total = 0.0
	king_tp_phase = 0
	_level6_refresh_third_nodes()
	global_position = _level6_phase_three_center_position()
	reset_physics_interpolation()
	level6_current_marker = null
	sprite.visible = true
	_play(&"idle", true)
	if is_instance_valid(king_hud):
		king_hud.visible = false
	_level6_refresh_third_nodes()
	print("VOID KING V56: phase-three ascent started; phase3 markers=", level6_third_markers.size())


func _level6_third_summit_reached() -> bool:
	if not is_instance_valid(target):
		return false
	_level6_refresh_third_nodes()
	if is_instance_valid(level6_third_identifier):
		return _level6_point_inside_area(level6_third_identifier, target.global_position)
	for marker: Marker2D in level6_third_markers:
		if is_instance_valid(marker) and target.global_position.distance_to(marker.global_position) < 190.0:
			return true
	return false


func _level6_spawn_falling_laser(warning_override: float = -1.0) -> void:
	if not is_instance_valid(target) or not king_royal_slashes.is_empty():
		return
	var view: Rect2 = _king_visible_world_rect()
	var requested_warning: float = level6_climb_laser_warning if warning_override < 0.0 else warning_override
	var warning: float = minf(0.68, requested_warning)
	var full_height: float = maxf(view.size.y * 1.35, 700.0)
	var top_y: float = view.position.y - full_height
	var bottom_y: float = view.end.y + full_height
	var margin_x: float = 55.0
	var leading: float = clampf(target.velocity.x * 0.14, -60.0, 60.0)
	var x: float = clampf(target.global_position.x + leading,
		view.position.x + margin_x, view.end.x - margin_x)

	level6_climb_slash_round += 1
	var pattern: int = level6_climb_slash_round % 3
	if pattern == 0:
		_queue_king_slash(Vector2(x, top_y), Vector2(x, bottom_y), warning)
	elif pattern == 1:
		_queue_king_slash(Vector2(x - 105.0, top_y),
			Vector2(x + 105.0, bottom_y), warning)
	else:
		_queue_king_slash(Vector2(x + 105.0, top_y),
			Vector2(x - 105.0, bottom_y), warning)
	if not king_royal_slashes.is_empty():
		var climb_slash: RoyalSlash = king_royal_slashes[king_royal_slashes.size() - 1]
		climb_slash.width_override = 19.0
	queue_redraw()

func _level6_update_falling_lasers(delta: float) -> void:
	var had_beams: bool = not level6_third_warnings.is_empty()
	for i: int in range(level6_third_warnings.size() - 1, -1, -1):
		var beam: VoidRainLaser = level6_third_warnings[i]
		beam.elapsed += delta
		if beam.elapsed < beam.warning:
			continue
		beam.head_y += beam.speed * delta
		var nearest_y: float = clampf(target.global_position.y, beam.head_y - beam.length, beam.head_y) if is_instance_valid(target) else -INF
		if not beam.struck and is_instance_valid(target) and absf(beam.x - target.global_position.x) <= 12.0 and absf(nearest_y - target.global_position.y) <= 24.0:
			beam.struck = true
			if target.has_method(&"tomar_dano"):
				target.call(&"tomar_dano", 1, Vector2(beam.x, target.global_position.y))
		if beam.head_y > beam.end_y:
			level6_third_warnings.remove_at(i)
	if had_beams:
		queue_redraw()


func _level6_draw_falling_lasers() -> void:
	if not level6_mode or level6_third_warnings.is_empty():
		return
	for beam: VoidRainLaser in level6_third_warnings:
		if beam.elapsed < beam.warning:
			var opacity: float = (0.25 + 0.38 * beam.elapsed / maxf(0.1, beam.warning))
			draw_line(to_local(Vector2(beam.x, beam.start_y)),
				to_local(Vector2(beam.x, beam.end_y)), Color(0.86, 0.88, 0.93, opacity), 2.0)
		else:
			var first: Vector2 = to_local(Vector2(beam.x, beam.head_y - beam.length))
			var last: Vector2 = to_local(Vector2(beam.x, beam.head_y))
			draw_line(first, last, Color(0.01, 0.012, 0.02, 0.95), 26.0)
			draw_line(first, last, Color(0.87, 0.88, 0.95, 0.82), 3.0)
			draw_line(last + Vector2(-13.0, 0.0), last + Vector2(13.0, 0.0), Color.WHITE, 2.0)


func _level6_update_final_climb(delta: float) -> void:
	if _level6_third_summit_reached():
		_level6_start_third_reveal()
		return
	_update_king_royal_slashes(delta)
	level6_third_laser_timer -= delta
	if level6_third_laser_timer <= 0.0:
		if king_royal_slashes.is_empty():
			_level6_spawn_falling_laser()
		level6_third_laser_timer = maxf(0.90, minf(level6_climb_laser_gap, 1.30) + randf_range(-0.09, 0.12))
	queue_redraw()


func _level6_phase_three_center_position() -> Vector2:
	_level6_refresh_third_nodes()
	var left_mark: Marker2D = null
	var right_mark: Marker2D = null
	for point: Marker2D in level6_third_markers:
		if not is_instance_valid(point):
			continue
		if not is_instance_valid(left_mark) or point.global_position.x < left_mark.global_position.x:
			left_mark = point
		if not is_instance_valid(right_mark) or point.global_position.x > right_mark.global_position.x:
			right_mark = point
	if is_instance_valid(left_mark) and is_instance_valid(right_mark):
		var middle: Vector2 = (left_mark.global_position + right_mark.global_position) * 0.5
		return middle + Vector2(0.0, -level6_marker_raise_pixels)
	if is_instance_valid(left_mark):
		return _level6_marker_position(left_mark)
	return global_position


func _level6_phase_three_aimed_slash(warning_seconds: float = 0.90) -> void:
	if not is_instance_valid(target) or king_tp_phase != 0:
		return
	var origin: Vector2 = global_position + Vector2(0.0, -17.0)
	var predicted: Vector2 = target.global_position + target.velocity * 0.10
	var to_player: Vector2 = predicted - origin
	var direction: Vector2 = to_player.normalized() if to_player.length_squared() > 4.0 else Vector2.DOWN
	var view: Rect2 = _king_visible_world_rect()
	var slash_length: float = maxf(maxf(1350.0, view.size.length() * 2.5), to_player.length() + view.size.length())
	_queue_king_slash(origin, origin + direction * slash_length, warning_seconds)
	if not king_royal_slashes.is_empty():
		var slash: RoyalSlash = king_royal_slashes[king_royal_slashes.size() - 1]
		slash.width_override = 19.0
		slash.phase3_pulsing_warning = true
	queue_redraw()


func _level6_start_third_reveal() -> void:
	for void_node: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if void_node.has_method(&"begin_phase_three_rising"):
			void_node.call(&"begin_phase_three_rising")
	level6_third_warnings.clear()
	_level6_clear_attacks()
	level6_stage = Level6Stage.PHASE_THREE
	level6_second_reveal = false
	level6_void_auto_fog_power_v79 = maxf(level6_void_auto_fog_power_v79,
		level6_phase3_fog_floor_v80)
	_level6_create_screen_darkness()
	level6_darkness_now = maxf(level6_darkness_now, 0.49)
	_level6_apply_world_darkness(level6_darkness_now)
	print("VOID KING V71: final duel started; atmospheric darkness alpha=",
		level6_screen_shadow.color.a if is_instance_valid(level6_screen_shadow) else -1.0,
		" / current HP=", hp, "/", max_hp)
	hp = 10
	max_hp = 10
	king_shield_phase = KingShieldPhase.EXPOSED
	king_tp_phase = 0
	level6_third_attack_timer = 2.3
	level6_third_attack_round = 0
	sprite.visible = true
	if is_instance_valid(level6_aura_sprite):
		level6_aura_sprite.visible = true
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.visible = true
		level6_aura_particles.emitting = true
	if is_instance_valid(king_hud):
		king_hud.visible = true
	health_changed.emit(hp, max_hp)
	_update_king_hp_label()
	_level6_refresh_third_nodes()
	level6_current_marker = null
	level6_perch_timer = 0.0
	_level6_choose_marker()
	print("VOID KING V61: phase3 trigger reached. Starting marker teleport now; markers=", level6_third_markers.size())


func _level6_update_third_reveal(delta: float) -> void:
	level6_stage_timer -= delta
	var camera: Camera2D = _level6_find_battle_camera()
	if is_instance_valid(camera):
		var power: float = (1.0 - clampf(level6_stage_timer / 2.15, 0.0, 1.0)) * 8.0
		camera.offset = Vector2(randf_range(-power, power), randf_range(-power, power))
	if level6_stage_timer <= 0.85:
		sprite.visible = true
		var progress: float = 1.0 - clampf(level6_stage_timer / 0.85, 0.0, 1.0)
		_king_set_teleport_death_frame(1.0 - progress)
	if level6_stage_timer <= 0.0:
		level6_stage = Level6Stage.PHASE_THREE
		sprite.visible = true
		_play(&"idle", true)
		level6_third_attack_timer = 1.6
		print("VOID KING V60: FINAL DUEL ACTIVE; 10 registered hits to win")


func _level6_update_third_fight(delta: float) -> void:
	if not is_instance_valid(target):
		return
	hover_time += delta
	king_shield_animation_time += delta
	king_black_flash_timer = maxf(0.0, king_black_flash_timer - delta)
	level6_hit_lock = maxf(0.0, level6_hit_lock - delta)
	if is_instance_valid(level6_void_shader):
		level6_void_shader.set_shader_parameter("hit_flash", 1.0 if king_black_flash_timer > 0.0 else 0.0)
	_level6_perch_tick(delta)
	_level6_sword_fallback()
	_level6_update_void_swords(delta)
	_update_king_royal_slashes(delta)
	_update_king_attack_cast_pose(delta)
	var facing_dx: float = target.global_position.x - global_position.x
	if absf(facing_dx) > 3.0:
		sprite.flip_h = (facing_dx > 0.0) != sprite_faces_right_by_default
	level6_third_attack_timer -= delta
	if king_tp_phase == 0 and level6_third_attack_timer <= 0.0 and level6_void_swords.is_empty() and king_royal_slashes.is_empty() and king_attack_cast_remaining <= 0.0:
		level6_third_attack_round += 1
		_begin_king_attack_cast()
		if level6_third_attack_round % 2 == 0:
			_level6_phase_three_aimed_slash(0.93 if hp > 4 else 0.82)
		else:
			_level6_start_void_swords(2 if hp > 4 else 3)
		level6_third_attack_timer = 2.65 if hp > 4 else 2.35
	_update_king_hp_label()
	queue_redraw()


func _level6_begin_final_death() -> void:
	if level6_stage == Level6Stage.THIRD_DEATH:
		return
	level6_stage = Level6Stage.THIRD_DEATH
	_collapse_level7_transition_started = false
	if is_instance_valid(target):
		target.set("tempo_invulneravel_restante", 99999.0)
	level6_third_fx_timer = 0.0
	_collapse_step = 0
	_collapse_elapsed = 0.0
	_collapse_total_elapsed = 0.0
	level6_third_fx_original_scale = sprite.scale
	_level6_clear_attacks()
	level6_third_warnings.clear()
	_play(&"death", true)
	sprite.visible = true
	if is_instance_valid(king_hud):
		king_hud.visible = false
	if is_instance_valid(level6_aura_particles):
		level6_aura_particles.emitting = true
	level6_final_shake_camera = _level6_find_battle_camera()
	if is_instance_valid(level6_final_shake_camera):
		level6_final_camera_offset = level6_final_shake_camera.offset
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	var tex: Texture2D = _level6_get_particle_texture()
	for i: int in range(72):
		var p: Sprite2D = Sprite2D.new()
		p.texture = tex
		p.z_index = 87
		p.scale = Vector2.ONE * randf_range(0.9, 3.0)
		p.modulate = Color(0.92, 0.93, 1.0, 0.84) if i % 9 == 0 else Color(0.015, 0.018, 0.026, 0.98)
		parent.add_child(p)
		p.global_position = global_position + Vector2(randf_range(-25.0, 25.0), randf_range(-35.0, 35.0))
		level6_third_fx_particles.append(p)
		var outward: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / 72.0 + randf_range(-0.18, 0.18)) * randf_range(120.0, 330.0)
		var tween: Tween = p.create_tween()
		tween.tween_property(p, "global_position", global_position + outward, 1.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.75)
		tween.tween_property(p, "global_position", global_position, 1.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.55).set_delay(0.90)
		tween.tween_callback(p.queue_free)
	_collapse_prepare_white_fog()
	_collapse_spawn_emitter(true, global_position, Vector2.UP, 0.13)
	print("VOID KING V87: original death animation + accelerating white fog")


func _level6_update_final_death(delta: float) -> void:
	_collapse_total_elapsed += delta
	_collapse_fog_clock += delta
	_collapse_update_white_fog()
	if _collapse_step == 0:
		level6_third_fx_timer += delta
		var progress: float = clampf(level6_third_fx_timer / maxf(0.2, level6_final_animation_seconds), 0.0, 1.0)
		if is_instance_valid(level6_final_shake_camera):
			var amount: float = 4.0 + 17.0 * progress * progress
			_collapse_camera_shake(amount)
		if progress >= 0.45:
			var shrink: float = clampf((progress - 0.45) / 0.20, 0.0, 1.0)
			sprite.scale = level6_third_fx_original_scale * maxf(0.025, 1.0 - shrink)
		if progress >= 0.66:
			sprite.visible = false
			if is_instance_valid(level6_aura_sprite):
				level6_aura_sprite.visible = false
			if is_instance_valid(level6_aura_particles):
				level6_aura_particles.emitting = false
		if level6_third_fx_timer >= level6_final_animation_seconds:
			_collapse_begin_rumble()
	elif _collapse_step == 1:
		_collapse_elapsed += delta
		var fraction: float = clampf(_collapse_elapsed / maxf(0.1, level6_collapse_rumble_seconds), 0.0, 1.0)
		_collapse_camera_shake(lerpf(9.0, level6_collapse_max_shake, pow(fraction, 1.65)))
		_collapse_spawn_rocks(delta)
		_collapse_burst_timer -= delta
		if _collapse_burst_timer <= 0.0:
			_collapse_burst_timer = lerpf(1.50, 0.28, fraction * fraction)
			_collapse_spawn_wave()
		if _collapse_elapsed >= level6_collapse_rumble_seconds:
			_collapse_begin_fall()
	elif _collapse_step == 2:
		_collapse_update_fall(delta)
	elif _collapse_step == 3:
		pass
	queue_redraw()

func _level6_draw_final_implosion() -> void:
	if level6_stage != Level6Stage.THIRD_DEATH:
		return
	var t: float = clampf(level6_third_fx_timer / maxf(0.1, level6_final_animation_seconds), 0.0, 1.0)
	if t > 0.40 and t < 0.79:
		var size: float = lerpf(230.0, 1.0, clampf((t - 0.40) / 0.39, 0.0, 1.0))
		for i: int in range(12):
			var theta: float = TAU * float(i) / 12.0 + hover_time
			var pos: Vector2 = body_shape.position + Vector2.RIGHT.rotated(theta) * size
			draw_line(pos, body_shape.position, Color(0.68, 0.70, 0.78, 0.36), 2.0)
	elif t >= 0.79:
		draw_circle(body_shape.position, maxf(0.0, 260.0 * (1.0 - t) / 0.21), Color(0.97, 0.98, 1.0, 0.22))


func _level6_complete_victory() -> void:
	if level6_stage == Level6Stage.COMPLETE:
		return
	level6_stage = Level6Stage.COMPLETE
	if is_instance_valid(level6_final_shake_camera):
		level6_final_shake_camera.offset = level6_final_camera_offset
	level6_final_victory.emit()
	print("VOID KING V87: five relics stopped the fall; Level 6 victory complete")


func _collapse_prepare_white_fog() -> void:
	if is_instance_valid(_collapse_ui):
		return
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		scene_root = get_tree().root
	_collapse_ui = CanvasLayer.new()
	_collapse_ui.name = "KingFinalWhiteFogAndCollapse"
	_collapse_ui.layer = 1320
	scene_root.add_child(_collapse_ui)
	_collapse_fog_root = Control.new()
	_collapse_fog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collapse_ui.add_child(_collapse_fog_root)
	_collapse_fog_texture = _collapse_make_soft_fog_texture()
	for i: int in range(34):
		var bank: TextureRect = TextureRect.new()
		bank.texture = _collapse_fog_texture
		bank.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bank.stretch_mode = TextureRect.STRETCH_SCALE
		bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bank.modulate.a = 0.0
		_collapse_fog_root.add_child(bank)
		_collapse_white_fog.append(bank)
	_collapse_white_shroud = ColorRect.new()
	_collapse_white_shroud.color = Color(0.89, 0.93, 1.0, 0.0)
	_collapse_white_shroud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collapse_fog_root.add_child(_collapse_white_shroud)
	_collapse_update_white_fog()


func _collapse_make_soft_fog_texture() -> Texture2D:
	var canvas: Image = Image.create(112, 112, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 91746
	noise.frequency = 0.072
	for py: int in range(112):
		for px: int in range(112):
			var coordinate: Vector2 = (Vector2(float(px), float(py)) - Vector2(55.5, 55.5)) / 55.5
			var radius: float = coordinate.length()
			var n: float = noise.get_noise_2d(float(px), float(py))
			var alpha: float = pow(clampf(1.0 - radius, 0.0, 1.0), 1.35)
			alpha *= clampf(0.70 + n * 0.52, 0.10, 1.0)
			canvas.set_pixel(px, py, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(canvas)


func _collapse_update_white_fog() -> void:
	if not is_instance_valid(_collapse_fog_root):
		return
	var screen: Vector2 = get_viewport_rect().size
	_collapse_fog_root.size = screen
	_collapse_white_shroud.size = screen
	var buildup_total: float = maxf(0.1, level6_final_animation_seconds + level6_collapse_rumble_seconds)
	var progress: float = clampf(_collapse_total_elapsed / buildup_total, 0.0, 1.0)
	var strength: float = minf(0.85, 0.05 + 0.72 * pow(progress, 1.9))
	if _collapse_step == 2:
		strength *= 0.64
	if _collapse_step >= 3:
		strength = 0.0
	_collapse_white_shroud.color.a = strength * 0.15
	var fog_speed: float = 1.0 + progress * progress * 5.2
	for i: int in range(_collapse_white_fog.size()):
		var item: TextureRect = _collapse_white_fog[i]
		var seed: float = float(i) * 1.618
		var width: float = screen.x * (0.19 + 0.11 * absf(sin(seed * 1.6)))
		var height: float = screen.y * (0.20 + 0.15 * absf(cos(seed)))
		item.size = Vector2(width, height)
		var fx: float = fposmod(float(i * 73) + _collapse_fog_clock * fog_speed * (23.0 + float(i % 7) * 4.0), screen.x + width * 1.6) - width
		var fy: float = fposmod(float(i * 59) + sin(_collapse_fog_clock * 0.43 + seed) * 53.0, screen.y + height * 1.7) - height * 0.5
		item.position = Vector2(fx, fy)
		item.modulate = Color(0.95, 0.97, 1.0, strength * (0.23 + 0.27 * absf(cos(seed))))
		item.visible = (float(i) / float(maxi(1, _collapse_white_fog.size())) < clampf(progress * 1.15 + 0.12, 0.0, 1.0))


func _collapse_camera_shake(strength: float) -> void:
	if not is_instance_valid(level6_final_shake_camera):
		level6_final_shake_camera = _level6_find_battle_camera()
		if is_instance_valid(level6_final_shake_camera):
			level6_final_camera_offset = level6_final_shake_camera.offset
	if is_instance_valid(level6_final_shake_camera):
		level6_final_shake_camera.offset = level6_final_camera_offset + Vector2(
			randf_range(-strength, strength), randf_range(-strength, strength))


func _collapse_scene_root() -> Node:
	var scene_root: Node = get_tree().current_scene
	return scene_root if is_instance_valid(scene_root) else get_tree().root


func _collapse_spawn_emitter(white_smoke: bool, at: Vector2, direction: Vector2, opacity: float) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.name = "KingFinalWhiteFog" if white_smoke else "KingFinalGateLikeBlackSmoke"
	emitter.one_shot = false
	emitter.amount = 42 if white_smoke else 70
	emitter.lifetime = 3.5 if white_smoke else 3.0
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = Vector2(170.0, 100.0)
	emitter.direction = direction
	emitter.spread = 63.0
	emitter.gravity = Vector2(0.0, -30.0)
	emitter.initial_velocity_min = 90.0
	emitter.initial_velocity_max = 280.0
	emitter.scale_amount_min = 1.15
	emitter.scale_amount_max = 2.65
	emitter.color = Color(0.94, 0.96, 1.0, opacity) if white_smoke else Color(0.016, 0.017, 0.028, opacity)
	emitter.texture = _collapse_fog_texture if is_instance_valid(_collapse_fog_texture) else _collapse_make_soft_fog_texture()
	emitter.z_index = 1750
	_collapse_scene_root().add_child(emitter)
	emitter.global_position = at
	emitter.emitting = true
	_collapse_emitters.append(emitter)
	return emitter


func _collapse_make_gate_wind_texture() -> Texture2D:
	if is_instance_valid(_collapse_wind_texture):
		return _collapse_wind_texture
	var wind_image: Image = Image.create(110, 10, false, Image.FORMAT_RGBA8)
	for py: int in range(10):
		for px: int in range(110):
			var horizontal: float = absf(float(px) - 54.5) / 54.5
			var vertical: float = absf(float(py) - 4.5) / 4.5
			var alpha: float = pow(1.0 - horizontal, 0.68) * pow(1.0 - vertical, 1.8) * 0.75
			wind_image.set_pixel(px, py, Color(1.0, 1.0, 1.0, alpha))
	_collapse_wind_texture = ImageTexture.create_from_image(wind_image)
	return _collapse_wind_texture


func _collapse_spawn_wind(at: Vector2, heading: Vector2) -> void:
	var wind: CPUParticles2D = CPUParticles2D.new()
	wind.name = "KingFinalGateWind"
	wind.amount = 45
	wind.lifetime = 0.67
	wind.one_shot = true
	wind.explosiveness = 0.20
	wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wind.emission_rect_extents = Vector2(14.0, 135.0)
	wind.direction = heading
	wind.spread = 14.0
	wind.gravity = Vector2.ZERO
	wind.initial_velocity_min = 650.0
	wind.initial_velocity_max = 1100.0
	wind.scale_amount_min = 0.65
	wind.scale_amount_max = 1.35
	wind.color = Color(0.76, 0.81, 0.92, 0.34)
	wind.texture = _collapse_make_gate_wind_texture()
	wind.z_index = 1751
	_collapse_scene_root().add_child(wind)
	wind.global_position = at
	wind.emitting = true
	var fading: Tween = create_tween()
	fading.tween_interval(1.6)
	fading.tween_callback(wind.queue_free)


func _collapse_spawn_wave() -> void:
	var center: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_collapse_spawn_wind(center + Vector2(60.0, -110.0), Vector2.LEFT)
	_collapse_spawn_wind(center + Vector2(-60.0, -110.0), Vector2.RIGHT)
	if _collapse_emitters.size() < 12:
		_collapse_spawn_emitter(false, center + Vector2(0.0, -65.0), Vector2.LEFT, 0.22)
		_collapse_spawn_emitter(false, center + Vector2(0.0, -65.0), Vector2.RIGHT, 0.22)
	for p: CPUParticles2D in _collapse_emitters:
		if is_instance_valid(p) and p.name == "KingFinalWhiteFog":
			p.amount = maxi(p.amount, mini(280, 42 + int(_collapse_total_elapsed * 18.0)))


func _collapse_spawn_rocks(delta: float) -> void:
	_collapse_debris_timer -= delta
	if _collapse_debris_timer > 0.0 or not is_instance_valid(target):
		return
	_collapse_debris_timer = randf_range(0.12, 0.36)
	var stone: Polygon2D = Polygon2D.new()
	stone.name = "FallingTempleFragment"
	var w: float = randf_range(9.0, 38.0)
	var h: float = randf_range(8.0, 29.0)
	stone.polygon = PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h * 0.65), Vector2(w * 0.82, h), Vector2(-w * 0.7, h * 0.85)])
	stone.color = Color(0.13, 0.13, 0.16, randf_range(0.7, 0.95))
	stone.z_index = 650
	_collapse_scene_root().add_child(stone)
	stone.global_position = target.global_position + Vector2(randf_range(-650.0, 650.0), randf_range(-650.0, -350.0))
	var tumble: Tween = create_tween()
	tumble.set_parallel(true)
	tumble.tween_property(stone, "global_position", stone.global_position + Vector2(0.0, randf_range(700.0, 1500.0)), randf_range(1.0, 2.4))
	tumble.tween_property(stone, "rotation", randf_range(-5.0, 5.0), 1.7)
	tumble.tween_property(stone, "modulate:a", 0.0, 2.0)
	tumble.chain().tween_callback(stone.queue_free)


func _collapse_begin_rumble() -> void:
	_collapse_step = 1
	_collapse_elapsed = 0.0
	_collapse_burst_timer = 0.0
	_collapse_debris_timer = 0.0
	_collapse_spawn_emitter(true, global_position, Vector2.UP, 0.22)
	if is_instance_valid(_level6_wander_retreat_wall):
		_level6_wander_retreat_wall.queue_free()
	if is_instance_valid(_level6_wander_opposite_wall):
		_level6_wander_opposite_wall.queue_free()
	print("VOID KING V87: king dead; expanding fog, violent wind, falling stones, stronger quakes")


func _collapse_find_tilemap_ground_y() -> float:
	var lowest: float = -INF
	for node: Node in _collapse_scene_root().find_children("*", "TileMapLayer", true, false):
		var layer: TileMapLayer = node as TileMapLayer
		if not is_instance_valid(layer):
			continue
		var used: Rect2i = layer.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var corner: Vector2 = layer.to_global(layer.map_to_local(Vector2i(used.position.x, used.end.y - 1)))
		lowest = maxf(lowest, corner.y)
	if level6_collapse_optional_ground_marker != NodePath(""):
		var marker: Marker2D = get_node_or_null(level6_collapse_optional_ground_marker) as Marker2D
		if is_instance_valid(marker):
			return marker.global_position.y
	if lowest == -INF:
		lowest = target.global_position.y + level6_collapse_fallback_fall_distance
	return lowest


func _collapse_store_and_disable_tilemaps() -> void:
	_collapse_tiles.clear()
	for node: Node in _collapse_scene_root().find_children("*", "TileMapLayer", true, false):
		var layer: TileMapLayer = node as TileMapLayer
		if is_instance_valid(layer):
			_collapse_tiles.append({"layer": layer, "enabled": layer.enabled})
			layer.enabled = false
	_collapse_tiles_restored = false
	print("VOID KING V87: ALL ", _collapse_tiles.size(), " TileMapLayers hidden / collision disabled")


func _collapse_restore_tilemaps() -> void:
	if _collapse_tiles_restored:
		return
	for info: Dictionary in _collapse_tiles:
		var layer: TileMapLayer = info.get("layer") as TileMapLayer
		if is_instance_valid(layer):
			layer.enabled = bool(info.get("enabled", true))
	_collapse_tiles_restored = true
	print("VOID KING V87: all TileMaps restored to their ORIGINAL enabled states after 5 s")


func _collapse_begin_fall() -> void:
	if not is_instance_valid(target):
		push_error("VOID KING V87: missing Player for collapse cinematic")
		return
	_collapse_step = 2
	_collapse_elapsed = 0.0
	_collapse_expected_ground_y = _collapse_find_tilemap_ground_y()
	_collapse_player_start_y = target.global_position.y
	_collapse_player_start_x = target.global_position.x
	_collapse_player_goal_y = maxf(_collapse_player_start_y + 1500.0,
		_collapse_expected_ground_y - 85.0)
	_collapse_player_physics = target.is_physics_processing()
	_collapse_player_process = target.is_processing()
	_collapse_player_mask = target.collision_mask
	target.set_meta(&"king_final_cinematic_active", true)
	for abyss: Node in get_tree().get_nodes_in_group(&"rising_void"):
		if abyss.has_method(&"set_king_final_fall_active"):
			abyss.call(&"set_king_final_fall_active", true)
	target.set("tempo_invulneravel_restante", 99999.0)
	target.velocity = Vector2.ZERO
	target.set_physics_process(false)
	target.set_process(false)
	var player_sprite: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(player_sprite) and player_sprite.sprite_frames != null:
		if player_sprite.sprite_frames.has_animation(&"fall"):
			player_sprite.play(&"fall")
		elif player_sprite.sprite_frames.has_animation(&"jump"):
			player_sprite.play(&"jump")
	target.collision_mask = 0
	if target.has_method(&"_resetar_queda_profunda"):
		target.call(&"_resetar_queda_profunda")
	_collapse_store_and_disable_tilemaps()
	_collapse_spawn_wave()
	print("VOID KING V87: all terrain removed for 5 s; 10-second fall from ", _collapse_player_start_y,
		" toward terrain Y=", _collapse_player_goal_y)


func _collapse_update_fall(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_collapse_elapsed += delta
	var duration: float = maxf(0.5, level6_collapse_fall_seconds)
	var ratio: float = clampf(_collapse_elapsed / duration, 0.0, 1.0)
	var eased: float = pow(ratio, 1.28)
	target.global_position = Vector2(_collapse_player_start_x,
		lerpf(_collapse_player_start_y, _collapse_player_goal_y, eased))
	target.velocity = Vector2(0.0, (_collapse_player_goal_y - _collapse_player_start_y) * 1.28 * pow(maxf(0.005, ratio), 0.28) / duration)
	_collapse_camera_shake(lerpf(12.0, 3.0, ratio))
	_collapse_spawn_rocks(delta)
	if _collapse_elapsed >= level6_collapse_hide_tiles_seconds:
		_collapse_restore_tilemaps()
	if ratio >= 0.81 and _collapse_relics.is_empty():
		_collapse_create_artifacts()
	if not _collapse_relics.is_empty():
		_collapse_update_artifacts(ratio, delta)
	if _collapse_elapsed >= duration:
		_collapse_begin_artifact_save()


func _collapse_create_artifacts() -> void:
	if not is_instance_valid(target):
		return
	var frames: SpriteFrames = GerenciadorArtefatos.sprite_frames_artefatos
	if frames == null:
		push_warning("VOID KING V87: missing registered artifact sprites; magical orbs used as fallback")
	var artifacts: Array[String] = ["escaravelho", "calice", "ankh", "mascara", "lapislazulidofarao"]
	for i: int in range(5):
		var relic: AnimatedSprite2D = AnimatedSprite2D.new()
		relic.name = "FinalSavingArtifact_" + artifacts[i]
		relic.z_index = 1800
		if frames != null and frames.has_animation(artifacts[i]):
			relic.sprite_frames = frames
			relic.animation = StringName(artifacts[i])
			relic.frame = 0
			relic.stop()
			relic.centered = GerenciadorArtefatos.visual_centered
			relic.offset = GerenciadorArtefatos.offset_visual_artefato
			relic.scale = GerenciadorArtefatos.escala_visual_artefato * 0.7
		else:
			var texture: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
			for gy: int in range(48):
				for gx: int in range(48):
					var distance: float = Vector2(float(gx) - 23.5, float(gy) - 23.5).length() / 24.0
					var glow: float = pow(1.0 - smoothstep(0.12, 1.0, distance), 1.6)
					texture.set_pixel(gx, gy, Color(1.0, 0.84, 0.41, glow * 0.94))
			var alternative: SpriteFrames = SpriteFrames.new()
			alternative.add_animation(&"glow")
			alternative.add_frame(&"glow", ImageTexture.create_from_image(texture))
			relic.sprite_frames = alternative
			relic.animation = &"glow"
			relic.scale = Vector2.ONE
		_collapse_scene_root().add_child(relic)
		relic.global_position = target.global_position
		_collapse_relics.append(relic)
	print("VOID KING V87: FIVE artifacts emerge to intercept the fall")


func _collapse_update_artifacts(ratio: float, delta: float) -> void:
	if not is_instance_valid(target):
		return
	var progress: float = clampf((ratio - 0.81) / 0.19, 0.0, 1.0)
	for i: int in range(_collapse_relics.size()):
		var artifact: AnimatedSprite2D = _collapse_relics[i]
		if not is_instance_valid(artifact):
			continue
		var theta: float = TAU * float(i) / 5.0 + _collapse_elapsed * (4.5 + progress * 16.0)
		var around: Vector2 = Vector2(cos(theta), sin(theta)) * (70.0 - progress * 22.0)
		var beneath: Vector2 = Vector2((float(i) - 2.0) * 30.0, 62.0 + absf(float(i) - 2.0) * 8.0)
		var position: Vector2 = around.lerp(beneath, smoothstep(0.60, 0.97, progress))
		artifact.global_position = target.global_position + position
		artifact.rotation = 0.0
		artifact.modulate = Color(1.0, 0.90 + 0.10 * sin(_collapse_elapsed * 13.0), 0.60, 1.0)


func _collapse_begin_artifact_save() -> void:
	if _collapse_step != 2:
		return
	_collapse_step = 3
	_collapse_elapsed = 0.0
	_collapse_restore_tilemaps()
	if is_instance_valid(target):
		target.velocity = Vector2.ZERO
	_collapse_make_white_screen()
	_collapse_run_white_rescue()


func _collapse_make_white_screen() -> void:
	if is_instance_valid(_collapse_flash):
		return
	_collapse_flash = CanvasLayer.new()
	_collapse_flash.name = "KingFiveArtifactsWhiteRescue"
	_collapse_flash.layer = 5000
	_collapse_scene_root().add_child(_collapse_flash)
	_collapse_flash_bg = ColorRect.new()
	_collapse_flash_bg.color = Color(1.0, 1.0, 1.0, 1.0)
	_collapse_flash_bg.modulate.a = 0.0
	_collapse_flash_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_collapse_flash.add_child(_collapse_flash_bg)
	_collapse_flash_label = Label.new()
	_collapse_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_collapse_flash_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collapse_flash_label.add_theme_color_override("font_color", Color(0.15, 0.14, 0.19, 1.0))
	_collapse_flash_label.add_theme_font_size_override("font_size", 28)
	_collapse_flash_label.modulate.a = 0.0
	_collapse_flash.add_child(_collapse_flash_label)
	_collapse_update_flash_layout()
	if not get_viewport().size_changed.is_connected(_collapse_update_flash_layout):
		get_viewport().size_changed.connect(_collapse_update_flash_layout)
	var flash: Tween = create_tween()
	flash.tween_property(_collapse_flash_bg, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_CUBIC)


func _collapse_update_flash_layout() -> void:
	if not is_instance_valid(_collapse_flash_bg):
		return
	var screen: Vector2 = get_viewport_rect().size
	_collapse_flash_bg.size = screen
	_collapse_flash_label.position = Vector2(screen.x * 0.09, screen.y * 0.32)
	_collapse_flash_label.size = Vector2(screen.x * 0.82, screen.y * 0.38)


func _collapse_rescue_text(message: String, hold: float) -> void:
	if not is_instance_valid(_collapse_flash_label):
		return
	_collapse_flash_label.text = message
	_collapse_flash_label.visible_characters = 0
	_collapse_flash_label.modulate.a = 1.0
	for i: int in range(message.length()):
		if not is_instance_valid(_collapse_flash_label):
			return
		_collapse_flash_label.visible_characters = i + 1
		await get_tree().create_timer(0.035).timeout
	await get_tree().create_timer(hold).timeout
	var fade: Tween = create_tween()
	fade.tween_property(_collapse_flash_label, "modulate:a", 0.0, 0.45)
	await fade.finished


func _collapse_place_player_on_ground() -> void:
	if not is_instance_valid(target):
		return
	var landing: Vector2 = Vector2(_collapse_player_start_x, _collapse_player_goal_y)
	if level6_collapse_optional_ground_marker != NodePath(""):
		var ground_marker: Marker2D = get_node_or_null(level6_collapse_optional_ground_marker) as Marker2D
		if is_instance_valid(ground_marker):
			landing = ground_marker.global_position
	else:
		var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var nearest_score: float = INF
		for side: float in [0.0, -90.0, 90.0, -190.0, 190.0]:
			var probe_x: float = landing.x + side
			var start: Vector2 = Vector2(probe_x, landing.y - 1300.0)
			var finish: Vector2 = Vector2(probe_x, landing.y + 2000.0)
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, finish, terrain_mask)
			query.collide_with_areas = false
			query.exclude = [target.get_rid(), get_rid()]
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty() or hit.get("normal", Vector2.ZERO).y > -0.5:
				continue
			var floor_pos: Vector2 = hit.get("position", landing)
			var score: float = absf(floor_pos.y - _collapse_expected_ground_y) + absf(side) * 0.4
			if score < nearest_score:
				nearest_score = score
				landing = floor_pos + Vector2(0.0, -36.0)

	target.global_position = landing
	target.velocity = Vector2.ZERO
	target.reset_physics_interpolation()
	if target.has_method(&"_resetar_queda_profunda"):
		target.call(&"_resetar_queda_profunda")
	target.collision_mask = _collapse_player_mask
	target.set_physics_process(_collapse_player_physics)
	target.set_process(_collapse_player_process)
	target.set("tempo_invulneravel_restante", 4.5)
	target.remove_meta(&"king_final_cinematic_active")


func _collapse_run_white_rescue() -> void:
	await get_tree().create_timer(2.75).timeout
	if not is_inside_tree():
		return
	await _collapse_rescue_text("Eu vi o chão chegando.", 1.45)
	await _collapse_rescue_text("As cinco relíquias apareceram de repente.", 1.35)
	await _collapse_rescue_text("E a queda parou.", 1.70)
	await get_tree().create_timer(2.25).timeout
	if not is_inside_tree():
		return

	for artifact: AnimatedSprite2D in _collapse_relics:
		if is_instance_valid(artifact):
			artifact.queue_free()
	_collapse_relics.clear()
	for fog: CPUParticles2D in _collapse_emitters:
		if is_instance_valid(fog):
			fog.emitting = false
	if is_instance_valid(_collapse_ui):
		_collapse_ui.queue_free()
	if is_instance_valid(level6_final_shake_camera):
		level6_final_shake_camera.offset = level6_final_camera_offset
	_collapse_step = 4
	_level6_complete_victory()
	if not is_inside_tree():
		return

	if _collapse_transfer_white_to_level7():
		return

	_collapse_place_player_on_ground()
	_collapse_flash.process_mode = Node.PROCESS_MODE_ALWAYS
	var fallback_fade: Tween = _collapse_flash.create_tween()
	fallback_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fallback_fade.tween_property(_collapse_flash_bg, "modulate:a", 0.0, 2.8)
	fallback_fade.tween_callback(_collapse_flash.queue_free)
	_collapse_flash = null


func _collapse_transfer_white_to_level7() -> bool:
	if not ResourceLoader.exists(level6_collapse_level7_scene):
		push_warning("Level 7 não encontrado: " + level6_collapse_level7_scene)
		return false
	if not is_instance_valid(_collapse_flash) or not is_instance_valid(_collapse_flash_bg):
		return false

	_collapse_flash_bg.modulate.a = 1.0
	_collapse_flash_label.modulate.a = 0.0
	_collapse_flash.process_mode = Node.PROCESS_MODE_ALWAYS
	_collapse_flash.reparent(get_tree().root)
	_collapse_level7_transition_started = true

	var camada_branca: CanvasLayer = _collapse_flash
	var tela_branca: ColorRect = _collapse_flash_bg
	var fade: Tween = camada_branca.create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	fade.set_trans(Tween.TRANS_SINE)
	fade.tween_interval(1.25)
	fade.tween_property(tela_branca, "modulate:a", 0.0, 2.5)
	fade.tween_callback(camada_branca.queue_free)
	fade.pause()

	var comecar_fade: Timer = Timer.new()
	comecar_fade.name = "IniciarFadeAposTroca"
	comecar_fade.one_shot = true
	comecar_fade.wait_time = 1.5
	comecar_fade.process_mode = Node.PROCESS_MODE_ALWAYS
	camada_branca.add_child(comecar_fade)
	comecar_fade.timeout.connect(Callable(fade, "play"))

	var seguranca: Timer = Timer.new()
	seguranca.name = "LimiteTelaBranca"
	seguranca.one_shot = true
	seguranca.wait_time = 5.0
	seguranca.process_mode = Node.PROCESS_MODE_ALWAYS
	camada_branca.add_child(seguranca)
	seguranca.timeout.connect(Callable(fade, "play"))
	seguranca.start()

	var resultado: Error = get_tree().change_scene_to_file(level6_collapse_level7_scene)
	if resultado != OK:
		push_error("Não foi possível carregar Level 7: " + str(resultado))
		_collapse_level7_transition_started = false
		_collapse_place_player_on_ground()
		fade.play()
		return true

	comecar_fade.start()
	print("Level 7: transição iniciada; tela branca será removida")
	return true

func _level6_update_attack_patterns(delta: float) -> void:
	if level6_stage not in [Level6Stage.PHASE_ONE, Level6Stage.PHASE_TWO]:
		return
	if king_gravefall_active:
		king_gravefall_warning_timer -= delta
		if king_gravefall_warning_timer <= 0.0:
			_finish_king_spell()
		return
	if not king_royal_slashes.is_empty() or not level6_void_walls.is_empty() or king_tp_phase != 0 or not level6_void_swords.is_empty():
		return
	if king_post_attack_timer > 0.0 or king_attack_cast_remaining > 0.0:
		return
	if level6_stage == Level6Stage.PHASE_ONE and king_shield_phase in [KingShieldPhase.EXPOSED, KingShieldPhase.BREAKING]:
		return
	if level6_stage == Level6Stage.PHASE_ONE and king_shield_phase == KingShieldPhase.SHIELDED:
		if king_elite_waves_spawned < 1 or _king_elites_alive_count() <= 0:
			return
	level6_attack_timer -= delta
	if level6_attack_timer > 0.0:
		return
	level6_attack_round += 1
	var danger: float = clampf(1.0 - float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	if level6_stage == Level6Stage.PHASE_ONE and king_shield_phase == KingShieldPhase.SHIELDED:
		if level6_attack_round % 3 == 0:
			_level6_start_void_swords(5)
		elif level6_attack_round % 2 == 0:
			_level6_start_void_dash_combo(2)
		else:
			_level6_start_void_twin_cut(2)
		level6_attack_timer = maxf(8.0, level6_guard_spell_interval)
		return
	_begin_king_attack_cast()
	if level6_stage == Level6Stage.PHASE_ONE:
		match level6_attack_round % 8:
			0: _level6_start_interleaved_pillars()
			1: _level6_start_void_dash_combo(2 if danger < 0.42 else 4)
			2: _level6_start_void_swords(5 if danger < 0.60 else 7)
			3: _level6_start_void_swords(6 if danger < 0.60 else 7)
			4: _level6_start_predictive_slash_spam(4 if danger < 0.50 else 7)
			5: _level6_start_horizontal_lanes(2 if danger < 0.55 else 3)
			6: _level6_start_void_wall()
			_: _level6_start_void_dash_combo(3 if danger < 0.50 else 5)
		level6_attack_timer = lerpf(2.55, 1.1, danger)
	else:
		match level6_attack_round % 10:
			0: _level6_start_marker_cuts(3 if danger < 0.5 else 5)
			1: _level6_start_void_swords(5 if danger < 0.40 else 7)
			2: _level6_start_void_dash_combo(3 if danger < 0.5 else 5)
			3: _level6_start_void_staircase(2 if danger < 0.5 else 3)
			4: _level6_start_horizontal_lanes(3)
			5: _level6_start_marker_cuts(4 if danger < 0.5 else 6)
			6: _level6_start_void_wall()
			7: _level6_start_void_swords(7)
			8: _level6_start_interleaved_pillars()
			_: _level6_start_predictive_slash_spam(5 if danger < 0.5 else 8)
		level6_attack_timer = lerpf(2.2, 0.9, danger)
	queue_redraw()


func _level6_start_void_wall() -> void:
	var view: Rect2 = _king_visible_world_rect()
	var wall: VoidWall = VoidWall.new()
	var side: bool = target.global_position.x > view.get_center().x
	var extra: float = maxf(220.0, view.size.x * 0.48)
	wall.start_x = (view.position.x - extra) if side else (view.end.x + extra)
	wall.end_x = (view.end.x + extra) if side else (view.position.x - extra)
	wall.width = 58.0
	wall.warning = 1.30
	wall.travel = clampf(absf(wall.end_x - wall.start_x) / 285.0, 3.30, 8.0)
	level6_void_walls.append(wall)
	king_post_attack_timer = maxf(king_post_attack_timer, wall.warning + wall.travel + 0.40)


func _level6_update_void_walls(delta: float) -> void:
	if level6_void_walls.is_empty():
		return
	for idx: int in range(level6_void_walls.size() - 1, -1, -1):
		var wall: VoidWall = level6_void_walls[idx]
		wall.elapsed += delta
		if wall.elapsed < wall.warning:
			continue
		var t: float = (wall.elapsed - wall.warning) / wall.travel
		if t > 1.0:
			level6_void_walls.remove_at(idx)
			continue
		var x: float = lerpf(wall.start_x, wall.end_x, clampf(t, 0.0, 1.0))
		wall.sweep_history.push_front(x)
		if wall.sweep_history.size() > 50:
			wall.sweep_history.pop_back()
		if not is_instance_valid(target):
			continue
		var distance_from_wall: float = absf(target.global_position.x - x)
		var is_dashing: bool = false
		if distance_from_wall <= wall.width * 0.5 + 120.0:
			for entry: Dictionary in target.get_property_list():
				if String(entry.get("name", "")) == "dash_remaining":
					is_dashing = float(target.get("dash_remaining")) > 0.0
					break
			if not is_dashing and absf(target.velocity.x) >= 300.0:
				var player_sprite: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
				if player_sprite != null and player_sprite.animation == &"dash":
					is_dashing = true
		if is_dashing and distance_from_wall <= wall.width * 0.5 + 100.0:
			wall.dashed_through = true
		if wall.dashed_through:
			continue
		if distance_from_wall < wall.width * 0.34 + 8.0:
			if wall.last_damage_time < 0.0:
				wall.last_damage_time = wall.elapsed
				if target.has_method(&"tomar_dano"):
					target.call(&"tomar_dano", skull_damage, Vector2(x, target.global_position.y))
	queue_redraw()


func _level6_start_predictive_slash_spam(amount: int) -> void:
	king_special_kind = 36
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view) + view.size.length()
	var count: int = clampi(amount, 3, 9)
	var ahead: Vector2 = target.global_position + target.velocity * 0.35
	for i: int in range(count):
		var angle: float = deg_to_rad(90.0) if i % 3 == 0 else (deg_to_rad(32.0) if i % 3 == 1 else deg_to_rad(148.0))
		var axis: Vector2 = Vector2.RIGHT.rotated(angle)
		var normal: Vector2 = Vector2(-axis.y, axis.x)
		var lane: Vector2 = ahead + normal * float((i % 4) - 2) * 82.0
		lane += Vector2(randf_range(-28.0, 28.0), randf_range(-18.0, 18.0))
		_queue_king_slash(lane - axis * reach, lane + axis * reach, 0.82 + float(i % 3) * 0.06, float(i) * 0.31)
	king_gravefall_warning_timer = 1.05 + float(count - 1) * 0.31 + 0.55


func _level6_start_void_rails(waves: int) -> void:
	king_special_kind = 12
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var middle_x: float = target.global_position.x
	var total: int = clampi(waves, 1, 3)
	for wave: int in range(total):
		var shift: float = (float(wave % 2) * 70.0) - 35.0
		for side: int in [-1, 1]:
			var x: float = middle_x + float(side) * 140.0 + shift
			_queue_king_slash(Vector2(x, view.position.y - reach),
				Vector2(x, view.end.y + reach), 0.92, float(wave) * 0.77)
	king_gravefall_warning_timer = 0.92 + float(total - 1) * 0.77 + 0.42


func _level6_start_void_twin_cut(cuts: int) -> void:
	king_special_kind = 13
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var anchor: Vector2 = target.global_position
	var total: int = clampi(cuts, 2, 3)
	for i: int in range(total):
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(42.0 if i % 2 == 0 else -42.0))
		var line_center: Vector2 = anchor + Vector2(float(i - 1) * 73.0, 0.0)
		_queue_king_slash(line_center - direction * reach,
			line_center + direction * reach, 0.95, float(i) * 0.52)
	king_gravefall_warning_timer = 0.95 + float(total - 1) * 0.52 + 0.42


func _level6_start_void_crown_fan(rays: int) -> void:
	king_special_kind = 14
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var center_dir: Vector2 = target.global_position - global_position
	if center_dir.length_squared() < 1.0:
		center_dir = Vector2.DOWN
	center_dir = center_dir.normalized()
	var total: int = clampi(rays, 2, 5)
	for i: int in range(total):
		var angle: float = (float(i) - (float(total - 1) / 2.0)) * deg_to_rad(13.0)
		var direction: Vector2 = center_dir.rotated(angle)
		_queue_king_slash(global_position - direction * 75.0,
			global_position + direction * reach, 0.95, float(i) * 0.24)
	king_gravefall_warning_timer = 0.95 + float(total - 1) * 0.24 + 0.43


func _level6_start_void_staircase(waves: int) -> void:
	king_special_kind = 15
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var anchor: Vector2 = target.global_position
	var total: int = clampi(waves, 2, 3)
	for wave: int in range(total):
		if wave % 2 == 0:
			for side: int in [-1, 1]:
				var x: float = anchor.x + float(side) * 125.0 + float(wave) * 35.0
				_queue_king_slash(Vector2(x, view.position.y - reach),
					Vector2(x, view.end.y + reach), 1.0, float(wave) * 0.86)
		else:
			var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(37.0))
			_queue_king_slash(anchor - direction * reach,
				anchor + direction * reach, 0.94, float(wave) * 0.86)
	king_gravefall_warning_timer = 1.0 + float(total - 1) * 0.86 + 0.43


func _level6_update_guard_visuals(delta: float) -> void:
	if level6_stage != Level6Stage.PHASE_ONE:
		return
	for guard: CharacterBody2D in king_elite_guards:
		if not is_instance_valid(guard) or guard.is_queued_for_deletion():
			continue
		var id: int = guard.get_instance_id()
		if guard.has_method(&"is_dead") and bool(guard.call(&"is_dead")):
			_level6_remove_guard_aura(guard)
			continue
		var current: int = int(guard.get("hp"))
		var last: int = int(level6_guard_previous_hp.get(id, current))
		var remaining: float = maxf(0.0, float(level6_guard_flash_timers.get(id, 0.0)) - delta)
		if current < last:
			remaining = 0.11
			_level6_guard_hit_sparks(guard.global_position)
		level6_guard_previous_hp[id] = current
		level6_guard_flash_timers[id] = remaining
		for visual_node: Node in guard.find_children("*", "AnimatedSprite2D", true, false):
			var art: AnimatedSprite2D = visual_node as AnimatedSprite2D
			if art != null and art.material is ShaderMaterial:
				(art.material as ShaderMaterial).set_shader_parameter("hit_flash", 1.0 if remaining > 0.0 else 0.0)
		if current <= 0:
			_level6_remove_guard_aura(guard)


func _level6_guard_hit_sparks(at_pos: Vector2) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.texture = _level6_get_particle_texture()
	fx.one_shot = true
	fx.amount = 13
	fx.lifetime = 0.32
	fx.explosiveness = 1.0
	fx.spread = 180.0
	fx.initial_velocity_min = 25.0
	fx.initial_velocity_max = 110.0
	fx.gravity = Vector2(0.0, 45.0)
	fx.color = Color(0.96, 0.97, 1.0, 0.90)
	fx.z_index = 80
	parent_node.add_child(fx)
	fx.global_position = at_pos
	fx.emitting = true
	get_tree().create_timer(0.55).timeout.connect(fx.queue_free)


func _level6_remove_guard_aura(guard: CharacterBody2D) -> void:
	if not is_instance_valid(guard):
		return
	for name: String in ["VoidMenacingSoftAura", "VoidMenacingSmoke"]:
		var effect: Node = guard.get_node_or_null(name)
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			effect.queue_free()


func _level6_start_interleaved_pillars() -> void:
	king_special_kind = 31
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var left: float = view.position.x - view.size.x * 0.72
	var right: float = view.end.x + view.size.x * 0.72
	var spacing: float = 112.0
	var target_x: float = target.global_position.x
	var moves: Array[float] = [-104.0, 95.0, -65.0]
	var player_vx: float = target.velocity.x if target is CharacterBody2D else 0.0
	for wave: int in range(3):
		var safe_x: float = clampf(target_x + moves[wave] + player_vx * 0.14,
			view.position.x + 75.0, view.end.x - 75.0)
		var x: float = left + float(wave % 2) * 55.0
		while x <= right:
			if absf(x - safe_x) > 92.0:
				_queue_king_slash(Vector2(x, view.position.y - reach),
					Vector2(x, view.end.y + reach), 0.86, float(wave) * 0.75)
			x += spacing
	king_gravefall_warning_timer = 0.86 + 2.0 * 0.75 + 0.78


func _level6_start_horizontal_lanes(rows: int) -> void:
	king_special_kind = 32
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var total: int = clampi(rows, 2, 3)
	var center_y: float = target.global_position.y
	for i: int in range(total):
		var lane_y: float = center_y + (float(i) - float(total - 1) * 0.5) * 108.0
		_queue_king_slash(Vector2(view.position.x - reach, lane_y),
			Vector2(view.end.x + reach, lane_y), 0.88, float(i) * 0.62)
	king_gravefall_warning_timer = 0.88 + float(total - 1) * 0.62 + 0.75


func _level6_start_marker_cuts(amount: int) -> void:
	if level6_stage != Level6Stage.PHASE_TWO or level6_second_markers.is_empty():
		return
	king_special_kind = 38
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view) + view.size.length()
	var valid: Array[Marker2D] = []
	for marker: Marker2D in level6_second_markers:
		if is_instance_valid(marker):
			valid.append(marker)
	if valid.is_empty():
		king_gravefall_active = false
		return
	valid.shuffle()
	var count: int = mini(clampi(amount, 2, 6), valid.size())
	for i: int in range(count):
		var anchor: Vector2 = _level6_marker_position(valid[i])
		if (i + level6_attack_round) % 2 == 0:
			_queue_king_slash(
				Vector2(anchor.x, view.position.y - reach),
				Vector2(anchor.x, view.end.y + reach),
				0.98, float(i) * 0.44)
		else:
			_queue_king_slash(
				Vector2(view.position.x - reach, anchor.y),
				Vector2(view.end.x + reach, anchor.y),
				0.98, float(i) * 0.44)
	king_gravefall_warning_timer = 0.98 + float(count - 1) * 0.44 + 0.75


func _level6_spear_spawn_is_clear(world_pos: Vector2) -> bool:
	var test_shape: CircleShape2D = CircleShape2D.new()
	test_shape.radius = 27.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = test_shape
	query.transform = Transform2D(0.0, world_pos)
	query.collision_mask = terrain_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(target):
		excluded.append(target.get_rid())
	query.exclude = excluded
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _level6_spear_terrain_contact(from_world: Vector2, to_world: Vector2) -> bool:
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(target):
		excluded.append(target.get_rid())
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from_world, to_world, terrain_mask, excluded)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _level6_start_void_swords(amount: int) -> void:
	if not is_instance_valid(target):
		return
	if not level6_void_swords.is_empty():
		return
	king_special_kind = 34
	var count: int = clampi(amount, 1, 7)
	var side_sign: float = -1.0 if randf() < 0.5 else 1.0
	var anchor_x: float = target.global_position.x + side_sign * 175.0
	var anchor_y: float = target.global_position.y - maxf(95.0, level6_spear_height_above_player)
	var scheduled_time: float = 0.0
	var pair_slot: int = -1
	if count >= 5 and randf() < 0.32:
		pair_slot = randi_range(1, count - 1)
	for i: int in range(count):
		var x: float = anchor_x + (float(i) - float(count - 1) * 0.5) * 48.0
		var spawn_point: Vector2 = Vector2(x, anchor_y)
		var clear: bool = false
		for attempt: int in range(7):
			spawn_point.y = anchor_y - float(attempt) * 32.0
			if _level6_spear_spawn_is_clear(spawn_point):
				clear = true
				break
		if not clear:
			continue
		var blade: VoidSword = VoidSword.new()
		blade.position = spawn_point
		blade.aim = target.global_position
		blade.direction = blade.position.direction_to(blade.aim)
		if i > 0 and i != pair_slot:
			scheduled_time += randf_range(0.23, 0.30)
		blade.delay = scheduled_time
		blade.warning = 0.75
		blade.aim_lock_time = 0.025
		blade.fade_time = 0.24
		level6_void_swords.append(blade)
	king_post_attack_timer = maxf(king_post_attack_timer, 1.3)


func _level6_update_void_swords(delta: float) -> void:
	if level6_void_swords.is_empty() or not is_instance_valid(target):
		return
	for index: int in range(level6_void_swords.size() - 1, -1, -1):
		var spear: VoidSword = level6_void_swords[index]
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
			var next_pos: Vector2 = old_pos + spear.direction * 340.0 * delta
			if _level6_spear_terrain_contact(old_pos, next_pos + spear.direction * 30.0):
				level6_void_swords.remove_at(index)
				continue
			spear.position = next_pos
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				target.global_position, old_pos, next_pos)
			if not spear.hit and closest.distance_squared_to(target.global_position) < 18.0 * 18.0:
				spear.hit = true
				if target.has_method(&"tomar_dano"):
					target.call(&"tomar_dano", 1, spear.position)
			if spear.hit or spear.flight > 2.0:
				level6_void_swords.remove_at(index)
	queue_redraw()


func _level6_start_void_dash_combo(amount: int) -> void:
	level6_dash_echoes.clear()
	king_special_kind = 35
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view) + view.size.length() * 0.5
	var count: int = clampi(amount, 2, 5)
	var predicted: Vector2 = target.global_position + target.velocity * 0.22
	for i: int in range(count):
		var angle: float = deg_to_rad(28.0 if i % 2 == 0 else 152.0)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var offset: Vector2 = Vector2(float(i % 3 - 1) * 55.0, float(i % 2) * 33.0)
		var center: Vector2 = predicted + offset
		_queue_king_slash(center - direction * reach, center + direction * reach,
			0.94, float(i) * 0.40)
	king_gravefall_warning_timer = 0.94 + float(count - 1) * 0.40 + 0.80
	king_post_attack_timer = maxf(king_post_attack_timer, 1.0)


func _level6_update_dash_echoes(delta: float) -> void:
	if level6_dash_echoes.is_empty() or not is_instance_valid(target):
		return
	for index: int in range(level6_dash_echoes.size() - 1, -1, -1):
		var echo: VoidDashEcho = level6_dash_echoes[index]
		echo.elapsed += delta
		var active: float = echo.elapsed - echo.delay
		if active < 0.0:
			continue
		if active >= echo.warn and active <= echo.warn + echo.travel:
			var progress: float = clampf((active - echo.warn) / echo.travel, 0.0, 1.0)
			var head: Vector2 = echo.start.lerp(echo.end, progress)
			if not echo.hit and head.distance_to(target.global_position) < 32.0:
				echo.hit = true
				if target.has_method(&"tomar_dano"):
					target.call(&"tomar_dano", skull_damage, head)
		if active > echo.warn + echo.travel + 0.24:
			level6_dash_echoes.remove_at(index)
	queue_redraw()


func _level6_draw_extra_attacks() -> void:
	if not level6_void_walls.is_empty():
		var view: Rect2 = _king_visible_world_rect()
		var top: float = view.position.y - view.size.y * 1.6
		var bottom: float = view.end.y + view.size.y * 1.6
		for wall: VoidWall in level6_void_walls:
			var progress: float = clampf(wall.elapsed / maxf(0.01, wall.warning), 0.0, 1.0)
			var active: bool = wall.elapsed >= wall.warning
			var x: float = wall.start_x
			if active:
				x = lerpf(wall.start_x, wall.end_x, clampf((wall.elapsed - wall.warning) / wall.travel, 0.0, 1.0))
				for trail_i: int in range(3, wall.sweep_history.size(), 3):
					var tx: float = wall.sweep_history[trail_i]
					var age: float = float(trail_i) / 50.0
					var fade: float = pow(1.0 - age, 1.25)
					var trail_start: Vector2 = to_local(Vector2(tx, top))
					var trail_end: Vector2 = to_local(Vector2(tx, bottom))
					draw_line(trail_start, trail_end,
						Color(0.008, 0.008, 0.014, 0.59 * fade),
						wall.width * (0.84 - age * 0.27), true)
					draw_line(trail_start, trail_end,
						Color(0.74, 0.77, 0.85, 0.28 * fade), 2.3, true)
			var alpha: float = 0.16 + 0.72 * progress if not active else 0.96
			var draw_x: float = x
			if not active:
				draw_x = clampf(x, view.position.x + 12.0, view.end.x - 12.0)
			var a: Vector2 = to_local(Vector2(draw_x, top))
			var b: Vector2 = to_local(Vector2(draw_x, bottom))
			draw_line(a, b, Color(0.85, 0.87, 0.94, 0.17 * alpha), wall.width + 9.0, true)
			draw_line(a, b, Color(0.004, 0.005, 0.010, alpha), wall.width, true)
			draw_line(a, b, Color(0.96, 0.96, 1.0, 0.58 * alpha), 3.0, true)
	for blade: VoidSword in level6_void_swords:
		if blade.elapsed < blade.delay:
			continue
		var local: Vector2 = to_local(blade.position)
		var forward: Vector2 = blade.direction.normalized()
		var side: Vector2 = Vector2(-forward.y, forward.x)
		var opacity: float = clampf((blade.elapsed - blade.delay) / blade.fade_time, 0.0, 1.0)
		var spear_outline: PackedVector2Array = PackedVector2Array([
			local + forward * 31.0,
			local + forward * 4.0 + side * 5.0,
			local - forward * 14.0 + side * 2.2,
			local - forward * 20.0,
			local - forward * 14.0 - side * 2.2,
			local + forward * 4.0 - side * 5.0
		])
		draw_colored_polygon(spear_outline, Color(0.96, 0.975, 1.0, 0.82 * opacity))
		var spear_groove: PackedVector2Array = PackedVector2Array([
			local + forward * 23.0,
			local + forward * 3.0 + side * 2.2,
			local - forward * 10.0,
			local + forward * 3.0 - side * 2.2
		])
		draw_colored_polygon(spear_groove, Color(0.08, 0.09, 0.12, 0.60 * opacity))
		draw_line(local - forward * 23.0, local - forward * 11.0,
			Color(0.86, 0.90, 0.99, 0.66 * opacity), 2.1, true)
		for i: int in range(blade.trail.size()):
			var after_point: Vector2 = to_local(blade.trail[i])
			var fade: float = pow(1.0 - float(i) / 12.0, 1.6) * 0.29
			draw_line(after_point - forward * 19.0, after_point + forward * 23.0,
				Color(0.82, 0.88, 1.0, fade), 2.8, true)


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
	king_tp_phase = 0
	king_tp_elapsed = 0.0
	king_tp_hold_remaining = maxf(2.0, king_teleport_hold_seconds)
	king_tp_destination = global_position
	king_tp_guard_mode = false
	king_tp_last_perch = -1
	king_tp_failed_attempts = 0
	king_tp_guard_perch_locked = false
	king_guard_perch_clock = 0.0
	king_attack_cast_remaining = 0.0
	king_attack_cast_total = 0.0
	king_final_pattern_round = 0
	king_dead_guard_position_known = false
	add_to_group(&"king_necromancer")
	king_skull_volley_timer = 1.2
	king_skull_spawns_remaining = 0
	max_hp = maxi(max_hp, maxi(340, king_max_hp))
	hp = max_hp
	activation_range = maxf(activation_range, 600.0)
	hover_speed *= king_hover_speed_multiplier
	arena_roam_distance = maxf(arena_roam_distance, 280.0)
	skeleton_count = 1
	slots.clear()
	king_base_sprite_scale = sprite.scale
	sprite.scale = king_base_sprite_scale * clampf(king_visual_scale, 3.5, 4.6)
	body_shape.scale *= 1.12
	sprite_tint = Color(0.92, 0.61, 1.0, 1.0)
	sprite.self_modulate = sprite_tint
	_build_king_crown()
	king_gravefall_cooldown_timer = 0.30
	king_elite_timer = 0.0
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
	return sprite.global_position.y - global_position.y + _king_visual_half_height()


func _build_king_crown() -> void:
	if level6_mode or _level6_detect_scene():
		return
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
	if level6_mode:
		if is_instance_valid(king_crown_root):
			king_crown_root.visible = false
		return
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
	king_hud.name = "VoidKingBossHUD" if level6_mode else "GraveMonarchBossHUD"
	king_hud.layer = 930 if level6_mode else 110
	var hud_parent: Node = get_tree().current_scene
	if hud_parent == null:
		hud_parent = get_tree().root
	hud_parent.add_child.call_deferred(king_hud)
	var frame := VBoxContainer.new()
	frame.name = "BossHeader"
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.offset_left = -246.0
	frame.offset_right = 246.0
	frame.offset_top = 16.0
	frame.offset_bottom = 94.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	king_hud.add_child(frame)
	var title := Label.new()
	title.text = "THE VOID KING" if level6_mode else "THE GRAVE MONARCH | KING NECROMANCER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.68, 0.70, 0.76) if level6_mode else Color(0.97, 0.79, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.018))
	title.add_theme_constant_override("outline_size", 2 if level6_mode else 4)
	frame.add_child(title)
	if level6_mode:
		level6_hud_gradient_bar = ColorRect.new()
		level6_hud_gradient_bar.name = "VoidHealthFade"
		level6_hud_gradient_bar.custom_minimum_size = Vector2(480.0, 19.0)
		level6_hud_gradient_bar.color = Color.WHITE
		level6_hud_gradient_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var health_shader := Shader.new()
		health_shader.code = """shader_type canvas_item;
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	float edge_left = smoothstep(0.0, 0.035, UV.x);
	float edge_right = 1.0 - smoothstep(0.96, 1.0, UV.x);
	float edge_top = smoothstep(0.0, 0.20, UV.y);
	float edge_bottom = 1.0 - smoothstep(0.76, 1.0, UV.y);
	float soft_end = 1.0 - smoothstep(health_ratio - 0.025, health_ratio + 0.014, UV.x);
	vec3 abyss = vec3(0.012, 0.013, 0.018);
	vec3 remaining = mix(vec3(0.12, 0.13, 0.15), vec3(0.31, 0.32, 0.35), 1.0 - UV.y);
	vec3 ink = mix(abyss, remaining, soft_end);
	float alpha = 0.93 * edge_left * edge_right * edge_top * edge_bottom;
	COLOR = vec4(ink, alpha);
} """
		level6_hud_gradient_material = ShaderMaterial.new()
		level6_hud_gradient_material.shader = health_shader
		level6_hud_gradient_bar.material = level6_hud_gradient_material
		frame.add_child(level6_hud_gradient_bar)
	else:
		king_hud_bar = ProgressBar.new()
		king_hud_bar.name = "KingHP"
		king_hud_bar.custom_minimum_size = Vector2(470.0, 18.0)
		king_hud_bar.min_value = 0.0
		king_hud_bar.max_value = float(max_hp)
		king_hud_bar.value = float(hp)
		king_hud_bar.show_percentage = true
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
	king_hud_status.add_theme_font_size_override("font_size", 12 if level6_mode else 13)
	king_hud_status.add_theme_color_override("font_color", Color(0.61, 0.63, 0.68) if level6_mode else Color(1.0, 0.86, 0.96))
	frame.add_child(king_hud_status)
	king_hud.visible = not level6_mode


func _update_king_hp_label() -> void:
	if is_king and not is_instance_valid(king_hud) and is_inside_tree():
		_create_king_boss_hud()
	if is_instance_valid(king_hud):
		king_hud.visible = true
	if is_instance_valid(king_hp_label):
		king_hp_label.text = "KING  %d/%d" % [hp, max_hp]
	if is_instance_valid(level6_hud_gradient_material):
		level6_hud_gradient_material.set_shader_parameter("health_ratio", clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0))
	if is_instance_valid(king_hud_bar):
		king_hud_bar.max_value = float(max_hp)
		king_hud_bar.value = float(hp)
		king_hud_bar.tooltip_text = "KING HP: %d / %d" % [hp, max_hp]
	if level6_mode and is_instance_valid(king_hud):
		king_hud.visible = level6_stage in [Level6Stage.REVEAL, Level6Stage.PHASE_ONE, Level6Stage.PHASE_TWO,
			Level6Stage.THIRD_REVEAL, Level6Stage.PHASE_THREE]
	if is_instance_valid(king_hud_status):
		if level6_mode:
			match level6_stage:
				Level6Stage.PHASE_ONE:
					if king_shield_phase == KingShieldPhase.SHIELDED:
						king_hud_status.text = "VOID WARD | DEFEAT THE ENHANCED MENACING GUARD"
					elif king_shield_phase == KingShieldPhase.BREAKING:
						king_hud_status.text = "THE WARD SHATTERS"
					elif king_shield_phase == KingShieldPhase.EXPOSED:
						king_hud_status.text = "ONE LAST STRIKE"
					else:
						king_hud_status.text = "VOID KING | BREAK HIM DOWN TO 1 HP"
				Level6Stage.PHASE_TWO:
					king_hud_status.text = "PHASE TWO | THE VOID KING"
				Level6Stage.THIRD_REVEAL:
					king_hud_status.text = "THE VOID KING'S LAST STAND"
				Level6Stage.PHASE_THREE:
					king_hud_status.text = "FINAL DUEL | %d STRIKES REMAIN" % hp
				_:
					king_hud_status.text = ""
			return
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
		elif king_last_stand_started and not king_gravefall_active:
			king_hud_status.text = "LAST STAND  |  THE GRAVE MONARCH UNLEASHED"
		elif king_shield_phase == KingShieldPhase.EXPOSED and hp <= 1:
			king_hud_status.text = "THE KING CLINGS TO LIFE  |  PURPLE REVIVAL INCOMING"
		elif king_shield_phase == KingShieldPhase.EXPOSED and not king_gravefall_active:
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
			king_hud_status.text = "ROYAL CROSSWEAVE  |  Dodge the crossing blades"
		elif king_special_kind == 9:
			king_hud_status.text = "RICHOCHET X  |  Watch the reflected warnings"
		elif king_special_kind == 10:
			king_hud_status.text = "ROYAL CASCADE  |  Lances, then crossed cuts"
		elif king_special_kind == 11:
			king_hud_status.text = "GRAVE GUILLOTINE  |  Three descending cuts"
		elif king_special_kind == 12:
			king_hud_status.text = "BONE CATHEDRAL  |  Shifting columns of death"
		elif king_special_kind == 13:
			king_hud_status.text = "ROYAL CROSSFIRE  |  The third line closes the gap"
		elif king_special_kind == 14:
			king_hud_status.text = "PHANTOM EXECUTION  |  Follow the warned lanes"
		elif king_special_kind == 15:
			king_hud_status.text = "MOURNING BELLS  |  Horizontal rows, then a vertical strike"
		elif king_special_kind == 16:
			king_hud_status.text = "SHATTERED THRONE  |  Find the center and move"
		elif king_special_kind == 17:
			king_hud_status.text = "THORN PROCESSION  |  Follow the staggered warnings"
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
	var original_warning: float = maxf(0.52, warning_time * minf(0.78, king_last_stand_warning_factor)) if king_last_stand_started else maxf(0.34, warning_time)
	slash.warning = original_warning + king_extra_laser_warning_seconds
	slash.delay = maxf(0.0, delay_time)
	if king_attack_cast_remaining > 0.0:
		slash.delay += king_attack_cast_total
	king_royal_slashes.append(slash)


func _begin_king_attack_cast() -> void:
	if king_tp_phase != 0 or king_revival_cast_fx > 0.0:
		return
	king_attack_cast_total = maxf(0.45, king_attack_cast_seconds)
	king_attack_cast_remaining = king_attack_cast_total
	_update_king_attack_cast_pose(0.0)


func _update_king_attack_cast_pose(delta: float) -> void:
	if king_attack_cast_remaining <= 0.0:
		return
	if king_tp_phase != 0 or king_revival_cast_fx > 0.0:
		return
	king_attack_cast_remaining = maxf(0.0, king_attack_cast_remaining - delta)
	if king_attack_cast_remaining <= 0.0:
		_play(&"idle", true)
		return
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	if level6_mode and level6_stage in [Level6Stage.PHASE_ONE, Level6Stage.PHASE_TWO, Level6Stage.PHASE_THREE]:
		var safe_cast: StringName = &"buffenemies" if sprite.sprite_frames.has_animation(&"buffenemies") else &"spawnenemies"
		if not sprite.sprite_frames.has_animation(safe_cast):
			safe_cast = &"idle"
		var safe_count: int = sprite.sprite_frames.get_frame_count(safe_cast)
		if safe_count > 0:
			var cast_progress: float = 1.0 - king_attack_cast_remaining / maxf(0.01, king_attack_cast_total)
			sprite.animation = safe_cast
			sprite.stop()
			sprite.set_frame_and_progress(clampi(int(cast_progress * float(safe_count)), 0, safe_count - 1), 0.0)
		return
	var cast_animation: StringName = REVIVE_ANIMATION
	if not sprite.sprite_frames.has_animation(cast_animation):
		cast_animation = &"spawnenemies"
	if not sprite.sprite_frames.has_animation(cast_animation):
		return
	var frames: int = sprite.sprite_frames.get_frame_count(cast_animation)
	if frames <= 0:
		return
	var progress: float = 1.0 - king_attack_cast_remaining / maxf(0.01, king_attack_cast_total)
	var frame: int = clampi(int(floor(progress * float(frames))), 0, frames - 1)
	sprite.animation = cast_animation
	sprite.stop()
	sprite.set_frame_and_progress(frame, 0.0)


func _king_royal_slash_hits_player(slash: RoyalSlash) -> bool:
	if not is_instance_valid(target):
		return false
	var v: Vector2 = slash.to_world - slash.from_world
	if v.length_squared() < 1.0:
		return false
	var beam: RectangleShape2D = RectangleShape2D.new()
	var effective_width: float = slash.width_override if slash.width_override > 0.0 else king_slash_hitbox_width
	beam.size = Vector2(v.length(), maxf(3.0, effective_width))
	var beam_pose: Transform2D = Transform2D(v.angle(), (slash.from_world + slash.to_world) * 0.5)
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
			_king_royal_slash_deal_damage(slash)
		var stop_at: float = attack_at + king_slash_expand_seconds + king_slash_fade_seconds
		if slash.elapsed > stop_at:
			king_royal_slashes.remove_at(index)
	if was_slashing and king_royal_slashes.is_empty():
		king_post_attack_timer = maxf(king_post_attack_timer,
			king_post_attack_pause * (0.65 if king_last_stand_started else 1.0))


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
		var slash_width: float = slash.width_override if slash.width_override > 0.0 else king_slash_hitbox_width
		if level6_mode:
			if not slash.fired:
				var t6: float = clampf(active_time / maxf(0.01, slash.warning), 0.0, 1.0)
				var a6: float = clampf(t6 / 0.2, 0.0, 1.0) * (0.55 + 0.40 * t6)
				var w6: float = slash_width
				if slash.phase3_pulsing_warning:
					var breathe6: float = 0.5 + 0.5 * sin(active_time * TAU * 4.5)
					var pulse_length: float = 1.0 if t6 > 0.84 else (0.74 + 0.22 * breathe6)
					var visible_tip: Vector2 = a.lerp(b, pulse_length)
					var pulsing_width: float = w6 * (0.84 + 0.16 * breathe6)
					draw_line(a, b, Color(0.82, 0.85, 0.92, a6 * 0.18), w6 * 1.18, true)
					draw_line(a, b, Color(0.012, 0.013, 0.019, a6 * 0.38), w6, true)
					draw_line(a, visible_tip, Color(0.012, 0.013, 0.019, a6 * 0.97), pulsing_width, true)
					draw_line(a, visible_tip, Color(0.94, 0.95, 1.0, a6 * 0.68), maxf(1.5, w6 * 0.14), true)
					draw_circle(a, 3.0 + 3.0 * breathe6, Color(0.94, 0.95, 1.0, a6 * 0.65))
				else:
					draw_line(a, b, Color(0.82, 0.85, 0.92, a6 * 0.22), w6 * 1.2, true)
					draw_line(a, b, Color(0.012, 0.013, 0.019, a6 * 0.93), w6, true)
					draw_line(a, b, Color(0.9, 0.91, 1.0, a6 * 0.56), maxf(1.5, w6 * 0.13), true)
					for endpoint: Vector2 in [a, b]:
						draw_circle(endpoint, maxf(2.0, w6 * 0.19), Color(0.88, 0.89, 1.0, a6 * 0.45))
				continue
			var after6: float = maxf(0.0, active_time - slash.warning)
			var e6: float = maxf(0.01, king_slash_expand_seconds)
			var f6: float = maxf(0.01, king_slash_fade_seconds)
			var remaining6: float = clampf(1.0 - maxf(0.0, after6 - e6) / f6, 0.0, 1.0)
			var width6: float = lerpf(slash_width * 1.04, 0.6, 1.0 - remaining6)
			draw_line(a, b, Color(0.82, 0.84, 0.92, remaining6 * 0.22), width6 * 1.23, true)
			draw_line(a, b, Color(0.004, 0.005, 0.009, remaining6 * 0.98), width6, true)
			draw_line(a, b, Color(0.94, 0.95, 1.0, remaining6 * 0.69), maxf(0.8, width6 * 0.17), true)
			continue
		if not slash.fired:
			var t: float = clampf(active_time / maxf(0.01, slash.warning), 0.0, 1.0)
			var fade_in: float = clampf(t / 0.30, 0.0, 1.0)
			var breathe: float = 0.86 + 0.14 * sin(t * TAU * 5.0)
			var alpha: float = fade_in * breathe * (0.45 + 0.40 * t)
			draw_line(a, b, Color(0.48, 0.05, 0.90, alpha * 0.22), slash_width * 1.15, true)
			draw_line(a, b, Color(0.85, 0.31, 1.0, alpha * 0.78), slash_width, true)
			draw_line(a, b, Color(1.0, 0.84, 1.0, alpha * 0.75), maxf(1.5, slash_width * 0.18), true)
			if slash.ricochet:
				for end_point: Vector2 in [a, b]:
					draw_circle(end_point, slash_width * 0.51,
						Color(0.80, 0.30, 1.0, alpha * 0.62))
					draw_circle(end_point, slash_width * 0.16,
						Color(1.0, 0.91, 1.0, alpha * 0.8))
			if slash.ricochet:
				draw_arc(a, 15.0 + 3.0 * sin(t * TAU * 2.0), 0.0, TAU, 24,
					Color(0.98, 0.64, 1.0, alpha), 3.0, true)
				draw_circle(a, 5.0, Color(1.0, 0.87, 1.0, alpha * 0.8))
			continue
		var after_hit: float = maxf(0.0, active_time - slash.warning)
		var expand_time: float = maxf(0.01, king_slash_expand_seconds)
		var fade_time: float = maxf(0.01, king_slash_fade_seconds)
		var width: float = 1.0
		var alpha: float = 1.0
		if after_hit < expand_time:
			var grow: float = clampf(after_hit / expand_time, 0.0, 1.0)
			width = lerpf(slash_width * 0.88, slash_width * 1.08, grow)
		else:
			var shrink: float = clampf((after_hit - expand_time) / fade_time, 0.0, 1.0)
			width = lerpf(slash_width * 1.08, 0.4, shrink * shrink * (3.0 - 2.0 * shrink))
			alpha = pow(1.0 - shrink, 1.25)
		draw_line(a, b, Color(0.58, 0.06, 0.95, alpha * 0.24), width * 1.15, true)
		draw_line(a, b, Color(0.88, 0.34, 1.0, alpha * 0.90), width, true)
		draw_line(a, b, Color(1.0, 0.95, 1.0, alpha), maxf(0.6, width * 0.30), true)
		if slash.ricochet:
			for end_point: Vector2 in [a, b]:
				draw_circle(end_point, maxf(1.0, width * 0.52),
					Color(0.88, 0.37, 1.0, alpha * 0.85))
				draw_circle(end_point, maxf(0.6, width * 0.17),
					Color(1.0, 0.96, 1.0, alpha))
		for spark_i: int in range(1, 6):
			var p: Vector2 = a.lerp(b, float(spark_i) / 6.0)
			var spark_size: float = maxf(0.0, width * 0.65)
			draw_line(p - normal * spark_size, p + normal * spark_size,
				Color(1.0, 0.78, 1.0, alpha * 0.56), 1.4, true)


func _king_visible_world_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var top_left: Vector2 = inverse * Vector2.ZERO
	var bottom_right: Vector2 = inverse * viewport_size
	return Rect2(top_left, bottom_right - top_left).abs()


func _king_laser_reach(view: Rect2) -> float:
	return maxf(view.size.length() * maxf(2.0, king_laser_screen_reach_multiplier),
		view.size.length() + 1800.0)


func _start_king_gravefall() -> void:
	king_special_kind = 1
	king_gravefall_active = true
	king_gravefall_warning_timer = maxf(0.65, king_gravefall_warning_time)
	king_gravefall_columns.clear()
	var view: Rect2 = _king_visible_world_rect()
	var center_x: float = clampf(target.global_position.x, view.position.x + 120.0, view.end.x - 120.0)
	var wave: int = 0
	for offset: float in [-330.0, -165.0, 0.0, 165.0, 330.0]:
		var x: float = center_x + offset
		if x < view.position.x - 20.0 or x > view.end.x + 20.0:
			continue
		king_gravefall_columns.append(x)
		_queue_king_slash(Vector2(x, view.position.y - _king_laser_reach(view)),
			Vector2(x, view.end.y + _king_laser_reach(view)),
			maxf(0.72, king_gravefall_warning_time), float(wave) * 0.38)
		wave += 1
	king_gravefall_warning_timer = maxf(king_gravefall_warning_timer,
		maxf(0.72, king_gravefall_warning_time) + float(maxi(0, wave - 1)) * 0.38 + 0.32)
	queue_redraw()


func _start_king_sweep() -> void:
	king_special_kind = 2
	king_gravefall_active = true
	king_gravefall_warning_timer = 0.92
	king_sweep_y.clear()
	var view: Rect2 = _king_visible_world_rect()
	var player_y: float = clampf(target.global_position.y, view.position.y + 110.0, view.end.y - 110.0)
	var wave: int = 0
	for offset: float in [-220.0, -110.0, 0.0, 110.0, 220.0]:
		var y: float = player_y + offset
		if y < view.position.y - 20.0 or y > view.end.y + 20.0:
			continue
		king_sweep_y.append(y)
		_queue_king_slash(Vector2(view.position.x - _king_laser_reach(view), y),
			Vector2(view.end.x + _king_laser_reach(view), y), 0.85, float(wave) * 0.38)
		wave += 1
	king_gravefall_warning_timer = maxf(0.92, 0.85 + float(maxi(0, wave - 1)) * 0.38 + 0.32)
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
			_queue_king_slash(Vector2(x, view.position.y - _king_laser_reach(view)),
					Vector2(x, view.end.y + _king_laser_reach(view)), 0.95, float(wave) * 0.32)
	queue_redraw()


func _start_king_eclipse_judgment() -> void:
	_start_king_ricochet_x()


func _start_king_royal_crossweave() -> void:
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
	var reach: float = _king_laser_reach(view)
	for wave: int in range(4):
		var theta: float = deg_to_rad(35.0 if wave % 2 == 0 else 145.0)
		var direction: Vector2 = Vector2.RIGHT.rotated(theta)
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		var lane_offset: float = -86.0 if wave < 2 else 86.0
		var lane_center: Vector2 = center + normal * lane_offset
		_queue_king_slash(lane_center - direction * reach,
			lane_center + direction * reach, 0.85, float(wave) * 0.38)
	queue_redraw()


func _king_ray_to_arena_edge(origin: Vector2, direction: Vector2, arena: Rect2) -> Dictionary:
	var d: Vector2 = direction.normalized()
	var tx: float = INF
	var ty: float = INF
	if d.x > 0.0001:
		tx = (arena.end.x - origin.x) / d.x
	elif d.x < -0.0001:
		tx = (arena.position.x - origin.x) / d.x
	if d.y > 0.0001:
		ty = (arena.end.y - origin.y) / d.y
	elif d.y < -0.0001:
		ty = (arena.position.y - origin.y) / d.y
	var distance: float = maxf(0.0, minf(tx, ty))
	var endpoint: Vector2 = origin + d * distance
	var reflected: Vector2 = d
	if absf(tx - distance) < 0.1:
		reflected.x = -reflected.x
	if absf(ty - distance) < 0.1:
		reflected.y = -reflected.y
	return {"end": endpoint, "direction": reflected.normalized()}


func _start_king_ricochet_x() -> void:
	king_special_kind = 9
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	if view.size.x < 150.0 or view.size.y < 150.0:
		_start_king_grave_shears()
		return
	var arena: Rect2 = view.grow(12.0)
	var center: Vector2 = arena.get_center()
	if is_instance_valid(target):
		center = Vector2(
			clampf(target.global_position.x, arena.position.x + arena.size.x * 0.36,
				arena.end.x - arena.size.x * 0.36),
			clampf(target.global_position.y, arena.position.y + arena.size.y * 0.35,
				arena.end.y - arena.size.y * 0.35))
	var bounce_count: int = clampi(king_ricochet_bounces, 5, 8)
	var warn: float = maxf(0.78, king_ricochet_warning_seconds)
	var bounce_warn: float = maxf(0.67, warn * 0.80)
	var bounce_step: float = 0.80
	var first_bounce_delay: float = warn + 0.14
	var overshoot: float = _king_laser_reach(view)
	var deviation: float = randf_range(-3.0, 3.0)
	for arm: int in range(2):
		var theta: float = deg_to_rad((28.0 if arm == 0 else 152.0) + deviation)
		var direction: Vector2 = Vector2.RIGHT.rotated(theta)
		var behind: Dictionary = _king_ray_to_arena_edge(center, -direction, arena)
		var ahead: Dictionary = _king_ray_to_arena_edge(center, direction, arena)
		var first_wall: Vector2 = ahead["end"]
		_queue_king_slash((behind["end"] as Vector2) - direction * overshoot,
			first_wall + direction * 26.0, warn, float(arm) * 0.11)
		king_royal_slashes[king_royal_slashes.size() - 1].ricochet = true
		var bounce_origin: Vector2 = first_wall
		var bounce_direction: Vector2 = ahead["direction"]
		for bounce_index: int in range(bounce_count):
			var reflected: Dictionary = _king_ray_to_arena_edge(
				bounce_origin + bounce_direction * 1.2, bounce_direction, arena)
			var next_wall: Vector2 = reflected["end"]
			if bounce_origin.distance_to(next_wall) < minf(arena.size.x, arena.size.y) * 0.30:
				bounce_direction = (arena.get_center() - bounce_origin).normalized()
				reflected = _king_ray_to_arena_edge(
					bounce_origin + bounce_direction * 1.2, bounce_direction, arena)
				next_wall = reflected["end"]
			var hit_end: Vector2 = next_wall + bounce_direction * 26.0
			if bounce_index == bounce_count - 1:
				hit_end = next_wall + bounce_direction * overshoot
			var delay: float = first_bounce_delay + float(bounce_index) * bounce_step + float(arm) * 0.11
			_queue_king_slash(bounce_origin - bounce_direction * 26.0,
				hit_end, bounce_warn, delay)
			king_royal_slashes[king_royal_slashes.size() - 1].ricochet = true
			bounce_origin = next_wall
			bounce_direction = reflected["direction"]
	king_gravefall_warning_timer = (first_bounce_delay
		+ float(bounce_count - 1) * bounce_step + bounce_warn
		+ king_slash_expand_seconds + king_slash_fade_seconds + 0.32)
	queue_redraw()


func _start_king_cascade_combo() -> void:
	king_special_kind = 10
	king_gravefall_active = true
	king_gravefall_warning_timer = 2.75
	var view: Rect2 = _king_visible_world_rect()
	var middle: Vector2 = view.get_center()
	if is_instance_valid(target):
		middle.x = clampf(target.global_position.x, view.position.x + 170.0, view.end.x - 170.0)
		middle.y = clampf(target.global_position.y, view.position.y + 100.0, view.end.y - 100.0)
	for side: int in [-1, 1]:
		var column_x: float = middle.x + float(side) * 132.0
		_queue_king_slash(Vector2(column_x, view.position.y - _king_laser_reach(view)),
			Vector2(column_x, view.end.y + _king_laser_reach(view)), 0.86, 0.12 if side > 0 else 0.0)
	var span: float = _king_laser_reach(view)
	var right_up: Vector2 = Vector2(span, -span)
	var right_down: Vector2 = Vector2(span, span)
	_queue_king_slash(middle - right_down, middle + right_down, 0.82, 1.05)
	_queue_king_slash(middle - right_up, middle + right_up, 0.82, 1.30)
	queue_redraw()


func _start_king_grave_shears() -> void:
	king_special_kind = 6
	king_gravefall_active = true
	king_gravefall_warning_timer = 1.90
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var center: Vector2 = view.get_center()
	for wave: int in range(3):
		var theta: float = deg_to_rad(-37.0 if wave % 2 == 0 else 37.0)
		var direction: Vector2 = Vector2.RIGHT.rotated(theta)
		var offset: Vector2 = Vector2(0.0, float(wave - 1) * 92.0)
		_queue_king_slash(center + offset - direction * reach,
			center + offset + direction * reach, 0.82, float(wave) * 0.45)
	queue_redraw()


func _start_king_royal_spearfall() -> void:
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
			_queue_king_slash(Vector2(x, view.position.y - _king_laser_reach(view)),
				Vector2(x, view.end.y + _king_laser_reach(view)), 0.82, float(wave) * 0.44)
	queue_redraw()


func _start_king_grave_guillotine() -> void:
	king_special_kind = 11
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var pivot: Vector2 = view.get_center()
	if is_instance_valid(target):
		pivot = target.global_position
	for i: int in range(3):
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(55.0 if i % 2 == 0 else -55.0))
		var p: Vector2 = pivot + Vector2(float(i - 1) * 100.0, -40.0 + float(i) * 35.0)
		_queue_king_slash(p - direction * reach, p + direction * reach, 0.75, float(i) * 0.34)
	king_gravefall_warning_timer = 2.20
	queue_redraw()


func _start_king_bone_cathedral() -> void:
	king_special_kind = 12
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var columns: int = clampi(int(floor(view.size.x / 125.0)), 5, 12)
	var spacing: float = view.size.x / float(columns)
	var direction: float = -1.0 if randf() < 0.5 else 1.0
	var shifts: Array[float] = [0.0, 0.43 * direction, -0.43 * direction]
	for wave: int in range(3):
		var offset: float = shifts[wave] * spacing
		for column: int in range(-1, columns + 2):
			var x: float = view.position.x + (float(column) + 0.5) * spacing + offset
			if x < view.position.x - king_slash_hitbox_width or x > view.end.x + king_slash_hitbox_width:
				continue
			_queue_king_slash(Vector2(x, view.position.y - reach),
				Vector2(x, view.end.y + reach), 0.85, float(wave) * 1.14)
	king_gravefall_warning_timer = 3.85
	queue_redraw()


func _start_king_royal_crossfire() -> void:
	king_special_kind = 13
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var anchor: Vector2 = target.global_position if is_instance_valid(target) else view.get_center()
	for i: int in range(3):
		var angle: float = [35.0, -35.0, 90.0][i]
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle))
		var offset: Vector2 = Vector2(0.0, 0.0) if i < 2 else Vector2(92.0, 0.0)
		_queue_king_slash(anchor + offset - direction * reach,
			anchor + offset + direction * reach, 0.82, float(i) * 0.43)
	king_gravefall_warning_timer = 2.65
	queue_redraw()


func _start_king_phantom_execution() -> void:
	king_special_kind = 14
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var origin: Vector2 = global_position
	var anchor: Vector2 = target.global_position if is_instance_valid(target) else view.get_center()
	for i: int in range(4):
		var delta_to_target: Vector2 = anchor - origin + Vector2(float(i - 2) * 105.0, 0.0)
		var direction: Vector2 = delta_to_target.normalized()
		if direction.length_squared() < 0.5:
			direction = Vector2.RIGHT
		var lane_center: Vector2 = anchor + Vector2(float(i - 2) * 70.0, 0.0)
		_queue_king_slash(lane_center - direction * reach,
			lane_center + direction * reach, 0.80, float(i) * 0.34)
	king_gravefall_warning_timer = 2.70
	queue_redraw()


func _start_king_mourning_bells() -> void:
	king_special_kind = 15
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	var base_y: float = view.position.y + view.size.y * 0.30
	for wave: int in range(3):
		var y: float = base_y + view.size.y * 0.20 * float(wave)
		_queue_king_slash(Vector2(view.position.x - reach, y),
			Vector2(view.end.x + reach, y), 0.82, float(wave) * 0.55)
	var x: float = target.global_position.x if is_instance_valid(target) else view.get_center().x
	_queue_king_slash(Vector2(x, view.position.y - reach),
		Vector2(x, view.end.y + reach), 0.80, 2.06)
	king_gravefall_warning_timer = 3.50
	queue_redraw()


func _start_king_shattered_throne() -> void:
	king_special_kind = 16
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	for lane: int in range(6):
		if lane == 2 or lane == 3:
			continue
		var x: float = view.position.x + view.size.x * (float(lane) + 0.5) / 6.0
		_queue_king_slash(Vector2(x, view.position.y - reach),
			Vector2(x, view.end.y + reach), 0.85, 0.0)
	for wave: int in range(2):
		var y: float = view.position.y + view.size.y * (0.27 if wave == 0 else 0.73)
		_queue_king_slash(Vector2(view.position.x - reach, y),
			Vector2(view.end.x + reach, y), 0.82, 1.15 + float(wave) * 0.55)
	king_gravefall_warning_timer = 3.25
	queue_redraw()


func _start_king_thorn_procession() -> void:
	king_special_kind = 17
	king_gravefall_active = true
	var view: Rect2 = _king_visible_world_rect()
	var reach: float = _king_laser_reach(view)
	for wave: int in range(4):
		var lane: int = [1, 5, 2, 4][wave]
		var x: float = view.position.x + view.size.x * (float(lane) + 0.5) / 7.0
		_queue_king_slash(Vector2(x, view.position.y - reach),
			Vector2(x, view.end.y + reach), 0.70, float(wave) * 0.52)
	var diagonal: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(-28.0))
	var anchor: Vector2 = view.get_center()
	_queue_king_slash(anchor - diagonal * reach, anchor + diagonal * reach, 0.82, 2.30)
	king_gravefall_warning_timer = 3.65
	queue_redraw()


func _fire_king_gravefall() -> void:
	_finish_king_spell()


func _fire_king_sweep() -> void:
	_finish_king_spell()


func _fire_king_crown() -> void:
	king_crown_burst_remaining = 0.34
	_finish_king_spell()


func _finish_king_spell() -> void:
	king_exposure_timer = maxf(king_exposure_timer, king_exposed_after_attack)
	if king_royal_slashes.is_empty():
		king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
	_clear_king_gravefall()
	_update_king_hp_label()


func _update_king_specials(delta: float) -> void:
	if king_shield_phase == KingShieldPhase.BREAKING or king_last_stand_intro_timer > 0.0:
		return
	if not is_king or not is_instance_valid(target):
		return
	if king_shield_phase == KingShieldPhase.SHIELDED and not king_gravefall_active:
		if not king_shield_elite_spawned or not _king_elite_is_alive():
			return
		if king_post_attack_timer > 0.0 or not king_royal_slashes.is_empty():
			return
		king_guard_attack_timer -= delta
		if king_guard_attack_timer <= 0.0:
			king_guard_attack_timer = maxf(8.0, king_guard_attack_interval)
			_begin_king_attack_cast()
			_start_king_gravefall()
		return
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
				4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17:
					_finish_king_spell()
				_:
					_clear_king_gravefall()
		_update_king_hp_label()
		return
	if king_skull_spawns_remaining > 0 or not king_royal_slashes.is_empty():
		return
	if king_post_attack_timer > 0.0 or king_tp_phase != 0 or king_attack_cast_remaining > 0.0:
		return
	if king_tp_hold_remaining <= 0.0 and king_tp_failed_attempts < 3:
		return
	king_gravefall_cooldown_timer -= delta
	if king_gravefall_cooldown_timer > 0.0:
		return
	king_special_round += 1
	_begin_king_attack_cast()
	if king_shield_phase == KingShieldPhase.EXPOSED:
		king_solo_attacks_since_guard += 1
		if king_total_resurrections == 0:
			king_exposed_spells_since_break += 1
	if king_shield_phase == KingShieldPhase.EXPOSED and king_total_resurrections == 0:
		match king_exposed_spells_since_break % 7:
			1:
				_start_king_grave_shears()
			2:
				_start_king_ricochet_x()
			3:
				_start_king_royal_spearfall()
			4:
				_start_king_cascade_combo()
			5:
				_start_king_royal_crossweave()
			6:
				_start_king_heavens_lances()
			_:
				_start_king_eclipse_judgment()
	elif king_last_stand_started:
		king_final_pattern_round += 1
		match king_final_pattern_round % 18:
			1:
				_start_king_bone_cathedral()
			2:
				_start_king_mourning_bells()
			3:
				_start_king_grave_guillotine()
			4:
				_start_king_shattered_throne()
			5:
				_start_king_ricochet_x()
			6:
				_start_king_thorn_procession()
			7:
				_start_king_royal_spearfall()
			8:
				_start_king_phantom_execution()
			9:
				_start_king_bone_cathedral()
			10:
				_start_king_sweep()
			11:
				_start_king_cascade_combo()
			12:
				_start_king_mourning_bells()
			13:
				_start_king_heavens_lances()
			14:
				_start_king_shattered_throne()
			15:
				_start_king_royal_crossfire()
			16:
				_start_king_thorn_procession()
			17:
				_start_king_ricochet_x()
			_:
				_start_king_royal_crossweave()
	else:
		match king_special_round % 9:
			1:
				_start_king_gravefall()
			2:
				_start_king_ricochet_x()
			3:
				_start_king_sweep()
			4:
				_start_king_grave_shears()
			5:
				_start_king_cascade_combo()
			6:
				_start_king_heavens_lances()
			7:
				_start_king_royal_crossweave()
			8:
				_start_king_eclipse_judgment()
			_:
				_start_king_royal_spearfall()
	king_gravefall_cooldown_timer = 0.07 if king_last_stand_started else (0.12 if king_shield_phase == KingShieldPhase.EXPOSED else 0.22)
	_update_king_hp_label()


func _start_king_skull_walls(from_side: bool) -> void:
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
		var coord: float = min_axis
		while coord <= max_axis:
			if absf(coord - wall.safe_center) > king_wall_safe_gap * 0.5 + 14.0:
				var world: Vector2 = Vector2(axis, coord) if wall.from_side else Vector2(coord, axis)
				var center: Vector2 = to_local(world)
				var scale_val: float = lerpf(0.28, 1.0, warning_t) if warned else 1.0
				var size: Vector2 = Vector2.ONE * king_wall_skull_size * scale_val
				draw_texture_rect(tex, Rect2(center - size * 0.5, size), false, Color(0.96, 0.56, 1.0, alpha))
			coord += king_wall_skull_size * 0.86
		for edge: float in [-1.0, 1.0]:
			var bound: float = wall.safe_center + edge * king_wall_safe_gap * 0.5
			var edge_world: Vector2 = Vector2(axis, bound) if wall.from_side else Vector2(bound, axis)
			draw_circle(to_local(edge_world), 5.0, Color(1.0, 0.88, 1.0, alpha))

func _resolve_king_menacing_scene() -> PackedScene:
	if king_menacing_skeleton_scene != null:
		return king_menacing_skeleton_scene
	if king_elite_scene_lookup_exhausted:
		return null
	king_elite_scene_lookup_exhausted = true
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
	elite.set_meta(&"king_necromancer_summon", true)
	elite.set_meta(&"necromancer_summon_owner", get_instance_id())
	elite.set_meta(&"king_guard_index", king_elite_waves_spawned)
	var is_l6_guard: bool = level6_mode and level6_stage == Level6Stage.PHASE_ONE
	elite.set("max_hp", maxi(1, level6_buffed_guard_health if is_l6_guard else king_normal_guard_hp))
	elite.set("activation_radius", 900.0)
	elite.set("attack_warning_seconds", 0.94 if is_l6_guard else 1.08)
	elite.set("point_blank_warning_seconds", 1.00 if is_l6_guard else 1.20)
	elite.set("lunge_warning_seconds", 0.96 if is_l6_guard else 1.14)
	elite.set("jump_slam_warning_seconds", 0.96 if is_l6_guard else 1.10)
	elite.set("advancing_slam_warning_seconds", 0.98 if is_l6_guard else 1.15)
	elite.set("tactical_retreat_chance", 0.14 if is_l6_guard else (0.22 if king_elite_waves_spawned == 0 else 0.50))
	elite.set_meta(&"king_guard_buffed", is_l6_guard)
	if is_l6_guard:
		elite.set_meta(&"king_reborn_elite", false)
		elite.set_meta(&"void_no_revive", true)
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
	if is_l6_guard:
		for guard_visual: Node in elite.find_children("*", "AnimatedSprite2D", true, false):
			var guard_art: AnimatedSprite2D = guard_visual as AnimatedSprite2D
			if guard_art != null:
				guard_art.material = level6_void_shader.duplicate() as ShaderMaterial
				(guard_art.material as ShaderMaterial).set_shader_parameter("hit_flash", 0.0)
				guard_art.self_modulate = Color.WHITE
				guard_art.modulate = Color.WHITE
		var guard_aura: Sprite2D = Sprite2D.new()
		guard_aura.name = "VoidMenacingSoftAura"
		guard_aura.texture = _level6_get_aura_texture()
		guard_aura.scale = Vector2(1.35, 1.65)
		guard_aura.position = Vector2(0.0, -17.0)
		guard_aura.z_index = -3
		guard_aura.show_behind_parent = true
		elite.add_child(guard_aura)
		var guard_smoke: CPUParticles2D = CPUParticles2D.new()
		guard_smoke.name = "VoidMenacingSmoke"
		guard_smoke.texture = _level6_get_particle_texture()
		guard_smoke.amount = 10
		guard_smoke.lifetime = 1.4
		guard_smoke.direction = Vector2.UP
		guard_smoke.spread = 60.0
		guard_smoke.initial_velocity_min = 10.0
		guard_smoke.initial_velocity_max = 23.0
		guard_smoke.color = Color(0.025, 0.025, 0.033, 0.29)
		guard_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		guard_smoke.emission_rect_extents = Vector2(10.0, 15.0)
		guard_smoke.position = Vector2(0.0, -13.0)
		guard_smoke.z_index = -2
		elite.add_child(guard_smoke)
		level6_guard_previous_hp[elite.get_instance_id()] = int(elite.get("hp"))
		level6_guard_flash_timers[elite.get_instance_id()] = 0.0
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
	if not is_king or king_shield_phase != KingShieldPhase.SHIELDED:
		return
	if king_elite_waves_spawned >= king_elite_total_waves:
		king_shield_elite_spawned = true
		if not _king_elite_is_alive():
			_begin_king_shield_break()
		return
	king_shield_spawn_retry = maxf(0.0, king_shield_spawn_retry - delta)
	if king_shield_spawn_retry <= 0.0:
		while king_elite_waves_spawned < king_elite_total_waves:
			if not _try_spawn_king_elite():
				king_shield_spawn_retry = 1.8
				break
		if king_elite_waves_spawned >= king_elite_total_waves:
			king_shield_elite_spawned = true
		_update_king_hp_label()

func _on_king_guard_died(guard: CharacterBody2D) -> void:
	if level6_mode and is_instance_valid(guard):
		_level6_remove_guard_aura(guard)
		if not bool(guard.get_meta(&"void_guard_cleanup_started", false)):
			guard.set_meta(&"void_guard_cleanup_started", true)
			get_tree().create_timer(0.85).timeout.connect(func() -> void:
				if is_instance_valid(guard):
					guard.queue_free()
			)
	if not is_instance_valid(guard):
		return
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
	if king_shield_phase != KingShieldPhase.EXPOSED or king_total_resurrections >= king_max_total_resurrections:
		return false
	if _king_active_purple_count() > 0:
		return false
	var best_guard: CharacterBody2D = null
	var best_score: float = INF
	for guard: CharacterBody2D in king_elite_guards:
		if not is_instance_valid(guard) or guard.is_queued_for_deletion():
			continue
		if not guard.has_method(&"can_be_royally_revived") or not bool(guard.call(&"can_be_royally_revived")):
			continue
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
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	_clear_king_gravefall()
	king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
	if not bool(best_guard.call(&"begin_royal_resurrection", mini(70, king_reborn_guard_hp))):
		return false
	king_last_revived_id = best_guard.get_instance_id()
	king_total_resurrections += 1
	king_revival_started = true
	king_revival_completed = true
	king_solo_attacks_since_guard = 0
	king_reborn_guard = best_guard
	if not king_reborn_guards.has(best_guard):
		king_reborn_guards.append(best_guard)
	king_revival_cast_total = (
		float(best_guard.get("royal_revive_ghost_seconds"))
		+ float(best_guard.get("royal_revive_hold_seconds"))
		+ float(best_guard.get("royal_revive_reverse_seconds"))
	)
	king_revival_cast_fx = maxf(0.5, king_revival_cast_total)
	king_attack_cast_remaining = 0.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(REVIVE_ANIMATION):
		_play(REVIVE_ANIMATION, true)
	king_revival_timer = maxf(6.0, king_repeat_revival_delay)
	king_guard_attack_timer = maxf(3.0, king_reborn_boss_spell_interval)
	print("GRAVE MONARCH V11: REMOTE RESURRECTION ", king_total_resurrections,
		"/", king_max_total_resurrections, " at ", best_guard.global_position)
	_update_king_hp_label()
	return true


func _set_flight_collision(landing: bool) -> void:
	if level6_mode:
		collision_layer = 0
		collision_mask = 0
		return
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
	level6_mode = _level6_detect_scene()
	_activate_king_mode()
	_level6_initialize()
	_level6_artifact_bind_player()


func _begin_king_shield_phase() -> void:
	if king_shield_phase != KingShieldPhase.SOLO:
		return
	king_shield_phase = KingShieldPhase.SHIELDED
	king_shield_elite_spawned = false
	king_attack_cast_remaining = 0.0
	king_shield_spawn_retry = 0.0
	king_shield_hit_fx = king_shield_hit_pulse_duration
	king_elite_waves_spawned = 0
	king_elite_total_waves = 2
	king_elite_guards.clear()
	king_guard_attack_timer = maxf(7.0, king_guard_attack_interval)
	king_black_flash_timer = 0.0
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
	king_attack_cast_remaining = 0.0
	king_shield_break_fx = maxf(0.2, king_shield_break_duration)
	king_shield_hit_fx = 0.0
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
	king_skull_volley_timer = maxf(24.0, king_skull_volley_timer)
	king_solo_hover_anchor_set = false
	king_solo_reposition_timer = 0.0
	king_solo_flight_velocity = Vector2.ZERO
	king_solo_attacks_since_guard = 0
	_play(&"idle", true)
	_update_king_hp_label()
	queue_redraw()
	print("GRAVE MONARCH V10: SHIELD SHATTERING; FULL MAGIC RETURNS AFTER BREAK")


func _update_king_revival_cast_pose() -> void:
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
	if king_last_stand_started or king_shield_phase != KingShieldPhase.EXPOSED:
		return
	king_last_stand_started = true
	king_last_stand_intro_timer = king_last_stand_intro_seconds
	king_attack_cast_remaining = 0.0
	king_revival_cast_fx = 0.0
	king_revival_cast_total = 0.0
	hp = mini(max_hp, maxi(hp + 100, int(ceil(float(max_hp) * king_last_stand_heal_ratio))))
	sprite_tint = Color(1.0, 0.47, 0.98, 1.0)
	_clear_skulls()
	king_skull_spawns_remaining = 0
	king_royal_slashes.clear()
	_clear_king_gravefall()
	king_post_attack_timer = maxf(king_post_attack_timer, king_last_stand_intro_seconds)
	king_gravefall_cooldown_timer = maxf(king_gravefall_cooldown_timer, 1.4)
	king_skull_volley_timer = maxf(king_skull_volley_timer, 19.0)
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
	var was_revival_casting: bool = king_revival_cast_fx > 0.0
	king_revival_cast_fx = maxf(0.0, king_revival_cast_fx - delta)
	if king_revival_cast_fx > 0.0:
		_update_king_revival_cast_pose()
	elif was_revival_casting:
		_play(&"idle", true)
	king_last_stand_intro_timer = maxf(0.0, king_last_stand_intro_timer - delta)
	if king_shield_phase == KingShieldPhase.EXPOSED:
		var purple_present: bool = _king_active_purple_count() > 0
		if purple_present:
			king_was_purple_guard_active = true
		elif king_was_purple_guard_active:
			king_was_purple_guard_active = false
			_begin_king_last_stand()
			king_revival_timer = minf(12.0, king_repeat_revival_delay)
			king_solo_attacks_since_guard = 0
			king_post_attack_timer = maxf(king_post_attack_timer, king_post_attack_pause)
			king_gravefall_cooldown_timer = maxf(king_gravefall_cooldown_timer, king_post_attack_pause)
		if (not purple_present
			and king_total_resurrections < king_max_total_resurrections
			and king_exposed_spells_since_break >= maxi(5, king_exposed_spells_before_revival)):
			king_revival_timer -= delta
			king_revival_attempt_cooldown = maxf(0.0, king_revival_attempt_cooldown - delta)
			var needed_solo_attacks: int = 5 if king_total_resurrections == 0 else 3
			if (king_solo_attacks_since_guard >= needed_solo_attacks
				and king_revival_timer <= 0.0 and king_revival_attempt_cooldown <= 0.0
				and king_royal_slashes.is_empty() and not king_gravefall_active
				and king_skull_spawns_remaining == 0 and king_post_attack_timer <= 0.0
				and king_tp_phase == 0):
				if king_total_resurrections > 0 and randf() > king_repeat_revival_chance:
					king_revival_attempt_cooldown = 7.0
					king_revival_timer = 5.0
				elif not _begin_king_elite_revive():
					king_revival_attempt_cooldown = 0.75
	if is_instance_valid(sprite):
		var hit_black: bool = king_black_flash_timer > 0.0
		sprite.self_modulate = Color.BLACK if hit_black else sprite_tint
		sprite.modulate = Color.BLACK if hit_black else Color.WHITE


func _physics_process(delta: float) -> void:
	if level6_mode:
		_level6_update(delta)
		return
	if state == State.DEAD:
		return
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
		_update_king_attack_cast_pose(delta)
		_update_king_crown(delta)
		if not is_instance_valid(king_hud):
			_create_king_boss_hud()
		_update_king_hp_label()
	if state != State.DORMANT:
		var hit_black: bool = king_black_flash_timer > 0.0
		sprite.self_modulate = Color.BLACK if hit_black else sprite_tint
		sprite.modulate = Color.BLACK if hit_black else Color.WHITE
		queue_redraw()


func _begin_encounter() -> void:
	if is_king:
		state = State.GUARDED
		opening_complete = true
		slots.clear()
		barrage_timer = 0.7
		king_gravefall_cooldown_timer = 0.30
		king_elite_timer = 0.0
		king_shield_countdown = clampf(king_shield_appear_delay, 5.0, 15.0)
		king_tp_hold_remaining = 0.75
		_create_king_boss_hud()
		_update_king_hp_label()
		_play(&"idle")
		print("GRAVE MONARCH: START BOSS PATTERN / MENACING ONLY")
		return
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
	_update_barrage(delta)


func _update_hover(delta: float) -> void:
	if not is_king:
		_fly_toward(home, hover_speed, delta)
		return
	velocity = Vector2.ZERO
	hover_time += delta
	if king_tp_phase != 0:
		_update_king_teleport_animation(delta)
		return
	var guard_active: bool = (king_shield_phase == KingShieldPhase.SHIELDED
		or _king_active_purple_count() > 0 or king_revival_cast_fx > 0.0)
	if guard_active != king_tp_guard_mode:
		king_tp_guard_mode = guard_active
		king_tp_guard_perch_locked = false
		king_tp_last_perch = -1
		king_guard_perch_clock = 0.0
		king_tp_hold_remaining = 0.0 if guard_active else 0.6
	var view: Rect2 = _king_visible_world_rect()
	if view.size.x < 120.0 or view.size.y < 120.0:
		return
	if guard_active:
		if king_revival_cast_fx > 0.0 or king_attack_cast_remaining > 0.0:
			return
		king_guard_perch_clock -= delta
		if king_guard_perch_clock <= 0.0:
			if _begin_king_teleport(view, true):
				king_guard_perch_clock = maxf(3.0, king_guard_teleport_interval)
				king_tp_guard_perch_locked = true
				king_tp_failed_attempts = 0
			else:
				king_tp_failed_attempts += 1
				king_guard_perch_clock = 0.75
		return
	king_tp_hold_remaining -= delta
	if (king_attack_cast_remaining > 0.0
		or king_revival_cast_fx > 0.0 or king_last_stand_intro_timer > 0.0):
		return
	if king_tp_hold_remaining <= 0.0:
		if _begin_king_teleport(view, false):
			king_tp_failed_attempts = 0
		else:
			king_tp_failed_attempts += 1
			king_tp_hold_remaining = 0.65
			if king_tp_failed_attempts == 1 or king_tp_failed_attempts % 8 == 0:
				push_warning("KING V30: no safe SOLO perch. Retrying.")


func _king_collect_no_spawn_shapes() -> void:
	king_no_spawn_shapes.clear()
	king_no_spawn_scanned = true
	var level: Node = get_tree().current_scene
	if level == null:
		level = get_tree().root
	for node: Node in level.find_children("*", "Area2D", true, false):
		var area: Area2D = node as Area2D
		var lower: String = area.name.to_lower()
		if not (lower == "bosscolider" or lower == "bossnospawnzone"
			or lower == "boss_no_spawn_zone" or area.is_in_group(&"boss_no_spawn")):
			continue
		for child: Node in area.get_children():
			if child is CollisionShape2D:
				var blocker: CollisionShape2D = child as CollisionShape2D
				if blocker.shape != null and not blocker.disabled:
					king_no_spawn_shapes.append(blocker)
	if not king_no_spawn_shapes.is_empty():
		print("KING V33: registered ", king_no_spawn_shapes.size(), " forbidden spawn shapes")


func _king_spawn_overlaps_zone(spawn_world: Vector2, use_king_body: bool) -> bool:
	if not king_no_spawn_scanned:
		_king_collect_no_spawn_shapes()
	var proposed_shape: Shape2D
	var proposed_transform: Transform2D
	if use_king_body:
		if not is_instance_valid(body_shape) or body_shape.shape == null:
			return false
		proposed_shape = body_shape.shape
		proposed_transform = body_shape.global_transform
		proposed_transform.origin += spawn_world - global_position
	else:
		var skull_probe: CircleShape2D = CircleShape2D.new()
		skull_probe.radius = maxf(12.0, king_spectral_skull_size * 0.42)
		proposed_shape = skull_probe
		proposed_transform = Transform2D(0.0, spawn_world)
	for zone_shape: CollisionShape2D in king_no_spawn_shapes:
		if not is_instance_valid(zone_shape) or zone_shape.disabled or zone_shape.shape == null:
			continue
		if proposed_shape.collide(proposed_transform, zone_shape.shape, zone_shape.global_transform):
			return true
	return false


func _king_teleport_ground_safe(candidate: Vector2, view: Rect2) -> Dictionary:
	if not is_instance_valid(body_shape) or body_shape.shape == null:
		return {"valid": false}
	var half_height: float = 22.0
	var half_width: float = 20.0
	if body_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = body_shape.shape as RectangleShape2D
		half_height = maxf(12.0, rect.size.y * absf(body_shape.global_scale.y) * 0.5)
		half_width = maxf(12.0, rect.size.x * absf(body_shape.global_scale.x) * 0.5)
	var visual_bottom: float = maxf(40.0, _king_visible_bottom_offset())
	var max_y: float = view.position.y + view.size.y * 0.64
	if is_instance_valid(target):
		max_y = minf(max_y, target.global_position.y - maxf(half_height + 28.0, 48.0))
	var min_y: float = view.position.y - maxf(100.0, minf(165.0, visual_bottom * 0.95))
	if max_y < min_y:
		max_y = min_y
	var physics: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var excluded: Array[RID] = _excluded_bodies()
	var probe_bottom: float = maxf(view.end.y + 380.0, candidate.y + 380.0)
	var offsets: Array[float] = [0.0, -35.0, 35.0, -70.0, 70.0, -110.0, 105.0, -155.0]
	for offset: float in offsets:
		var probe: Vector2 = Vector2(candidate.x, clampf(candidate.y + offset, min_y, max_y))
		if is_instance_valid(target) and probe.distance_to(target.global_position) < 82.0:
			continue
		var next_floor_y: float = INF
		for dx: float in [-half_width * 0.55, 0.0, half_width * 0.55]:
			var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				Vector2(probe.x + dx, probe.y + half_height + 4.0),
				Vector2(probe.x + dx, probe_bottom), terrain_mask, excluded)
			var hit: Dictionary = physics.intersect_ray(ray)
			if hit.is_empty():
				continue
			if (hit["normal"] as Vector2).y > -0.55:
				continue
			next_floor_y = minf(next_floor_y, (hit["position"] as Vector2).y)
		if next_floor_y != INF:
			var floor_clearance: float = maxf(half_height + 12.0, minf(visual_bottom + 8.0, 120.0))
			probe.y = minf(probe.y, next_floor_y - floor_clearance)
		if is_instance_valid(target):
			probe.y = minf(probe.y, target.global_position.y - maxf(half_height + 28.0, 48.0))
		if probe.y < min_y - 25.0:
			continue
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = body_shape.shape
		var proposed: Transform2D = body_shape.global_transform
		proposed.origin += probe - global_position
		query.transform = proposed
		query.collision_mask = terrain_mask
		query.exclude = excluded
		query.margin = 1.0
		if not physics.intersect_shape(query, 1).is_empty():
			continue
		if _king_spawn_overlaps_zone(probe, true):
			continue
		return {"valid": true, "position": probe}
	return {"valid": false}


func _king_pick_teleport_destination(view: Rect2, guard_active: bool) -> Dictionary:
	var best: Dictionary = {"valid": false}
	var best_score: float = -INF
	var margin_x: float = clampf(view.size.x * 0.08, 18.0, 52.0)
	var left_x: float = view.position.x + margin_x
	var right_x: float = view.end.x - margin_x
	if right_x - left_x < 70.0:
		return best
	var y_ratios: Array[float] = [-0.14, 0.04, 0.19, 0.35, 0.50]
	if guard_active:
		y_ratios = [-0.18, -0.06, 0.07, 0.18, 0.30]
	for i: int in range(11):
		var x: float = lerpf(left_x, right_x, float(i) / 10.0)
		for ratio: float in y_ratios:
			var tested: Dictionary = _king_teleport_ground_safe(
				Vector2(x, view.position.y + view.size.y * ratio), view)
			if not bool(tested.get("valid", false)):
				continue
			var pos: Vector2 = tested["position"]
			var travel: float = pos.distance_to(global_position)
			if travel < maxf(58.0, view.size.x * 0.14):
				continue
			var score: float = randf_range(0.0, 15.0) + minf(travel, 350.0) * 0.16
			if i == king_tp_last_perch:
				score -= 220.0
			if is_instance_valid(target):
				var player_distance: float = pos.distance_to(target.global_position)
				if guard_active:
					score += player_distance * 5.0
					if absf(pos.x - target.global_position.x) < view.size.x * 0.25:
						score -= 300.0
				else:
					score -= absf(player_distance - view.size.x * 0.38) * 0.60
			if guard_active:
				score += absf(float(i) / 10.0 - 0.5) * 520.0
				for guard: CharacterBody2D in king_elite_guards:
					if not is_instance_valid(guard) or guard.is_queued_for_deletion():
						continue
					if guard.has_method(&"is_dead") and bool(guard.call(&"is_dead")):
						continue
					score += minf(330.0, pos.distance_to(guard.global_position)) * 1.6
			var art_center_y: float = pos.y + sprite.position.y
			if art_center_y < view.position.y - 40.0:
				score -= (view.position.y - 40.0 - art_center_y) * 1.4
			if score > best_score:
				best_score = score
				best = {"valid": true, "position": pos, "index": i}
	return best


func _begin_king_teleport(view: Rect2, guard_active: bool) -> bool:
	var candidate: Dictionary = _king_pick_teleport_destination(view, guard_active)
	if not bool(candidate.get("valid", false)):
		return false
	king_tp_destination = candidate["position"]
	king_tp_last_perch = int(candidate["index"])
	print("KING V30 TELEPORT START: ", global_position, " -> ", king_tp_destination,
		" | guard=", guard_active)
	king_tp_phase = 1
	king_tp_elapsed = 0.0
	_king_set_teleport_death_frame(0.0)
	if is_instance_valid(king_crown_root):
		king_crown_root.visible = false
	return true


func _king_set_teleport_death_frame(progress: float) -> void:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(&"death"):
		return
	var frame_count: int = sprite.sprite_frames.get_frame_count(&"death")
	if frame_count <= 0:
		return
	sprite.stop()
	sprite.animation = &"death"
	var frame_index: int = clampi(int(round(clampf(progress, 0.0, 1.0) * float(frame_count - 1))), 0, frame_count - 1)
	sprite.set_frame_and_progress(frame_index, 0.0)


func _update_king_teleport_animation(delta: float) -> void:
	if king_tp_phase == 1:
		king_tp_elapsed += delta
		var t: float = clampf(king_tp_elapsed / maxf(0.12, king_teleport_vanish_seconds), 0.0, 1.0)
		_king_set_teleport_death_frame(t)
		if t >= 1.0:
			if level6_mode and level6_stage == Level6Stage.PHASE_TWO:
				_level6_secure_second_marker()
			global_position = king_tp_destination
			reset_physics_interpolation()
			sprite.reset_physics_interpolation()
			king_tp_phase = 2
			king_tp_elapsed = 0.0
			_king_set_teleport_death_frame(1.0)
		return
	if king_tp_phase == 2:
		king_tp_elapsed += delta
		var t: float = clampf(king_tp_elapsed / maxf(0.20, king_teleport_reappear_seconds), 0.0, 1.0)
		_king_set_teleport_death_frame(1.0 - t)
		if t >= 1.0:
			king_tp_phase = 0
			king_tp_elapsed = 0.0
			king_tp_hold_remaining = maxf(3.8, king_teleport_hold_seconds)
			print("KING V30 TELEPORT FINISHED at ", global_position)
			if is_instance_valid(king_crown_root):
				king_crown_root.visible = true
			_play(&"idle", true)
			queue_redraw()


func _update_barrage(delta: float) -> void:
	if is_king and (king_shield_phase in [KingShieldPhase.SHIELDED, KingShieldPhase.BREAKING]
		or _king_active_purple_count() > 0 or king_last_stand_intro_timer > 0.0
		or (king_shield_phase == KingShieldPhase.EXPOSED and king_total_resurrections == 0)):
		return
	if is_king:
		if king_skull_spawns_remaining <= 0:
			king_skull_volley_timer -= delta
			if (king_skull_volley_timer <= 0.0
				and king_post_attack_timer <= 0.0
				and not king_gravefall_active
				and king_royal_slashes.is_empty()):
				king_skull_spawns_remaining = 2 if king_last_stand_started else 3
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
	if absf(global_position.x - destination.x) > 5.0:
		var approach_y: float = minf(global_position.y, destination.y - 44.0)
		_fly_toward(Vector2(destination.x, approach_y), hover_speed, delta)
	else:
		_fly_toward(destination, hover_speed, delta)
	if global_position.distance_to(destination) <= 6.0:
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
	if level6_mode:
		return
	if level6_mode and skulls.size() >= LEVEL6_SKULL_MAX:
		return
	if king_shield_phase == KingShieldPhase.BREAKING:
		return
	if not is_king or not is_instance_valid(target):
		return
	var view: Rect2 = _king_visible_world_rect()
	var skull := Skull.new()
	var visual := Sprite2D.new()
	visual.texture = SKULL_TEXTURE
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.modulate = Color(1.0, 1.0, 1.0, 0.0) if level6_mode else Color(0.82, 0.34, 1.0, 0.0)
	visual.top_level = true
	if level6_mode:
		visual.material = level6_void_shader.duplicate() as ShaderMaterial
		var aura: Sprite2D = Sprite2D.new()
		aura.name = "SkullVoidAura"
		aura.texture = _level6_get_aura_texture()
		aura.scale = Vector2(1.6, 1.6)
		aura.z_index = -1
		aura.show_behind_parent = true
		visual.add_child(aura)
	var texture_size: Vector2 = SKULL_TEXTURE.get_size()
	var size_multiplier: float = maxf(60.0, king_spectral_skull_size) / maxf(texture_size.x, texture_size.y)
	skull.base_scale = Vector2.ONE * size_multiplier
	visual.scale = skull.base_scale * 0.10
	add_child(visual)
	var safe_view: Rect2 = view.grow(-50.0)
	if safe_view.size.x < 20.0 or safe_view.size.y < 20.0:
		safe_view = view
	var chosen: Vector2 = Vector2.ZERO
	var found_safe_spawn: bool = false
	var best_distance: float = -1.0
	if level6_mode:
		var sectors: Array[Vector2i] = [
			Vector2i(0, 0), Vector2i(2, 2), Vector2i(2, 0), Vector2i(0, 2),
			Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)
		]
		var slot: int = (level6_skull_spawn_serial + level6_skull_spawn_rotation) % sectors.size()
		level6_skull_spawn_serial += 1
		for shift: int in range(sectors.size()):
			var sector: Vector2i = sectors[(slot + shift) % sectors.size()]
			for attempt: int in range(8):
				var candidate: Vector2 = safe_view.position + Vector2(
					(float(sector.x) + randf_range(0.14, 0.86)) / 3.0 * safe_view.size.x,
					(float(sector.y) + randf_range(0.14, 0.86)) / 3.0 * safe_view.size.y
				)
				if _king_spawn_overlaps_zone(candidate, false):
					continue
				var distance: float = candidate.distance_to(target.global_position)
				if distance < 180.0 or candidate.distance_to(global_position) < 95.0:
					continue
				if level6_last_skull_spawn.x != INF and candidate.distance_to(level6_last_skull_spawn) < 160.0:
					continue
				chosen = candidate
				found_safe_spawn = true
				break
			if found_safe_spawn:
				break
	if not found_safe_spawn:
		for attempt: int in range(90):
			var candidate: Vector2 = Vector2(
				randf_range(safe_view.position.x, safe_view.end.x),
				randf_range(safe_view.position.y, safe_view.end.y)
			)
			if _king_spawn_overlaps_zone(candidate, false):
				continue
			var distance: float = candidate.distance_to(target.global_position)
			if distance > best_distance:
				best_distance = distance
				chosen = candidate
				found_safe_spawn = true
			if (distance >= king_skull_min_spawn_distance
				and candidate.distance_to(global_position) >= 105.0):
				chosen = candidate
				break
	if not found_safe_spawn:
		visual.queue_free()
		return
	visual.global_position = chosen
	if level6_mode:
		level6_last_skull_spawn = chosen
	skull.direction = chosen.direction_to(target.global_position)
	skull.visual = visual
	skull.spectral = true
	skull.cruise_speed = king_skull_flight_speed
	skull.speed = king_skull_flight_speed * (0.55 if level6_mode else 1.0)
	skull.velocity = skull.direction * skull.speed
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
			skull.charge_elapsed = minf(king_skull_charge_duration, skull.charge_elapsed + delta)
			var t: float = clampf(skull.charge_elapsed / maxf(0.01, king_skull_charge_duration), 0.0, 1.0)
			var eased: float = t * t * (3.0 - 2.0 * t)
			skull.visual.scale = skull.base_scale * lerpf(0.10, 1.0, eased)
			skull.visual.modulate.a = eased
			skull.visual.rotation = skull.direction.angle() + PI
			continue
		var start: Vector2 = skull.visual.global_position
		if skull.spectral:
			skull.flight_elapsed += delta
			if level6_mode:
				var wanted_direction: Vector2 = start.direction_to(target.global_position)
				var turn_error: float = 0.0
				if wanted_direction.length_squared() > 0.0001:
					turn_error = angle_difference(skull.direction.angle(), wanted_direction.angle())
					var maximum_rotation: float = level6_skull_turn_rate_v48 * delta
					skull.direction = skull.direction.rotated(
						clampf(turn_error, -maximum_rotation, maximum_rotation)
					).normalized()
				var brake: float = clampf((absf(turn_error) - 0.30) / 1.60, 0.0, 1.0)
				var cruise: float = maxf(1.0, skull.cruise_speed)
				var wanted_speed: float = cruise * (1.0 - 0.52 * brake)
				var acceleration: float = 470.0 if skull.speed > wanted_speed else 285.0
				skull.speed = move_toward(skull.speed, wanted_speed, acceleration * delta)
				skull.velocity = skull.direction * skull.speed
			else:
				var tracking_age: float = skull.flight_elapsed - king_skull_tracking_delay
				if tracking_age > 0.0:
					var tracking_factor: float = clampf(
						tracking_age / maxf(0.05, king_skull_tracking_ramp), 0.0, 1.0
					)
					var orbit_phase: float = skull.flight_elapsed * 1.6 + skull.wobble_seed
					var distance_to_player: float = start.distance_to(target.global_position)
					var orbit_strength: float = clampf((distance_to_player - 45.0) / 210.0, 0.0, 1.0)
					var sideways: Vector2 = Vector2(-skull.direction.y, skull.direction.x)
					var orbit_offset: float = sin(orbit_phase) * 32.0 * skull.orbit_sign * orbit_strength
					var desired_point: Vector2 = target.global_position + sideways * orbit_offset
					var desired: Vector2 = start.direction_to(desired_point)
					if desired.length_squared() > 0.001:
						var angle_delta: float = angle_difference(skull.direction.angle(), desired.angle())
						var turn_limit: float = king_skull_turn_rate * tracking_factor * delta
						skull.direction = skull.direction.rotated(
							clampf(angle_delta, -turn_limit, turn_limit)
						).normalized()
			skull.visual.rotation = skull.direction.angle() + PI
		var displacement: Vector2 = skull.velocity if (level6_mode and skull.spectral) else skull.direction * skull.speed
		var finish: Vector2 = start + displacement * delta
		skull.lifetime -= delta
		var phase_time: float = 1.5 if level6_mode else king_skull_terrain_phase_time
		if skull.spectral and skull.flight_elapsed < phase_time:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, start, finish)
			if closest.distance_to(target.global_position) < 26.0:
				if target.has_method(&"tomar_dano"):
					target.call(&"tomar_dano", skull.damage, start)
				skull.visual.queue_free()
				skulls.remove_at(index)
			elif skull.lifetime <= 0.0:
				skull.visual.queue_free()
				skulls.remove_at(index)
			else:
				skull.visual.global_position = finish
			continue
		var collision_bits: int = 0x7FFFFFFF if level6_mode else (target.collision_layer | terrain_mask)
		var query := PhysicsRayQueryParameters2D.create(start, finish, collision_bits, excluded)
		query.hit_from_inside = true
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
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
	if level6_mode:
		return level6_stage in [Level6Stage.PHASE_ONE, Level6Stage.PHASE_TWO, Level6Stage.PHASE_THREE]
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
	var texture: Texture2D = null
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
		if count > 0:
			texture = sprite.sprite_frames.get_frame_texture(sprite.animation, clampi(sprite.frame, 0, count - 1))
	var local_size: Vector2 = texture.get_size() if texture != null else Vector2(28.0, 40.0)
	var actual_scale: Vector2 = sprite.global_transform.get_scale().abs()
	var body := RectangleShape2D.new()
	body.size = Vector2(maxf(48.0, local_size.x * actual_scale.x * (0.65 if level6_mode else 0.49)),
		maxf(62.0, local_size.y * actual_scale.y * (0.73 if level6_mode else 0.59)))
	var center: Vector2 = sprite.global_position + Vector2(0.0, -body.size.y * 0.05)
	return attack_shape.shape.collide(attack_shape.global_transform, body,
		Transform2D(0.0, center))


func take_damage(amount: int, origin: Vector2 = Vector2.ZERO) -> void:
	tomar_dano(amount, origin)


func tomar_dano(amount: int, _origin: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or not can_receive_player_hit():
		return
	if level6_mode:
		if level6_hit_lock > 0.0:
			return
		if level6_stage == Level6Stage.PHASE_ONE:
			if king_shield_phase == KingShieldPhase.SOLO:
				var previous_hp_one: int = hp
				hp = maxi(1, hp - amount)
				if hp < previous_hp_one:
					level6_hit_lock = 0.12
					_level6_accepted_hit(previous_hp_one)
					health_changed.emit(hp, max_hp)
				if hp <= 1:
					_level6_begin_guard()
			elif king_shield_phase == KingShieldPhase.SHIELDED:
				king_shield_hit_fx = maxf(king_shield_hit_fx, king_shield_hit_pulse_duration)
			elif king_shield_phase == KingShieldPhase.EXPOSED:
				var previous_hp_last: int = hp
				hp = 0
				level6_hit_lock = 0.12
				_level6_accepted_hit(previous_hp_last)
				health_changed.emit(hp, max_hp)
				_level6_start_dissolving(true)
		elif level6_stage == Level6Stage.PHASE_THREE:
			var prior_final_hp: int = hp
			hp = maxi(0, hp - 1)
			level6_hit_lock = 0.32
			_level6_accepted_hit(prior_final_hp)
			health_changed.emit(hp, max_hp)
			if hp <= 0:
				_level6_begin_final_death()
			else:
				level6_third_attack_timer = maxf(level6_third_attack_timer, 1.0)
		elif level6_stage == Level6Stage.PHASE_TWO:
			var previous_hp_two: int = hp
			hp = maxi(0, hp - amount)
			if hp < previous_hp_two:
				level6_hit_lock = 0.12
				_level6_accepted_hit(previous_hp_two)
				health_changed.emit(hp, max_hp)
			if hp <= 0:
				_level6_start_dissolving(false)
		_update_king_hp_label()
		queue_redraw()
		return
	if state == State.DORMANT:
		_begin_encounter()
	match king_shield_phase:
		KingShieldPhase.SOLO:
			var old_hp: int = hp
			hp = maxi(1, hp - amount)
			king_black_flash_timer = maxf(0.22, king_black_hit_flash_duration)
			sprite.self_modulate = Color.BLACK
			sprite.modulate = Color.BLACK
			print("KING NECROMANCER HIT: -", old_hp - hp, " HP | ", hp, "/", max_hp)
			health_changed.emit(hp, max_hp)
			_update_king_hp_label()
		KingShieldPhase.SHIELDED:
			king_shield_hit_fx = maxf(0.1, king_shield_hit_pulse_duration)
			if king_shield_elite_spawned and not _king_elite_is_alive():
				_begin_king_shield_break()
		KingShieldPhase.BREAKING:
			pass
		KingShieldPhase.EXPOSED:
			if king_last_stand_intro_timer > 0.0:
				return
			var purple_alive: bool = _king_active_purple_count() > 0
			var hp_floor: int = (_king_purple_hp_floor() if purple_alive
				else (0 if king_last_stand_started else 1))
			if purple_alive and hp <= hp_floor:
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
	_collapse_restore_tilemaps()
	if is_instance_valid(target) and bool(target.get_meta(&"king_final_cinematic_active", false)):
		target.collision_mask = _collapse_player_mask
		target.set_physics_process(_collapse_player_physics)
		target.set_process(_collapse_player_process)
		target.remove_meta(&"king_final_cinematic_active")
	if is_instance_valid(_collapse_flash) and not _collapse_level7_transition_started:
		_collapse_flash.queue_free()
	if is_instance_valid(_collapse_ui):
		_collapse_ui.queue_free()
	for artifact: AnimatedSprite2D in _collapse_relics:
		if is_instance_valid(artifact):
			artifact.queue_free()
	for smoke: CPUParticles2D in _collapse_emitters:
		if is_instance_valid(smoke):
			smoke.queue_free()
	if _level6_artifact_rescue_active and is_inside_tree():
		get_tree().paused = _level6_artifact_prev_tree_paused
	if is_instance_valid(_level6_artifact_overlay):
		_level6_artifact_overlay.queue_free()
	if is_instance_valid(level6_title_layer):
		level6_title_layer.queue_free()
	if level6_mode:
		_level6_stop_shake()
		if is_instance_valid(level6_blackout_layer):
			level6_blackout_layer.queue_free()
		if is_instance_valid(level6_screen_layer):
			level6_screen_layer.queue_free()
		if is_instance_valid(level6_void_visual_layer):
			level6_void_visual_layer.queue_free()
		if is_instance_valid(level6_dark_test_test_layer):
			level6_dark_test_test_layer.queue_free()
		if is_instance_valid(level6_dark_test_layout_layer):
			level6_dark_test_layout_layer.queue_free()
		if is_instance_valid(level6_dark_test_high_layer):
			level6_dark_test_high_layer.queue_free()
		if is_instance_valid(level6_fx_root_v73):
			level6_fx_root_v73.queue_free()
		if is_instance_valid(level6_dark_test_label):
			level6_dark_test_label.queue_free()
		if is_instance_valid(level6_dark_test_backing_v74):
			level6_dark_test_backing_v74.queue_free()
		if is_instance_valid(level6_dark_test_ui_layer):
			level6_dark_test_ui_layer.queue_free()
		if is_instance_valid(level6_world_darkness):
			if level6_world_darkness_owned:
				level6_world_darkness.queue_free()
			else:
				level6_world_darkness.color = level6_world_darkness_original
		if is_instance_valid(level6_player_hud_layer):
			level6_player_hud_layer.layer = level6_player_hud_previous_layer
	if level6_mode and level6_camera_initialized:
		var cam: Camera2D = get_viewport().get_camera_2d()
		if is_instance_valid(cam):
			cam.offset = level6_original_cam_offset
			cam.zoom = level6_camera_base_zoom
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
	if level6_mode and animation == &"spawnenemies2":
		animation = &"idle"
	if not sprite.sprite_frames.has_animation(animation):
		return
	if restart:
		sprite.stop()
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _draw() -> void:
	if state == State.DEAD:
		return
	if level6_mode and level6_stage in [Level6Stage.HIDDEN, Level6Stage.WAITING, Level6Stage.SHAKING,
		Level6Stage.CLIMB, Level6Stage.SECOND_WAIT, Level6Stage.PHASE_THREE_PENDING]:
		return
	if is_king and level6_mode:
		var swirl_phase: float = hover_time * 1.2
		for orbit_i: int in range(14):
			var theta: float = swirl_phase + TAU * float(orbit_i) / 14.0
			var radius: float = 58.0 + 8.0 * sin(theta * 2.5 + swirl_phase)
			var mote: Vector2 = body_shape.position + Vector2.RIGHT.rotated(theta) * radius
			draw_circle(mote, 2.0 + float(orbit_i % 3), Color(0.02, 0.02, 0.027, 0.37))
	if is_king:
		var center: Vector2 = body_shape.position
		var pulse: float = 0.5 + 0.5 * sin(hover_time * 3.0)
		if not level6_mode:
			draw_circle(center, 72.0 + 4.0 * pulse, Color(0.45, 0.08, 0.80, 0.055))
		if not level6_mode and king_gravefall_active and king_special_kind == 3:
			var progress: float = clampf(1.0 - king_gravefall_warning_timer / 0.72, 0.0, 1.0)
			var alpha: float = clampf(progress / 0.30, 0.0, 1.0) * (0.48 + 0.42 * progress)
			draw_arc(center, 130.0 - 25.0 * progress, 0.0, TAU, 60,
				Color(1.0, 0.33, 0.89, alpha), 8.0, true)
			for ray_index: int in range(7):
				var angle: float = TAU * float(ray_index) / 7.0
				var ray: Vector2 = Vector2.RIGHT.rotated(angle)
				draw_line(center + ray * 35.0, center + ray * 123.0,
					Color(0.90, 0.39, 1.0, alpha), 3.0, true)
		if king_crown_burst_remaining > 0.0 and not level6_mode:
			var b: float = 1.0 - king_crown_burst_remaining / 0.34
			var radius: float = (125.0 + 75.0 * b) if b < 0.25 else (145.0 - 50.0 * (b - 0.25) / 0.75)
			draw_arc(center, radius, 0.0, TAU, 60,
				Color(0.97, 0.72, 1.0, pow(1.0 - b, 1.25)), maxf(0.5, 18.0 * (1.0 - b)), true)
		var shield_origin: Vector2 = body_shape.position
		if king_shield_phase == KingShieldPhase.SHIELDED:
			var wave: float = 0.5 + 0.5 * sin(king_shield_animation_time * 4.6)
			var shield_impact_pulse: float = king_shield_hit_fx / maxf(0.01, king_shield_hit_pulse_duration)
			var radius: float = 83.0 + 5.0 * wave + 12.0 * shield_impact_pulse
			draw_circle(shield_origin, radius, Color(0.012, 0.014, 0.019, 0.27 + 0.13 * shield_impact_pulse) if level6_mode else Color(0.22, 0.06, 0.62, 0.12 + 0.13 * shield_impact_pulse))
			draw_arc(shield_origin, radius, 0.0, TAU, 72,
				Color(0.09, 0.095, 0.11, 0.85 + 0.14 * shield_impact_pulse) if level6_mode else Color(0.78, 0.53, 1.0, 0.76 + 0.23 * shield_impact_pulse), 6.0 + shield_impact_pulse * 8.0, true)
			draw_arc(shield_origin, radius - 11.0, 0.0, TAU, 64,
				Color(0.22, 0.23, 0.25, 0.46 + 0.36 * shield_impact_pulse) if level6_mode else Color(0.95, 0.80, 1.0, 0.45 + 0.40 * shield_impact_pulse), 2.0, true)
			for rune_i: int in range(8):
				var angle: float = float(rune_i) * TAU / 8.0 + king_shield_animation_time * 0.45
				var mark: Vector2 = shield_origin + Vector2.RIGHT.rotated(angle) * radius
				draw_circle(mark, 4.0 + shield_impact_pulse * 2.0, Color(0.18, 0.19, 0.22, 0.88) if level6_mode else Color(0.90, 0.69, 1.0, 0.85))
		elif king_shield_phase == KingShieldPhase.BREAKING:
			var t: float = 1.0 - king_shield_break_fx / maxf(0.01, king_shield_break_duration)
			var alpha: float = maxf(0.0, 1.0 - t)
			for piece_i: int in range(18):
				var angle: float = TAU * float(piece_i) / 18.0
				var tangent: Vector2 = Vector2.RIGHT.rotated(angle)
				var middle: Vector2 = shield_origin + tangent * (85.0 + 70.0 * t)
				draw_line(middle - tangent.rotated(PI / 2.0) * (13.0 - t * 10.0),
					middle + tangent.rotated(PI / 2.0) * (13.0 - t * 10.0),
					Color(0.12, 0.13, 0.15, alpha) if level6_mode else Color(0.93, 0.74, 1.0, alpha), maxf(0.6, 7.0 * alpha), true)
		elif _king_purple_ward_active():
			var ward_pulse: float = 0.5 + 0.5 * sin(king_shield_animation_time * 6.0)
			var ward_hit: float = king_shield_hit_fx / maxf(0.01, king_shield_hit_pulse_duration)
			var ward_radius: float = 75.0 + 5.0 * ward_pulse + 10.0 * ward_hit
			draw_circle(shield_origin, ward_radius, Color(0.012, 0.014, 0.019, 0.30) if level6_mode else Color(0.34, 0.06, 0.56, 0.15))
			draw_arc(shield_origin, ward_radius, 0.0, TAU, 64,
				Color(0.09, 0.10, 0.12, 0.78 + 0.20 * ward_hit) if level6_mode else Color(0.92, 0.52, 1.0, 0.72 + 0.26 * ward_hit), 5.0 + 7.0 * ward_hit, true)
			draw_arc(shield_origin, ward_radius - 8.0, 0.0, TAU, 64,
				Color(0.21, 0.22, 0.24, 0.39 + 0.23 * ward_hit) if level6_mode else Color(0.64, 0.18, 0.95, 0.35 + 0.28 * ward_hit), 2.0, true)
		_draw_king_royal_slashes()
		if level6_mode:
			_level6_draw_extra_attacks()
			_level6_draw_falling_lasers()
			_level6_draw_final_implosion()
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
	if (state == State.GUARDED or state == State.OPENING) and shots_left > 0:
		draw_arc(body_shape.position, 13.0, 0.0, TAU, 24, Color(1.0, 0.23, 0.30, 0.85), 2.0)


func _level6_void_make_particle_texture(pixel_size: int, core_color: Color) -> Texture2D:
	var image: Image = Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(pixel_size - 1), float(pixel_size - 1)) * 0.5
	var radius: float = float(pixel_size) * 0.5
	for y: int in range(pixel_size):
		for x: int in range(pixel_size):
			var d: float = Vector2(float(x), float(y)).distance_to(center) / radius
			var opacity: float = pow(1.0 - smoothstep(0.0, 1.0, d), 2.0)
			image.set_pixel(x, y, Color(core_color.r, core_color.g, core_color.b, core_color.a * opacity))
	return ImageTexture.create_from_image(image)


func _level6_void_make_fog_texture() -> Texture2D:
	var width: int = 256
	var height: int = 128
	var image_data: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 72011
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.023
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	for y: int in range(height):
		var fy: float = (float(y) + 0.5) / float(height)
		var vert_mask: float = 1.0 - smoothstep(0.17, 0.50, absf(fy - 0.50))
		for x: int in range(width):
			var fx: float = (float(x) + 0.5) / float(width)
			var side_mask: float = smoothstep(0.0, 0.15, fx) * (1.0 - smoothstep(0.85, 1.0, fx))
			var n: float = noise.get_noise_2d(float(x), float(y))
			var density: float = smoothstep(-0.33, 0.24, n)
			var streak: float = 0.13 + 0.87 * pow(density, 0.72)
			var ribbons: float = 0.86 + 0.14 * sin(fy * 30.0 + n * 2.9 + fx * 6.0)
			var alpha: float = clampf(vert_mask * side_mask * streak * ribbons * 1.28, 0.0, 1.0)
			image_data.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return ImageTexture.create_from_image(image_data)


func _level6_void_make_vignette_texture() -> Texture2D:
	var width: int = 256
	var height: int = 144
	var image_data: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			var nx: float = (float(x) + 0.5) / float(width) * 2.0 - 1.0
			var ny: float = (float(y) + 0.5) / float(height) * 2.0 - 1.0
			var dist: float = Vector2(nx * 0.90, ny * 1.04).length()
			var edges: float = smoothstep(0.44, 1.06, dist)
			var bottom: float = smoothstep(0.36, 1.0, (ny + 1.0) * 0.5) * 0.09
			var opacity: float = clampf(edges * 0.83 + bottom, 0.0, 0.85)
			image_data.set_pixel(x, y, Color(0.012, 0.009, 0.04, opacity))
	return ImageTexture.create_from_image(image_data)


func _level6_void_fx_panel(texture: Texture2D, label: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = label
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	level6_fx_root_v73.add_child(rect)
	return rect


func _level6_void_world_seed_v76(cx: int, cy: int, salt: float) -> float:
	return fposmod(sin(float(cx) * 127.1 + float(cy) * 311.7 + salt) * 43758.5453, 1.0)


func _level6_create_void_atmosphere() -> void:
	if is_instance_valid(level6_fx_root_v73):
		return
	if not is_instance_valid(level6_dark_test_ui_layer):
		_level6_dark_test_setup()
	if not is_instance_valid(level6_dark_test_ui_layer):
		return

	_level6_keep_hud_above_darkness()
	var fx_host: Node = level6_player_hud_layer if is_instance_valid(level6_player_hud_layer) else level6_dark_test_ui_layer
	level6_fx_root_v73 = Control.new()
	level6_fx_root_v73.name = "VoidWorldGridProjectedOnVisibleHUD_V76"
	level6_fx_root_v73.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level6_fx_root_v73.position = Vector2.ZERO
	level6_fx_root_v73.size = get_viewport_rect().size
	level6_fx_root_v73.clip_contents = false
	fx_host.add_child.call_deferred(level6_fx_root_v73)
	fx_host.move_child.call_deferred(level6_fx_root_v73, 0)
	level6_fx_parent_is_hud_v74 = is_instance_valid(level6_player_hud_layer)

	var fog_texture: Texture2D = _level6_void_make_fog_texture()
	level6_fog_panels_v73.clear()
	for i: int in range(LEVEL6_FOG_COLS_V76 * LEVEL6_FOG_ROWS_V76):
		var bank: TextureRect = _level6_void_fx_panel(fog_texture, "WorldMist_" + str(i))
		bank.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		level6_fog_panels_v73.append(bank)

	level6_vignette_v73 = _level6_void_fx_panel(_level6_void_make_vignette_texture(), "VoidEdgeVignetteV76")

	var dot_texture: Texture2D = _level6_void_make_particle_texture(20, Color(0.0, 0.0, 0.0, 1.0))
	var smoke_texture: Texture2D = _level6_void_make_particle_texture(36, Color(0.0, 0.0, 0.0, 1.0))
	level6_ash_motes_v73.clear()
	level6_mote_velocities_v73.clear()
	level6_mote_opacities_v73.clear()
	for i: int in range(LEVEL6_ASH_COLS_V76 * LEVEL6_ASH_ROWS_V76):
		var smoke: bool = i % 7 == 0
		var mote: TextureRect = _level6_void_fx_panel(smoke_texture if smoke else dot_texture,
			"WorldSmoke_" + str(i) if smoke else "WorldAsh_" + str(i))
		mote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		level6_ash_motes_v73.append(mote)
		level6_mote_opacities_v73.append(0.26 if smoke else 0.52)
		level6_mote_velocities_v73.append(Vector2.ZERO)

	level6_void_viewport_size = get_viewport_rect().size
	level6_void_atmosphere_ready = true
	print("VOID KING V79: TRUE BLACK WORLD FOG READY; host=", fx_host.get_path() if fx_host.is_inside_tree() else fx_host.name,
		" fog=", level6_fog_panels_v73.size(), " ash=", level6_ash_motes_v73.size(),
		" camera=", get_viewport().get_camera_2d())


func _level6_update_void_atmosphere(_darkness: float) -> void:
	if not is_instance_valid(level6_fx_root_v73):
		_level6_create_void_atmosphere()
	if not is_instance_valid(level6_fx_root_v73):
		return

	var screen: Vector2 = get_viewport_rect().size
	if not level6_void_viewport_size.is_equal_approx(screen):
		level6_void_viewport_size = screen
		level6_fx_root_v73.size = screen

	var fog_target: float = 0.0
	var vignette_target: float = 0.0
	if level6_stage == Level6Stage.PHASE_ONE:
		if king_shield_phase == KingShieldPhase.SOLO:
			var first_danger: float = 1.0 - float(hp) / maxf(1.0, float(max_hp))
			vignette_target = 0.13 + 0.17 * clampf(first_danger, 0.0, 1.0)
		elif king_shield_phase == KingShieldPhase.SHIELDED:
			var guard_danger: float = 1.0 - _level6_guard_hp_ratio()
			fog_target = smoothstep(0.40, 0.90, guard_danger)
			vignette_target = 0.26 + fog_target * 0.58
			if fog_target >= 0.45 and not level6_void_guard_cue_logged_v79:
				level6_void_guard_cue_logged_v79 = true
				print("VOID KING V79: dying skeleton activated BLACK FOG + VIGNETTE")
		else:
			fog_target = 0.65
			vignette_target = 0.79
	elif level6_stage == Level6Stage.PHASE_TWO:
		var second_danger: float = 1.0 - float(hp) / maxf(1.0, float(max_hp))
		vignette_target = 0.23 + 0.22 * clampf(second_danger, 0.0, 1.0)
	elif level6_stage == Level6Stage.DISSOLVE_ONE:
		fog_target = 0.30
		vignette_target = 0.54
	elif level6_stage == Level6Stage.DISSOLVE_TWO:
		fog_target = 0.27
		vignette_target = 0.40
	elif level6_stage == Level6Stage.PHASE_THREE_PENDING:
		fog_target = 0.34
		vignette_target = 0.42
	elif level6_stage == Level6Stage.PHASE_THREE_CLIMB:
		fog_target = 0.42
		vignette_target = 0.44
	elif level6_stage == Level6Stage.THIRD_REVEAL:
		fog_target = level6_phase3_fog_floor_v80
		vignette_target = 0.52
	elif level6_stage == Level6Stage.PHASE_THREE:
		var final_danger: float = clampf(1.0 - float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
		fog_target = lerpf(level6_phase3_fog_floor_v80, 1.0,
			pow(final_danger, 1.15))
		vignette_target = 0.46 + 0.48 * smoothstep(0.0, 1.0, final_danger)
		if hp <= 3 and not level6_void_final_cue_logged_v79:
			level6_void_final_cue_logged_v79 = true
			print("VOID KING V80: final-three-hit fog and vignette crescendo")
	elif level6_stage == Level6Stage.THIRD_DEATH:
		fog_target = 0.75
		vignette_target = 0.67

	var dt: float = maxf(0.0, get_physics_process_delta_time())
	var fog_rate: float = 0.86 if fog_target > level6_void_auto_fog_power_v79 else 0.42
	var vignette_rate: float = 1.15 if vignette_target > level6_void_auto_vignette_power_v79 else 0.65
	level6_void_auto_fog_power_v79 = move_toward(level6_void_auto_fog_power_v79,
		fog_target, dt * fog_rate)
	level6_void_auto_vignette_power_v79 = move_toward(level6_void_auto_vignette_power_v79,
		vignette_target, dt * vignette_rate)
	var power: float = level6_void_auto_fog_power_v79
	level6_void_ambient_intensity = power
	level6_void_fog_time += dt * level6_void_fog_motion_speed_v79
	var pulse: float = 1.0
	if level6_stage == Level6Stage.PHASE_THREE and hp <= 3:
		pulse = 0.96 + 0.04 * sin(level6_void_fog_time * 1.35)

	var world_to_screen: Transform2D = get_viewport().get_canvas_transform()
	var screen_to_world: Transform2D = world_to_screen.affine_inverse()
	var world_center: Vector2 = screen_to_world * (screen * 0.5)
	var zoom_x: float = maxf(0.15, world_to_screen.x.length())
	var zoom_y: float = maxf(0.15, world_to_screen.y.length())

	var show_fog: bool = level6_test_fog or power > 0.025
	var fog_alpha: float = (level6_void_manual_fog_alpha_v79 if level6_test_fog
		else lerpf(0.23, level6_void_max_auto_fog_alpha_v79, power)) * pulse
	var grid_x: int = floori(world_center.x / LEVEL6_FOG_SPACING_V76.x)
	var grid_y: int = floori(world_center.y / LEVEL6_FOG_SPACING_V76.y)
	for i: int in range(level6_fog_panels_v73.size()):
		var bank: TextureRect = level6_fog_panels_v73[i]
		var cx: int = grid_x + i % LEVEL6_FOG_COLS_V76 - 4
		var cy: int = grid_y + floori(float(i) / float(LEVEL6_FOG_COLS_V76)) - 3
		var seeded: float = _level6_void_world_seed_v76(cx, cy, 17.0)
		bank.visible = show_fog and seeded > 0.23
		if not bank.visible:
			continue
		var jitter: Vector2 = Vector2(
			(_level6_void_world_seed_v76(cx, cy, 31.0) - 0.5) * 190.0,
			(_level6_void_world_seed_v76(cx, cy, 67.0) - 0.5) * 95.0)
		var drift: Vector2 = Vector2(
			sin(level6_void_fog_time * (0.39 + 0.11 * seeded) + seeded * TAU) * 68.0
				+ sin(level6_void_fog_time * 0.17 + seeded * 4.3) * 27.0,
			cos(level6_void_fog_time * (0.25 + 0.08 * seeded) + seeded * TAU) * 24.0
				+ sin(level6_void_fog_time * 0.31 + seeded * 2.0) * 11.0)
		var world_position: Vector2 = Vector2(float(cx) * LEVEL6_FOG_SPACING_V76.x,
			float(cy) * LEVEL6_FOG_SPACING_V76.y) + jitter + drift
		var pixel_center: Vector2 = world_to_screen * world_position
		var world_width: float = 480.0 + seeded * 90.0
		var world_height: float = 175.0 + seeded * 45.0
		var breathing: float = 1.0 + 0.045 * sin(level6_void_fog_time * 0.43 + seeded * TAU)
		bank.size = Vector2(world_width * zoom_x, world_height * zoom_y) * breathing
		bank.position = pixel_center - bank.size * 0.5
		bank.modulate = Color(1.0, 1.0, 1.0,
			fog_alpha * (0.84 + 0.16 * seeded))

	var show_ash: bool = level6_test_particles or power > 0.055
	var ash_alpha: float = 0.78 if level6_test_particles else lerpf(0.23, 0.64, power)
	var ash_x: int = floori(world_center.x / LEVEL6_ASH_SPACING_V76.x)
	var ash_y: int = floori(world_center.y / LEVEL6_ASH_SPACING_V76.y)
	for i: int in range(level6_ash_motes_v73.size()):
		var mote: TextureRect = level6_ash_motes_v73[i]
		var cx: int = ash_x + i % LEVEL6_ASH_COLS_V76 - 6
		var cy: int = ash_y + floori(float(i) / float(LEVEL6_ASH_COLS_V76)) - 4
		var seeded: float = _level6_void_world_seed_v76(cx, cy, 109.0)
		mote.visible = show_ash and seeded > 0.24
		if not mote.visible:
			continue
		var smoke: bool = i % 7 == 0
		var jitter: Vector2 = Vector2(
			(_level6_void_world_seed_v76(cx, cy, 119.0) - 0.5) * 115.0,
			(_level6_void_world_seed_v76(cx, cy, 127.0) - 0.5) * 75.0)
		var float_motion: Vector2 = Vector2(
			sin(level6_void_fog_time * (0.48 + 0.14 * seeded) + seeded * TAU) * 18.0,
			48.0 - fposmod(level6_void_fog_time * (11.0 + 10.0 * seeded)
				+ seeded * 85.0, 96.0))
		var world_position: Vector2 = Vector2(float(cx) * LEVEL6_ASH_SPACING_V76.x,
			float(cy) * LEVEL6_ASH_SPACING_V76.y) + jitter + float_motion
		var pixel_center: Vector2 = world_to_screen * world_position
		var diameter: float = (12.0 + seeded * 8.0) if smoke else (3.5 + seeded * 3.3)
		mote.size = Vector2(diameter * zoom_x, diameter * zoom_y)
		mote.position = pixel_center - mote.size * 0.5
		mote.modulate = Color(1.0, 1.0, 1.0,
			ash_alpha * (0.55 if smoke else 0.95) * (0.83 + 0.17 * seeded))

	if is_instance_valid(level6_vignette_v73):
		level6_vignette_v73.position = Vector2.ZERO
		level6_vignette_v73.size = screen
		level6_vignette_v73.visible = (level6_test_vignette
			or level6_void_auto_vignette_power_v79 > 0.025)
		level6_vignette_v73.modulate.a = (0.63 if level6_test_vignette
			else clampf(level6_void_auto_vignette_power_v79 * 0.77, 0.0, 0.73))

	if is_instance_valid(level6_particle_test_signal_v73):
		level6_particle_test_signal_v73.visible = false

func _input(event: InputEvent) -> void:
	if not level6_mode or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var keycode: int = key_event.physical_keycode
	if keycode in [KEY_3, KEY_KP_3] or key_event.keycode in [KEY_3, KEY_KP_3]:
		if level6_stage not in [Level6Stage.THIRD_DEATH, Level6Stage.COMPLETE]:
			if not is_instance_valid(target):
				target = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
			if is_instance_valid(target):
				print("KING FINAL V88 DEBUG 3: começando morte, colapso e queda")
				_level6_begin_final_death()
		get_viewport().set_input_as_handled()
		return
	match keycode:
		KEY_0:
			level6_test_fog = false
			level6_test_particles = false
			level6_test_vignette = false
			level6_preview_all_v76 = false
			_level6_dark_test_select(0)
			_level6_update_void_atmosphere(level6_darkness_now)
			return
		KEY_9:
			level6_test_fog = not level6_test_fog
			_level6_update_void_atmosphere(level6_darkness_now)
			print("VOID KING V79: FOG toggle = ", level6_test_fog)
			_level6_dark_test_label_update()
			return
		KEY_P:
			level6_test_particles = not level6_test_particles
			_level6_update_void_atmosphere(level6_darkness_now)
			print("VOID KING V79: UI MOTES toggle = ", level6_test_particles)
			_level6_dark_test_label_update()
			return
		KEY_V:
			level6_test_vignette = not level6_test_vignette
			_level6_update_void_atmosphere(level6_darkness_now)
			print("VOID KING V79: VIGNETTE toggle = ", level6_test_vignette)
			_level6_dark_test_label_update()
			return
		KEY_B:
			var all_enabled: bool = level6_test_fog and level6_test_particles and level6_test_vignette and level6_dark_test_mode == 4
			if all_enabled and level6_preview_all_v76:
				level6_preview_all_v76 = false
				level6_test_fog = false
				level6_test_particles = false
				level6_test_vignette = false
				_level6_dark_test_select(0)
			else:
				level6_test_fog = true
				level6_test_particles = true
				level6_test_vignette = true
				level6_preview_all_v76 = true
				_level6_dark_test_select(4)
			_level6_update_void_atmosphere(level6_darkness_now)
			print("VOID KING V79: full atmosphere preview = ", not all_enabled)
			return
	var next_mode: int = -1
	match keycode:
		KEY_4:
			next_mode = 4
		KEY_5:
			next_mode = 5
		KEY_6:
			next_mode = 6
		KEY_7:
			next_mode = 7
		KEY_8:
			next_mode = 8
	if next_mode < 0:
		return
	level6_preview_all_v76 = false
	if next_mode == level6_dark_test_mode:
		next_mode = 0
	_level6_dark_test_select(next_mode)

func _level6_dark_test_setup() -> void:
	set_process_input(true)
	set_process(true)
	if is_instance_valid(level6_dark_test_ui_layer):
		return
	_level6_keep_hud_above_darkness()
	level6_dark_test_ui_layer = CanvasLayer.new()
	level6_dark_test_ui_layer.name = "V76_ATMOSPHERE_LAB_FALLBACK"
	level6_dark_test_ui_layer.layer = 850
	level6_dark_test_ui_layer.follow_viewport_enabled = false
	get_tree().root.add_child.call_deferred(level6_dark_test_ui_layer)


func _level6_dark_test_select(next_mode: int) -> void:
	if not is_instance_valid(level6_dark_test_ui_layer):
		_level6_dark_test_setup()
	_level6_dark_test_clear_all()
	level6_dark_test_mode = next_mode
	_level6_dark_test_tick()
	var label: String = _level6_dark_test_mode_name()
	var drawn_rect: ColorRect = _level6_dark_test_active_rect()
	var in_tree: bool = is_instance_valid(drawn_rect) and drawn_rect.is_visible_in_tree()
	print("VOID KING V71: darkness key selected = ", next_mode, " | method = ", label,
		" | node_visible_in_tree = ", in_tree,
		" | canvas = ", _level6_dark_test_canvas_number(),
		" | viewport = ", get_viewport_rect().size)


func _level6_dark_test_mode_name() -> String:
	match level6_dark_test_mode:
		4:
			return "V62: black ColorRect + color.a, layer 100"
		5:
			return "V64: Control/full-rect + color.a, layer 160"
		6:
			return "V65: CanvasModulate darkens the world canvas"
		7:
			return "V66: root-level black screen, layer 800"
		8:
			return "V67: black rectangle on boss title canvas, layer 520"
		_:
			return "OFF / normal automatic boss-phase darkness"


func _level6_dark_test_canvas_number() -> int:
	match level6_dark_test_mode:
		4:
			return level6_dark_test_test_layer.layer if is_instance_valid(level6_dark_test_test_layer) else -1
		5:
			return level6_dark_test_layout_layer.layer if is_instance_valid(level6_dark_test_layout_layer) else -1
		7:
			return level6_dark_test_high_layer.layer if is_instance_valid(level6_dark_test_high_layer) else -1
		8:
			return level6_title_layer.layer if is_instance_valid(level6_title_layer) else -1
		_:
			return -1


func _level6_dark_test_active_rect() -> ColorRect:
	match level6_dark_test_mode:
		4:
			return level6_dark_test_test_rect
		5:
			return level6_dark_test_layout_rect
		7:
			return level6_dark_test_high_rect
		8:
			return level6_dark_test_title_rect
		_:
			return null


func _level6_dark_test_clear_all() -> void:
	if is_instance_valid(level6_screen_shadow):
		level6_screen_shadow.modulate.a = 1.0
		level6_screen_shadow.color = Color(0.0, 0.0, 0.0, 0.0)
		level6_screen_shadow.visible = true
	if is_instance_valid(level6_dark_test_test_layer):
		level6_dark_test_test_layer.visible = false
	if is_instance_valid(level6_dark_test_layout_layer):
		level6_dark_test_layout_layer.visible = false
	if is_instance_valid(level6_dark_test_high_layer):
		level6_dark_test_high_layer.visible = false
	if is_instance_valid(level6_dark_test_title_rect):
		level6_dark_test_title_rect.visible = false
	if is_instance_valid(level6_world_darkness):
		level6_world_darkness.color = level6_world_darkness_original


func _level6_dark_test_tick() -> void:
	if not level6_mode:
		return
	if level6_dark_test_mode == 0:
		_level6_dark_test_label_update()
		return
	var vp_size: Vector2 = get_viewport_rect().size
	match level6_dark_test_mode:
		4:
			if not is_instance_valid(level6_dark_test_test_rect):
				level6_dark_test_test_layer = CanvasLayer.new()
				level6_dark_test_test_layer.name = "V71_Method4_V62_ColorAlpha"
				level6_dark_test_test_layer.layer = 100
				get_tree().root.add_child.call_deferred(level6_dark_test_test_layer)
				level6_dark_test_test_rect = ColorRect.new()
				level6_dark_test_test_rect.name = "ColorAlphaTest"
				level6_dark_test_test_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				level6_dark_test_test_layer.add_child(level6_dark_test_test_rect)
			level6_dark_test_test_layer.visible = true
			level6_dark_test_test_rect.visible = true
			level6_dark_test_test_rect.color = Color(0.0, 0.0, 0.0, 0.27 if level6_preview_all_v76 else 0.83)
			level6_dark_test_test_rect.position = Vector2.ZERO
			if not level6_dark_test_test_rect.size.is_equal_approx(vp_size):
				level6_dark_test_test_rect.size = vp_size
		5:
			if not is_instance_valid(level6_dark_test_layout_rect):
				level6_dark_test_layout_layer = CanvasLayer.new()
				level6_dark_test_layout_layer.name = "V71_Method5_V64_ViewportControl"
				level6_dark_test_layout_layer.layer = 160
				get_tree().root.add_child.call_deferred(level6_dark_test_layout_layer)
				level6_dark_test_layout_root = Control.new()
				level6_dark_test_layout_root.name = "ViewportRoot"
				level6_dark_test_layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
				level6_dark_test_layout_layer.add_child(level6_dark_test_layout_root)
				level6_dark_test_layout_root.size = vp_size
				level6_dark_test_layout_rect = ColorRect.new()
				level6_dark_test_layout_rect.name = "StretchedAlphaTest"
				level6_dark_test_layout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				level6_dark_test_layout_root.add_child(level6_dark_test_layout_rect)
				level6_dark_test_layout_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			level6_dark_test_layout_layer.visible = true
			level6_dark_test_layout_rect.visible = true
			level6_dark_test_layout_rect.color = Color(0.0, 0.0, 0.0, 0.83)
			if not level6_dark_test_layout_root.size.is_equal_approx(vp_size):
				level6_dark_test_layout_root.size = vp_size
		6:
			if not is_instance_valid(level6_world_darkness):
				var scene_root: Node = get_tree().current_scene
				if not is_instance_valid(scene_root):
					scene_root = get_parent()
				if is_instance_valid(scene_root):
					for child: Node in scene_root.get_children():
						if child is CanvasModulate:
							level6_world_darkness = child as CanvasModulate
							level6_world_darkness_owned = false
							break
					if not is_instance_valid(level6_world_darkness):
						level6_world_darkness = CanvasModulate.new()
						level6_world_darkness.name = "V71_Method6_V65_CanvasModulate"
						scene_root.add_child(level6_world_darkness)
						level6_world_darkness_owned = true
					level6_world_darkness_original = level6_world_darkness.color
			if is_instance_valid(level6_world_darkness):
				level6_world_darkness.visible = true
				level6_world_darkness.color = Color(0.17, 0.17, 0.17, 1.0)
		7:
			if not is_instance_valid(level6_dark_test_high_rect):
				level6_dark_test_high_layer = CanvasLayer.new()
				level6_dark_test_high_layer.name = "V71_Method7_V66_HighCanvas"
				level6_dark_test_high_layer.layer = 800
				level6_dark_test_high_layer.follow_viewport_enabled = false
				get_tree().root.add_child.call_deferred(level6_dark_test_high_layer)
				level6_dark_test_high_rect = ColorRect.new()
				level6_dark_test_high_rect.name = "HighCanvasBlackout"
				level6_dark_test_high_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				level6_dark_test_high_layer.add_child(level6_dark_test_high_rect)
			level6_dark_test_high_layer.visible = true
			level6_dark_test_high_rect.visible = true
			level6_dark_test_high_rect.color = Color(0.0, 0.0, 0.0, 0.83)
			level6_dark_test_high_rect.position = Vector2.ZERO
			if not level6_dark_test_high_rect.size.is_equal_approx(vp_size):
				level6_dark_test_high_rect.size = vp_size
		8:
			if not is_instance_valid(level6_title_layer):
				_level6_create_title_overlay()
			if is_instance_valid(level6_title_layer):
				if not is_instance_valid(level6_dark_test_title_rect):
					level6_dark_test_title_rect = ColorRect.new()
					level6_dark_test_title_rect.name = "V71_Method8_V67_TitleDarkness"
					level6_dark_test_title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					level6_title_layer.add_child(level6_dark_test_title_rect)
					level6_title_layer.move_child(level6_dark_test_title_rect, 0)
				level6_title_layer.visible = true
				if level6_stage != Level6Stage.INTRO_TITLE:
					level6_title_layer.layer = 520
					if is_instance_valid(level6_title_black):
						level6_title_black.visible = false
					if is_instance_valid(level6_title_text):
						level6_title_text.visible = false
					if is_instance_valid(level6_title_king_text):
						level6_title_king_text.visible = false
				level6_dark_test_title_rect.visible = true
				level6_dark_test_title_rect.color = Color(0.0, 0.0, 0.0, 0.83)
				level6_dark_test_title_rect.position = Vector2.ZERO
				if not level6_dark_test_title_rect.size.is_equal_approx(vp_size):
					level6_dark_test_title_rect.size = vp_size
	_level6_dark_test_label_update()


func _level6_dark_test_label_update() -> void:
	if not is_instance_valid(level6_dark_test_label):
		return
	var active_rect: ColorRect = _level6_dark_test_active_rect()
	var draw_status: String = "auto alpha=" + str(snappedf(level6_screen_shadow.color.a, 0.01)) if is_instance_valid(level6_screen_shadow) else "auto overlay MISSING"
	if level6_dark_test_mode == 6:
		draw_status = "CanvasModulate=" + str(level6_world_darkness.color) if is_instance_valid(level6_world_darkness) else "CanvasModulate MISSING"
	elif level6_dark_test_mode > 0:
		draw_status = "test node visible=" + str(active_rect.is_visible_in_tree()) + " | alpha=" + str(active_rect.color.a) if is_instance_valid(active_rect) else "test node MISSING"
	var fog_visible: int = 0
	for bank: TextureRect in level6_fog_panels_v73:
		if is_instance_valid(bank) and bank.is_visible_in_tree():
			fog_visible += 1
	var ash_visible: int = 0
	for mote: TextureRect in level6_ash_motes_v73:
		if is_instance_valid(mote) and mote.is_visible_in_tree():
			ash_visible += 1
	level6_dark_test_label.text = (
        "VOID KING V79 MOVING BLACK FOG + AUTO CLIMAXES  3=ENDING  4-8=dark  9=FOG  P=ash  V=vignette  B=ALL  0=reset\n"
		+ "DARK " + str(level6_dark_test_mode) + " " + _level6_dark_test_mode_name() + " | " + draw_status + "\n"
		+ "FOG=" + str(level6_test_fog) + " PARTICLES=" + str(level6_test_particles)
		+ " VIGNETTE=" + str(level6_test_vignette) + " | stage=" + str(level6_stage) + "\n"
		+ "V74 HUD canvas=" + str(level6_fx_parent_is_hud_v74)
		+ " fog drawn=" + str(fog_visible) + " ash drawn=" + str(ash_visible)
		+ " | B preview=" + str(level6_preview_all_v76)
	)
