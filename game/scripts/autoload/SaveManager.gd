extends Node
## Autoload STUB: the save system (spec §13) is a later session. What exists
## now is the SaveBlob seam — one function serializes the whole envelope to
## a plain Dictionary, one applies it back — so local file, export/import,
## and any future cloud PUT/GET all consume the same bytes.
##
## Later session wires: user:// (IndexedDB) snapshots on surface events and
## visibilitychange->hidden flush, save_version migrations, and the
## export/import safety hatch via JavaScriptBridge.

const SAVE_PATH := "user://save.dat"
const SAVE_VERSION := 1


func build_envelope() -> Dictionary:
	## The §13 envelope: a plain Dictionary, never a Resource/class.
	var collected := PackedInt32Array()
	for tile in GameState.collected.keys():
		collected.append(tile.x)
		collected.append(tile.y)
	return {
		"save_version": SAVE_VERSION,
		"world_seed": GameState.world_seed,
		"world":
		{
			"dug": GameState.dug.duplicate(),
			"collected": collected,
		},
		"wallet": Wallet.money,
		"upgrades":
		{
			"drill": Upgrades.levels["drill"],
			"fuel": Upgrades.levels["fuel"],
			"cargo": Upgrades.levels["cargo"],
			"hull": Upgrades.levels["hull"],
			"light": Upgrades.levels["light"],
			"hoist": Upgrades.hoist,
		},
		"run": null,
		"stats": {},  # 0012 — later session
		"milestones": {},  # 0012 — later session
		"nudges": {"audio_hint_shown": false, "a2hs_dismissed": 0},  # 0013
		"meta": {"saved_at": 0, "play_secs": 0, "schema_note": "vertical slice"},
	}


func apply_envelope(env: Dictionary) -> void:
	## Load defensively: missing key -> default (spec §13). world_seed absent
	## means corrupt — caller should fall back to new_game().
	GameState.world_seed = env.get("world_seed", 0)
	GameState.dug = env.get("world", {}).get("dug", {})
	GameState.collected.clear()
	var flat: PackedInt32Array = env.get("world", {}).get("collected", PackedInt32Array())
	var i := 0
	while i + 1 < flat.size():
		GameState.collected[Vector2i(flat[i], flat[i + 1])] = true
		i += 2
	Wallet.money = env.get("wallet", 0)
	var up: Dictionary = env.get("upgrades", {})
	for track in ["drill", "fuel", "cargo", "hull", "light"]:
		Upgrades.levels[track] = up.get(track, 0)
	Upgrades.hoist = up.get("hoist", false)
