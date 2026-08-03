extends Node
## Autoload: EP1 Part I leaderboard — the client side (spec L2–L5). Local
## save is the SOLE source of truth; the board is a best-effort mirror. The
## whole feature runs FULLY OFFLINE by default (LeaderboardConfig.enabled()
## is false with no project URL) — no HTTPRequest is ever created, so the
## headless CI run makes no network call and "backend unreachable" is a
## normal state, never an error.
##
## Two metrics (spec L2): total_banked = the existing, monotonic
## MinersLog.stats["money_banked"] (read as-is, no parallel tally) and
## best_haul = a per-run accumulator persisted in the save. Scores are
## advisory/social and client-trusted — nothing downstream may assume they
## are authoritative.

## best_haul strictly increased during the current run — the sell-screen
## non-blocking banner's cue (spec L5-C). Rank text is folded in when a live
## board is configured; offline it reads as a new personal record.
signal best_haul_improved(value: int)
## Identity or dirty/sync state changed — the Miner's Log board tab refreshes.
signal board_changed

## Nickname bounds (spec L2): 3–16 chars, trimmed.
const NICK_MIN := 3
const NICK_MAX := 16

var config: LeaderboardConfig = preload("res://config/leaderboard.tres")

## Durable identity anchor (save blob). Generated on first run / migration.
var device_id := ""
## Display label (not unique). Auto-assigned default until the player renames.
var nickname := ""
## Best single surface-to-surface descent — persisted, monotonic.
var best_haul := 0

## Non-persisted (spec L4): a single dirty flag, no queue. A banking event
## sets it; a successful submit clears it. A missed post is harmless — the
## next absolute-value write under server GREATEST carries the truth.
var scores_dirty := false

## Run-scoped best_haul accumulator (spec L3): resets at descent start, folds
## every banking event in on the event itself (order-independent).
var _banked_this_run := 0
var _in_descent := false
var _deepest_this_run := 0

## Latest known global rank for this player's best_haul (0 = unknown/offline).
var _best_rank := 0

var _http: HTTPRequest = null
var _access_token := ""
var _posting := false
var _js_visibility_cb: JavaScriptObject


func _ready() -> void:
	GameState.cargo_sold.connect(_on_cargo_sold)
	GameState.depth_changed.connect(_on_depth_changed)
	GameState.run_lost.connect(_on_run_lost)
	# The visibility-hidden post piggybacks on the same signal SaveManager
	# flushes on (spec L3) — registered here independently so either can fire.
	if OS.has_feature("web"):
		_js_visibility_cb = JavaScriptBridge.create_callback(_on_js_visibility)
		JavaScriptBridge.get_interface("document").addEventListener(
			"visibilitychange", _js_visibility_cb
		)


func total_banked() -> int:
	## The lifetime metric IS the shipped counter — read as-is (spec L3).
	return int(MinersLog.stats.get("money_banked", 0))


func best_rank() -> int:
	return _best_rank


func online_configured() -> bool:
	return config.enabled()


# --- identity (spec L2 / L5-E: lazy, no first-run modal) ----------------------


func ensure_identity() -> void:
	## Called by Main after load: mint a durable device_id + a default nickname
	## if the save had none (new game, or a pre-v5 save that just migrated).
	if device_id.is_empty():
		device_id = _new_uuid()
	if nickname.strip_edges().is_empty():
		nickname = _default_nickname()
	board_changed.emit()


func set_nickname(name: String) -> bool:
	## Rename in place (spec L5-E) — client-enforced 3–16 chars, trimmed; the
	## server CHECK mirrors it. Rejects empty/whitespace-only.
	var trimmed := name.strip_edges()
	if trimmed.length() < NICK_MIN or trimmed.length() > NICK_MAX:
		return false
	nickname = trimmed
	scores_dirty = true
	board_changed.emit()
	_maybe_post()
	return true


func _default_nickname() -> String:
	## e.g. "Prospector-4F2A" — a stable label derived from the device_id, so
	## a fresh player always has a name without ever being prompted (spec L5-E).
	var tag := device_id.replace("-", "").substr(0, 4).to_upper()
	if tag.is_empty():
		tag = "0000"
	return "Prospector-%s" % tag


func _new_uuid() -> String:
	## RFC-4122-ish v4 UUID from runtime randomness (like GameState's seed, the
	## one sanctioned use of randi() — worldgen determinism is untouched).
	var b := PackedByteArray()
	b.resize(16)
	for i in range(16):
		b[i] = randi() & 0xFF
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var hex := b.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [
			hex.substr(0, 8),
			hex.substr(8, 4),
			hex.substr(12, 4),
			hex.substr(16, 4),
			hex.substr(20, 12)
		]
	)


# --- score capture (spec L3) --------------------------------------------------


func _on_depth_changed(depth: int) -> void:
	# Reset the per-run accumulator on descent start (first leave of the
	# surface); it then holds the run's total THROUGH the ending surface sell,
	# resetting only when the next descent begins (spec L3 — order-independent).
	if depth > 0 and not _in_descent:
		_in_descent = true
		_banked_this_run = 0
	_deepest_this_run = maxi(_deepest_this_run, depth)
	if depth == 0:
		_in_descent = false
		if _deepest_this_run >= MinersLog.RUN_MIN_DEPTH:
			_deepest_this_run = 0
			_maybe_post()  # run-complete trigger


func _on_cargo_sold(value: int) -> void:
	## Every banking event (surface sale OR hauler mid-descent bank) folds into
	## the record on the event itself — the max always already includes it.
	if value <= 0:
		return
	_banked_this_run += value
	scores_dirty = true
	if _banked_this_run > best_haul:
		best_haul = _banked_this_run
		best_haul_improved.emit(best_haul)
	board_changed.emit()


func _on_run_lost(_reason: String, _cargo_lost: int) -> void:
	# A lost descent banks nothing further; it keeps only what was hauled up
	# first (already folded via cargo_sold). Not a completed run — no post here.
	_deepest_this_run = 0
	_in_descent = false


# --- offline posture & posting (spec L4) --------------------------------------


func on_app_launch() -> void:
	## App-launch trigger (spec L4): catch up any dirty state from a prior
	## session that never got posted. A no-op offline.
	_maybe_post()


func _on_js_visibility(_args: Array) -> void:
	if str(JavaScriptBridge.eval("document.visibilityState", true)) == "hidden":
		_maybe_post()


func _maybe_post() -> void:
	## The single post path. Idempotent absolute-value write under server
	## GREATEST, so any backlog collapses into one catch-up post — no queue.
	## Gated: with no configured backend this returns immediately and the game
	## stays fully offline (local values remain the truth).
	if not config.enabled() or not scores_dirty or _posting:
		return
	_submit_scores()


func _submit_scores() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = config.request_timeout_secs
		add_child(_http)
	_posting = true
	var ok := await _ensure_session()
	if not ok:
		_posting = false
		return  # stays dirty; retries at the next trigger
	var body := JSON.stringify({"p_total": total_banked(), "p_best": best_haul})
	var err := _http.request(
		"%s/rest/v1/rpc/submit_score" % config.url(), _auth_headers(), HTTPClient.METHOD_POST, body
	)
	if err != OK:
		_posting = false
		return
	var res: Array = await _http.request_completed
	var code: int = res[1]
	if code >= 200 and code < 300:
		scores_dirty = false
		board_changed.emit()
	_posting = false


func _ensure_session() -> bool:
	## Anonymous sign-in (spec L1): a fresh anon auth.uid() as the write
	## credential; the durable device_id stays the identity anchor. Endpoint +
	## exact body are the one live-verify item (see supabase/README.md).
	if not _access_token.is_empty():
		return true
	var body := JSON.stringify({})
	var err := _http.request(
		"%s/auth/v1/signup" % config.url(),
		["apikey: %s" % config.key(), "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		return false
	var res: Array = await _http.request_completed
	var code: int = res[1]
	if code < 200 or code >= 300:
		return false
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if parsed is Dictionary and parsed.has("access_token"):
		_access_token = str(parsed["access_token"])
		return true
	return false


func _auth_headers() -> PackedStringArray:
	return PackedStringArray(
		[
			"apikey: %s" % config.key(),
			"Authorization: Bearer %s" % _access_token,
			"Content-Type: application/json",
		]
	)


# --- save envelope (save_version 5) -------------------------------------------


func build_state() -> Dictionary:
	return {"best_haul": best_haul, "device_id": device_id, "nickname": nickname}


func load_state(env: Dictionary) -> void:
	## Read the flat EP1 fields from the envelope (spec §E3). Defensive: a
	## pre-v5 save (already migrated to carry the keys) or a mistyped value
	## falls back to empty/zero, and ensure_identity() then mints defaults.
	var bh: Variant = env.get("best_haul", 0)
	best_haul = maxi(0, int(bh)) if (bh is int or bh is float) else 0
	var did: Variant = env.get("device_id", "")
	device_id = str(did) if did is String else ""
	var nick: Variant = env.get("nickname", "")
	nickname = str(nick) if nick is String else ""
	_banked_this_run = 0
	_in_descent = false
	_deepest_this_run = 0
	scores_dirty = false
	board_changed.emit()
