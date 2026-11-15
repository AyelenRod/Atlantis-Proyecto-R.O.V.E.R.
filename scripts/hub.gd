extends Node2D
## Estación orbital modular: una viga-pasillo central (como la de la ISS) con el módulo de mando

signal entrar_fase(indice: int)

const T := 32                      # tamaño de un tile en píxeles
const MUNDO := Vector2i(72, 46)    # tamaño del mundo en tiles
const ZOOM := 1.25

# Rectángulos en tiles (x, y, ancho, alto).
# "fase" = índice de la fase (0-4) o -1 si no es sala de fase. "tipo": mando | modulo | viga | pasillo.
const AREAS := [
	{"rect": Rect2i(30, 19, 13, 7), "fase": -1, "tipo": "mando"},    # 0  Mando (centro de la viga)
	{"rect": Rect2i(4, 8, 13, 10),  "fase": 0,  "tipo": "modulo"},   # 1  Planificación (arriba, oeste)
	{"rect": Rect2i(17, 27, 13, 10), "fase": 1, "tipo": "modulo"},   # 2  Laboratorio (abajo)
	{"rect": Rect2i(30, 8, 13, 10), "fase": 2,  "tipo": "modulo"},   # 3  Lanzamiento (arriba, sobre el mando)
	{"rect": Rect2i(43, 27, 13, 10), "fase": 3, "tipo": "modulo"},   # 4  Operación (abajo)
	{"rect": Rect2i(56, 8, 13, 10), "fase": 4,  "tipo": "modulo"},   # 5  Resultados (arriba, este)
	# Mando: escalones que redondean el octágono
	{"rect": Rect2i(32, 18, 9, 1),  "fase": -1, "tipo": "mando"},
	{"rect": Rect2i(32, 26, 9, 1),  "fase": -1, "tipo": "mando"},
	# Viga central (dos tramos, a cada lado del mando)
	{"rect": Rect2i(4, 21, 26, 3),  "fase": -1, "tipo": "viga"},
	{"rect": Rect2i(43, 21, 24, 3), "fase": -1, "tipo": "viga"},
	# Esclusas que unen cada módulo con la viga
	{"rect": Rect2i(9, 18, 3, 3),   "fase": -1, "tipo": "pasillo"},
	{"rect": Rect2i(22, 24, 3, 3),  "fase": -1, "tipo": "pasillo"},
	{"rect": Rect2i(35, 18, 3, 1),  "fase": -1, "tipo": "pasillo"},
	{"rect": Rect2i(48, 24, 3, 3),  "fase": -1, "tipo": "pasillo"},
	{"rect": Rect2i(61, 18, 3, 3),  "fase": -1, "tipo": "pasillo"},
]

# Compuerta de cada módulo (se abre cuando la fase está desbloqueada).
const PUERTAS := [
	{"fase": 0, "rect": Rect2i(9, 18, 3, 1)},
	{"fase": 1, "rect": Rect2i(22, 26, 3, 1)},
	{"fase": 2, "rect": Rect2i(35, 18, 3, 1)},
	{"fase": 3, "rect": Rect2i(48, 26, 3, 1)},
	{"fase": 4, "rect": Rect2i(61, 18, 3, 1)},
]

# Paleta: grafito azulado con un acento por módulo (menos pastel, más "estación").
const COLORES_SALA := [
	Color("#3f6f9c"), Color("#6b5b9e"), Color("#3c8c8c"), Color("#a06a3a"), Color("#3f8a5a"),
]
const COLOR_PISO := Color("#2b3344")        # base del piso de los módulos
const COLOR_MANDO := Color("#3a4560")
const COLOR_VIGA := Color("#4a5366")
const COLOR_PASILLO := Color("#39414f")
const COLOR_MURO := Color("#11141d")
const COLOR_MURO_FRENTE := Color("#262d3d")
const COLOR_MURO_BORDE := Color("#8793ad")
const COLOR_LUZ := Color("#ffb86b")          # luces de la viga (naranja del tema)
const COLOR_VIDRIO := Color(0.35, 0.6, 1.0, 0.18)

var jugador: Player
var zonas: Array[Zona] = []
var piso := {}      # Vector2i -> índice en AREAS
var muros := {}     # Vector2i -> true
var ventanas := {}  # Vector2i -> true (tiles de pared que son ventanal)
var _t := 0.0


func _ready() -> void:
	# El fondo (galaxia con estrellas) lo pone main.gd en una CanvasLayer detrás de la base:
	_construir_mapa()
	_marcar_ventanas()
	_crear_paredes()
	_crear_puertas()
	# El centro del módulo de mando queda libre (sin mesa): solo los anillos pintados en el piso.
	_crear_zonas()
	_crear_jugador()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 4.0) != int((_t - delta) * 4.0):   # las luces de la viga parpadean 4 veces por segundo
		queue_redraw()


## Zona en la que está parado el jugador y que puede usar (o null).
func zona_cercana() -> Zona:
	for z in zonas:
		if z.jugador_dentro and GameState.fase_disponible(z.indice):
			return z
	return null


func centro_area(indice: int) -> Vector2:
	var r: Rect2i = AREAS[indice]["rect"]
	return Vector2(r.position * T) + Vector2(r.size * T) / 2.0


func _construir_mapa() -> void:
	for idx in AREAS.size():
		var r: Rect2i = AREAS[idx]["rect"]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				piso[Vector2i(x, y)] = idx
	for clave in piso:
		var p: Vector2i = clave
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var q := p + Vector2i(dx, dy)
				if not piso.has(q):
					muros[q] = true


## Los módulos tienen un ventanal en la pared que da al espacio (arriba en los de arriba,
## abajo en los de abajo).
func _marcar_ventanas() -> void:
	for i in range(1, 6):
		var r: Rect2i = AREAS[i]["rect"]
		var arriba: bool = r.position.y < 21
		var y: int = r.position.y - 1 if arriba else r.end.y
		for x in range(r.position.x + 2, r.end.x - 2):
			var p := Vector2i(x, y)
			if muros.has(p):
				ventanas[p] = true


func _crear_paredes() -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Paredes"
	add_child(cuerpo)
	# Une los tiles de pared contiguos de cada fila para usar menos colisiones.
	var filas := {}
	for clave in muros:
		var v: Vector2i = clave
		if not filas.has(v.y):
			filas[v.y] = []
		filas[v.y].append(v.x)
	for y in filas:
		var xs: Array = filas[y]
		xs.sort()
		var inicio: int = xs[0]
		var previo: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i == xs.size() or xs[i] != previo + 1:
				_rect_pared(cuerpo, inicio, y, previo - inicio + 1)
				if i < xs.size():
					inicio = xs[i]
			if i < xs.size():
				previo = xs[i]


func _rect_pared(cuerpo: StaticBody2D, x0: int, y: int, n: int) -> void:
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(n * T, T)
	forma.shape = rect
	forma.position = Vector2(x0 * T + n * T / 2.0, y * T + T / 2.0)
	cuerpo.add_child(forma)


func _crear_puertas() -> void:
	for d in PUERTAS:
		var r: Rect2i = d["rect"]
		var puerta := Puerta.new()
		puerta.configurar(d["fase"], Vector2(r.size * T))
		puerta.position = Vector2(r.position * T) + Vector2(r.size * T) / 2.0
		add_child(puerta)


func _crear_zonas() -> void:
	for i in GameState.FASES.size():
		var z := Zona.new()
		z.configurar(i, GameState.FASES[i]["nombre"], centro_area(i + 1))
		z.entrar_solicitado.connect(func(idx: int): entrar_fase.emit(idx))
		add_child(z)
		zonas.append(z)


func _crear_jugador() -> void:
	jugador = Player.new()
	jugador.position = centro_area(0) + Vector2(0, 48)
	add_child(jugador)

	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MUNDO.x * T
	cam.limit_bottom = MUNDO.y * T
	jugador.add_child(cam)


# ---------------------------------------------------------------- dibujo (arte por código)

func _draw() -> void:
	_dibujar_piso()
	_dibujar_detalles_modulos()
	_dibujar_viga()
	_dibujar_mando()
	_dibujar_paredes()
	_dibujar_consolas()


func _dibujar_piso() -> void:
	for clave in piso:
		var pos: Vector2i = clave
		var idx: int = piso[clave]
		var tipo: String = AREAS[idx]["tipo"]
		var f: int = AREAS[idx]["fase"]
		var base := COLOR_PASILLO
		match tipo:
			"mando": base = COLOR_MANDO
			"viga": base = COLOR_VIGA
			"modulo": base = COLOR_PISO.lerp(COLORES_SALA[f], 0.35)
		var r := Rect2(Vector2(pos * T), Vector2(T, T))
		draw_rect(r, base)
		# Placas grandes (2x2 tiles) en vez de cuadrícula fina
		if pos.x % 2 == 0:
			draw_line(r.position, r.position + Vector2(0, T), Color(0, 0, 0, 0.18), 1.0)
		if pos.y % 2 == 0:
			draw_line(r.position, r.position + Vector2(T, 0), Color(0, 0, 0, 0.18), 1.0)
		if muros.has(pos + Vector2i.UP):   # sombra bajo la pared
			draw_rect(Rect2(r.position, Vector2(T, 10)), Color(0, 0, 0, 0.30))


## Cada módulo: franja de color en el borde interior, emblema circular al centro.
func _dibujar_detalles_modulos() -> void:
	for i in range(1, 6):
		var r: Rect2i = AREAS[i]["rect"]
		var f: int = AREAS[i]["fase"]
		var acento: Color = COLORES_SALA[f]
		var px := Rect2(Vector2(r.position * T), Vector2(r.size * T))
		# Franja perimetral
		draw_rect(px.grow(-6.0), acento.lightened(0.15), false, 4.0)
		draw_rect(px.grow(-14.0), Color(acento.r, acento.g, acento.b, 0.35), false, 1.5)
		# Emblema del módulo en el piso (anillo con marcas, como una plataforma)
		var c := centro_area(i)
		draw_circle(c, 78.0, Color(0, 0, 0, 0.18))
		draw_arc(c, 72.0, 0.0, TAU, 64, acento.lightened(0.2), 3.0, true)
		draw_arc(c, 58.0, 0.0, TAU, 64, Color(acento.r, acento.g, acento.b, 0.5), 1.5, true)
		for k in 8:
			var a := float(k) * TAU / 8.0
			draw_line(c + Vector2(62, 0).rotated(a), c + Vector2(72, 0).rotated(a), acento.lightened(0.3), 2.0)
		# Número de la fase grande y tenue en una esquina
		var fuente := ThemeDB.fallback_font
		draw_string(fuente, Vector2(px.position.x + 22, px.end.y - 20), str(f + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1, 1, 1, 0.08))


## La viga: celosía diagonal y luces de guía que corren hacia el mando.
func _dibujar_viga() -> void:
	var parpadeo := int(_t * 4.0)
	for a in AREAS:
		if a["tipo"] != "viga":
			continue
		var r: Rect2i = a["rect"]
		var px := Rect2(Vector2(r.position * T), Vector2(r.size * T))
		# Celosía
		for x in range(r.position.x, r.end.x, 2):
			var x0 := float(x * T)
			draw_line(Vector2(x0, px.position.y), Vector2(x0 + 2 * T, px.end.y), Color(1, 1, 1, 0.06), 2.0)
			draw_line(Vector2(x0 + 2 * T, px.position.y), Vector2(x0, px.end.y), Color(1, 1, 1, 0.06), 2.0)
		# Rieles laterales
		draw_line(px.position + Vector2(0, 4), Vector2(px.end.x, px.position.y + 4), Color("#6e7890"), 3.0)
		draw_line(Vector2(px.position.x, px.end.y - 4), px.end - Vector2(0, 4), Color("#6e7890"), 3.0)
		# Luces que "corren" hacia el centro
		var hacia_derecha := r.position.x < 30
		for x in range(r.position.x, r.end.x):
			var fase_luz: int = (x if hacia_derecha else -x) + parpadeo
			var on := fase_luz % 6 == 0
			var col := COLOR_LUZ if on else Color(COLOR_LUZ.r, COLOR_LUZ.g, COLOR_LUZ.b, 0.25)
			var cx := float(x * T) + T / 2.0
			draw_circle(Vector2(cx, px.position.y + 4), 2.5, col)
			draw_circle(Vector2(cx, px.end.y - 4), 2.5, col)


## El mando: anillos concéntricos y una rosa de orientación en el piso.
func _dibujar_mando() -> void:
	var c := centro_area(0)
	for k in range(1, 4):
		draw_arc(c, 30.0 * k, 0.0, TAU, 64, Color(1, 1, 1, 0.10), 2.0, true)
	for k in 4:
		var a := float(k) * TAU / 4.0 + PI / 4.0
		draw_line(c + Vector2(34, 0).rotated(a), c + Vector2(96, 0).rotated(a), Color(1, 1, 1, 0.08), 2.0)
	draw_arc(c, 100.0, 0.0, TAU, 72, Color("#8fa0c8"), 3.0, true)


func _dibujar_paredes() -> void:
	for clave in muros:
		var pos: Vector2i = clave
		var r := Rect2(Vector2(pos * T), Vector2(T, T))
		if ventanas.has(pos):
			# Ventanal: vidrio translúcido (se ven las estrellas del fondo) con marco
			draw_rect(r, COLOR_VIDRIO)
			draw_rect(r, Color("#1a2238"), false, 3.0)
			draw_line(r.position + Vector2(6, 6), r.position + Vector2(T - 10, T - 10), Color(1, 1, 1, 0.12), 2.0)
			continue
		draw_rect(r, COLOR_MURO)
		if piso.has(pos + Vector2i.DOWN):   # cara frontal de la pared
			draw_rect(r, COLOR_MURO_FRENTE)
			draw_rect(Rect2(r.position.x, r.position.y + T - 6, T, 6), COLOR_MURO_BORDE)
			draw_rect(Rect2(r.position.x, r.position.y, T, 2), Color("#0b0e18"))
		# Remaches en las paredes exteriores
		if (pos.x + pos.y) % 3 == 0:
			draw_circle(r.get_center(), 2.0, Color(1, 1, 1, 0.08))


## Consolas de pared en cada módulo (sustituyen a las cajas de carga).
func _dibujar_consolas() -> void:
	for i in range(1, 6):
		var r: Rect2i = AREAS[i]["rect"]
		var f: int = AREAS[i]["fase"]
		var acento: Color = COLORES_SALA[f]
		var y := float(r.position.y * T) + 4.0
		for x in [r.position.x + 1, r.end.x - 4]:
			var p := Vector2(x * T, y)
			var caja := Rect2(p, Vector2(3 * T - 8, 22))
			draw_rect(Rect2(caja.position + Vector2(0, 4), caja.size), Color(0, 0, 0, 0.3))
			draw_rect(caja, Color("#1b2130"))
			draw_rect(caja, acento.lightened(0.1), false, 2.0)
			draw_rect(Rect2(caja.position + Vector2(6, 5), Vector2(caja.size.x - 40, 12)), Color(acento.r, acento.g, acento.b, 0.45))
			for k in 3:
				var on := (int(_t * 2.0) + k + i) % 3 != 0
				draw_circle(caja.position + Vector2(caja.size.x - 10 - k * 9, 11), 3.0, Color("#7be495") if on else Color("#263040"))
