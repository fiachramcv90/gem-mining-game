class_name UpgradeShop
extends PanelContainer
## The upgrade shop (spec §4): all six tracks of the ratchet off
## Upgrades.buy(). Each row shows current level, effect, and the next price
## (price_scale-aware via Upgrades.next_price()); buttons grey out when
## unaffordable and read MAX when a track is done. The aspirational Hoist
## row surfaces only once Drill/Fuel/Cargo are deep (spec §4). Grey-box UI
## built in code, like the rest of the hub — real art direction is spec §7.

signal closed

const TRACKS: Array[String] = ["drill", "fuel", "cargo", "hull", "light"]
const TRACK_JOBS := {
	"drill": "drill power",
	"fuel": "fuel cap",
	"cargo": "cargo slots",
	"hull": "hull cap",
	"light": "darkness",
}

var _wallet_label: Label
var _rows := {}
var _hoist_row: HBoxContainer
var _hoist_info: Label
var _hoist_buy: Button


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "UPGRADES"
	UITheme.style_title(title)
	vbox.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	vbox.add_child(_wallet_label)

	vbox.add_child(HSeparator.new())

	for track in TRACKS:
		vbox.add_child(_build_row(track))
	_hoist_row = _build_hoist_row()
	vbox.add_child(_hoist_row)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(back)

	# Affordability shifts with every purchase and sale.
	Wallet.money_changed.connect(_on_state_changed)
	Upgrades.upgrades_changed.connect(refresh)


func _on_state_changed(_money: int) -> void:
	refresh()


func _build_row(track: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(84, 44)
	buy.pressed.connect(_on_buy.bind(track))
	row.add_child(buy)
	_rows[track] = {"info": info, "buy": buy}
	return row


func _build_hoist_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_hoist_info = Label.new()
	_hoist_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hoist_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_hoist_info)
	_hoist_buy = Button.new()
	_hoist_buy.custom_minimum_size = Vector2(84, 44)
	_hoist_buy.pressed.connect(_on_buy_hoist)
	row.add_child(_hoist_buy)
	return row


func _on_buy(track: String) -> void:
	Upgrades.buy(track)  # refresh arrives via upgrades_changed


func _on_buy_hoist() -> void:
	Upgrades.buy_hoist()


func refresh() -> void:
	_wallet_label.text = "banked  $%d" % Wallet.money
	for track in TRACKS:
		var level: int = Upgrades.levels[track]
		var price := Upgrades.next_price(track)
		var info: Label = _rows[track]["info"]
		var buy: Button = _rows[track]["buy"]
		var name_part := "%s L%d/%d" % [track.to_upper(), level, Upgrades.max_level(track)]
		if price < 0:
			info.text = "%s — %s (maxed)" % [name_part, _effect_text(track, level)]
			buy.text = "MAX"
			buy.disabled = true
		else:
			info.text = (
				"%s — %s → %s"
				% [name_part, _effect_text(track, level), _effect_text(track, level + 1)]
			)
			buy.text = "$%d" % price
			buy.disabled = price > Wallet.money
	_refresh_hoist()


func _refresh_hoist() -> void:
	# Owned stays visible as a trophy; otherwise the row exists only once
	# Drill/Fuel/Cargo are deep.
	_hoist_row.visible = Upgrades.hoist or Upgrades.hoist_available()
	if not _hoist_row.visible:
		return
	var eco := GameState.economy
	_hoist_info.text = "HOIST — ascent fuel & time ×%.1f" % eco.hoist_ascent_factor
	if Upgrades.hoist:
		_hoist_buy.text = "OWNED"
		_hoist_buy.disabled = true
	else:
		var cost := Upgrades.hoist_cost()
		_hoist_buy.text = "$%d" % cost
		_hoist_buy.disabled = cost > Wallet.money


func _effect_text(track: String, level: int) -> String:
	var eco := GameState.economy
	match track:
		"drill":
			return "%s %.2f" % [TRACK_JOBS[track], eco.drill_power[level]]
		"fuel":
			return "%s %d" % [TRACK_JOBS[track], eco.fuel_capacity[level]]
		"cargo":
			return "%s %d" % [TRACK_JOBS[track], eco.cargo_slots[level]]
		"hull":
			return "%s %d" % [TRACK_JOBS[track], eco.hull_capacity[level]]
		"light":
			return "%s ×%.2f" % [TRACK_JOBS[track], eco.light_darkness_mult[level]]
	return ""
