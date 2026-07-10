class_name PrototypeMain
extends Node2D
## Prototype orchestrator + HUD. Builds the grey-box mine, the digger, and an
## on-screen control panel so all three schemes / two movement modes / two dig
## timings can be compared LIVE on one build — no rebuild to switch. THROWAWAY.

# live settings the Player reads each frame
var scheme: int = DiggerPlayer.Scheme.TAP
var move_mode: int = DiggerPlayer.Move.FLOATY
var dig_mode: int = DiggerPlayer.Dig.DRILL

var grid: DigGrid
var player: DiggerPlayer

var _scheme_btn: Button
var _move_btn: Button
var _dig_btn: Button
var _fuel: ProgressBar
var _status: Label
var _hint: Label
var _flash: Label
var _flash_time := 0.0

func _ready() -> void:
	grid = DigGrid.new()
	add_child(grid)
	grid.setup()

	player = DiggerPlayer.new()
	player.grid = grid
	player.main = self
	add_child(player)

	_build_hud()
	_refresh_buttons()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var bar := VBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(8, 6)
	bar.add_theme_constant_override("separation", 4)
	root.add_child(bar)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	_scheme_btn = _make_button("Scheme")
	_scheme_btn.pressed.connect(_cycle_scheme)
	row.add_child(_scheme_btn)

	_move_btn = _make_button("Move")
	_move_btn.pressed.connect(_cycle_move)
	row.add_child(_move_btn)

	_dig_btn = _make_button("Dig")
	_dig_btn.pressed.connect(_cycle_dig)
	row.add_child(_dig_btn)

	var reset_btn := _make_button("Reset mine")
	reset_btn.pressed.connect(_reset)
	bar.add_child(reset_btn)

	_fuel = ProgressBar.new()
	_fuel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuel.custom_minimum_size = Vector2(220, 16)
	_fuel.min_value = 0
	_fuel.max_value = 100
	_fuel.show_percentage = true
	bar.add_child(_fuel)

	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_status)

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(10, 838)
	_hint.custom_minimum_size = Vector2(420, 34)
	_hint.size = Vector2(420, 34)
	root.add_child(_hint)

	_flash = Label.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flash.position = Vector2(20, 300)
	_flash.size = Vector2(400, 60)
	_flash.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_flash.add_theme_font_size_override("font_size", 22)
	root.add_child(_flash)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	return b

# --- toggles ---------------------------------------------------------------
func _cycle_scheme() -> void:
	scheme = (scheme + 1) % 3
	player.reset_input()
	_refresh_buttons()

func _cycle_move() -> void:
	move_mode = DiggerPlayer.Move.GROUNDED if move_mode == DiggerPlayer.Move.FLOATY else DiggerPlayer.Move.FLOATY
	_refresh_buttons()

func _cycle_dig() -> void:
	dig_mode = DiggerPlayer.Dig.INSTANT if dig_mode == DiggerPlayer.Dig.DRILL else DiggerPlayer.Dig.DRILL
	_refresh_buttons()

func _reset() -> void:
	grid.setup()
	player.respawn()
	flash("Mine reset")

func _refresh_buttons() -> void:
	_scheme_btn.text = "Scheme: %s" % _scheme_name()
	_move_btn.text = "Move: %s" % ("Floaty" if move_mode == DiggerPlayer.Move.FLOATY else "Grounded")
	_dig_btn.text = "Dig: %s" % ("Hold-drill" if dig_mode == DiggerPlayer.Dig.DRILL else "Instant")
	_hint.text = _hint_text()

func _scheme_name() -> String:
	match scheme:
		DiggerPlayer.Scheme.TAP: return "Tap-adjacent"
		DiggerPlayer.Scheme.DRAG: return "Drag-direction"
		_: return "Virtual stick"

func _hint_text() -> String:
	var base := ""
	match scheme:
		DiggerPlayer.Scheme.TAP:
			base = "TAP a cell next to the digger to move/dig toward it, one cell at a time."
		DiggerPlayer.Scheme.DRAG:
			base = "TOUCH & DRAG anywhere: the digger thrusts in the drag direction; it drills whatever it presses into."
		_:
			base = "TOUCH & HOLD anywhere for a virtual stick; drag to steer thrust; it drills what it presses into."
	return base + "  (Arrow keys also work.)  Fly UP to climb home — ascent burns fuel."

# --- flash messages --------------------------------------------------------
func flash(msg: String) -> void:
	_flash.text = msg
	_flash_time = 1.6

func _process(delta: float) -> void:
	_fuel.value = player.fuel
	_status.text = "Gems dug: %d    Runs lost: %d" % [player.gems, player.runs_lost]
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.text = ""
