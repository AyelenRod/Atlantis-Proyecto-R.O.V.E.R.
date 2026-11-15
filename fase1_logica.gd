extends RefCounted
## Lógica de la Fase 1 (sin interfaz): sala de planificación.

const Datos = preload("res://fase1_datos.gd")

const PASO_OBJETIVO := 0
const PASO_RUTA := 1
const PASO_REQUISITOS := 2
const ULTIMO_PASO := 2

const OK := "ok"
const FALLA := "falla"
const INFO := "info"

var paso: int = PASO_OBJETIVO
var modo: String = "solo"            # "solo" | "equipo"   (ya elegido)
var nivel_id: String = ""            # "facil" | "medio" | "dificil"   (ya elegido)
var nombres: Array = []              # nombres de los jugadores (ya elegidos)
var destino: String = ""             # elegido en el paso OBJETIVO
var ruta: String = ""                # elegida en el paso RUTA


# ---------------------------------------------------------------- configuración previa

## Lee lo que eligió el menú anterior.
func cargar_config() -> bool:
	var c: Dictionary = GameState.config
	if c.is_empty() or not Datos.NIVELES.has(c.get("nivel", "")):
		return false
	modo = c.get("modo", "solo")
	nivel_id = c["nivel"]
	nombres = Array(c.get("nombres", [])).duplicate()
	return true


## Para probar la escena sola: simula la configuración de Datos.PRUEBA_ACTIVA.
func usar_prueba(clave: String = Datos.PRUEBA_ACTIVA) -> bool:
	if not Datos.PRUEBAS.has(clave):
		return false
	var p: Dictionary = Datos.PRUEBAS[clave]
	GameState.configurar_partida(p["modo"], p["nivel"], p["nombres"])
	return cargar_config()


# ---------------------------------------------------------------- navegación y elecciones

func ir_a(p: int) -> void:
	paso = clampi(p, PASO_OBJETIVO, ULTIMO_PASO)


func elegir_destino(d: String) -> void:
	if d != destino:
		ruta = ""
	destino = d
	ir_a(PASO_RUTA)


func elegir_ruta(r: String) -> void:
	ruta = r
	ir_a(PASO_REQUISITOS)


# ---------------------------------------------------------------- consultas

func nivel() -> Dictionary:
	return Datos.NIVELES[nivel_id]


func destinos_del_nivel() -> Dictionary:
	return Datos.NIVELES[nivel_id]["destinos"]


func rutas_del_destino() -> Dictionary:
	return Datos.RUTAS.get(destino, {})


func texto_contexto() -> String:
	var n: Dictionary = nivel()
	var quienes := "Solo" if modo == "solo" else "Equipo de %d" % nombres.size()
	var pres: String = n["txt_presupuesto"]
	if n["presupuesto"] >= 0:
		pres = "%d millones" % n["presupuesto"]
	var dias: String = n["txt_tiempo"]
	if n["dias"] >= 0:
		dias = "%d días" % n["dias"]
	return "Nivel: %s  ·  %s  ·  Presupuesto: %s  ·  Preparación: %s" % [n["nombre"], quienes, pres, dias]


## Devuelve "" si la ruta cabe en el presupuesto y el tiempo del nivel, o el motivo por el que no cabe.
func motivo_excede(r: Dictionary) -> String:
	return motivo_excede_en(nivel(), r)


static func motivo_excede_en(n: Dictionary, r: Dictionary) -> String:
	var motivos: Array = []
	if n["presupuesto"] >= 0 and r["costo"] > n["presupuesto"]:
		motivos.append("presupuesto")
	if n["dias"] >= 0 and r["dias"] > n["dias"]:
		motivos.append("tiempo de preparación")
	return " y ".join(motivos)


func presupuesto_libre() -> bool:
	return nivel()["presupuesto"] < 0


## Saldo del presupuesto tras pagar la ruta (-1 si el presupuesto es libre).
func saldo_restante() -> int:
	var pres: int = nivel()["presupuesto"]
	if pres < 0:
		return -1
	return pres - rutas_del_destino()[ruta]["costo"]


## Filas de la tabla de requisitos del nivel contra la ruta elegida.
## Cada fila: {"nombre", "limite", "plan", "estado"} con estado OK, FALLA o INFO.
func requisitos() -> Array:
	var n: Dictionary = nivel()
	var r: Dictionary = rutas_del_destino()[ruta]
	var filas: Array = []

	var pres: int = n["presupuesto"]
	filas.append({
		"nombre": "Presupuesto",
		"limite": n["txt_presupuesto"] if pres < 0 else "Máx. %d millones" % pres,
		"plan": "%d millones" % r["costo"],
		"estado": OK if (pres < 0 or r["costo"] <= pres) else FALLA,
	})

	var dias: int = n["dias"]
	filas.append({
		"nombre": "Tiempo de preparación",
		"limite": n["txt_tiempo"] if dias < 0 else "Máx. %d días" % dias,
		"plan": "%d días" % r["dias"],
		"estado": OK if (dias < 0 or r["dias"] <= dias) else FALLA,
	})

	filas.append({"nombre": "Información", "limite": n["txt_info"], "plan": "Se investiga en el Laboratorio", "estado": INFO})
	filas.append({"nombre": "Eventos de tránsito", "limite": n["txt_eventos"], "plan": "Ocurren en la Fase 3", "estado": INFO})
	return filas


func cumple_requisitos() -> bool:
	for f in requisitos():
		if f["estado"] == FALLA:
			return false
	return true


## Avance de la barra de progreso (0.0 a 1.0) según la fase y el paso actual.
func avance_total() -> float:
	var fase: int = GameState.fase_actual
	var dentro := (float(paso) / float(ULTIMO_PASO)) if fase == 1 else 0.0
	return (float(fase - 1) + dentro) / float(Datos.FASES.size())


# ---------------------------------------------------------------- ficha de misión

## Construye la ficha de misión (config previa + lo elegido aquí).
func crear_ficha(guardar: bool = true) -> Dictionary:
	var n: Dictionary = nivel()
	var r: Dictionary = rutas_del_destino()[ruta]
	var total := maxi(nombres.size(), 1)
	var jugadores: Array = []
	for i in total:
		var nom: String = String(nombres[i]).strip_edges() if i < nombres.size() else ""
		if nom == "":
			nom = "Jugador %d" % (i + 1)
		jugadores.append({"nombre": nom, "roles": roles_de(i, total)})
	var f := {
		"modo": modo,
		"nivel": nivel_id,
		"nivel_nombre": n["nombre"],
		"destino": destino,
		"objetivo": n["destinos"][destino]["objetivo"],
		"ruta": ruta,                               # nombre de la ruta elegida
		"ruta_desc": r["desc"],
		"costo_ruta": r["costo"],                   # millones
		"dias_ruta": r["dias"],                     # días de preparación que exige la ruta
		"saldo_taller": saldo_restante(),           # presupuesto - costo_ruta (-1 = libre)
		"fases": Datos.FASES.duplicate(),
		"presupuesto": n["presupuesto"],            # -1 = libre
		"dias_preparacion": n["dias"],              # -1 = ilimitado
		"info_oculta": n["info_oculta"],            # 0.0 a 1.0
		"eventos_transito": n["eventos"],
		"txt_presupuesto": n["txt_presupuesto"],
		"txt_info": n["txt_info"],
		"txt_eventos": n["txt_eventos"],
		"txt_tiempo": n["txt_tiempo"],
		"jugadores": jugadores,                     # [{"nombre": String, "roles": Array}]
	}
	if guardar:
		GameState.guardar_ficha(f)
	return f


## Reparte los 4 roles entre n jugadores: el rol j le toca al jugador (j % n).
func roles_de(i: int, n: int) -> Array:
	var r: Array = []
	for j in Datos.ROLES.size():
		if j % n == i:
			r.append(Datos.ROLES[j])
	return r


# ---------------------------------------------------------------- autoprueba

## Revisa que los datos estén bien escritos (niveles, destinos, rutas y pruebas).
## Devuelve la lista de errores (vacía si todo está bien).
func autoprueba() -> Array:
	var errores: Array = []
	for nid in Datos.ORDEN_NIVELES:
		var n: Dictionary = Datos.NIVELES[nid]
		for d in n["destinos"].keys():
			if not Datos.RUTAS.has(d) or Datos.RUTAS[d].is_empty():
				errores.append("El destino '%s' (nivel %s) no tiene rutas en RUTAS." % [d, nid])
				continue
			var alguna_cabe := false
			for rn in Datos.RUTAS[d].keys():
				var r: Dictionary = Datos.RUTAS[d][rn]
				for campo in ["desc", "costo", "dias", "viaje", "dv", "riesgo", "nota"]:
					if not r.has(campo):
						errores.append("La ruta '%s' de '%s' no tiene el campo '%s' (el Laboratorio lo necesita)." % [rn, d, campo])
				if not (r.has("costo") and r.has("dias")):
					continue
				if motivo_excede_en(n, r) == "":
					alguna_cabe = true
			if not alguna_cabe:
				errores.append("Ninguna ruta de '%s' cabe en los límites del nivel %s (sería imposible de ganar)." % [d, nid])
	for clave in Datos.PRUEBAS.keys():
		var p: Dictionary = Datos.PRUEBAS[clave]
		if not Datos.NIVELES.has(p["nivel"]):
			errores.append("Prueba '%s': el nivel '%s' no existe." % [clave, p["nivel"]])
	if not Datos.PRUEBAS.has(Datos.PRUEBA_ACTIVA):
		errores.append("PRUEBA_ACTIVA ('%s') no existe en PRUEBAS." % Datos.PRUEBA_ACTIVA)
	return errores
