# Barra de progreso horizontal NARANJA superior con ícono de nave que avanza.
extends Control
class_name HudOperacion

var _barra_progreso: ProgressBar
var _icono_nave_progreso: Control
var _lbl_progreso_pct: Label
var _lbl_titulo_nivel: Label
var _panel_lateral: PanelContainer
var _contenedor_metricas: VBoxContainer
var _lbl_instruccion: Label
var _progreso_actual: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir_ui()


func _construir_ui() -> void:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	# -------------------------------------------------------------------------
	# BARRA DE PROGRESO HORIZONTAL NARANJA SUPERIOR + ÍCONO DE NAVE
	# -------------------------------------------------------------------------
	var top_box := VBoxContainer.new()
	top_box.anchor_left = 0.04
	top_box.anchor_right = 0.68 # Deja espacio libre a la derecha para el panel lateral
	top_box.anchor_top = 0.025
	top_box.offset_bottom = 78.0
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(top_box)

	var fila_titulo := HBoxContainer.new()
	top_box.add_child(fila_titulo)

	_lbl_titulo_nivel = Label.new()
	_lbl_titulo_nivel.text = "FASE 4 · OPERACIÓN"
	_lbl_titulo_nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_titulo_nivel.add_theme_color_override("font_color", Color("#F3F0FF"))
	_lbl_titulo_nivel.add_theme_font_size_override("font_size", 16)
	fila_titulo.add_child(_lbl_titulo_nivel)

	_lbl_progreso_pct = Label.new()
	_lbl_progreso_pct.text = "0%"
	_lbl_progreso_pct.add_theme_color_override("font_color", Color("ff9a4d"))
	_lbl_progreso_pct.add_theme_font_size_override("font_size", 15)
	fila_titulo.add_child(_lbl_progreso_pct)

	# Contenedor relativo para posicionar el ícono de nave encima de la barra naranja
	var pista_barra := Control.new()
	pista_barra.custom_minimum_size = Vector2(0, 28)
	pista_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(pista_barra)

	_barra_progreso = ProgressBar.new()
	_barra_progreso.min_value = 0.0
	_barra_progreso.max_value = 100.0
	_barra_progreso.value = 0.0
	_barra_progreso.show_percentage = false
	_barra_progreso.anchor_left = 0.0
	_barra_progreso.anchor_right = 1.0
	_barra_progreso.anchor_top = 0.28
	_barra_progreso.anchor_bottom = 0.72
	_aplicar_estilo_barra_naranja(_barra_progreso)
	pista_barra.add_child(_barra_progreso)

	# Ícono vectorial de nave espacial que avanza sobre la barra naranja
	_icono_nave_progreso = _IconoNaveBarra.new()
	_icono_nave_progreso.size = Vector2(26, 22)
	_icono_nave_progreso.position = Vector2(0, 3)
	pista_barra.add_child(_icono_nave_progreso)

	# -------------------------------------------------------------------------
	# PANEL LATERAL DE TELEMETRÍA CON ALPHA REDUCIDO (NO TAPA LA NAVE)
	# -------------------------------------------------------------------------
	_panel_lateral = PanelContainer.new()
	_panel_lateral.anchor_left = 0.73
	_panel_lateral.anchor_right = 0.98
	_panel_lateral.anchor_top = 0.10   # deja libre la esquina superior derecha (botón "Volver a la base")
	_panel_lateral.anchor_bottom = 0.72
	_panel_lateral.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo_panel := StyleBoxFlat.new()
	# Alpha reducido (0.58) para mantener visibilidad espacial completa detrás del HUD
	estilo_panel.bg_color = Color(0.05, 0.04, 0.13, 0.58)
	estilo_panel.border_color = Color("b794ff")   # MORADO del tema
	estilo_panel.set_border_width_all(1)
	estilo_panel.set_corner_radius_all(12)
	estilo_panel.set_content_margin_all(14)
	_panel_lateral.add_theme_stylebox_override("panel", estilo_panel)
	raiz.add_child(_panel_lateral)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel_lateral.add_child(vbox)

	var cabecera := Label.new()
	cabecera.text = "TELEMETRÍA DE MISIÓN"
	cabecera.add_theme_color_override("font_color", Color("ff9a4d"))
	cabecera.add_theme_font_size_override("font_size", 14)
	vbox.add_child(cabecera)

	vbox.add_child(HSeparator.new())

	_contenedor_metricas = VBoxContainer.new()
	_contenedor_metricas.add_theme_constant_override("separation", 6)
	vbox.add_child(_contenedor_metricas)

	vbox.add_child(HSeparator.new())

	_lbl_instruccion = Label.new()
	_lbl_instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_instruccion.add_theme_color_override("font_color", Color(0.92, 0.90, 0.99, 0.92))
	_lbl_instruccion.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_lbl_instruccion)


func _aplicar_estilo_barra_naranja(barra: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.22, 0.72)
	bg.border_color = Color("b794ff")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff9a4d") # NARANJA del tema
	fill.set_corner_radius_all(6)

	barra.add_theme_stylebox_override("background", bg)
	barra.add_theme_stylebox_override("fill", fill)


func configurar_titulo(titulo: String, instruccion: String) -> void:
	_lbl_titulo_nivel.text = titulo
	_lbl_instruccion.text = instruccion


func actualizar_progreso(porcentaje: float) -> void:
	_progreso_actual = clampf(porcentaje, 0.0, 100.0)
	_barra_progreso.value = _progreso_actual
	_lbl_progreso_pct.text = "%d%%" % roundi(_progreso_actual)
	var ancho_disponible := maxf(10.0, _barra_progreso.size.x - 24.0)
	_icono_nave_progreso.position.x = (_progreso_actual / 100.0) * ancho_disponible


func actualizar_telemetria(filas: Array[Dictionary]) -> void:
	# Cada fila: {"etiqueta": String, "valor": String, "color": Color}
	for hijo in _contenedor_metricas.get_children():
		hijo.queue_free()

	for fila in filas:
		var hbox := HBoxContainer.new()
		var lbl_k := Label.new()
		lbl_k.text = str(fila.get("etiqueta", ""))
		lbl_k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_k.add_theme_color_override("font_color", Color("#B9B4D8"))
		lbl_k.add_theme_font_size_override("font_size", 13)

		var lbl_v := Label.new()
		lbl_v.text = str(fila.get("valor", ""))
		var col_valor: Color = fila.get("color", Color("#FFFFFF"))
		lbl_v.add_theme_color_override("font_color", col_valor)
		lbl_v.add_theme_font_size_override("font_size", 13)

		hbox.add_child(lbl_k)
		hbox.add_child(lbl_v)
		_contenedor_metricas.add_child(hbox)


class _IconoNaveBarra extends Control:
	func _draw() -> void:
		# Ícono compacto de nave apuntando a la derecha sobre la barra naranja
		var pts := PackedVector2Array([
			Vector2(24, 11),
			Vector2(7, 3),
			Vector2(10, 11),
			Vector2(7, 19),
		])
		draw_colored_polygon(pts, Color("#FFF7ED"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("ff9a4d"), 1.5, true)
		draw_circle(Vector2(15, 11), 2.3, Color("#38BDF8"))
