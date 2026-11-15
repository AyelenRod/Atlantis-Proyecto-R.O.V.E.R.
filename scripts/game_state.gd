extends Node
## Estado global unificado del juego (autoload "GameState").

signal recursos_cambiaron   # cambió la nave (piezas, masa, energía, costo)
signal progreso_cambio      # cambió qué fases están completadas
signal turno_cambio         # multijugador: cambió el jugador al que le toca jugar

## Datos de la Fase 1 (niveles, destinos, rutas, roles, imágenes).
const Datos = preload("res://fase1_datos.gd")
const ROLES = Datos.ROLES
const ORDEN_NIVELES = Datos.ORDEN_NIVELES

const FASES := [
	{"nombre": "1 Planificación", "tarea": "Definir objetivo y ruta", "escena": "res://fase1.tscn"},
	{"nombre": "2 Laboratorio", "tarea": "Ensamblar la nave",   "escena": "res://scenes/fase2_laboratorio.tscn"},
	{"nombre": "3 Lanzamiento", "tarea": "Validar cohete y órbita",   "escena": "res://scenes/fase3_lanzamiento.tscn"},
	{"nombre": "4 Operación", "tarea": "Ejecutar la misión",     "escena": "res://scenes/fase4_operacion.tscn"},
	{"nombre": "5 Resultados", "tarea": "Revisar el reporte",    "escena": "res://scenes/fase5_resultados.tscn"},
]

## Niveles: vienen de fase1_datos.gd (nombre, presupuesto, dias, destinos, ...).
## La Fase 2 (Laboratorio) lee NIVELES[nivel]["presupuesto"] y ["nombre"].
const NIVELES = Datos.NIVELES

## Datos que el Laboratorio guarda como metadatos de este nodo.
## o al cambiar el plan de la Fase 1, para que no queden restos de otra partida.
const META_FASES := ["lab_estado", "lab_resumen", "lab_minijuego"]

## Tope que se usa cuando el nivel tiene presupuesto "libre" (-1), para no limitar el taller.
const PRESUPUESTO_LIBRE := 99999.0

# ---------- Configuración y ficha de misión (Misión Orbital) ----------

## Lo elegido ANTES de entrar a la base: modo, nivel y jugadores.
var config: Dictionary = {}

## La ficha de misión que crea la Fase 1 y que usan las demás fases.
var ficha: Dictionary = {}

## Fase que se está jugando (1..5).
var fase_actual: int = 1

## MULTIJUGADOR (relevos): asignaciones[i] = índice del jugador (en config.nombres) dueño de la fase i.
var asignaciones: Array[int] = []
## true: el reparto de fases entre jugadores se sortea. false: en orden (J1, J2, J3...).
const ASIGNACION_ALEATORIA := true
## Multijugador en red: índice de ESTE dispositivo en config.nombres (lo pone Red). -1 si no es en red.
var mi_indice: int = -1

## Cada jugador tiene un color fijo (según su posición en la lista de nombres).
const COLORES_JUGADOR := [Color("#3b82f6"), Color("#ef4444"), Color("#22c55e"), Color("#a855f7")]
const NOMBRES_COLOR := ["azul", "rojo", "verde", "morado"]
const TRAJE_BASE := Color("#f3f5f8")

# ---------- Progreso y nave (Misión Espacial) ----------

var nivel: String = "facil"
var destino: String = ""
var presupuesto_max: float = 1000.0
## Saldo con el que arranca el taller (presupuesto de la Fase 1 menos la ruta).
var presupuesto_inicial_taller: float = 1000.0
var componentes: Array[ComponentData] = []

# Progreso de la partida
var fases_completadas: Array[bool] = [false, false, false, false, false]
var desbloqueo_libre: bool = false   # modo prueba (tecla F1 en el juego)

# Resultados de las fases (cada fase escribe lo suyo)
var ruta: String = ""
var eventos_resueltos: Array = []
var datos_cientificos: float = 0.0
## Resultado de la Fase 3 (Lanzamiento y tránsito): exito (bool), motivo, combustible_pct,
var transito: Dictionary = {}
## Resultado de la Fase 4 (Operación): métricas del nivel jugado.
var operacion: Dictionary = {}
var puntaje: int = 0


# ---------- Partida (Misión Orbital) ----------

## Llamar desde el menú, justo antes de entrar a la base.
## modo: "solo" | "equipo"   nivel: "facil" | "medio" | "dificil"   nombres: ["Ana", "Luis", ...]
func configurar_partida(modo: String, nivel_id: String, nombres: Array) -> void:
	# Validación: en Fácil siempre se juega solo, aunque el menú o la red pidan otra cosa.
	if modo != "solo" and not nivel_permite_multijugador(nivel_id):
		modo = "solo"
		nombres = nombres.slice(0, 1) if nombres.size() > 0 else ["Jugador 1"]
	config = {"modo": modo, "nivel": nivel_id, "nombres": nombres.duplicate()}
	ficha = {}
	fase_actual = 1
	iniciar_nivel(nivel_id)
	_repartir_fases()


## Guarda la ficha que crea la Fase 1 y vuelca a GameState lo que necesita la Fase 2
## (destino, ruta y saldo del taller).
func guardar_ficha(f: Dictionary) -> void:
	# Si la Fase 1 se repite con OTRO destino o ruta, lo que dependía del plan anterior
	# (nave, presupuesto del taller y fases 2 a 5) ya no sirve: se reinicia.
	var plan_igual: bool = (
		not ficha.is_empty()
		and String(ficha.get("destino", "")) == String(f.get("destino", ""))
		and String(ficha.get("ruta", "")) == String(f.get("ruta", ""))
	)
	ficha = f
	fase_actual = 1
	if plan_igual:
		return
	_limpiar_progreso_posterior()
	destino = String(f.get("destino", ""))
	ruta = String(f.get("ruta", ""))
	var saldo: float = float(f.get("saldo_taller", -1))
	presupuesto_max = saldo if saldo >= 0.0 else PRESUPUESTO_LIBRE
	presupuesto_inicial_taller = presupuesto_max
	recursos_cambiaron.emit()
	progreso_cambio.emit()


## Borra todo lo que dependía de la Fase 1: nave, resultados y fases 2 a 5 (la Fase 1 se conserva).
func _limpiar_progreso_posterior() -> void:
	componentes.clear()
	for i in range(1, fases_completadas.size()):
		fases_completadas[i] = false
	eventos_resueltos.clear()
	datos_cientificos = 0.0
	transito = {}
	operacion = {}
	puntaje = 0
	for clave in META_FASES:
		if has_meta(clave):
			remove_meta(clave)


func presupuesto_libre() -> bool:
	return int(ficha.get("presupuesto", -1)) < 0


func tiempo_ilimitado() -> bool:
	return int(ficha.get("dias_preparacion", -1)) < 0


# ---------- Multijugador (relevos) ----------
## Cada fase tiene UN dueño.
## el turno es del dueño de la primera fase sin completar.
## todos juegan al menos una fase (con 2 jugadores: 3 y 2; con 3: 2, 2 y 1; con 4: 2, 1, 1 y 1).

## El multijugador (equipo o red) solo existe en Medio y Difícil (Datos.NIVELES_EQUIPO).
func nivel_permite_multijugador(id: String) -> bool:
	return Datos.NIVELES_EQUIPO.has(id)


## true en "equipo" (un solo dispositivo, por relevos) y en "red" (cada quien en su dispositivo).
func es_multijugador() -> bool:
	var modo := String(config.get("modo", "solo"))
	return (modo == "equipo" or modo == "red") and Array(config.get("nombres", [])).size() > 1


## Multijugador en red local: cada dispositivo juega solo SUS fases.
func es_red() -> bool:
	return String(config.get("modo", "solo")) == "red" and es_multijugador()


## Reparte las 5 fases en rueda (J1, J2, J3, J1, J2...) con el orden de jugadores sorteado.
func _repartir_fases() -> void:
	asignaciones.clear()
	if not es_multijugador():
		return
	var n: int = Array(config["nombres"]).size()
	var orden: Array[int] = []
	for j in n:
		orden.append(j)
	if ASIGNACION_ALEATORIA:
		orden.shuffle()
	for i in FASES.size():
		asignaciones.append(orden[i % n])
	turno_cambio.emit()


func color_jugador(j: int) -> Color:
	return COLORES_JUGADOR[maxi(j, 0) % COLORES_JUGADOR.size()]


func nombre_color(j: int) -> String:
	return NOMBRES_COLOR[maxi(j, 0) % NOMBRES_COLOR.size()]


## Color del traje del jugador j (el blanco del traje mezclado con su color).
func traje_de(j: int) -> Color:
	return TRAJE_BASE.lerp(color_jugador(j), 0.85)


## Color del astronauta de la base: el del jugador en turno (en red, el de este dispositivo).
## En modo solo, el traje blanco de siempre.
func traje_en_turno() -> Color:
	if not es_multijugador():
		return TRAJE_BASE
	var j := mi_indice if es_red() else jugador_en_turno()
	return TRAJE_BASE if j < 0 else traje_de(j)


func nombre_jugador(j: int) -> String:
	var nombres: Array = config.get("nombres", [])
	if j >= 0 and j < nombres.size():
		return String(nombres[j])
	return "Jugador %d" % (j + 1)


## Nombre del dueño de la fase i ("" en modo solo).
func dueno_de(i: int) -> String:
	if asignaciones.is_empty() or i < 0 or i >= asignaciones.size():
		return ""
	return nombre_jugador(asignaciones[i])


## Fase a la que le toca jugar ahora (la primera sin completar), o -1 si ya están todas.
func fase_en_turno() -> int:
	for i in fases_completadas.size():
		if not fases_completadas[i]:
			return i
	return -1


## Jugador al que le toca el turno (-1 en modo solo o con todo completado).
func jugador_en_turno() -> int:
	var f := fase_en_turno()
	if asignaciones.is_empty() or f == -1:
		return -1
	return asignaciones[f]


## ¿Puede quien tiene el turno abrir esta fase?
func es_fase_del_turno(i: int) -> bool:
	if not es_multijugador() or desbloqueo_libre:
		return true
	if es_red():
		return i < asignaciones.size() and asignaciones[i] == mi_indice
	var j := jugador_en_turno()
	return j == -1 or (i < asignaciones.size() and asignaciones[i] == j)


## La consola se puede usar: la fase está desbloqueada Y es del jugador en turno.
func fase_disponible(i: int) -> bool:
	if not (fase_desbloqueada(i) and es_fase_del_turno(i)):
		return false
	# En red, una fase terminada ya no se reabre: su estado ya se sincronizó con todos.
	if es_red() and not desbloqueo_libre and fases_completadas[i]:
		return false
	return true


# ---------- Sincronización en red ----------
## Foto del estado compartido (solo tipos que viajan por RPC: nada de Resources ni nodos).
func exportar_estado() -> Dictionary:
	var comps: Array = []
	for c in componentes:
		var metas := {}
		for k in c.get_meta_list():
			metas[String(k)] = c.get_meta(k)
		comps.append({
			"id": c.id, "nombre": c.nombre, "categoria": c.categoria,
			"masa_kg": c.masa_kg, "energia_w": c.energia_w, "costo": c.costo,
			"datos_mbps": c.datos_mbps, "riesgo_falla": c.riesgo_falla,
			"descripcion": c.descripcion, "metas": metas,
		})
	var metas_gs := {}
	for clave in META_FASES:
		if has_meta(clave):
			metas_gs[clave] = get_meta(clave)
	var hechas: Array = []
	for b in fases_completadas:
		hechas.append(b)
	return {
		"nivel": nivel, "destino": destino, "ruta": ruta,
		"presupuesto_max": presupuesto_max,
		"presupuesto_inicial_taller": presupuesto_inicial_taller,
		"ficha": ficha, "componentes": comps, "fases_completadas": hechas,
		"eventos_resueltos": eventos_resueltos, "datos_cientificos": datos_cientificos,
		"transito": transito, "operacion": operacion, "puntaje": puntaje,
		"metas": metas_gs,
	}


## Aplica una foto recibida de la red.
func importar_estado(s: Dictionary) -> void:
	nivel = String(s.get("nivel", nivel))
	destino = String(s.get("destino", destino))
	ruta = String(s.get("ruta", ruta))
	presupuesto_max = float(s.get("presupuesto_max", presupuesto_max))
	presupuesto_inicial_taller = float(s.get("presupuesto_inicial_taller", presupuesto_inicial_taller))
	var f: Dictionary = s.get("ficha", {})
	if not f.is_empty():
		ficha = f.duplicate(true)
	componentes.clear()
	var lista: Array = s.get("componentes", [])
	for d in lista:
		var c := ComponentData.new()
		c.id = String(d.get("id", ""))
		c.nombre = String(d.get("nombre", ""))
		c.categoria = String(d.get("categoria", ""))
		c.masa_kg = float(d.get("masa_kg", 0.0))
		c.energia_w = float(d.get("energia_w", 0.0))
		c.costo = float(d.get("costo", 0.0))
		c.datos_mbps = float(d.get("datos_mbps", 0.0))
		c.riesgo_falla = float(d.get("riesgo_falla", 0.0))
		c.descripcion = String(d.get("descripcion", ""))
		var metas: Dictionary = d.get("metas", {})
		for k in metas:
			c.set_meta(k, metas[k])
		componentes.append(c)
	var hechas: Array = s.get("fases_completadas", [])
	for k in mini(hechas.size(), fases_completadas.size()):
		if hechas[k]:
			fases_completadas[k] = true   # solo se agregan fases hechas, nunca se quitan
	var ev: Array = s.get("eventos_resueltos", [])
	eventos_resueltos = ev.duplicate()
	datos_cientificos = float(s.get("datos_cientificos", datos_cientificos))
	var t: Dictionary = s.get("transito", {})
	transito = t.duplicate(true)
	var o: Dictionary = s.get("operacion", {})
	operacion = o.duplicate(true)
	puntaje = int(s.get("puntaje", puntaje))
	var metas_gs: Dictionary = s.get("metas", {})
	for clave in META_FASES:
		if metas_gs.has(clave):
			set_meta(clave, metas_gs[clave])
		elif has_meta(clave):
			remove_meta(clave)
	recursos_cambiaron.emit()
	progreso_cambio.emit()
	turno_cambio.emit()


# ---------- Progreso de fases (Misión Espacial) ----------

## Dificultad real de la partida.
## se usa lo elegido en el menú y, como último recurso, el nivel interno.
func nivel_actual() -> String:
	var id := String(ficha.get("nivel", ""))
	if id == "":
		id = String(config.get("nivel", ""))
	if id == "":
		id = nivel
	if not NIVELES.has(id):
		id = "facil"
	return id


## Arranca una partida nueva en el nivel elegido.
## y de emitir las señales, para que ninguna interfaz se refresque con "fácil" por error.
func iniciar_nivel(id: String) -> void:
	nivel = id
	config["nivel"] = id
	_limpiar_partida()
	destino = ""   # lo define la Fase 1
	presupuesto_max = PRESUPUESTO_LIBRE   # provisional hasta confirmar la Fase 1
	presupuesto_inicial_taller = presupuesto_max
	recursos_cambiaron.emit()
	progreso_cambio.emit()


func _limpiar_partida() -> void:
	destino = ""
	presupuesto_max = PRESUPUESTO_LIBRE
	presupuesto_inicial_taller = PRESUPUESTO_LIBRE
	componentes.clear()
	fases_completadas.fill(false)
	ruta = ""
	eventos_resueltos.clear()
	datos_cientificos = 0.0
	transito = {}
	operacion = {}
	puntaje = 0
	for clave in META_FASES:
		if has_meta(clave):
			remove_meta(clave)


## Vuelve todo al estado inicial (al terminar la misión).
func reiniciar() -> void:
	nivel = "facil"
	ficha = {}
	fase_actual = 1
	asignaciones.clear()
	_limpiar_partida()
	recursos_cambiaron.emit()
	progreso_cambio.emit()


func completar_fase(i: int) -> void:
	fases_completadas[i] = true
	progreso_cambio.emit()
	turno_cambio.emit()


## Una fase se desbloquea al completar la anterior (o en modo prueba).
func fase_desbloqueada(i: int) -> bool:
	return desbloqueo_libre or i == 0 or fases_completadas[i - 1]


func todas_completas() -> bool:
	return not fases_completadas.has(false)


func fases_hechas() -> int:
	return fases_completadas.count(true)


# ---------- Nave ----------

func agregar(c: ComponentData) -> bool:
	if costo_total() + c.costo > presupuesto_max:
		return false
	componentes.append(c)
	recursos_cambiaron.emit()
	return true


func quitar(c: ComponentData) -> void:
	componentes.erase(c)
	recursos_cambiaron.emit()


func masa_total() -> float:
	return componentes.reduce(func(a, c): return a + c.masa_kg, 0.0)


func balance_energia() -> float:
	return componentes.reduce(func(a, c): return a + c.energia_w, 0.0)


func costo_total() -> float:
	return componentes.reduce(func(a, c): return a + c.costo, 0.0)


func es_valida() -> bool:
	return balance_energia() >= 0.0 and costo_total() <= presupuesto_max
