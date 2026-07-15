class_name HazardConfig
extends Resource
## Every hazard tunable from the final spec's Appendix A (0007 hazards).
## The full roster is live: FALLS (Act I), GAS POCKETS (Acts I/II),
## CAVE-INS (Act II) and LAVA (Act III). All values are launch DEFAULTS
## and stay named @export Inspector knobs.

# --- falls (Act I — LIVE, spec §5) -------------------------------------------
## Tiles of free fall before damage starts.
@export var fall_grace_tiles := 3
## Hull damage per tile fallen past the grace, ~linear.
@export var fall_dmg_per_tile := 4.0
## Cap as a fraction of CURRENT hull — scales with upgrades: serious but
## survivable, never a one-shot.
@export var fall_dmg_cap_frac := 0.45
## Seen in the light, a thrust-brace multiplies the damage by this.
@export var fall_light_brace_factor := 0.4
## Implementation knob (not Appendix A): unsupported downward speed, in
## tiles/sec, above which a drop starts counting as a fall — filters the
## micro-drift of hover flight out of fall detection.
@export var fall_min_speed_tiles := 0.5

# --- gas pockets (Acts I/II — LIVE, spec §5) ----------------------------------
## Burst damage by band: Clay / Sandstone / Granite / Bedrock. Darkness never
## scales damage size — only whether the tell was seen (§6).
@export var gas_burst_dmg := PackedInt32Array([8, 14, 18, 22])
## Placement rate by band (fraction of undug tiles seeded as gas): rare in
## Clay, common Sandstone+ (spec §5). Topsoil has none by roster.
@export var gas_encounter_rate := PackedFloat32Array([0.005, 0.02, 0.03, 0.035])

# --- cave-ins (Act II — LIVE, spec §5) ----------------------------------------
## Damage by band: Granite / Bedrock.
@export var cavein_dmg := PackedInt32Array([15, 25])
## Placement rate by band (fraction of undug tiles seeded as cracked/unstable
## rock), Granite / Bedrock only. Placement is a pure per-tile hash of
## (world_seed, coords) — never runtime randf().
@export var cavein_encounter_rate := PackedFloat32Array([0.02, 0.03])
## Implementation knobs (not Appendix A): how long an undermined tile
## trembles before it drops — the telegraph beat the player gets to move —
## and how fast the dropped rock falls, in tiles/sec.
@export var cavein_telegraph_secs := 0.45
@export var cavein_fall_speed_tiles := 16.0

# --- lava / heat (Act III — LIVE, spec §5) -------------------------------------
@export var lava_tick_dmg := 5.0
@export var lava_tick_interval := 0.2
## Lava glows — self-lit through darkness (the fair exception, spec §6).
@export var lava_glow_radius := 6.0
## Bedrock-only placement gate: a tile is lava where its seeded noise
## channel exceeds (1 - this rate) — 0 disables lava entirely. Like the
## cave channel, higher = more; the felt fraction is a noise quantile, so
## tune by eye, not arithmetic.
@export var lava_encounter_rate := 0.12
## Implementation knob (not Appendix A): the lava noise channel's frequency
## — lower = larger, rarer molten pockets.
@export var lava_noise_frequency := 0.05

# --- darkness x hazards (spec §6) ---------------------------------------------
## §6 is implemented as the RENDERING RULE: a hazard's tell is drawn only
## inside the lit view radius — the darkness renderer IS the dodge mechanic,
## no dice roll. These full-dark hit fractions stay calibration anchors for
## tuning encounter rates against the §5 expected-damage curve.
@export var hazard_hit_frac_dark := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])

# --- calibration anchors (spec §5 reconciled contract) ------------------------
## The expected-damage/tile curve the encounter rates are tuned against —
## NOT a live drain (0006 x 0007): base x (1 + gain x depth_fraction).
@export var hazard_base_per_tile := 0.02
@export var hazard_depth_gain := 4.0
