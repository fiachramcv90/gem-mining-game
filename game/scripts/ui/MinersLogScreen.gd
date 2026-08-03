class_name MinersLogScreen
extends PanelContainer
## The Miner's Log (spec §8) + the EP1 leaderboard folded in (spec L5): one
## screen, two switchers. Scope tabs — STATS (the shipped 8 stats + 14
## milestones) / GLOBAL / GROUPS — plus a metric toggle (Best haul / Total
## banked). The player's own row is always pinned + highlighted. Identity is
## lazy: a default nickname, editable here any time, never a gate. Offline is
## a normal state — the boards show local values and reassure (spec L5-F);
## groups are add-only, join-by-Crockford-code (spec L5-D).

signal closed

enum Scope { STATS, GLOBAL, GROUPS }

const FAMILY_ORDER: Array[String] = ["DEPTH", "WEALTH", "SURVIVAL"]

var _scope := Scope.STATS
var _metric_best := true  # true = best haul, false = total banked

var _deepest_label: Label
var _stat_labels := {}
var _milestone_labels := {}

var _tab_buttons := {}
var _metric_row: HBoxContainer
var _best_btn: Button
var _total_btn: Button
var _stats_panel: Control
var _global_panel: Control
var _groups_panel: Control
var _board_intro: Label

var _nick_edit: LineEdit
var _board_list: VBoxContainer
var _board_status: Label
var _join_edit: LineEdit
var _create_edit: LineEdit
var _groups_list: VBoxContainer
var _groups_status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "MINER'S LOG"
	UITheme.style_title(title)
	vbox.add_child(title)

	vbox.add_child(_build_scope_tabs())
	_metric_row = _build_metric_toggle()
	vbox.add_child(_metric_row)

	_board_intro = Label.new()
	_board_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_intro.add_theme_font_size_override("font_size", 12)
	_board_intro.add_theme_color_override("font_color", Palette.UI_GOLD)
	_board_intro.visible = false
	vbox.add_child(_board_intro)

	_stats_panel = _build_stats_panel()
	vbox.add_child(_stats_panel)
	_global_panel = _build_global_panel()
	vbox.add_child(_global_panel)
	_groups_panel = _build_groups_panel()
	vbox.add_child(_groups_panel)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(back)

	Leaderboard.board_changed.connect(_refresh_boards_ui)
	_set_scope(Scope.STATS)


# --- switchers ----------------------------------------------------------------


func _build_scope_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for spec: Array in [[Scope.STATS, "STATS"], [Scope.GLOBAL, "GLOBAL"], [Scope.GROUPS, "GROUPS"]]:
		var button := Button.new()
		button.text = spec[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_scope.bind(spec[0]))
		row.add_child(button)
		_tab_buttons[spec[0]] = button
	return row


func _build_metric_toggle() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_best_btn = Button.new()
	_best_btn.text = "BEST HAUL"
	_best_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_best_btn.pressed.connect(_set_metric.bind(true))
	row.add_child(_best_btn)
	_total_btn = Button.new()
	_total_btn.text = "TOTAL BANKED"
	_total_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total_btn.pressed.connect(_set_metric.bind(false))
	row.add_child(_total_btn)
	return row


func _set_scope(scope: int) -> void:
	_scope = scope
	_stats_panel.visible = scope == Scope.STATS
	_global_panel.visible = scope == Scope.GLOBAL
	_groups_panel.visible = scope == Scope.GROUPS
	_metric_row.visible = scope != Scope.STATS
	for s: int in _tab_buttons:
		(_tab_buttons[s] as Button).modulate = (Color.WHITE if s == scope else Color(1, 1, 1, 0.5))
	if scope != Scope.STATS:
		_show_board_intro_once()
		Leaderboard.refresh_boards()
	refresh()


func _set_metric(best: bool) -> void:
	_metric_best = best
	_best_btn.modulate = Color.WHITE if best else Color(1, 1, 1, 0.5)
	_total_btn.modulate = Color.WHITE if not best else Color(1, 1, 1, 0.5)
	_refresh_boards_ui()


func _show_board_intro_once() -> void:
	if Nudges.board_intro_shown:
		return
	_board_intro.text = (
		"you're '%s' — tap RENAME · join a group to play with friends" % Leaderboard.nickname
	)
	_board_intro.visible = true
	Nudges.mark_nudge("board_intro_shown")


# --- STATS panel (the shipped Miner's Log) ------------------------------------


func _build_stats_panel() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

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
		"cargo_value_lost"
	]:
		var stat := Label.new()
		stat.add_theme_font_size_override("font_size", 13)
		vbox.add_child(stat)
		_stat_labels[key] = stat

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 320)
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
	return vbox


# --- GLOBAL / GROUPS shared identity ------------------------------------------


func _build_identity_row() -> HBoxContainer:
	## The lazy-identity affordance (spec L5-E): rename any time, 3–16 chars.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_nick_edit = LineEdit.new()
	_nick_edit.max_length = Leaderboard.NICK_MAX
	_nick_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nick_edit.placeholder_text = "your name"
	row.add_child(_nick_edit)
	var rename := Button.new()
	rename.text = "RENAME"
	rename.pressed.connect(_on_rename)
	row.add_child(rename)
	return row


func _on_rename() -> void:
	if Leaderboard.set_nickname(_nick_edit.text):
		Sfx.play("upgrade")
	else:
		_board_status.text = "name must be 3–16 characters"
		_board_status.visible = true


func _build_global_panel() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.visible = false
	vbox.add_child(_build_identity_row())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_board_list = VBoxContainer.new()
	_board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_board_list)
	_board_status = _dim_status()
	vbox.add_child(_board_status)
	return vbox


# --- GROUPS panel -------------------------------------------------------------


func _build_groups_panel() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.visible = false

	var join := HBoxContainer.new()
	join.add_theme_constant_override("separation", 6)
	_join_edit = LineEdit.new()
	_join_edit.placeholder_text = "join code (e.g. K7Q2Z9)"
	_join_edit.max_length = 6
	_join_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.add_child(_join_edit)
	var join_btn := Button.new()
	join_btn.text = "JOIN"
	join_btn.pressed.connect(func() -> void: Leaderboard.join_group(_join_edit.text))
	join.add_child(join_btn)
	vbox.add_child(join)

	var make := HBoxContainer.new()
	make.add_theme_constant_override("separation", 6)
	_create_edit = LineEdit.new()
	_create_edit.placeholder_text = "new group name"
	_create_edit.max_length = 24
	_create_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make.add_child(_create_edit)
	var make_btn := Button.new()
	make_btn.text = "CREATE"
	make_btn.pressed.connect(func() -> void: Leaderboard.create_group(_create_edit.text))
	make.add_child(make_btn)
	vbox.add_child(make)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_groups_list = VBoxContainer.new()
	_groups_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_groups_list)
	_groups_status = _dim_status()
	vbox.add_child(_groups_status)
	return vbox


func _dim_status() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Palette.UI_TEXT_DIM)
	return label


# --- refresh ------------------------------------------------------------------


func refresh() -> void:
	_refresh_stats()
	_refresh_boards_ui()


func _refresh_stats() -> void:
	var s := MinersLog.stats
	_deepest_label.text = "deepest  %dm" % int(s["deepest_depth"])
	_stat_labels["tiles_dug"].text = "tiles dug  %d" % int(s["tiles_dug"])
	_stat_labels["gems_collected"].text = "gems collected  %d" % int(s["gems_collected"])
	_stat_labels["money_banked"].text = "money banked  $%d" % int(s["money_banked"])
	_stat_labels["prize_gems_banked"].text = "prize gems banked  %d" % int(s["prize_gems_banked"])
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


func _refresh_boards_ui() -> void:
	if _nick_edit != null and not _nick_edit.has_focus():
		_nick_edit.text = Leaderboard.nickname
	_refresh_global()
	_refresh_groups()


func _metric_value(best: int, total: int) -> int:
	return best if _metric_best else total


func _refresh_global() -> void:
	if _board_list == null:
		return
	for child in _board_list.get_children():
		child.queue_free()
	# The player's own row is always pinned + highlighted, even off-board.
	var you := _metric_value(Leaderboard.best_haul, Leaderboard.total_banked())
	_board_list.add_child(_board_row("★ %s (you)" % Leaderboard.nickname, you, true))
	for r: Dictionary in Leaderboard.global_rows:
		if str(r.get("nickname", "")) == Leaderboard.nickname:
			continue
		_board_list.add_child(
			_board_row(str(r["nickname"]), _metric_value(r["best_haul"], r["total_banked"]), false)
		)
	if Leaderboard.global_rows.is_empty():
		_board_status.text = (
			"be the first to dig deep — scores are saved locally and sync when a board is connected"
			if Leaderboard.online_configured()
			else "offline — your scores are saved and will sync when a board is connected"
		)
		_board_status.visible = true
	else:
		_board_status.visible = false


func _refresh_groups() -> void:
	if _groups_list == null:
		return
	for child in _groups_list.get_children():
		child.queue_free()
	for g: Dictionary in Leaderboard.groups:
		_groups_list.add_child(_group_row(g))
	var status := Leaderboard.last_status
	if Leaderboard.groups.is_empty() and status.is_empty():
		status = "join or create a group to compare with friends (add-only — no leaving in v1)"
	_groups_status.text = status
	_groups_status.visible = not status.is_empty()


func _board_row(name_text: String, value: int, highlight: bool) -> Control:
	var panel := PanelContainer.new()
	if highlight:
		panel.add_theme_stylebox_override("panel", UITheme.row_box())
	var row := HBoxContainer.new()
	panel.add_child(row)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	if highlight:
		name_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = "$%d" % value
	value_label.add_theme_font_size_override("font_size", 13)
	if highlight:
		value_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	row.add_child(value_label)
	return panel


func _group_row(group: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.row_box())
	var row := HBoxContainer.new()
	panel.add_child(row)
	var name_label := Label.new()
	name_label.text = str(group.get("name", "group"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	row.add_child(name_label)
	var share := Button.new()
	share.text = str(group.get("join_code", "??????"))
	share.pressed.connect(_share_code.bind(str(group.get("join_code", ""))))
	row.add_child(share)
	return panel


func _share_code(code: String) -> void:
	## Tap-to-share (spec L5-D): the native share sheet on web, clipboard else.
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			(
				"if (navigator.share) { navigator.share({text: 'Join my Gem Miner group: %s'}); }"
				% code
			),
			true
		)
	DisplayServer.clipboard_set(code)
	_groups_status.text = "code %s copied" % code
	_groups_status.visible = true
