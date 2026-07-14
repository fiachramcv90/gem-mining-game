extends Node
## Autoload: the upgrade ratchet (spec §4) — six permanent tracks, levels only
## ever climb. Effective values are derived here from (EconomyConfig, level);
## never stored. The shop UI arrives with the full hub census (later session);
## buy() exists now so the ratchet state and save schema (§13) are stable.

signal upgrades_changed

## Level per track; L0 is the free starting kit.
var levels := {"drill": 0, "fuel": 0, "cargo": 0, "hull": 0, "light": 0}
var hoist := false


func _eco() -> EconomyConfig:
	return GameState.economy


func drill_power() -> float:
	return _eco().drill_power[levels["drill"]]


func fuel_capacity() -> int:
	return _eco().fuel_capacity[levels["fuel"]]


func cargo_slots() -> int:
	return _eco().cargo_slots[levels["cargo"]]


func hull_capacity() -> int:
	return _eco().hull_capacity[levels["hull"]]


func light_mult() -> float:
	return _eco().light_darkness_mult[levels["light"]]


func ascent_factor() -> float:
	## The Hoist halves ascent fuel & time once bought (spec §4).
	return _eco().hoist_ascent_factor if hoist else 1.0


func _prices_for(track: String) -> PackedInt32Array:
	match track:
		"drill":
			return _eco().drill_price
		"fuel":
			return _eco().fuel_price
		"cargo":
			return _eco().cargo_price
		"hull":
			return _eco().hull_price
		"light":
			return _eco().light_price
	return PackedInt32Array()


func max_level(track: String) -> int:
	## Highest reachable level for a track (L0 is the free starting kit, so
	## the price array's length IS the max level).
	return _prices_for(track).size()


func next_price(track: String) -> int:
	## Price of the next level for a track, or -1 if maxed.
	var prices := _prices_for(track)
	var level: int = levels[track]
	if level >= prices.size():
		return -1
	return _eco().price_of(prices, level)


func hoist_cost() -> int:
	return int(round(_eco().hoist_price * _eco().price_scale))


func hoist_available() -> bool:
	## The aspirational Hoist surfaces in the shop only once Drill/Fuel/Cargo
	## are deep (spec §4); "deep" is the hoist_reveal_min_level knob.
	var min_level: int = _eco().hoist_reveal_min_level
	return (
		levels["drill"] >= min_level
		and levels["fuel"] >= min_level
		and levels["cargo"] >= min_level
	)


func buy(track: String) -> bool:
	var price := next_price(track)
	if price < 0 or not Wallet.try_spend(price):
		return false
	levels[track] += 1
	upgrades_changed.emit()
	return true


func buy_hoist() -> bool:
	if hoist or not Wallet.try_spend(hoist_cost()):
		return false
	hoist = true
	upgrades_changed.emit()
	return true
