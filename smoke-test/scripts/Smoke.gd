class_name SmokeMain
extends Node2D
## iOS Safari platform smoke-test harness — wayfinder ticket 0011.
##
## THROWAWAY. Its only job is to let Fiachra *see with his eyes* whether a
## single-threaded Godot 4.3 web export behaves on a real iPhone the way ticket
## 0002 predicts. It deliberately proves the four platform facts 0002 rests on
## and surfaces every result on-screen (no devtools required):
##
##   1. Touch input works        — a gem sprite follows your finger.
##   2. Audio unlocks on gesture — a Sample-playback blip fires on every tap.
##   3. WebGL2/Compatibility up  — renderer/driver string + "WebGL2 OK".
##   4. Memory stays bounded     — live FPS + WASM linear heap + Godot static
##                                 memory + peak, so a leak/OOM is visible, and
##                                 a resize counter so rotate/resize churn (the
##                                 0002 §4 canvas-resize crash) is measurable.
##
## It also watches for a WebGL "context lost" event (0002 §4) and shows it big
## and red if it ever fires. No game systems here — this is a platform probe.

var _sprite_pos: Vector2
var _sprite_target: Vector2
var _taps: int = 0
var _resizes: int = 0
var _audio: AudioStreamPlayer

# HUD labels
var _lbl_render: Label
var _lbl_fps: Label
var _lbl_mem: Label
var _lbl_touch: Label
var _lbl_ctx: Label

# cached / polled figures
var _fps: float = 0.0
var _static_mb: float = 0.0
var _peak_static_mb: float = 0.0
var _wasm_mb: float = -1.0
var _peak_wasm_mb: float = -1.0
var _js_heap_mb: float = -1.0
var _cap_mb: int = -1
var _ctx_lost: bool = false

var _render_method: String = ""
var _render_driver: String = ""
var _adapter: String = ""
var _webgl2_ok: bool = false
var _is_web: bool = false

var _poll_accum: float = 0.0
const POLL_EVERY := 0.25  # seconds — throttle JS bridge reads


func _ready() -> void:
	var vp := get_viewport_rect().size
	_sprite_pos = vp * 0.5
	_sprite_target = _sprite_pos

	_is_web = OS.has_feature("web")

	_setup_audio()
	_probe_renderer()
	_setup_js_hooks()
	_build_hud()

	# Rotate/resize is the 0002 §4 canvas-resize hazard — count every one so the
	# memory figures beside it can be watched for growth across resizes.
	get_tree().get_root().size_changed.connect(_on_resized)

	set_process(true)


func _setup_audio() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.stream = _make_blip()
	# Sample playback (0002 §3) — low latency without threads, the reason a
	# single-threaded web build sounds fine on iOS Safari. Force it explicitly
	# rather than relying only on the project default so the intent is legible.
	_audio.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	add_child(_audio)


## Generate a short one-shot blip as a 16-bit PCM AudioStreamWAV. A WAV/sample
## (not a procedural AudioStreamGenerator, which web Sample playback can't do —
## 0002 §3) is exactly what Sample playback wants.
func _make_blip() -> AudioStreamWAV:
	var sr := 22050
	var dur := 0.14
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(sr)
		var env := 1.0 - float(i) / float(n)      # linear decay
		var tone := sin(TAU * 720.0 * t)
		var s: float = clampf(tone * env * 0.6, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = data
	return wav


func _probe_renderer() -> void:
	# Godot 4.3 has NO get_current_rendering_method()/driver_name() on OS *or*
	# RenderingServer (those arrived in a later 4.x) — calling them is a GDScript
	# parse error that fails the whole script to load, so the scene runs nothing
	# and iOS shows only the default grey clear colour. Use what 4.3 actually has:
	# the configured method from ProjectSettings, and the video-adapter calls
	# (get_video_adapter_name/api_version exist in 4.3).
	_render_method = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
	_render_driver = RenderingServer.get_video_adapter_api_version()  # e.g. "WebGL 2.0 ..." on web
	_adapter = RenderingServer.get_video_adapter_name()
	# gl_compatibility is the only web renderer (0002 §2) and it targets WebGL 2.0,
	# so the configured method being gl_compatibility IS the "WebGL2 up" signal;
	# the api-version string above shows the live "WebGL 2.0" for the eye.
	_webgl2_ok = _render_method == "gl_compatibility"


## Inject the JS hooks the readouts depend on. The WASM-memory clamp itself
## lives in the export's head_include (web/head_include.html), which runs before
## the engine boots; here we only add a belt-and-braces context-lost listener in
## case head_include was stripped.
func _setup_js_hooks() -> void:
	if not _is_web:
		return
	JavaScriptBridge.eval(
		"""
		if (window.__ctxLost === undefined) {
			window.__ctxLost = false;
			window.addEventListener('webglcontextlost', function(){ window.__ctxLost = true; }, true);
		}
		""",
		true
	)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat gameplay touches
	layer.add_child(root)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(12, 40)  # keep clear of the notch / status bar
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var title := Label.new()
	title.text = "iOS SMOKE TEST (0011)"
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)

	_lbl_render = _make_label(col)
	_lbl_fps = _make_label(col)
	_lbl_mem = _make_label(col)
	_lbl_touch = _make_label(col)

	# Big context-lost banner (0002 §4). Empty unless it fires.
	_lbl_ctx = Label.new()
	_lbl_ctx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_ctx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_ctx.position = Vector2(20, 300)
	_lbl_ctx.size = Vector2(400, 120)
	_lbl_ctx.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_lbl_ctx.add_theme_font_size_override("font_size", 24)
	root.add_child(_lbl_ctx)

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Tap = play blip (unlocks audio). Drag = move the gem. Rotate the phone to stress resize."
	hint.position = Vector2(12, 812)
	hint.size = Vector2(416, 60)
	root.add_child(hint)


func _make_label(parent: Node) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 17)
	parent.add_child(l)
	return l


# --- input -----------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_sprite_target = event.position
			_taps += 1
			_play_blip()
	elif event is InputEventScreenDrag:
		_sprite_target = event.position


func _play_blip() -> void:
	_audio.play()


# --- resize ----------------------------------------------------------------
func _on_resized() -> void:
	_resizes += 1
	# Keep the sprite on-screen after a rotate so it stays visible.
	var vp := get_viewport_rect().size
	_sprite_target.x = clampf(_sprite_target.x, 20.0, vp.x - 20.0)
	_sprite_target.y = clampf(_sprite_target.y, 20.0, vp.y - 20.0)


# --- per-frame -------------------------------------------------------------
func _process(delta: float) -> void:
	# ease the sprite toward its target so the follow reads as smooth motion
	_sprite_pos = _sprite_pos.lerp(_sprite_target, clampf(delta * 14.0, 0.0, 1.0))
	queue_redraw()

	_fps = Engine.get_frames_per_second()

	_poll_accum += delta
	if _poll_accum >= POLL_EVERY:
		_poll_accum = 0.0
		_poll_memory()

	_refresh_hud()


func _poll_memory() -> void:
	_static_mb = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	_peak_static_mb = maxf(_peak_static_mb, _static_mb)

	if not _is_web:
		return
	# WASM linear heap size — works on Safari (buffer.byteLength is standard),
	# unlike performance.memory which is Chrome-only. This is the figure that
	# grows toward the clamped cap if anything leaks (0002 §4). Populated by the
	# head_include shim which stashes the engine's WebAssembly.Memory globally.
	var wasm := float(JavaScriptBridge.eval(
		"(window.__godotWasmMemory && window.__godotWasmMemory.buffer) ? window.__godotWasmMemory.buffer.byteLength : -1",
		true
	))
	if wasm >= 0.0:
		_wasm_mb = wasm / 1048576.0
		_peak_wasm_mb = maxf(_peak_wasm_mb, _wasm_mb)

	var heap := float(JavaScriptBridge.eval(
		"(window.performance && performance.memory) ? performance.memory.usedJSHeapSize : -1",
		true
	))
	_js_heap_mb = (heap / 1048576.0) if heap >= 0.0 else -1.0

	_cap_mb = int(JavaScriptBridge.eval("window.__wasmMemCapMB || -1", true))
	_ctx_lost = bool(JavaScriptBridge.eval("window.__ctxLost === true", true))


func _refresh_hud() -> void:
	var ok := "WebGL2 OK" if _webgl2_ok else "WebGL2 ??"
	_lbl_render.text = "%s  |  %s / %s\n%s" % [ok, _render_method, _render_driver, _adapter]

	_lbl_fps.text = "FPS: %d   resizes: %d" % [int(round(_fps)), _resizes]

	var mem := "Godot static: %.1f MB (peak %.1f)" % [_static_mb, _peak_static_mb]
	if _wasm_mb >= 0.0:
		mem += "\nWASM heap: %.1f MB (peak %.1f)" % [_wasm_mb, _peak_wasm_mb]
	if _cap_mb > 0:
		mem += "  cap %d MB" % _cap_mb
	if _js_heap_mb >= 0.0:
		mem += "\nJS heap: %.1f MB" % _js_heap_mb
	elif _is_web:
		mem += "\nJS heap: n/a (Safari)"
	_lbl_mem.text = mem

	_lbl_touch.text = "taps: %d" % _taps

	_lbl_ctx.text = "⚠ WEBGL CONTEXT LOST" if _ctx_lost else ""


# --- draw ------------------------------------------------------------------
func _draw() -> void:
	# a "gem" sprite (faceted diamond) that follows the finger — the touch proof
	var p := _sprite_pos
	var r := 34.0
	var top := p + Vector2(0, -r)
	var right := p + Vector2(r, 0)
	var bottom := p + Vector2(0, r)
	var left := p + Vector2(-r, 0)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Color(0.37, 0.78, 0.88))
	draw_colored_polygon(PackedVector2Array([top, right, p]), Color(0.56, 0.88, 0.94))
	draw_colored_polygon(PackedVector2Array([top, left, p]), Color(0.25, 0.61, 0.72))
	# a faint target ring where the finger last was, so drag is legible
	draw_arc(_sprite_target, r + 10.0, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 2.0)
