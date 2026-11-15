extends RefCounted
## Lógica de la Fase 3 (sin interfaz): el tránsito hacia el destino.

const Datos = preload("res://scripts/fase3/fase3_datos.gd")

const ESTADO_LISTO := "listo"          # antes de lanzar
const ESTADO_VIAJANDO := "viajando"
const ESTADO_EVENTO := "evento"        # viaje pausado esperando decisión
const ESTADO_EXITO := "exito"
const ESTADO_FALLO := "fallo"

var estado: String = ESTADO_LISTO
var progreso: float = 0.0        # 0 a 100
var combustible: float = 100.0   # 0 a 100
var integridad: float = 100.0    # 0 a 100
var motivo_fallo: String = ""

var eventos: Array = []          # [{"porcentaje", "nombre", "mensaje", "opcion_a", "opcion_b"}]
var indice_evento: int = 0
var decisiones: Array[String] = []   # "Tormenta solar: Girar la nave..." (va a GameState.eventos_resueltos)

var _ritmo: Dictionary = Datos.RITMO["facil"]


## Prepara el viaje con la partida actual (nivel y ficha de GameState).
func preparar() -> void:
	estado = ESTADO_LISTO
	progreso = 0.0
	combustible = 100.0
	integridad = 100.0
	motivo_fallo = ""
	indice_evento = 0
	decisiones.clear()
	_ritmo = Datos.RITMO.get(GameState.nivel_actual(), Datos.RITMO["facil"])
	eventos = _elegir_eventos(_cantidad_eventos())


func _cantidad_eventos() -> int:
	var n: int = int(GameState.ficha.get("eventos_transito", Datos.EVENTOS_POR_NIVEL.get(GameState.nivel_actual(), 1)))
	return clampi(n, 1, Datos.EVENTOS.size())


## Toma n eventos del catálogo (en orden, como el original) y los reparte a lo largo del viaje.
func _elegir_eventos(n: int) -> Array:
	var lista: Array = []
	for i in n:
		var e: Dictionary = Datos.EVENTOS[i].duplicate(true)
		e["porcentaje"] = int(round(100.0 * float(i + 1) / float(n + 1)))   # 1 evento: 50 %; 2: 33 y 67 %...
		lista.append(e)
	return lista


func lanzar() -> void:
	if estado == ESTADO_LISTO:
		estado = ESTADO_VIAJANDO


## Avanza el viaje.
func avanzar(delta: float) -> String:
	if estado != ESTADO_VIAJANDO:
		return estado
	progreso = minf(progreso + delta * float(_ritmo["progreso"]), 100.0)
	combustible = maxf(combustible - delta * float(_ritmo["combustible"]), 0.0)
	if combustible <= 0.0:
		_fallar("Se agotó el combustible antes de llegar a %s." % GameState.destino)
	elif indice_evento < eventos.size() and progreso >= float(eventos[indice_evento]["porcentaje"]):
		estado = ESTADO_EVENTO
	elif progreso >= 100.0:
		_terminar_exito()
	return estado


func evento_actual() -> Dictionary:
	if indice_evento < eventos.size():
		return eventos[indice_evento]
	return {}


## Aplica la opción elegida ("a" o "b") del evento actual y reanuda el viaje.
func resolver(opcion: String) -> void:
	if estado != ESTADO_EVENTO:
		return
	var e: Dictionary = evento_actual()
	var o: Dictionary = e["opcion_a"] if opcion == "a" else e["opcion_b"]
	combustible = clampf(combustible + float(o["combustible"]), 0.0, 100.0)
	integridad = clampf(integridad + float(o["integridad"]), 0.0, 100.0)
	decisiones.append("%s: %s" % [e["nombre"], o["texto"]])
	indice_evento += 1
	if integridad <= 0.0:
		_fallar("La nave perdió toda su integridad tras «%s»." % e["nombre"])
	elif combustible <= 0.0:
		_fallar("La nave se quedó sin combustible tras «%s»." % e["nombre"])
	else:
		estado = ESTADO_VIAJANDO


func _terminar_exito() -> void:
	estado = ESTADO_EXITO
	_guardar(true)


func _fallar(motivo: String) -> void:
	estado = ESTADO_FALLO
	motivo_fallo = motivo
	_guardar(false)


## Escribe en GameState lo que usan las fases siguientes.
func _guardar(exito: bool) -> void:
	GameState.eventos_resueltos = decisiones.duplicate()
	GameState.transito = {
		"exito": exito,
		"motivo": motivo_fallo,
		"combustible_pct": snappedf(combustible, 0.1),
		"integridad_pct": snappedf(integridad, 0.1),
		"eventos": eventos.size(),
	}


## Revisión previa al lanzamiento (informativa: la Fase 5 es la que califica).
## Cada fila: {"nombre", "valor", "ok"}
func revision_previa() -> Array:
	var filas: Array = []
	var piezas := GameState.componentes.size()
	filas.append({"nombre": "Nave ensamblada", "valor": "%d piezas · %.0f kg" % [piezas, GameState.masa_total()], "ok": piezas > 0})
	filas.append({"nombre": "Balance de energía", "valor": "%+.0f W" % GameState.balance_energia(), "ok": GameState.balance_energia() >= 0.0})
	var ruta := GameState.ruta if GameState.ruta != "" else "sin definir"
	filas.append({"nombre": "Ruta planificada", "valor": ruta, "ok": GameState.ruta != ""})
	filas.append({"nombre": "Eventos previstos en tránsito", "valor": str(eventos.size()), "ok": true})
	return filas
