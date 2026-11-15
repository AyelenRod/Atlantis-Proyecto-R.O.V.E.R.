extends RefCounted
## Tema visual compartido por TODAS las fases (mismos colores, botones y campos).

const MORADO := Color("b794ff")
const NARANJA := Color("ff9a4d")
const PANEL := Color(0.10, 0.08, 0.24, 0.85)
const PANEL_HOVER := Color(0.20, 0.14, 0.42, 0.95)
const TRANSPARENTE := Color(0, 0, 0, 0)


static func _caja(bg: Color, borde: Color, ancho: int = 2, radio: int = 14, margen: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	return s


static func caja_panel() -> StyleBoxFlat:
	return _caja(Color(0.08, 0.07, 0.20, 0.80), MORADO, 2, 16, 22)


## Tarjeta con borde de color (para estados: éxito, falla, aviso).
static func caja_color(borde: Color) -> StyleBoxFlat:
	return _caja(Color(0.08, 0.07, 0.20, 0.80), borde, 2, 16, 22)


## Si existe res://fonts/Poppins-Regular.ttf (y Poppins-Bold.ttf) los usa; si no, usa la fuente por defecto.
static func fuente(negrita: bool = false) -> Font:
	var ruta := "res://fonts/Poppins-Bold.ttf" if negrita else "res://fonts/Poppins-Regular.ttf"
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return null


static func crear() -> Theme:
	var t := Theme.new()
	var f := fuente()
	if f:
		t.default_font = f
	t.default_font_size = 18

	t.set_color("font_color", "Label", Color.WHITE)

	# Botones (y OptionButton)
	for tipo in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tipo, _caja(PANEL, MORADO.darkened(0.2)))
		t.set_stylebox("hover", tipo, _caja(PANEL_HOVER, NARANJA))
		t.set_stylebox("pressed", tipo, _caja(PANEL_HOVER.darkened(0.25), NARANJA))
		var foco := _caja(TRANSPARENTE, NARANJA)
		foco.draw_center = false
		t.set_stylebox("focus", tipo, foco)
		t.set_color("font_color", tipo, Color.WHITE)
		t.set_color("font_hover_color", tipo, NARANJA)
		t.set_color("font_pressed_color", tipo, NARANJA)
		t.set_color("font_focus_color", tipo, Color.WHITE)

	# Menú desplegable del OptionButton
	t.set_stylebox("panel", "PopupMenu", _caja(Color("14102e"), MORADO, 2, 10, 8))
	t.set_stylebox("hover", "PopupMenu", _caja(PANEL_HOVER, NARANJA, 0, 8, 6))
	t.set_color("font_color", "PopupMenu", Color.WHITE)
	t.set_color("font_hover_color", "PopupMenu", NARANJA)

	# Campos de texto
	t.set_stylebox("normal", "LineEdit", _caja(Color(0.05, 0.04, 0.14, 0.9), MORADO.darkened(0.3), 2, 10, 10))
	t.set_stylebox("focus", "LineEdit", _caja(Color(0.07, 0.05, 0.18, 0.95), NARANJA, 2, 10, 10))
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.4))
	t.set_color("caret_color", "LineEdit", NARANJA)

	# Barra de progreso
	t.set_stylebox("background", "ProgressBar", _caja(Color(1, 1, 1, 0.12), TRANSPARENTE, 0, 8, 0))
	t.set_stylebox("fill", "ProgressBar", _caja(NARANJA, TRANSPARENTE, 0, 8, 0))

	# Paneles (tarjetas)
	t.set_stylebox("panel", "PanelContainer", caja_panel())

	# Barras de desplazamiento
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, _caja(Color(1, 1, 1, 0.06), TRANSPARENTE, 0, 6, 0))
		t.set_stylebox("grabber", sb, _caja(MORADO.darkened(0.3), TRANSPARENTE, 0, 6, 0))
		t.set_stylebox("grabber_highlight", sb, _caja(MORADO, TRANSPARENTE, 0, 6, 0))
		t.set_stylebox("grabber_pressed", sb, _caja(NARANJA, TRANSPARENTE, 0, 6, 0))

	return t
