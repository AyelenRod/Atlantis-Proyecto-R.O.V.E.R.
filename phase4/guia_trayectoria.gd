# Dibuja una guía visual de puntos animados (ruta de trayectoria) y tolerancias de objetivo
extends Node2D
class_name GuiaTrayectoria

@export var color_puntos: Color = Color(0.98, 0.68, 0.22, 0.85)
@export var color_objetivo: Color = Color(0.22, 0.88, 0.62, 0.85)
@export var separacion_puntos: float = 24.0
@export var radio_punto: float = 3.2
@export var velocidad_animacion: float = 38.0

var puntos_ruta: PackedVector2Array = PackedVector2Array()
var posicion_objetivo: Vector2 = Vector2.ZERO
var radio_objetivo: float = 44.0
var mostrar_zona_objetivo: bool = true
var angulo_objetivo_rad: float = 0.0
var mostrar_vector_angulo: bool = false

var _fase: float = 0.0


func configurar_ruta(puntos: PackedVector2Array, meta: Vector2, radio_meta: float = 44.0) -> void:
	puntos_ruta = puntos
	posicion_objetivo = meta
	radio_objetivo = radio_meta
	queue_redraw()


func _process(delta: float) -> void:
	_fase = fposmod(_fase + delta * velocidad_animacion, separacion_puntos)
	queue_redraw()


func _draw() -> void:
	# Dibujar puntos animados a lo largo de la polilínea guía
	if puntos_ruta.size() >= 2:
		var acumulado := 0.0
		for i in range(puntos_ruta.size() - 1):
			var a := puntos_ruta[i]
			var b := puntos_ruta[i + 1]
			var dist := a.distance_to(b)
			if dist < 1.0:
				continue
			var dir := (b - a) / dist
			var cursor := _fase - fposmod(acumulado, separacion_puntos)
			if cursor < 0.0:
				cursor += separacion_puntos
			while cursor <= dist:
				var p := a + dir * cursor
				var progreso := clampf((acumulado + cursor) / maxf(1.0, _longitud_total()), 0.0, 1.0)
				var col := color_puntos.lerp(color_objetivo, progreso * 0.75)
				col.a *= 0.45 + 0.55 * (1.0 - absf(progreso - 0.5))
				draw_circle(p, radio_punto, col)
				cursor += separacion_puntos
			acumulado += dist

	# Dibujar anillo de destino / ventana orbital
	if mostrar_zona_objetivo:
		var pulso := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.005)
		draw_arc(posicion_objetivo, radio_objetivo * pulso, 0.0, TAU, 48, color_objetivo, 2.0, true)
		draw_arc(posicion_objetivo, radio_objetivo * 0.45, 0.0, TAU, 32, Color(color_objetivo.r, color_objetivo.g, color_objetivo.b, 0.35), 1.5, true)

		# Indicador opcional de ángulo óptimo (ej.
		if mostrar_vector_angulo:
			var dir_ang := Vector2.RIGHT.rotated(angulo_objetivo_rad)
			draw_line(
				posicion_objetivo - dir_ang * (radio_objetivo * 0.7),
				posicion_objetivo + dir_ang * (radio_objetivo * 0.9),
				Color(1.0, 0.85, 0.35, 0.9),
				2.0,
				true
			)


func _longitud_total() -> float:
	var total := 0.0
	for i in range(puntos_ruta.size() - 1):
		total += puntos_ruta[i].distance_to(puntos_ruta[i + 1])
	return total
