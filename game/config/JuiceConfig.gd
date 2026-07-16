class_name JuiceConfig
extends Resource
## Every juice/audio tunable of the §7 art & juice pass, Appendix-A style:
## launch defaults, all named @export Inspector knobs — tuning feel is a
## slider drag, never a code change. Visual-first (spec §7): every beat
## fully lands with sound off; audio and vibration are additive layers.

# --- screen shake (camera-offset noise, fast decay) ---------------------------
## Peak camera offset at full trauma, in px.
@export var shake_max_offset_px := 6.0
## Trauma drained per second — short and sharp, never seasick.
@export var shake_decay_per_sec := 2.6
## Trauma added per beat size (shake scales with trauma squared).
@export var shake_small := 0.28
@export var shake_medium := 0.5
@export var shake_large := 0.75

# --- flash (one full-screen rect, fast fade) -----------------------------------
@export var flash_fade_secs := 0.22
@export var flash_alpha_small := 0.10
@export var flash_alpha_big := 0.26

# --- particle bursts (pooled CPUParticles2D, spec §7/§12) -----------------------
## Per-burst counts; every burst is clamped to WorldgenConfig.particle_cap.
@export var burst_dig := 5
@export var burst_break := 8
@export var burst_gem := 6
@export var burst_hazard := 8
@export var particle_lifetime_secs := 0.45
@export var particle_speed_px := 70.0
## Concurrent pooled emitters; a burst past the pool steals the oldest.
@export var emitter_pool_size := 6

# --- vibration (best-effort navigator.vibrate — additive only, spec §7) --------
@export var vibrate_gem_ms := 12
@export var vibrate_sell_ms := 18
@export var vibrate_milestone_ms := 30
@export var vibrate_hazard_ms := 45
@export var vibrate_lost_ms := 90

# --- audio (the bonus layer, spec §7/§11) ---------------------------------------
@export var sfx_volume_db := -6.0
@export var music_volume_db := -14.0
@export var hum_volume_db := -22.0
## Depths (tiles) where each ambient loop peaks; loops volume-crossfade
## between anchors (crossfade is playback, never a bus effect — §11).
@export var music_depth_anchors := PackedInt32Array([0, 240, 480])
