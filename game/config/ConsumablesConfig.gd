class_name ConsumablesConfig
extends Resource
## Every tunable for EP1's six-tool consumable loadout (EP1 spec C1–C4).
## All values are the spec Appendix first-draft DEFAULTS and stay named
## @export Inspector knobs — re-balancing is a slider drag, never a code
## change. Scarcity (maxCharges, drones capped at 2) is the balancing
## mechanism; do not loosen it (EP1 standing principle).
##
## Tool ids are the canonical keys shared by Loadout, the garage shop, the
## HUD and onboarding. Order here is the shop/unlock order (shallow → deep).

const TOOLS: Array[String] = ["flare", "fuel_cell", "dynamite", "repair_kit", "scout", "hauler"]

## Display name + the run-pressure each tool insures (EP1 spec C1 table).
const TOOL_NAMES := {
	"flare": "Flare",
	"fuel_cell": "Fuel Cell",
	"dynamite": "Dynamite",
	"repair_kit": "Repair Kit",
	"scout": "Scout Drone",
	"hauler": "Hauler Drone",
}
const TOOL_PRESSURES := {
	"flare": "darkness",
	"fuel_cell": "fuel",
	"dynamite": "hard rock",
	"repair_kit": "hull",
	"scout": "discovery",
	"hauler": "cargo",
}

# --- the loadout system (C1): unlock schedule & first-draft pricing ----------
## Depth (tiles) at which the tool becomes visible+buyable in the garage shop.
@export var unlock_depth := {
	"flare": 120,
	"fuel_cell": 180,
	"dynamite": 260,
	"repair_kit": 340,
	"scout": 450,
	"hauler": 550,
}
## One-time unlock price, paid once to make the tool stockable.
@export var unlock_price := {
	"flare": 150,
	"fuel_cell": 300,
	"dynamite": 600,
	"repair_kit": 500,
	"scout": 2000,
	"hauler": 3500,
}
## Price per charge bought into garage stock.
@export var per_charge_price := {
	"flare": 8,
	"fuel_cell": 25,
	"dynamite": 40,
	"repair_kit": 35,
	"scout": 60,
	"hauler": 80,
}
## Stock cap per tool — scarcity's home (drones capped at 2). Do not loosen.
@export var max_charges := {
	"flare": 5,
	"fuel_cell": 3,
	"dynamite": 4,
	"repair_kit": 3,
	"scout": 2,
	"hauler": 2,
}
## Active loadout slot count (C1 / C3 — the HUD is three corner buttons).
@export var active_slots := 3

# --- dynamite (C4 / EP1-08) --------------------------------------------------
## Downward-biased teardrop, ~3-tile radius: below / up / wide reach in tiles.
@export var blast_down := 3
@export var blast_up := 2
@export var blast_wide := 2
## Short auto-fuse (the gamble is time pressure, not a manual detonate).
@export var fuse_time := 1.3
## Proximity-scaled self-damage, capped at this fraction of CURRENT hull
## (0007's currency, like falls' 45% cap) — punishing but never an instakill.
@export var self_dmg_frac := 0.40
## Self-damage reach in tiles (full at centre, tapering to 0 here).
@export var self_dmg_radius := 3.0

# --- hauler drone (C4 / EP1-09) ----------------------------------------------
## Round-trip flight time = base + per_depth * depth (tiles). Self-powered
## (never draws the fuel tank); one drone, sequential — can't re-send in air.
@export var haul_trip_time_base := 3.0
@export var haul_trip_time_per_depth := 0.02

# --- scout drone (C4 / EP1-09) -----------------------------------------------
## Generously wide but bounded detection radius (tiles) for the nearest
## qualifying gem; refuses (keeps the charge) with no target in range.
@export var scout_radius := 26.0
## Minimum gem tier the scout will point at (the prize always qualifies).
@export var scout_min_tier := 4
## Tunnel dig cadence — tiles cleared per second along the path to the target.
@export var scout_tunnel_tiles_per_sec := 14.0

# --- relief consumables (C4 / EP1-10) ----------------------------------------
## Fuel cell tops up this fraction of MAX fuel (scales with Fuel upgrades).
@export var fuel_cell_frac := 0.40
## Repair kit heals this fraction of MAX hull (scales with Hull upgrades).
@export var repair_frac := 0.40
## Flare: a generous local lit disc (tiles, wider than the personal Light
## bubble), dropped just ahead, burning for flare_duration then fading.
@export var flare_radius := 9.0
@export var flare_duration := 10.0
## How far ahead of the digger the flare drops, in tiles.
@export var flare_lead := 1.5


func name_of(tool: String) -> String:
	return TOOL_NAMES.get(tool, tool)


func pressure_of(tool: String) -> String:
	return TOOL_PRESSURES.get(tool, "")


func cap_of(tool: String) -> int:
	return int(max_charges.get(tool, 0))
