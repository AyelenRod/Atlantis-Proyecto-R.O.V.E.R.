extends PhaseBase
## Interfaz de la Fase 5 (Sala de resultados): solo dibuja pantallas y muestra lo que calcula

const TemaEspacial = preload("res://tema_espacial.gd")
const FondoEspacial = preload("res://fondo_espacial.gd")
const Datos = preload("res://fase1_datos.gd")   # nombres de salas e imágenes

const USAR_DATOS_DEMO := true   # carga DatosDemoFase5 si la nave llega vacía

const COLOR_ACENTO := Color("ff9a4d")
const VERDE := Color("7be495")
const ROJO := Color("ff6b6b")
const AMARILLO := Color("ffd166")

var evaluacion := EvaluacionMision.new()
var datos_demo := false

var _contenido: VBoxContainer
var _margen: MarginContainer
var _deco: Control
var _pista: Control
var _progreso: ProgressBar
var _cohete: TextureRect
var _etiquetas_fase: Array = []
var _flotantes: Array = []
var _tiempo: float = 0.0
var _puntaje_lbl: Label
var _veredicto_lbl: Label


func _sola() -> bool:
	return get_tree().current_scene == self


func _ready() -> void:
	# Datos y evaluación (lógica)
	if GameState.componentes.is_empty() and USAR_DATOS_DEMO:
		DatosDemoFase5.cargar()
		datos_demo = true
	evaluacion.evaluar()
	GameState.puntaje = evaluacion.puntaje

	# Pantalla
	theme = TemaEspacial.crear()

	var fondo := FondoEspacial.new()
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_deco = Control.new()
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deco)
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_margen = MarginContainer.new()
	add_child(_margen)
	_margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margen.add_theme_constant_override("margin_top", 28 if _sola() else 64)
	_margen.add_theme_constant_override("margin_bottom", 28)
	resized.connect(_ajustar_margenes)
	_ajustar_margenes()

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	_margen.add_child(raiz)
	raiz.add_child(_crear_barra())

	var contexto := Label.new()
	contexto.text = _texto_contexto()
	contexto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contexto.add_theme_font_size_override("font_size", 16)
	contexto.modulate = COLOR_ACENTO
	raiz.add_child(contexto)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(scroll)

	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 14)
	scroll.add_child(_contenido)

	_construir_reporte()
	_decorar()
	_animar()


func _ajustar_margenes() -> void:
	var m := int(maxf(24.0, (size.x - 900.0) * 0.5))
	_margen.add_theme_constant_override("margin_left", m)
	_margen.add_theme_constant_override("margin_right", m)


func _process(delta: float) -> void:
	_tiempo += delta
	var s := _deco.size
	for f in _flotantes:
		var spr: Sprite2D = f["spr"]
		spr.position = Vector2(f["rx"] * s.x, f["ry"] * s.y + sin(_tiempo * 0.9 + f["fase"]) * f["amp"])
		spr.rotation = sin(_tiempo * 0.6 + f["fase"]) * 0.06 + f["rot"]


func _texto_contexto() -> String:
	var f: Dictionary = GameState.ficha
	var nivel_nombre: String = f.get("nivel_nombre", GameState.NIVELES[GameState.nivel_actual()]["nombre"])
	var t := "Nivel: %s  ·  Destino: %s" % [nivel_nombre, GameState.destino]
	if f.has("jugadores"):
		var n: int = f["jugadores"].size()
		t += "  ·  " + ("Solo" if n <= 1 else "Equipo de %d" % n)
	if datos_demo:
		t += "  ·  (datos de demostración)"
	return t


# ---------------------------------------------------------------- imágenes y dibujos flotantes

func _cargar(ruta: String) -> Texture2D:
	if ruta != "" and ResourceLoader.exists(ruta):
		return load(ruta)
	return null


func _agregar_flotante(clave: String, rx: float, ry: float, tam: float, amp: float = 10.0, rot: float = 0.0) -> void:
	var tex := _cargar(Datos.IMG.get(clave, ""))
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	var lado: float = maxf(tex.get_width(), tex.get_height())
	spr.scale = Vector2.ONE * (tam / lado)
	spr.modulate.a = 0.0
	_deco.add_child(spr)
	create_tween().tween_property(spr, "modulate:a", 1.0, 0.5)
	_flotantes.append({"spr": spr, "rx": rx, "ry": ry, "amp": amp, "rot": rot, "fase": randf() * TAU})


func _decorar() -> void:
	if evaluacion.exito:
		_agregar_flotante("astronauta_bandera", 0.93, 0.50, 150.0)
		_agregar_flotante("satelite", 0.07, 0.40, 120.0, 8.0, -0.3)
	else:
		_agregar_flotante("astronauta_morado", 0.93, 0.50, 150.0, 10.0, 0.4)
		_agregar_flotante("ovni", 0.07, 0.55, 120.0, 10.0)


# ---------------------------------------------------------------- barra de progreso con cohete

func _crear_barra() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)

	var fila := HBoxContainer.new()
	for i in Datos.FASES.size():
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, Datos.FASES[i]]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 14)
		l.modulate = COLOR_ACENTO if i == Datos.FASES.size() - 1 else Color(1, 1, 1, 0.55)
		fila.add_child(l)
		_etiquetas_fase.append(l)
	caja.add_child(fila)

	_pista = Control.new()
	_pista.custom_minimum_size = Vector2(0, 50)
	caja.add_child(_pista)

	_progreso = ProgressBar.new()
	_progreso.max_value = 100
	_progreso.value = 80
	_progreso.show_percentage = false
	_progreso.custom_minimum_size = Vector2(0, 14)
	_progreso.anchor_left = 0.0
	_progreso.anchor_right = 1.0
	_progreso.anchor_top = 0.5
	_progreso.anchor_bottom = 0.5
	_progreso.offset_top = -7.0
	_progreso.offset_bottom = 7.0
	_pista.add_child(_progreso)

	_cohete = TextureRect.new()
	_cohete.texture = _cargar(Datos.IMG.get("cohete_horizontal", ""))
	_cohete.visible = _cohete.texture != null
	_cohete.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cohete.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cohete.custom_minimum_size = Vector2(64, 64)
	_cohete.size = Vector2(64, 64)
	_cohete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.add_child(_cohete)

	_progreso.value_changed.connect(_colocar_cohete)
	_pista.resized.connect(_colocar_cohete)
	return caja


func _colocar_cohete(_valor: float = 0.0) -> void:
	if _cohete == null or _pista == null or _progreso == null:
		return
	var borde: float = _pista.size.x * _progreso.value / _progreso.max_value
	var x := clampf(borde - _cohete.size.x * 0.85, -8.0, _pista.size.x - _cohete.size.x)
	_cohete.position = Vector2(x, (_pista.size.y - _cohete.size.y) * 0.5)


# ---------------------------------------------------------------- ayudas de interfaz (mismas que Fase 1)

func _titulo(t: String, tam: int = 34, padre: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0.72, 0.58, 1.0, 0.45))
	l.add_theme_constant_override("outline_size", 8)
	var negrita := TemaEspacial.fuente(true)
	if negrita:
		l.add_theme_font_override("font", negrita)
	(padre if padre else _contenido).add_child(l)
	return l


func _texto(t: String, tam: int = 18, padre: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", tam)
	(padre if padre else _contenido).add_child(l)
	return l


func _boton(t: String, alto: int, accion: Callable, padre: Node = null) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, alto)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(accion)
	(padre if padre else _contenido).add_child(b)
	return b


func _tarjeta(borde: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	if borde.a > 0.0:
		p.add_theme_stylebox_override("panel", TemaEspacial.caja_color(borde))
	_contenido.add_child(p)
	return p


# ---------------------------------------------------------------- el reporte

func _construir_reporte() -> void:
	var color_estado := VERDE if evaluacion.exito else ROJO
	var f: Dictionary = GameState.ficha

	_titulo("Sala de resultados")
	_texto("Reporte final de la misión a %s." % GameState.destino).modulate = Color(1, 1, 1, 0.7)

	# --- Tarjeta de puntaje: número grande a la izquierda, datos de la misión a la derecha
	var tarjeta := _tarjeta(color_estado)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 28)
	tarjeta.add_child(fila)

	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(260, 0)
	izq.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(izq)
	_texto("PUNTAJE", 16, izq).modulate = COLOR_ACENTO
	_puntaje_lbl = _titulo("0", 72, izq)
	_puntaje_lbl.modulate = color_estado
	_texto("de 100", 14, izq).modulate = Color(1, 1, 1, 0.6)
	var n := evaluacion.estrellas()
	_texto("★".repeat(n) + "☆".repeat(3 - n), 34, izq).modulate = AMARILLO if n > 0 else Color(1, 1, 1, 0.4)
	_veredicto_lbl = _texto(("✓ " if evaluacion.exito else "✗ ") + evaluacion.calificacion().to_upper(), 20, izq)
	_veredicto_lbl.modulate = color_estado
	_veredicto_lbl.modulate.a = 0.0
	var negrita := TemaEspacial.fuente(true)
	if negrita:
		_veredicto_lbl.add_theme_font_override("font", negrita)

	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	der.add_theme_constant_override("separation", 8)
	fila.add_child(der)
	_texto("Misión", 16, der).modulate = COLOR_ACENTO
	_dato(der, "Objetivo", f.get("objetivo", "Misión a %s" % GameState.destino))
	if GameState.ruta != "":
		var ruta_txt: String = GameState.ruta
		if f.has("costo_ruta"):
			ruta_txt += " (%d M · %d días de preparación)" % [f["costo_ruta"], f["dias_ruta"]]
		_dato(der, "Ruta", ruta_txt)
	_dato(der, "Nave", "%d piezas · %.0f kg · energía %+.0f W · costo %.0f M" % [
		GameState.componentes.size(), GameState.masa_total(), GameState.balance_energia(), GameState.costo_total()])
	if not GameState.eventos_resueltos.is_empty():
		_dato(der, "Eventos resueltos", ", ".join(PackedStringArray(GameState.eventos_resueltos)))
	if not GameState.operacion.is_empty():
		var op: Dictionary = GameState.operacion
		_dato(der, "Operación", "%s — %s" % [op.get("titulo_nivel", "Nivel"), "completada" if op.get("exito", false) else "fallida"])
	if not GameState.asignaciones.is_empty():
		# Relevos: qué fases jugó cada quien, con su color de astronauta
		var nombres_cfg: Array = GameState.config.get("nombres", [])
		var lineas: Array = []
		for j in nombres_cfg.size():
			var fases: Array = []
			for i in GameState.asignaciones.size():
				if GameState.asignaciones[i] == j:
					fases.append(String(GameState.FASES[i]["nombre"]))
			lineas.append("%s (%s): %s" % [nombres_cfg[j], GameState.nombre_color(j), ", ".join(PackedStringArray(fases))])
		_dato(der, "Tripulación", "\n".join(PackedStringArray(lineas)))
	elif f.has("jugadores") and f["jugadores"].size() > 1:
		var nombres: Array = []
		for j in f["jugadores"]:
			nombres.append("%s (%s)" % [j["nombre"], ", ".join(PackedStringArray(j["roles"]))])
		_dato(der, "Tripulación", "\n".join(PackedStringArray(nombres)))

	# --- Tarjeta de revisión: tabla como la de "Requisitos del nivel"
	_texto("Revisión de la misión", 20).modulate = COLOR_ACENTO
	var tarjeta_rev := _tarjeta()
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 28)
	rejilla.add_theme_constant_override("v_separation", 12)
	tarjeta_rev.add_child(rejilla)
	for encabezado in ["Revisión", "Qué pasó", "Puntos", ""]:
		var h := Label.new()
		h.text = encabezado
		h.modulate = COLOR_ACENTO
		rejilla.add_child(h)
	for r in evaluacion.revisiones:
		_fila_revision(rejilla, r)

	# --- Aporte de la tripulación (solo en modo equipo)
	var aportes: Array = evaluacion.aporte_por_jugador()
	if not aportes.is_empty():
		_texto("Aporte de la tripulación", 20).modulate = COLOR_ACENTO
		var tarjeta_trip := _tarjeta()
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 10)
		tarjeta_trip.add_child(grid)
		var mejor := -1.0
		for a in aportes:
			if a["max"] > 0:
				mejor = maxf(mejor, float(a["puntos"]) / float(a["max"]))
		for a in aportes:
			var ratio := (float(a["puntos"]) / float(a["max"])) if a["max"] > 0 else 0.0
			var nom := Label.new()
			nom.text = "%s%s\n%s" % ["★ " if a["max"] > 0 and is_equal_approx(ratio, mejor) else "", a["nombre"], ", ".join(PackedStringArray(a["roles"]))]
			nom.custom_minimum_size = Vector2(200, 0)
			nom.add_theme_font_size_override("font_size", 15)
			if a.has("color"):
				nom.modulate = a["color"]
			grid.add_child(nom)
			var barra := ProgressBar.new()
			barra.max_value = 1.0
			barra.value = ratio
			barra.show_percentage = false
			barra.custom_minimum_size = Vector2(220, 14)
			barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(barra)
			var v := Label.new()
			v.text = "%d / %d\n%s" % [a["puntos"], a["max"], ", ".join(PackedStringArray(a["revisiones"]))]
			v.add_theme_font_size_override("font_size", 13)
			v.modulate = Color(1, 1, 1, 0.75)
			grid.add_child(v)

	# --- Por qué funcionó o falló
	var tarjeta_res := _tarjeta(color_estado)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	tarjeta_res.add_child(caja)
	var enc := _texto("Por qué funcionó" if evaluacion.exito else "Por qué falló", 20, caja)
	enc.modulate = color_estado
	if negrita:
		enc.add_theme_font_override("font", negrita)
	_texto(evaluacion.resumen(), 17, caja)

	_boton("Terminar misión y volver al menú →", 60, terminar)


func _dato(padre: Node, nombre: String, valor: String) -> void:
	var l := Label.new()
	l.text = "%s: %s" % [nombre, valor]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 16)
	padre.add_child(l)


func _fila_revision(rejilla: GridContainer, r: EvaluacionMision.Revision) -> void:
	var color := VERDE if r.ok else ROJO
	for i in 4:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i < 3 else Control.SIZE_SHRINK_BEGIN
		match i:
			0:
				l.text = r.nombre
				l.custom_minimum_size = Vector2(150, 0)
			1:
				l.text = r.detalle
				l.add_theme_font_size_override("font_size", 15)
			2:
				l.text = "%d / %d" % [r.puntos, r.maximo]
				l.custom_minimum_size = Vector2(70, 0)
				l.modulate = AMARILLO
			3:
				l.text = "✓" if r.ok else "✗"
				l.modulate = color
		if i == 1 and not r.ok:
			l.modulate = color
		rejilla.add_child(l)


# ---------------------------------------------------------------- animaciones

func _animar() -> void:
	_contenido.modulate.a = 0.0
	create_tween().tween_property(_contenido, "modulate:a", 1.0, 0.25)
	# La barra de salas llega al final (80 % -> 100 %)
	create_tween().tween_property(_progreso, "value", 100.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# El puntaje cuenta de 0 al final y luego aparece el veredicto
	var t := create_tween()
	t.tween_method(_poner_puntaje, 0, evaluacion.puntaje, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_mostrar_veredicto)


func _poner_puntaje(v: Variant) -> void:
	_puntaje_lbl.text = str(int(v))


func _mostrar_veredicto() -> void:
	_veredicto_lbl.pivot_offset = _veredicto_lbl.size / 2.0
	_veredicto_lbl.scale = Vector2(0.6, 0.6)
	var t := create_tween().set_parallel(true)
	t.tween_property(_veredicto_lbl, "modulate:a", 1.0, 0.3)
	t.tween_property(_veredicto_lbl, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
