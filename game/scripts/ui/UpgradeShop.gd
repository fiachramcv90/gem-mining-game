class_name UpgradeShop
extends PanelContainer
## The upgrade shop (spec §4) — the ratchet's storefront, not a debug table
## (session-7 owner feedback: the raw grey-box read). Each track is a card
## with a readable identity: its name, its job in plain words, a level pip
## strip (L2/4 is SEEN, not parsed), a current → next effect line, and a
## price button whose three states — affordable / can't afford / MAXED —
## read at arm's length (UITheme.style_price_button). The bought row pops
## through the existing Juice vocabulary's tween idiom; the screen-wide
## upgrade beat is Juice's as before.
##
## Presentation only: every price, effect, and the Hoist's aspirational
## reveal rule come from Upgrades/EconomyConfig — 0006 stays closed.

signal closed

const TRACKS: Array[String] = ["drill", "fuel", "cargo", "hull", "light"]
## Each track's job, in plain words — what the money actually buys.
const TRACK_JOBS := {
	"drill": "how fast rock breaks — the way deeper",
	"fuel": "how deep a round trip reaches",
	"cargo": "how many gems one trip carries",
	"hull": "how much punishment you survive",
	"light": "how far you see — sight is the dodge",
	"hoist": "the climb home, at half fuel and time",
}

## Pip-strip geometry (code-drawn from the Palette — no icon art).
const PIP_SIZE := 10.0
const PIP_GAP := 4.0

var _wallet_label: Label
## track -> {"panel", "pips", "effect", "buy"} for the five level tracks
## plus "hoist".
var _rows := {}
var _hoist_row: PanelContainer


func _ready() -> void:
	custom_minimum_size = Vector2(372, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "UPGRADES"
	UITheme.style_title(title)
	vbox.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_font_size_override("font_size", 15)
	_wallet_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	vbox.add_child(_wallet_label)

	vbox.add_child(HSeparator.new())

	# The track cards scroll if they must (Hoist revealed on a short screen);
	# at the stock 440x880 viewport all six sit visible.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for track in TRACKS:
		list.add_child(_build_row(track))
	_hoist_row = _build_row("hoist")
	list.add_child(_hoist_row)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func() -> void: closed.emit())
	back.pressed.connect(func() -> void: Sfx.play("click"))
	vbox.add_child(back)

	# Affordability shifts with every purchase and sale.
	Wallet.money_changed.connect(_on_state_changed)
	Upgrades.upgrades_changed.connect(refresh)


func _on_state_changed(_money: int) -> void:
	refresh()


func _build_row(track: String) -> PanelContainer:
	## One track card: name + pips / job line / effect + price button.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.row_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var name_label := Label.new()
	name_label.text = track.to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	head.add_child(name_label)
	var pips := Control.new()
	var pip_count := _pip_count(track)
	pips.custom_minimum_size = Vector2(pip_count * (PIP_SIZE + PIP_GAP) - PIP_GAP, PIP_SIZE + 2.0)
	pips.draw.connect(_draw_pips.bind(pips, track))
	head.add_child(pips)

	var job := Label.new()
	job.text = TRACK_JOBS[track]
	job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job.add_theme_font_size_override("font_size", 11)
	job.add_theme_color_override("font_color", Palette.UI_TEXT_DIM)
	col.add_child(job)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	col.add_child(foot)
	var effect := Label.new()
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 13)
	foot.add_child(effect)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(92, 40)
	if track == "hoist":
		buy.pressed.connect(_on_buy_hoist)
	else:
		buy.pressed.connect(_on_buy.bind(track))
	foot.add_child(buy)

	_rows[track] = {"panel": panel, "pips": pips, "effect": effect, "buy": buy}
	return panel


func _pip_count(track: String) -> int:
	return 1 if track == "hoist" else Upgrades.max_level(track)


func _draw_pips(pips: Control, track: String) -> void:
	## The level strip: filled gold squares for bought levels, empty outlined
	## squares for the road ahead — L2/4 seen at a glance.
	var filled: int = Upgrades.levels.get(track, 0)
	if track == "hoist":
		filled = 1 if Upgrades.hoist else 0
	for i in range(_pip_count(track)):
		var rect := Rect2(i * (PIP_SIZE + PIP_GAP), 1.0, PIP_SIZE, PIP_SIZE)
		if i < filled:
			pips.draw_rect(rect, Palette.UI_GOLD, true)
		else:
			pips.draw_rect(rect, Palette.UI_PANEL_BORDER, false, 1.0)


func _on_buy(track: String) -> void:
	if Upgrades.buy(track):  # refresh arrives via upgrades_changed
		_pop_row(track)


func _on_buy_hoist() -> void:
	if Upgrades.buy_hoist():
		# The aspirational purchase gets the slightly bigger pop; the
		# screen-wide gold beat is Juice's existing upgrade flash.
		_pop_row("hoist", 1.22)


func _pop_row(track: String, from_scale: float = 1.12) -> void:
	## The buy moment on the row itself (same tween idiom as the HUD's
	## banked-gold pop — the existing Juice vocabulary, no new primitives).
	var panel: PanelContainer = _rows[track]["panel"]
	panel.pivot_offset = panel.size * 0.5
	var pop := create_tween()
	pop.set_parallel(true)
	(
		pop
		. tween_property(panel, "scale", Vector2.ONE, 0.35)
		. from(Vector2(from_scale, from_scale))
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	pop.tween_property(panel, "modulate", Color.WHITE, 0.5).from(Color(1.0, 0.85, 0.3))


func refresh() -> void:
	_wallet_label.text = "banked  $%d" % Wallet.money
	for track in TRACKS:
		var level: int = Upgrades.levels[track]
		var price := Upgrades.next_price(track)
		var effect: Label = _rows[track]["effect"]
		var buy: Button = _rows[track]["buy"]
		if price < 0:
			effect.text = "%s — maxed" % _effect_text(track, level)
			buy.text = "MAX"
			UITheme.style_price_button(buy, UITheme.Price.DONE)
		else:
			effect.text = "%s  →  %s" % [_effect_text(track, level), _effect_text(track, level + 1)]
			buy.text = "$%d" % price
			UITheme.style_price_button(
				buy, UITheme.Price.AFFORD if price <= Wallet.money else UITheme.Price.POOR
			)
		_rows[track]["pips"].queue_redraw()
	_refresh_hoist()


func _refresh_hoist() -> void:
	# Owned stays visible as a trophy; otherwise the row exists only once
	# Drill/Fuel/Cargo are deep (spec §4's reveal rule, unchanged).
	_hoist_row.visible = Upgrades.hoist or Upgrades.hoist_available()
	if not _hoist_row.visible:
		return
	var factor: float = GameState.economy.hoist_ascent_factor
	var effect: Label = _rows["hoist"]["effect"]
	var buy: Button = _rows["hoist"]["buy"]
	if Upgrades.hoist:
		effect.text = "ascent ×%.1f fuel & time — yours" % factor
		buy.text = "OWNED"
		UITheme.style_price_button(buy, UITheme.Price.DONE)
	else:
		effect.text = "self-powered climb  →  ×%.1f fuel & time" % factor
		var cost := Upgrades.hoist_cost()
		buy.text = "$%d" % cost
		UITheme.style_price_button(
			buy, UITheme.Price.AFFORD if cost <= Wallet.money else UITheme.Price.POOR
		)
	_rows["hoist"]["pips"].queue_redraw()


func _effect_text(track: String, level: int) -> String:
	var eco := GameState.economy
	match track:
		"drill":
			return "power %.2f" % eco.drill_power[level]
		"fuel":
			return "cap %d" % eco.fuel_capacity[level]
		"cargo":
			return "slots %d" % eco.cargo_slots[level]
		"hull":
			return "cap %d" % eco.hull_capacity[level]
		"light":
			return "darkness ×%.2f" % eco.light_darkness_mult[level]
	return ""
