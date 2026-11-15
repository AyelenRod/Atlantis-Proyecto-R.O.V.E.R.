class_name Astronauta
extends Node2D
## Astronauta de la Tierra: traje blanco tipo EMU, casco con visor dorado, mochila de soporte

const BLANCO := Color("#f3f5f8")
const SOMBRA := Color("#c9cfda")
const GRIS := Color("#9aa1b0")
const GRIS_CLARO := Color("#dfe3ea")
const CONTORNO := Color("#2b2f3a")
const ROJO := Color("#d62828")
const NARANJA := Color("#e07a1f")
const ORO := Color("#c9922b")

## Color del traje.
var color_traje := BLANCO:
	set(v):
		color_traje = v
		queue_redraw()
var cara := 1.0                  # 1 = mira a la derecha, -1 = izquierda
var caminando := false
var flotar := false             # flotando en gravedad cero (menú)
var polvo_activo := true
var bandera: Array[Color] = [Color("#006847"), Color("#ffffff"), Color("#ce1126")]   # parche (México)
var fase := 0.0
var _t := 0.0
var _giro := 0.0
var _cara_previa := 1.0
var _polvo: CPUParticles2D


func _ready() -> void:
	_polvo = CPUParticles2D.new()
	_polvo.position = Vector2(0, 17)
	_polvo.amount = 10
	_polvo.lifetime = 0.45
	_polvo.local_coords = false
	_polvo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_polvo.emission_sphere_radius = 3.0
	_polvo.direction = Vector2(0, -1)
	_polvo.spread = 70.0
	_polvo.gravity = Vector2.ZERO
	_polvo.initial_velocity_min = 8.0
	_polvo.initial_velocity_max = 22.0
	_polvo.scale_amount_min = 2.0
	_polvo.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.87, 0.95, 0.55))
	g.set_color(1, Color(0.85, 0.87, 0.95, 0.0))
	_polvo.color_ramp = g
	_polvo.show_behind_parent = true
	_polvo.emitting = false
	add_child(_polvo)


func _process(delta: float) -> void:
	_t += delta
	if caminando:
		fase += delta * 10.0
	elif fase != 0.0:
		fase = 0.0
	if cara != _cara_previa:
		_cara_previa = cara
		_giro = 1.0
	_giro = maxf(0.0, _giro - delta * 7.0)
	_polvo.emitting = caminando and polvo_activo
	queue_redraw()


static func _elipse(c: Vector2, rx: float, ry: float, n: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# Transformación del cuerpo (espejo según la cara, con aplastamiento al girar).
func _base(bob: float, k: float) -> void:
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(k, 1.0))


# Transformación de una extremidad que gira sobre su articulación.
func _miembro(pivote: Vector2, angulo: float, bob: float, k: float) -> void:
	draw_set_transform(Vector2(pivote.x * k, pivote.y + bob), angulo * signf(cara), Vector2(k, 1.0))


func _pierna(pivote: Vector2, ang: float, bob: float, k: float, delante: bool) -> void:
	_miembro(pivote, ang, bob, k)
	var tela := color_traje if delante else color_traje.darkened(0.2)
	draw_rect(Rect2(-4.5, 0, 9, 8), tela)
	draw_rect(Rect2(-4.5, 0, 9, 8), CONTORNO, false, 1.5)
	draw_rect(Rect2(-4.5, 2.5, 9, 2), ROJO)
	draw_rect(Rect2(-5, 8, 12, 5), GRIS)
	draw_rect(Rect2(-5, 8, 12, 5), CONTORNO, false, 1.5)


func _brazo(pivote: Vector2, ang: float, bob: float, k: float, delante: bool) -> void:
	_miembro(pivote, ang, bob, k)
	var tela := color_traje if delante else color_traje.darkened(0.2)
	draw_rect(Rect2(-3.5, -1, 7, 10), tela)
	draw_rect(Rect2(-3.5, -1, 7, 10), CONTORNO, false, 1.5)
	if delante:
		for i in 3:
			draw_rect(Rect2(-3.0 + i * 2.0, 1.5, 2.0, 4.0), bandera[i])
		draw_rect(Rect2(-3.0, 1.5, 6.0, 4.0), CONTORNO, false, 1.0)
	draw_rect(Rect2(-4, 8, 8, 5), GRIS_CLARO)
	draw_rect(Rect2(-4, 8, 8, 5), CONTORNO, false, 1.5)
	draw_rect(Rect2(-4, 8, 8, 1.5), NARANJA)


func _draw() -> void:
	var k := cara * (1.0 - 0.3 * _giro)
	var s := 0.0
	var bob := 0.0
	if caminando:
		s = sin(fase) * 0.6
		bob = -absf(sin(fase)) * 2.5
	elif flotar:
		s = sin(_t * 1.2) * 0.14
		bob = sin(_t * 1.6) * 3.0
	else:
		bob = sin(_t * 2.2) * 0.8          # respiración

	# Sombra en el suelo
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not flotar:
		draw_colored_polygon(_elipse(Vector2(0, 17), 15.0 + bob, 5.0), Color(0, 0, 0, 0.3))

	# Atrás: pierna y brazo traseros
	_pierna(Vector2(0, 4), -s, bob, k, false)
	_brazo(Vector2(0, -6), s * 0.9, bob, k, false)

	# Mochila de soporte vital y torso
	_base(bob, k)
	draw_rect(Rect2(-17, -11, 9, 17), GRIS_CLARO)
	draw_rect(Rect2(-17, -11, 9, 17), CONTORNO, false, 1.5)
	draw_rect(Rect2(-15, -8, 5, 3), Color("#3b82f6"))
	draw_rect(Rect2(-15, -3, 5, 3), NARANJA)
	draw_line(Vector2(-8, -3), Vector2(-3, -1), GRIS, 2.0)
	draw_rect(Rect2(-9, -8, 18, 14), color_traje)
	draw_rect(Rect2(-9, 3, 18, 3), GRIS_CLARO)
	draw_rect(Rect2(-9, -8, 18, 14), CONTORNO, false, 1.5)
	draw_rect(Rect2(1, -5, 7, 6), GRIS)
	draw_rect(Rect2(1, -5, 7, 6), CONTORNO, false, 1.0)
	draw_circle(Vector2(2.7, -3.2), 0.9, ROJO)
	draw_circle(Vector2(4.7, -3.2), 0.9, Color("#4ade80"))
	draw_circle(Vector2(6.7, -3.2), 0.9, Color("#3b82f6"))

	# Delante: pierna y brazo delanteros
	_pierna(Vector2(0, 4), s, bob, k, true)
	_brazo(Vector2(0, -6), -s * 0.9, bob, k, true)

	# Casco con visor dorado
	_base(bob, k)
	draw_rect(Rect2(-6, -10, 12, 3), GRIS)
	draw_rect(Rect2(-2, -32, 6, 3), GRIS)
	draw_rect(Rect2(-2, -32, 6, 3), CONTORNO, false, 1.0)
	draw_circle(Vector2(1, -19), 11.5, color_traje.lightened(0.12))
	draw_arc(Vector2(1, -19), 11.5, 0.0, TAU, 28, CONTORNO, 1.5)
	var visor := _elipse(Vector2(5, -19), 7.5, 8.5)
	draw_colored_polygon(visor, ORO)
	draw_colored_polygon(_elipse(Vector2(4, -22), 5.0, 4.0), Color(0.96, 0.84, 0.48, 0.8))
	visor.append(visor[0])
	draw_polyline(visor, Color("#4a3510"), 1.5)
	draw_colored_polygon(_elipse(Vector2(8, -23), 2.0, 1.2), Color(1, 1, 1, 0.85))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
