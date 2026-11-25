# Menacing Skeleton V47 - restored V45 attack timings; fog-only visual delay handled by fog V15
# Menacing Skeleton V41 - syntax fix: restored two indented original statements
# Menacing Skeleton V45 - predictive orange dash fog, real windup before ALL dashes, swept orange sword hit
# Menacing Skeleton V44 - deterministic pre-dash fog timing; fight-only parallax ambience
# Menacing Skeleton V43 - fog warning for real dashes only + ambience hook
# Menacing Skeleton V42 - WORLD-SPACE ground fog, dense lateral warning sweep BEFORE each Level 3 dash, scatter DURING dash
# Based on V41 (corrected V39 boss); ordinary enemies and non-Level3 stages unchanged
# Requires res://menacing_phase3_fog.gd alongside this boss script.
# Fog is visual-only, and is not tied to phase 3 HP thresholds.
# Menacing Skeleton V39 - higher breakable platforms, anti-camping and triple-dash retaliation
# Menacing Skeleton V38 - committed airborne downswing pose and slightly slower non-dash sword attacks in Level 3
# Menacing Skeleton V37 - occasional 1 HP white healing wisps during the Level 3 boss battle
# Menacing Skeleton V36 - uniform Level 3 dash movement speed, independent of sword tempo
# Menacing Skeleton V35 - longer readable warnings and staged sword tempo; faster yellow arena dash
# Menacing Skeleton V34 - Level 3 attack families by color, no arrow/frozen-frame warnings
# Menacing Skeleton V27 - grounded ghost fade-in over corpse
# Menacing Skeleton V26 - one-second genuine navigation-stall teleport to safe terrain
# Menacing Skeleton V25 - larger resurrected body, matching hurtbox and modest sword scale
# Menacing Skeleton V24: remove misleading front-circle warning; keep sprite-color and windup telegraphs
# Menacing Skeleton V23: Menacing corpses/guards never stack; slash damage cannot hit far behind
# Menacing Skeleton V22: 4.7s cinematic royal resurrection, fade + hold + reverse death
# Menacing Skeleton V21: persistent corpses and ghost/reverse-death royal resurrection
# Menacing Skeleton V20: purple resurrection gets extra dash/jump pressure and longer combos with fair warnings
# Menacing Skeleton V19: readable telegraphs, independent tactical walk/backpedal AI
# V17 - faster Menacing attack rhythms; regular hits deal damage without interrupting an already committed attack; parry still cancels
# V15 - King Necromancer summon integration without artifact-mode side effects
extends CharacterBody2D
# V16: true sprite-aligned hurtbox + no stun immunity (including King summons)
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
enum SoloAttack { NONE, RED, ORANGE, YELLOW, JUMP, GREEN, PURPLE, PLATFORM_PUNISH, FOG_SLAM, FOUNTAIN_DASH }

@export var solo_attack_repeat_delay: float = 4.0
@export var solo_special_repeat_delay: float = 6.0
var _solo_attack_ready_at: Dictionary = {}
var _solo_combat_clock: float = 0.0
var _solo_reposition_remaining: float = 0.0

@export_group("Combat")
@export var max_hp: int = 25
@export var damage_per_hit: int = 1
@export var activation_radius: float = 165.0
@export var pursuit_speed: float = 120.0
@export var gravity: float = 980.0
@export var maximum_fall_speed: float = 680.0
@export var melee_reach: float = 105.0
@export var attack_interval: float = 0.42
@export var attack_interval_random: float = 0.10

@export_group("Combat Movement AI")
@export var tactical_min_range: float = 86.0
@export var tactical_max_range: float = 155.0
@export var tactical_decision_min: float = 0.75
@export var tactical_decision_max: float = 1.65
@export_range(0.0, 1.0) var tactical_retreat_chance: float = 0.35
@export var tactical_backpedal_multiplier: float = 0.74
@export var tactical_walk_pause_chance: float = 0.13

@export_group("Sword Attacks")
@export var dash_attack_distance: float = 310.0
@export var attack_warning_seconds: float = 1.00
@export var attack_warning_color: Color = Color(1.0, 0.72, 0.32)
@export var combo_swing_seconds: float = 0.15
@export var combo_followup_pause: float = 0.020
@export var combo_dash_seconds: float = 0.085
@export var combo_dash_distance: float = 52.0
@export var point_blank_distance: float = 60.0
@export var point_blank_warning_seconds: float = 1.15
@export var point_blank_commit_seconds: float = 0.09
@export var point_blank_followup_pause: float = 0.12
@export var point_blank_swing_seconds: float = 0.18
@export_range(0.0, 1.0) var alternate_combo_chance: float = 0.30
@export var endlag: float = 0.72
@export_range(0.0, 1.0) var advancing_slam_chance: float = 0.18
@export var advancing_slam_warning_seconds: float = 1.10
@export var advancing_slam_distance: float = 104.0
@export var advancing_slam_seconds: float = 0.30

@export_group("Solo Boss Arena")
@export var solo_arena_barriers: bool = true
@export_range(1.0, 4.0, 0.25) var solo_hp_multiplier: float = 2.0
@export_range(100, 500, 10) var solo_boss_min_hp: int = 270
@export var solo_arena_fallback_padding: float = 530.0

@export_group("Solo Boss Combat Stages")
@export_range(0.50, 0.80, 0.05) var solo_stage_two_threshold: float = 0.65
@export_range(0.15, 0.45, 0.05) var solo_stage_three_threshold: float = 0.30
@export_range(0.3, 1.5, 0.05) var solo_stage_transition_pause: float = 0.85

@export_group("Level 3 Boss Color Warnings")
@export var solo_red_warning_color: Color = Color(1.0, 0.17, 0.22)
@export var solo_orange_warning_color: Color = Color(1.0, 0.56, 0.14)
@export var solo_yellow_warning_color: Color = Color(1.0, 0.88, 0.15)
@export var solo_green_warning_color: Color = Color(0.30, 0.97, 0.40)
@export var solo_purple_warning_color: Color = Color(0.72, 0.39, 1.0)
@export_range(0.45, 1.30, 0.05) var solo_red_warning_seconds: float = 0.85
@export_range(0.30, 1.00, 0.05) var solo_orange_warning_seconds: float = 0.60
@export_range(0.35, 1.00, 0.05) var solo_yellow_warning_seconds: float = 0.63
@export_range(0.20, 0.80, 0.05) var solo_green_warning_seconds: float = 0.36
@export_range(0.40, 1.10, 0.05) var solo_purple_warning_seconds: float = 0.66
@export_range(0.06, 0.45, 0.02) var solo_combo_followup_warning: float = 0.16
@export_range(0.80, 1.60, 0.05) var solo_long_jump_multiplier: float = 1.22
@export_range(1600.0, 2600.0, 50.0) var solo_level3_dash_speed: float = 2150.0
@export_range(200.0, 1800.0, 50.0) var solo_full_dash_fallback_distance: float = 740.0
@export_range(60.0, 220.0, 5.0) var solo_jump_air_drift_speed: float = 125.0
@export_range(1.0, 2.0, 0.05) var solo_ground_swing_slowdown: float = 1.40

@export_group("Level 3 WORLD Fog (all HP stages)")
@export var level3_fog_enabled: bool = true
@export var level3_fog_start_immediately: bool = true # For testing: ambient ground fog sweeps in at scene start.
@export var level3_fog_script_path: String = "res://menacing_phase3_fog.gd"
# Minimum actual windup BEFORE each Level 3 dash. The fog must have time to
# finish sweeping while the boss is still telegraphing, never in the dash.
@export_range(0.70, 1.50, 0.05) var level3_fog_min_dash_warning: float = 1.05
@export_range(0.0, 2.0, 0.05) var level3_fog_swing_disturbance: float = 0.85
@export_range(0.0, 2.0, 0.05) var level3_fog_dash_disturbance: float = 0.65
@export_range(0.04, 0.35, 0.01) var level3_fog_dash_pulse_interval: float = 0.13

@export_group("Level 3 Last Judge-Inspired Specials")
# Set 1 or 2 to test the new attacks; 0 = regular selection.
@export_enum("Random", "Always Fog Slam", "Always Fountain Dash") var last_judge_test_attack: int = 0
@export_range(0.0, 0.5, 0.01) var last_judge_fog_slam_chance: float = 0.34
@export_range(0.0, 0.5, 0.01) var last_judge_fountain_dash_chance: float = 0.50
@export_range(260.0, 650.0, 10.0) var last_judge_slam_jump_speed: float = 440.0
@export_range(0.1, 0.6, 0.01) var last_judge_slam_hover_seconds: float = 0.30
@export_range(650.0, 1700.0, 25.0) var last_judge_slam_descent_speed: float = 1125.0
@export_range(0.3, 1.2, 0.05) var last_judge_hazard_damage_interval: float = 0.9

@export_group("Level 3 Arena Platforms")
@export var solo_arena_platforms_enabled: bool = true
@export_range(90.0, 190.0, 5.0) var solo_platform_width: float = 128.0
@export_range(14.0, 30.0, 2.0) var solo_platform_thickness: float = 20.0
@export_range(55.0, 150.0, 1.0) var solo_platform_height_above_ground: float = 93.0
@export_range(1.5, 6.0, 0.1) var solo_platform_camp_seconds: float = 2.9
@export_range(0.35, 1.5, 0.05) var solo_platform_shatter_warning_seconds: float = 0.75
@export_range(1800.0, 2800.0, 50.0) var solo_platform_revenge_dash_speed: float = 2350.0

@export_group("Level 3 Healing Wisps")
@export_range(8.0, 60.0, 1.0) var solo_heal_interval_seconds: float = 20.0
@export_range(0.0, 1.0, 0.05) var solo_heal_spawn_chance: float = 0.65
@export_range(6.0, 30.0, 1.0) var solo_heal_lifetime_seconds: float = 14.0

@export_group("Jump Slam and Evasion")
@export_range(0.0, 1.0) var jump_slam_chance: float = 0.30
@export var jump_slam_range: float = 155.0
@export var jump_slam_warning_seconds: float = 1.05
@export var jump_slam_launch_speed: float = 305.0
@export var jump_slam_move_speed: float = 235.0
@export_range(0.0, 1.0) var evade_chance: float = 0.24
@export var evade_distance: float = 42.0
@export var evade_speed: float = 230.0
@export var evade_cooldown_seconds: float = 2.4

@export_group("Long Lunge")
@export_range(0.0, 1.0) var close_lunge_chance: float = 0.23
@export var lunge_warning_seconds: float = 1.10
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
@export var stun_immunity_period: float = 0.0 # Legacy Inspector setting; damage now always stuns.

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
# Maximum distance the PLAYER body-center may be behind this skeleton
# and still be struck. The frontal reach is unchanged.
@export_range(0.0, 25.0, 1.0) var sword_rear_reach_tolerance: float = 8.0
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

@export_group("Stuck Teleport")
@export_range(0.5, 3.0, 0.1) var stuck_teleport_after_seconds: float = 1.0
@export_range(1.0, 8.0, 0.5) var stuck_teleport_retry_cooldown: float = 3.0
@export_range(5.0, 60.0, 1.0) var stuck_teleport_min_progress: float = 18.0
@export_range(70.0, 200.0, 5.0) var stuck_teleport_min_player_distance: float = 135.0
# Never change collision_mask to pass through terrain.


@export_group("Artifact Buff Integration")
# Preserved so existing scenes and King summon setup can still load.
# Neither Inspector test override grants artifacts to the Player anymore.
@export_range(-1, 4, 1) var test_artifact_count_override: int = -1
@export var debug_grant_all_artifact_buffs_on_engage: bool = false

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
var damage_white_flash: float = 0.0
# Each skeleton owns its own tactic timer, so simultaneous King summons
# do not mirror one another or always swing on the same frame.
var tactical_timer: float = 0.0
var tactical_choice: int = 0 # 0 approach, 1 backpedal, 2 hold, 3 circle/reposition
var tactical_side: float = 1.0
var walk_playing_backwards: bool = false
var royal_guard_index: int = -1

# Royal summons remain as corpses after their death animation, until the King
# resurrects the SAME instance. Ordinary Menacing Skeletons still disappear.
var royal_corpse_ready: bool = false
var royal_reviving_stage: int = 0  # 0 corpse/none, 1 fade-in, 2 ghost hold, 3 reverse death
var royal_revive_elapsed: float = 0.0
var royal_revive_preview: AnimatedSprite2D = null
@export_group("Purple Menacing Size")
@export_range(1.05, 1.5, 0.05) var royal_reborn_visual_multiplier: float = 1.25
@export_range(1.05, 1.5, 0.05) var royal_reborn_body_multiplier: float = 1.20
@export_range(1.0, 1.3, 0.05) var royal_reborn_attack_multiplier: float = 1.10
var royal_reborn_growth_applied: bool = false
var royal_reborn_floor_lift: float = 0.0

@export_group("Royal Resurrection Cinematic")
@export_range(1.0, 5.0, 0.1) var royal_revive_ghost_seconds: float = 2.2
@export_range(0.3, 3.0, 0.1) var royal_revive_hold_seconds: float = 0.9
@export_range(0.5, 3.0, 0.1) var royal_revive_reverse_seconds: float = 1.6
var royal_original_collision_layer: int = 0
var royal_original_collision_mask: int = 0
var stuck_timer: float = 0.0
var stuck_anchor_x: float = 0.0
var stuck_teleport_cooldown: float = 0.0
var solo_arena_walls: Array[StaticBody2D] = []
var solo_boss_stage: int = 1
var solo_stage_flash_remaining: float = 0.0
var solo_low_hp_dash_combo: bool = false
var is_level3_arena_boss: bool = false
var level3_boss_hud: CanvasLayer = null
var level3_boss_hud_bar: ProgressBar = null
var level3_boss_hud_status: Label = null
var level3_fog: Node2D = null
var level3_fog_dash_pulse_timer: float = 0.0
var level3_fog_dash_started_this_strike: bool = false
# The orange middle dash is very fast: collect its *actual authored sword*
# path before move_and_slide(), then sweep that shape over the traveled gap.
var _orange_dash_sweep_start: Transform2D = Transform2D.IDENTITY
var _orange_dash_sweep_valid: bool = false
var solo_arena_platform_nodes: Array[StaticBody2D] = []
var solo_platform_camp_target: StaticBody2D = null
var solo_platform_camp_elapsed: float = 0.0
var solo_platform_break_target: StaticBody2D = null
var solo_platform_break_remaining: float = 0.0
var solo_platform_punish_pending: bool = false
var solo_platform_punish_elapsed: float = 0.0
var solo_warning_slash: Slash = Slash.FRONT
var solo_warning_step_remaining: float = 0.0
var solo_warning_step_direction: float = 0.0
var solo_combo_jump_followup: bool = false
var solo_air_downswing_active: bool = false
var solo_attack: SoloAttack = SoloAttack.NONE
var solo_attack_recovery: float = 0.0
var solo_heal_countdown: float = 20.0
var solo_heal_damage_seen: bool = false
var solo_heal_wisp: Area2D = null
var solo_heal_visual_texture: Texture2D = null
var _last_judge_slam_active: bool = false
var _last_judge_slam_stage: int = 0 # 0 ascend, 1 hover, 2 plunge
var _last_judge_slam_hover_elapsed: float = 0.0
var _last_judge_slam_total_elapsed: float = 0.0
var _last_judge_slam_left_floor: bool = false
var _last_judge_hazard_cd: float = 0.0

func _is_level3_arena_boss() -> bool:
	if bool(get_meta(&"king_necromancer_summon", false)):
		return false
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root) or not scene_root.is_ancestor_of(self):
		scene_root = self
		while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
			scene_root = scene_root.get_parent()
	var scene_name: String = scene_root.scene_file_path.get_file().get_basename().to_lower().replace("_", "")
	if scene_name.is_empty():
		scene_name = String(scene_root.name).to_lower().replace("_", "")
	if scene_name != "level3":
		return false
	var left_marker: Node2D = scene_root.find_child("bossclosearena", true, false) as Node2D
	var right_marker: Node2D = scene_root.find_child("bossclosearena2", true, false) as Node2D
	if not is_instance_valid(left_marker) or not is_instance_valid(right_marker):
		return false
	var min_x: float = minf(left_marker.global_position.x, right_marker.global_position.x)
	var max_x: float = maxf(left_marker.global_position.x, right_marker.global_position.x)
	if global_position.x < min_x - 150.0 or global_position.x > max_x + 150.0:
		return false
	if scene_root.has_meta(&"tdc_level3_menacing_boss_id"):
		var claimed_id: int = int(scene_root.get_meta(&"tdc_level3_menacing_boss_id"))
		if claimed_id != get_instance_id():
			return false
	scene_root.set_meta(&"tdc_level3_menacing_boss_id", get_instance_id())
	return true

func _spawn_level3_fog() -> void:
	# Reuse the V39 boss-only detection: never add fog to summons/other levels.
	if not is_level3_arena_boss or not level3_fog_enabled or mode == Mode.DEAD:
		return
	if is_instance_valid(level3_fog):
		return
	if not ResourceLoader.exists(level3_fog_script_path):
		push_warning("Level 3 Menacing Skeleton fog script missing: " + level3_fog_script_path)
		return
	var fog_source: Script = load(level3_fog_script_path) as Script
	if fog_source == null:
		push_warning("Could not load Level 3 fog script: " + level3_fog_script_path)
		return
	var instance: Node = fog_source.new() as Node
	if not (instance is Node2D):
		push_warning("The Level 3 fog script must extend Node2D for world-space fog.")
		if is_instance_valid(instance):
			instance.free()
		return
	var root: Node = get_tree().current_scene
	if not is_instance_valid(root):
		instance.free()
		return
	level3_fog = instance as Node2D
	level3_fog.name = "MenacingLevel3ArenaFog"
	root.add_child(level3_fog)
	# Real level coordinates, based on V39's existing arena markers.
	var a: Node2D = root.find_child("bossclosearena", true, false) as Node2D
	var b: Node2D = root.find_child("bossclosearena2", true, false) as Node2D
	var left_x: float = global_position.x - 450.0
	var right_x: float = global_position.x + 450.0
	if is_instance_valid(a) and is_instance_valid(b):
		left_x = minf(a.global_position.x, b.global_position.x)
		right_x = maxf(a.global_position.x, b.global_position.x)
	level3_fog.call("configure_arena", left_x, right_x, self, solid_terrain_mask)
	level3_fog.call("activate")


func _pulse_level3_fog(power: float = 1.0) -> void:
	if not is_level3_arena_boss or not level3_fog_enabled:
		return
	if not is_instance_valid(level3_fog):
		# Fog may have been disabled at startup for testing.
		_spawn_level3_fog()
	if is_instance_valid(level3_fog):
		level3_fog.call("disturb_at", global_position, maxf(0.0, power))


func _level3_fog_is_real_dash(target_combo_index: int = -1) -> bool:
	# Only authored full dashes, never the non-dashing sword swings.
	var index: int = combo_index if target_combo_index < 0 else target_combo_index
	if not is_level3_arena_boss or index < 0:
		return false
	match solo_attack:
		SoloAttack.RED:
			return index < 2
		SoloAttack.YELLOW, SoloAttack.FOUNTAIN_DASH:
			return index == 0
		SoloAttack.ORANGE:
			return index == 1
		SoloAttack.PLATFORM_PUNISH:
			return true
		_:
			return false


func _warn_level3_fog_before_dash(duration: float, target_combo_index: int = -1) -> void:
	# Normal: begin the sweep when the dash's WARNING starts.
	# Orange middle dash: forecast it while the preceding slash is playing.
	# The fog knows which combo index it is waiting for and does not
	# interpret the preceding slash as the dash itself.
	if not is_level3_arena_boss or not level3_fog_enabled:
		return
	var index: int = combo_index if target_combo_index < 0 else target_combo_index
	if not _level3_fog_is_real_dash(index):
		return
	if mode != Mode.WARNING and not (mode == Mode.STRIKE and index == combo_index + 1):
		return
	if not is_instance_valid(level3_fog):
		_spawn_level3_fog()
	if is_instance_valid(level3_fog):
		level3_fog.call("warn_before_dash", maxf(0.1, duration),
			1.0 if facing_right else -1.0, index)


func _notify_level3_fog_dash_started() -> void:
	if not is_level3_arena_boss or not level3_fog_enabled:
		return
	if is_instance_valid(level3_fog):
		level3_fog.call("dash_started", global_position, dash_direction)


func _cleanup_level3_fog() -> void:
	if is_instance_valid(level3_fog) and not level3_fog.is_queued_for_deletion():
		level3_fog.queue_free()
	level3_fog = null


func _ready() -> void:
	royal_original_collision_layer = collision_layer
	royal_original_collision_mask = collision_mask
	is_level3_arena_boss = _is_level3_arena_boss()
	if is_level3_arena_boss:
		max_hp = 270
		pursuit_speed *= 1.08
		attack_interval *= 0.90
		endlag *= 0.90
		jump_slam_chance = minf(0.42, jump_slam_chance + 0.07)
		close_lunge_chance = minf(0.35, close_lunge_chance + 0.05)
	hp = maxi(1, max_hp)
	royal_guard_index = int(get_meta(&"king_guard_index", -1))
	tactical_side = -1.0 if royal_guard_index == 0 else 1.0
	if royal_guard_index < 0:
		tactical_side = -1.0 if randf() < 0.5 else 1.0
	tactical_timer = randf_range(0.25, 1.0) + maxf(0.0, float(royal_guard_index)) * 0.55
	tactical_choice = 0 if royal_guard_index != 1 else 3
	starting_position = global_position
	stuck_anchor_x = global_position.x
	add_to_group(&"inimigo")
	add_to_group(&"enemy")
	add_to_group(&"menacing_skeleton")
	# Physical bodies should pass through other Menacing Skeletons, NOT the floor.
	# Prevent one guard from being treated as another guard's platform.
	_ignore_other_menacing_bodies()
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
	if is_level3_arena_boss and level3_fog_enabled and level3_fog_start_immediately:
		# Deferred so the level has finished initializing its camera and terrain.
		call_deferred("_spawn_level3_fog")

func _physics_process(delta: float) -> void:
	if mode == Mode.DEAD:
		if royal_reviving_stage > 0:
			_update_royal_resurrection(delta)
		elif bool(get_meta(&"king_necromancer_summon", false)) and not is_on_floor():
			# A slain royal guard settles onto its platform as a persistent corpse.
			velocity.x = 0.0
			velocity.y = minf(maximum_fall_speed, velocity.y + gravity * delta)
			move_and_slide()
		return
	_find_player()
	_ensure_player_pass_through()
	_solo_combat_clock += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	evade_cd = maxf(0.0, evade_cd - delta)
	stun_cd = maxf(0.0, stun_cd - delta)
	obstacle_jump_cd = maxf(0.0, obstacle_jump_cd - delta)
	stuck_teleport_cooldown = maxf(0.0, stuck_teleport_cooldown - delta)
	_update_solo_healing_wisp(delta)
	damage_white_flash = maxf(0.0, damage_white_flash - delta)
	solo_stage_flash_remaining = maxf(0.0, solo_stage_flash_remaining - delta)
	if _is_desperate() and not low_hp_phase_seen:
		low_hp_phase_seen = true
		attacks_since_fatigue = 0
		fatigue_threshold = _roll_fatigue_threshold()
		if mode == Mode.EXHAUSTED:
			fatigue_remaining = minf(fatigue_remaining, desperation_fatigue_max_seconds)
	if _last_judge_slam_active and _last_judge_slam_stage == 1:
		velocity.y = 0.0 # True zero-gravity hover, until 300 ms finishes.
	elif not is_on_floor():
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
			if _last_judge_slam_active:
				_update_last_judge_fog_slam(delta)
			else:
				_update_jump_slam(delta)
		Mode.EVADE:
			_update_evade(delta)
		Mode.OBSTACLE_JUMP:
			_update_obstacle_jump(delta)
		_:
			velocity.x = 0.0
	# Save the sword's world transform at the start of the movement step.
	# This lets the orange middle dash hit even when it crosses the player
	# between successive physics ticks at 2150 px/s.
	_orange_dash_sweep_valid = (is_level3_arena_boss and mode == Mode.STRIKE
		and solo_attack == SoloAttack.ORANGE and combo_index == 1
		and strike_dash_distance > 0.0 and is_instance_valid(front_hitbox))
	if _orange_dash_sweep_valid:
		_orange_dash_sweep_start = front_hitbox.global_transform
	move_and_slide()
	_update_solo_platform_trap(delta)
	_update_stuck_teleport(delta)
	_last_judge_hazard_cd = maxf(0.0, _last_judge_hazard_cd - delta)
	if (is_level3_arena_boss and engaged and _last_judge_hazard_cd <= 0.0
		and is_instance_valid(target) and is_instance_valid(level3_fog)
		and level3_fog.has_method("is_fog_fire_hazard_at")
		and bool(level3_fog.call("is_fog_fire_hazard_at", target.global_position))):
		_last_judge_hazard_cd = last_judge_hazard_damage_interval
		_apply_player_hit()
	# Short fog wakes following each Level 3 dash, independent of HP stage.
	if is_level3_arena_boss and level3_fog_enabled and mode == Mode.STRIKE and absf(velocity.x) > 250.0:
		level3_fog_dash_pulse_timer -= delta
		if level3_fog_dash_pulse_timer <= 0.0:
			level3_fog_dash_pulse_timer = maxf(0.04, level3_fog_dash_pulse_interval)
			_pulse_level3_fog(level3_fog_dash_disturbance)
	else:
		level3_fog_dash_pulse_timer = 0.0
	if mode == Mode.STRIKE:
		_check_strike_hit_window()
	# Preserve attack warning coloration, with a short white hit flash on damage.
	if is_level3_arena_boss and solo_stage_flash_remaining > 0.0:
		var pulse: float = 0.47 + 0.18 * sin(solo_stage_flash_remaining * 19.0)
		sprite.self_modulate = original_sprite_color.lerp(Color(0.71, 0.49, 0.92), pulse)
	elif damage_white_flash > 0.0:
		sprite.self_modulate = Color.WHITE
	elif mode == Mode.WARNING or (is_level3_arena_boss and mode == Mode.JUMP_SLAM):
		sprite.self_modulate = _solo_pattern_color() if is_level3_arena_boss else attack_warning_color
	elif mode not in [Mode.EXHAUSTED, Mode.STUNNED]:
		sprite.self_modulate = original_sprite_color
	# Always repaint once after mode changes. Otherwise the LAST WARNING
	# arc is cached and stays on screen throughout the next attack.
	queue_redraw()

func _update_stuck_teleport(delta: float) -> void:
	# Count only genuine navigation stalls. Standing still to telegraph,
	# attack, recover, evade or play the resurrection is intentional.
	if not engaged or not is_instance_valid(target) or mode not in [Mode.CHASE, Mode.OBSTACLE_JUMP]:
		stuck_timer = 0.0
		stuck_anchor_x = global_position.x
		return
	if stuck_teleport_cooldown > 0.0:
		stuck_timer = 0.0
		stuck_anchor_x = global_position.x
		return
	var horizontal_gap: float = absf(target.global_position.x - global_position.x)
	if horizontal_gap < stuck_teleport_min_player_distance:
		stuck_timer = 0.0
		stuck_anchor_x = global_position.x
		return
	# If the enemy has actually advanced, start a fresh 1-second window.
	if absf(global_position.x - stuck_anchor_x) >= stuck_teleport_min_progress:
		stuck_timer = 0.0
		stuck_anchor_x = global_position.x
		return
	stuck_timer += delta
	if stuck_timer < stuck_teleport_after_seconds:
		return
	stuck_timer = 0.0
	stuck_anchor_x = global_position.x
	# Delay the next attempt even if no suitable platform can be found.
	stuck_teleport_cooldown = stuck_teleport_retry_cooldown
	_try_safe_stuck_teleport()


func _try_safe_stuck_teleport() -> void:
	if not is_instance_valid(target) or body_shape.shape == null:
		return
	# Avoid teleporting onto the player or onto a second Menacing.
	# The order is reversed for guard #2 to discourage synchronized TPs.
	var offsets: Array[float] = [150.0, -150.0, 215.0, -215.0, 280.0, -280.0]
	if royal_guard_index == 1:
		offsets.reverse()
	var half_height: float = _body_half_size().y
	var shape_offset_y: float = body_shape.global_position.y - global_position.y
	var ray_top_y: float = target.global_position.y - 140.0
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for offset_x: float in offsets:
		var sample_x: float = target.global_position.x + offset_x
		var floor_hit: Dictionary = _terrain_hit(
			Vector2(sample_x, ray_top_y),
			Vector2(sample_x, target.global_position.y + 240.0)
		)
		if floor_hit.is_empty():
			continue
		var normal: Vector2 = floor_hit.get("normal", Vector2.UP)
		if normal.y > -0.60:
			continue
		var floor_point: Vector2 = floor_hit["position"]
		if absf(floor_point.y - target.global_position.y) > 195.0:
			continue
		var candidate: Vector2 = Vector2(
			sample_x,
			floor_point.y - half_height - shape_offset_y - 3.0
		)
		if candidate.distance_to(global_position) < 65.0:
			continue
		if candidate.distance_to(target.global_position) < 95.0:
			continue
		var colliding_guard: bool = false
		for node in get_tree().get_nodes_in_group(&"menacing_skeleton"):
			if node != self and is_instance_valid(node) and node is Node2D:
				if candidate.distance_to((node as Node2D).global_position) < 85.0:
					colliding_guard = true
					break
		if colliding_guard:
			continue
		# Reuse this enemy's REAL physics shape and terrain collision mask.
		var check: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		check.shape = body_shape.shape
		var at_candidate: Transform2D = body_shape.global_transform
		at_candidate.origin += candidate - global_position
		check.transform = at_candidate
		check.collision_mask = solid_terrain_mask
		check.exclude = [get_rid()]
		if not space.intersect_shape(check, 1).is_empty():
			continue
		global_position = candidate
		velocity = Vector2.ZERO
		mode = Mode.CHASE
		attack_cd = maxf(attack_cd, 0.35) # Brief reaction grace after teleport.
		obstacle_jump_time = 0.0
		obstacle_jump_cd = 0.30
		stuck_anchor_x = global_position.x
		reset_physics_interpolation()
		_face_player()
		_set_animation(animation_idle)
		return


func _ignore_other_menacing_bodies() -> void:
	# Godot collision exceptions are reciprocal, and also work when both
	# skeletons are on the same collision layer as the TileMap.
	# Do not remove their CollisionShape2D: sword/parry hit-testing needs it.
	for node in get_tree().get_nodes_in_group(&"menacing_skeleton"):
		if node == self or not is_instance_valid(node) or not node is PhysicsBody2D:
			continue
		var other: PhysicsBody2D = node as PhysicsBody2D
		add_collision_exception_with(other)
		other.add_collision_exception_with(self)


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
	return GerenciadorArtefatos.quantidade_coletada()

func _begin_fight() -> void:
	engaged = true
	mode = Mode.CHASE
	if is_level3_arena_boss:
		if level3_fog_enabled and not is_instance_valid(level3_fog):
			call_deferred("_spawn_level3_fog")
		solo_heal_damage_seen = false
		solo_heal_countdown = solo_heal_interval_seconds
		if solo_arena_barriers:
			call_deferred("_spawn_solo_arena_barriers")
		if solo_arena_platforms_enabled:
			call_deferred("_spawn_solo_arena_platforms")
		call_deferred("_create_level3_boss_hud")
	attack_cd = 0.60 + (0.70 * float(royal_guard_index) if royal_guard_index >= 0 else randf_range(0.0, 0.25))
	# King's summons are elite guards, not independent artifact minibosses.
	# Their attacks/parry behavior stays intact without changing Kris's buffs.
	if not bool(get_meta(&"king_necromancer_summon", false)):
		if is_instance_valid(target) and target.has_method(&"begin_menacing_skeleton_fight"):
			target.call(
				&"begin_menacing_skeleton_fight",
				_get_collected_artifacts()
			)
	fight_started.emit()

func _choose_tactical_action() -> void:
	# Each enemy rolls independently. The two King's guards favour distinct
	# rhythms: the first tends to engage, the second to flank/reposition.
	tactical_timer = randf_range(tactical_decision_min, tactical_decision_max)
	var roll: float = randf()
	var retreat_probability: float = tactical_retreat_chance
	if royal_guard_index == 1:
		retreat_probability += 0.15
	elif royal_guard_index == 0:
		retreat_probability -= 0.13
	if roll < retreat_probability:
		tactical_choice = 1
	elif roll < retreat_probability + tactical_walk_pause_chance:
		tactical_choice = 2
	elif roll < retreat_probability + tactical_walk_pause_chance + 0.24:
		tactical_choice = 3
		tactical_side *= -1.0
	else:
		tactical_choice = 0


func _play_tactical_walk(backpedaling: bool) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_walk):
		_set_animation(animation_idle)
		return
	if sprite.animation != animation_walk or not sprite.is_playing() or walk_playing_backwards != backpedaling:
		walk_playing_backwards = backpedaling
		if backpedaling:
			# Reverse the walk animation, NOT the facing direction.
			sprite.play_backwards(animation_walk)
		else:
			sprite.play(animation_walk, 1.0)


func _update_chase(delta: float) -> void:
	if not is_instance_valid(target):
		velocity.x = 0.0
		_set_animation(animation_idle)
		return
	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y - global_position.y
	_face_player()
	var direction: float = signf(dx)
	var gap: float = absf(dx)
	var grounded: bool = is_on_floor()
	tactical_timer -= delta
	if tactical_timer <= 0.0:
		_choose_tactical_action()

	var move_direction: float = 0.0
	var retreating: bool = false
	# Keep chasing if far away; use independently chosen near-range
	# approaches, backsteps and brief holds to break mirrored behaviour.
	if gap > tactical_max_range:
		move_direction = direction
	elif gap < tactical_min_range and tactical_choice == 1:
		move_direction = -direction
		retreating = true
	elif gap < tactical_min_range * 0.65 and tactical_choice != 2:
		move_direction = -direction if tactical_choice == 3 else direction
		retreating = move_direction != direction
	elif tactical_choice == 1:
		move_direction = -direction
		retreating = true
	elif tactical_choice == 3:
		# Brief flank/feint: the direction changes with each decision.
		move_direction = tactical_side
		retreating = move_direction != direction
	elif tactical_choice == 0 and gap > melee_reach * 0.65:
		move_direction = direction

	if _solo_reposition_remaining > 0.0:
		_solo_reposition_remaining = maxf(0.0, _solo_reposition_remaining - delta)
		move_direction = direction if gap > tactical_max_range else -direction
		if is_zero_approx(move_direction):
			move_direction = tactical_side
		if grounded and not _has_ground_ahead(move_direction):
			move_direction = -move_direction
		retreating = move_direction != direction

	velocity.x = 0.0
	if absf(move_direction) > 0.5:
		if grounded and not retreating and _try_start_obstacle_jump(move_direction):
			return
		if not grounded or _has_ground_ahead(move_direction):
			var move_speed: float = pursuit_speed * (desperation_walk_multiplier if _is_desperate() else 1.0)
			if retreating:
				move_speed *= tactical_backpedal_multiplier
			velocity.x = move_direction * move_speed
	if absf(velocity.x) > 0.1:
		_play_tactical_walk(retreating)
	else:
		_set_animation(animation_idle)

	if attack_cd > 0.0 or not grounded or absf(dy) > unreachable_vertical_gap:
		return
	var strike_range: float = maxf(dash_attack_distance, _solo_arena_width() * 0.94) if is_level3_arena_boss else dash_attack_distance
	if gap <= strike_range and _warning_visible_at(global_position):
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
	# Only actual terrain should count as a ledge or obstacle. In particular,
	# another Menacing must NOT trigger obstacle-jumps or false ground checks.
	var exclude_bodies: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group(&"menacing_skeleton"):
		if node != self and is_instance_valid(node) and node is CollisionObject2D:
			exclude_bodies.append((node as CollisionObject2D).get_rid())
	if target is CollisionObject2D and is_instance_valid(target):
		exclude_bodies.append((target as CollisionObject2D).get_rid())
	query.exclude = exclude_bodies
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


func _solo_pattern_color() -> Color:
	match solo_attack:
		SoloAttack.RED:
			return solo_red_warning_color
		SoloAttack.ORANGE:
			return solo_orange_warning_color
		SoloAttack.YELLOW, SoloAttack.FOUNTAIN_DASH:
			return solo_yellow_warning_color
		SoloAttack.GREEN:
			return solo_green_warning_color
		SoloAttack.PURPLE:
			return solo_purple_warning_color
		SoloAttack.PLATFORM_PUNISH:
			return Color(0.96, 0.22, 0.91)
		_:
			return original_sprite_color


func _solo_stage_warning_floor(pattern: SoloAttack) -> float:
	if solo_boss_stage == 1:
		match pattern:
			SoloAttack.RED:
				return 1.50
			SoloAttack.ORANGE:
				return 1.28
			SoloAttack.YELLOW, SoloAttack.FOUNTAIN_DASH:
				return 1.28
			SoloAttack.GREEN:
				return 0.82
			SoloAttack.PURPLE:
				return 1.30
	elif solo_boss_stage == 2:
		match pattern:
			SoloAttack.RED:
				return 1.23
			SoloAttack.ORANGE:
				return 1.05
			SoloAttack.YELLOW, SoloAttack.FOUNTAIN_DASH:
				return 1.06
			SoloAttack.GREEN:
				return 0.66
			SoloAttack.PURPLE:
				return 1.06
	else:
		match pattern:
			SoloAttack.RED:
				return 1.02
			SoloAttack.ORANGE:
				return 0.85
			SoloAttack.YELLOW, SoloAttack.FOUNTAIN_DASH:
				return 0.87
			SoloAttack.GREEN:
				return 0.52
			SoloAttack.PURPLE:
				return 0.90
	return 0.0


func _solo_swing_time_multiplier() -> float:
	match solo_boss_stage:
		1:
			return 1.65
		2:
			return 1.30
		_:
			return 1.0


func _solo_followup_warning_seconds() -> float:
	match solo_boss_stage:
		1:
			return maxf(0.42, solo_combo_followup_warning)
		2:
			return maxf(0.32, solo_combo_followup_warning)
		_:
			return maxf(0.22, solo_combo_followup_warning)


func _solo_arena_width() -> float:
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		var a: Node2D = scene_root.find_child("bossclosearena", true, false) as Node2D
		var b: Node2D = scene_root.find_child("bossclosearena2", true, false) as Node2D
		if is_instance_valid(a) and is_instance_valid(b):
			return maxf(300.0, absf(a.global_position.x - b.global_position.x))
	return solo_full_dash_fallback_distance


func _start_last_judge_fog_slam() -> void:
	# Jump with the FIRST frame of downswing, hover 300 ms at the apex,
	# then descend. The gray/fire waves are fired on real floor contact.
	solo_attack = SoloAttack.FOG_SLAM
	combo_order.assign([Slash.DOWN])
	combo_index = 0
	solo_attack_recovery = 1.10
	jump_slam = true
	solo_air_downswing_active = false
	_last_judge_slam_active = true
	_last_judge_slam_stage = 0
	_last_judge_slam_hover_elapsed = 0.0
	_last_judge_slam_total_elapsed = 0.0
	_last_judge_slam_left_floor = false
	attack_hit_done = false
	velocity = Vector2(0.0, -absf(last_judge_slam_jump_speed))
	mode = Mode.JUMP_SLAM
	_pose_attack(Slash.DOWN)
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)
	sprite.self_modulate = original_sprite_color


func _update_last_judge_fog_slam(delta: float) -> void:
	_last_judge_slam_total_elapsed += delta
	velocity.x = 0.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_down):
		if sprite.animation != animation_down:
			_pose_attack(Slash.DOWN)
		sprite.pause()
		sprite.set_frame_and_progress(0, 0.0)
	if not is_on_floor():
		_last_judge_slam_left_floor = true
	if _last_judge_slam_stage == 0:
		# Wait for the apex (or a ceiling) before the motionless hover.
		if _last_judge_slam_left_floor and (velocity.y >= -25.0 or is_on_ceiling()):
			_last_judge_slam_stage = 1
			velocity.y = 0.0
	elif _last_judge_slam_stage == 1:
		velocity.y = 0.0
		_last_judge_slam_hover_elapsed += delta
		if _last_judge_slam_hover_elapsed >= last_judge_slam_hover_seconds:
			_last_judge_slam_stage = 2
			velocity.y = last_judge_slam_descent_speed
	else:
		velocity.y = maxf(velocity.y, last_judge_slam_descent_speed)
		if is_on_floor() and _last_judge_slam_left_floor:
			_last_judge_slam_active = false
			velocity = Vector2.ZERO
			if is_instance_valid(level3_fog) and level3_fog.has_method("start_ground_slam_waves"):
				level3_fog.call("start_ground_slam_waves", global_position)
			_pulse_level3_fog(1.6)
			_begin_strike(Slash.DOWN)
			return
	if _last_judge_slam_total_elapsed > 4.0 or (not _last_judge_slam_left_floor and is_on_floor() and _last_judge_slam_stage == 2):
		_last_judge_slam_active = false
		_finish_attack_pattern()


func _solo_attack_is_ready(pattern: SoloAttack) -> bool:
	return _solo_combat_clock >= float(_solo_attack_ready_at.get(pattern, 0.0))


func _start_solo_attack_cooldown(pattern: SoloAttack) -> void:
	var delay: float = solo_attack_repeat_delay
	if pattern in [SoloAttack.FOG_SLAM, SoloAttack.FOUNTAIN_DASH, SoloAttack.PLATFORM_PUNISH]:
		delay = solo_special_repeat_delay
	_solo_attack_ready_at[pattern] = _solo_combat_clock + maxf(0.0, delay)


func _start_level3_color_attack() -> void:
	if not is_instance_valid(target):
		return
	combo_index = 0
	combo_pause_remaining = 0.0
	solo_low_hp_dash_combo = false
	solo_combo_jump_followup = false
	solo_air_downswing_active = false
	solo_warning_step_remaining = 0.0
	point_blank_attack = false
	lunge_attack = false
	advancing_slam = false
	jump_slam = false
	lunge_backstep_remaining = 0.0
	_face_player()
	committed_target_x = target.global_position.x
	var close: bool = _target_at_point_blank()
	# Level 3 specials. All existing attacks retain their weights
	# on rolls that do not select a new move. Override for testing in Inspector.
	var slam_ready: bool = is_on_floor() and _solo_attack_is_ready(SoloAttack.FOG_SLAM) and not test_move(global_transform, Vector2(0.0, -42.0))
	var fountain_ready: bool = is_on_floor() and _solo_attack_is_ready(SoloAttack.FOUNTAIN_DASH)
	if slam_ready:
		if last_judge_test_attack == 1 or (last_judge_test_attack == 0 and randf() < last_judge_fog_slam_chance):
			velocity.x = 0.0
			_start_solo_attack_cooldown(SoloAttack.FOG_SLAM)
			_start_last_judge_fog_slam()
			return
	if fountain_ready and (last_judge_test_attack == 2 or (last_judge_test_attack == 0 and randf() < last_judge_fountain_dash_chance)):
		solo_attack = SoloAttack.FOUNTAIN_DASH
	else:
		solo_attack = SoloAttack.NONE
	var special_fountain_selected: bool = solo_attack == SoloAttack.FOUNTAIN_DASH
	var roll: float = randf()
	# At low health, the high-mobility attacks happen more often.
	if absf(target.global_position.x - global_position.x) > dash_attack_distance:
		# At long range, choose a pattern that can actually reach the player.
		solo_attack = SoloAttack.RED if randf() < (0.35 if hp <= 100 else 0.18) else SoloAttack.YELLOW
	elif hp <= 100:
		if roll < 0.28:
			solo_attack = SoloAttack.RED
		elif roll < 0.51:
			solo_attack = SoloAttack.YELLOW
		elif roll < 0.73:
			solo_attack = SoloAttack.ORANGE
		elif roll < 0.82:
			solo_attack = SoloAttack.JUMP
		elif roll < 0.91:
			solo_attack = SoloAttack.PURPLE
		else:
			solo_attack = SoloAttack.GREEN if close else SoloAttack.PURPLE
	elif solo_boss_stage >= 2:
		if roll < 0.17:
			solo_attack = SoloAttack.RED
		elif roll < 0.36:
			solo_attack = SoloAttack.YELLOW
		elif roll < 0.61:
			solo_attack = SoloAttack.ORANGE
		elif roll < 0.76:
			solo_attack = SoloAttack.JUMP
		elif roll < 0.89:
			solo_attack = SoloAttack.PURPLE
		else:
			solo_attack = SoloAttack.GREEN if close else SoloAttack.ORANGE
	else:
		if roll < 0.08:
			solo_attack = SoloAttack.RED
		elif roll < 0.20:
			solo_attack = SoloAttack.YELLOW
		elif roll < 0.43:
			solo_attack = SoloAttack.ORANGE
		elif roll < 0.62:
			solo_attack = SoloAttack.JUMP
		elif roll < 0.78:
			solo_attack = SoloAttack.PURPLE
		else:
			solo_attack = SoloAttack.GREEN if close else SoloAttack.ORANGE

	if special_fountain_selected:
		solo_attack = SoloAttack.FOUNTAIN_DASH
	elif not _solo_attack_is_ready(solo_attack):
		var alternatives: Array[SoloAttack] = [SoloAttack.RED, SoloAttack.YELLOW]
		if absf(target.global_position.x - global_position.x) <= dash_attack_distance:
			alternatives.append_array([SoloAttack.ORANGE, SoloAttack.JUMP, SoloAttack.PURPLE])
			if close:
				alternatives.append(SoloAttack.GREEN)
		for i in range(alternatives.size() - 1, -1, -1):
			if not _solo_attack_is_ready(alternatives[i]):
				alternatives.remove_at(i)
		if alternatives.is_empty() and last_judge_test_attack == 0:
			if slam_ready:
				velocity.x = 0.0
				_start_solo_attack_cooldown(SoloAttack.FOG_SLAM)
				_start_last_judge_fog_slam()
				return
			if fountain_ready:
				alternatives.append(SoloAttack.FOUNTAIN_DASH)
		if alternatives.is_empty():
			solo_attack = SoloAttack.NONE
			_solo_reposition_remaining = 0.25
			attack_cd = 0.25
			return
		solo_attack = alternatives.pick_random()
	velocity.x = 0.0
	_start_solo_attack_cooldown(solo_attack)
	match solo_attack:
		SoloAttack.RED:
			combo_order.assign([Slash.FRONT, Slash.FRONT, Slash.SIDE, Slash.DOWN])
			solo_attack_recovery = 1.5
			warning_duration = solo_red_warning_seconds
		SoloAttack.ORANGE:
			combo_order.assign([Slash.SIDE, Slash.FRONT])
			if randf() < 0.45:
				combo_order.append(Slash.DOWN)
			solo_attack_recovery = 1.0
			warning_duration = solo_orange_warning_seconds
		SoloAttack.YELLOW:
			combo_order.assign([Slash.FRONT])
			solo_attack_recovery = 0.70
			warning_duration = solo_yellow_warning_seconds
		SoloAttack.FOUNTAIN_DASH:
			combo_order.assign([Slash.FRONT])
			solo_attack_recovery = 1.05
			warning_duration = maxf(solo_yellow_warning_seconds, 0.70)
		SoloAttack.GREEN:
			var green_slashes: Array[Slash] = [Slash.FRONT, Slash.SIDE, Slash.DOWN]
			combo_order.assign([green_slashes[randi_range(0, green_slashes.size() - 1)]])
			solo_attack_recovery = 0.60
			warning_duration = solo_green_warning_seconds
		SoloAttack.PURPLE:
			# Its first front slash is consistent; the final two vary.
			combo_order.assign([Slash.FRONT, Slash.SIDE, Slash.DOWN] if randf() < 0.5 else [Slash.FRONT, Slash.DOWN, Slash.SIDE])
			solo_attack_recovery = 1.0
			warning_duration = solo_purple_warning_seconds
		SoloAttack.JUMP:
			combo_order.assign([Slash.DOWN])
			solo_attack_recovery = 0.80
			committed_target_x = target.global_position.x
			jump_slam = true
			warning_frame_count = 0
			_start_jump_slam()
			velocity.y = -absf(jump_slam_launch_speed) * solo_long_jump_multiplier
			return
		_:
			return

	# Keep color tells readable even if an earlier Inspector value was saved.
	warning_duration = maxf(warning_duration, _solo_stage_warning_floor(solo_attack))
	if solo_attack not in [SoloAttack.RED, SoloAttack.ORANGE]:
		if solo_boss_stage == 1:
			solo_attack_recovery += 0.20
		elif solo_boss_stage == 2:
			solo_attack_recovery += 0.08
	# Every REAL dash gives the cloud ample time to advance before motion.
	# Orange's opening swing is not a dash, so its initial warning is unchanged.
	if _level3_fog_is_real_dash():
		warning_duration = maxf(warning_duration, level3_fog_min_dash_warning)
	mode = Mode.WARNING
	recovery_remaining = warning_duration
	warning_frame_count = 0
	# The tell is entirely color: no frozen sword frames or directional arrows.
	_set_animation(animation_idle)
	sprite.self_modulate = _solo_pattern_color()
	if _solo_pattern_dash_distance(combo_order[combo_index]) > 0.0:
		_warn_level3_fog_before_dash(warning_duration)


func _solo_pattern_dash_distance(slash: Slash) -> float:
	var width: float = _solo_arena_width()
	match solo_attack:
		SoloAttack.RED:
			if combo_index <= 1:
				return maxf(300.0, width * 0.76)
			return 66.0
		SoloAttack.ORANGE:
			if combo_index == 1:
				return maxf(170.0, width * 0.36)
			return 52.0 if combo_index == 2 else 0.0
		SoloAttack.YELLOW:
			return maxf(420.0, width * 0.91)
		SoloAttack.FOUNTAIN_DASH:
			return maxf(365.0, width * 0.74)
		SoloAttack.PURPLE:
			return 60.0 if combo_index > 0 else 30.0
		SoloAttack.PLATFORM_PUNISH:
			return maxf(340.0, width * 0.67)
		_:
			return 0.0


func _solo_safe_dash_distance(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var hit: KinematicCollision2D = KinematicCollision2D.new()
	if test_move(global_transform, Vector2(dash_direction * distance, 0.0), hit):
		return clampf(absf(hit.get_travel().x) - 4.0, 0.0, distance)
	return distance


func _start_attack_pattern() -> void:
	if is_level3_arena_boss:
		_start_level3_color_attack()
		return
	mode = Mode.WARNING
	combo_index = 0
	combo_pause_remaining = 0.0
	solo_low_hp_dash_combo = false
	solo_combo_jump_followup = false
	solo_air_downswing_active = false
	solo_warning_step_remaining = 0.0
	point_blank_attack = _target_at_point_blank()
	var gap := absf(target.global_position.x - global_position.x)
	jump_slam = gap <= jump_slam_range and randf() < jump_slam_chance and not test_move(global_transform, Vector2(0.0, -48.0))
	lunge_attack = not jump_slam and (not _target_in_melee_range() or (not point_blank_attack and randf() < close_lunge_chance))
	advancing_slam = not jump_slam and not lunge_attack and not point_blank_attack and randf() < advancing_slam_chance
	if _solo_low_hp_dash_unlocked() and not jump_slam:
		var late_dash_roll: float = randf()
		if late_dash_roll < 0.32:
			lunge_attack = true
			advancing_slam = false
			point_blank_attack = false
		elif late_dash_roll < 0.64:
			lunge_attack = false
			advancing_slam = true
			point_blank_attack = false
		elif late_dash_roll < 0.89:
			lunge_attack = false
			advancing_slam = false
			point_blank_attack = false
			solo_low_hp_dash_combo = true
	combo_order.assign([Slash.DOWN, Slash.SIDE, Slash.FRONT])
	if bool(get_meta(&"king_reborn_elite", false)) and not jump_slam and not lunge_attack and not advancing_slam and not point_blank_attack:
		# Purple resurrection earns five/six authored strikes, not faster
		# invisible hits. The windup for the opener remains visible.
		combo_order.append(Slash.SIDE)
		combo_order.append(Slash.DOWN)
		if randf() < 0.50:
			combo_order.append(Slash.FRONT)
	if not jump_slam and not point_blank_attack and not lunge_attack and not advancing_slam and randf() < alternate_combo_chance:
		var previous_length: int = combo_order.size()
		if randf() < 0.5:
			combo_order.assign([Slash.DOWN, Slash.FRONT, Slash.SIDE])
		else:
			combo_order.assign([Slash.SIDE, Slash.DOWN, Slash.FRONT])
		if bool(get_meta(&"king_reborn_elite", false)):
			combo_order.append(Slash.FRONT)
			if previous_length >= 5:
				combo_order.append(Slash.SIDE)
	# The Level 3 boss can choose sword chains whose second strike requires
	# another read. King's guards and ordinary skeletons keep their original AI.
	if is_level3_arena_boss and not solo_low_hp_dash_combo and randf() < 0.76:
		var chain: float = randf()
		jump_slam = false
		lunge_attack = false
		advancing_slam = false
		point_blank_attack = false
		if chain < 0.29:
			combo_order.assign([Slash.SIDE, Slash.DOWN])
			solo_combo_jump_followup = true
		elif chain < 0.57:
			combo_order.assign([Slash.SIDE, Slash.FRONT])
		elif chain < 0.83:
			combo_order.assign([Slash.DOWN])
			advancing_slam = true
		else:
			combo_order.assign([Slash.FRONT, Slash.SIDE, Slash.DOWN])
	if (is_level3_arena_boss and point_blank_attack and not jump_slam
		and combo_order[0] == Slash.DOWN):
		point_blank_attack = false
		advancing_slam = true

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
		sprite.self_modulate = attack_warning_color
	# Keep the original warning duration for the opening strike.
	warning_duration = maxf(0.75 if bool(get_meta(&"king_reborn_elite", false)) else 0.95, warning_duration)
	recovery_remaining = maxf(0.01, warning_duration)
	if is_level3_arena_boss:
		solo_warning_slash = Slash.DOWN if jump_slam else (Slash.FRONT if lunge_attack else combo_order[0])
		_prepare_solo_warning_movement(solo_warning_slash)
		sprite.self_modulate = _solo_warning_color(solo_warning_slash)
	if jump_slam and is_level3_arena_boss:
		_start_jump_slam()

func _solo_warning_color(slash: Slash) -> Color:
	match slash:
		Slash.SIDE:
			return solo_orange_warning_color
		Slash.DOWN:
			return solo_purple_warning_color
		_:
			return solo_yellow_warning_color

func _prepare_solo_warning_movement(_slash: Slash) -> void:
	solo_warning_step_remaining = 0.0
	solo_warning_step_direction = 0.0

func _start_solo_followup_warning() -> void:
	if not is_level3_arena_boss or combo_index >= combo_order.size():
		_finish_attack_pattern()
		return
	mode = Mode.WARNING
	_face_player()
	committed_target_x = target.global_position.x if is_instance_valid(target) else global_position.x
	if solo_attack == SoloAttack.PLATFORM_PUNISH:
		warning_duration = 0.33 if solo_boss_stage < 3 else 0.28
	else:
		warning_duration = _solo_followup_warning_seconds()
	# Follow-ups were as short as 0.16s: an entire arena sweep was never
	# visible before the following dash. Extend ONLY genuine dashes.
	if _level3_fog_is_real_dash():
		warning_duration = maxf(warning_duration, level3_fog_min_dash_warning)
	recovery_remaining = warning_duration
	warning_frame_count = 0
	_set_animation(animation_idle)
	sprite.self_modulate = _solo_pattern_color()
	if _solo_pattern_dash_distance(combo_order[combo_index]) > 0.0:
		_warn_level3_fog_before_dash(warning_duration)

func _start_solo_air_downswing() -> void:
	if not is_level3_arena_boss:
		_finish_attack_pattern()
		return
	jump_slam = true
	_start_jump_slam()
	velocity.y = -absf(jump_slam_launch_speed) * solo_long_jump_multiplier

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
		if is_level3_arena_boss and solo_warning_step_remaining > 0.0 and is_on_floor():
			var warning_step: float = minf(solo_warning_step_remaining, 115.0 * delta)
			if _has_ground_ahead(solo_warning_step_direction) and not test_move(
				global_transform, Vector2(solo_warning_step_direction * warning_step, 0.0)
			):
				velocity.x = solo_warning_step_direction * warning_step / maxf(0.001, delta)
				solo_warning_step_remaining -= warning_step
			else:
				solo_warning_step_remaining = 0.0
		if lunge_backstep_remaining > 0.0 and is_on_floor() and not is_on_wall():
			var step := minf(lunge_backstep_remaining, lunge_retreat_speed * delta)
			velocity.x = lunge_backstep_direction * step / delta
			lunge_backstep_remaining -= step
		if not is_level3_arena_boss and not lunge_attack and warning_frame_count > 0:
			var progress := 1.0 - recovery_remaining / maxf(0.01, warning_duration)
			_update_strike_frame(progress, 0, warning_frame_count)
		return
	if jump_slam:
		_start_jump_slam()
	else:
		_begin_strike(Slash.FRONT if lunge_attack else combo_order[combo_index])


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
	if is_level3_arena_boss:
		_pulse_level3_fog(level3_fog_swing_disturbance * 0.60)
	mode = Mode.JUMP_SLAM
	jump_slam_airborne = false
	jump_slam_elapsed = 0.0
	velocity = Vector2(0.0, -absf(jump_slam_launch_speed))
	if is_level3_arena_boss:
		sprite.self_modulate = original_sprite_color
		# Hold the first downswing frame throughout the entire flight.
		# The actual sword animation starts only after landing.
		_pose_attack(Slash.DOWN)
	elif warning_frame_count > 0:
		sprite.set_frame_and_progress(warning_frame_count - 1, 0.0)


func _update_jump_slam(delta: float) -> void:
	jump_slam_elapsed += delta
	if is_level3_arena_boss and is_instance_valid(sprite):
		# Stay in the anticipation pose until ground contact, including descent.
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_down):
			if sprite.animation != animation_down:
				_pose_attack(Slash.DOWN)
			elif sprite.frame != 0 or sprite.is_playing():
				sprite.pause()
				sprite.set_frame_and_progress(0, 0.0)
	elif solo_air_downswing_active and is_instance_valid(sprite) and sprite.sprite_frames != null:
		var prehit_frame: int = mini(
			_hit_frame(Slash.DOWN),
			sprite.sprite_frames.get_frame_count(sprite.animation) - 1
		)
		if prehit_frame > 0:
			_update_strike_frame(clampf(jump_slam_elapsed / 0.38, 0.0, 1.0), 0, prehit_frame + 1)
	if is_on_floor() and jump_slam_airborne:
		solo_air_downswing_active = false
		_begin_strike(Slash.DOWN)
		return
	if jump_slam_elapsed >= jump_timeout:
		_finish_attack_pattern()
		return
	if not is_on_floor():
		jump_slam_airborne = true
	var direction := 1.0 if facing_right else -1.0
	var gap := maxf(0.0, (committed_target_x - global_position.x) * direction)
	var drift_speed: float = solo_jump_air_drift_speed if is_level3_arena_boss else jump_slam_move_speed
	velocity.x = direction * minf(drift_speed, gap / maxf(delta, 0.0001))


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
	if solo_low_hp_dash_combo and combo_index > 0 and is_instance_valid(target):
		_face_player()
		committed_target_x = target.global_position.x
	active_slash = slash
	attack_hit_done = false
	strike_elapsed = 0.0
	strike_commit_remaining = 0.0
	level3_fog_dash_started_this_strike = false
	velocity.x = 0.0
	# All swings use the facing chosen when the windup began.
	dash_direction = 1.0 if facing_right else -1.0
	if not _pose_attack(slash):
		_finish_attack_pattern()
		return

	mode = Mode.STRIKE
	if is_level3_arena_boss:
		# All attacks (red/yellow/orange/green/purple/jump) disturb the fog.
		_pulse_level3_fog(level3_fog_swing_disturbance)
	sprite.self_modulate = original_sprite_color
	var close_swing := point_blank_attack
	strike_duration = maxf(0.06, point_blank_swing_seconds if close_swing else combo_swing_seconds)
	strike_dash_seconds = minf(strike_duration, combo_dash_seconds)
	strike_dash_distance = combo_dash_distance
	if solo_low_hp_dash_combo:
		strike_dash_distance = maxf(strike_dash_distance, 70.0)
	strike_first_frame = warning_frame_count if (combo_index == 0 or (is_level3_arena_boss and not jump_slam)) else 0
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
	if jump_slam or close_swing or (
		not lunge_attack
		and (not is_level3_arena_boss or (not advancing_slam and not solo_low_hp_dash_combo))
		and not (is_level3_arena_boss and slash == Slash.DOWN)
		and _target_at_point_blank()
	):
		strike_dash_distance = 0.0
	strike_first_frame = clampi(strike_first_frame, 0, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
	if is_level3_arena_boss and solo_attack != SoloAttack.NONE:
		# All color-combo dashes move during the authored attack animation.
		# Never cancel them merely because the player is close.
		strike_dash_distance = 0.0
		strike_dash_seconds = 0.0
		strike_commit_remaining = 0.0
		strike_first_frame = 0
		var planned_dash: float = _solo_pattern_dash_distance(slash)
		if planned_dash > 0.0 and is_on_floor():
			strike_dash_distance = _solo_safe_dash_distance(planned_dash)
			if solo_attack == SoloAttack.RED and combo_index < 2:
				strike_duration = maxf(0.25, strike_dash_distance / 1350.0)
			elif solo_attack == SoloAttack.YELLOW:
				strike_duration = maxf(0.18, strike_dash_distance / solo_level3_dash_speed)
			elif solo_attack == SoloAttack.ORANGE and combo_index == 1:
				strike_duration = maxf(0.19, strike_dash_distance / 1350.0)
			else:
				strike_duration = maxf(0.15, combo_swing_seconds)
		else:
			strike_duration = maxf(0.15, combo_swing_seconds)
		if solo_attack != SoloAttack.YELLOW:
			strike_duration *= _solo_swing_time_multiplier()
		# Only attacks that have no dash in their pattern get extra animation time.
		# Dash attacks keep their existing 2150 px/s speed and original duration.
		if planned_dash <= 0.0:
			strike_duration *= solo_ground_swing_slowdown
		if strike_dash_distance > 0.0:
			# All normal Level 3 color dashes still use their V38 speed.
			strike_dash_seconds = strike_dash_distance / maxf(1.0, solo_level3_dash_speed)
			strike_duration = maxf(strike_duration, strike_dash_seconds)
		if solo_attack == SoloAttack.PLATFORM_PUNISH:
			# The three retaliation dashes are fast, but always leave a visible gap.
			strike_dash_seconds = strike_dash_distance / maxf(1.0, solo_platform_revenge_dash_speed)
			strike_duration = maxf(0.23, strike_dash_seconds + 0.075)
	if close_swing and not jump_slam and combo_index == 0:
		strike_commit_remaining = maxf(0.0, point_blank_commit_seconds)
	var pose_frame := maxi(0, strike_first_frame - 1) if strike_commit_remaining > 0.0 else strike_first_frame
	sprite.set_frame_and_progress(pose_frame, 0.0)
	# Orange has a non-dashing opener followed by a genuine middle dash.
	# Start the fog WHILE that opener swings, not after it has already ended.
	# The later follow-up WARNING reuses this sweep without restarting it.
	if is_level3_arena_boss and solo_attack == SoloAttack.ORANGE and combo_index == 0 and combo_order.size() > 1:
		_warn_level3_fog_before_dash(strike_duration + maxf(
			level3_fog_min_dash_warning, _solo_followup_warning_seconds()
		), 1)
	# V44: the WARNING -> STRIKE transition is the definitive deadline for
	# the fog telegraph. Do not wait for velocity or the next physics tick;
	# otherwise the warning can remain dense WHILE the dash is happening.
	if is_level3_arena_boss and _level3_fog_is_real_dash():
		if solo_attack == SoloAttack.FOUNTAIN_DASH and is_instance_valid(level3_fog):
			level3_fog.call("arm_fountain_dash")
		level3_fog_dash_started_this_strike = true
		_notify_level3_fog_dash_started()


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
	# Fallback for unusual mid-strike transitions. Normally the fog already
	# disperses in _begin_strike(), before ANY dash animation/movement runs.
	if (is_level3_arena_boss and _level3_fog_is_real_dash()
		and not level3_fog_dash_started_this_strike and absf(velocity.x) > 75.0):
		level3_fog_dash_started_this_strike = true
		_notify_level3_fog_dash_started()
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
		# For orange's high-speed middle dash, damage is active over the real
		# travel, not only one sprite frame that can miss the player entirely.
		var orange_dash_traveling: bool = (is_level3_arena_boss
			and solo_attack == SoloAttack.ORANGE and combo_index == 1
			and active_slash == Slash.FRONT and strike_dash_distance > 0.0
			and strike_elapsed <= strike_dash_seconds + 0.02)
		if not orange_dash_traveling:
			var wanted := clampi(_hit_frame(active_slash), 0, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
			var extra: int = 0 if (is_level3_arena_boss and hp <= 100) else maxi(0, slash_active_extra_frames)
			if sprite.frame < wanted or sprite.frame > wanted + extra:
				return
	# The lunge can connect once along its committed path, through the sword shape.
	if _try_attack_hit():
		attack_hit_done = true


func _on_animation_finished() -> void:
	if mode == Mode.DEAD and death_animation_playing and sprite.animation == animation_death:
		death_animation_playing = false
		if bool(get_meta(&"king_necromancer_summon", false)):
			_finish_royal_corpse()
		else:
			queue_free()



func _update_solo_healing_wisp(delta: float) -> void:
	if not is_level3_arena_boss or not engaged or mode == Mode.DEAD:
		return
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var maximum: int = int(target.get("vida_maxima"))
	if maximum <= 0:
		return
	var current: int = int(Global.vida_atual)
	if current <= 0:
		return
	if current >= maximum:
		solo_heal_damage_seen = false
		solo_heal_countdown = solo_heal_interval_seconds
		return
	if not solo_heal_damage_seen:
		solo_heal_damage_seen = true
		solo_heal_countdown = solo_heal_interval_seconds
	if is_instance_valid(solo_heal_wisp):
		return
	solo_heal_countdown -= delta
	if solo_heal_countdown > 0.0:
		return
	if mode in [Mode.WARNING, Mode.STRIKE, Mode.JUMP_SLAM]:
		# Wait briefly for the current attack to finish before placing the pickup.
		solo_heal_countdown = 0.7
		return
	solo_heal_countdown = solo_heal_interval_seconds
	if randf() > solo_heal_spawn_chance:
		return
	var spawn_pos: Vector2 = _find_solo_heal_position()
	if not is_finite(spawn_pos.x) or not is_finite(spawn_pos.y):
		# Terrain placement failed; try again soon instead of losing the chance.
		solo_heal_countdown = 1.5
		return
	call_deferred("_spawn_solo_healing_wisp", spawn_pos)


func _find_solo_heal_position() -> Vector2:
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root) or not is_instance_valid(target):
		return Vector2(INF, INF)
	var arena_left: float = target.global_position.x - 330.0
	var arena_right: float = target.global_position.x + 330.0
	var marker_a: Node2D = scene_root.find_child("bossclosearena", true, false) as Node2D
	var marker_b: Node2D = scene_root.find_child("bossclosearena2", true, false) as Node2D
	if is_instance_valid(marker_a) and is_instance_valid(marker_b):
		arena_left = minf(marker_a.global_position.x, marker_b.global_position.x) + 115.0
		arena_right = maxf(marker_a.global_position.x, marker_b.global_position.x) - 115.0
	if arena_right <= arena_left:
		return Vector2(INF, INF)
	var camera: Camera2D = get_viewport().get_camera_2d()
	var camera_center_x: float = target.global_position.x
	var visible_half_width: float = INF
	if is_instance_valid(camera):
		camera_center_x = camera.get_screen_center_position().x
		visible_half_width = get_viewport_rect().size.x * 0.5 / maxf(absf(camera.zoom.x), 0.01)
	var offsets: Array[float] = [-185.0, 205.0, -245.0, 145.0, 265.0, -135.0]
	offsets.shuffle()
	for x_offset: float in offsets:
		var test_x: float = target.global_position.x + x_offset
		if test_x < arena_left or test_x > arena_right:
			continue
		if absf(test_x - camera_center_x) > visible_half_width - 45.0:
			continue
		if absf(test_x - global_position.x) < 105.0:
			continue
		var from_point: Vector2 = Vector2(test_x, target.global_position.y - 115.0)
		var to_point: Vector2 = Vector2(test_x, target.global_position.y + 205.0)
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			from_point, to_point, solid_terrain_mask, [get_rid()]
		)
		var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
		if not result.has("position"):
			continue
		var floor_y: float = (result["position"] as Vector2).y
		if absf(floor_y - target.global_position.y) > 160.0:
			continue
		var candidate: Vector2 = Vector2(test_x, floor_y - 36.0)
		var check_shape: CircleShape2D = CircleShape2D.new()
		check_shape.radius = 22.0
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = check_shape
		query.transform = Transform2D(0.0, candidate)
		query.collision_mask = solid_terrain_mask
		query.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		return candidate
	return Vector2(INF, INF)


func _solo_heal_texture() -> Texture2D:
	if solo_heal_visual_texture != null:
		return solo_heal_visual_texture
	var side: int = 24
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	for px: int in range(side):
		for py: int in range(side):
			var distance: float = Vector2(float(px) - 11.5, float(py) - 11.5).length()
			var inner: float = clampf(1.0 - distance / 5.0, 0.0, 1.0)
			var halo: float = pow(clampf(1.0 - distance / 12.0, 0.0, 1.0), 2.3)
			img.set_pixel(px, py, Color(0.96, 0.98, 1.0, maxf(inner, halo * 0.48)))
	solo_heal_visual_texture = ImageTexture.create_from_image(img)
	return solo_heal_visual_texture


func _spawn_solo_healing_wisp(world_pos: Vector2) -> void:
	if is_instance_valid(solo_heal_wisp) or not is_level3_arena_boss:
		return
	var root: Node = get_tree().current_scene
	if not is_instance_valid(root) or not is_instance_valid(target):
		return
	var pickup: Area2D = Area2D.new()
	pickup.name = "MenacingHealingWisp"
	pickup.collision_layer = 0
	pickup.collision_mask = (target as CollisionObject2D).collision_layer if target is CollisionObject2D else 1
	pickup.monitoring = true
	pickup.monitorable = false
	root.add_child(pickup)
	pickup.global_position = world_pos

	var hitbox: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 24.0
	hitbox.shape = circle
	pickup.add_child(hitbox)

	var core: Sprite2D = Sprite2D.new()
	core.name = "WhiteCore"
	core.texture = _solo_heal_texture()
	core.scale = Vector2.ONE * 1.7
	core.modulate = Color(1.0, 1.0, 1.0, 0.96)
	core.z_index = 85
	pickup.add_child(core)

	var fragments: CPUParticles2D = CPUParticles2D.new()
	fragments.name = "WhiteSparks"
	fragments.texture = _solo_heal_texture()
	fragments.amount = 18
	fragments.lifetime = 1.1
	fragments.direction = Vector2.UP
	fragments.spread = 70.0
	fragments.gravity = Vector2.ZERO
	fragments.initial_velocity_min = 12.0
	fragments.initial_velocity_max = 26.0
	fragments.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fragments.emission_sphere_radius = 12.0
	fragments.scale_amount_min = 0.30
	fragments.scale_amount_max = 0.78
	fragments.z_index = 86
	pickup.add_child(fragments)
	fragments.emitting = true

	pickup.body_entered.connect(_on_solo_heal_wisp_collected.bind(pickup))
	solo_heal_wisp = pickup
	var float_anim: Tween = pickup.create_tween().set_loops()
	float_anim.tween_property(pickup, "global_position:y", world_pos.y - 5.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_anim.tween_property(pickup, "global_position:y", world_pos.y + 5.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(solo_heal_lifetime_seconds).timeout.connect(
		func() -> void:
			if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
				pickup.queue_free()
	)


func _on_solo_heal_wisp_collected(body: Node2D, pickup: Area2D) -> void:
	if not is_level3_arena_boss or not engaged or mode == Mode.DEAD:
		return
	if body != target or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
		return
	var maximum: int = int(target.get("vida_maxima"))
	if Global.vida_atual <= 0 or Global.vida_atual >= maximum:
		return
	Global.curar(1)
	target.set("vida", Global.vida_atual)
	if target.has_signal(&"vida_alterada"):
		target.emit_signal(&"vida_alterada", int(Global.vida_atual), maximum)
	pickup.queue_free()
	solo_heal_countdown = solo_heal_interval_seconds


func _remove_solo_healing_wisp() -> void:
	if is_instance_valid(solo_heal_wisp) and not solo_heal_wisp.is_queued_for_deletion():
		solo_heal_wisp.queue_free()
	solo_heal_wisp = null


func _spawn_solo_arena_barriers() -> void:
	if not engaged or mode == Mode.DEAD or not is_instance_valid(target):
		return
	if not solo_arena_walls.is_empty() or not is_level3_arena_boss:
		return
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return
	var left_x: float = minf(target.global_position.x, global_position.x) - solo_arena_fallback_padding
	var right_x: float = maxf(target.global_position.x, global_position.x) + solo_arena_fallback_padding
	var edge_a: Node2D = scene_root.find_child("bossclosearena", true, false) as Node2D
	var edge_b: Node2D = scene_root.find_child("bossclosearena2", true, false) as Node2D
	if is_instance_valid(edge_a) and is_instance_valid(edge_b):
		if absf(edge_a.global_position.x - edge_b.global_position.x) >= 220.0:
			left_x = minf(edge_a.global_position.x, edge_b.global_position.x)
			right_x = maxf(edge_a.global_position.x, edge_b.global_position.x)
			left_x = minf(left_x, minf(target.global_position.x, global_position.x) - 95.0)
			right_x = maxf(right_x, maxf(target.global_position.x, global_position.x) + 95.0)
	var wall_y: float = (target.global_position.y + global_position.y) * 0.5 - 60.0
	var player_body: CollisionObject2D = target as CollisionObject2D
	var wall_layer: int = 1
	if is_instance_valid(player_body) and player_body.collision_mask != 0:
		wall_layer = player_body.collision_mask
	_create_solo_arena_wall(scene_root, "MenacingArenaBarrierLeft", Vector2(left_x, wall_y), wall_layer)
	_create_solo_arena_wall(scene_root, "MenacingArenaBarrierRight", Vector2(right_x, wall_y), wall_layer)


func _create_solo_arena_wall(scene_root: Node, wall_name: String, position_world: Vector2, wall_layer: int) -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = wall_layer
	wall.collision_mask = 0
	wall.add_to_group("king_arena_seal")
	wall.add_to_group("menacing_arena_seal")

	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(112.0, 200000.0)
	collision.shape = rectangle
	wall.add_child(collision)

	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-56.0, -10000.0),
		Vector2(56.0, -10000.0),
		Vector2(56.0, 10000.0),
		Vector2(-56.0, 10000.0)
	])
	visual.color = Color(0.005, 0.006, 0.011, 0.77)
	visual.z_index = 35
	wall.add_child(visual)

	scene_root.add_child(wall)
	wall.global_position = position_world
	solo_arena_walls.append(wall)


func _remove_solo_arena_barriers() -> void:
	for wall: StaticBody2D in solo_arena_walls:
		if is_instance_valid(wall) and not wall.is_queued_for_deletion():
			wall.queue_free()
	solo_arena_walls.clear()


func _spawn_solo_arena_platforms() -> void:
	if not is_level3_arena_boss or not engaged or mode == Mode.DEAD:
		return
	if not solo_arena_platform_nodes.is_empty():
		return
	var root: Node = get_tree().current_scene
	if not is_instance_valid(root):
		return
	var a: Node2D = root.find_child("bossclosearena", true, false) as Node2D
	var b: Node2D = root.find_child("bossclosearena2", true, false) as Node2D
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var left: float = minf(a.global_position.x, b.global_position.x)
	var right: float = maxf(a.global_position.x, b.global_position.x)
	var span: float = right - left
	if span < 420.0:
		return
	var anchor_y: float = maxf(global_position.y, target.global_position.y)
	for preferred_ratio: float in [0.27, 0.73]:
		for adjustment: float in [0.0, -0.09, 0.09, -0.15, 0.15]:
			var x: float = lerpf(left, right, preferred_ratio + adjustment)
			if x < left + 110.0 or x > right - 110.0:
				continue
			if absf(x - global_position.x) < 92.0 or absf(x - target.global_position.x) < 92.0:
				continue
			var overlaps_another: bool = false
			for placed: StaticBody2D in solo_arena_platform_nodes:
				if is_instance_valid(placed) and absf(x - placed.global_position.x) < solo_platform_width + 45.0:
					overlaps_another = true
					break
			if overlaps_another:
				continue
			var floor_y: float = _solo_find_floor_y(x, anchor_y)
			if absf(floor_y - anchor_y) > 160.0:
				continue
			var platform_y: float = floor_y - maxf(88.0, solo_platform_height_above_ground)
			if not _solo_platform_space_free(x, platform_y):
				continue
			_create_solo_arena_platform(root, Vector2(x, platform_y))
			break


func _solo_find_floor_y(x: float, anchor_y: float) -> float:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(x, anchor_y - 8.0),
		Vector2(x, anchor_y + 780.0),
		solid_terrain_mask,
		[get_rid()]
	)
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if result.has("position"):
		return (result["position"] as Vector2).y
	return anchor_y + 35.0


func _solo_platform_space_free(x: float, y: float) -> bool:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(solo_platform_width + 8.0, solo_platform_thickness + 6.0)
	query.shape = shape
	query.transform = Transform2D(0.0, Vector2(x, y))
	query.collision_mask = solid_terrain_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _create_solo_arena_platform(root: Node, world_pos: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "MenacingArenaPlatform"
	body.collision_layer = solid_terrain_mask
	body.collision_mask = 0
	body.add_to_group("menacing_arena_platform")
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(solo_platform_width, solo_platform_thickness)
	collision.shape = shape
	body.add_child(collision)
	var fill: Polygon2D = Polygon2D.new()
	var half_width: float = solo_platform_width * 0.5
	var half_height: float = solo_platform_thickness * 0.5
	fill.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height), Vector2(half_width, -half_height),
		Vector2(half_width, half_height), Vector2(-half_width, half_height)
	])
	fill.color = Color(0.19, 0.17, 0.25, 0.95)
	fill.z_index = 2
	body.add_child(fill)
	var rim: Line2D = Line2D.new()
	rim.width = 3.0
	rim.default_color = Color(0.67, 0.49, 0.82, 0.95)
	rim.points = PackedVector2Array([Vector2(-half_width, -half_height), Vector2(half_width, -half_height)])
	body.add_child(rim)
	root.add_child(body)
	body.global_position = world_pos
	# The player can stand on and wall-cling to these, but the Skeleton cannot
	# collide with his own platforms or accidentally shorten a dash against one.
	add_collision_exception_with(body)
	body.add_collision_exception_with(self)
	solo_arena_platform_nodes.append(body)


func _solo_player_on_platform() -> StaticBody2D:
	if not is_instance_valid(target) or not (target is CharacterBody2D):
		return null
	var player: CharacterBody2D = target as CharacterBody2D
	if not player.is_on_floor():
		return null
	for platform: StaticBody2D in solo_arena_platform_nodes:
		if not is_instance_valid(platform) or platform.is_queued_for_deletion():
			continue
		var upper_edge: float = platform.global_position.y - solo_platform_thickness * 0.5
		if absf(player.global_position.x - platform.global_position.x) > solo_platform_width * 0.5 + 4.0:
			continue
		# Works whether the Player origin is at the feet or near the torso.
		if player.global_position.y > upper_edge + 8.0 or player.global_position.y < upper_edge - 125.0:
			continue
		return platform
	return null


func _update_solo_platform_trap(delta: float) -> void:
	if not is_level3_arena_boss or not engaged or mode == Mode.DEAD:
		return
	if is_instance_valid(solo_platform_break_target):
		solo_platform_break_remaining -= delta
		var flicker: float = 0.5 + 0.5 * sin(solo_platform_break_remaining * 35.0)
		solo_platform_break_target.modulate = Color(1.0, 0.30 + 0.47 * flicker, 0.42 + 0.42 * flicker, 1.0)
		if solo_platform_break_remaining <= 0.0:
			_shatter_solo_platform(solo_platform_break_target)
			solo_platform_break_target = null
			solo_platform_punish_pending = true
			solo_platform_punish_elapsed = 0.0
	elif not solo_platform_punish_pending:
		var occupied: StaticBody2D = _solo_player_on_platform()
		if is_instance_valid(occupied):
			if occupied != solo_platform_camp_target:
				solo_platform_camp_target = occupied
				solo_platform_camp_elapsed = 0.0
			solo_platform_camp_elapsed += delta
			if solo_platform_camp_elapsed >= solo_platform_camp_seconds:
				_begin_solo_platform_shatter(occupied)
		else:
			solo_platform_camp_elapsed = maxf(0.0, solo_platform_camp_elapsed - delta * 2.0)
			if solo_platform_camp_elapsed <= 0.0:
				solo_platform_camp_target = null
	if solo_platform_punish_pending:
		solo_platform_punish_elapsed += delta
		var grounded: bool = target is CharacterBody2D and (target as CharacterBody2D).is_on_floor()
		var recovered: bool = grounded and _solo_player_on_platform() == null and solo_platform_punish_elapsed >= 0.35
		if recovered or solo_platform_punish_elapsed >= 2.7:
			if is_on_floor() and mode in [Mode.CHASE, Mode.RECOVER, Mode.EXHAUSTED]:
				_start_solo_platform_revenge()


func _begin_solo_platform_shatter(platform: StaticBody2D) -> void:
	if not is_instance_valid(platform):
		return
	solo_platform_break_target = platform
	solo_platform_break_remaining = solo_platform_shatter_warning_seconds
	solo_platform_camp_elapsed = 0.0
	solo_platform_camp_target = null
	# The cracking platform is the warning. Stop the current attack so there
	# is no unrelated sword hit while the player is being dropped.
	mode = Mode.RECOVER
	solo_attack = SoloAttack.NONE
	combo_pause_remaining = 0.0
	combo_index = 0
	jump_slam = false
	lunge_attack = false
	point_blank_attack = false
	advancing_slam = false
	attack_hit_done = true
	velocity.x = 0.0
	recovery_remaining = solo_platform_shatter_warning_seconds + 0.55
	_set_animation(animation_idle)


func _shatter_solo_platform(platform: StaticBody2D) -> void:
	if not is_instance_valid(platform):
		return
	_pulse_level3_fog(maxf(level3_fog_swing_disturbance, 1.2))
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		var fragments: CPUParticles2D = CPUParticles2D.new()
		fragments.name = "MenacingPlatformFragments"
		fragments.emitting = false
		fragments.one_shot = true
		fragments.amount = 44
		fragments.lifetime = 0.75
		fragments.explosiveness = 1.0
		fragments.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fragments.emission_rect_extents = Vector2(solo_platform_width * 0.48, 5.0)
		fragments.direction = Vector2(0.0, -1.0)
		fragments.spread = 180.0
		fragments.initial_velocity_min = 105.0
		fragments.initial_velocity_max = 255.0
		fragments.gravity = Vector2(0.0, 300.0)
		fragments.color = Color(0.79, 0.55, 0.98, 1.0)
		scene_root.add_child(fragments)
		fragments.global_position = platform.global_position
		fragments.emitting = true
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(fragments):
				fragments.queue_free()
		)
	solo_arena_platform_nodes.erase(platform)
	platform.queue_free()


func _start_solo_platform_revenge() -> void:
	if not is_instance_valid(target) or not is_level3_arena_boss or mode == Mode.DEAD:
		return
	if mode == Mode.EXHAUSTED or attack_cd > 0.0 or not _solo_attack_is_ready(SoloAttack.PLATFORM_PUNISH):
		return
	solo_platform_punish_pending = false
	solo_platform_punish_elapsed = 0.0
	solo_attack = SoloAttack.PLATFORM_PUNISH
	_start_solo_attack_cooldown(solo_attack)
	solo_attack_recovery = 1.1
	combo_order.assign([Slash.FRONT, Slash.FRONT, Slash.FRONT])
	combo_index = 0
	combo_pause_remaining = 0.0
	jump_slam = false
	lunge_attack = false
	point_blank_attack = false
	advancing_slam = false
	solo_combo_jump_followup = false
	solo_low_hp_dash_combo = false
	strike_commit_remaining = 0.0
	solo_warning_step_remaining = 0.0
	velocity.x = 0.0
	_face_player()
	committed_target_x = target.global_position.x
	mode = Mode.WARNING
	warning_duration = maxf(
		0.72 if solo_boss_stage < 3 else 0.60,
		level3_fog_min_dash_warning
	)
	recovery_remaining = warning_duration
	warning_frame_count = 0
	_set_animation(animation_idle)
	sprite.self_modulate = _solo_pattern_color()
	_warn_level3_fog_before_dash(warning_duration)


func _remove_solo_arena_platforms() -> void:
	solo_platform_camp_target = null
	solo_platform_break_target = null
	solo_platform_camp_elapsed = 0.0
	solo_platform_break_remaining = 0.0
	solo_platform_punish_pending = false
	solo_platform_punish_elapsed = 0.0
	for platform: StaticBody2D in solo_arena_platform_nodes:
		if is_instance_valid(platform) and not platform.is_queued_for_deletion():
			platform.queue_free()
	solo_arena_platform_nodes.clear()


func _create_level3_boss_hud() -> void:
	if not is_level3_arena_boss or not engaged or mode == Mode.DEAD:
		return
	if is_instance_valid(level3_boss_hud):
		return
	level3_boss_hud = CanvasLayer.new()
	level3_boss_hud.name = "MenacingSkeletonBossHUD"
	level3_boss_hud.layer = 110
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return
	scene_root.add_child(level3_boss_hud)
	var frame: VBoxContainer = VBoxContainer.new()
	frame.name = "BossHeader"
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.offset_left = -246.0
	frame.offset_right = 246.0
	frame.offset_top = 16.0
	frame.offset_bottom = 94.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level3_boss_hud.add_child(frame)
	var title: Label = Label.new()
	title.text = "MENACING SKELETON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.92))
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.010, 0.023))
	title.add_theme_constant_override("outline_size", 4)
	frame.add_child(title)
	level3_boss_hud_bar = ProgressBar.new()
	level3_boss_hud_bar.name = "MenacingHP"
	level3_boss_hud_bar.custom_minimum_size = Vector2(470.0, 18.0)
	level3_boss_hud_bar.min_value = 0.0
	level3_boss_hud_bar.max_value = float(max_hp)
	level3_boss_hud_bar.value = float(hp)
	level3_boss_hud_bar.show_percentage = true
	level3_boss_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.07, 0.02, 0.12, 0.94)
	bar_bg.border_color = Color(0.80, 0.37, 0.98)
	bar_bg.set_border_width_all(2)
	level3_boss_hud_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.71, 0.21, 0.91)
	level3_boss_hud_bar.add_theme_stylebox_override("fill", bar_fill)
	frame.add_child(level3_boss_hud_bar)
	level3_boss_hud_status = Label.new()
	level3_boss_hud_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level3_boss_hud_status.add_theme_font_size_override("font_size", 13)
	level3_boss_hud_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.96))
	frame.add_child(level3_boss_hud_status)
	_update_level3_boss_hud()


func _update_level3_boss_hud() -> void:
	if not is_level3_arena_boss:
		return
	if is_instance_valid(level3_boss_hud_bar):
		level3_boss_hud_bar.max_value = float(max_hp)
		level3_boss_hud_bar.value = float(hp)
		level3_boss_hud_bar.tooltip_text = "MENACING SKELETON HP: %d / %d" % [hp, max_hp]
	if is_instance_valid(level3_boss_hud_status):
		if hp <= 100 and hp > 0:
			level3_boss_hud_status.text = "LAST STAND  |  %d / %d HP" % [hp, max_hp]
		else:
			level3_boss_hud_status.text = "PHASE %d  |  %d / %d HP" % [solo_boss_stage, hp, max_hp]


func _remove_level3_boss_hud() -> void:
	if is_instance_valid(level3_boss_hud) and not level3_boss_hud.is_queued_for_deletion():
		level3_boss_hud.queue_free()
	level3_boss_hud = null
	level3_boss_hud_bar = null
	level3_boss_hud_status = null


func _exit_tree() -> void:
	_cleanup_level3_fog()
	_remove_solo_healing_wisp()
	_remove_solo_arena_barriers()
	_remove_solo_arena_platforms()
	_remove_level3_boss_hud()


func _end_strike() -> void:
	velocity.x = 0.0
	combo_index += 1
	attacks_since_fatigue += 1
	if (is_level3_arena_boss and solo_attack != SoloAttack.NONE
		and combo_index < combo_order.size()):
		if solo_combo_jump_followup and active_slash == Slash.SIDE and combo_order[combo_index] == Slash.DOWN:
			_start_solo_air_downswing()
		else:
			_start_solo_followup_warning()
		return
	if jump_slam or point_blank_attack or lunge_attack or advancing_slam or combo_index >= combo_order.size():
		_finish_attack_pattern()
		return
	var followup_pause := point_blank_followup_pause if point_blank_attack else combo_followup_pause
	combo_pause_remaining = maxf(0.01, followup_pause)
	mode = Mode.RECOVER


func _finish_attack_pattern() -> void:
	if is_level3_arena_boss and solo_attack != SoloAttack.NONE:
		_start_solo_attack_cooldown(solo_attack)
	_last_judge_slam_active = false
	solo_combo_jump_followup = false
	solo_air_downswing_active = false
	solo_warning_step_remaining = 0.0
	sprite.self_modulate = original_sprite_color
	if attacks_since_fatigue >= fatigue_threshold:
		_start_exhausted()
		return
	mode = Mode.RECOVER
	recovery_remaining = solo_attack_recovery if (is_level3_arena_boss and solo_attack != SoloAttack.NONE) else endlag
	solo_attack = SoloAttack.NONE
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
	# Every hit uses the original authored sword CollisionShape2D and the
	# player's actual body CollisionShape2D. Never invent new hurtbox sizes.
	var orange_middle: bool = (is_level3_arena_boss
		and solo_attack == SoloAttack.ORANGE and combo_index == 1
		and active_slash == Slash.FRONT and _orange_dash_sweep_valid)
	var current_transform: Transform2D = hitbox.global_transform
	var traveled: float = _orange_dash_sweep_start.origin.distance_to(current_transform.origin) if orange_middle else 0.0
	var samples: int = clampi(ceili(traveled / 10.0), 1, 64) if orange_middle else 1
	var facing_sign: float = 1.0 if facing_right else -1.0
	for child in target.find_children("*", "CollisionShape2D", true, false):
		if not child is CollisionShape2D:
			continue
		var other: CollisionShape2D = child as CollisionShape2D
		if other.disabled or other.shape == null or other.get_parent() != target:
			continue
		for step: int in range(samples + 1):
			var fraction: float = float(step) / float(samples)
			var sword_at: Transform2D = current_transform
			if orange_middle:
				sword_at.origin = _orange_dash_sweep_start.origin.lerp(current_transform.origin, fraction)
			# Prevent phantom hits behind the *sampled* sword position.
			var boss_sample_x: float = body_shape.global_position.x + sword_at.origin.x - current_transform.origin.x
			if (other.global_position.x - boss_sample_x) * facing_sign < -sword_rear_reach_tolerance:
				continue
			if hitbox.shape.collide(sword_at, other.shape, other.global_transform):
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
	_update_level3_boss_hud()
	if hp <= 0:
		_die()
		return
	_update_solo_boss_stage()
	if solo_stage_flash_remaining > 0.0:
		return
	mode = Mode.RECOVER
	recovery_remaining = parry_cancel_recovery
	combo_index = 0
	combo_pause_remaining = 0.0
	solo_combo_jump_followup = false
	solo_air_downswing_active = false
	solo_warning_step_remaining = 0.0
	solo_attack = SoloAttack.NONE
	attack_cd = maxf(attack_cd, 0.24)
	sprite.speed_scale = 1.0
	sprite.self_modulate = Color(0.55, 0.97, 1.0)
	_set_animation(animation_hurt)



func _solo_low_hp_dash_unlocked() -> bool:
	return is_level3_arena_boss and hp > 0 and hp <= 100


func _update_solo_boss_stage() -> void:
	if not is_level3_arena_boss or mode == Mode.DEAD:
		return
	if max_hp <= 0:
		return
	var hp_ratio: float = float(hp) / float(max_hp)
	var next_stage: int = 1
	if hp_ratio <= solo_stage_three_threshold:
		next_stage = 3
	elif hp_ratio <= solo_stage_two_threshold:
		next_stage = 2
	if next_stage <= solo_boss_stage:
		return
	while solo_boss_stage < next_stage:
		solo_boss_stage += 1
		pursuit_speed *= 1.06
		attack_interval *= 0.91
		endlag *= 0.91
		jump_slam_chance = minf(0.48, jump_slam_chance + 0.04)
		close_lunge_chance = minf(0.40, close_lunge_chance + 0.035)
		alternate_combo_chance = minf(0.47, alternate_combo_chance + 0.06)
		fatigue_after_min_attacks += 1
		fatigue_after_max_attacks += 1
		fatigue_duration_min *= 0.94
		fatigue_duration_max *= 0.94
	# A brief visible breather announces the new attack rhythm.
	# The regular warning durations do not get shortened.
	_update_level3_boss_hud()
	if engaged:
		mode = Mode.RECOVER
		combo_index = 0
		combo_pause_remaining = 0.0
		attack_hit_done = true
		jump_slam = false
		lunge_attack = false
		advancing_slam = false
		point_blank_attack = false
		solo_combo_jump_followup = false
		solo_air_downswing_active = false
		solo_warning_step_remaining = 0.0
		solo_attack = SoloAttack.NONE
		velocity.x = 0.0
		recovery_remaining = maxf(0.3, solo_stage_transition_pause)
		attack_cd = maxf(attack_cd, 0.45)
		solo_stage_flash_remaining = recovery_remaining
		_set_animation(animation_idle)
		queue_redraw()

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
		# Debug overlay matches the actual mirrored, animated, padded hit zone.
		draw_set_transform_matrix(sprite.transform)
		draw_rect(_current_body_damage_rect().grow(4.0),
			Color(0.2, 1.0, 0.5, 0.9), false, 1.5)
		if sprite.animation == animation_front or sprite.animation == animation_side:
			draw_rect(rear_torso_rect.grow(4.0),
				Color(0.2, 1.0, 0.5, 0.7), false, 1.5)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _attack_hits_visible_body_rect(attack_shape: CollisionShape2D, rect: Rect2) -> bool:
	# The slash and target sprite have their own transforms. Testing a real
	# rectangle through sprite.global_transform handles facing reflection,
	# offsets and animation pose without expanding to a big world AABB.
	var visible_body: RectangleShape2D = RectangleShape2D.new()
	# Convert the mirrored sprite transform to an ordinary rotated rectangle:
	# physics shapes should not receive a negative/reflected transform.
	var sprite_pose: Transform2D = sprite.global_transform
	var world_size: Vector2 = Vector2(
		(sprite_pose.x.length()) * (rect.size.x + 8.0),
		(sprite_pose.y.length()) * (rect.size.y + 8.0)
	)
	visible_body.size = world_size
	var center_world: Vector2 = sprite_pose * rect.get_center()
	var body_pose: Transform2D = Transform2D(sprite_pose.get_rotation(), center_world)
	return attack_shape.shape.collide(
		attack_shape.global_transform,
		visible_body,
		body_pose
	)


func attack_shape_hits_hurtbox(attack_shape: CollisionShape2D) -> bool:
	if mode == Mode.DEAD or attack_shape == null:
		return false
	if attack_shape.disabled or attack_shape.shape == null:
		return false
	if not is_instance_valid(sprite):
		return false
	# V16: The player tests this ART-ALIGNED hurtbox instead of the smaller,
	# fixed movement collider. The animation-specific offsets already used
	# by _current_body_damage_rect() finally matter during actual gameplay.
	if _attack_hits_visible_body_rect(attack_shape, _current_body_damage_rect()):
		return true
	# During front/side attacks the torso stays hittable as the blade moves.
	if sprite.animation == animation_front or sprite.animation == animation_side:
		if _attack_hits_visible_body_rect(attack_shape, rear_torso_rect):
			return true
	# Always accept hits on the real body collider as well, including poses
	# where the atlas sprite has shifted away from the centered collision.
	if is_instance_valid(body_shape) and body_shape.shape != null and not body_shape.disabled:
		return attack_shape.shape.collide(attack_shape.global_transform, body_shape.shape, body_shape.global_transform)
	return false

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
	_update_level3_boss_hud()
	if hp <= 0:
		_die()
		return
	_update_solo_boss_stage()
	# V18: HP is real; flash WHITE for 0.12s without resetting the attack.
	damage_white_flash = 0.12
	# V17: Damage DOES NOT interrupt his warning, slash, dash, or combo.
	# This is super-armor against interruption, not immunity to HP damage.
	# A successful timed parry still cancels the attack via _on_parried().
	# Keep sprite pose/timers untouched so the planned attack finishes.


func _die() -> void:
	if mode == Mode.DEAD:
		return
	_last_judge_slam_active = false
	mode = Mode.DEAD
	_cleanup_level3_fog()
	solo_attack = SoloAttack.NONE
	_remove_solo_healing_wisp()
	_remove_solo_arena_barriers()
	_remove_solo_arena_platforms()
	_remove_level3_boss_hud()
	royal_corpse_ready = false
	royal_reviving_stage = 0
	set_meta(&"king_royal_reviving", false)
	# Clear the previous attack-warning drawing even if killed mid-telegraph.
	queue_redraw()
	engaged = false
	velocity = Vector2.ZERO
	collision_layer = 0
	if bool(get_meta(&"king_necromancer_summon", false)):
		# Terrain-only collision lets the corpse fall onto its platform, while
		# the player and other skeletons walk through its inert body.
		collision_mask = solid_terrain_mask
		body_shape.set_deferred("disabled", false)
	else:
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
	if sprite.sprite_frames != null:
		var death_name: StringName = animation_death
		if not sprite.sprite_frames.has_animation(death_name):
			death_name = &"death"
		if sprite.sprite_frames.has_animation(death_name):
			animation_death = death_name
			sprite.play(death_name)
			death_animation_playing = true
			# Safety for looping animations: settle on the very last frame.
			var frames: int = sprite.sprite_frames.get_frame_count(death_name)
			var fps: float = maxf(1.0, sprite.sprite_frames.get_animation_speed(death_name))
			var keep_corpse: bool = bool(get_meta(&"king_necromancer_summon", false))
			get_tree().create_timer(float(frames) / fps + 0.15).timeout.connect(
				func() -> void:
					if is_instance_valid(self) and mode == Mode.DEAD and royal_reviving_stage == 0:
						if keep_corpse:
							_finish_royal_corpse()
						else:
							queue_free()
			)
			return
	# Missing death sprite: keep an inert body at its last available pose.
	if bool(get_meta(&"king_necromancer_summon", false)):
		_finish_royal_corpse()
	else:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, death_fade_seconds)
		tween.tween_callback(queue_free)




# =====================================================
# KING-OWNED MENACING: CORPSE -> GHOST -> REVERSE DEATH
# =====================================================
func _finish_royal_corpse() -> void:
	if mode != Mode.DEAD or royal_reviving_stage != 0:
		return
	death_animation_playing = false
	sprite.stop()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_death):
		var last_frame: int = maxi(0, sprite.sprite_frames.get_frame_count(animation_death) - 1)
		sprite.animation = animation_death
		sprite.set_frame_and_progress(last_frame, 0.0)
	royal_corpse_ready = true
	sprite.modulate.a = 1.0

func can_be_royally_revived() -> bool:
	return bool(get_meta(&"king_necromancer_summon", false)) and mode == Mode.DEAD and royal_corpse_ready and royal_reviving_stage == 0

func begin_royal_resurrection(reborn_hp: int = 110) -> bool:
	if not can_be_royally_revived():
		return false
	royal_corpse_ready = false
	royal_reviving_stage = 1
	royal_revive_elapsed = 0.0
	set_meta(&"king_royal_reviving", true)
	set_meta(&"king_reborn_elite", true)
	set_meta(&"king_guard_buffed", true)
	set_meta(&"king_royal_revive_count", int(get_meta(&"king_royal_revive_count", 0)) + 1)
	# Reuses the SAME body and hitboxes. No duplicated active enemy node.
	max_hp = maxi(90, reborn_hp)
	hp = max_hp
	pursuit_speed = 205.0
	attack_interval = 0.22
	attack_interval_random = 0.09
	endlag = 0.32
	dash_attack_distance = 420.0
	close_lunge_chance = 0.62
	alternate_combo_chance = 0.88
	advancing_slam_chance = 0.38
	jump_slam_chance = 0.67
	jump_slam_range = 240.0
	jump_slam_launch_speed = 425.0
	jump_slam_move_speed = 350.0
	# Shorter reaction time, but the purple warning is always readable.
	melee_reach = 120.0
	tactical_min_range = 65.0
	tactical_max_range = 115.0
	tactical_decision_min = 0.38
	tactical_decision_max = 0.95
	tactical_walk_pause_chance = 0.04
	jump_slam_warning_seconds = 0.76
	attack_warning_seconds = 0.84
	point_blank_warning_seconds = 0.88
	lunge_warning_seconds = 0.84
	advancing_slam_warning_seconds = 0.86
	attack_warning_color = Color(0.84, 0.43, 1.0)
	combo_dash_distance = 86.0
	combo_swing_seconds = 0.135
	combo_followup_pause = 0.045
	lunge_speed = 1010.0
	obstacle_jump_cooldown = 0.62
	small_jump_velocity = -430.0
	tall_jump_velocity = -580.0
	fatigue_after_min_attacks = 12
	fatigue_after_max_attacks = 16
	fatigue_duration_min = 1.25
	fatigue_duration_max = 1.75
	tactical_retreat_chance = 0.16
	activation_radius = 1000.0
	# Purple shading belongs to the resurrected skeleton, not the corpse.
	original_sprite_color = Color(0.72, 0.38, 1.0)
	sprite.self_modulate = Color(0.49, 0.24, 0.70)
	if is_instance_valid(royal_revive_preview):
		royal_revive_preview.queue_free()
	royal_revive_preview = AnimatedSprite2D.new()
	royal_revive_preview.name = "RoyalResurrectionGhost"
	royal_revive_preview.sprite_frames = sprite.sprite_frames
	royal_revive_preview.transform = sprite.transform
	royal_revive_preview.flip_h = sprite.flip_h
	royal_revive_preview.centered = sprite.centered
	royal_revive_preview.offset = sprite.offset
	royal_revive_preview.z_index = sprite.z_index + 2
	royal_revive_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	royal_revive_preview.modulate = Color(0.74, 0.40, 1.0, 0.0)
	add_child(royal_revive_preview)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_idle):
		royal_revive_preview.animation = animation_idle
		royal_revive_preview.frame = 0
	royal_revive_preview.stop()
	royal_revive_preview.scale = sprite.scale * 1.12 * maxf(1.05, royal_reborn_visual_multiplier)
	_align_royal_ghost_feet_to_corpse()
	return true

func _align_royal_ghost_feet_to_corpse() -> void:
	# The idle-frame ghost is taller than the collapsed death-frame corpse.
	# Align its bottom to the real collider's floor, not the corpse sprite's
	# center. This is why the enlarged fade-in previously floated in midair.
	if not is_instance_valid(royal_revive_preview):
		return
	if not body_shape.shape is RectangleShape2D:
		royal_revive_preview.position = sprite.position
		return
	var body_rect: RectangleShape2D = body_shape.shape as RectangleShape2D
	var feet_y: float = body_shape.position.y + body_rect.size.y * absf(body_shape.scale.y) * 0.5
	var frame_texture: Texture2D = null
	if (royal_revive_preview.sprite_frames != null
		and royal_revive_preview.sprite_frames.has_animation(royal_revive_preview.animation)
		and royal_revive_preview.sprite_frames.get_frame_count(royal_revive_preview.animation) > 0):
		frame_texture = royal_revive_preview.sprite_frames.get_frame_texture(royal_revive_preview.animation, 0)
	if frame_texture == null:
		royal_revive_preview.position = sprite.position
		return
	var image_height: float = float(frame_texture.get_height())
	var bottom_offset: float = (image_height * 0.5 if royal_revive_preview.centered else image_height)
	bottom_offset += royal_revive_preview.offset.y
	royal_revive_preview.position = Vector2(
		body_shape.position.x - royal_revive_preview.offset.x * royal_revive_preview.scale.x,
		feet_y - bottom_offset * absf(royal_revive_preview.scale.y) - 2.0
	)


func _apply_royal_reborn_growth() -> void:
	# Enlarge the real sprite and PHYSICS hurtbox together, once per body.
	# Updating both authored transforms is essential: _apply_facing()
	# rebuilds the sprite/Area2D pose every time he turns.
	if royal_reborn_growth_applied:
		return
	royal_reborn_growth_applied = true
	var visual_factor: float = maxf(1.05, royal_reborn_visual_multiplier)
	var body_factor: float = maxf(1.05, royal_reborn_body_multiplier)
	var sword_factor: float = maxf(1.0, royal_reborn_attack_multiplier)
	authored_sprite_transform = authored_sprite_transform.scaled_local(
		Vector2.ONE * visual_factor)
	authored_attack_area_transform = authored_attack_area_transform.scaled_local(
		Vector2.ONE * sword_factor)
	if body_shape.shape is RectangleShape2D:
		var body_rect: RectangleShape2D = body_shape.shape as RectangleShape2D
		royal_reborn_floor_lift = (body_rect.size.y * absf(body_shape.scale.y)
			* (body_factor - 1.0) * 0.5)
	body_shape.scale *= body_factor
	_apply_facing()
	queue_redraw()


func _update_royal_resurrection(delta: float) -> void:
	royal_revive_elapsed += delta
	if royal_reviving_stage == 1:
		# 2.2 seconds: a transparent purple ghost slowly forms ABOVE the corpse.
		var progress: float = clampf(royal_revive_elapsed / maxf(0.05, royal_revive_ghost_seconds), 0.0, 1.0)
		if is_instance_valid(royal_revive_preview):
			royal_revive_preview.modulate.a = 0.88 * progress
			royal_revive_preview.scale = sprite.scale * maxf(1.05, royal_reborn_visual_multiplier) * lerpf(1.12, 1.0, progress)
			_align_royal_ghost_feet_to_corpse()
		if progress >= 1.0:
			royal_reviving_stage = 2
			royal_revive_elapsed = 0.0
		return
	if royal_reviving_stage == 2:
		# 0.9 seconds: hold the visible ghost before the body moves at all.
		var hold_progress: float = clampf(royal_revive_elapsed / maxf(0.05, royal_revive_hold_seconds), 0.0, 1.0)
		if is_instance_valid(royal_revive_preview):
			royal_revive_preview.modulate.a = 0.88 * (1.0 - 0.15 * hold_progress)
			_align_royal_ghost_feet_to_corpse()
		if hold_progress >= 1.0:
			if is_instance_valid(royal_revive_preview):
				royal_revive_preview.queue_free()
			royal_revive_preview = null
			royal_reviving_stage = 3
			royal_revive_elapsed = 0.0
			# The ghost merges into a larger, physically hittable royal body.
			_apply_royal_reborn_growth()
			# Now the enlarged body plays its death frames backward.
			sprite.stop()
			sprite.self_modulate = original_sprite_color
		return
	if royal_reviving_stage == 3:
		# 1.6 seconds: clearly visible reversed death animation.
		var reverse_progress: float = clampf(royal_revive_elapsed / maxf(0.05, royal_revive_reverse_seconds), 0.0, 1.0)
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_death):
			var last: int = maxi(0, sprite.sprite_frames.get_frame_count(animation_death) - 1)
			sprite.animation = animation_death
			sprite.set_frame_and_progress(clampi(int(floor(float(last) * (1.0 - reverse_progress))), 0, last), 0.0)
		if reverse_progress >= 1.0:
			_finish_royal_resurrection()

func _finish_royal_resurrection() -> void:
	if royal_reviving_stage != 3 or mode != Mode.DEAD:
		return
	royal_reviving_stage = 0
	royal_revive_elapsed = 0.0
	set_meta(&"king_royal_reviving", false)
	royal_corpse_ready = false
	# Lift half of the physical height increase once, preserving feet-on-floor.
	if royal_reborn_floor_lift > 0.0:
		global_position.y -= royal_reborn_floor_lift
		royal_reborn_floor_lift = 0.0
	collision_layer = royal_original_collision_layer
	collision_mask = royal_original_collision_mask
	_ignore_other_menacing_bodies()
	body_shape.set_deferred("disabled", false)
	attack_area.set_deferred("monitoring", true)
	death_animation_playing = false
	sprite.speed_scale = 1.0
	sprite.modulate.a = 1.0
	sprite.self_modulate = original_sprite_color
	velocity = Vector2.ZERO
	engaged = true
	mode = Mode.CHASE
	stuck_timer = 0.0
	stuck_anchor_x = global_position.x
	stuck_teleport_cooldown = 1.5
	attack_cd = 0.80
	recovery_remaining = 0.0
	combo_index = 0
	combo_pause_remaining = 0.0
	attacks_since_fatigue = 0
	fatigue_threshold = _roll_fatigue_threshold()
	_find_player()
	_ensure_player_pass_through()
	_face_player()
	_set_animation(animation_idle)
	queue_redraw()
	health_changed.emit(hp, max_hp)
