extends Node
## Autoload: the save system (spec §13). One file, user://save.dat — on the
## web that is IndexedDB via Emscripten IDBFS, and Godot auto-syncs it (never
## call syncfs). The envelope is a plain Dictionary, never a Resource/class.
##
## Snapshot cadence: surface events (arrive / sell / upgrade), run lost, and
## visibilitychange -> hidden (the critical iOS flush — the reliable "going
## away" signal). Never per-dug-tile.
##
## The SaveBlob seam: serialize_blob()/deserialize_blob() turn the envelope
## into bytes and back — the local file, the export download, the import
## file-input, and any future cloud PUT/GET all consume the same bytes.

signal import_succeeded
signal import_failed(reason: String)

const SAVE_PATH := "user://save.dat"
const SAVE_VERSION := 3
const EXPORT_FILENAME := "gem-miner-save.dat"
const IMPORT_INPUT_ID := "gem-miner-import"

## Surface-arrive snapshots only fire when the run actually went underground:
## the depth signal flickers 0<->1 while hovering at the surface line, and
## each of those must not be a disk write (cadence plumbing, not a knob).
const ARRIVE_SAVE_MIN_DEPTH := 4

## The hidden HTML file input the import hatch clicks (spec §13). It reads
## the chosen file and hands the bytes to GDScript as base64 through the
## window.gemMinerImport callback.
const _IMPORT_INPUT_JS := """
(function () {
	if (document.getElementById('gem-miner-import')) { return; }
	var el = document.createElement('input');
	el.type = 'file';
	el.id = 'gem-miner-import';
	el.style.display = 'none';
	el.addEventListener('change', function () {
		var file = el.files && el.files[0];
		el.value = '';
		if (!file) { return; }
		var reader = new FileReader();
		reader.onload = function () {
			var bytes = new Uint8Array(reader.result);
			var bin = '';
			for (var i = 0; i < bytes.length; i++) {
				bin += String.fromCharCode(bytes[i]);
			}
			window.gemMinerImport(btoa(bin));
		};
		reader.readAsArrayBuffer(file);
	});
	document.body.appendChild(el);
})();
"""

## Suppresses snapshot triggers while a load is mutating the very state the
## triggers listen to.
var _loading := false
var _deepest_since_save := 0

# Kept as members so the browser-side callbacks are never garbage-collected.
var _js_visibility_cb: JavaScriptObject
var _js_import_cb: JavaScriptObject


func _ready() -> void:
	_connect_snapshot_triggers()
	_init_web_hooks()


func _notification(what: int) -> void:
	# Desktop/mobile-app equivalents of the hidden flush.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


# --- the envelope (spec §13) ---------------------------------------------------


func build_envelope() -> Dictionary:
	## The §13 envelope: a plain Dictionary, never a Resource/class.
	var collected := PackedInt32Array()
	for tile: Vector2i in GameState.collected.keys():
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
		"run": null,  # best-effort mid-run state — still a stub (spec §13)
		"stats": MinersLog.stats.duplicate(),  # 0012 (spec §8)
		"milestones": MinersLog.milestones.duplicate(),  # 0012 (spec §8)
		"nudges":  # 0013 (spec §9)
		{
			"audio_hint_shown": Nudges.audio_hint_shown,
			"a2hs_dismissed": Nudges.a2hs_dismissed,
		},
		"settings":  # §7 reduce-motion toggle (session 6)
		{
			"motion_mode": Settings.motion_mode,
		},
		"meta":
		{
			"saved_at": int(Time.get_unix_time_from_system()),
			"play_secs": 0,
			"schema_note": "vertical slice 6",
		},
	}


func apply_envelope(env: Dictionary) -> void:
	## Load defensively (spec §13): missing or mistyped key -> default. The
	## envelope's "run" is null/stubbed, so every load starts at the surface,
	## topped up.
	GameState.world_seed = _int_in(env, "world_seed", 0)
	var world := _dict_in(env, "world")
	GameState.dug.clear()
	var dug_in: Variant = world.get("dug")
	if dug_in is Dictionary:
		for cc: Variant in dug_in:
			if cc is Vector2i and dug_in[cc] is PackedByteArray:
				GameState.dug[cc] = dug_in[cc]
	GameState.collected.clear()
	var flat: Variant = world.get("collected")
	if flat is PackedInt32Array:
		var i := 0
		while i + 1 < flat.size():
			GameState.collected[Vector2i(flat[i], flat[i + 1])] = true
			i += 2
	Wallet.money = maxi(0, _int_in(env, "wallet", 0))
	var up := _dict_in(env, "upgrades")
	for track: String in Upgrades.levels.keys():
		Upgrades.levels[track] = clampi(_int_in(up, track, 0), 0, Upgrades.max_level(track))
	Upgrades.hoist = bool(up.get("hoist", false))
	MinersLog.load_state(_dict_in(env, "stats"), _dict_in(env, "milestones"))
	Nudges.load_state(_dict_in(env, "nudges"))
	Settings.load_state(_dict_in(env, "settings"))
	GameState.cargo.clear()
	GameState.top_up()
	GameState.set_depth(0)


# --- the SaveBlob seam ----------------------------------------------------------


func serialize_blob() -> PackedByteArray:
	## Outbound: the envelope as bytes. Local file, export download, and any
	## future cloud PUT all consume exactly these.
	return var_to_bytes(build_envelope())


func deserialize_blob(bytes: PackedByteArray) -> Dictionary:
	## Inbound: bytes -> validated, migrated envelope, or {} when corrupt.
	## save_version is checked first; world_seed absent => corrupt (spec §13).
	var parsed: Variant = bytes_to_var(bytes)
	if not (parsed is Dictionary):
		return {}
	var env: Dictionary = parsed
	if not (env.get("save_version") is int):
		return {}
	if int(env["save_version"]) > SAVE_VERSION:
		return {}  # from a future build — refuse rather than mangle
	env = _migrate(env)
	if env.is_empty() or not (env.get("world_seed") is int):
		return {}
	return env


func _migrate(env: Dictionary) -> Dictionary:
	## The ordered, pure migrate(dict) -> dict chain (spec §13): each step
	## bumps save_version by exactly one; only ever add keys or bump the
	## version. Anything older than the oldest step is treated as corrupt.
	while int(env.get("save_version", 0)) < SAVE_VERSION:
		match int(env.get("save_version", 0)):
			1:
				env = _migrate_1_to_2(env)
			2:
				env = _migrate_2_to_3(env)
			_:
				return {}
	return env


func _migrate_1_to_2(env: Dictionary) -> Dictionary:
	## v1 -> v2 (session 5): the 0012/0013 keys — stats / milestones /
	## nudges — become live state. Keys are only ADDED; a v1 save loads
	## clean and starts counting from zero (v1 builds already wrote empty
	## placeholders for all three, so this mostly just bumps the version).
	if not (env.get("stats") is Dictionary):
		env["stats"] = {}
	if not (env.get("milestones") is Dictionary):
		env["milestones"] = {}
	if not (env.get("nudges") is Dictionary):
		env["nudges"] = {"audio_hint_shown": false, "a2hs_dismissed": 0}
	env["save_version"] = 2
	return env


func _migrate_2_to_3(env: Dictionary) -> Dictionary:
	## v2 -> v3 (session 6): the `settings` key — the §7 reduce-motion
	## toggle's home. Key only ADDED; a v2 save loads clean on auto.
	if not (env.get("settings") is Dictionary):
		env["settings"] = {"motion_mode": Settings.Motion.AUTO}
	env["save_version"] = 3
	return env


# --- local file -----------------------------------------------------------------


func save_now() -> void:
	## Whole-file snapshot. On the web, closing the file hands it to IDBFS
	## and Godot schedules the async sync itself.
	if _loading:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: FileAccess error %d" % FileAccess.get_open_error())
		return
	f.store_buffer(serialize_blob())
	f.close()


func load_game() -> bool:
	## Load-on-boot. false => no usable save (absent or corrupt); the caller
	## starts a new game.
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var env := deserialize_blob(bytes)
	if env.is_empty():
		return false
	_loading = true
	apply_envelope(env)
	_loading = false
	return true


# --- the export/import safety hatch (spec §13) -----------------------------------


func export_save() -> void:
	## OUT: download the same SaveBlob bytes as the local file.
	save_now()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(
			serialize_blob(), EXPORT_FILENAME, "application/octet-stream"
		)
	else:
		print("export: save written to ", ProjectSettings.globalize_path(SAVE_PATH))


func request_import() -> void:
	## IN: click the hidden file input. The caller has already shown the
	## "this replaces your progress" confirm (spec §13).
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.getElementById('%s').click();" % IMPORT_INPUT_ID, true)
	else:
		import_failed.emit("import needs the web build")


func import_bytes(bytes: PackedByteArray) -> void:
	## Validate, persist the (migrated) envelope, and reboot into it — the
	## boot path is the single place a save becomes live state.
	var env := deserialize_blob(bytes)
	if env.is_empty():
		import_failed.emit("not a valid save file")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		import_failed.emit("could not write the save file")
		return
	f.store_buffer(var_to_bytes(env))
	f.close()
	import_succeeded.emit()
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- snapshot triggers (spec §13 cadence) -----------------------------------------


func _connect_snapshot_triggers() -> void:
	GameState.cargo_sold.connect(_on_cargo_sold)
	GameState.run_lost.connect(_on_run_lost)
	GameState.depth_changed.connect(_on_depth_changed)
	Upgrades.upgrades_changed.connect(save_now)


func _on_cargo_sold(_value: int) -> void:
	save_now()


func _on_run_lost(_reason: String, _cargo_lost: int) -> void:
	save_now()


func _on_depth_changed(depth: int) -> void:
	_deepest_since_save = maxi(_deepest_since_save, depth)
	if depth == 0 and _deepest_since_save >= ARRIVE_SAVE_MIN_DEPTH:
		_deepest_since_save = 0
		save_now()


# --- browser hooks (web only) ------------------------------------------------------


func _init_web_hooks() -> void:
	if not OS.has_feature("web"):
		return
	# Ask for durable storage (spec §13): a silent grant on WebKit, and the
	# best defence against the 7-day no-interaction eviction cap.
	JavaScriptBridge.eval(
		"if (navigator.storage && navigator.storage.persist) { navigator.storage.persist(); }", true
	)
	# The critical iOS flush: snapshot the moment the page goes hidden so the
	# async IDBFS sync has something current to carry.
	_js_visibility_cb = JavaScriptBridge.create_callback(_on_js_visibility_changed)
	JavaScriptBridge.get_interface("document").addEventListener(
		"visibilitychange", _js_visibility_cb
	)
	_js_import_cb = JavaScriptBridge.create_callback(_on_js_import_file)
	JavaScriptBridge.get_interface("window").gemMinerImport = _js_import_cb
	JavaScriptBridge.eval(_IMPORT_INPUT_JS, true)


func _on_js_visibility_changed(_args: Array) -> void:
	if str(JavaScriptBridge.eval("document.visibilityState", true)) == "hidden":
		save_now()


func _on_js_import_file(args: Array) -> void:
	if args.is_empty():
		import_failed.emit("no file chosen")
		return
	import_bytes(Marshalls.base64_to_raw(str(args[0])))


# --- defensive typed getters -----------------------------------------------------


func _int_in(env: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = env.get(key)
	if v is int:
		return v
	if v is float:
		return int(v)
	return fallback


func _dict_in(env: Dictionary, key: String) -> Dictionary:
	var v: Variant = env.get(key)
	return v if v is Dictionary else {}
