# Autoload "Phase4Manager": coordina la Fase 4 (Operación).
extends Node

signal estado_actualizado
signal nivel_completado(nivel: int, metricas: Dictionary)
signal mision_fallida(nivel: int, motivo: String, metricas: Dictionary)

const SCRIPTS_NIVELES := {
	1: "res://phase4/nivel1_orbita.gd",
	2: "res://phase4/nivel2_aterrizaje.gd",
	3: "res://phase4/nivel3_sonda_solar.gd",
}

const PERFILES_NAVE := {
	"debil": {
		"nombre": "Cápsula Ligera Mk-I",
		"empuje": 220.0,
		"rotacion_vel": 2.4,
		"combustible_max": 85.0,
		"escudo_max": 1250.0,
		"tolerancia_aterrizaje": 3.8,
	},
	"media": {
		"nombre": "Orbiter Estándar Mk-II",
		"empuje": 280.0,
		"rotacion_vel": 2.9,
		"combustible_max": 100.0,
		"escudo_max": 1550.0,
		"tolerancia_aterrizaje": 4.6,
	},
	"fuerte": {
		"nombre": "Crucero Solar Mk-III",
		"empuje": 340.0,
		"rotacion_vel": 3.4,
		"combustible_max": 125.0,
		"escudo_max": 1900.0,
		"tolerancia_aterrizaje": 5.5,
	},
}

var nivel_actual: int = 1
var tipo_nave: String = "media"

# Ramificaciones seleccionables por el jugador en Fase 4 (o heredadas de GameState.ficha)
var destino_nivel2: String = "luna"        # "luna" | "marte"
var destino_nivel3: String = "sonda_solar" # "sonda_solar" | "jupiter"

var resultado_final_ganado: bool = false
var motivo_ultimo_fallo: String = ""
var ultima_metrica: Dictionary = {}
var historial_niveles: Dictionary = {}


func _ready() -> void:
	_registrar_controles()
	_sincronizar_con_game_state()


func _registrar_controles() -> void:
	var mapa := {
		"p4_izquierda": [KEY_LEFT, KEY_A],
		"p4_derecha": [KEY_RIGHT, KEY_D],
		"p4_arriba": [KEY_UP, KEY_W],
		"p4_abajo": [KEY_DOWN, KEY_S],
		"p4_accion": [KEY_SPACE, KEY_E],
		"p4_medir": [KEY_F, KEY_ENTER],
	}
	for accion in mapa.keys():
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
		for tecla in mapa[accion]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			if not InputMap.action_has_event(accion, ev):
				InputMap.action_add_event(accion, ev)


func _sincronizar_con_game_state() -> void:
	if not has_node("/root/GameState"):
		return
	var gs := get_node("/root/GameState")
	if "ficha" in gs and typeof(gs.ficha) == TYPE_DICTIONARY:
		var f: Dictionary = gs.ficha
		match str(gs.nivel_actual()):
			"facil":
				nivel_actual = 1
			"medio":
				nivel_actual = 2
			"dificil":
				nivel_actual = 3

		var dest := str(f.get("destino", "")).to_lower()
		if "luna" in dest:
			destino_nivel2 = "luna"
		elif "marte" in dest:
			destino_nivel2 = "marte"
		elif "júpiter" in dest or "jupiter" in dest:
			destino_nivel3 = "jupiter"
		elif "solar" in dest:
			destino_nivel3 = "sonda_solar"
	elegir_perfil_por_nave()


## Elige el perfil de nave según lo armado en el Laboratorio (piezas de propulsión).
## Sin nave (fase no jugada) se queda el perfil "media".
func elegir_perfil_por_nave() -> void:
	if not has_node("/root/GameState"):
		return
	var gs := get_node("/root/GameState")
	if gs.componentes.is_empty():
		return
	var motores := 0
	for c in gs.componentes:
		if c.categoria == "propulsion":
			motores += 1
	tipo_nave = "debil" if motores == 0 else ("media" if motores == 1 else "fuerte")


## Controles del nivel según la ramificación activa: lista de [teclas, acción].
func controles_nivel(n: int) -> Array:
	match n:
		1:
			return [
				["← →  /  A D", "Girar la nave"],
				["↑  /  W", "Empuje hacia adelante"],
				["↓  /  S", "Retro-empuje para frenar"],
				["Espacio / E (mantener)", "Abrir la cofia dentro de la ventana verde y liberar el satélite"],
			]
		2:
			if destino_nivel2 == "luna":
				return [
					["Espacio / E", "Iniciar la secuencia de frenado"],
					["← →  /  A D", "Inclinar la nave durante el descenso"],
					["↑  /  W (mantener)", "Retrocohetes: frenar la caída"],
					["← →  (ya en el suelo)", "Mover el escáner por la superficie"],
					["F / Espacio (mantener)", "Escanear cada muestra científica (3 en total)"],
				]
			return [
				["Espacio / E", "Abrir el paracaídas"],
				["← →  /  A D", "Inclinar la nave durante el descenso"],
				["↑  /  W (mantener)", "Retrocohetes: frenar la caída"],
				["Espacio / E (ya en el suelo)", "Desplegar la rampa del rover"],
				["← →  /  A D", "Conducir el rover"],
				["↑  /  W", "Saltar las rocas con el rover"],
				["F / Espacio (en la baliza)", "Transmitir los datos"],
			]
		_:
			if destino_nivel3 == "jupiter":
				return [
					["Flechas  /  WASD", "Maniobrar entre los asteroides"],
					["F / Espacio (mantener)", "Escanear las lunas: Ío, Europa y Ganímedes"],
				]
			return [
				["↑ ↓  /  W S", "Acercar o alejar la trayectoria del Sol"],
				["← →  /  A D", "Orientar el escudo térmico hacia el Sol"],
				["F / Espacio (mantener)", "Medir plasma y viento solar (solo con el escudo bien orientado)"],
			]


## Título y descripción del nivel según la ramificación activa (para la pantalla de inicio del hub).
func info_nivel(n: int) -> Dictionary:
	match n:
		1:
			return {"titulo": "Nivel 1 — Órbita terrestre (despliegue de satélite)",
				"resumen": "Alinea la nave con la ventana orbital usando las flechas y mantén ESPACIO/E en la zona verde para abrir la cofia y liberar el satélite.",
				"detalles": "Controles: Flechas/WASD + Espacio/E  ·  Objetivo: precisión angular ≤ 8°"}
		2:
			if destino_nivel2 == "luna":
				return {"titulo": "Nivel 2 — Luna (aterrizaje + ciencia en superficie)",
					"resumen": "Frena con los retrocohetes hasta posar la nave y luego escanea 3 muestras científicas en la superficie lunar.",
					"detalles": "Controles: Flechas (retrocohetes y escáner) + Espacio/E  ·  Objetivo: aterrizar suave y 100 % de muestras"}
			return {"titulo": "Nivel 2 — Marte (aterrizaje + rover)",
				"resumen": "Despliega el paracaídas con ESPACIO, frena con los retrocohetes y luego lanza y conduce el rover hasta la baliza.",
				"detalles": "Controles: Espacio (paracaídas/rampa) + Flechas  ·  Objetivo: velocidad de impacto baja y rover en la baliza"}
		_:
			if destino_nivel3 == "jupiter":
				return {"titulo": "Nivel 3 — Júpiter (asteroides + lunas galileanas)",
					"resumen": "Esquiva asteroides y escanea Ío, Europa y Ganímedes mientras orbitas el gigante gaseoso.",
					"detalles": "Controles: Flechas (maniobrar) + F/Espacio (escanear)  ·  Objetivo: 3 lunas escaneadas"}
			return {"titulo": "Nivel 3 — Sonda solar (resistencia extrema)",
				"resumen": "Mantén el escudo térmico orientado al Sol mientras recolectas plasma y viento solar con F o ESPACIO.",
				"detalles": "Controles: Flechas (orientar escudo) + F/Espacio (medir)  ·  Objetivo: 100 % de datos científicos"}


func obtener_perfil_nave() -> Dictionary:
	return PERFILES_NAVE.get(tipo_nave, PERFILES_NAVE["media"])


func establecer_tipo_nave(nuevo_tipo: String) -> void:
	if PERFILES_NAVE.has(nuevo_tipo):
		tipo_nave = nuevo_tipo
		estado_actualizado.emit()


func establecer_destino_nivel2(destino: String) -> void:
	if destino in ["luna", "marte"]:
		destino_nivel2 = destino
		estado_actualizado.emit()


func establecer_destino_nivel3(destino: String) -> void:
	if destino in ["sonda_solar", "jupiter"]:
		destino_nivel3 = destino
		estado_actualizado.emit()


func rotar_tipo_nave() -> String:
	var orden := ["debil", "media", "fuerte"]
	var idx := (orden.find(tipo_nave) + 1) % orden.size()
	tipo_nave = orden[idx]
	estado_actualizado.emit()
	return tipo_nave


func iniciar_nivel(nivel: int) -> void:
	nivel_actual = clampi(nivel, 1, 3)
	motivo_ultimo_fallo = ""


func crear_nivel() -> Node2D:
	var n := Node2D.new()
	n.name = "Nivel%d" % nivel_actual
	n.set_script(load(SCRIPTS_NIVELES[nivel_actual]))
	return n


func completar_nivel(metricas: Dictionary) -> void:
	resultado_final_ganado = true
	motivo_ultimo_fallo = ""
	ultima_metrica = metricas.duplicate(true)
	ultima_metrica["nivel"] = nivel_actual
	ultima_metrica["exito"] = true
	ultima_metrica["nave"] = str(obtener_perfil_nave().get("nombre", "Estándar"))
	historial_niveles[nivel_actual] = ultima_metrica
	nivel_completado.emit(nivel_actual, ultima_metrica)


func fallar_mision(motivo: String, metricas: Dictionary) -> void:
	resultado_final_ganado = false
	motivo_ultimo_fallo = motivo
	ultima_metrica = metricas.duplicate(true)
	ultima_metrica["nivel"] = nivel_actual
	ultima_metrica["exito"] = false
	ultima_metrica["motivo"] = motivo
	ultima_metrica["nave"] = str(obtener_perfil_nave().get("nombre", "Estándar"))
	historial_niveles[nivel_actual] = ultima_metrica
	mision_fallida.emit(nivel_actual, motivo, ultima_metrica)
