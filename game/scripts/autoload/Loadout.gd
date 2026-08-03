extends Node
## Autoload: the EP1 consumable loadout (spec C1) — the 3-slot × one-type ×
## N-charges model. Slots gate variety, charges gate quantity. Tools unlock
## by depth-gated shop visibility + a one-time unlock price; charges are
## bought into garage stock (capped at maxCharges — scarcity's home). Only
## the active-slot tools descend and are at risk: their charges are forfeited
## on a lost run, while garage-stored charges of inactive tools stay safe
## (extends the shipped carried = at risk / banked = safe asymmetry).
##
## This autoload owns the DISCRETIONARY, never-mandatory guardrail: a broke
## player always progresses by drilling + free refuel/repair — consumables
## are a cash sink you can ignore. It carries state + economy only; the
## in-run EFFECTS live in the per-scene ToolRunner (calls consume() on use).

signal loadout_changed
signal stock_changed(tool: String, count: int)
## A tool was activated in-run and its charge spent — the HUD flashes the
## button, the ToolRunner has already applied the effect.
signal tool_used(tool: String)

var config: ConsumablesConfig = preload("res://config/consumables.tres")

## tool -> bool: the one-time unlock price has been paid (tool is stockable).
var unlocked := {}
## tool -> int: charges held in garage stock, 0..config.cap_of(tool).
var stock := {}
## Up to config.active_slots tool ids, in slot order — the descend-with set.
var loadout: Array[String] = []


func _ready() -> void:
	reset()
	GameState.run_lost.connect(_on_run_lost)


func reset() -> void:
	unlocked = {}
	stock = {}
	for tool in config.TOOLS:
		unlocked[tool] = false
		stock[tool] = 0
	loadout = []


# --- shop visibility, unlock & stock (spec C1) -------------------------------


func is_visible(tool: String) -> bool:
	## Depth-gated shop visibility: the tool appears once the player has ever
	## reached its unlock depth (lifetime deepest — the opening hour stays pure
	## core-loop, the >=120 gate).
	return int(MinersLog.stats.get("deepest_depth", 0)) >= int(config.unlock_depth.get(tool, 0))


func is_unlocked(tool: String) -> bool:
	return bool(unlocked.get(tool, false))


func unlock(tool: String) -> bool:
	## Pay the one-time unlock price. No-op (false) if hidden, already unlocked,
	## or unaffordable — the wallet can never go negative (no death spiral).
	if is_unlocked(tool) or not is_visible(tool):
		return false
	if not Wallet.try_spend(int(config.unlock_price.get(tool, 0))):
		return false
	unlocked[tool] = true
	loadout_changed.emit()
	return true


func buy_charge(tool: String) -> bool:
	## Buy one charge into garage stock, capped at maxCharges (scarcity).
	if not is_unlocked(tool) or int(stock.get(tool, 0)) >= config.cap_of(tool):
		return false
	if not Wallet.try_spend(int(config.per_charge_price.get(tool, 0))):
		return false
	stock[tool] = int(stock.get(tool, 0)) + 1
	stock_changed.emit(tool, stock[tool])
	return true


func charges(tool: String) -> int:
	return int(stock.get(tool, 0))


# --- the 3 active slots (spec C1 / C3) ---------------------------------------


func is_active(tool: String) -> bool:
	return loadout.has(tool)


func toggle_active(tool: String) -> void:
	## Equip/unequip a tool into the active slots. Add-only up to the slot cap;
	## re-tapping an equipped tool frees its slot.
	if not is_unlocked(tool):
		return
	if loadout.has(tool):
		loadout.erase(tool)
	elif loadout.size() < int(config.active_slots):
		loadout.append(tool)
	else:
		return
	loadout_changed.emit()


func active_tools() -> Array[String]:
	return loadout


func has_equipped_gear() -> bool:
	return not loadout.is_empty()


func can_use(tool: String) -> bool:
	## Usable in-run: equipped in an active slot and a charge remains.
	return loadout.has(tool) and int(stock.get(tool, 0)) > 0


func consume(tool: String) -> bool:
	## Spend one charge — called by the ToolRunner AFTER an effect commits.
	if not can_use(tool):
		return false
	stock[tool] = int(stock.get(tool, 0)) - 1
	stock_changed.emit(tool, stock[tool])
	tool_used.emit(tool)
	return true


func _on_run_lost(_reason: String, _cargo_lost: int) -> void:
	## Carried = at risk: the active-slot charges that descended are forfeited
	## (extends the shipped rule). Inactive tools' garage stock is untouched.
	var changed := false
	for tool in loadout:
		if int(stock.get(tool, 0)) > 0:
			stock[tool] = 0
			stock_changed.emit(tool, 0)
			changed = true
	if changed:
		loadout_changed.emit()


# --- save envelope (save_version 5) ------------------------------------------


func build_state() -> Dictionary:
	## The EP1 `consumables` block of the save envelope (safe/surface state:
	## a lost run has already forfeited before any snapshot).
	return {
		"unlocked": unlocked.duplicate(),
		"stock": stock.duplicate(),
		"loadout": loadout.duplicate(),
	}


func load_state(data: Dictionary) -> void:
	## Load defensively (spec §13): missing/mistyped key -> default. Unknown
	## tool ids from a newer build are ignored; caps are re-clamped so a hand
	## edited or future save can never exceed current scarcity.
	reset()
	var unlocked_in: Variant = data.get("unlocked")
	if unlocked_in is Dictionary:
		for tool in config.TOOLS:
			unlocked[tool] = bool(unlocked_in.get(tool, false))
	var stock_in: Variant = data.get("stock")
	if stock_in is Dictionary:
		for tool in config.TOOLS:
			var v: Variant = stock_in.get(tool, 0)
			var n := int(v) if (v is int or v is float) else 0
			stock[tool] = clampi(n, 0, config.cap_of(tool))
	var loadout_in: Variant = data.get("loadout")
	if loadout_in is Array:
		for tool: Variant in loadout_in:
			if (
				tool is String
				and config.TOOLS.has(tool)
				and bool(unlocked.get(tool, false))
				and not loadout.has(tool)
				and loadout.size() < int(config.active_slots)
			):
				loadout.append(tool)
	loadout_changed.emit()
