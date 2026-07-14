class_name HUD
extends CanvasLayer
## The three-pressures HUD (spec §1) + the placeholder surface hub (sell ·
## refuel/repair · descend — the full hub census §9 is a later session) and
## the single run-lost outcome screen. Built in code: grey-box UI, real art
## direction is spec §7. process_mode is ALWAYS so hub buttons work while the
## tree is paused.

var _readout: Control
var _hub_button: Button
var _hub_panel: Control
var _hub_wallet: Label
var _hub_cargo: Label
var _lost_panel: Control
var _lost_reason: Label

@onready var stick: VirtualStick = $VirtualStick


func _ready() -> void:
	_readout = Control.new()
	_readout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.draw.connect(_draw_readout)
	add_child(_readout)

	_hub_button = Button.new()
	_hub_button.text = "SURFACE HUB"
	_hub_button.position = Vector2(300, 12)
	_hub_button.size = Vector2(128, 44)
	_hub_button.pressed.connect(_open_hub)
	add_child(_hub_button)

	_hub_panel = _build_hub_panel()
	add_child(_hub_panel)

	_lost_panel = _build_lost_panel()
	add_child(_lost_panel)

	GameState.run_lost.connect(_on_run_lost)


func _process(_delta: float) -> void:
	_hub_button.visible = (
		GameState.depth == 0 and not _hub_panel.visible and not _lost_panel.visible
	)
	_readout.queue_redraw()


# --- readout: fuel / hull / cargo / depth / wallet ---------------------------


func _draw_readout() -> void:
	var font := ThemeDB.fallback_font
	var eco := GameState.economy
	var fuel_cap := float(Upgrades.fuel_capacity())
	var hull_cap := float(Upgrades.hull_capacity())

	# The round-trip warning (spec §9): the fuel gauge pulses when what's
	# left approaches the estimated cost of the climb home.
	var ascent_cost := GameState.depth * eco.fuel_ascent_per_tile * Upgrades.ascent_factor()
	var fuel_color := Color(0.35, 0.75, 0.95)
	if GameState.depth > 0 and GameState.fuel < ascent_cost * eco.roundtrip_pulse_threshold:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		fuel_color = Color(0.95, 0.25, 0.2).lerp(Color(0.95, 0.6, 0.2), pulse)

	_bar(Vector2(12, 12), "FUEL", GameState.fuel / fuel_cap, fuel_color, font)
	_bar(Vector2(12, 34), "HULL", GameState.hull / hull_cap, Color(0.4, 0.85, 0.45), font)

	var cargo_text := "CARGO %d/%d" % [GameState.cargo.size(), Upgrades.cargo_slots()]
	if GameState.cargo.size() >= Upgrades.cargo_slots():
		cargo_text += "  HOLD FULL"
	_readout.draw_string(
		font, Vector2(12, 72), cargo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE
	)
	_readout.draw_string(
		font,
		Vector2(12, 92),
		"DEPTH %dm" % GameState.depth,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color.WHITE
	)
	_readout.draw_string(
		font,
		Vector2(12, 112),
		"$%d" % Wallet.money,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(1.0, 0.85, 0.4)
	)


func _bar(pos: Vector2, label: String, frac: float, color: Color, font: Font) -> void:
	var size := Vector2(150, 14)
	_readout.draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.55), true)
	_readout.draw_rect(Rect2(pos, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), color, true)
	_readout.draw_rect(Rect2(pos, size), Color(1, 1, 1, 0.5), false, 1.0)
	_readout.draw_string(
		font, pos + Vector2(4, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9)
	)


# --- placeholder surface hub --------------------------------------------------


func _center_wrap(panel: Control) -> Control:
	## True centring at any viewport size: a full-rect CenterContainer that
	## ignores mouse itself (the stick keeps working around the panel).
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.visible = false
	wrap.add_child(panel)
	return wrap


func _build_hub_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SURFACE HUB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_hub_wallet = Label.new()
	_hub_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hub_wallet)

	_hub_cargo = Label.new()
	_hub_cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hub_cargo)

	vbox.add_child(_hub_action("SELL CARGO", _on_sell))
	vbox.add_child(_hub_action("REFUEL + REPAIR (free)", _on_refuel))
	vbox.add_child(_hub_action("DESCEND", _close_hub))

	var note := Label.new()
	note.text = "upgrades arrive next session"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 11)
	vbox.add_child(note)
	return _center_wrap(panel)


func _hub_action(label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(handler)
	return button


func _open_hub() -> void:
	_refresh_hub_labels()
	_hub_panel.visible = true
	get_tree().paused = true


func _close_hub() -> void:
	_hub_panel.visible = false
	get_tree().paused = false


func _on_sell() -> void:
	GameState.sell_cargo()
	_refresh_hub_labels()


func _on_refuel() -> void:
	GameState.refuel_repair()
	_refresh_hub_labels()


func _refresh_hub_labels() -> void:
	_hub_wallet.text = "wallet  $%d" % Wallet.money
	_hub_cargo.text = "cargo  %d gems worth $%d" % [GameState.cargo.size(), GameState.cargo_value()]


# --- the single run-lost outcome (spec §1) ------------------------------------


func _build_lost_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "RUN LOST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_lost_reason = Label.new()
	_lost_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lost_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lost_reason)

	var detail := Label.new()
	detail.text = "cargo forfeited — wallet and upgrades are safe"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	vbox.add_child(detail)

	vbox.add_child(_hub_action("BACK TO THE SURFACE", _dismiss_lost))
	return _center_wrap(panel)


func _on_run_lost(reason: String) -> void:
	_lost_reason.text = reason
	_lost_panel.visible = true
	get_tree().paused = true


func _dismiss_lost() -> void:
	_lost_panel.visible = false
	get_tree().paused = false
