extends CanvasLayer
## Autoload: the §16 memory-profiling overlay — the quiet debug readout the
## owner reads numbers off a real iPhone with. Hidden by default and NEVER
## ships visible: the only way in is the hidden corner-tap pattern on the
## tap-to-start screen (TitleScreen — deliberately not a hub census item,
## the §9 census is closed). Costs ~nothing while hidden: processing is off
## and nothing polls.
##
## What it reads, and why each number exists:
##  - WASM heap (MB, + peak): the Emscripten linear memory's
##    buffer.byteLength via JavaScriptBridge — THE Safari-safe heap signal
##    (performance.memory is Chrome-only; Performance.MEMORY_STATIC reads 0
##    on web). Captured by the head_include shim (game/web/head_include.html)
##    wrapping WebAssembly.instantiate(Streaming) — the engine's memory is
##    module-defined and exported, never JS-constructed, which is why 0011's
##    Memory-constructor capture could never fire.
##  - Godot-side counters that already work everywhere: resident chunk count
##    and generation queue (the §12 bounded window, OBSERVED never changed),
##    pickups, lava shapes, prize tiles, node/object counts, FPS, depth.
##  - Resize count + WebGL context-lost flag (the 0002 §4 hazards the 0011
##    smoke test watched — this overlay supersedes it, spec §14).

const _WASM_HEAP_JS := (
	"(window.__godotWasmMemory && window.__godotWasmMemory.buffer)"
	+ " ? window.__godotWasmMemory.buffer.byteLength : -1"
)

## Seconds between JavaScriptBridge polls while visible (eval isn't free).
@export var poll_interval_secs := 0.5

var _mine: Mine
var _label: Label
var _wasm_mb := -1.0
var _peak_wasm_mb := -1.0
var _ctx_lost := false
var _resizes := 0
var _poll_accum := 0.0


func _ready() -> void:
	# Above the HUD and the Juice flash: a debug readout must never be
	# occluded by the thing it is measuring.
	layer = 4
	visible = false
	set_process(false)

	_label = Label.new()
	# A runtime-added top-level Control under a CanvasLayer has no real size
	# until a resize fires (the session-5/TitleScreen lesson) — drive the
	# rect from the viewport explicitly and re-sync on size_changed.
	# Right-aligned, clear of the left HUD bars.
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_fit_label()

	# Counting resizes is one integer increment — cheap enough to always run,
	# and rotate churn before the overlay is opened still gets counted.
	get_tree().root.size_changed.connect(_on_resized)


func _fit_label() -> void:
	var rect := get_viewport().get_visible_rect()
	_label.position = Vector2(12.0, 12.0)
	_label.size = Vector2(rect.size.x - 24.0, 240.0)


func register(mine: Mine) -> void:
	## Called by Main each scene boot, like Juice.register.
	_mine = mine


func toggle() -> void:
	## The one way in/out (TitleScreen's hidden corner-tap pattern). Session
	## only — never persisted, so it can never ship visible.
	visible = not visible
	set_process(visible)
	if visible:
		_poll()
		_refresh()


func _on_resized() -> void:
	_resizes += 1
	_fit_label()


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum >= poll_interval_secs:
		_poll_accum = 0.0
		_poll()
	_refresh()


func _poll() -> void:
	if not OS.has_feature("web"):
		return
	var wasm := float(JavaScriptBridge.eval(_WASM_HEAP_JS, true))
	if wasm >= 0.0:
		_wasm_mb = wasm / 1048576.0
		_peak_wasm_mb = maxf(_peak_wasm_mb, _wasm_mb)
	_ctx_lost = bool(JavaScriptBridge.eval("window.__ctxLost === true", true))


func _refresh() -> void:
	var lines: Array[String] = []
	lines.append("FPS %d · resizes %d" % [int(round(Engine.get_frames_per_second())), _resizes])
	if _wasm_mb >= 0.0:
		lines.append("WASM heap %.1f MB (peak %.1f)" % [_wasm_mb, _peak_wasm_mb])
	elif OS.has_feature("web"):
		lines.append("WASM heap n/a (capture missing)")
	var static_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	lines.append("static %.1f MB · nodes %d · objects %d" % [static_mb, nodes, objects])
	if is_instance_valid(_mine):
		var c := _mine.debug_counts()
		lines.append(
			"chunks %d (queued %d) · pickups %d" % [c["chunks"], c["queued"], c["pickups"]]
		)
		lines.append("lava shapes %d · prize tiles %d" % [c["lava_shapes"], c["prize_tiles"]])
	lines.append("depth %d" % GameState.depth)
	if _ctx_lost:
		lines.append("!! WEBGL CONTEXT LOST !!")
	_label.text = "\n".join(lines)
