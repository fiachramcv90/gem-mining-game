class_name HUD
extends CanvasLayer
## The three-pressures HUD (spec §1) + the surface hub — the complete §9
## census: the four core actions (sell · refuel/repair · upgrade · descend)
## + the Miner's Log button + the ♥ Support corner + the 💾 save-safety
## corner — plus the single run-lost outcome screen, the milestone banner,
## the first-descent ghost line, and the tap-to-start screen. Built in
## code: grey-box UI, real art direction is spec §7. process_mode is ALWAYS
## so hub buttons work while the tree is paused.

## The ghost line's lifecycle (spec §9): armed until the first descent,
## showing until the first dig or the backstop, then done for good —
## "first run" is derived from an empty dug delta, never a save flag.
enum GhostState { ARMED, SHOWING, DONE }

const BANNER_FADE_IN := 0.25
const BANNER_HOLD := 2.2
const BANNER_FADE_OUT := 0.5

var _readout: Control
var _hub_button: Button
var _hub_panel: Control
var _hub_wallet: Label
var _hub_cargo: Label
var _sell_button: Button
var _shop: UpgradeShop
var _shop_panel: Control
var _save_corner: SaveCorner
var _support_corner: SupportCorner
var _log_screen: MinersLogScreen
var _log_panel: Control
var _lost_panel: Control
var _lost_reason: Label
var _title: TitleScreen

# The milestone banner (spec §8): one terse line, faded in and out over the
# action — never a modal, you may be dodging lava. Queued so simultaneous
# awards read one at a time.
var _banner: Label
var _banner_queue: Array[String] = []
var _banner_playing := false

var _ghost_line: Label
var _ghost_state := GhostState.ARMED
var _ghost_clock := 0.0

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

	_shop = UpgradeShop.new()
	_shop.closed.connect(_close_shop)
	_shop_panel = _center_wrap(_shop)
	add_child(_shop_panel)

	_log_screen = MinersLogScreen.new()
	_log_screen.closed.connect(_close_log)
	_log_panel = _center_wrap(_log_screen)
	add_child(_log_panel)

	_save_corner = SaveCorner.new()
	add_child(_save_corner)

	_support_corner = SupportCorner.new()
	add_child(_support_corner)

	_lost_panel = _build_lost_panel()
	add_child(_lost_panel)

	_banner = _build_banner()
	add_child(_banner)

	_ghost_line = _build_ghost_line()
	add_child(_ghost_line)

	# The tap-to-start screen sits over everything (spec §9): it pauses the
	# tree in its _ready and the game-starting tap releases it.
	_title = TitleScreen.new()
	add_child(_title)

	GameState.run_lost.connect(_on_run_lost)
	GameState.cargo_sold.connect(_on_cargo_sold)
	GameState.tile_dug.connect(_on_first_dig)
	MinersLog.milestone_earned.connect(_on_milestone_earned)


func _process(delta: float) -> void:
	_hub_button.visible = (
		GameState.depth == 0
		and not _title.visible
		and not _hub_panel.visible
		and not _shop_panel.visible
		and not _log_panel.visible
		and not _lost_panel.visible
	)
	_tick_ghost_line(delta)
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

	_sell_button = _hub_action("SELL CARGO", _on_sell)
	vbox.add_child(_sell_button)
	vbox.add_child(_hub_action("REFUEL + REPAIR (free)", _on_refuel))
	vbox.add_child(_hub_action("UPGRADES", _open_shop))
	# The one new button 0012 is allowed (spec §8) — the census is complete.
	vbox.add_child(_hub_action("MINER'S LOG", _open_log))
	vbox.add_child(_hub_action("DESCEND", _close_hub))
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


func _open_shop() -> void:
	_hub_panel.visible = false
	_shop.refresh()
	_shop_panel.visible = true


func _close_shop() -> void:
	_shop_panel.visible = false
	_refresh_hub_labels()
	_hub_panel.visible = true


func _open_log() -> void:
	_hub_panel.visible = false
	_log_screen.refresh()
	_log_panel.visible = true


func _close_log() -> void:
	_log_panel.visible = false
	_refresh_hub_labels()
	_hub_panel.visible = true


func _on_sell() -> void:
	GameState.sell_cargo()


func _on_refuel() -> void:
	GameState.refuel_repair()
	_refresh_hub_labels()


func _on_cargo_sold(value: int) -> void:
	## The sell celebration (session-1 device feedback): the ratchet must
	## READ — a "+$" float over a gold pop on the banked total. Grey-box;
	## the full juice pass is spec §7.
	_refresh_hub_labels()
	if value <= 0:
		return
	_flash_banked(value)


func _flash_banked(value: int) -> void:
	var float_label := Label.new()
	float_label.text = "+$%d" % value
	float_label.add_theme_font_size_override("font_size", 22)
	float_label.modulate = Color(1.0, 0.85, 0.3)
	float_label.position = Vector2(_hub_wallet.size.x * 0.5 - 24.0, -12.0)
	_hub_wallet.add_child(float_label)
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(float_label, "position:y", -40.0, 1.1)
	rise.tween_property(float_label, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	rise.chain().tween_callback(float_label.queue_free)

	_hub_wallet.pivot_offset = _hub_wallet.size * 0.5
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(_hub_wallet, "scale", Vector2.ONE, 0.4).from(Vector2(1.4, 1.4))
	pop.tween_property(_hub_wallet, "modulate", Color.WHITE, 0.6).from(Color(1.0, 0.85, 0.3))


func _refresh_hub_labels() -> void:
	_hub_wallet.text = "banked  $%d" % Wallet.money
	var value := GameState.cargo_value()
	_hub_cargo.text = "cargo  %d gems worth $%d" % [GameState.cargo.size(), value]
	_sell_button.text = "SELL CARGO — $%d" % value
	_sell_button.disabled = GameState.cargo.is_empty()


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


func _on_run_lost(reason: String, _cargo_lost: int) -> void:
	# The death-reason line is permanent UI (spec §9) — the fuel variant
	# ("ran dry below ground — the climb home costs fuel too") closes the
	# round-trip lesson at the one moment it has full attention.
	_lost_reason.text = reason
	_lost_panel.visible = true
	get_tree().paused = true


func _dismiss_lost() -> void:
	_lost_panel.visible = false
	get_tree().paused = false


# --- the milestone banner (spec §8) --------------------------------------------


func _build_banner() -> Label:
	var banner := Label.new()
	# Full-width strip via offsets (position would bake in the zero size the
	# label still has during _ready).
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 150.0
	banner.offset_bottom = 190.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 16)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate = Color(1.0, 0.85, 0.4, 0.0)
	return banner


func _on_milestone_earned(_id: String, line: String) -> void:
	if line.is_empty():
		return
	_banner_queue.append(line)
	_play_next_banner()


func _play_next_banner() -> void:
	if _banner_playing or _banner_queue.is_empty():
		return
	_banner_playing = true
	_banner.text = _banner_queue.pop_front()
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, BANNER_FADE_IN)
	t.tween_interval(BANNER_HOLD)
	t.tween_property(_banner, "modulate:a", 0.0, BANNER_FADE_OUT)
	t.tween_callback(_on_banner_done)


func _on_banner_done() -> void:
	_banner_playing = false
	_play_next_banner()


# --- the controls ghost line (spec §9) -------------------------------------------


func _build_ghost_line() -> Label:
	var ghost := Label.new()
	ghost.text = "push to fly · hold into rock to dig"
	ghost.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ghost.offset_top = 300.0
	ghost.offset_bottom = 340.0
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.add_theme_font_size_override("font_size", 14)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1, 1, 1, 0.0)
	return ghost


func _tick_ghost_line(delta: float) -> void:
	## First descent only, derived from an empty dug delta — no flag: the
	## first dig is itself the persisted event that retires the line. The
	## backstop timer catches the player who only ever flies.
	match _ghost_state:
		GhostState.ARMED:
			if GameState.depth > 0:
				if GameState.dug.is_empty():
					_ghost_state = GhostState.SHOWING
					_ghost_clock = 0.0
					create_tween().tween_property(_ghost_line, "modulate:a", 0.6, 0.5)
				else:
					_ghost_state = GhostState.DONE
		GhostState.SHOWING:
			_ghost_clock += delta
			if _ghost_clock >= GameState.economy.ghost_line_backstop_secs:
				_dismiss_ghost_line()
		GhostState.DONE:
			pass


func _on_first_dig(_tile: Vector2i) -> void:
	if _ghost_state == GhostState.SHOWING:
		_dismiss_ghost_line()


func _dismiss_ghost_line() -> void:
	_ghost_state = GhostState.DONE
	create_tween().tween_property(_ghost_line, "modulate:a", 0.0, 0.6)
