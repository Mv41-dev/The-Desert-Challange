# V36: Rolling fog and flowing fire cores with contact ignition.
# V35: Smaller ramp-shaped Slam hazard and gray banks held through the final ramp.
# V34: Ramp-shaped Slam fire and fast, billowing Fountain jets.
# V33: Growing gray Slam warning, turbulent Slam fire, and rising Fountain jets.
# Fountain vents are wider-spaced, fewer, narrower, and taller.
# Existing warning times, boss AI and damage values are retained.
# V30: Seamless world-space normal dash blaze, bright additive yellow core,
# no repeated fountain columns; specials remain separate.
# V29: normal dash creates CONTINUOUS fiery ground fog, special Fountain keeps spaced vertical vents.
# Gray fog remains normal-blended; hot yellow core is a separate additive layer.
# V48 boss timings / hitboxes / V15 warning timings unchanged.
# Menacing Skeleton Fog V28 - AGGLOMERATED GRAY-TO-BLAZING SMOKE, ALL FIRE EFFECTS.
# Complete replacement for V27. No cone sprites, fire shader rectangles,
# chunky expanded fountains, or manually placed scenes. Uses V18 fog texture.
# Gray warning -> same-sized orange outer/yellow inner fog (faster rise) ->
# cooling gray smoke shrinking into the sand. Boss V48 logic/timings untouched.
# V27: Narrow translucent fire tongues with soft tips and bright base; removes noisy rectangular flame columns.
# Keeps all V26 boss/fog hooks, timing, damage, and ember/cooling systems.
# V26: REAL-TIME SHADER FIRE (animated rising noise), optional additive hot glow; replaces repeated static flame images.
# Gray warnings, V25 special timings, hitboxes, attack logic and shake unchanged.
# V25: Longer gray special-attack warnings, widely staggered fountain vents, rounded fire with soft hot cores.
# All existing V24 boss combat, fog and camera timing remains unchanged.
# V23: denser miniature low warning sparks, additive camera shaking, fiery smoke cools/falls into sand mist.
# V21: localized, organically flickering FIRE erupting through the gray fog along real dashes.
# Fire is not orange-tinted smoke or giant geometric spikes; it has bright hot cores.
# V20: flame spikes replaced by fiery RECOLORS of the SAME procedural gray smoke cloud.
# Orange rolling smoke explosions + abundant tiny sparks ONLY along the real dash path.
# V19: animated ground-flame explosions FOLLOW REAL LEVEL 3 BOSS DASH MOVEMENT ONLY.
# Fog V18: cooler genuinely gray smoke, tiny irregular sparks, no giant ember halo rings.
# VISUAL-ONLY: V15 visual warning delay, exact combat/dash timings, and sand height unchanged.
# Fog V17: quiet continuous gray ground mist + textured pre-dash smoke + brighter embers.
# VISUAL CHANGE ONLY. V15 fog-only visual delay and all boss warning/dash timing remain unchanged.
# No extra Area2D, GPU particle scene, or external texture required.
# Fog V16: natural layered smoke wisps + bright ember specks, preserves V15 visual delay and dash timing.
# Fog V15: visual-only 0.23s start offset, WITHOUT altering boss windups or dash speed.
# Menacing Skeleton Fog V13: white/gray DASH-ONLY telegraph, disperses on STRIKE transition
# Uses the same ground placement and fog thickness as V12.
# This V12 script integrates with a separate optional ambience Node2D in level_3.
# The ambience script darkens ONLY ParallaxBackground; fog lives in world space.
# WORLD-SPACE VISIBLE procedural fog banks + irregular smoke textures.
# Replaces V2 faint-sprites-only look. No scene or external texture required.
# Keep the existing V42 Menacing Skeleton boss script unchanged.
# V14: predictive combo-aware fog warning, sweep finishes ahead of actual dash.
# The boss script calls configure_arena(), activate(), warn_before_dash(),
# dash_started(), and disturb_at(). The fog never deals damage.
extends Node2D
class_name MenacingPhase3Fog

@export_group("Permanent Level 3 Atmosphere")
@export var fog_color: Color = Color(0.43, 0.45, 0.48, 1.0)
@export_range(0.0, 1.0, 0.01) var permanent_ground_density: float = 0.63
@export_range(0.0, 1.0, 0.01) var permanent_upper_haze: float = 0.014
@export_range(0.0, 1.0, 0.01) var persistent_bank_opacity: float = 0.95
@export_range(30.0, 95.0, 1.0) var puff_spacing: float = 48.0
@export var ground_collision_mask: int = 1
# Actual maximum height of the permanent fog above the floor, in world pixels.
# Previous versions had 200+ pixel clouds even when their centers were lowered.
# This controls BOTH the bank geometry and the smoke sprite dimensions.
@export_range(20.0, 110.0, 1.0) var ambient_fog_height_px: float = 28.0
# Level 3 uses a mostly flat sand floor. Reject raised colliders/platforms when
# anchoring the long continuous fog strip, otherwise spikes draw into the sky.
@export_range(0.0, 32.0, 1.0) var main_floor_max_height_difference_px: float = 6.0
@export var entrance_sweep_seconds: float = 0.90
@export var atmospheric_drift_speed: float = 0.88
# Tiny 3px overlap hides the hard edge without burying the fog underground.
# Fog height extends UP from the actual sand surface, not up from an underground collider.
@export_range(0.0, 12.0, 0.5) var fog_below_ground_px: float = 3.0
# V10 rendering-only trim: positive Y is DOWN; no raycast, phase,
# opacity, animation timing or boss changes.
@export_range(0.0, 60.0, 1.0) var fog_render_down_px: float = 24.0
# If the TileMap isn't part of the configured terrain mask, the player's
# grounded collision foot is a more reliable floor reference than a cactus.
@export var use_player_floor_anchor: bool = true
@export var print_floor_debug: bool = true

@export_group("V17 Continuous Low Fog")
# Exactly ONE low continuous polygon along the sand. Its upper edge fades out;
# no repeated wavy polygon bands or full-screen overlay.
@export_range(12.0, 85.0, 1.0) var continuous_ground_fog_height_px: float = 39.0
@export_range(0.0, 0.5, 0.01) var continuous_ground_fog_alpha: float = 0.20
# Only a few faint wisps are left inside the permanent ground layer.
@export_range(0.0, 1.0, 0.01) var ambient_wisp_alpha_multiplier: float = 0.22

@export_group("Dense Dash Warning Fog")
# The same white mist thickens during a real dash windup.
# Tuned to stay BELOW the actors' upper bodies, not blank out the whole scene.
@export_range(0.2, 1.0, 0.01) var warning_density: float = 0.88
# Sweep reaches the opposite arena side quickly, then remains visible
# through the rest of the boss's windup instead of arriving during the dash.
@export_range(0.30, 0.95, 0.05) var warning_sweep_seconds: float = 0.52
# V15: THIS delays ONLY the appearance of the dense warning fog.
# Boss warning/animation durations, dash speeds, hit frames remain V45 original.
# Fog still disperses immediately on the WARNING -> STRIKE transition.
@export_range(0.0, 0.45, 0.01) var fog_visual_delay_v15: float = 0.23
@export_range(24.0, 160.0, 1.0) var warning_height_above_ground: float = 58.0
@export_range(0.15, 1.0, 0.01) var disperse_seconds: float = 0.48
# Exact same hue as normal fog. The warning changes density, not color.
@export var warning_tint: Color = Color(0.43, 0.45, 0.48, 1.0)
@export var warning_front_highlight: Color = Color(0.62, 0.64, 0.67, 1.0)
@export_range(0.0, 1.0, 0.01) var warning_core_alpha: float = 0.42
@export_range(0.0, 1.0, 0.01) var warning_upper_alpha: float = 0.13
@export_range(0.0, 1.0, 0.01) var warning_puff_alpha: float = 0.48
# A warning is shown only during an actual boss windup, not on scene startup.
@export var show_test_warning_on_start: bool = false
@export var debug_fog_output: bool = true

@export_group("V18 Gray Smoke / Tiny Sparks")
# Large opaque polygon strips from V15 are fully disabled. Soft textured puffs
# now make all the volume, with different outlines and independent motion.
@export_range(0.30, 2.0, 0.05) var natural_warning_smoke_density: float = 1.0
@export_range(0.30, 2.0, 0.05) var natural_ambient_smoke_density: float = 1.0
@export_range(0.0, 3.0, 0.05) var ember_rate_multiplier: float = 1.0
@export var ember_bright_orange: Color = Color(1.0, 0.47, 0.075)
@export var ember_yellow_core: Color = Color(1.0, 0.90, 0.42)
@export_range(8, 1400, 1) var maximum_embers: int = 960
@export_range(0.1, 2.0, 0.05) var ember_fade_time: float = 1.05
@export_range(0.0, 400.0, 1.0) var warning_ember_emission_rate: float = 240.0
@export_range(0, 100, 1) var warning_ember_start_burst: int = 32
@export_range(40.0, 900.0, 1.0) var warning_ember_band_length: float = 700.0
@export_range(0.0, 10.0, 0.5) var ambient_ember_emission_rate: float = 1.0
@export_range(0, 64, 1) var dash_ember_burst_count: int = 36

@export_group("V21 Fire Eruption Trail | Actual Dashes Only")
# Visual-only: never changes boss attack timing, damage, ground-fog, or warnings.
@export var flaming_dash_fog_enabled: bool = true
@export_range(12.0, 145.0, 1.0) var flame_trail_spacing: float = 22.0
@export_range(0.25, 1.8, 0.05) var flame_visual_scale: float = 0.90
@export_range(0.45, 2.0, 0.05) var flame_burst_lifetime: float = 1.25
@export_range(1, 45, 1) var flame_sparks_per_burst: int = 11
@export_range(10, 150, 1) var flame_max_bursts: int = 72
# Burnt-orange smoky edges, live orange tongues, golden/yellow interiors.
@export var flame_outer_color: Color = Color(0.87, 0.23, 0.035, 1.0)
@export var flame_body_color: Color = Color(1.0, 0.47, 0.045, 1.0)
@export var flame_core_color: Color = Color(1.0, 0.91, 0.31, 1.0)
@export_range(0.5, 1.7, 0.05) var flame_height_multiplier: float = 1.0

@export_group("V24 Special Fog Waves and Fountain Vents")
@export_range(350.0, 1800.0, 25.0) var slam_wave_speed: float = 1060.0
@export_range(0.20, 0.50, 0.001) var slam_wave_flame_delay: float = 0.333
@export_range(50.0, 160.0, 5.0) var fountain_vent_spacing: float = 118.0
@export_range(0.25, 0.85, 0.01) var fountain_vent_ignite_delay: float = 0.50
@export_range(0.4, 1.4, 0.05) var fountain_vent_flame_seconds: float = 0.66
@export_range(50, 180, 1) var max_special_smoke_puffs: int = 100

@export_group("V25 Special Attacks: Readable Smoke Before Fire")
# Separate V25 properties deliberately override V24 defaults even if old
# exported Inspector values were previously saved in the boss scene.
@export_range(250.0, 900.0, 10.0) var v25_slam_gray_wave_speed: float = 520.0
@export_range(0.60, 1.60, 0.05) var v25_slam_fire_delay: float = 0.95
@export_range(0.75, 2.0, 0.05) var v25_fountain_gray_hold: float = 1.15
@export_range(180.0, 650.0, 5.0) var v25_fountain_spacing: float = 330.0
@export_range(1, 12, 1) var fountain_max_vents_per_dash: int = 4
@export_range(35.0, 100.0, 1.0) var fountain_visual_width_px: float = 60.0
@export_range(90.0, 260.0, 1.0) var fountain_visual_height_px: float = 168.0
@export_range(75.0, 200.0, 5.0) var slam_fire_front_tail_px: float = 115.0
@export_range(0.70, 1.50, 0.05) var v25_fountain_gray_volume: float = 1.15
@export_range(0.45, 1.50, 0.05) var v25_special_fire_size: float = 0.92

@export_group("V30 Seamless World-Space Dash Fire")
@export_range(45.0, 125.0, 1.0) var normal_dash_fire_width_px: float = 82.0
@export_range(25.0, 125.0, 1.0) var normal_dash_fire_height_px: float = 74.0
@export var additive_hot_core_enabled: bool = true
@export_range(0.4, 1.8, 0.05) var normal_dash_fire_opacity: float = 1.12
@export_range(0.3, 1.6, 0.05) var normal_dash_core_brightness: float = 1.15
@export_range(0.35, 1.8, 0.05) var normal_dash_smoke_settle_seconds: float = 1.00
@export_range(1, 16, 1) var dash_sparks_per_sample: int = 5

@export_group("V28 Agglomerated Smoke Fire: All Ignitions")
# All ignitions have the identical cloudy footprint as their gray telegraph.
@export_range(55.0, 210.0, 1.0) var shader_fire_width_px: float = 112.0
@export_range(55.0, 230.0, 1.0) var shader_fire_height_px: float = 118.0
@export_range(10.0, 100.0, 1.0) var gray_plume_rise_speed: float = 32.0
@export_range(45.0, 220.0, 1.0) var blazing_plume_rise_speed: float = 93.0

@export_group("V23 Level 3 Boss Camera Impact")
@export var boss_screen_shake_enabled: bool = true
@export_range(0.0, 9.0, 0.1) var normal_attack_shake_px: float = 1.6
@export_range(0.0, 9.0, 0.1) var dash_shake_px: float = 2.0
@export_range(0.0, 14.0, 0.1) var jump_landing_shake_px: float = 6.0
@export_range(0.05, 0.60, 0.01) var attack_shake_seconds: float = 0.16
@export_range(0.08, 0.75, 0.01) var jump_landing_shake_seconds: float = 0.30

# V28: NO flame sprites, no shader rectangles, no cones. Every blazing effect
# reuses the SAME soft-edged smoke texture as the permanent gray fog.
# The palette, vertical velocity and density change, not the effect footprint.

# A single world-aligned field for each ordinary dash, not one rectangle
# every 22px. Shader only generates the organic silhouette; glow is a separate
# additive pass so Mobile renderer stays readable even without HDR bloom.
const DASH_RIBBON_SHADER: String = """
shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float world_left = 0.0;
uniform float world_width = 100.0;
uniform float fire_height = 74.0;
uniform float heat = 1.0;
uniform float opacity = 1.0;
uniform float intensity = 1.0;
uniform bool glow_pass = false;
uniform bool vertical_plume = false;
uniform float slam_direction = 0.0;
uniform float ignition = 0.0;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += noise2(p) * a;
        p = p * 2.03 + vec2(13.7, 9.2);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    float x = world_left + UV.x * max(world_width, 1.0);
    float y = UV.y; // 0 = top, 1 = floor
    float t = TIME;

    vec2 p1 = vec2(x * 0.010 - t * 0.10, y * 2.1 + t * 0.18);
    vec2 p2 = vec2(x * 0.024 + t * 0.22, y * 4.9 - t * 0.42);
    vec2 p3 = vec2(x * 0.041 - t * 0.16, y * 7.8 + t * 0.90);
    if (vertical_plume) {
        float stream = y + t * 3.9;
        p1 = vec2(x * 0.038, stream * 2.4);
        p2 = vec2(x * 0.072, stream * 5.2);
        p3 = vec2(x * 0.13, stream * 9.0);
    }
    float broad = fbm(p1);
    float medium = fbm(p2 + vec2(broad * 1.6, broad * 0.55));
    float fine = fbm(p3 + vec2(medium * 1.3, broad * 0.6));

    float top = 0.30 + 0.17 * (1.0 - broad) + 0.05 * sin(x * 0.028 + t * 1.8) + 0.03 * sin(x * 0.063 - t * 2.7);
    float vertical = smoothstep(top - 0.16, top + 0.11, y);
    float bottom_fill = smoothstep(0.06, 0.48, y);
    if (abs(slam_direction) > 0.5) {
        float crest = fbm(vec2(x * 0.026 - t * 0.48, y * 2.6 + t * 0.9));
        float fray = fbm(vec2(x * 0.073 + t * 0.31, y * 5.7 + t * 1.7));
        float along = slam_direction > 0.0 ? UV.x : 1.0 - UV.x;
        top = clamp(0.10 + 0.78 * along + 0.48 * (crest - 0.46) + 0.22 * (fray - 0.46), 0.06, 0.94);
        vertical = smoothstep(top - 0.09, top + 0.08, y) * smoothstep(0.0, 0.14, y);
    }
    if (vertical_plume) {
        // Increasing the noise phase moves its features toward the top.

        vertical = smoothstep(0.02, 0.22, y);
        bottom_fill = mix(0.88, 1.0, y);
    }
    float field = broad * 0.43 + medium * 0.34 + fine * 0.23 + y * 0.25;
    if (vertical_plume) {
        field += 0.18 * (1.0 - y);
    }
    float breakup = smoothstep(0.34, 0.74, field + medium * 0.14 - (1.0 - y) * 0.11);
    float wisps = smoothstep(0.47, 0.82, broad * 0.35 + fine * 0.40 + medium * 0.25 + y * 0.18);
    float outer = vertical * bottom_fill * breakup * (0.78 + 0.22 * medium);
    float core = vertical * bottom_fill * wisps * smoothstep(0.54, 0.92, field + fine * 0.12);

    float feather = clamp(24.0 / max(world_width, 1.0), 0.02, 0.24);
    float ends = smoothstep(0.0, feather, UV.x) * (1.0 - smoothstep(1.0 - feather, 1.0, UV.x));
    outer *= ends;
    core *= ends;

    // Same yellow/orange palette and world-noise for all ignitions.
    // In Fountain mode the fog stays INSIDE a narrow vertical lane,
    // swirls upward and softly fades into the air. Never a hard rectangle.
    if (vertical_plume) {
        float sway = (1.0 - y) * (0.13 * sin(y * 5.4 + t * 3.2 + world_left * 0.035) + 0.09 * sin(world_left));
        sway += (broad - 0.47) * (1.0 - y) * 0.36;
        float half_width = mix(0.14, 0.47, smoothstep(0.03, 0.94, y)) + (medium - 0.47) * 0.20;
        float side_distance = abs(UV.x - 0.5 + sway);
        float side_mask = 1.0 - smoothstep(half_width - 0.12, half_width + 0.01, side_distance);
        float tip_fade = smoothstep(0.025, 0.28, y);
        float billow = 0.75 + 0.25 * sin(y * 13.0 + t * 20.0 + world_left * 0.042);
        outer *= side_mask * tip_fade * billow;
        float spine = 1.0 - smoothstep(0.02, half_width * 0.83, side_distance);
        core = max(core, outer * spine * (0.58 + 0.32 * medium));
        core *= side_mask * tip_fade * billow;
    }

    if (vertical_plume || abs(slam_direction) > 0.5) {
        float pockets = smoothstep(0.40, 0.73, field + 0.10 * medium);
        core = max(core, outer * pockets * (0.70 + 0.45 * y));
        outer = min(1.5, outer * 1.85);
        core *= 1.65;
    }
    float floor_soft = 1.0 - 0.10 * smoothstep(0.95, 1.0, y);
    outer *= floor_soft;
    core *= floor_soft;

    float contact = ignition * outer * smoothstep(0.62, 0.98, y);
    if (glow_pass) {
        float hot_center = core * heat * opacity * intensity;
        hot_center *= 0.26 + 0.54 * smoothstep(0.42, 0.95, y);
        if (vertical_plume) {
            hot_center *= 1.0 + 1.35 * (1.0 - y);
        }
        vec3 inner = mix(vec3(1.0, 0.74, 0.12), vec3(1.0, 0.95, 0.42), smoothstep(0.58, 0.90, field));
        COLOR = vec4(inner, clamp(hot_center * 0.70 + contact * 0.30, 0.0, 1.0));
    } else {
        vec3 cooled = vec3(0.40, 0.42, 0.45);
        vec3 edge = vec3(0.84, 0.25, 0.06);
        vec3 body = vec3(1.0, 0.52, 0.11);
        vec3 inner = vec3(1.0, 0.88, 0.26);

        float body_mix = smoothstep(0.40, 0.80, field + medium * 0.08);
        vec3 fiery = mix(edge, body, body_mix);
        fiery = mix(fiery, inner, core * 0.42);
        fiery = mix(fiery, vec3(1.0, 0.94, 0.65), clamp(contact, 0.0, 0.84));
        vec3 coal = mix(cooled, vec3(0.75, 0.24, 0.075), smoothstep(0.03, 0.52, heat) * smoothstep(0.47, 0.71, field));
        vec3 final_col = mix(coal, fiery, heat);

        float alpha = outer * opacity * mix(0.18, 0.56, heat);
        alpha += core * opacity * heat * 0.10;
        COLOR = vec4(final_col, alpha);
    }
}
"""

class DashSmokeExplosionRenderer:
	extends Node2D
	# One painter for gray telegraphs AND every orange/yellow burning effect.
	# Paint many overlapping, small, irregular smoke curls rather than one
	# giant sprite. A plume never extends outside its designated rectangle.
	var smoke_texture: Texture2D = null
	var bursts: Array[Dictionary] = []
	var special_puffs: Array[Dictionary] = []
	var fountain_vents: Array[Dictionary] = []
	var ignite_delay: float = 1.15
	var gray_fountain_volume: float = 1.15
	var special_fire_scale: float = 0.92
	var normal_width: float = 112.0
	var normal_height: float = 118.0
	var visual_scale: float = 0.90
	var height_multiplier: float = 1.0
	var outer_color: Color = Color(0.40, 0.15, 0.07)
	var body_color: Color = Color(0.98, 0.41, 0.06)
	var core_color: Color = Color(1.0, 0.84, 0.34)
	var fog_color: Color = Color(0.43, 0.45, 0.48)
	var clock: float = 0.0
	var gray_rise_speed: float = 32.0
	var fiery_rise_speed: float = 93.0
	var emissive_pass: bool = false
	var dash_width: float = 70.0
	var dash_height: float = 64.0
	var warning_smoke_color: Color
	var warning_smoke_alpha: float
	var fountain_width: float = 60.0
	var fountain_height: float = 168.0

	func _cloud(pos: Vector2, dimensions: Vector2, tint: Color, opacity: float, hot_core: bool = false) -> void:
		# Two CanvasItems, two different blend modes. Gray fog and orange
		# silhouette are NORMAL, only small yellow cores are ADDITIVE.
		if emissive_pass != hot_core or smoke_texture == null or opacity < 0.003:
			return
		draw_texture_rect(smoke_texture,
			Rect2(pos - dimensions * 0.5, dimensions), false,
			Color(tint.r, tint.g, tint.b, clampf(opacity, 0.0, 1.0)))

	func _plume(base: Vector2, width: float, height: float,
			seed: float, time: float, fire_mix: float,
			strength: float, rise_multiplier: float = 1.0,
			traveled_pixels: float = -1.0) -> void:
		# EXACTLY the same agglomerated rectangular column for both colors.
		# Tiny curls recycle as they rise; they shrink/fade BEFORE reaching
		# the top. Fire speeds up the vertical drift without growing the shape.
		if strength < 0.003:
			return
		var w: float = maxf(14.0, width)
		var h: float = maxf(18.0, height)
		var heat: float = clampf(fire_mix, 0.0, 1.0)
		var speed: float = lerpf(gray_rise_speed, fiery_rise_speed, heat) * rise_multiplier
		# A supplied travel value preserves continuous upward movement while
		# the gray column ignites. It never teleports smoke between phases.
		var advance: float = (traveled_pixels if traveled_pixels >= 0.0 else time * speed) / h
		# 4 overlapping streams by 11 vertical samples: full continuous fog,
		# no disconnected floating circles, no sharp edges, no fake flame tips.
		for row in range(11):
			for lane in range(4):
				var unique: float = seed * 1.41 + float(row) * 9.73 + float(lane) * 4.17
				var offset: float = 0.045 * sin(unique * 1.47)
				var height_fraction: float = fposmod((float(row) + float(lane) * 0.27) / 11.0 + advance + offset, 1.0)
				var fade_top: float = 1.0 - smoothstep(0.67, 0.99, height_fraction)
				var fade_bottom: float = smoothstep(0.0, 0.045, height_fraction)
				var thin: float = fade_top * fade_bottom
				if thin < 0.015:
					continue
				var jitter: float = 0.045 * sin(unique + time * 1.2 + height_fraction * 7.0)
				var horizontal: float = (float(lane) - 1.5) * 0.19 + jitter
				var y: float = base.y - height_fraction * h
				# Keep each curl's TEXTURE footprint INSIDE the lane. Horizontal
				# centers end at +-0.34w, curl half-width <= 0.15w.
				var x: float = base.x + horizontal * w
				var center_weight: float = clampf(1.0 - absf(horizontal) * 2.25, 0.0, 1.0)
				var density: float = (0.78 + 0.22 * sin(unique * 2.3 + time * 5.0)) * thin * strength
				var cloud_width: float = w * (0.25 + 0.030 * sin(unique * 2.0))
				var cloud_height: float = h * (0.26 + 0.030 * sin(unique * 0.9))
				# Fire's OUTER curls are orange. Gray simply uses the ambient
				# gray tint and the identical physical cloud footprint.
				var fire_outer: Color = outer_color.lerp(body_color, clampf(0.40 + 0.33 * center_weight - 0.23 * height_fraction, 0.0, 1.0))
				var tint: Color = fog_color.lerp(fire_outer, heat)
				_cloud(Vector2(x, y), Vector2(cloud_width, cloud_height), tint,
					density * lerpf(0.23, 0.77, heat))

				# Yellow-hot INNER MASS: same individual smoke sprites, only
				# smaller and concentrated near the center, never a cone.
				if lane == 1 or lane == 2:
					var inner_mix: float = center_weight * (1.0 - 0.48 * height_fraction)
					var core_tint: Color = body_color.lerp(core_color, 0.63 + 0.37 * inner_mix)
					_cloud(Vector2(x + jitter * w * 0.15, y + h * 0.012),
						Vector2(cloud_width * 0.71, cloud_height * 0.76), core_tint,
						density * heat * 0.73 * inner_mix, true)

		# Continuous low foot merging the column into the ground fog, without
		# a rectangle-like solid horizontal base.
		for n in range(4):
			var dx: float = (float(n) - 1.5) * w * 0.17
			var foot_tint: Color = fog_color.lerp(body_color, heat)
			_cloud(base + Vector2(dx, -4.0 - 2.0 * sin(clock * 2.3 + seed + n)),
				Vector2(w * 0.29, h * 0.22), foot_tint,
				strength * 0.17)
			if heat > 0.05 and (n == 1 or n == 2):
				_cloud(base + Vector2(dx * 0.5, -7.0),
					Vector2(w * 0.20, h * 0.15), core_color,
					strength * heat * 0.66, true)

	func _dash_ribbon(b: Dictionary) -> void:
		# Ordinary dashes and the fiery Slam wave: contiguous low smoke along
		# the floor. This is NEVER the vertically spaced Fountain geometry.
		var t: float = clampf(float(b["age"]) / maxf(0.05, float(b["life"])), 0.0, 1.0)
		var ignition: float = smoothstep(0.0, 0.075, t)
		var cooling: float = 1.0 - smoothstep(0.43, 0.70, t)
		var heat: float = ignition * cooling
		var residue: float = smoothstep(0.36, 0.67, t) * (1.0 - smoothstep(0.84, 1.0, t))
		var sc: float = float(b["scale"]) * visual_scale
		var center: Vector2 = b["position"]
		var wind: float = -float(b["direction"]) * 12.0 * t
		var seed: float = float(b["phase"])
		var settle: float = smoothstep(0.48, 1.0, t)
		var y: float = center.y - dash_height * 0.23 * sc + settle * 9.0
		var w: float = dash_width * sc
		var h: float = dash_height * sc * (1.0 - 0.42 * settle)
		var orange: Color = outer_color.lerp(body_color, 0.54)
		# Three offset smoke curls per sample form ONE connected ribbon when
		# adjacent samples are spaced 22px apart. No rows, no pillars.
		for j in range(3):
			var shift: float = float(j - 1)
			var fuzz: float = sin(seed + float(j) * 2.4 + clock * 5.7)
			var spot: Vector2 = Vector2(center.x + wind + shift * w * 0.17 + fuzz * 2.6,
				y + float(abs(j - 1)) * 3.0 + fuzz * 3.0)
			_cloud(spot, Vector2(w * 0.79, h * 0.98), orange,
				heat * (0.43 if j == 1 else 0.32))
			_cloud(spot + Vector2(0.0, h * 0.12), Vector2(w * 0.62, h * 0.66), body_color,
				heat * (0.51 if j == 1 else 0.30))
			# Small, concentrated additive interior, not a glowing gray bank.
			_cloud(spot + Vector2(0.0, h * 0.13), Vector2(w * 0.37, h * 0.42), core_color,
				heat * (0.37 if j == 1 else 0.22), true)
			# The SAME texture gradually cools and sinks into gray fog.
			_cloud(spot + Vector2(0.0, -8.0 * (1.0 - settle)),
				Vector2(w * 0.85, h * 0.81), fog_color, residue * 0.18)

	func _draw() -> void:
		if smoke_texture == null:
			return
		# Existing gray slam waves use the SAME cloud texture as everything.
		for p: Dictionary in special_puffs:
			var settle: float = smoothstep(0.0, 0.48, float(p["settle_age"]))
			var x: Vector2 = p["position"]
			var sc: float = float(p["size"])
			var strength: float = smoothstep(0.0, 0.13, float(p["age"])) * (1.0 - settle)
			var swell: float = smoothstep(0.0, 0.78, float(p["age"]) / float(p["warning_time"]))
			var height: float = float(p["height"]) * lerpf(0.50, 1.0, swell) * lerpf(1.0, 0.28, settle)
			var width: float = 90.0 * sc * lerpf(0.84, 1.12, swell)
			var roll: float = sin(clock * 2.2 + x.x * 0.047)
			_cloud(x + Vector2(roll * 4.0, -height * (0.44 + 0.035 * roll)),
				Vector2(width, height), fog_color, strength * 0.35)
			_cloud(x + Vector2(19.0 * float(p["direction"]) - roll * 5.5, -height * 0.30),
				Vector2(width * 0.77, height * 0.78), fog_color, strength * 0.23)

		# Normal dash is a low, CONTINUOUS burning fog ribbon.
		# Special Fountain vents below remain deliberately separated.
		for b: Dictionary in bursts:
			_dash_ribbon(b)

		# FOUNTAIN: keep the SAME narrow gray updraft as its warning.
		# The hot phase is rendered by the V31 fire shader on matching
		# vertical surfaces, not by the older 44 cloud-stamp flame columns.
		for v: Dictionary in fountain_vents:
			var age: float = float(v["age"])
			var seed: float = float(v["phase"])
			var base: Vector2 = v["position"]
			var sc: float = float(v["height_scale"])
			var width: float = fountain_width
			var full_height: float = fountain_height * sc
			if age < ignite_delay + 0.12:
				var gray_in: float = smoothstep(0.0, 0.17, age) * (1.0 - smoothstep(ignite_delay, ignite_delay + 0.12, age))
				if not emissive_pass:
					for curl in range(9):
						var phase: float = fposmod(float(curl) / 9.0 + age * gray_rise_speed * 3.0 / full_height, 1.0)
						var envelope: float = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.64, 1.0, phase))
						var drift: float = sin(seed + phase * 6.0 + curl * 1.7) * width * 0.19
						var center: Vector2 = base + Vector2(drift, -phase * full_height)
						var size: Vector2 = Vector2(width * (1.32 - phase * 0.36), full_height * 0.39)
						_cloud(center, size, warning_smoke_color, gray_in * envelope * warning_smoke_alpha * gray_fountain_volume)
			else:
				# Cooling residue is gray again, never an orange cloud stamp.
				var hot_t: float = (age - ignite_delay) / maxf(0.08, float(v["flame_time"]))
				var cool: float = smoothstep(0.69, 0.94, hot_t) * (1.0 - smoothstep(1.04, 1.33, hot_t))
				if cool > 0.005:
					_plume(base, width, full_height * (1.0 - 0.30 * cool),
						seed, age, 0.0, cool * 0.40, 0.70,
						ignite_delay * gray_rise_speed + (age - ignite_delay) * fiery_rise_speed)



var _active: bool = false
var _elapsed: float = 0.0
var _left: float = -400.0
var _right: float = 400.0
var _reference_y: float = 400.0
var _boss: CharacterBody2D = null
var _terrain_points: PackedVector2Array = PackedVector2Array()
var _main_floor_y: float = 400.0
var _ground_anchor_check: float = 0.0
var _anchor_source: String = "terrain"
# Existing boss signal hooks and V15 warning timings remain untouched.
# V19 trail is strictly gated on an actual warned Level 3 dash movement.
const BOSS_MODE_WARNING: int = 2
const BOSS_MODE_STRIKE: int = 3
const BOSS_MODE_JUMP_SLAM: int = 9
var _previous_boss_mode: int = -1
var _puff_texture: Texture2D = null
var _back_layer: Node2D = null
var _persistent_bank_layer: Node2D = null
var _persistent_strips: Array[Polygon2D] = []
var _continuous_ground_bank: Polygon2D = null
var _warning_bank: Polygon2D = null
var _warning_upper_bank: Polygon2D = null
var _front_layer: Node2D = null
var _warning_layer: Node2D = null
var _back_puffs: Array[Sprite2D] = []
var _near_puffs: Array[Sprite2D] = []
var _high_puffs: Array[Sprite2D] = []
var _warning_puffs: Array[Sprite2D] = []
var _warning_wisp_details: Array[Sprite2D] = []
var _embers: Array[Dictionary] = []
var _ember_accumulator: float = 0.0
var _wave_edge: Sprite2D = null
var _wave_particles: CPUParticles2D = null
var _dash_particles: CPUParticles2D = null
var _fire_layer: DashSmokeExplosionRenderer = null
var _fire_glow_layer: DashSmokeExplosionRenderer = null
var _flame_bursts: Array[Dictionary] = []
var _flame_dash_tracking: bool = false
var _flame_dash_last_position: Vector2 = Vector2.ZERO
var _flame_dash_carry: float = 0.0
# One world-space ribbon per actual ordinary dash. Special Fountain vents use
# the existing (deliberately separated) renderer instead.
var _dash_fire_ribbons: Array[Dictionary] = []
var _active_dash_fire_ribbon: Dictionary = {}
var _dash_fire_ribbon_layer: Node2D = null
var _dash_ribbon_outer_shader: Shader = null
var _dash_ribbon_hot_shader: Shader = null
var _fountain_dash_armed: bool = false
var _fountain_index: int = 0
var _special_vents: Array[Dictionary] = []
var _special_smoke: Array[Dictionary] = []
var _slam_waves: Array[Dictionary] = []

# phase: 0 = resting, 1 = warning sweeping across the world, 2 = scattering
var _warning_phase: int = 0
var _warning_elapsed: float = 0.0
var _warning_duration: float = 0.70
# The strike we are warning about. Orange may start the tell one strike EARLY.
var _warning_target_combo_index: int = -1
var _warning_direction: float = 1.0
var _warning_front_x: float = -10000.0
var _warning_start_burst_done: bool = false
var _dash_origin: Vector2 = Vector2.ZERO
var _impact_point: Vector2 = Vector2(-10000.0, -10000.0)
var _impact_strength: float = 0.0
var _impact_particles_cd: float = 0.0

# Non-destructive camera shake: remember and remove ONLY the offset this
# controller applied, leaving Player/Camera2D camera follow behavior intact.
var _shake_camera: Camera2D = null
var _last_shake_applied: Vector2 = Vector2.ZERO
var _shake_remaining: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0


func configure_arena(left_x: float, right_x: float, boss: CharacterBody2D, terrain_mask: int = 1) -> void:
	_left = minf(left_x, right_x)
	_right = maxf(left_x, right_x)
	if _right - _left < 280.0:
		var center: float = (_left + _right) * 0.5
		_left = center - 400.0
		_right = center + 400.0
	_boss = boss
	if is_instance_valid(boss):
		_reference_y = boss.global_position.y + 35.0
	ground_collision_mask = terrain_mask


func _ready() -> void:
	# Parent is the LEVEL scene. This node uses world coordinates.
	top_level = true
	global_position = Vector2(0.0, fog_render_down_px)
	_puff_texture = _make_smoke_texture()
	# After the boss's default-priority physics step: sample its ACTUAL path.
	process_priority = 100

	_back_layer = Node2D.new()
	_back_layer.name = "AtmosphericMistBehindActors"
	_back_layer.z_index = -2
	add_child(_back_layer)

	# Solid translucent world-geometry backing makes the fog genuinely visible,
	# rather than relying on nearly invisible alpha in individual smoke puffs.
	_persistent_bank_layer = Node2D.new()
	_persistent_bank_layer.name = "WorldGroundFogBands"
	_persistent_bank_layer.z_index = -1
	add_child(_persistent_bank_layer)
	# One smoothly alpha-graded, sand-anchored strip, not four overlapping
	# wave polygons. The shader-free vertex gradient is cheap and reliable.
	_continuous_ground_bank = Polygon2D.new()
	_continuous_ground_bank.name = "V17ContinuousLowGrayMist"
	_persistent_bank_layer.add_child(_continuous_ground_bank)

	_front_layer = Node2D.new()
	_front_layer.name = "GroundMistAroundFeet"
	_front_layer.z_index = 1
	add_child(_front_layer)

	_warning_layer = Node2D.new()
	_warning_layer.name = "DensePreDashFog"
	# Behind combatants: dark fog is an ominous background telegraph,
	# never a black curtain in front of the boss or the player.
	_warning_layer.z_index = -1
	add_child(_warning_layer)

	# Fire stays visually BEHIND actors and over the gray background mist.
	_fire_layer = DashSmokeExplosionRenderer.new()
	_fire_layer.name = "ActualDashFierySmokeExplosions"
	_fire_layer.z_index = -1
	_fire_layer.smoke_texture = _puff_texture
	_fire_layer.visual_scale = flame_visual_scale
	_fire_layer.height_multiplier = flame_height_multiplier
	_fire_layer.outer_color = flame_outer_color
	_fire_layer.body_color = flame_body_color
	_fire_layer.core_color = flame_core_color
	add_child(_fire_layer)

	# Draw the SAME smoke geometry in a second CanvasItem, but emit only
	# the INNER yellow-hot curls using additive blending. This keeps orange
	# borders and gray post-flame smoke from becoming washed out.
	_fire_glow_layer = DashSmokeExplosionRenderer.new()
	_fire_glow_layer.name = "V29AdditiveFireCoresOnly"
	_fire_glow_layer.z_index = -1
	_fire_glow_layer.emissive_pass = true
	_fire_glow_layer.smoke_texture = _puff_texture
	var hot_material: CanvasItemMaterial = CanvasItemMaterial.new()
	hot_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fire_glow_layer.material = hot_material
	add_child(_fire_glow_layer)

	# The existing gray smoke texture now paints ALL flaming stages too.
	_fire_layer.normal_width = shader_fire_width_px
	_fire_layer.normal_height = shader_fire_height_px
	_fire_layer.gray_rise_speed = gray_plume_rise_speed
	_fire_layer.fiery_rise_speed = blazing_plume_rise_speed
	_fire_layer.fog_color = fog_color

	_setup_dash_fire_ribbon_layer()

	_warning_upper_bank = Polygon2D.new()
	_warning_upper_bank.name = "UnusedOldFogUpperBand"
	_warning_layer.add_child(_warning_upper_bank)
	_warning_bank = Polygon2D.new()
	_warning_bank.name = "UnusedOldFogCoreBand"
	_warning_layer.add_child(_warning_bank)

	_wave_edge = _create_puff(_warning_layer, "MovingWarningFront")
	_wave_edge.scale = Vector2(0.55, 0.27)
	_wave_edge.modulate.a = 0.0
	_wave_edge.visible = false

	_wave_particles = _create_particle_system(_warning_layer, "WarningCurlParticles", true)
	_wave_particles.emission_rect_extents = Vector2(9.0, 9.0)
	_wave_particles.amount = 37
	_wave_particles.lifetime = 0.55
	_wave_particles.emitting = false
	_wave_particles.color = Color(warning_tint.r, warning_tint.g, warning_tint.b, 0.18)

	_dash_particles = _create_particle_system(_front_layer, "DashDispersalParticles", false)
	_dash_particles.amount = 54
	_dash_particles.lifetime = 0.62
	_dash_particles.emission_rect_extents = Vector2(58.0, 20.0)
	_dash_particles.emitting = false

	visible = false
	set_process(false)


func _setup_dash_fire_ribbon_layer() -> void:
	# No WorldEnvironment is forced on the level. HDR glow is renderer-
	# dependent; additive hot cores must work even without postprocess bloom.
	_dash_ribbon_outer_shader = Shader.new()
	_dash_ribbon_outer_shader.code = DASH_RIBBON_SHADER
	_dash_ribbon_hot_shader = Shader.new()
	_dash_ribbon_hot_shader.code = DASH_RIBBON_SHADER.replace(
		"blend_mix", "blend_add")
	_dash_fire_ribbon_layer = Node2D.new()
	_dash_fire_ribbon_layer.name = "V30SeamlessOrdinaryDashFire"
	_dash_fire_ribbon_layer.z_index = -1
	add_child(_dash_fire_ribbon_layer)


func _new_dash_ribbon_surface(label: String, glowing: bool) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.name = label
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _dash_ribbon_hot_shader if glowing else _dash_ribbon_outer_shader
	material.set_shader_parameter("glow_pass", glowing)
	rect.material = material
	_dash_fire_ribbon_layer.add_child(rect)
	return rect


func _new_fire_pair(label: String) -> Dictionary:
	return {
		"main": _new_dash_ribbon_surface(label + "_OrangeFog", false),
		"hot": _new_dash_ribbon_surface(label + "_YellowCore", true)
	}


func _free_fire_pair(pair: Dictionary) -> void:
	for key in ["main", "hot"]:
		var surface: ColorRect = pair.get(key) as ColorRect
		if is_instance_valid(surface):
			surface.queue_free()


func _place_fire_pair(pair: Dictionary, left: float, top: float,
		width: float, height: float, heat: float, alpha: float,
		vertical: bool = false, ignition: float = 0.0) -> void:
	for key in ["main", "hot"]:
		var surface: ColorRect = pair.get(key) as ColorRect
		if not is_instance_valid(surface):
			continue
		surface.position = Vector2(left, top)
		surface.size = Vector2(maxf(2.0, width), maxf(2.0, height))
		var mat: ShaderMaterial = surface.material as ShaderMaterial
		mat.set_shader_parameter("world_left", left)
		mat.set_shader_parameter("world_width", width)
		mat.set_shader_parameter("fire_height", height)
		mat.set_shader_parameter("heat", heat)
		mat.set_shader_parameter("opacity", alpha)
		mat.set_shader_parameter("intensity", normal_dash_core_brightness)
		mat.set_shader_parameter("vertical_plume", vertical)
		mat.set_shader_parameter("ignition", ignition)
		surface.visible = not (key == "hot" and not additive_hot_core_enabled)


func _begin_dash_fire_ribbon(position_x: float) -> void:
	if not flaming_dash_fog_enabled or not is_instance_valid(_dash_fire_ribbon_layer):
		return
	_finish_dash_fire_ribbon()
	_active_dash_fire_ribbon = _new_fire_ribbon(position_x, "NormalDash")


func _new_fire_ribbon(start_x: float, label: String) -> Dictionary:
	var pair: Dictionary = _new_fire_pair(label)
	var ribbon: Dictionary = {
		"min_x": start_x,
		"max_x": start_x,
		"finished": false,
		"burn_age": 0.0,
		"after": 0.0,
		"main": pair["main"],
		"hot": pair["hot"]
	}
	_dash_fire_ribbons.append(ribbon)
	return ribbon


func _extend_dash_fire_ribbon(x: float) -> void:
	if _active_dash_fire_ribbon.is_empty():
		return
	_active_dash_fire_ribbon["min_x"] = minf(float(_active_dash_fire_ribbon["min_x"]), x)
	_active_dash_fire_ribbon["max_x"] = maxf(float(_active_dash_fire_ribbon["max_x"]), x)


func _finish_dash_fire_ribbon() -> void:
	if _active_dash_fire_ribbon.is_empty():
		return
	_active_dash_fire_ribbon["finished"] = true
	_active_dash_fire_ribbon["after"] = 0.0
	_active_dash_fire_ribbon = {}


func _update_dash_fire_ribbons(delta: float) -> void:
	# A ribbon is one connected field from its first position to its last.
	# Fire slowly cools to gray and sinks when the actual dash ends.
	for i in range(_dash_fire_ribbons.size() - 1, -1, -1):
		var r: Dictionary = _dash_fire_ribbons[i]
		r["burn_age"] = float(r["burn_age"]) + delta
		var ended: bool = bool(r["finished"])
		if ended:
			r["after"] = float(r["after"]) + delta
		var after: float = float(r["after"])
		var settle: float = maxf(0.2, normal_dash_smoke_settle_seconds)
		if ended and after > settle:
			for key in ["main", "hot"]:
				var surface: ColorRect = r[key]
				if is_instance_valid(surface):
					surface.queue_free()
			_dash_fire_ribbons.remove_at(i)
			continue
		var heat: float = (1.0 - smoothstep(0.18 * settle, 0.69 * settle, after)) if ended else 1.0
		var opacity: float = (1.0 - smoothstep(0.55 * settle, settle, after)) if ended else 1.0
		var x0: float = float(r["min_x"])
		var x1: float = float(r["max_x"])
		var margin: float = normal_dash_fire_width_px * 0.35
		var left_edge: float = x0 - margin
		var width: float = maxf(3.0, x1 - x0 + margin * 2.0)
		var floor_y: float = _floor_y_at((x0 + x1) * 0.5)
		var sink: float = smoothstep(0.30 * settle, settle, after) if ended else 0.0
		var height: float = maxf(18.0, normal_dash_fire_height_px * (1.0 - 0.32 * sink))
		for key in ["main", "hot"]:
			var surface: ColorRect = r[key]
			if not is_instance_valid(surface):
				continue
			surface.position = Vector2(left_edge, floor_y - height + 2.0)
			surface.size = Vector2(width, height)
			var m: ShaderMaterial = surface.material as ShaderMaterial
			m.set_shader_parameter("world_left", left_edge)
			m.set_shader_parameter("world_width", width)
			m.set_shader_parameter("fire_height", height)
			m.set_shader_parameter("heat", heat)
			m.set_shader_parameter("ignition", 1.0 - smoothstep(0.02, 0.18, float(r["burn_age"])))
			m.set_shader_parameter("opacity", opacity * normal_dash_fire_opacity)
			m.set_shader_parameter("intensity", normal_dash_core_brightness)
			m.set_shader_parameter("slam_direction", float(r.get("slam_direction", 0.0)))
			surface.visible = not (key == "hot" and not additive_hot_core_enabled)


func _spawn_dash_trail_sparks(at_x: float, direction: float) -> void:
	var base_y: float = _floor_y_at(at_x)
	for j in range(dash_sparks_per_sample):
		var at: Vector2 = Vector2(at_x + randf_range(-15.0, 15.0),
			base_y - randf_range(5.0, normal_dash_fire_height_px * 0.75))
		var speed: Vector2 = Vector2(-direction * randf_range(15.0, 95.0),
			-randf_range(22.0, 140.0))
		_spawn_ember(at, speed)


func _sync_procedural_fire() -> void:
	# Both passes receive identical plume geometry; only blend mode and
	# selected portions differ. No damage, timing, or attack-state changes.
	for painter: DashSmokeExplosionRenderer in [_fire_layer, _fire_glow_layer]:
		if not is_instance_valid(painter):
			continue
		painter.bursts = _flame_bursts
		painter.fountain_vents = _special_vents
		painter.special_puffs = _special_smoke
		painter.ignite_delay = v25_fountain_gray_hold
		painter.gray_fountain_volume = v25_fountain_gray_volume
		painter.special_fire_scale = v25_special_fire_size
		painter.visual_scale = flame_visual_scale
		painter.height_multiplier = flame_height_multiplier
		painter.outer_color = flame_outer_color
		painter.body_color = flame_body_color
		painter.core_color = flame_core_color
		painter.normal_width = shader_fire_width_px
		painter.normal_height = shader_fire_height_px
		painter.dash_width = normal_dash_fire_width_px
		painter.dash_height = normal_dash_fire_height_px
		painter.warning_smoke_color = warning_tint
		painter.warning_smoke_alpha = warning_density * warning_puff_alpha * natural_warning_smoke_density
		painter.fountain_width = fountain_visual_width_px
		painter.fountain_height = fountain_visual_height_px
		painter.gray_rise_speed = gray_plume_rise_speed
		painter.fiery_rise_speed = blazing_plume_rise_speed
		painter.fog_color = fog_color
		painter.clock = _elapsed
		painter.visible = (not painter.emissive_pass) or additive_hot_core_enabled
		painter.queue_redraw()


func _make_smoke_texture() -> Texture2D:
	# Generated irregular smoke sprite. No external assets, no solid oval:
	# multiple warped noise layers break the silhouette and create transparent
	# holes and curls. All smoke uses this one texture, in different sizes.
	var primary: FastNoiseLite = FastNoiseLite.new()
	primary.seed = 42071
	primary.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	primary.frequency = 0.028
	var details: FastNoiseLite = FastNoiseLite.new()
	details.seed = 99183
	details.noise_type = FastNoiseLite.TYPE_PERLIN
	details.frequency = 0.062
	var wide: int = 192
	var tall: int = 136
	var image: Image = Image.create(wide, tall, false, Image.FORMAT_RGBA8)
	for y in range(tall):
		for x in range(wide):
			var xx: float = (float(x) - float(wide - 1) * 0.5) / (float(wide) * 0.5)
			var yy: float = (float(y) - float(tall - 1) * 0.5) / (float(tall) * 0.5)
			var warp_x: float = primary.get_noise_2d(float(x) + 82.0, float(y) * 0.87) * 0.28
			var warp_y: float = primary.get_noise_2d(float(x) * 0.8, float(y) - 53.0) * 0.24
			var radial: float = sqrt(pow(xx + warp_x, 2.0) * 0.90 + pow(yy + warp_y, 2.0) * 1.13)
			var edge: float = 1.0 - smoothstep(0.47, 1.05, radial)
			var large_noise: float = (primary.get_noise_2d(float(x) * 1.34, float(y) * 1.22) + 1.0) * 0.5
			var fine_noise: float = (details.get_noise_2d(float(x) * 1.8 + 13.0, float(y) * 1.6) + 1.0) * 0.5
			var hole: float = smoothstep(0.26, 0.78, large_noise * 0.84 + fine_noise * 0.16)
			var opacity: float = edge * hole * (0.60 + large_noise * 0.62)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(opacity, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _create_puff(parent: Node2D, label: String) -> Sprite2D:
	var puff: Sprite2D = Sprite2D.new()
	puff.name = label
	puff.texture = _puff_texture
	puff.centered = true
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(puff)
	return puff


func _create_particle_system(parent: Node2D, label: String, continuous: bool) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = label
	p.texture = _puff_texture
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	p.emitting = false
	p.one_shot = not continuous
	p.explosiveness = 0.0 if continuous else 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.gravity = Vector2(0.0, -20.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 80.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 0.20
	p.scale_amount_max = 0.48
	p.color = Color(0.43, 0.45, 0.48, 0.30)
	parent.add_child(p)
	return p


func activate() -> void:
	if _active:
		return
	_active = true
	_elapsed = 0.0
	# Warning is a denser version of the same ambient fog color.
	warning_tint = fog_color
	visible = true
	_warning_phase = 0
	_warning_elapsed = 0.0
	_warning_target_combo_index = -1
	_flame_dash_tracking = false
	_flame_bursts.clear()
	_flame_dash_carry = 0.0
	_sync_procedural_fire()
	if is_instance_valid(_fire_layer):
		_fire_layer.bursts = _flame_bursts
		_fire_layer.queue_redraw()
	_previous_boss_mode = int(_boss.get("mode")) if is_instance_valid(_boss) else -1
	_shake_remaining = 0.0
	_shake_strength = 0.0
	_sample_main_ground()
	# Capture a valid floor contact before building the initial fog geometry.
	_refresh_ground_contact_anchor()
	_build_puffs()
	_render_fog_banks(0.0)
	set_process(true)
	if debug_fog_output:
		print("[MenacingFog V30] ACTIVE: seamless dash fire + additive core! Boss:",
			_boss.name if is_instance_valid(_boss) else "missing",
			"  bounds=[", snappedf(_left, 1.0), ",", snappedf(_right, 1.0),
			"] ground at boss=", snappedf(_floor_y_at(_boss.global_position.x if is_instance_valid(_boss) else (_left + _right) * 0.5), 1.0),
			"  puffs=", _near_puffs.size(), "  main floor y=", _main_floor_y,
			"  height=", ambient_fog_height_px, "px  anchor=", _anchor_source,
			"  expected ground Y=", snappedf(_reference_y, 1.0))
	if show_test_warning_on_start:
		warn_before_dash(1.15, 1.0)


func deactivate() -> void:
	_clear_camera_shake()
	_active = false
	_flame_dash_tracking = false
	_finish_dash_fire_ribbon()
	for r: Dictionary in _dash_fire_ribbons:
		for key in ["main", "hot"]:
			var item: ColorRect = r[key]
			if is_instance_valid(item):
				item.queue_free()
	_dash_fire_ribbons.clear()
	for vent: Dictionary in _special_vents:
		if vent.has("fire_pair"):
			_free_fire_pair(vent["fire_pair"])
	_special_vents.clear()
	_slam_waves.clear()
	_special_smoke.clear()
	_flame_bursts.clear()
	_sync_procedural_fire()
	if is_instance_valid(_fire_layer):
		_fire_layer.bursts = _flame_bursts
		_fire_layer.queue_redraw()
	_warning_phase = 0
	visible = false
	set_process(false)
	if is_instance_valid(_wave_particles):
		_wave_particles.emitting = false
	_embers.clear()
	queue_redraw()


func _sample_main_ground() -> void:
	# Follow the TOP of the main sand surface, not the deepest hit inside the
	# TileMap. V8 chose maximum world Y, which buried the fog hundreds of pixels.
	_terrain_points.clear()
	var count: int = clampi(ceili((_right - _left) / maxf(25.0, puff_spacing)) + 1, 14, 95)
	var hits: Array[float] = []
	for i in range(count):
		var x: float = lerpf(_left, _right, float(i) / float(count - 1))
		hits.append(_find_main_floor_y(x))

	# The median resists stray cactus/platform hits and still follows the flat
	# sand surface when the camera moves horizontally through the arena.
	var sorted_hits: Array[float] = hits.duplicate()
	sorted_hits.sort()
	_main_floor_y = sorted_hits[int(sorted_hits.size() / 2)]
	_anchor_source = "nearest sand surface"
	var tolerance: float = maxf(0.0, main_floor_max_height_difference_px)
	for i in range(count):
		var x: float = lerpf(_left, _right, float(i) / float(count - 1))
		var y: float = _main_floor_y + clampf(hits[i] - _main_floor_y, -tolerance, tolerance)
		_terrain_points.append(Vector2(x, y))


func _find_main_floor_y(x: float) -> float:
	# The real sand surface is close to the standing boss's feet, approximated
	# by configure_arena() as boss.global_position.y + 35.0. Do NOT shoot an
	# 850px ray and select its deepest collision: that's inside/under the sand.
	var expected: float = _reference_y
	var from_world: Vector2 = Vector2(x, expected - 170.0)
	var to_world: Vector2 = Vector2(x, expected + 85.0)
	var excluded: Array[RID] = []
	if is_instance_valid(_boss):
		excluded.append(_boss.get_rid())
	var best_floor: float = expected
	var best_distance: float = 1000000.0
	for attempt in range(18):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			from_world, to_world, ground_collision_mask
		)
		query.exclude = excluded
		query.collide_with_areas = false
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider") as Object
		var rid: RID = hit.get("rid", RID())
		var spot: Vector2 = hit.get("position", Vector2(x, expected))
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		var distance: float = absf(spot.y - expected)
		# Only upward-facing floor surfaces near the arena's real floor are
		# eligible. Ignore elevated platforms, cactus tops, steep walls,
		# underside collisions, and surfaces deep below the visible sand.
		if normal.y < -0.50 and distance <= 60.0:
			if not (collider is CharacterBody2D or
				(collider is Node and (collider as Node).is_in_group("menacing_arena_platform"))):
				if distance < best_distance:
					best_distance = distance
					best_floor = spot.y
		if not rid.is_valid() or excluded.has(rid):
			break
		excluded.append(rid)
	return best_floor


func _body_floor_contact_y(body: CharacterBody2D) -> float:
	if not is_instance_valid(body) or not body.is_on_floor():
		return -100000000.0
	# First choice: contact point from the actual physics collision.
	for i in range(body.get_slide_collision_count()):
		var contact: KinematicCollision2D = body.get_slide_collision(i)
		if contact != null and contact.get_normal().y < -0.65:
			return contact.get_position().y
	# Fallback: transformed bottom of the real body collider, not the art.
	for node: Node in body.get_children():
		if node is CollisionShape2D:
			var collider: CollisionShape2D = node as CollisionShape2D
			if collider.disabled or collider.shape == null:
				continue
			var half_height: float = 0.0
			if collider.shape is CapsuleShape2D:
				half_height = (collider.shape as CapsuleShape2D).height * 0.5
			elif collider.shape is RectangleShape2D:
				half_height = (collider.shape as RectangleShape2D).size.y * 0.5
			elif collider.shape is CircleShape2D:
				half_height = (collider.shape as CircleShape2D).radius
			if half_height > 0.0:
				return collider.to_global(Vector2(0.0, half_height)).y
		elif node is CollisionPolygon2D:
			var poly: CollisionPolygon2D = node as CollisionPolygon2D
			if poly.disabled:
				continue
			var bottom: float = -100000000.0
			for vertex: Vector2 in poly.polygon:
				bottom = maxf(bottom, poly.to_global(vertex).y)
			return bottom
	return -100000000.0


func _refresh_ground_contact_anchor() -> void:
	if not use_player_floor_anchor:
		return
	var root: Node = get_tree().current_scene
	if not is_instance_valid(root):
		return
	var player: CharacterBody2D = root.find_child("Player", true, false) as CharacterBody2D
	var player_floor: float = _body_floor_contact_y(player)
	var boss_floor: float = _body_floor_contact_y(_boss)

	# A platform, airborne animation, or deep terrain contact must NEVER
	# drag the whole mist sheet away from the sand. Accept grounded character
	# feet only when they're already close to the sampled ground surface.
	var closest_floor: float = _main_floor_y
	var closest_diff: float = 26.0
	for candidate: float in [player_floor, boss_floor]:
		if candidate <= -99999999.0:
			continue
		var difference: float = absf(candidate - _main_floor_y)
		if difference < closest_diff:
			closest_diff = difference
			closest_floor = candidate
	var offset: float = closest_floor - _main_floor_y
	if absf(offset) < 1.5:
		return
	_main_floor_y = closest_floor
	for i in range(_terrain_points.size()):
		var point: Vector2 = _terrain_points[i]
		_terrain_points[i] = Vector2(point.x, point.y + offset)
	_anchor_source = "nearby grounded foot"
	if print_floor_debug:
		print("[MenacingFog V13] Sand surface adjusted by ", snappedf(offset, 1.0),
			" px; world Y=", snappedf(_main_floor_y, 1.0))


func _build_puffs() -> void:
	for puff: Sprite2D in _back_puffs:
		puff.queue_free()
	for puff: Sprite2D in _near_puffs:
		puff.queue_free()
	for puff: Sprite2D in _high_puffs:
		puff.queue_free()
	for puff: Sprite2D in _warning_puffs:
		puff.queue_free()
	for puff: Sprite2D in _warning_wisp_details:
		puff.queue_free()
	_back_puffs.clear()
	_near_puffs.clear()
	_high_puffs.clear()
	_warning_puffs.clear()
	_warning_wisp_details.clear()

	var height_ratio: float = maxf(0.35, ambient_fog_height_px / 28.0)
	for i in range(_terrain_points.size()):
		var ground: Vector2 = _terrain_points[i]
		var variation: float = float(i)
		# Deterministic per-cloud variation: no perfectly repeated parallel bands.
		var r1: float = sin(variation * 2.351 + 0.41)
		var r2: float = sin(variation * 3.761 + 1.82)
		var r3: float = sin(variation * 1.847 + 5.31)

		var distant: Sprite2D = _create_puff(_back_layer, "HighWisp_%d" % i)
		distant.scale = Vector2(0.71 + 0.24 * r1, (0.15 + 0.035 * r2) * height_ratio)
		distant.position = ground + Vector2(11.0 * r2, -ambient_fog_height_px * 0.71)
		_high_puffs.append(distant)

		var back: Sprite2D = _create_puff(_back_layer, "RollingWisp_%d" % i)
		back.scale = Vector2(1.05 + 0.30 * r1, (0.28 + 0.043 * r3) * height_ratio)
		back.position = ground + Vector2(18.0 * r1, -ambient_fog_height_px * 0.36)
		_back_puffs.append(back)

		var near: Sprite2D = _create_puff(_front_layer, "GroundWisp_%d" % i)
		near.scale = Vector2(0.95 + 0.24 * r2, (0.20 + 0.036 * r1) * height_ratio)
		near.position = ground + Vector2(-18.0 * r3, -ambient_fog_height_px * 0.19)
		_near_puffs.append(near)

		var warning: Sprite2D = _create_puff(_warning_layer, "RollingDashCloud_%d" % i)
		var w_height: float = warning_height_above_ground / 60.0
		warning.scale = Vector2(1.34 + 0.32 * r2, (0.49 + 0.10 * r1) * w_height)
		warning.position = ground + Vector2(16.0 * r1, -warning_height_above_ground * 0.35)
		warning.modulate.a = 0.0
		_warning_puffs.append(warning)

		# Secondary, lighter smoke curl: offset and different animation speed.
		var detail: Sprite2D = _create_puff(_warning_layer, "CurlingDashWisp_%d" % i)
		detail.scale = Vector2(0.79 + 0.22 * r3, (0.35 + 0.06 * r2) * w_height)
		detail.position = ground + Vector2(-19.0 * r2, -warning_height_above_ground * 0.53)
		detail.modulate.a = 0.0
		_warning_wisp_details.append(detail)


func warn_before_dash(warning_seconds: float, dash_direction: float = 1.0, upcoming_combo_index: int = -1) -> void:
	if not _active:
		return
	# Orange forecasts its middle dash during the opener, then calls again
	# at the beginning of the follow-up WARNING. Never restart that sweep.
	if _warning_phase == 1 and _warning_target_combo_index == upcoming_combo_index:
		_warning_duration = maxf(_warning_duration, _warning_elapsed + maxf(0.0, warning_seconds))
		return
	_warning_phase = 1
	_warning_elapsed = 0.0
	_warning_bank.position = Vector2.ZERO
	_warning_upper_bank.position = Vector2.ZERO
	_warning_duration = maxf(0.12, warning_seconds)
	_warning_target_combo_index = upcoming_combo_index
	_warning_direction = 1.0 if dash_direction >= 0.0 else -1.0
	_warning_front_x = (_left - 140.0) if _warning_direction > 0.0 else (_right + 140.0)
	_warning_start_burst_done = false
	_dash_origin = _boss.global_position if is_instance_valid(_boss) else Vector2((_left + _right) * 0.5, _reference_y)
	# No premature leading-edge particles during the fog-only visual delay.
	_wave_edge.visible = false
	_wave_particles.direction = Vector2(-_warning_direction, -0.2)
	_wave_particles.emitting = false
	if debug_fog_output:
		print("[MenacingFog V15] Dash windup unchanged. Fog visible after:",
			fog_visual_delay_v15, "s; next combo hit:", upcoming_combo_index,
			"  original windup:", warning_seconds)


func arm_fountain_dash() -> void:
	if not _active:
		return
	_fountain_dash_armed = true
	_fountain_index = 0


func start_ground_slam_waves(world_position: Vector2) -> void:
	if not _active:
		return
	# Independent gray left/right fronts; V25 fire follows only after readable buildup.
	for direction in [-1.0, 1.0]:
		var max_distance: float = (world_position.x - _left) if direction < 0.0 else (_right - world_position.x)
		_slam_waves.append({
			"x": world_position.x,
			"direction": direction,
			"age": 0.0,
			"distance": maxf(0.0, max_distance),
			"gray_next": 0.0,
			"fire_next": 0.0
		})
	disturb_at(world_position, 1.7)


func is_fog_fire_hazard_at(world_position: Vector2) -> bool:
	if not _active:
		return false
	var height_above_floor: float = _floor_y_at(world_position.x) - world_position.y
	for w: Dictionary in _slam_waves:
		var a: float = float(w["age"])
		if a < v25_slam_fire_delay:
			continue
		var fire_dist: float = minf(float(w["distance"]), (a - v25_slam_fire_delay) * v25_slam_gray_wave_speed)
		var front_x: float = float(w["x"]) + float(w["direction"]) * fire_dist
		var behind_tip: float = (front_x - world_position.x) * float(w["direction"])
		var hot_depth: float = minf(44.0, slam_fire_front_tail_px * 0.5)
		if fire_dist <= 8.0 or behind_tip < 0.0 or behind_tip > minf(hot_depth, fire_dist):
			continue
		var hot_height: float = normal_dash_fire_height_px * lerpf(0.10, 0.38, behind_tip / hot_depth)
		if height_above_floor >= -8.0 and height_above_floor <= hot_height:
			return true
	for v: Dictionary in _special_vents:
		var a: float = float(v["age"])
		if a >= v25_fountain_gray_hold and a <= v25_fountain_gray_hold + fountain_vent_flame_seconds * 0.82:
			if absf(world_position.x - Vector2(v["position"]).x) < fountain_visual_width_px * 0.48 and height_above_floor >= -15.0 and height_above_floor <= fountain_visual_height_px * float(v["height_scale"]) * 0.85:
				return true
	return false


func dash_started(world_position: Vector2, dash_direction: float = 1.0) -> void:
	# V19: this is the existing boss's REAL dash callback, not a warning.
	# Flames are only spawned after the boss physically travels, sampled below.
	if not _active:
		return
	if flaming_dash_fog_enabled and is_instance_valid(_boss):
		if int(_boss.get("mode")) == BOSS_MODE_STRIKE and float(_boss.get("strike_dash_distance")) > 0.0:
			if not _flame_dash_tracking:
				_flame_dash_tracking = true
				_flame_dash_last_position = _boss.global_position
				_flame_dash_carry = 0.0
				if not _fountain_dash_armed:
					_begin_dash_fire_ribbon(_boss.global_position.x)
	# The V42 boss may notify the same dash after this controller already
	# detected WARNING -> STRIKE. Avoid resetting the fade or spawning twice.
	if _warning_phase != 1:
		_impact_point = world_position
		_impact_strength = maxf(_impact_strength, 0.85)
		return
	_warning_phase = 2
	_warning_elapsed = 0.0
	_warning_direction = 1.0 if dash_direction >= 0.0 else -1.0
	_dash_origin = world_position
	_wave_edge.visible = false
	_wave_particles.emitting = false
	_warning_start_burst_done = false
	_impact_point = world_position
	_impact_strength = 1.3
	_emit_dash_smoke(world_position, _warning_direction)
	if ember_rate_multiplier > 0.0:
		for i in range(dash_ember_burst_count):
			var pos: Vector2 = world_position + Vector2(randf_range(-35.0, 35.0), randf_range(-30.0, 8.0))
			_spawn_ember(pos, Vector2(-_warning_direction * randf_range(30.0, 105.0), -randf_range(15.0, 110.0)))


func disturb_at(world_position: Vector2, power: float = 1.0) -> void:
	if not _active:
		return
	# Sword impacts and fast movement push existing mist OUT of the way.
	# Do not create fresh thick clouds during the slash; the dense fog is
	# exclusively the pre-slash telegraph, dispersed by dash_started().
	_impact_point = world_position
	_impact_strength = maxf(_impact_strength, clampf(power, 0.0, 1.5))


func _emit_dash_smoke(world_position: Vector2, direction: float) -> void:
	_dash_particles.global_position = world_position + Vector2(0.0, -13.0)
	_dash_particles.direction = Vector2(-direction, -0.25)
	_dash_particles.emitting = false
	_dash_particles.restart()
	_dash_particles.emitting = true


func _floor_y_at(world_x: float) -> float:
	if _terrain_points.is_empty():
		return _reference_y
	var size: int = _terrain_points.size()
	if world_x <= _terrain_points[0].x:
		return _terrain_points[0].y
	if world_x >= _terrain_points[size - 1].x:
		return _terrain_points[size - 1].y
	var t: float = clampf((world_x - _left) / maxf(1.0, _right - _left) * float(size - 1), 0.0, float(size - 1))
	var index: int = mini(floori(t), size - 2)
	return lerpf(_terrain_points[index].y, _terrain_points[index + 1].y, t - float(index))


func _physics_process(_delta: float) -> void:
	# Fires ONLY where the boss really MOVES DURING A REAL LEVEL 3 DASH.
	# WARNING, standing sword strikes, jump slams, purple/green non-dashes,
	# and after-dash recovery never spawn flame bursts.
	if not _active or not flaming_dash_fog_enabled or not _flame_dash_tracking:
		return
	if not is_instance_valid(_boss) or int(_boss.get("mode")) != BOSS_MODE_STRIKE:
		_flame_dash_tracking = false
		_finish_dash_fire_ribbon()
		_fountain_dash_armed = false
		return
	var dash_duration: float = float(_boss.get("strike_dash_seconds"))
	var elapsed: float = float(_boss.get("strike_elapsed"))
	var traveled_range: float = float(_boss.get("strike_dash_distance"))
	if dash_duration <= 0.0 or traveled_range <= 0.0 or elapsed > dash_duration + 0.025:
		_flame_dash_tracking = false
		_finish_dash_fire_ribbon()
		_fountain_dash_armed = false
		return
	var current_position: Vector2 = _boss.global_position
	var movement: Vector2 = current_position - _flame_dash_last_position
	var length: float = movement.length()
	if length <= 1.0:
		return
	# Interpolate every spacing pixels so even supersonic 2000+ px/s dashes
	# leave CONTINUOUS explosions instead of one burst per physics tick.
	var spacing: float = maxf(12.0, v25_fountain_spacing if _fountain_dash_armed else flame_trail_spacing)
	var distance_to_next: float = spacing - _flame_dash_carry
	while distance_to_next <= length:
		var point: Vector2 = _flame_dash_last_position.lerp(current_position, distance_to_next / length)
		if point.x >= _left - 25.0 and point.x <= _right + 25.0:
			if _fountain_dash_armed:
				_spawn_special_vent(point.x)
			else:
				_spawn_dash_trail_sparks(point.x, signf(movement.x) if absf(movement.x) > 0.1 else 1.0)
		distance_to_next += spacing
	_flame_dash_carry = fposmod(_flame_dash_carry + length, spacing)
	if not _fountain_dash_armed:
		_extend_dash_fire_ribbon(current_position.x)
	_flame_dash_last_position = current_position


func _spawn_flame_burst(at_x: float, direction: float) -> void:
	# Ground-anchored fiery recolor of the SAME gray fog; no pointed flames.
	var base: Vector2 = Vector2(at_x, _floor_y_at(at_x) - 8.0)
	if _flame_bursts.size() >= flame_max_bursts:
		_flame_bursts.remove_at(0)
	_flame_bursts.append({
		"position": base,
		"direction": direction,
		"age": 0.0,
		"life": flame_burst_lifetime * randf_range(0.75, 1.22),
		"scale": randf_range(0.72, 1.08),
		"phase": randf_range(0.0, TAU),
		"smoke_offset_y": -25.0,
		"smoke_velocity_y": randf_range(-85.0, -40.0)
	})
	# Short bright fragments, pushed backward by the boss's dash pressure.
	for i in range(flame_sparks_per_burst):
		var pos: Vector2 = base + Vector2(randf_range(-26.0, 26.0), -randf_range(2.0, 57.0))
		var horizontal: float = -direction * randf_range(45.0, 185.0) + randf_range(-20.0, 20.0)
		_spawn_ember(pos, Vector2(horizontal, -randf_range(42.0, 170.0)))


func _spawn_special_vent(at_x: float) -> void:
	# Alternating offset/height to make an interleaved series of narrow fog
	# columns. They ignite only after V25 hold, leaving enough time to read the gray vent.
	if _fountain_index >= fountain_max_vents_per_dash:
		return
	var sign_y: float = -1.0 if _fountain_index % 2 == 0 else 1.0
	_fountain_index += 1
	# Farther apart, with alternating lean and height. Actual damage X uses
	# these exact locations, not the original, more crowded dash sample.
	var x: float = clampf(at_x + sign_y * 16.0, _left + 12.0, _right - 12.0)
	if _special_vents.size() >= 36:
		_special_vents.remove_at(0)
	_special_vents.append({
		"position": Vector2(x, _floor_y_at(x) - 3.0),
		"age": 0.0,
		"phase": randf_range(0.0, TAU),
		"lean": sign_y,
		"height_scale": 0.94 if sign_y < 0.0 else 1.10,
		"flame_time": fountain_vent_flame_seconds,
		"lit": false
	})


func _spawn_special_gray_puff(at_x: float, direction: float, sweep_progress: float) -> void:
	# A second sweep can replenish smoke already standing on the same ground.
	for puff: Dictionary in _special_smoke:
		if absf(Vector2(puff["position"]).x - at_x) < 21.0:
			puff["settle_age"] = 0.0
			puff["height"] = maxf(float(puff["height"]), warning_height_above_ground * lerpf(0.78, 1.66, sweep_progress))
			return
	if _special_smoke.size() >= max_special_smoke_puffs:
		_special_smoke.remove_at(0)
	_special_smoke.append({
		"position": Vector2(at_x, _floor_y_at(at_x) - 3.0),
		"direction": direction,
		"age": 0.0,
		"settle_age": 0.0,
		"warning_time": maxf(0.05, v25_slam_fire_delay),
		"height": warning_height_above_ground * lerpf(0.78, 1.66, sweep_progress),
		"size": randf_range(1.00, 1.23)
	})


func _update_last_judge_specials(delta: float) -> void:
	for i in range(_slam_waves.size() - 1, -1, -1):
		var w: Dictionary = _slam_waves[i]
		w["age"] = float(w["age"]) + delta
		var age: float = float(w["age"])
		var max_distance: float = float(w["distance"])
		var gray_distance: float = minf(max_distance, age * v25_slam_gray_wave_speed)
		var fire_distance: float = minf(max_distance, maxf(0.0, age - v25_slam_fire_delay) * v25_slam_gray_wave_speed)
		var dir: float = float(w["direction"])
		# Gray wave arrives FIRST; fire waits V25 delay so the telegraph is visible.
		while float(w["gray_next"]) <= gray_distance:
			var x: float = float(w["x"]) + dir * float(w["gray_next"])
			var sweep_progress: float = float(w["gray_next"]) / maxf(45.0, max_distance)
			_spawn_special_gray_puff(x, dir, sweep_progress)
			w["gray_next"] = float(w["gray_next"]) + maxf(45.0, (_right - _left) / maxf(1.0, max_special_smoke_puffs - 2.0))
		if age >= v25_slam_fire_delay and fire_distance > 2.0:
			# The Slam ribbon uses a more irregular flame crest.
			# One ribbon per left/right burning wave, not repeated flame stamps.
			if not w.has("fire_ribbon"):
				w["fire_ribbon"] = _new_fire_ribbon(float(w["x"]), "SlamWave")
				w["fire_ribbon"]["slam_direction"] = dir
			var sr: Dictionary = w["fire_ribbon"]
			var front_x: float = float(w["x"]) + dir * fire_distance
			# Keep the bright front near the actual damaging wave instead
			# of lighting the entire traversed arena after it has passed.
			var tail_x: float = front_x - dir * slam_fire_front_tail_px
			if dir > 0.0:
				tail_x = maxf(float(w["x"]), tail_x)
			else:
				tail_x = minf(float(w["x"]), tail_x)
			sr["min_x"] = minf(tail_x, front_x)
			sr["max_x"] = maxf(tail_x, front_x)
			# Sparks follow the leading edge, not the full width of the fire.
			while float(w["fire_next"]) <= fire_distance:
				var fx: float = float(w["x"]) + dir * float(w["fire_next"])
				_spawn_dash_trail_sparks(fx, dir)
				w["fire_next"] = float(w["fire_next"]) + 78.0
		if age >= max_distance / maxf(1.0, v25_slam_gray_wave_speed) + v25_slam_fire_delay + 0.15:
			if w.has("fire_ribbon"):
				var sr_end: Dictionary = w["fire_ribbon"]
				sr_end["finished"] = true
				sr_end["after"] = 0.0
			_slam_waves.remove_at(i)

	var hold_slam_fog: bool = not _slam_waves.is_empty()
	if not hold_slam_fog:
		for ribbon: Dictionary in _dash_fire_ribbons:
			if ribbon.has("slam_direction"):
				hold_slam_fog = true
				break
	for i in range(_special_smoke.size() - 1, -1, -1):
		var s: Dictionary = _special_smoke[i]
		s["age"] = float(s["age"]) + delta
		if not hold_slam_fog:
			s["settle_age"] = float(s["settle_age"]) + delta
		if float(s["settle_age"]) >= 0.48:
			_special_smoke.remove_at(i)

	for i in range(_special_vents.size() - 1, -1, -1):
		var v: Dictionary = _special_vents[i]
		var previous_age: float = float(v["age"])
		var new_age: float = previous_age + delta
		v["age"] = new_age
		if previous_age < v25_fountain_gray_hold and new_age >= v25_fountain_gray_hold:
			# Fountain sparks arc upward, then fade; the gray column remains
			# completely visible during its original 1.15-second warning.
			var base: Vector2 = v["position"]
			v["fire_pair"] = _new_fire_pair("Fountain_%d" % i)
			for n in range(42):
				_spawn_ember(base + Vector2(randf_range(-18.0,18.0), -randf_range(0.0, 40.0)),
					Vector2(randf_range(-52.0, 52.0), -randf_range(150.0, 360.0)))
		if new_age >= v25_fountain_gray_hold and v.has("fire_pair"):
			var p: Dictionary = v["fire_pair"]
			var base2: Vector2 = v["position"]
			var life_t: float = (new_age - v25_fountain_gray_hold) / maxf(0.08, float(v["flame_time"]))
			var hot: float = smoothstep(0.0, 0.035, life_t) * (1.0 - smoothstep(0.58, 0.93, life_t))
			var fade: float = 1.0 - smoothstep(0.82, 1.35, life_t)
			var launch: float = 1.0 - pow(1.0 - clampf(life_t / 0.08, 0.0, 1.0), 3.0)
			var h: float = fountain_visual_height_px * float(v["height_scale"]) * lerpf(0.24, 1.22, launch)
			var wpx: float = fountain_visual_width_px
			_place_fire_pair(p, base2.x - wpx * 0.5, base2.y - h,
				wpx, h, hot, fade * normal_dash_fire_opacity, true, 1.0 - smoothstep(0.04, 0.28, life_t))
		if new_age >= v25_fountain_gray_hold + fountain_vent_flame_seconds * 1.35:
			if v.has("fire_pair"):
				_free_fire_pair(v["fire_pair"])
			_special_vents.remove_at(i)

	if is_instance_valid(_fire_layer):
		_fire_layer.special_puffs = _special_smoke
		_fire_layer.fountain_vents = _special_vents
		_fire_layer.ignite_delay = v25_fountain_gray_hold
		_fire_layer.gray_fountain_volume = v25_fountain_gray_volume
		_fire_layer.special_fire_scale = v25_special_fire_size
		_fire_layer.queue_redraw()


func _update_flame_bursts(delta: float) -> void:
	for i in range(_flame_bursts.size() - 1, -1, -1):
		var b: Dictionary = _flame_bursts[i]
		b["age"] = float(b["age"]) + delta
		# Small rising plume -> gravity pulls it gently toward its floor anchor.
		# Damping prevents oscillation or crossing into the ground.
		var fall_speed: float = float(b["smoke_velocity_y"]) + 285.0 * delta
		var next_height: float = float(b["smoke_offset_y"]) + fall_speed * delta
		if next_height >= -8.0:
			next_height = -8.0
			fall_speed = 0.0
		b["smoke_velocity_y"] = fall_speed
		b["smoke_offset_y"] = next_height
		if float(b["age"]) >= float(b["life"]):
			_flame_bursts.remove_at(i)
	if is_instance_valid(_fire_layer):
		_fire_layer.visual_scale = flame_visual_scale
		_fire_layer.height_multiplier = flame_height_multiplier
		_fire_layer.outer_color = flame_outer_color
		_fire_layer.body_color = flame_body_color
		_fire_layer.core_color = flame_core_color
		_fire_layer.bursts = _flame_bursts
		_fire_layer.queue_redraw()
	_sync_procedural_fire()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_ground_anchor_check -= delta
	if _ground_anchor_check <= 0.0:
		_ground_anchor_check = 0.20
		_refresh_ground_contact_anchor()
	_impact_strength = maxf(0.0, _impact_strength - delta * 2.05)
	_impact_particles_cd = maxf(0.0, _impact_particles_cd - delta)
	# Watch boss mode directly. This ensures dense fog appears BEFORE each
	# slash, and goes away as soon as the swing or jump starts, rather than
	# staying thick during a non-dashing attack. V42's calls still work too.
	_watch_boss_attack_state()
	_update_boss_screen_shake(delta)
	_warning_elapsed += delta

	var entrance: float = clampf(_elapsed / maxf(0.10, entrance_sweep_seconds), 0.0, 1.0)
	var intro_front: float = lerpf(_left - 140.0, _right + 140.0, entrance)

	# World-space fog geometry is rebuilt every frame so it visibly sweeps in,
	# follows the actual terrain, and drifts slightly above ground.
	_render_fog_banks(intro_front)

	# Low permanent atmospheric fog exists at fixed coordinates in the level,
	# independent of HUD, camera zoom, or the screen edges.
	for i in range(_terrain_points.size()):
		var ground: Vector2 = _terrain_points[i]
		var fi: float = float(i)
		var appearing: float = clampf((intro_front - ground.x + 95.0) / 115.0, 0.0, 1.0)
		var slow: float = _elapsed * atmospheric_drift_speed
		var bob: float = sin(slow * 0.60 + fi * 1.21)
		var small: float = sin(slow + fi * 2.1)
		var proximity: float = clampf(1.0 - ground.distance_to(_impact_point) / 245.0, 0.0, 1.0)
		var clearing: float = 1.0 - proximity * _impact_strength * 0.58

		var far: Sprite2D = _high_puffs[i]
		far.position = ground + Vector2(12.0 * bob, -ambient_fog_height_px * 0.71 + 2.5 * small)
		far.modulate = Color(fog_color.r, fog_color.g, fog_color.b,
			permanent_upper_haze * 0.35 * natural_ambient_smoke_density * ambient_wisp_alpha_multiplier * appearing * clearing * (0.85 + 0.12 * bob))

		var back: Sprite2D = _back_puffs[i]
		back.position = ground + Vector2(18.0 * bob, -ambient_fog_height_px * 0.36 + 4.5 * small + 4.0)
		back.modulate = Color(fog_color.r, fog_color.g, fog_color.b,
			permanent_ground_density * 0.32 * natural_ambient_smoke_density * ambient_wisp_alpha_multiplier * appearing * clearing * (0.80 + 0.15 * bob))

		var low: Sprite2D = _near_puffs[i]
		low.position = ground + Vector2(-17.0 * small, -ambient_fog_height_px * 0.18 + 3.4 * bob + 7.0)
		low.modulate = Color(fog_color.r, fog_color.g, fog_color.b,
			permanent_ground_density * 0.36 * natural_ambient_smoke_density * ambient_wisp_alpha_multiplier * appearing * clearing)

	if _warning_phase == 1:
		_update_warning_sweep()
		# If an attack was cancelled or parried, do not leave the danger fog up.
		if _warning_elapsed > _warning_duration + 0.27:
			# Cancelled/parried warnings fade without a fake dash explosion.
			_warning_phase = 2
			_warning_elapsed = 0.0
			_wave_edge.visible = false
			_wave_particles.emitting = false
	elif _warning_phase == 2:
		_update_warning_disperse()
	else:
		_wave_edge.visible = false
		_wave_particles.emitting = false
		_warning_bank.polygon = PackedVector2Array()
		_warning_upper_bank.polygon = PackedVector2Array()
		for warning: Sprite2D in _warning_puffs:
			warning.modulate.a = 0.0
		for wisp: Sprite2D in _warning_wisp_details:
			wisp.modulate.a = 0.0
	# Barely noticeable atmospheric sparks are distinct from the dramatic
	# orange pre-dash embers. This never creates a damage Area2D.
	if _warning_phase == 0 and ambient_ember_emission_rate > 0.0 and ember_rate_multiplier > 0.0:
		_ember_accumulator += delta * ambient_ember_emission_rate * ember_rate_multiplier
		while _ember_accumulator >= 1.0:
			_ember_accumulator -= 1.0
			var ax: float = randf_range(_left, _right)
			_spawn_ember(Vector2(ax, _floor_y_at(ax) - randf_range(3.0, 24.0)),
				Vector2(randf_range(-8.0, 8.0), -randf_range(8.0, 24.0)))
	_update_last_judge_specials(delta)
	_update_flame_bursts(delta)
	_update_dash_fire_ribbons(delta)
	_update_embers(delta)


func is_dash_warning_active() -> bool:
	# Optional ambience node queries this to darken only the parallax.
	return _active and _warning_phase == 1



func _trigger_camera_shake(strength: float, seconds: float) -> void:
	if not boss_screen_shake_enabled:
		return
	var power: float = maxf(0.0, strength)
	var duration: float = maxf(0.02, seconds)
	if power > _shake_strength or _shake_remaining < 0.04:
		_shake_strength = power
		_shake_duration = duration
		_shake_remaining = duration


func _clear_camera_shake() -> void:
	if is_instance_valid(_shake_camera):
		_shake_camera.offset -= _last_shake_applied
	_shake_camera = null
	_last_shake_applied = Vector2.ZERO
	_shake_remaining = 0.0
	_shake_duration = 0.0
	_shake_strength = 0.0


func _update_boss_screen_shake(delta: float) -> void:
	if not is_instance_valid(_boss):
		_clear_camera_shake()
		return

	var mode_now: int = int(_boss.get("mode"))
	var active_battle: bool = bool(_boss.get("engaged")) and mode_now != 6
	# Level 3 boss controller is never attached to other Menacing Skeletons.
	if active_battle and boss_screen_shake_enabled:
		if mode_now == BOSS_MODE_STRIKE and _previous_boss_mode != BOSS_MODE_STRIKE:
			# EVERY sword attack gets a subtle pulse, including green/purple.
			var jumped: bool = (_previous_boss_mode == BOSS_MODE_JUMP_SLAM
				or bool(_boss.get("jump_slam")))
			if jumped:
				_trigger_camera_shake(jump_landing_shake_px, jump_landing_shake_seconds)
			else:
				_trigger_camera_shake(normal_attack_shake_px, attack_shake_seconds)
		elif mode_now == BOSS_MODE_JUMP_SLAM and _previous_boss_mode != BOSS_MODE_JUMP_SLAM:
			_trigger_camera_shake(normal_attack_shake_px * 0.7, attack_shake_seconds)
	_previous_boss_mode = mode_now

	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	var transient: float = 0.0
	if _shake_remaining > 0.0:
		var fraction: float = _shake_remaining / maxf(0.01, _shake_duration)
		transient = _shake_strength * pow(fraction, 1.2)
	else:
		_shake_strength = 0.0

	var dash_motion: float = 0.0
	if active_battle and mode_now == BOSS_MODE_STRIKE:
		var distance: float = float(_boss.get("strike_dash_distance"))
		var dash_time: float = float(_boss.get("strike_dash_seconds"))
		var strike_time: float = float(_boss.get("strike_elapsed"))
		if distance > 15.0 and dash_time > 0.0 and strike_time < dash_time:
			dash_motion = dash_shake_px

	# Additive offset, so camera follow/tracking and any designer offset survive.
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != _shake_camera:
		# Camera switch must NOT discard a newly triggered attack impulse.
		if is_instance_valid(_shake_camera):
			_shake_camera.offset -= _last_shake_applied
		_shake_camera = camera
		_last_shake_applied = Vector2.ZERO
	if not is_instance_valid(camera):
		return
	var base_offset: Vector2 = camera.offset - _last_shake_applied
	var amplitude: float = maxf(transient, dash_motion) if active_battle else 0.0
	var applied: Vector2 = Vector2.ZERO
	if amplitude > 0.02:
		applied = Vector2(randf_range(-amplitude, amplitude),
			randf_range(-amplitude * 0.65, amplitude * 0.65))
	camera.offset = base_offset + applied
	_last_shake_applied = applied


func _exit_tree() -> void:
	_clear_camera_shake()


func _watch_boss_attack_state() -> void:
	# Do not guess that *any* strike is the warned dash. Orange first
	# slashes normally, and its next (index 1) strike is the dash.
	if not is_instance_valid(_boss) or _warning_phase != 1:
		return
	var current_mode: int = int(_boss.get("mode"))
	var current_combo: int = int(_boss.get("combo_index"))
	if current_mode == BOSS_MODE_STRIKE:
		if _warning_target_combo_index < 0 or current_combo == _warning_target_combo_index:
			dash_started(_boss.global_position, _warning_direction)
		elif current_combo != _warning_target_combo_index - 1:
			_cancel_warning_quietly()
	elif current_mode != BOSS_MODE_WARNING:
		_cancel_warning_quietly()


func _cancel_warning_quietly() -> void:
	_warning_phase = 2
	_warning_elapsed = 0.0
	_warning_start_burst_done = false
	_wave_edge.visible = false
	_wave_particles.emitting = false


func _make_terrain_strip(
	front_x: float,
	direction: float,
	height: float,
	bottom_offset: float,
	wave_pixels: float,
	phase_shift: float
) -> PackedVector2Array:
	# All coordinates are actual LEVEL/world coordinates, not camera pixels.
	# Generate a filled strip between a drifting top edge and the actual floor.
	var min_x: float = _left if direction > 0.0 else maxf(_left, front_x)
	var max_x: float = minf(_right, front_x) if direction > 0.0 else _right
	var polygon: PackedVector2Array = PackedVector2Array()
	if max_x - min_x <= 1.0:
		return polygon
	var count: int = clampi(ceili((max_x - min_x) / 24.0), 10, 180)
	for i in range(count + 1):
		var x: float = lerpf(min_x, max_x, float(i) / float(count))
		var floor_y: float = _floor_y_at(x)
		var w: float = sin(x * 0.023 + _elapsed * 1.75 + phase_shift) * wave_pixels
		w += sin(x * 0.057 - _elapsed * 0.9 + phase_shift) * wave_pixels * 0.23
		polygon.append(Vector2(x, floor_y - height + w))
	for i in range(count, -1, -1):
		var x: float = lerpf(min_x, max_x, float(i) / float(count))
		polygon.append(Vector2(x, _floor_y_at(x) + bottom_offset))
	return polygon


func _render_fog_banks(intro_front: float) -> void:
	# A single contiguous, STRAIGHT-TOP mist blanket, with transparent top
	# vertices and subtle gray alpha at sand level. It reveals from one side
	# as the arena fog enters, but does not look like layered wave strips.
	for strip: Polygon2D in _persistent_strips:
		strip.polygon = PackedVector2Array()
	if not is_instance_valid(_continuous_ground_bank):
		return
	var far_edge: float = clampf(intro_front, _left, _right)
	if far_edge <= _left + 1.0:
		_continuous_ground_bank.polygon = PackedVector2Array()
		return
	var width: float = far_edge - _left
	var count: int = clampi(ceili(width / 34.0), 4, 160)
	var poly: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var low_alpha: float = clampf(continuous_ground_fog_alpha * permanent_ground_density, 0.0, 0.40)
	# Transparent top: no visible cropped edge floating in the sky.
	for i in range(count + 1):
		var x: float = lerpf(_left, far_edge, float(i) / float(count))
		poly.append(Vector2(x, _floor_y_at(x) - continuous_ground_fog_height_px))
		colors.append(Color(fog_color.r, fog_color.g, fog_color.b, 0.0))
	# Subtle continuous bottom. The final 3px sit under the sand texture.
	for i in range(count, -1, -1):
		var x: float = lerpf(_left, far_edge, float(i) / float(count))
		poly.append(Vector2(x, _floor_y_at(x) + fog_below_ground_px))
		var variation: float = 0.92 + 0.08 * sin(x * 0.018 + _elapsed * 0.17)
		colors.append(Color(fog_color.r, fog_color.g, fog_color.b, low_alpha * variation))
	_continuous_ground_bank.polygon = poly
	_continuous_ground_bank.vertex_colors = colors


func _update_warning_sweep() -> void:
	# IMPORTANT: V15 timing is intentionally IDENTICAL. Only the visual
	# representation is replaced with textured clouds and orange sparks.
	var visible_time: float = maxf(0.0, _warning_elapsed - fog_visual_delay_v15)
	var p: float = clampf(visible_time / maxf(0.12, warning_sweep_seconds), 0.0, 1.0)
	_warning_front_x = lerpf(_left - 150.0, _right + 150.0, p) if _warning_direction > 0.0 else lerpf(_right + 150.0, _left - 150.0, p)

	# Dense wisps form a rolling front, then linger during the remainder of
	# the boss windup. The leading edge is turbulent, not a rectangular wipe.
	for i in range(_warning_puffs.size()):
		var ground: Vector2 = _terrain_points[i]
		var fi: float = float(i)
		var behind: float = (_warning_front_x - ground.x) * _warning_direction
		var p_behind: float = (behind + 55.0 + sin(fi * 1.57 + _elapsed * 4.0) * 29.0) / 127.0
		var reveal: float = smoothstep(0.0, 1.0, p_behind)
		var rise: float = sin(fi * 1.61 + _elapsed * 2.6) * 6.0
		var sway: float = sin(fi * 1.9 + _elapsed * 3.1) * 16.0
		var twirl: float = sin(fi * 0.96 - _elapsed * 1.9)
		var w: Sprite2D = _warning_puffs[i]
		w.position = ground + Vector2(16.0 * twirl + sway, -warning_height_above_ground * 0.35 + rise)
		w.rotation = sin(fi * 0.91 + _elapsed * 1.15) * 0.12
		w.modulate = Color(warning_tint.r, warning_tint.g, warning_tint.b,
			clampf(warning_density * warning_puff_alpha * natural_warning_smoke_density * reveal *
			(0.68 + 0.22 * sin(fi * 0.67 + _elapsed * 2.2)), 0.0, 0.75))
		var d: Sprite2D = _warning_wisp_details[i]
		d.position = ground + Vector2(23.0 * sin(fi * 2.03 - _elapsed * 1.91),
			-warning_height_above_ground * 0.52 + 9.0 * sin(fi * 0.78 - _elapsed * 2.65))
		d.rotation = sin(fi * 1.37 - _elapsed * 1.38) * 0.20
		d.modulate = Color(warning_tint.r, warning_tint.g, warning_tint.b,
			clampf(warning_density * warning_puff_alpha * 0.64 * natural_warning_smoke_density * reveal, 0.0, 0.53))

	_warning_upper_bank.polygon = PackedVector2Array()
	_warning_bank.polygon = PackedVector2Array()
	_wave_edge.visible = false
	_wave_particles.position = Vector2(_warning_front_x,
		_floor_y_at(_warning_front_x) - warning_height_above_ground * 0.22)
	_wave_particles.emitting = visible_time > 0.0 and p < 0.995

	# Last Judge-style warning: the mist grows denser and is full of many tiny
	# blazing flecks. Keep them distributed THROUGH the warning bank, not just
	# as a thin line on the sweep front. Still visual-only and pre-dash only.
	if visible_time > 0.0 and p > 0.10 and ember_rate_multiplier > 0.0:
		var bank_fill: float = clampf(p, 0.18, 1.0)
		if not _warning_start_burst_done:
			_warning_start_burst_done = true
			_spawn_warning_ember_cluster(_warning_front_x, bank_fill, warning_ember_start_burst)
		_ember_accumulator += get_process_delta_time() * warning_ember_emission_rate * ember_rate_multiplier
		while _ember_accumulator >= 1.0:
			_ember_accumulator -= 1.0
			_spawn_warning_ember_cluster(_warning_front_x, bank_fill, 1 + int(randi() % 2))



func _spawn_warning_ember_cluster(front_x: float, bank_scale: float, count: int) -> void:
	if count <= 0 or ember_rate_multiplier <= 0.0:
		return
	# Newly entered smoke AND older already-revealed smoke receive embers;
	# V22 used only a short band immediately behind the moving edge.
	var reached_left: float = _left if _warning_direction > 0.0 else clampf(front_x, _left, _right)
	var reached_right: float = clampf(front_x, _left, _right) if _warning_direction > 0.0 else _right
	if reached_right < reached_left:
		return
	var trailing_length: float = minf(warning_ember_band_length * bank_scale, reached_right - reached_left)
	for i in range(count):
		var emit_x: float = randf_range(reached_left, reached_right)
		# Some particles cluster near the advancing edge, most fill the bank.
		if i % 4 == 0 and trailing_length > 20.0:
			emit_x = clampf(front_x - _warning_direction * randf_range(0.0, trailing_length),
				_left, _right)
		# Tiny low-flying embers, not large targets scattered across the sky.
		var emit_y: float = _floor_y_at(emit_x) - randf_range(3.0, warning_height_above_ground * 0.55)
		var vel: Vector2 = Vector2(
			-_warning_direction * randf_range(7.0, 33.0) + randf_range(-10.0, 10.0),
			-randf_range(8.0, 37.0)
		)
		_spawn_ember(Vector2(emit_x, emit_y), vel)


func _spawn_ember(at: Vector2, initial_speed: Vector2) -> void:
	if _embers.size() >= maximum_embers:
		_embers.remove_at(0)
	var life: float = maxf(0.12, ember_fade_time * randf_range(0.60, 1.28))
	# Small, varied sparks: pinpoint embers, short flying streaks and
	# angular flecks. Nothing creates the old target-like circular halos.
	var kind: int = randi_range(0, 11)
	_embers.append({
		"position": at,
		"velocity": initial_speed,
		"life": life,
		"max_life": life,
		"size": randf_range(0.48, 1.15),
		"kind": kind,  # 0-3 pinpoints, 4-9 hairline streaks, 10-11 flecks
		"phase": randf_range(0.0, TAU)
	})


func _update_embers(delta: float) -> void:
	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e["life"] = float(e["life"]) - delta
		if float(e["life"]) <= 0.0:
			_embers.remove_at(i)
			continue
		var speed: Vector2 = e["velocity"]
		speed += Vector2(sin(_elapsed * 8.0 + float(e["phase"])) * 10.0 * delta, -10.0 * delta)
		e["velocity"] = speed * (1.0 - minf(0.95, delta * 0.5))
		e["position"] = Vector2(e["position"]) + speed * delta
	queue_redraw()


func _draw() -> void:
	# Draw tiny, varied embers without concentric circles or large light halos.
	# The colored flecks remain purely visual and move in world coordinates.
	for e: Dictionary in _embers:
		var p: Vector2 = Vector2(e["position"])
		var factor: float = clampf(float(e["life"]) / maxf(0.01, float(e["max_life"])), 0.0, 1.0)
		var twinkle: float = 0.78 + 0.22 * sin(_elapsed * 17.0 + float(e["phase"]))
		var r: float = float(e["size"])
		var kind: int = int(e["kind"])
		var hot: Color = ember_yellow_core if kind == 0 or kind == 7 or kind == 10 else ember_bright_orange
		hot.a = factor * twinkle * 0.96
		if kind <= 3:
			# Most are 1-3 pixel points, with no fake circular glow field.
			draw_circle(p, r * (0.73 if kind % 2 == 0 else 1.0), hot)
		elif kind <= 9:
			# Moving hairline sparks, direction comes from actual ember motion.
			var motion: Vector2 = Vector2(e["velocity"])
			var direction: Vector2 = motion.normalized() if motion.length_squared() > 1.0 else Vector2(0.45, -0.9)
			var length: float = r * (2.7 if kind % 2 == 0 else 4.2)
			draw_line(p - direction * length, p + direction * r * 0.4, hot, maxf(0.75, r * 0.65), true)
		else:
			# Uneven triangular sparks, not round particles.
			var direction: Vector2 = Vector2(cos(float(e["phase"])), sin(float(e["phase"])))
			var sideways: Vector2 = Vector2(-direction.y, direction.x)
			var poly: PackedVector2Array = PackedVector2Array([
				p + direction * r * 1.8,
				p - direction * r * 1.1 + sideways * r * 0.52,
				p - direction * r * 0.6 - sideways * r * 0.50
			])
			draw_colored_polygon(poly, hot)


func _update_warning_disperse() -> void:
	# The boss starts moving: smoke blows sideways and curls upward; the
	# orange specks already in flight fade naturally on their own.
	var t: float = clampf(_warning_elapsed / maxf(0.10, disperse_seconds), 0.0, 1.0)
	var alpha: float = 1.0 - smoothstep(0.52, 1.0, t)
	var rise: float = 18.0 * sin(t * PI)
	var settling_down: float = 18.0 * pow(t, 1.65)
	_warning_bank.polygon = PackedVector2Array()
	_warning_upper_bank.polygon = PackedVector2Array()
	for i in range(_warning_puffs.size()):
		var ground: Vector2 = _terrain_points[i]
		var fi: float = float(i)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var w: Sprite2D = _warning_puffs[i]
		w.position = ground + Vector2(
			_warning_direction * t * 95.0 + side * t * 26.0,
			-warning_height_above_ground * 0.35 - rise + settling_down - sin(fi * 1.5) * 3.0)
		w.rotation += get_process_delta_time() * side * 0.3
		w.modulate = Color(warning_tint.r, warning_tint.g, warning_tint.b,
			warning_density * warning_puff_alpha * natural_warning_smoke_density * alpha * 0.72)
		var d: Sprite2D = _warning_wisp_details[i]
		d.position = ground + Vector2(-_warning_direction * t * 56.0 + side * 20.0,
			-warning_height_above_ground * 0.52 - rise * 1.2 + settling_down * 1.35)
		d.modulate = Color(warning_tint.r, warning_tint.g, warning_tint.b,
			warning_density * warning_puff_alpha * natural_warning_smoke_density * alpha * 0.40)
	if t >= 1.0:
		_warning_phase = 0
		_warning_bank.position = Vector2.ZERO
		_warning_upper_bank.position = Vector2.ZERO
		_warning_bank.polygon = PackedVector2Array()
		_warning_upper_bank.polygon = PackedVector2Array()
		for w: Sprite2D in _warning_puffs:
			w.modulate.a = 0.0
		for d: Sprite2D in _warning_wisp_details:
			d.modulate.a = 0.0
