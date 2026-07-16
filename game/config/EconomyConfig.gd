class_name EconomyConfig
extends Resource
## Every economy/dig-feel tunable from the final spec's Appendix A
## (0006 economy + the 0004 dig constant + 0013 onboarding knobs).
## All values are launch DEFAULTS and stay named @export Inspector knobs —
## re-balancing is a slider drag, never a code change.

# --- dig feel (0004) --------------------------------------------------------
## Seconds of drilling per unit hardness. The drill-time contract (spec §3):
## effective_drill_time = hardness * dig_constant / drill_power.
@export var dig_constant := 0.34

# --- gem values (0006) ------------------------------------------------------
## Sale value by tier, T1..T5.
@export var gem_value := PackedInt32Array([8, 15, 28, 52, 95])
## The prize gem, off the tier curve (~9.5x a T5).
@export var prize_value := 900

# --- the six upgrade tracks (0006): index = level, L0 is the free kit -------
@export var drill_power := PackedFloat32Array([0.31, 0.62, 0.93, 1.24, 1.55])
@export var drill_price := PackedInt32Array([100, 280, 750, 1900])
@export var fuel_capacity := PackedInt32Array([80, 180, 380, 650, 1050])
@export var fuel_price := PackedInt32Array([80, 240, 640, 1600])
@export var cargo_slots := PackedInt32Array([12, 20, 32, 50, 75])
@export var cargo_price := PackedInt32Array([120, 320, 800, 2000])
@export var hull_capacity := PackedInt32Array([100, 150, 220, 320, 450])
@export var hull_price := PackedInt32Array([90, 260, 700, 1750])
@export var light_darkness_mult := PackedFloat32Array([1.0, 0.68, 0.42, 0.25])
@export var light_price := PackedInt32Array([150, 450, 1200])
@export var hoist_price := 5000
@export var hoist_ascent_factor := 0.5
## The Hoist is aspirational (spec §4): it surfaces in the shop only once
## Drill, Fuel, AND Cargo have all reached this level.
@export var hoist_reveal_min_level := 3

# --- fuel consumption (0006): the round-trip budget -------------------------
@export var fuel_descent_per_tile := 0.4
## The asymmetry that makes the climb home a real budget line. On-device
## tuned (session 4, feedback #5): stepped down from the 0006 draft of 1.0 —
## the climb home cost less without defusing the round-trip squeeze. 0.5
## (the suggested halving) stays off the table unless play demands it.
@export var fuel_ascent_per_tile := 0.7
## Charged per tile dug (hover-while-drilling).
@export var fuel_hover_per_tile := 0.15
@export var fuel_reserve_margin := 0.12

# --- surface costs: pinned to zero, plumbing not a plan (spec §1) -----------
@export var refuel_cost_per_unit := 0.0
@export var repair_cost_per_hp := 0.0

# --- pacing ------------------------------------------------------------------
## Master pacing lever: global multiplier over all price arrays.
@export var price_scale := 1.0
@export var surface_hub_seconds := 15.0

# --- onboarding (0013) -------------------------------------------------------
## Fuel gauge pulses when remaining fuel < this x estimated ascent cost.
@export var roundtrip_pulse_threshold := 1.3
## Ghost line self-dismiss backstop, seconds (spec §9).
@export var ghost_line_backstop_secs := 10.0

# --- distribution (0010 / spec §15) -------------------------------------------
## The one quiet support surface: the itch.io page URL. A placeholder knob
## until the page exists — while empty, the ♥ corner link reads "coming
## soon" instead of opening anything. Never mid-run, never a modal.
@export var support_url := ""


func price_of(prices: PackedInt32Array, level_index: int) -> int:
	## Price to buy level (level_index+1), with the global price_scale applied.
	return int(round(prices[level_index] * price_scale))
