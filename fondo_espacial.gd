extends Control
## Fondo de espacio compartido por todas las fases.

var ruta_fondo: String = "res://img/fondo_galaxia.jpg"

var _textura: Texture2D = null
var _estrellas: Array = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ruta_fondo != "" and ResourceLoader.exists(ruta_fondo):
		_textura = load(ruta_fondo)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var colores := [Color("ffffff"), Color("cfd8ff"), Color("ffd9b3"), Color("d9c2ff")]
	for i in 200:
		_estrellas.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"r": rng.randf_range(0.6, 1.9),
			"fase": rng.randf() * TAU,
			"vel": rng.randf_range(0.6, 2.2),
			"color": colores[rng.randi() % colores.size()],
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 0 or s.y <= 0:
		return

	if _textura:
		# Imagen que cubre toda la pantalla, con un vaivén lento y una capa oscura
		# para que el texto se lea bien.
		var ts := _textura.get_size()
		var esc: float = maxf(s.x / ts.x, s.y / ts.y) * 1.08
		var tam := ts * esc
		var desv := Vector2(sin(_t * 0.15) * s.x * 0.015, cos(_t * 0.12) * s.y * 0.012)
		draw_texture_rect(_textura, Rect2((s - tam) / 2.0 + desv, tam), false)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.02, 0.10, 0.50))
	else:
		var arriba := Color("070616")
		var abajo := Color("150d33")
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]),
			PackedColorArray([arriba, arriba, abajo, abajo]))
		_nebulosa(Vector2(s.x * 0.22, s.y * 0.35), s.y * 0.55, Color(0.45, 0.30, 0.95))
		_nebulosa(Vector2(s.x * 0.75, s.y * 0.70), s.y * 0.50, Color(1.00, 0.45, 0.35))
		_planeta(Vector2(s.x * 0.02, s.y * 1.00), s.y * 0.22, Color("3b2f9e"), Color("8a7cff"), false)
		_planeta(Vector2(s.x * 0.98, s.y * 0.98), s.y * 0.17, Color("d9692b"), Color("ffc27a"), true)

	for e in _estrellas:
		var brillo: float = 0.40 + 0.60 * (0.5 + 0.5 * sin(_t * e["vel"] + e["fase"]))
		var c: Color = e["color"]
		c.a = brillo
		draw_circle(Vector2(e["p"].x * s.x, e["p"].y * s.y), e["r"], c)


func _nebulosa(centro: Vector2, radio: float, color: Color) -> void:
	var capas := 14
	for k in capas:
		var c := color
		c.a = 0.022
		draw_circle(centro, radio * (1.0 - float(k) / capas), c)


func _planeta(centro: Vector2, r: float, base: Color, luz: Color, anillo: bool) -> void:
	if anillo:
		draw_set_transform(centro, -0.35, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, r * 1.75, 0.0, TAU, 72, Color(1, 0.85, 0.6, 0.55), 7.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var b := base
	b.a = 0.9
	draw_circle(centro, r, b)
	var l := luz
	l.a = 0.30
	draw_circle(centro + Vector2(-r * 0.25, -r * 0.25), r * 0.70, l)
	l.a = 0.20
	draw_circle(centro + Vector2(-r * 0.35, -r * 0.35), r * 0.40, l)
