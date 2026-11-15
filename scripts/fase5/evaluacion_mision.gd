class_name EvaluacionMision
extends RefCounted

# Masa máxima (kg) que el cohete puede llevar a cada destino.
const MASA_MAX := {"facil": 400.0, "medio": 250.0, "dificil": 150.0}

const SISTEMAS_REQUERIDOS := ["energia", "propulsion", "comunicacion", "computadora"]
const NOMBRE_SISTEMA := {
	"energia": "energía", "propulsion": "propulsión",
	"comunicacion": "comunicación", "computadora": "computadora",
}
const META_CIENCIA := 5.0   # datos (Mbps) con los que se obtiene el máximo en ciencia
## Qué fase (0-4) responde por cada revisión, para el aporte por jugador con el reparto de relevos.
const REVISION_FASE := {
	"Presupuesto": 0, "Masa": 1, "Energía": 1, "Sistemas críticos": 1, "Fiabilidad": 1,
	"Ciencia": 1, "Tránsito": 2, "Operación": 3,
}
## Qué rol responde por cada revisión (para el aporte por jugador en modo equipo).
const REVISION_ROL := {
	"Presupuesto": "Finanzas", "Energía": "Ingeniero", "Masa": "Planificador",
	"Sistemas críticos": "Ingeniero", "Fiabilidad": "Ingeniero",
	"Tránsito": "Astronauta", "Operación": "Astronauta", "Ciencia": "Planificador",
}

class Revision:
	var nombre: String
	var ok: bool
	var puntos: int
	var maximo: int
	var detalle: String
	var critica: bool

	func _init(n: String, o: bool, p: int, m: int, d: String, c: bool) -> void:
		nombre = n; ok = o; puntos = p; maximo = m; detalle = d; critica = c

var revisiones: Array[Revision] = []
var puntaje := 0
var exito := false
var motivos_fallo: Array[String] = []

func evaluar() -> void:
	revisiones.clear()
	motivos_fallo.clear()
	_revisar_presupuesto()
	_revisar_energia()
	_revisar_masa()
	_revisar_sistemas()
	_revisar_fiabilidad()
	_revisar_transito()
	_revisar_operacion()
	_revisar_ciencia()
	_calcular_puntaje()


# Revisiones

func _agregar(nombre: String, ok: bool, puntos: int, maximo: int, detalle: String, critica := false) -> void:
	revisiones.append(Revision.new(nombre, ok, puntos, maximo, detalle, critica))
	if critica and not ok:
		motivos_fallo.append(detalle)


func _revisar_presupuesto() -> void:
	var costo := GameState.costo_total()
	var libre := GameState.presupuesto_max >= GameState.PRESUPUESTO_LIBRE
	var ok := libre or costo <= GameState.presupuesto_max
	var detalle := ""
	if libre:
		detalle = "Presupuesto libre en este nivel: la nave costó %.0f M." % costo
	elif ok:
		detalle = "Gastaste %.0f M de los %.0f M disponibles para la nave." % [costo, GameState.presupuesto_max]
	else:
		detalle = "Te pasaste del presupuesto por %.0f M. La misión no se habría aprobado." % [costo - GameState.presupuesto_max]
	_agregar("Presupuesto", ok, 15 if ok else 0, 15, detalle, true)


func _revisar_energia() -> void:
	var energia := GameState.balance_energia()
	var ok := energia >= 0.0
	var detalle := ""
	if ok:
		detalle = "Balance de +%.0f W: la nave genera más de lo que consume." % energia
	else:
		detalle = "Balance de %.0f W: los sistemas consumen más de lo que generan. La nave se apagó." % energia
	_agregar("Energía", ok, 15 if ok else 0, 15, detalle, true)


func _revisar_masa() -> void:
	var masa := GameState.masa_total()
	var masa_max: float = MASA_MAX.get(GameState.nivel_actual(), 400.0)
	var ok := masa <= masa_max
	var detalle := ""
	if ok:
		detalle = "%.0f kg de %.0f kg permitidos para %s." % [masa, masa_max, GameState.destino]
	else:
		detalle = "%.0f kg supera los %.0f kg que el cohete puede llevar a %s. No alcanzó la órbita." % [masa, masa_max, GameState.destino]
	_agregar("Masa", ok, 10 if ok else 0, 10, detalle, true)


func _revisar_sistemas() -> void:
	var faltan: Array[String] = []
	for cat in SISTEMAS_REQUERIDOS:
		if not tiene_categoria(cat):
			faltan.append(NOMBRE_SISTEMA[cat])
	var presentes := SISTEMAS_REQUERIDOS.size() - faltan.size()
	var puntos := int(round(15.0 * float(presentes) / float(SISTEMAS_REQUERIDOS.size())))
	var detalle := ""
	if faltan.is_empty():
		detalle = "La nave tiene energía, propulsión, comunicación y computadora."
	else:
		detalle = "Faltan sistemas esenciales: %s." % ", ".join(faltan)
	_agregar("Sistemas críticos", faltan.is_empty(), puntos, 15, detalle, true)


func _revisar_fiabilidad() -> void:
	var fiabilidad := calcular_fiabilidad()
	var ok := fiabilidad >= 0.5
	var detalle := "Probabilidad de que ninguna pieza falle: %d%%." % int(round(fiabilidad * 100.0))
	if not ok:
		detalle += " Demasiado riesgo: una pieza falló en tránsito."
	elif fiabilidad < 0.75:
		detalle += " Aceptable, pero piezas más confiables subirían el puntaje."
	_agregar("Fiabilidad", ok, int(round(10.0 * fiabilidad)), 10, detalle, true)


## Fase 3: el viaje (GameState.transito lo escribe la Sala de lanzamiento).
func _revisar_transito() -> void:
	var tr: Dictionary = GameState.transito
	if tr.is_empty():
		_agregar("Tránsito", true, 7, 10, "El lanzamiento no se jugó: se asume un viaje sin incidentes.", false)
		return
	if tr.get("exito", false):
		var integ := float(tr.get("integridad_pct", 100.0))
		var comb := float(tr.get("combustible_pct", 0.0))
		var puntos := int(round(10.0 * clampf(0.6 + 0.4 * integ / 100.0, 0.0, 1.0)))
		var detalle := "Llegó con %d %% de integridad y %d %% de combustible; %d eventos resueltos." % [int(integ), int(comb), GameState.eventos_resueltos.size()]
		_agregar("Tránsito", true, puntos, 10, detalle, true)
	else:
		_agregar("Tránsito", false, 0, 10, "La nave no llegó: %s" % tr.get("motivo", "falló en el tránsito."), true)


## Fase 4: lo que pasó al ejecutar la misión (GameState.operacion lo escribe la Sala de operación).
func _revisar_operacion() -> void:
	var op: Dictionary = GameState.operacion
	if op.is_empty():
		_agregar("Operación", true, 10, 15, "La operación no se jugó: se asume un desempeño medio.", false)
		return
	var exito: bool = op.get("exito", false)
	if exito:
		var detalle := "%s completado en %.0f s" % [op.get("titulo_nivel", "Nivel"), float(op.get("tiempo_s", 0.0))]
		if op.has("combustible_pct"):
			detalle += " con %.0f %% de combustible de reserva" % float(op["combustible_pct"])
		_agregar("Operación", true, 15, 15, detalle + ".", true)
	else:
		_agregar("Operación", false, 0, 15, "La nave falló durante la operación: %s" % op.get("motivo", "no completó la maniobra."), true)


func _revisar_ciencia() -> void:
	var ciencia := calcular_ciencia()
	var fraccion := clampf(ciencia / META_CIENCIA, 0.0, 1.0)
	var detalle := ""
	var op: Dictionary = GameState.operacion
	if op.has("datos_cientificos_pct"):
		# Nivel 3 de la operación (sonda solar) mide directamente cuántos datos se recogieron.
		fraccion = clampf(float(op["datos_cientificos_pct"]) / 100.0, 0.0, 1.0)
		detalle = "La sonda recogió el %.0f %% de los datos científicos previstos." % (fraccion * 100.0)
	elif ciencia > 0.0:
		detalle = "La misión envió %.1f Mbps de datos científicos a la Tierra." % ciencia
	else:
		detalle = "Sin instrumentos: la nave llegó, pero no obtuvo datos científicos."
	var puntos := int(round(10.0 * fraccion))
	_agregar("Ciencia", fraccion > 0.0, puntos, 10, detalle, false)


func _calcular_puntaje() -> void:
	puntaje = 0
	for r in revisiones:
		puntaje += r.puntos
	exito = motivos_fallo.is_empty()
	if not exito:
		puntaje = mini(puntaje, 49)
	puntaje = clampi(puntaje, 0, 100)


# Cálculos auxiliares

func tiene_categoria(cat: String) -> bool:
	for c in GameState.componentes:
		if c.categoria == cat:
			return true
	return false


## Probabilidad de que ninguna pieza falle.
func calcular_fiabilidad() -> float:
	var f := 1.0
	for c in GameState.componentes:
		f *= 1.0 - clampf(c.riesgo_falla, 0.0, 1.0)
	return f


## Datos científicos
func calcular_ciencia() -> float:
	if GameState.datos_cientificos > 0.0:
		return GameState.datos_cientificos
	var total := 0.0
	for c in GameState.componentes:
		total += c.datos_mbps
	return total


func calificacion() -> String:
	if not exito:
		return "Misión fallida"
	if puntaje >= 90:
		return "Misión excelente"
	if puntaje >= 75:
		return "Misión exitosa"
	return "Misión cumplida con problemas"


func estrellas() -> int:
	if not exito:
		return 0
	if puntaje >= 90:
		return 3
	if puntaje >= 75:
		return 2
	return 1


## Explicación por qué funcionó o falló.
func resumen() -> String:
	if not exito:
		return "La misión a %s falló. %s" % [GameState.destino, " ".join(motivos_fallo)]
	var t := "La nave llegó a %s dentro del presupuesto, con energía suficiente y todos los sistemas a bordo." % GameState.destino
	if GameState.ruta != "":
		t += " Ruta: %s." % GameState.ruta
	if not GameState.eventos_resueltos.is_empty():
		t += " Se resolvieron %d eventos durante el viaje." % GameState.eventos_resueltos.size()
	var mejoras: Array[String] = []
	for r in revisiones:
		if r.puntos < r.maximo:
			mejoras.append(r.nombre.to_lower())
	if not mejoras.is_empty():
		t += " Para subir el puntaje mejora: %s." % ", ".join(mejoras)
	return t


## Aporte de cada jugador según sus roles: [{"nombre", "roles", "puntos", "max", "revisiones"}].
func aporte_por_jugador() -> Array:
	# Con reparto de fases (relevos): cada jugador responde por las revisiones de SUS fases.
	if not GameState.asignaciones.is_empty():
		var lista_r: Array = []
		var nombres: Array = GameState.config.get("nombres", [])
		for j in nombres.size():
			var p := 0
			var m := 0
			var revs: Array[String] = []
			var fases: Array[String] = []
			for i in GameState.asignaciones.size():
				if GameState.asignaciones[i] == j:
					fases.append(String(GameState.FASES[i]["nombre"]))
			for r in revisiones:
				var f: int = REVISION_FASE.get(r.nombre, -1)
				if f >= 0 and f < GameState.asignaciones.size() and GameState.asignaciones[f] == j:
					p += r.puntos
					m += r.maximo
					revs.append(r.nombre)
			lista_r.append({"nombre": String(nombres[j]), "roles": fases, "puntos": p, "max": m, "revisiones": revs, "color": GameState.color_jugador(j)})
		return lista_r
	var jugadores: Array = GameState.ficha.get("jugadores", [])
	if jugadores.size() <= 1:
		return []
	var lista: Array = []
	for j in jugadores:
		var p := 0
		var m := 0
		var nombres: Array[String] = []
		for r in revisiones:
			if REVISION_ROL.get(r.nombre, "") in j["roles"]:
				p += r.puntos
				m += r.maximo
				nombres.append(r.nombre)
		lista.append({"nombre": j["nombre"], "roles": j["roles"], "puntos": p, "max": m, "revisiones": nombres})
	return lista
