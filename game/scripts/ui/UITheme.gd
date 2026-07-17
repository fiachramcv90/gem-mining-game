class_name UITheme
extends RefCounted
## The shared UI theme (feedback #4: hub/shop/log layout & typography) —
## one code-built Theme on the Palette so every panel reads as the same
## game: dark panels, warm gold accents, chunky touch-sized buttons.
## Applied to each code-built panel root; still default-font (a pixel font
## is a later asset decision), so typography here is size/colour/spacing.

## Price-button states (the shop's at-a-glance affordability read, spec §4
## presentation): AFFORD pops gold, POOR shows the price dimmed, DONE reads
## MAX/OWNED in the good green — three visibly distinct states.
enum Price { AFFORD, POOR, DONE }


static func build() -> Theme:
	var theme := Theme.new()

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(
		Palette.UI_PANEL_BG.r, Palette.UI_PANEL_BG.g, Palette.UI_PANEL_BG.b, 0.97
	)
	panel.border_color = Palette.UI_PANEL_BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 18.0
	panel.content_margin_right = 18.0
	panel.content_margin_top = 16.0
	panel.content_margin_bottom = 16.0
	theme.set_stylebox("panel", "PanelContainer", panel)

	theme.set_stylebox("normal", "Button", _button_box(Palette.UI_BUTTON_BG))
	theme.set_stylebox("hover", "Button", _button_box(Palette.UI_BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _button_box(Palette.UI_BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _button_box(Palette.UI_PANEL_BG))
	theme.set_stylebox("focus", "Button", _button_box(Palette.UI_BUTTON_HOVER))
	theme.set_color("font_color", "Button", Palette.UI_TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Palette.UI_GOLD)
	theme.set_color("font_disabled_color", "Button", Palette.UI_TEXT_DIM)
	theme.set_color("font_focus_color", "Button", Palette.UI_TEXT)

	theme.set_color("font_color", "Label", Palette.UI_TEXT)

	var sep := StyleBoxLine.new()
	sep.color = Palette.UI_PANEL_BORDER
	theme.set_stylebox("separator", "HSeparator", sep)
	return theme


static func style_title(label: Label, color: Color = Palette.UI_GOLD) -> void:
	## The one shared header voice: big, gold, centred.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)


static func row_box() -> StyleBoxFlat:
	## A subtle inset card for list rows (the shop's track cards): darker
	## than the panel, thin border, tighter margins than the panel box.
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.UI_PANEL_BG.darkened(0.25)
	box.border_color = Palette.UI_PANEL_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func style_price_button(button: Button, state: Price) -> void:
	## One shared voice for every buy button: affordable gold-rimmed and
	## live, unaffordable dim but still priced, maxed/owned quiet green.
	match state:
		Price.AFFORD:
			button.disabled = false
			button.add_theme_color_override("font_color", Palette.UI_GOLD)
			button.add_theme_stylebox_override("normal", _button_box_rimmed(Palette.UI_GOLD))
		Price.POOR:
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", Palette.UI_TEXT_DIM)
			button.remove_theme_stylebox_override("normal")
		Price.DONE:
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", Palette.UI_GOOD)
			button.remove_theme_stylebox_override("normal")


static func _button_box_rimmed(rim: Color) -> StyleBoxFlat:
	var box := _button_box(Palette.UI_BUTTON_BG)
	box.border_color = Color(rim.r, rim.g, rim.b, 0.75)
	return box


static func _button_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Palette.UI_PANEL_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box
