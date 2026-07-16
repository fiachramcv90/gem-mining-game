extends Node
## Autoload: the Miner's Log (spec §8) — the game's one meta-progression
## surface. 8 lifetime stats (plain int counters, incremented at the moment
## of the event) + 14 honorific milestones in three families, every one
## pinned to an event GameState already signals — no new detection systems.
##
## Honorific-only is the hard line: a milestone pays a banner and a Log
## entry, never money, currency, or capability. Daily hooks are rejected on
## the record — do not add them here.

## A milestone landing: the HUD shows the one-line terse banner (never a
## modal); the Log screen honours it fully at the hub.
signal milestone_earned(id: String, banner: String)

## What counts as a run for runs_completed: the surface arrival only counts
## after reaching this depth, or the 0<->1 hover flicker at the surface line
## would mint runs (same reasoning as SaveManager.ARRIVE_SAVE_MIN_DEPTH,
## kept separate — save cadence and run semantics are different dials).
const RUN_MIN_DEPTH := 4

const STAT_KEYS: Array[String] = [
	"deepest_depth",
	"tiles_dug",
	"gems_collected",
	"money_banked",
	"prize_gems_banked",
	"runs_completed",
	"runs_lost",
	"cargo_value_lost",
]

## The 14 milestones (spec §8): Depth 5 / Wealth 4 / Survival 5. The name +
## line copy is the entire content cost of this layer — terse miner voice.
## Depth thresholds are read from WorldgenConfig at award time, never stored.
const MILESTONES: Array[Dictionary] = [
	{
		"id": "depth_clay",
		"family": "DEPTH",
		"name": "Into the Clay",
		"line": "CLAY. The topsoil is behind you."
	},
	{
		"id": "depth_sandstone",
		"family": "DEPTH",
		"name": "Sandstone Deep",
		"line": "SANDSTONE. Deep enough to matter."
	},
	{
		"id": "depth_granite",
		"family": "DEPTH",
		"name": "Granite Bitten",
		"line": "GRANITE. The rock fights back now."
	},
	{
		"id": "depth_bedrock",
		"family": "DEPTH",
		"name": "Bedrock Walker",
		"line": "BEDROCK. Few dig this deep."
	},
	{
		"id": "depth_bottom",
		"family": "DEPTH",
		"name": "The Bottom",
		"line": "THE BOTTOM. There is no deeper."
	},
	{
		"id": "wealth_first_sell",
		"family": "WEALTH",
		"name": "First Sale",
		"line": "SOLD. The ratchet turns."
	},
	{
		"id": "wealth_first_upgrade",
		"family": "WEALTH",
		"name": "Money Into Iron",
		"line": "UPGRADED. Money into iron."
	},
	{
		"id": "wealth_prize_banked",
		"family": "WEALTH",
		"name": "The Prize, Banked",
		"line": "PRIZE BANKED. The climb home was part of it."
	},
	{
		"id": "wealth_hoist",
		"family": "WEALTH",
		"name": "The Hoist",
		"line": "THE HOIST. The long climb, bought off."
	},
	{
		"id": "survival_fall",
		"family": "SURVIVAL",
		"name": "Long Drop",
		"line": "SOME DROP. Walked away from it."
	},
	{
		"id": "survival_gas",
		"family": "SURVIVAL",
		"name": "Gas Breather",
		"line": "GAS. Bad air, still breathing."
	},
	{
		"id": "survival_cavein",
		"family": "SURVIVAL",
		"name": "Out From Under",
		"line": "CAVE-IN. Not your tomb today."
	},
	{
		"id": "survival_lava",
		"family": "SURVIVAL",
		"name": "Singed, Not Smelted",
		"line": "LAVA. Singed, not smelted."
	},
	{
		"id": "survival_first_loss",
		"family": "SURVIVAL",
		"name": "Every Miner Loses a Load",
		"line": "LOAD LOST. Every miner loses one."
	},
]

## The 8 lifetime counters (spec §13 "stats"). Displayed, never spent.
var stats := {}
## Earned milestones: {id: true} — flat, string-keyed, no timestamps.
## Unknown ids from a newer build are kept, not dropped (load defensively).
var milestones := {}

## Deepest tile of the run in progress — the runs_completed detector: reset
## on run lost so the free respawn's surface arrival never counts as a run.
var _deepest_this_run := 0


func _ready() -> void:
	reset()
	GameState.depth_changed.connect(_on_depth_changed)
	GameState.tile_dug.connect(_on_tile_dug)
	GameState.gem_collected.connect(_on_gem_collected)
	GameState.cargo_sold.connect(_on_cargo_sold)
	GameState.prizes_banked.connect(_on_prizes_banked)
	GameState.run_lost.connect(_on_run_lost)
	GameState.hazard_survived.connect(_on_hazard_survived)
	Upgrades.upgrades_changed.connect(_on_upgrades_changed)


func reset() -> void:
	stats = {}
	for key in STAT_KEYS:
		stats[key] = 0
	milestones = {}
	_deepest_this_run = 0


func load_state(stats_in: Dictionary, milestones_in: Dictionary) -> void:
	## Load defensively (spec §13): missing or mistyped key -> zero. Then
	## self-heal: stat-derivable badges re-award themselves silently, so a
	## migrated save back-fills what its numbers already prove (spec §8).
	reset()
	for key in STAT_KEYS:
		var v: Variant = stats_in.get(key)
		if v is int:
			stats[key] = maxi(0, v)
		elif v is float:
			stats[key] = maxi(0, int(v))
	for id: Variant in milestones_in.keys():
		if id is String and bool(milestones_in[id]):
			milestones[id] = true
	_self_heal()


func entry_of(id: String) -> Dictionary:
	for entry in MILESTONES:
		if entry["id"] == id:
			return entry
	return {}


func is_earned(id: String) -> bool:
	return milestones.has(id)


# --- the moment-of-the-event counters (spec §8) --------------------------------


func _on_depth_changed(depth: int) -> void:
	if depth > stats["deepest_depth"]:
		stats["deepest_depth"] = depth
	_deepest_this_run = maxi(_deepest_this_run, depth)
	_award_depth_family(depth, _award)
	if depth == 0 and _deepest_this_run >= RUN_MIN_DEPTH:
		# Back at the surface after a real descent: a run completed
		# (CONTEXT.md "Run" — lost runs reset the tracker before this).
		stats["runs_completed"] += 1
		_deepest_this_run = 0


func _on_tile_dug(_tile: Vector2i) -> void:
	stats["tiles_dug"] += 1


func _on_gem_collected(_tier: int) -> void:
	stats["gems_collected"] += 1


func _on_cargo_sold(value: int) -> void:
	if value <= 0:
		return
	stats["money_banked"] += value
	_award("wealth_first_sell")


func _on_prizes_banked(count: int) -> void:
	stats["prize_gems_banked"] += count
	_award("wealth_prize_banked")


func _on_run_lost(_reason: String, cargo_lost: int) -> void:
	stats["runs_lost"] += 1
	stats["cargo_value_lost"] += cargo_lost
	_deepest_this_run = 0
	_award("survival_first_loss")


func _on_hazard_survived(kind: String, _amount: float) -> void:
	## One badge per hazard mechanism (spec §8), pinned to the damage the
	## hull just absorbed — the event spec §5 already lands.
	match kind:
		GameState.HAZARD_FALL:
			_award("survival_fall")
		GameState.HAZARD_GAS:
			_award("survival_gas")
		GameState.HAZARD_CAVEIN:
			_award("survival_cavein")
		GameState.HAZARD_LAVA:
			_award("survival_lava")


func _on_upgrades_changed() -> void:
	if _any_upgrade_bought():
		_award("wealth_first_upgrade")
	if Upgrades.hoist:
		_award("wealth_hoist")


# --- awarding -------------------------------------------------------------------


func _award(id: String) -> void:
	if milestones.has(id):
		return
	milestones[id] = true
	milestone_earned.emit(id, entry_of(id).get("line", ""))


func _award_silent(id: String) -> void:
	milestones[id] = true


func _award_depth_family(depth: int, award: Callable) -> void:
	## The Depth family pins to 0005's band edges (config, never copied) and
	## the designed bottom: the deepest DIGGABLE tile sits one above the
	## bedrock floor at designed_bottom_depth, hence the -1 capstone.
	var edges := GameState.world.band_edges
	if depth >= edges[1]:
		award.call("depth_clay")
	if depth >= edges[2]:
		award.call("depth_sandstone")
	if depth >= edges[3]:
		award.call("depth_granite")
	if depth >= edges[4]:
		award.call("depth_bedrock")
	if depth >= GameState.world.designed_bottom_depth - 1:
		award.call("depth_bottom")


func _self_heal() -> void:
	## Stat-derivable badges self-heal at load, SILENTLY — no banner replay
	## (spec §8). Event-only survival badges (fall/gas/cavein/lava) cannot be
	## back-derived and are simply earnable going forward.
	_award_depth_family(int(stats["deepest_depth"]), _heal)
	_heal_if("wealth_first_sell", int(stats["money_banked"]) > 0)
	_heal_if("wealth_first_upgrade", _any_upgrade_bought())
	_heal_if("wealth_prize_banked", int(stats["prize_gems_banked"]) > 0)
	_heal_if("wealth_hoist", Upgrades.hoist)
	_heal_if("survival_first_loss", int(stats["runs_lost"]) > 0)


func _heal(id: String) -> void:
	_award_silent(id)


func _heal_if(id: String, earned: bool) -> void:
	if earned:
		_award_silent(id)


func _any_upgrade_bought() -> bool:
	for track: String in Upgrades.levels.keys():
		if int(Upgrades.levels[track]) > 0:
			return true
	return Upgrades.hoist
