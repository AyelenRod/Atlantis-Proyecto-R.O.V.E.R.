extends Control
## SALA DE ESPERA del multijugador en red (Wi-Fi).

const TemaEspacial = preload("res://tema_espacial.gd")
const FondoEspacial = preload("res://fondo_espacial.gd")
const Datos = preload("res://fase1_datos.gd")

const COLOR_ACENTO := Color("ff9a4d")
const ANCHO_COLUMNA := 900.0

var _nombre := "Jugador"
var _ip := ""
var _nivel := ""
var _mensaje := ""
var _margen: MarginContainer
var _contenido: VBoxContainer


func _ready() -> void:
	theme = TemaEspacial.crear()

	var fondo := FondoEspacial.new()
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_margen = MarginContainer.new()
	add_child(_margen)
	_margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margen.add_theme_constant_override("margin_top", 16)
	_margen.add_theme_constant_override("margin_bottom", 16)
	resized.connect(_ajustar_margenes)
	_ajustar_margenes()

	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 10)
	_margen.add_child(_contenido)

	var nivel_anterior := String(GameState.config.get("nivel", ""))
	if Datos.NIVELES.has(nivel_anterior):
		_nivel = nivel_anterior

	Red.lobby_cambio.connect(_mostrar)
	Red.conexion_fallida.connect(_al_fallar)
	Red.desconectado.connect(_al_desconectar)
	_mostrar()


func _ajustar_margenes() -> void:
	var m := int(maxf(24.0, (size.x - ANCHO_COLUMNA) * 0.5))
	_margen.add_theme_constant_override("margin_left", m)
	_margen.add_theme_constant_override("margin_right", m)


# ---------------------------------------------------------------- ayudas de interfaz

func _titulo(t: String, tam: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0.72, 0.58, 1.0, 0.45))
	l.add_theme_constant_override("outline_size", 8)
	_contenido.add_child(l)
	return l


func _texto(t: String, tam: int = 18) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", tam)
	_contenido.add_child(l)
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


func _limpiar_pantalla() -> void:
	for c in _contenido.get_children():
		_contenido.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------- pantallas

func _mostrar() -> void:
	_limpiar_pantalla()
	if not Red.activo:
		_vista_inicio()
	elif Red.jugadores.is_empty():
		_vista_conectando()
	else:
		_vista_sala()


func _vista_inicio() -> void:
	_titulo("MULTIJUGADOR EN RED", 36)
	_texto("Todos los dispositivos deben estar en la misma red Wi-Fi. Uno crea la sala y los demás se unen con su IP.", 16).modulate = Color(1, 1, 1, 0.75)

	_texto("Tu nombre", 20).modulate = COLOR_ACENTO
	var campo := LineEdit.new()
	campo.text = _nombre
	campo.placeholder_text = "Tu nombre"
	campo.max_length = 20
	campo.custom_minimum_size = Vector2(0, 40)
	campo.text_changed.connect(func(t: String) -> void: _nombre = t)
	_contenido.add_child(campo)

	_texto("Crear una sala", 20).modulate = COLOR_ACENTO
	_boton("Crear sala (soy el anfitrión)", 50, _crear)

	_texto("Unirse a una sala", 20).modulate = COLOR_ACENTO
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	_contenido.add_child(fila)
	var campo_ip := LineEdit.new()
	campo_ip.text = _ip
	campo_ip.placeholder_text = "IP del anfitrión, ej. 192.168.1.20"
	campo_ip.custom_minimum_size = Vector2(0, 40)
	campo_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo_ip.text_changed.connect(func(t: String) -> void: _ip = t)
	campo_ip.text_submitted.connect(func(_t: String) -> void: _unirse())
	fila.add_child(campo_ip)
	var b := _boton("Unirse", 40, _unirse, fila)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(140, 40)

	if _mensaje != "":
		var m := _texto(_mensaje, 16)
		m.modulate = Color("ffd166")

	_boton("← Volver al menú", 44, _volver)


func _vista_conectando() -> void:
	_titulo("CONECTANDO...", 36)
	_texto("Buscando la sala en %s" % _ip.strip_edges(), 18)
	_boton("Cancelar", 44, _salir_sala)


func _vista_sala() -> void:
	_titulo("SALA DE ESPERA", 36)
	if Red.es_host:
		var ips := Red.ips_locales()
		var txt := "Dile a los demás que se unan con esta IP:  %s" % (", ".join(ips) if ips.size() > 0 else "(no se encontró una IP de red local)")
		_texto(txt, 20).modulate = COLOR_ACENTO
		_texto("Puerto %d (UDP). Si no pueden entrar, revisa el firewall de esta computadora." % Red.PUERTO, 14).modulate = Color(1, 1, 1, 0.6)

	_texto("Jugadores (%d/%d)" % [Red.jugadores.size(), Red.MAX_JUGADORES], 20).modulate = COLOR_ACENTO
	var mi_id := multiplayer.get_unique_id()
	for k in Red.jugadores.size():
		var j: Dictionary = Red.jugadores[k]
		var linea := "%s  (astronauta %s)" % [String(j["nombre"]), GameState.nombre_color(k)]
		if int(j["id"]) == 1:
			linea += "  ·  anfitrión"
		if int(j["id"]) == mi_id:
			linea += "  ← tú"
		_texto("●  " + linea, 20).modulate = GameState.color_jugador(k)

	if Red.es_host:
		_texto("Dificultad", 20).modulate = COLOR_ACENTO
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_contenido.add_child(scroll)
		var tarjetas := VBoxContainer.new()
		tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tarjetas.add_theme_constant_override("separation", 8)
		scroll.add_child(tarjetas)
		_texto("El multijugador se juega en Medio o Difícil.", 14).modulate = Color(1, 1, 1, 0.6)
		for id in Datos.ORDEN_NIVELES:
			if not Datos.NIVELES_EQUIPO.has(id):
				continue
			var n: Dictionary = Datos.NIVELES[id]
			var t := "%s%s  —  %s" % ["✓  " if id == _nivel else "", n["nombre"], n["resumen"]]
			var b := _boton(t, 56, _elegir_nivel.bind(id), tarjetas)
			b.add_theme_font_size_override("font_size", 16)
		var listo: bool = Red.jugadores.size() >= 2 and _nivel != ""
		var ini := _boton("Iniciar partida", 52, _iniciar)
		ini.disabled = not listo
		if Red.jugadores.size() < 2:
			_texto("Hacen falta al menos 2 jugadores.", 14).modulate = Color("ffd166")
		elif _nivel == "":
			_texto("Elige una dificultad para continuar.", 14).modulate = Color("ffd166")
	else:
		_texto("Esperando a que el anfitrión inicie la partida...", 18).modulate = Color(1, 1, 1, 0.8)

	_boton("← Salir de la sala", 44, _salir_sala)


# ---------------------------------------------------------------- acciones

func _crear() -> void:
	_mensaje = ""
	var err := Red.crear_sala(_nombre)
	if err != OK:
		_mensaje = "No se pudo crear la sala (¿el puerto %d está en uso?)." % Red.PUERTO
		_mostrar()


func _unirse() -> void:
	_mensaje = ""
	if _ip.strip_edges() == "":
		_mensaje = "Escribe la IP del anfitrión."
		_mostrar()
		return
	var err := Red.unirse(_ip, _nombre)
	if err != OK:
		_mensaje = "IP no válida o no se pudo iniciar la conexión."
	_mostrar()


func _elegir_nivel(id: String) -> void:
	_nivel = id
	_mostrar()


func _iniciar() -> void:
	Red.iniciar_partida(_nivel)


func _salir_sala() -> void:
	Red.cerrar()
	_mensaje = ""
	_mostrar()


func _volver() -> void:
	Red.cerrar()
	Transicion.ir_a("res://menu.tscn")


func _al_fallar(motivo: String) -> void:
	_mensaje = motivo
	_mostrar()


func _al_desconectar(motivo: String) -> void:
	_mensaje = motivo
	_mostrar()
