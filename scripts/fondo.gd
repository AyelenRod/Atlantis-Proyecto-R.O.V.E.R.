
class_name Fondo
extends Node2D

## Fondo espacial 2.5D procedural

var tam := Vector2(1280, 720)
var cantidad := 220

var deriva := 8.0
var tiempo := 0.0

var estrellas := []
var planetas := []
var asteroides := []
var nebulosas := []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# ESTRELLAS
	for i in cantidad:
		estrellas.append({
			"pos": Vector2(
				rng.randf_range(0, tam.x),
				rng.randf_range(0, tam.y)
			),
			"fase": rng.randf_range(0, TAU),
			"tam": rng.randf_range(0.8, 2.2),
			"vel": rng.randf_range(0.2, 1.0)
		})

	# PLANETAS
	planetas = [
		{
			"pos": Vector2(1000, 180),
			"radio": 95.0,
			"color": Color("#5141a0"),
			"luz": Color("#a99aff"),
			"vel": 2.0
		},
		{
			"pos": Vector2(260, 560),
			"radio": 42.0,
			"color": Color("#176b91"),
			"luz": Color("#61dfff"),
			"vel": 5.0
		}
	]

	# ASTEROIDES
	for i in 16:
		asteroides.append({
			"pos": Vector2(
				rng.randf_range(0, tam.x),
				rng.randf_range(0, tam.y)
			),
			"radio": rng.randf_range(3, 11),
			"fase": rng.randf_range(0, TAU),
			"vel": rng.randf_range(5, 15)
		})

	# NEBULOSAS
	nebulosas = [
		{"pos": Vector2(350, 250), "color": Color(0.3, 0.1, 0.7, 0.12), "radio": 220.0},
		{"pos": Vector2(850, 520), "color": Color(0.05, 0.35, 0.8, 0.10), "radio": 260.0},
		{"pos": Vector2(700, 100), "color": Color(0.7, 0.1, 0.4, 0.08), "radio": 180.0}
	]


func _process(delta: float) -> void:
	tiempo += delta

	for estrella in estrellas:
		var p = estrella["pos"]
		p.x -= deriva * estrella["vel"] * delta

		if p.x < 0:
			p.x = tam.x

		estrella["pos"] = p

	for roca in asteroides:
		roca["pos"].x -= roca["vel"] * delta

		if roca["pos"].x < -20:
			roca["pos"].x = tam.x + 20

	queue_redraw()


func _draw() -> void:
	# ESPACIO
	draw_rect(Rect2(Vector2.ZERO, tam), Color("#050611"))

	# NEBULOSAS
	for nube in nebulosas:
		var pos = nube["pos"]
		var radio = nube["radio"]

		for i in 8:
			var escala = 1.0 - float(i) * 0.10
			var color = nube["color"]
			color.a = nube["color"].a * (1.0 - float(i) * 0.08)

			draw_circle(pos, radio * escala, color)

	# ESTRELLAS
	for estrella in estrellas:
		var alfa = 0.4 + 0.5 * sin(
			tiempo * 1.5 * estrella["vel"] + estrella["fase"]
		)

		draw_circle(
			estrella["pos"],
			estrella["tam"],
			Color(0.8, 0.9, 1.0, alfa)
		)

	# PLANETAS
	for planeta in planetas:
		dibujar_planeta(planeta)

	# ASTEROIDES
	for roca in asteroides:
		dibujar_asteroide(roca)


func dibujar_planeta(planeta: Dictionary) -> void:
	var pos: Vector2 = planeta["pos"]
	var radio: float = planeta["radio"]

	# ATMOSFERA
	for i in 6:
		var escala = 1.2 + float(i) * 0.06
		var aura = planeta["luz"]
		aura.a = 0.035

		draw_circle(pos, radio * escala, aura)

	# CUERPO
	draw_circle(pos, radio, planeta["color"])

	# SOMBRA DEL PLANETA
	draw_circle(
		pos + Vector2(radio * 0.35, radio * 0.12),
		radio * 0.88,
		Color(0.01, 0.015, 0.06, 0.65)
	)

	# ILUMINACIÓN
	draw_arc(
		pos,
		radio,
		deg_to_rad(110),
		deg_to_rad(290),
		64,
		planeta["luz"],
		3.0
	)

	# BRILLO
	draw_arc(
		pos,
		radio * 1.04,
		deg_to_rad(200),
		deg_to_rad(340),
		64,
		Color(0.5, 0.8, 1.0, 0.5),
		1.5
	)


func dibujar_asteroide(roca: Dictionary) -> void:
	var pos: Vector2 = roca["pos"]
	var radio: float = roca["radio"]
	var rotacion: float = tiempo * 0.5 + roca["fase"]

	var puntos := PackedVector2Array()

	for i in 8:
		var angulo = TAU * float(i) / 8.0 + rotacion
		var variacion = 0.75 + 0.25 * sin(
			float(i) * 4.0 + roca["fase"]
		)

		puntos.append(
			pos + Vector2(cos(angulo), sin(angulo)) * radio * variacion
		)

	for i in puntos.size():
		var siguiente = (i + 1) % puntos.size()

		draw_line(
			puntos[i],
			puntos[siguiente],
			Color("#777d9b"),
			1.5
		)

	draw_colored_polygon(
		puntos,
		Color("#30354b")
	)
