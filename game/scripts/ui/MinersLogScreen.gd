class_name MinersLogScreen
extends PanelContainer
## The single Miner's Log screen (spec §8): the 8 lifetime stats and the
## 14-milestone checklist together — they are the same psychological object
## ("my record"). Unearned milestones show as "???" silhouettes; earned ones
## show their name and terse line. Honorific-only: nothing here grants
## anything, and nothing here is spent. Grey-box UI like the rest of the
## hub — real art direction is spec §7.

signal closed

const FAMILY_ORDER: Array[String] = ["DEPTH", "WEALTH", "SURVIVAL"]

var _deepest_label: Label
var _stat_labels := {}
var _milestone_labels := {}


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "MINER'S LOG"
	UITheme.style_title(title)
	vbox.add_child(title)

	# The record, shown big (spec §8); the rest of the stats read as a list.
	_deepest_label = Label.new()
	_deepest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deepest_label.add_theme_font_size_override("font_size", 22)
	_deepest_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	vbox.add_child(_deepest_label)

	for key: String in [
		"tiles_dug",
		"gems_collected",
		"money_banked",
		"prize_gems_banked",
		"runs",
		"cargo_value_lost",
	]:
		var stat := Label.new()
		stat.add_theme_font_size_override("font_size", 13)
		vbox.add_child(stat)
		_stat_labels[key] = stat

	vbox.add_child(HSeparator.new())

	# The milestone checklist, scrolling so the panel never outgrows the
	# portrait viewport.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for family in FAMILY_ORDER:
		var header := Label.new()
		header.text = family
		header.add_theme_font_size_override("font_size", 11)
		header.modulate = Color(1, 1, 1, 0.55)
		list.add_child(header)
		for entry in MinersLog.MILESTONES:
			if entry["family"] != family:
				continue
			var row := Label.new()
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_theme_font_size_override("font_size", 13)
			list.add_child(row)
			_milestone_labels[entry["id"]] = row

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(back)


func refresh() -> void:
	var s := MinersLog.stats
	_deepest_label.text = "deepest  %dm" % int(s["deepest_depth"])
	_stat_labels["tiles_dug"].text = "tiles dug  %d" % int(s["tiles_dug"])
	_stat_labels["gems_collected"].text = "gems collected  %d" % int(s["gems_collected"])
	_stat_labels["money_banked"].text = "money banked  $%d" % int(s["money_banked"])
	_stat_labels["prize_gems_banked"].text = "prize gems banked  %d" % int(s["prize_gems_banked"])
	# Completed and lost read as a pair — no shaming ratio (spec §8).
	_stat_labels["runs"].text = (
		"runs  %d home · %d lost" % [int(s["runs_completed"]), int(s["runs_lost"])]
	)
	_stat_labels["cargo_value_lost"].text = "cargo value lost  $%d" % int(s["cargo_value_lost"])

	for entry in MinersLog.MILESTONES:
		var row: Label = _milestone_labels[entry["id"]]
		if MinersLog.is_earned(entry["id"]):
			row.text = "%s — %s" % [entry["name"], entry["line"]]
			row.modulate = Color(1.0, 0.9, 0.55)
		else:
			row.text = "???"
			row.modulate = Color(1, 1, 1, 0.35)
