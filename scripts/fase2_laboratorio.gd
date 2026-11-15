extends PhaseBase
const FondoEspacial = preload("res://fondo_espacial.gd")
const Datos = preload("res://fase1_datos.gd")   # rutas y niveles: fuente única (Fase 1)
const ESCENA_FONDO_3D := preload("res://phase4/fondo_orbital.tscn")
var _astro_vista_3d: MeshInstance3D = null
const COL_FONDO := Color(0.04, 0.04, 0.11)
const COL_PANEL := Color(0.08, 0.08, 0.19)
const COL_FILA := Color(0.12, 0.12, 0.27)
const COL_FILA_SEL := Color(0.16, 0.3, 0.2)
const COL_OK := Color(0.5, 1.0, 0.6)
const COL_MAL := Color(1.0, 0.45, 0.45)
const COL_AVISO := Color(1.0, 0.82, 0.35)
const COL_SUAVE := Color(0.72, 0.77, 0.92)
const E_ARCHIVO := 0
const E_PRESUPUESTO := 1
const E_TALLER := 2
const E_SIMULADOR := 3
const E_MAPA := 4
const ESTACIONES := [
	{"nombre": "Archivo de misión", "dias": 0},
	{"nombre": "Oficina de presupuesto", "dias": 0},
	{"nombre": "Taller de ingeniería", "dias": 0},
	{"nombre": "Simulador de pruebas", "dias": 0},
	{"nombre": "Mapa de rutas", "dias": 0},
]
# Respaldo: si no hay ficha de la Fase 1 (laboratorio abierto solo con F6) se usan los días del nivel.
const DIAS_NIVEL := {"facil": -1, "medio": 10, "dificil": 7}
const MAX_PRUEBAS := 2          # pruebas por pieza
const MAX_NEGOCIACIONES := 2    # intentos en la oficina de presupuesto
const CATEGORIAS := ["estructura", "energia", "comunicacion", "computadora", "propulsion", "termico", "instrumento"]
const CAT_NOMBRE := {
	"estructura": "Estructura",
	"energia": "Energía",
	"comunicacion": "Comunicaciones",
	"computadora": "Computadora de a bordo",
	"propulsion": "Propulsión",
	"termico": "Control térmico",
	"instrumento": "Instrumento científico",
	"blindaje": "Protección contra radiación",
}
# ----- colores para la parte visual -----
const CAT_COL := {
	"estructura": Color(0.65, 0.7, 0.85),
	"energia": Color(1.0, 0.85, 0.3),
	"comunicacion": Color(0.4, 0.8, 1.0),
	"computadora": Color(0.6, 1.0, 0.7),
	"propulsion": Color(1.0, 0.55, 0.35),
	"termico": Color(1.0, 0.45, 0.55),
	"instrumento": Color(0.8, 0.6, 1.0),
}
const ESTACION_COL := [
	Color(0.45, 0.7, 1.0),
	Color(1.0, 0.82, 0.35),
	Color(0.5, 1.0, 0.6),
	Color(1.0, 0.55, 0.45),
	Color(0.75, 0.6, 1.0),
]
const OPC_NIVEL := {
	"facil": ["tierra"],
	"medio": ["luna", "marte"],
	"dificil": ["sol", "jupiter"],
}
const DESTINOS := {
	"tierra": {
		"nombre": "Órbita terrestre", "palabras": ["terrestre"],
		"solar": 1.0, "enlace": 1.0, "masa_max": 80,
		"distancia": "300 a 36 000 km", "luz": "100 % de la luz solar",
		"retardo": "menos de 0.2 segundos",
		"entorno": "Eclipses frecuentes y radiación baja.",
		"req": ["estructura", "energia", "computadora", "comunicacion", "instrumento"],
	},
	"luna": {
		"nombre": "Luna", "palabras": ["luna"],
		"solar": 1.0, "enlace": 0.7, "masa_max": 150,
		"distancia": "384 000 km", "luz": "100 % (pero 14 días de noche en la superficie)",
		"retardo": "1.3 segundos",
		"entorno": "Sin atmósfera, polvo y cambios bruscos de temperatura.",
		"req": ["estructura", "energia", "computadora", "comunicacion", "instrumento", "propulsion"],
	},
	"marte": {
		"nombre": "Marte", "palabras": ["marte"],
		"solar": 0.43, "enlace": 0.25, "masa_max": 180,
		"distancia": "55 a 400 millones de km", "luz": "43 % de la luz solar",
		"retardo": "3 a 22 minutos",
		"entorno": "Atmósfera delgada, polvo y frío intenso.",
		"req": ["estructura", "energia", "computadora", "comunicacion", "instrumento", "propulsion"],
	},
	"sol": {
		"nombre": "Órbita solar", "palabras": ["solar"],
		"solar": 2.5, "enlace": 0.3, "masa_max": 200,
		"distancia": "cerca de 0.3 UA del Sol", "luz": "mucho mayor que en la Tierra",
		"retardo": "3 a 20 minutos",
		"entorno": "Calor extremo y radiación intensa.",
		"req": ["estructura", "energia", "computadora", "comunicacion", "instrumento", "propulsion", "termico"],
	},
	"jupiter": {
		"nombre": "Júpiter", "palabras": ["júpiter", "jupiter"],
		"solar": 0.04, "enlace": 0.12, "masa_max": 220,
		"distancia": "590 a 970 millones de km", "luz": "4 % de la luz solar",
		"retardo": "35 a 52 minutos",
		"entorno": "Cinturón de radiación extremo.",
		"req": ["estructura", "energia", "computadora", "comunicacion", "instrumento", "propulsion", "blindaje"],
	},
}
const DEST_COL := {
	"tierra": Color(0.2, 0.5, 1.0),
	"luna": Color(0.8, 0.8, 0.82),
	"marte": Color(0.85, 0.4, 0.25),
	"sol": Color(1.0, 0.8, 0.3),
	"jupiter": Color(0.85, 0.7, 0.5),
}
const PREGUNTAS := {
	"tierra": [
		{"p": "¿Por qué una nave en órbita baja necesita baterías?",
			"o": ["Pasa por la sombra de la Tierra", "En el espacio no hay Sol", "Para aumentar su masa"], "c": 0,
			"e": "En órbita baja entra en sombra (eclipse) unas 16 veces al día. Las baterías mantienen todo encendido sin Sol.",
			"cat": "energia"},
		{"p": "Una cámara genera muchos más datos que un magnetómetro. ¿Qué debe crecer para no perderlos?",
			"o": ["La estructura", "Las comunicaciones", "El panel solar"], "c": 1,
			"e": "Los datos solo sirven si llegan a la Tierra: la antena fija cuántos Mbps puedes enviar.",
			"cat": "comunicacion"},
		{"p": "Subir de una órbita baja a una geoestacionaria requiere...",
			"o": ["Más Δv (combustible)", "Menos masa", "Nada especial"], "c": 0,
			"e": "Cambiar de órbita cuesta velocidad (Δv). Más Δv significa más propulsión y más masa.",
			"cat": "propulsion"},
	],
	"luna": [
		{"p": "¿Cuánto tarda una señal de radio en llegar a la Luna?",
			"o": ["Unos 1.3 segundos", "Unos 20 minutos", "Es instantánea"], "c": 0,
			"e": "La Luna está a 384 000 km y la luz viaja a 300 000 km/s: casi un segundo y medio.",
			"cat": "comunicacion"},
		{"p": "En la noche lunar (14 días) los paneles no generan. ¿Qué ayuda?",
			"o": ["Baterías grandes o un RTG", "Más cámaras", "Una antena mayor"], "c": 0,
			"e": "Sin Sol, solo las baterías o una fuente como el RTG mantienen vivos los sistemas.",
			"cat": "energia"},
		{"p": "La ruta de baja energía a la Luna...",
			"o": ["Gasta menos Δv pero tarda más", "Es más rápida", "Gasta más Δv"], "c": 0,
			"e": "Aprovecha la gravedad de la Tierra y el Sol: ahorra combustible, pero tarda meses.",
			"cat": "propulsion"},
	],
	"marte": [
		{"p": "A Marte llega ~43 % de la luz solar. Esto implica...",
			"o": ["Paneles más grandes o un RTG", "Paneles que rinden más", "Nada"], "c": 0,
			"e": "Con menos luz, cada panel genera menos: hay que compensar o usar energía nuclear.",
			"cat": "energia"},
		{"p": "La señal Tierra-Marte tarda de 3 a 22 minutos. Por eso la nave...",
			"o": ["Debe ser autónoma", "Se maneja con joystick", "No necesita computadora"], "c": 0,
			"e": "No se puede controlar en tiempo real: la computadora de a bordo decide sola.",
			"cat": "computadora"},
		{"p": "¿Por qué la transferencia Hohmann gasta menos combustible?",
			"o": ["Aprovecha la posición de los planetas", "Va en línea recta", "Usa menos masa"], "c": 0,
			"e": "Es la órbita de menor energía entre dos planetas, aunque tarda unos 9 meses.",
			"cat": "propulsion"},
	],
	"sol": [
		{"p": "El mayor enemigo cerca del Sol es...",
			"o": ["El calor", "El frío", "La falta de luz"], "c": 0,
			"e": "La temperatura sube muchísimo: se necesita un escudo térmico.",
			"cat": "termico"},
		{"p": "Más cerca del Sol, la energía solar disponible...",
			"o": ["Aumenta, pero el calor limita", "Disminuye", "No cambia"], "c": 0,
			"e": "Hay más luz, pero los paneles se sobrecalientan y pierden eficiencia.",
			"cat": "energia"},
		{"p": "¿Por qué usar asistencias de Venus para acercarse al Sol?",
			"o": ["Frenan la nave con poco combustible", "Dan más luz", "Cargan las baterías"], "c": 0,
			"e": "Para caer hacia el Sol hay que perder velocidad orbital; Venus ayuda a hacerlo.",
			"cat": "propulsion"},
	],
	"jupiter": [
		{"p": "A Júpiter llega ~4 % de la luz solar. ¿Qué energía conviene?",
			"o": ["Baterías cargadas en la Tierra", "RTG o paneles gigantes", "Combustible líquido"], "c": 1,
			"e": "Con tan poca luz, los paneles normales no bastan: se usa un RTG o paneles enormes.",
			"cat": "energia"},
		{"p": "La radiación de Júpiter daña la electrónica. ¿Qué ayuda?",
			"o": ["Computadora tolerante y blindaje", "Una antena mayor", "Más cámaras"], "c": 0,
			"e": "La radiación daña los chips; por eso se usan computadoras tolerantes y blindaje.",
			"cat": "computadora"},
		{"p": "Una asistencia gravitatoria sirve para...",
			"o": ["Ganar velocidad sin combustible", "Frenar con atmósfera", "Recargar baterías"], "c": 0,
			"e": "La nave toma un poco de velocidad del planeta al pasar cerca.",
			"cat": "propulsion"},
	],
}
const CATALOGO := [
	{"id": "est_cubesat", "n": "Estructura CubeSat 6U", "cat": "estructura", "m": 8, "e": -2, "c": 30, "r": 0.03,
		"desc": "Caja pequeña y ligera. Ideal para misiones cerca de la Tierra."},
	{"id": "est_media", "n": "Estructura de aluminio", "cat": "estructura", "m": 40, "e": -4, "c": 50, "r": 0.04,
		"desc": "Estructura robusta de uso general para el espacio profundo."},
	{"id": "est_blindada", "n": "Estructura blindada", "cat": "estructura", "m": 70, "e": -6, "c": 110, "r": 0.03,
		"rad": true, "adv": true, "desc": "Protege la electrónica de la radiación, pero pesa mucho."},
	{"id": "panel_solar_basico", "n": "Panel solar básico", "cat": "energia", "m": 5, "e": 40, "c": 20, "r": 0.05,
		"solar": true, "desc": "Genera energía con la luz del Sol. Rinde menos lejos del Sol."},
	{"id": "panel_solar_avanzado", "n": "Panel solar avanzado", "cat": "energia", "m": 8, "e": 100, "c": 55, "r": 0.08,
		"solar": true, "adv": true, "desc": "Más potencia por kilo, pero más delicado."},
	{"id": "bateria", "n": "Batería de iones de litio", "cat": "energia", "m": 7, "e": 20, "c": 15, "r": 0.04,
		"desc": "Guarda energía para eclipses y picos de consumo."},
	{"id": "rtg", "n": "Generador RTG", "cat": "energia", "m": 45, "e": 110, "c": 90, "r": 0.03,
		"adv": true, "desc": "Genera energía con calor radiactivo. No depende del Sol."},
	{"id": "com_uhf", "n": "Radio UHF", "cat": "comunicacion", "m": 1, "e": -5, "c": 10, "r": 0.03,
		"enlace": 2, "desc": "Muy ligera, pero transmite pocos datos."},
	{"id": "com_s", "n": "Antena banda S", "cat": "comunicacion", "m": 3, "e": -15, "c": 25, "r": 0.05,
		"enlace": 10, "desc": "Equilibrio entre peso y velocidad de transmisión."},
	{"id": "com_x", "n": "Antena banda X", "cat": "comunicacion", "m": 10, "e": -35, "c": 60, "r": 0.06,
		"enlace": 40, "desc": "Para misiones más lejanas con más datos."},
	{"id": "com_ka", "n": "Antena Ka de alta ganancia", "cat": "comunicacion", "m": 22, "e": -45, "c": 130, "r": 0.09,
		"enlace": 150, "adv": true, "desc": "Enorme capacidad de transmisión, pesada y cara."},
	{"id": "cpu_basica", "n": "Computadora básica", "cat": "computadora", "m": 1, "e": -3, "c": 15, "r": 0.04,
		"desc": "Suficiente para misiones simples cerca de la Tierra."},
	{"id": "cpu_rad", "n": "Computadora tolerante a radiación", "cat": "computadora", "m": 2, "e": -8, "c": 45, "r": 0.02,
		"rad": true, "adv": true, "desc": "Resiste la radiación. Imprescindible en ambientes extremos."},
	{"id": "prop_gas", "n": "Propulsor de gas frío", "cat": "propulsion", "m": 3, "e": -3, "c": 15, "r": 0.04,
		"dv": 150, "desc": "Pequeños ajustes de órbita. Muy poco Δv."},
	{"id": "prop_quim", "n": "Motor químico", "cat": "propulsion", "m": 25, "e": -8, "c": 60, "r": 0.08,
		"dv": 1500, "desc": "Empuje fuerte y confiable. Δv medio."},
	{"id": "prop_ion", "n": "Propulsión iónica", "cat": "propulsion", "m": 35, "e": -80, "c": 140, "r": 0.10,
		"dv": 4500, "adv": true, "desc": "Muchísimo Δv, pero consume mucha energía."},
	{"id": "term_mli", "n": "Radiador y mantas térmicas", "cat": "termico", "m": 6, "e": -3, "c": 25, "r": 0.03,
		"desc": "Control térmico básico."},
	{"id": "term_escudo", "n": "Escudo térmico solar", "cat": "termico", "m": 30, "e": -5, "c": 90, "r": 0.05,
		"adv": true, "desc": "Protege del calor extremo cerca del Sol."},
	{"id": "inst_cam", "n": "Cámara óptica", "cat": "instrumento", "m": 4, "e": -15, "c": 25, "r": 0.04,
		"datos": 20, "ciencia": 3, "desc": "Imágenes en luz visible. Genera bastantes datos."},
	{"id": "inst_mag", "n": "Magnetómetro", "cat": "instrumento", "m": 2, "e": -5, "c": 18, "r": 0.03,
		"datos": 1, "ciencia": 2, "desc": "Mide campos magnéticos. Casi no genera datos."},
	{"id": "inst_part", "n": "Detector de partículas", "cat": "instrumento", "m": 5, "e": -10, "c": 30, "r": 0.05,
		"datos": 2, "ciencia": 3, "desc": "Mide la radiación y el viento solar."},
	{"id": "inst_esp", "n": "Espectrómetro", "cat": "instrumento", "m": 6, "e": -25, "c": 45, "r": 0.07,
		"datos": 8, "ciencia": 5, "desc": "Descubre de qué está hecho lo que observa."},
	{"id": "inst_ir", "n": "Cámara infrarroja", "cat": "instrumento", "m": 7, "e": -30, "c": 50, "r": 0.08,
		"datos": 35, "ciencia": 5, "adv": true, "desc": "Mide temperatura. Produce muchos datos."},
	{"id": "inst_sar", "n": "Radar de apertura sintética", "cat": "instrumento", "m": 15, "e": -60, "c": 85, "r": 0.10,
		"datos": 80, "ciencia": 8, "adv": true, "desc": "Mapea la superficie, incluso con nubes. Enorme volumen de datos."},
]

# ================= CONSTANTES DEL MINIJUEGO: CENTRO DE CONTROL =================
const ETAPAS_MJ := ["Encendido del motor", "Eclipse: balance de energía", "Anomalía en vuelo", "Transmisión de datos"]
const ESENCIALES := ["estructura", "computadora", "comunicacion", "termico"]
# [velocidad de la barra, ancho base de la ventana]
const MJ_DIF := {
	"tierra": [50.0, 22.0],
	"luna": [60.0, 18.0],
	"marte": [70.0, 15.0],
	"sol": [80.0, 13.0],
	"jupiter": [90.0, 11.0],
}
# En cada lista, la opción 0 es la correcta (se baraja al mostrarla)
const FALLAS := {
	"estructura": {"t": "Vibraciones fuertes en la estructura durante el empuje",
		"o": ["Reducir el empuje y vigilar la estructura con sensores", "Ignorar la alerta y aumentar el empuje", "Apagar la computadora de a bordo"],
		"e": "Las vibraciones pueden romper la estructura: lo prudente es reducir cargas y monitorear."},
	"energia": {"t": "El voltaje del bus de energía cae por debajo del límite",
		"o": ["Apagar cargas no esenciales y priorizar sistemas vitales", "Encender todos los instrumentos para diagnosticar", "Desconectar las baterías"],
		"e": "Con poca energía se protegen primero los sistemas vitales; los instrumentos pueden esperar."},
	"comunicacion": {"t": "Se pierde el enlace con la Tierra",
		"o": ["Cambiar a un modo de baja velocidad y reapuntar la antena", "Apagar el transmisor definitivamente", "Enviar más datos por el mismo canal"],
		"e": "Un modo lento es más robusto y permite recuperar el contacto."},
	"computadora": {"t": "La computadora de a bordo se reinicia sola (posible error por radiación)",
		"o": ["Pasar a modo seguro y restaurar desde memoria protegida", "Seguir la secuencia sin revisar nada", "Apagar los paneles solares"],
		"e": "La radiación corrompe la memoria: el modo seguro permite restaurar el estado sin arriesgar la misión."},
	"propulsion": {"t": "Presión anormal en el tanque del motor",
		"o": ["Cerrar válvulas y abortar la quema para evaluar", "Encender el motor a máxima potencia", "Calentar el tanque"],
		"e": "Una presión anormal puede acabar en explosión: se aborta y se diagnostica."},
	"termico": {"t": "El radiador reporta una temperatura fuera de rango",
		"o": ["Reorientar la nave para proteger el lado caliente y reducir consumo", "Encender más instrumentos", "Apuntar los paneles directo al Sol"],
		"e": "Hay que reducir la entrada de calor y el calor generado por la propia electrónica."},
	"instrumento": {"t": "Un instrumento satura y envía datos corruptos",
		"o": ["Reiniciarlo y recalibrarlo en modo seguro", "Subir su ganancia al máximo", "Borrar todos los datos de la misión"],
		"e": "Reiniciar y recalibrar suele resolver una saturación sin perder los datos buenos."},
}

# ======================================================================
#   CLASES VISUALES (todo se dibuja por código, sin imágenes)
# ======================================================================

# Barra del minijuego con ventana, marcas y destello de acierto/fallo
class BarraSenal extends Control:
	var valor := 0.0
	var vmin := 0.0
	var vmax := 0.0
	var flash := 0.0
	var flash_col := Color(0.4, 1.0, 0.5)
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.07, 0.18))
		for i in range(1, 10):
			var x := w * float(i) / 10.0
			draw_line(Vector2(x, h * 0.65), Vector2(x, h), Color(1, 1, 1, 0.15), 1.0)
		var vx := w * vmin / 100.0
		var vw := w * (vmax - vmin) / 100.0
		draw_rect(Rect2(vx - 3.0, 0, vw + 6.0, h), Color(0.3, 0.9, 0.5, 0.15))
		draw_rect(Rect2(vx, 0, vw, h), Color(0.3, 0.85, 0.5, 0.45))
		draw_rect(Rect2(vx, 0, vw, h), Color(0.6, 1.0, 0.7), false, 2.0)
		var nx := w * valor / 100.0
		draw_rect(Rect2(nx - 6.0, 0, 12.0, h), Color(1.0, 0.9, 0.4, 0.2))
		draw_rect(Rect2(nx - 1.5, 0, 3.0, h), Color(1.0, 0.92, 0.45))
		if flash > 0.0:
			draw_rect(Rect2(0, 0, w, h), Color(flash_col.r, flash_col.g, flash_col.b, flash * 0.35))
		draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.35, 0.75), false, 1.0)

# Ilustración del destino con una nave orbitando
class VistaDestino extends Control:
	var destino := "tierra"
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _nave_mini(p: Vector2) -> void:
		draw_rect(Rect2(p.x - 9.0, p.y - 1.5, 6.0, 3.0), Color(0.3, 0.6, 1.0))
		draw_rect(Rect2(p.x + 3.0, p.y - 1.5, 6.0, 3.0), Color(0.3, 0.6, 1.0))
		draw_rect(Rect2(p.x - 3.0, p.y - 3.0, 6.0, 6.0), Color(0.9, 0.92, 1.0))
	func _planeta(c: Vector2, r: float) -> void:
		match destino:
			"tierra":
				draw_circle(c, r * 1.12, Color(0.4, 0.7, 1.0, 0.15))
				draw_circle(c, r, Color(0.1, 0.3, 0.75))
				for i in range(5):
					var a := t * 0.25 + float(i) * 1.3
					var vis := cos(a)
					if vis > -0.2:
						var py := (float((i * 37) % 100) / 100.0 - 0.5) * r * 1.0
						var p := c + Vector2(sin(a) * r * 0.6, py)
						draw_circle(p, r * 0.18 * (0.6 + 0.4 * vis), Color(0.2, 0.6, 0.3))
				draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.06))
			"luna":
				draw_circle(c, r, Color(0.72, 0.72, 0.75))
				var cr := [Vector3(-0.3, -0.2, 0.18), Vector3(0.25, 0.1, 0.22), Vector3(-0.1, 0.4, 0.12), Vector3(0.35, -0.35, 0.1)]
				for q in cr:
					draw_circle(c + Vector2(q.x, q.y) * r, q.z * r, Color(0.5, 0.5, 0.54))
			"marte":
				draw_circle(c, r, Color(0.78, 0.35, 0.2))
				draw_circle(c + Vector2(-r * 0.3, r * 0.1), r * 0.25, Color(0.6, 0.25, 0.15))
				draw_circle(c + Vector2(r * 0.3, -r * 0.2), r * 0.18, Color(0.62, 0.27, 0.16))
				draw_circle(c + Vector2(0, -r * 0.85), r * 0.17, Color(1, 1, 1, 0.8))
			"sol":
				for i in range(5):
					draw_circle(c, r * (1.9 - float(i) * 0.2) + sin(t * 2.0 + float(i)) * 2.0, Color(1.0, 0.7, 0.2, 0.05 + 0.03 * float(i)))
				draw_circle(c, r, Color(1.0, 0.85, 0.3))
				draw_circle(c, r * 0.7, Color(1.0, 0.95, 0.7))
			"jupiter":
				draw_circle(c, r, Color(0.8, 0.65, 0.45))
				for i in range(int(-r), int(r), 3):
					var fy := float(i)
					var hw := sqrt(maxf(r * r - fy * fy, 0.0))
					var k := 0.5 + 0.5 * sin(fy * 0.35)
					draw_line(Vector2(c.x - hw, c.y + fy), Vector2(c.x + hw, c.y + fy), Color(0.8, 0.65, 0.45).lerp(Color(0.55, 0.38, 0.25), k), 3.0)
				draw_circle(c + Vector2(sin(t * 0.25) * r * 0.45, r * 0.3), r * 0.14, Color(0.75, 0.3, 0.2))
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.07, 0.7))
		draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.35, 0.75, 0.6), false, 1.0)
		var c := Vector2(w * 0.5, h * 0.5)
		var r := minf(h * 0.26, w * 0.16)
		var rx := minf(r * 2.6, w * 0.46)
		var ry := minf(r * 0.9, h * 0.4)
		var a := t * 0.9
		var sp := c + Vector2(cos(a) * rx, sin(a) * ry)
		var pts := PackedVector2Array()
		for i in range(65):
			var ang := TAU * float(i) / 64.0
			pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_polyline(pts, Color(1, 1, 1, 0.16), 1.0)
		if sin(a) < 0.0:
			_nave_mini(sp)
		_planeta(c, r)
		if sin(a) >= 0.0:
			_nave_mini(sp)

# Trayectoria Tierra -> destino con las 3 rutas posibles
class VistaRuta extends Control:
	var destino := "tierra"
	var nombre := ""
	var col_dest := Color(0.4, 0.6, 1.0)
	var elegida := -1
	var alcanza := true
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _bez(p0: Vector2, p1: Vector2, p2: Vector2, u: float) -> Vector2:
		return p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.07, 0.7))
		draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.35, 0.75, 0.6), false, 1.0)
		var p0 := Vector2(46.0, h * 0.5)
		var p2 := Vector2(w - 46.0, h * 0.5)
		var offs := [-0.45, 0.0, 0.45]
		for i in range(3):
			var p1 := Vector2(w * 0.5, h * 0.5 + float(offs[i]) * h * 1.6)
			var pts := PackedVector2Array()
			for k in range(49):
				pts.append(_bez(p0, p1, p2, float(k) / 48.0))
			if i == elegida:
				var cc := Color(0.5, 1.0, 0.6) if alcanza else Color(1.0, 0.5, 0.45)
				draw_polyline(pts, Color(cc.r, cc.g, cc.b, 0.2), 8.0)
				draw_polyline(pts, cc, 3.0)
				var u := fmod(t * 0.25, 1.0)
				for j in range(1, 7):
					var u2 := u - float(j) * 0.02
					if u2 >= 0.0:
						draw_circle(_bez(p0, p1, p2, u2), 4.0 - float(j) * 0.5, Color(1, 1, 1, 0.5 - float(j) * 0.07))
				draw_circle(_bez(p0, p1, p2, u), 5.0, Color(1, 1, 1))
			else:
				for k in range(0, 48, 2):
					draw_line(pts[k], pts[k + 1], Color(0.6, 0.65, 0.9, 0.35), 1.5)
		draw_circle(p0, 17.0, Color(0.2, 0.5, 1.0, 0.18))
		draw_circle(p0, 12.0, Color(0.15, 0.4, 0.9))
		draw_circle(p0 + Vector2(-3, -3), 4.0, Color(0.3, 0.7, 0.4))
		draw_string(font, p0 + Vector2(-24.0, 34.0), "Tierra", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 13, Color(0.8, 0.88, 1.0))
		draw_circle(p2, 20.0, Color(col_dest.r, col_dest.g, col_dest.b, 0.18))
		draw_circle(p2, 14.0, col_dest)
		draw_string(font, p2 + Vector2(-40.0, 34.0), nombre, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(0.8, 0.88, 1.0))
		if elegida < 0:
			draw_string(font, Vector2(0.0, 20.0), "Elige una ruta para ver la trayectoria", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(1.0, 0.82, 0.35))

# Esquema de la nave: se dibuja según las piezas ensambladas
class VistaNave extends Control:
	var comps: Array = []
	var eclipse := false
	var alerta := false
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.07, 0.75))
		draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.35, 0.75, 0.6), false, 1.0)
		if comps.is_empty():
			draw_string(font, Vector2(0.0, h * 0.5), "Agrega piezas para ver tu nave", HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.6, 0.65, 0.85))
			return
		var est = null
		var paneles: Array = []
		var baterias := 0
		var rtg := false
		var antenas: Array = []
		var props: Array = []
		var instr: Array = []
		var escudo := false
		var radiador := false
		var cpu := false
		var cpu_rad := false
		for c in comps:
			match String(c.categoria):
				"estructura":
					est = c
				"energia":
					if c.get_meta("solar", false):
						paneles.append(c)
					elif String(c.id) == "rtg":
						rtg = true
					else:
						baterias += 1
				"comunicacion":
					antenas.append(c)
				"propulsion":
					props.append(c)
				"instrumento":
					instr.append(c)
				"termico":
					if String(c.id) == "term_escudo":
						escudo = true
					else:
						radiador = true
				"computadora":
					cpu = true
					if c.get_meta("rad", false):
						cpu_rad = true
		var cx := w * 0.5
		var cy := h * 0.5
		var s := clampf(h / 170.0, 0.6, 1.0)
		draw_set_transform(Vector2(cx * (1.0 - s), cy * (1.0 - s) + sin(t * 1.3) * 3.0), 0.0, Vector2(s, s))
		var bw := 60.0
		var bh := 44.0
		if est != null:
			match String(est.id):
				"est_media":
					bw = 90.0
					bh = 56.0
				"est_blindada":
					bw = 100.0
					bh = 60.0
		var body := Rect2(cx - bw * 0.5, cy - bh * 0.5, bw, bh)
		# paneles solares (alas)
		var n := paneles.size()
		for li in range(2):
			var lado := -1.0 if li == 0 else 1.0
			var x0 := cx + lado * bw * 0.5
			for k in range(int(ceil(float(n) / 2.0))):
				var idx := k * 2 + li
				if idx >= n:
					continue
				var pw := 34.0
				var gap := 8.0
				var xa := x0 + lado * (gap + float(k) * (pw + 4.0))
				var rx := xa if lado > 0.0 else xa - pw
				var rect := Rect2(rx, cy - 20.0, pw, 40.0)
				var col := Color(0.2, 0.45, 0.95)
				if paneles[idx].get_meta("adv", false):
					col = Color(0.3, 0.85, 1.0)
				if eclipse:
					col = col.darkened(0.7)
				draw_line(Vector2(x0 if k == 0 else x0 + lado * (gap + float(k - 1) * (pw + 4.0) + pw), cy), Vector2(xa, cy), Color(0.7, 0.72, 0.8), 2.0)
				draw_rect(rect, col)
				for g in range(1, 3):
					draw_line(Vector2(rect.position.x + pw * float(g) / 3.0, rect.position.y), Vector2(rect.position.x + pw * float(g) / 3.0, rect.end.y), Color(0, 0, 0, 0.35), 1.0)
				draw_line(Vector2(rect.position.x, cy), Vector2(rect.end.x, cy), Color(0, 0, 0, 0.35), 1.0)
				draw_rect(rect, Color(1, 1, 1, 0.4), false, 1.0)
		# RTG
		if rtg:
			var rxp := cx - bw * 0.3
			draw_line(Vector2(rxp, body.position.y), Vector2(rxp, body.position.y - 14.0), Color(0.7, 0.72, 0.8), 2.0)
			var cyl := Rect2(rxp - 6.0, body.position.y - 36.0, 12.0, 22.0)
			draw_circle(cyl.get_center(), 14.0, Color(1.0, 0.5, 0.2, 0.12 + 0.05 * sin(t * 3.0)))
			draw_rect(cyl, Color(0.85, 0.45, 0.2))
			for g in range(1, 4):
				draw_line(Vector2(cyl.position.x - 3.0, cyl.position.y + float(g) * 5.0), Vector2(cyl.end.x + 3.0, cyl.position.y + float(g) * 5.0), Color(0.6, 0.3, 0.15), 2.0)
		if est == null:
			draw_rect(body, Color(1, 1, 1, 0.25), false, 1.0)
			draw_string(font, Vector2(body.position.x, cy + 4.0), "sin estructura", HORIZONTAL_ALIGNMENT_CENTER, bw, 11, Color(1.0, 0.82, 0.35))
		else:
			var bc := Color(0.62, 0.66, 0.78)
			if String(est.id) == "est_blindada":
				bc = Color(0.5, 0.52, 0.58)
			draw_rect(body, bc)
			draw_rect(Rect2(body.position.x, cy + bh * 0.15, bw, bh * 0.35), Color(0, 0, 0, 0.18))
			if String(est.id) == "est_blindada":
				draw_rect(body.grow(-5.0), Color(0, 0, 0, 0.3), false, 2.0)
			draw_rect(body, Color(1, 1, 1, 0.5), false, 1.5)
		# radiadores
		if radiador:
			draw_rect(Rect2(body.position.x - 3.0, cy - 8.0, 3.0, 16.0), Color(0.85, 0.88, 0.95))
			draw_rect(Rect2(body.end.x, cy - 8.0, 3.0, 16.0), Color(0.85, 0.88, 0.95))
		# escudo térmico
		if escudo:
			draw_arc(Vector2(cx, body.position.y + 10.0), bw * 0.75, PI * 1.1, PI * 1.9, 24, Color(1.0, 0.8, 0.3), 6.0)
			draw_arc(Vector2(cx, body.position.y + 10.0), bw * 0.75 - 5.0, PI * 1.1, PI * 1.9, 24, Color(0.8, 0.5, 0.2), 2.0)
		# baterías
		for i in range(mini(baterias, 3)):
			draw_rect(Rect2(body.position.x + 6.0 + float(i) * 12.0, body.end.y - 12.0, 9.0, 7.0), Color(0.4, 0.95, 0.5))
		# computadora
		if cpu:
			var cc := Color(0.9, 0.7, 0.2) if cpu_rad else Color(0.2, 0.7, 0.4)
			draw_rect(Rect2(cx - 7.0, cy - 5.0, 14.0, 14.0), cc.darkened(0.5))
			draw_rect(Rect2(cx - 7.0, cy - 5.0, 14.0, 14.0), cc, false, 1.5)
		# instrumentos
		var pal := [Color(0.4, 0.9, 1.0), Color(1.0, 0.5, 0.9), Color(1.0, 0.9, 0.4), Color(1.0, 0.6, 0.3), Color(0.6, 1.0, 0.5), Color(0.9, 0.9, 1.0)]
		for i in range(instr.size()):
			var px := body.position.x + 9.0 + float(i) * 13.0
			if px > body.end.x - 8.0:
				break
			var ic: Color = pal[i % pal.size()]
			draw_circle(Vector2(px, body.position.y + 11.0), 4.5, ic)
			draw_circle(Vector2(px, body.position.y + 11.0), 2.0, Color(0.05, 0.05, 0.12))
		if not antenas.is_empty():
			var en := 0.0
			for a in antenas:
				en = maxf(en, float(a.get_meta("enlace", 0.0)))
			var rr := 6.0 + sqrt(en) * 1.5
			var base := Vector2(cx + bw * 0.3, body.position.y)
			var dish_c := base + Vector2(0.0, -10.0 - rr * 0.2)
			draw_line(base, dish_c, Color(0.7, 0.72, 0.8), 2.0)
			draw_arc(dish_c, rr, 0.15, PI - 0.15, 20, Color(0.85, 0.9, 1.0), 3.0)
			var feed := dish_c + Vector2(0.0, -rr * 0.9)
			draw_line(dish_c, feed, Color(0.7, 0.72, 0.8), 1.0)
			draw_circle(feed, 2.0, Color(1.0, 0.85, 0.4))
			if not eclipse:
				for k in range(3):
					var rw := 10.0 + float(k) * 9.0 + fmod(t * 14.0, 9.0)
					draw_arc(feed, rw, -PI * 0.8, -PI * 0.2, 14, Color(0.5, 0.9, 1.0, 0.5 - float(k) * 0.15), 1.5)
		# propulsores con llama
		var np := props.size()
		var total := float(np) * 18.0
		for i in range(np):
			var nx := cx - total * 0.5 + float(i) * 18.0 + 9.0
			var ny := body.end.y
			var tw := 8.0
			var nl := 6.0
			var fl := 7.0
			var fcol := Color(0.9, 0.9, 1.0, 0.7)
			match String(props[i].id):
				"prop_quim":
					tw = 14.0
					nl = 12.0
					fl = 16.0 + sin(t * 22.0 + float(i) * 1.7) * 3.0
					fcol = Color(1.0, 0.6, 0.2, 0.9)
				"prop_ion":
					tw = 16.0
					nl = 8.0
					fl = 20.0 + sin(t * 8.0 + float(i)) * 1.5
					fcol = Color(0.4, 0.75, 1.0, 0.9)
					draw_circle(Vector2(nx, ny + nl + 4.0), 8.0, Color(0.4, 0.7, 1.0, 0.25))
				_:
					fl = 7.0 + sin(t * 25.0 + float(i)) * 2.0
			var poly := PackedVector2Array([Vector2(nx - tw * 0.3, ny), Vector2(nx + tw * 0.3, ny), Vector2(nx + tw * 0.5, ny + nl), Vector2(nx - tw * 0.5, ny + nl)])
			draw_colored_polygon(poly, Color(0.45, 0.47, 0.55))
			var fp := PackedVector2Array([Vector2(nx - tw * 0.4, ny + nl), Vector2(nx + tw * 0.4, ny + nl), Vector2(nx, ny + nl + fl)])
			draw_colored_polygon(fp, fcol)
			var fp2 := PackedVector2Array([Vector2(nx - tw * 0.2, ny + nl), Vector2(nx + tw * 0.2, ny + nl), Vector2(nx, ny + nl + fl * 0.6)])
			draw_colored_polygon(fp2, Color(1, 1, 1, 0.8))
		if alerta:
			draw_arc(Vector2(cx, cy), 70.0 + sin(t * 6.0) * 4.0, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.6 + 0.3 * sin(t * 6.0)), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if eclipse:
			draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.25))
			draw_string(font, Vector2(10.0, 18.0), "ECLIPSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.82, 0.35))
		if alerta:
			draw_string(font, Vector2(10.0, 18.0), "ALERTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.45, 0.45))

var est: Dictionary = {}                 # estado persistente del laboratorio (vive en GameState como meta)
var _plantillas: Array[ComponentData] = []
var _tab: int = E_ARCHIVO
var _filtro: String = ""                 # categoría del catálogo ("" = todas)
var _cuerpo: VBoxContainer
var _lbl_info: Label
var _lbl_dias: Label
var _lbl_msg: Label
var _lbl_estado: Label
var _btn_fin: Button
var _botones_tab: Array[Button] = []
var _barras: Array[ProgressBar] = []
var _lbl_barras: Array[Label] = []
var _lista_nave: VBoxContainer
var _tabs_bar: HBoxContainer
var _btn_reiniciar: Button

# ----- estado del minijuego -----
var _minijuego_activo := false
var _mj_etapa := 0
var _mj_puntos: Array[float] = []
var _mj_modo_barra := false
var _senal := 0.0
var _direccion := 1.0
var _velocidad_senal := 65.0
var _ancho := 18.0
var _centro_obj := 70.0
var _mj_aciertos := 0
var _mj_intentos := 0
var _mj_apagados: Dictionary = {}
var _mj_falla_comp: ComponentData
var _mj_falla_fallos := 0
var _mj_falla_btns: Array[Button] = []
var _barra: BarraSenal
var _mj_gauge: ProgressBar
var _lbl_mj: Label
var _lbl_aux: Label
var _btn_mj: Button
var _btn_continuar: Button

func _process(delta: float) -> void:
	if is_instance_valid(_astro_vista_3d):
		_astro_vista_3d.rotate_y(0.35 * delta)
	if not _minijuego_activo or not is_instance_valid(_barra):
		return
	_barra.flash = maxf(_barra.flash - delta * 3.0, 0.0)
	if _mj_modo_barra:
		_senal += _direccion * delta * _velocidad_senal
		if _senal >= 100.0:
			_senal = 100.0
			_direccion = -1.0
		elif _senal <= 0.0:
			_senal = 0.0
			_direccion = 1.0
		_barra.valor = _senal
	_barra.queue_redraw()


func _ready() -> void:
	# Si la Fase 1 no dejó destino (por ejemplo, al abrir esta escena sola con F6),
	# _estado_nuevo() usa el destino por defecto del nivel elegido.
	# las piezas ni el progreso: la dificultad siempre es la que se eligió en el menú.
	_preparar_estado()
	for d in CATALOGO:
		_plantillas.append(_crear(d))
	_construir_ui()
	_ir_a(E_ARCHIVO)


func _preparar_estado() -> void:
	var viejo = null
	if GameState.has_meta("lab_estado"):
		viejo = GameState.get_meta("lab_estado")
	var nueva := true
	if viejo is Dictionary:
		nueva = (
			viejo.get("nivel", "") != GameState.nivel_actual()
			or viejo.get("plan", "") != _plan_actual()
			or (viejo.get("completada", false) and not GameState.fases_completadas[1])
			or int(viejo.get("n_piezas", 0)) != GameState.componentes.size()
		)
	if nueva:
		est = _estado_nuevo()
		GameState.set_meta("lab_estado", est)
	else:
		est = viejo


func _estado_nuevo() -> Dictionary:
	# Los días de preparación vienen de la ficha de la Fase 1 (misma fuente que los requisitos del nivel).
	var dias: int = int(GameState.ficha.get("dias_preparacion", DIAS_NIVEL[GameState.nivel_actual()]))
	var dk := _detectar_destino()
	var ambiguo := false
	var opciones: Array = OPC_NIVEL[GameState.nivel_actual()]
	if dk == "":
		dk = opciones[0]
		ambiguo = opciones.size() > 1
	# La ruta que se eligió en la Fase 1 queda fijada: aquí solo se comprueba que la nave pueda recorrerla.
	var ruta_idx := _indice_ruta(dk, String(GameState.ficha.get("ruta", "")))
	if ruta_idx >= 0:
		ambiguo = false
	return {
		"nivel": GameState.nivel_actual(),
		"plan": _plan_actual(),
		"ruta_fija": ruta_idx >= 0,
		"dias": dias,
		"visitadas": [false, false, false, false, false],
		"destino": dk,
		"ambiguo": ambiguo,
		"respuestas": {},
		"reveladas": {},
		"extra": 0.0,
		"gasto_pruebas": 0.0,
		"negociaciones": 0,
		"ruta_idx": ruta_idx,
		"n_piezas": GameState.componentes.size(),
		"completada": false,
	}
## Identifica el plan de la Fase 1 (destino + ruta) para saber si el estado guardado sigue siendo válido.
func _plan_actual() -> String:
	return "%s|%s" % [GameState.ficha.get("destino", ""), GameState.ficha.get("ruta", "")]


## Rutas de un destino, tomadas del catálogo único de la Fase 1 (Datos.RUTAS).
## Cada ruta: {"n": nombre, "dias": días de viaje, "dv": Δv necesario, "r": riesgo, "nota": texto}.
func _rutas(dk: String) -> Array:
	var lista: Array = []
	var catalogo: Dictionary = Datos.RUTAS.get(DESTINOS[dk]["nombre"], {})
	for nombre in catalogo.keys():
		var r: Dictionary = catalogo[nombre]
		lista.append({"n": nombre, "dias": int(r["viaje"]), "dv": float(r["dv"]),
			"r": float(r["riesgo"]), "nota": String(r["nota"])})
	return lista


## Posición de una ruta (por nombre) dentro de las rutas del destino, o -1 si no está.
func _indice_ruta(dk: String, nombre: String) -> int:
	if nombre == "":
		return -1
	var lista := _rutas(dk)
	for i in range(lista.size()):
		if lista[i]["n"] == nombre:
			return i
	return -1


func _detectar_destino() -> String:
	# 1) El destino exacto que dejó la Fase 1 (p. ej. "Órbita solar").
	var opciones: Array = OPC_NIVEL[GameState.nivel_actual()]
	for k in opciones:
		if String(DESTINOS[k]["nombre"]) == GameState.destino:
			return k
	# 2) Respaldo: buscar palabras clave.
	#    puede nombrar otro planeta (p. ej. "Asistencia de Júpiter" hacia la Órbita solar).
	for texto in [GameState.destino, GameState.ruta]:
		var t: String = String(texto).to_lower()
		var hallados: Array[String] = []
		for k in OPC_NIVEL[GameState.nivel_actual()]:
			for palabra in DESTINOS[k]["palabras"]:
				if t.contains(palabra):
					hallados.append(k)
					break
		if hallados.size() == 1:
			return hallados[0]
	return ""
func _dest() -> String:
	return est["destino"]
func _masa_max() -> float:
	return float(DESTINOS[_dest()]["masa_max"])
func _crear(d: Dictionary) -> ComponentData:
	var c := ComponentData.new()
	c.id = d["id"]
	c.nombre = d["n"]
	c.categoria = d["cat"]
	c.masa_kg = float(d["m"])
	c.energia_w = float(d["e"])
	c.costo = float(d["c"])
	c.datos_mbps = float(d.get("datos", 0))
	c.riesgo_falla = float(d["r"])
	c.descripcion = d["desc"]
	for k in ["enlace", "dv", "ciencia", "solar", "rad", "adv"]:
		if d.has(k):
			c.set_meta(k, d[k])
	return c
func _cuenta(cat: String) -> int:
	var n := 0
	for c in GameState.componentes:
		if c.categoria == cat:
			n += 1
	return n
func _cumple(req: String) -> bool:
	if req == "blindaje":
		for c in GameState.componentes:
			if c.get_meta("rad", false):
				return true
		return false
	return _cuenta(req) > 0
func energia_generada() -> float:
	var f: float = DESTINOS[_dest()]["solar"]
	var t := 0.0
	for c in GameState.componentes:
		if c.energia_w > 0.0:
			t += c.energia_w * (f if c.get_meta("solar", false) else 1.0)
	return t
func energia_consumida() -> float:
	var t := 0.0
	for c in GameState.componentes:
		if c.energia_w < 0.0:
			t += -c.energia_w
	return t
func datos_total() -> float:
	var t := 0.0
	for c in GameState.componentes:
		t += c.datos_mbps
	return t
func enlace_efectivo() -> float:
	var t := 0.0
	for c in GameState.componentes:
		t += float(c.get_meta("enlace", 0.0))
	return t * float(DESTINOS[_dest()]["enlace"])
func dv_total() -> float:
	var t := 0.0
	for c in GameState.componentes:
		t += float(c.get_meta("dv", 0.0))
	return t
func ciencia_estimada() -> float:
	var s := 0.0
	for c in GameState.componentes:
		s += float(c.get_meta("ciencia", 0.0))
	var datos := datos_total()
	if datos > 0.0:
		s *= minf(1.0, enlace_efectivo() / datos)
	return s
func _ruta_actual() -> Dictionary:
	var i: int = est["ruta_idx"]
	if i < 0:
		return {}
	return _rutas(_dest())[i]
func _correctas() -> int:
	var dk := _dest()
	var resp := _resps(dk)
	var lista: Array = PREGUNTAS[dk]
	var n := 0
	for i in range(lista.size()):
		if resp[i] == int(lista[i]["c"]):
			n += 1
	return n
func _resps(dk: String) -> Array:
	if not est["respuestas"].has(dk):
		est["respuestas"][dk] = [-1, -1, -1]
	return est["respuestas"][dk]
func _req_visibles() -> bool:
	return GameState.nivel_actual() != "dificil" or est["visitadas"][E_ARCHIVO]
func _riesgo_visible(c: ComponentData) -> bool:
	if c.get_meta("investigado", false):
		return true
	if est["reveladas"].has(c.categoria):
		return true
	match GameState.nivel_actual():
		"facil":
			return true
		"medio":
			return not c.get_meta("adv", false)
	return false
func _riesgo_ruta_visible() -> bool:
	return GameState.nivel_actual() != "dificil" or _correctas() >= 2
func _txt_riesgo(c: ComponentData) -> String:
	if _riesgo_visible(c):
		return "%d %%" % int(roundf(c.riesgo_falla * 100.0))
	return "???"
func _fiabilidad() -> float:
	var f := 1.0
	var oculto := false
	for c in GameState.componentes:
		f *= 1.0 - c.riesgo_falla
		if not _riesgo_visible(c):
			oculto = true
	var r := _ruta_actual()
	if not r.is_empty():
		f *= 1.0 - float(r["r"])
		if not _riesgo_ruta_visible():
			oculto = true
	return -1.0 if oculto else f
func _dias_ok(n: int) -> bool:
	var d: int = est["dias"]
	return d < 0 or d >= n
func _gastar_dias(n: int) -> void:
	if int(est["dias"]) >= 0:
		est["dias"] = int(est["dias"]) - n
func _validar() -> Dictionary:
	var bloqueos: Array[String] = []
	var faltantes: Array[String] = []
	var avisos: Array[String] = []
	for esencial in ["estructura", "energia", "computadora"]:
		if _cuenta(esencial) == 0:
			bloqueos.append("Falta: " + CAT_NOMBRE[esencial])
	if energia_generada() < energia_consumida():
		bloqueos.append("Energía insuficiente (genera %s W y consume %s W)" % [_num(energia_generada()), _num(energia_consumida())])
	if GameState.masa_total() > _masa_max():
		bloqueos.append("Te pasas del límite de masa (%s kg)" % _num(_masa_max()))
	if GameState.costo_total() > GameState.presupuesto_max:
		bloqueos.append("Te pasas del presupuesto")
	var r := _ruta_actual()
	if r.is_empty():
		bloqueos.append("Elige una ruta en el Mapa de rutas")
	elif dv_total() < float(r["dv"]):
		bloqueos.append("Δv insuficiente para la ruta (%s de %s m/s)" % [_num(dv_total()), _num(float(r["dv"]))])
	var visibles := _req_visibles()
	for req in DESTINOS[_dest()]["req"]:
		if req == "estructura" or req == "energia" or req == "computadora":
			continue
		if not _cumple(req):
			if visibles:
				bloqueos.append("Falta: " + CAT_NOMBRE[req])
			else:
				faltantes.append(req)
	if datos_total() > enlace_efectivo() + 0.001:
		var perdida := 100.0 * (1.0 - enlace_efectivo() / datos_total())
		avisos.append("Perderás ~%d %% de los datos (el enlace no alcanza)" % int(roundf(perdida)))
	return {"bloqueos": bloqueos, "faltantes": faltantes, "avisos": avisos}

# ---------- TEMA Y ESTILOS ----------
func _caja_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb
func _crear_tema() -> Theme:
	var t := Theme.new()
	var normal := _caja_boton(Color(0.16, 0.16, 0.34), Color(0.45, 0.4, 0.85))
	var hover := _caja_boton(Color(0.22, 0.22, 0.45), Color(0.7, 0.65, 1.0))
	var pressed := _caja_boton(Color(0.1, 0.1, 0.24), Color(0.5, 1.0, 0.6))
	var disabled := _caja_boton(Color(0.1, 0.1, 0.18), Color(0.25, 0.25, 0.4))
	for tipo in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tipo, normal)
		t.set_stylebox("hover", tipo, hover)
		t.set_stylebox("pressed", tipo, pressed)
		t.set_stylebox("disabled", tipo, disabled)
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
		t.set_color("font_color", tipo, Color(0.9, 0.93, 1.0))
		t.set_color("font_hover_color", tipo, Color.WHITE)
		t.set_color("font_pressed_color", tipo, COL_OK)
		t.set_color("font_disabled_color", tipo, Color(0.5, 0.5, 0.62))
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = Color(0.08, 0.08, 0.16)
	fondo_barra.set_corner_radius_all(6)
	fondo_barra.set_border_width_all(1)
	fondo_barra.border_color = Color(0.3, 0.3, 0.5)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Color(0.85, 0.9, 1.0)
	relleno.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", fondo_barra)
	t.set_stylebox("fill", "ProgressBar", relleno)
	return t
func _fade(n: Control) -> void:
	n.modulate.a = 0.0
	create_tween().tween_property(n, "modulate:a", 1.0, 0.25)
func _col_riesgo(p: float) -> Color:
	if p < 0.05:
		return COL_OK
	if p < 0.09:
		return COL_AVISO
	return COL_MAL
func _flujo() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f
func _chip(texto: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.9)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_lbl(texto, 12, col))
	return p
func _chips(c: ComponentData) -> HFlowContainer:
	var f := _flujo()
	f.add_child(_chip(CAT_NOMBRE[c.categoria], CAT_COL[c.categoria]))
	f.add_child(_chip("%s kg" % _num(c.masa_kg), Color(0.7, 0.8, 1.0)))
	f.add_child(_chip("%s W" % _signo(c.energia_w), COL_OK if c.energia_w > 0.0 else Color(1.0, 0.65, 0.35)))
	f.add_child(_chip("costo %s" % _num(c.costo), COL_AVISO))
	var rc := COL_SUAVE
	if _riesgo_visible(c):
		rc = _col_riesgo(c.riesgo_falla)
	f.add_child(_chip("riesgo %s" % _txt_riesgo(c), rc))
	if c.datos_mbps > 0.0:
		f.add_child(_chip("datos %s Mbps" % _num(c.datos_mbps), Color(0.6, 0.9, 1.0)))
	var enlace: float = float(c.get_meta("enlace", 0.0))
	if enlace > 0.0:
		f.add_child(_chip("enlace %s Mbps" % _num(enlace), Color(0.5, 0.8, 1.0)))
	var dv: float = float(c.get_meta("dv", 0.0))
	if dv > 0.0:
		f.add_child(_chip("Δv %s m/s" % _num(dv), Color(1.0, 0.7, 0.9)))
	var ciencia: float = float(c.get_meta("ciencia", 0.0))
	if ciencia > 0.0:
		f.add_child(_chip("ciencia %s" % _num(ciencia), Color(0.8, 1.0, 0.5)))
	return f
func _vista_nave(alto: float, eclipse: bool = false, alerta: bool = false) -> VistaNave:
	var v := VistaNave.new()
	v.comps = GameState.componentes
	v.custom_minimum_size = Vector2(0, alto)
	v.eclipse = eclipse
	v.alerta = alerta
	return v

func _construir_ui() -> void:
	var fondo := FondoEspacial.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.theme = _crear_tema()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	add_child(margen)
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 8)
	margen.add_child(raiz)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 16)
	raiz.add_child(cab)
	cab.add_child(_titulo("FASE 2: LABORATORIO", 26, Color(0.75, 0.85, 1.0)))
	_lbl_info = _lbl("", 15, COL_SUAVE)
	_lbl_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cab.add_child(_lbl_info)
	_lbl_dias = _lbl("", 16, COL_AVISO)
	cab.add_child(_lbl_dias)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(hueco)
	var recursos := HBoxContainer.new()
	recursos.add_theme_constant_override("separation", 12)
	raiz.add_child(recursos)
	for i in range(5):
		var caja := VBoxContainer.new()
		caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caja.add_theme_constant_override("separation", 2)
		recursos.add_child(caja)
		var l := _lbl("", 14)
		caja.add_child(l)
		var barra := ProgressBar.new()
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 14)
		caja.add_child(barra)
		_lbl_barras.append(l)
		_barras.append(barra)
	_tabs_bar = HBoxContainer.new()
	_tabs_bar.add_theme_constant_override("separation", 6)
	raiz.add_child(_tabs_bar)
	for i in range(ESTACIONES.size()):
		var bt := Button.new()
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.custom_minimum_size = Vector2(0, 38)
		bt.pressed.connect(_ir_a.bind(i))
		_tabs_bar.add_child(bt)
		_botones_tab.append(bt)
	_cuerpo = VBoxContainer.new()
	_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(_cuerpo)
	_lbl_msg = _lbl("", 16, COL_SUAVE, true)
	_lbl_msg.custom_minimum_size = Vector2(300, 24)
	raiz.add_child(_lbl_msg)
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 12)
	raiz.add_child(pie)
	_btn_reiniciar = _btn("Reiniciar laboratorio", _reiniciar_lab)
	pie.add_child(_btn_reiniciar)
	_lbl_estado = _lbl("", 14, COL_AVISO, true)
	_lbl_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_lbl_estado)
	_btn_fin = _btn("Finalizar laboratorio", _finalizar)
	_btn_fin.custom_minimum_size = Vector2(220, 40)
	pie.add_child(_btn_fin)
func _actualizar_tabs() -> void:
	for i in range(ESTACIONES.size()):
		var t: String = "%d. %s" % [i + 1, ESTACIONES[i]["nombre"]]
		var costo: int = ESTACIONES[i]["dias"]
		if est["visitadas"][i]:
			t += " *"
		elif costo > 0 and int(est["dias"]) >= 0:
			t += " (%d día)" % costo
		_botones_tab[i].text = t
		if i == _tab:
			var activo := _caja_boton(Color(0.14, 0.2, 0.3), ESTACION_COL[i])
			activo.set_border_width_all(2)
			_botones_tab[i].add_theme_stylebox_override("normal", activo)
			_botones_tab[i].add_theme_stylebox_override("hover", activo)
			_botones_tab[i].add_theme_color_override("font_color", ESTACION_COL[i])
		else:
			_botones_tab[i].remove_theme_stylebox_override("normal")
			_botones_tab[i].remove_theme_stylebox_override("hover")
			_botones_tab[i].remove_theme_color_override("font_color")
func _ir_a(i: int) -> void:
	if _minijuego_activo:
		return
	est["visitadas"][i] = true
	_tab = i
	_actualizar_tabs()
	_refrescar()
	match i:
		E_ARCHIVO:
			_vista_archivo()
		E_TALLER:
			_vista_taller()
		E_PRESUPUESTO:
			_vista_presupuesto()
		E_SIMULADOR:
			_vista_simulador()
		E_MAPA:
			_vista_mapa()
func _refrescar() -> void:
	est["n_piezas"] = GameState.componentes.size()
	var d: Dictionary = DESTINOS[_dest()]
	var fiab := _fiabilidad()
	var f_txt := "???" if fiab < 0.0 else "%d %%" % int(roundf(fiab * 100.0))
	_lbl_info.text = "Nivel %s  |  Destino: %s  |  Fiabilidad estimada: %s" % [GameState.NIVELES[GameState.nivel_actual()]["nombre"], d["nombre"], f_txt]
	if int(est["dias"]) < 0:
		_lbl_dias.text = "Días de preparación: ilimitados"
		_lbl_dias.add_theme_color_override("font_color", COL_SUAVE)
	else:
		_lbl_dias.text = "Días de preparación: %d" % int(est["dias"])
		var poco: bool = int(est["dias"]) <= 2
		_lbl_dias.add_theme_color_override("font_color", COL_MAL if poco else COL_AVISO)
	var costo := GameState.costo_total()
	_set_barra(0, "Presupuesto: %s / %s" % [_num(costo), _num(GameState.presupuesto_max)], costo, GameState.presupuesto_max, costo > GameState.presupuesto_max)
	var masa := GameState.masa_total()
	_set_barra(1, "Masa: %s / %s kg" % [_num(masa), _num(_masa_max())], masa, _masa_max(), masa > _masa_max())
	var gen := energia_generada()
	var con := energia_consumida()
	_set_barra(2, "Energía: genera %s W, consume %s W" % [_num(gen), _num(con)], con, maxf(gen, 1.0), con > gen)
	var datos := datos_total()
	var enlace := enlace_efectivo()
	_set_barra(3, "Datos %s / Enlace %s Mbps" % [_num(datos), _num(enlace)], datos, maxf(maxf(enlace, datos), 1.0), datos > enlace + 0.001)
	var r := _ruta_actual()
	var dv := dv_total()
	if r.is_empty():
		_set_barra(4, "Δv: %s m/s (elige una ruta)" % _num(dv), 0.0, 1.0, false)
	else:
		var necesario := float(r["dv"])
		_set_barra(4, "Δv: %s / %s m/s necesarios" % [_num(dv), _num(necesario)], minf(dv, maxf(necesario, 1.0)), maxf(necesario, 1.0), dv < necesario)
	var v := _validar()
	var bl: Array = v["bloqueos"]
	_btn_fin.disabled = not bl.is_empty()
	if bl.is_empty():
		_lbl_estado.text = "Todo listo. Puedes finalizar el laboratorio."
		_lbl_estado.add_theme_color_override("font_color", COL_OK)
	else:
		_lbl_estado.text = "Pendiente: " + "; ".join(PackedStringArray(bl))
		_lbl_estado.add_theme_color_override("font_color", COL_AVISO)
func _set_barra(i: int, texto: String, valor: float, maximo: float, malo: bool) -> void:
	_lbl_barras[i].text = texto
	_barras[i].max_value = maxf(maximo, 1.0)
	_barras[i].value = valor
	_barras[i].modulate = COL_MAL if malo else Color(0.6, 1.0, 0.7)
func _msg(texto: String, bien: bool) -> void:
	_lbl_msg.text = texto
	_lbl_msg.add_theme_color_override("font_color", COL_OK if bien else COL_MAL)
func _lbl(t: String, tam: int = 16, col: Color = Color.WHITE, ajustar: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	if ajustar:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(160, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
func _titulo(t: String, tam: int = 22, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	Estilo.texto(l, tam, col)
	return l
func _btn(t: String, cb: Callable, activo: bool = true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not activo
	b.pressed.connect(cb)
	return b
func _caja(col: Color, m: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(m)
	sb.border_color = Color(0.4, 0.35, 0.75)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb
func _caja_acento(col: Color, m: int, acento: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(m)
	sb.border_color = acento
	sb.border_width_left = 5
	return sb
func _limpiar(n: Node) -> void:
	for h in n.get_children():
		n.remove_child(h)
		h.queue_free()
func _nueva_fila() -> HBoxContainer:
	_limpiar(_cuerpo)
	var fila := HBoxContainer.new()
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 12)
	_cuerpo.add_child(fila)
	_fade(fila)
	return fila
func _panel(padre: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _caja(COL_PANEL))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	padre.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v
func _fila_panel(padre: Control, col: Color = COL_FILA, acento: Color = Color(0, 0, 0, 0)) -> HBoxContainer:
	var p := PanelContainer.new()
	if acento.a > 0.0:
		p.add_theme_stylebox_override("panel", _caja_acento(col, 8, acento))
	else:
		p.add_theme_stylebox_override("panel", _caja(col, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	return h
func _num(x: float) -> String:
	if is_equal_approx(x, roundf(x)):
		return str(int(roundf(x)))
	return String.num(x, 1)
func _signo(x: float) -> String:
	return ("+" if x > 0.0 else "") + _num(x)
func _stats(c: ComponentData) -> String:
	var p: PackedStringArray = []
	p.append("%s kg" % _num(c.masa_kg))
	p.append("%s W" % _signo(c.energia_w))
	p.append("costo %s" % _num(c.costo))
	p.append("riesgo %s" % _txt_riesgo(c))
	if c.datos_mbps > 0.0:
		p.append("datos %s Mbps" % _num(c.datos_mbps))
	var enlace: float = float(c.get_meta("enlace", 0.0))
	if enlace > 0.0:
		p.append("enlace %s Mbps" % _num(enlace))
	var dv: float = float(c.get_meta("dv", 0.0))
	if dv > 0.0:
		p.append("Δv %s m/s" % _num(dv))
	var ciencia: float = float(c.get_meta("ciencia", 0.0))
	if ciencia > 0.0:
		p.append("ciencia %s" % _num(ciencia))
	return "  |  ".join(p)
func _nombre(c: ComponentData) -> String:
	return c.nombre + ("  (avanzado)" if c.get_meta("adv", false) else "")
func _vista_archivo() -> void:
	var fila := _nueva_fila()
	var dk := _dest()
	var d: Dictionary = DESTINOS[dk]
	var izq := _panel(fila)
	izq.add_child(_titulo("Archivo de misión", 22))
	izq.add_child(_lbl("Aquí investigas el destino antes de diseñar la nave.", 14, COL_SUAVE, true))
	if est["ambiguo"] and int(est["ruta_idx"]) < 0:
		izq.add_child(_lbl("Elige el destino de tu misión:", 15, COL_AVISO))
		var sel := OptionButton.new()
		var opciones: Array = OPC_NIVEL[GameState.nivel_actual()]
		for i in range(opciones.size()):
			sel.add_item(DESTINOS[opciones[i]]["nombre"])
			if opciones[i] == dk:
				sel.select(i)
		sel.item_selected.connect(_cambiar_destino)
		izq.add_child(sel)
	izq.add_child(_titulo(d["nombre"], 26, Color(0.7, 0.8, 1.0)))
	izq.add_child(_crear_vista_astro_3d(dk))
	izq.add_child(_lbl("Distancia: " + d["distancia"], 16, Color.WHITE, true))
	izq.add_child(_lbl("Luz solar: " + d["luz"], 16, Color.WHITE, true))
	izq.add_child(_lbl("Retardo de la señal: " + d["retardo"], 16, Color.WHITE, true))
	izq.add_child(_lbl("Entorno: " + d["entorno"], 16, Color.WHITE, true))
	izq.add_child(_lbl("Masa máxima de la nave: %s kg" % _num(_masa_max()), 16, COL_AVISO, true))
	izq.add_child(_titulo("Tu nave necesita:", 18))
	for req in d["req"]:
		var tiene := _cumple(req)
		izq.add_child(_lbl(("[OK] " if tiene else "[  ] ") + CAT_NOMBRE[req], 15, COL_OK if tiene else COL_SUAVE))
	var der := _panel(fila)
	der.add_child(_titulo("Preguntas cortas", 22))
	der.add_child(_lbl("Cada acierto revela los riesgos de fallo de una categoría de piezas. Si fallas, lee la explicación: ahí está la clave.", 14, COL_SUAVE, true))
	var lista: Array = PREGUNTAS[dk]
	var resp := _resps(dk)
	for qi in range(lista.size()):
		var preg: Dictionary = lista[qi]
		der.add_child(_lbl("%d. %s" % [qi + 1, preg["p"]], 16, Color.WHITE, true))
		if resp[qi] == -1:
			for oi in range(preg["o"].size()):
				var b := Button.new()
				b.text = preg["o"][oi]
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.pressed.connect(_responder.bind(qi, oi))
				der.add_child(b)
		else:
			var acerto: bool = resp[qi] == int(preg["c"])
			var elegido: String = preg["o"][resp[qi]]
			der.add_child(_lbl(("Correcto: " if acerto else "Tu respuesta: ") + elegido, 15, COL_OK if acerto else COL_MAL, true))
			if not acerto:
				der.add_child(_lbl("Era: " + String(preg["o"][int(preg["c"])]), 15, COL_OK, true))
			der.add_child(_lbl(preg["e"], 14, COL_SUAVE, true))
			if acerto:
				der.add_child(_lbl("Riesgos revelados: " + CAT_NOMBRE[preg["cat"]], 14, COL_AVISO, true))
		der.add_child(HSeparator.new())
func _cambiar_destino(i: int) -> void:
	est["destino"] = OPC_NIVEL[GameState.nivel_actual()][i]
	_refrescar()
	_vista_archivo()
func _responder(qi: int, op: int) -> void:
	var dk := _dest()
	var preg: Dictionary = PREGUNTAS[dk][qi]
	var resp := _resps(dk)
	if resp[qi] != -1:
		return
	resp[qi] = op
	if op == int(preg["c"]):
		est["reveladas"][preg["cat"]] = true
		_msg("¡Correcto! Ahora conoces los riesgos de: " + CAT_NOMBRE[preg["cat"]], true)
	else:
		_msg("Respuesta incorrecta. Lee la explicación: entender por qué importa es parte de la misión.", false)
	_refrescar()
	_vista_archivo()
func _vista_taller() -> void:
	var fila := _nueva_fila()
	var cat := _panel(fila)
	cat.add_child(_titulo("Catálogo de componentes", 22))
	var filtro := OptionButton.new()
	filtro.add_item("Todas las categorías")
	var sel := 0
	for i in range(CATEGORIAS.size()):
		filtro.add_item(CAT_NOMBRE[CATEGORIAS[i]])
		if CATEGORIAS[i] == _filtro:
			sel = i + 1
	filtro.select(sel)
	filtro.item_selected.connect(_on_filtro)
	cat.add_child(filtro)
	for i in range(_plantillas.size()):
		var c := _plantillas[i]
		if _filtro != "" and c.categoria != _filtro:
			continue
		var h := _fila_panel(cat, COL_FILA, CAT_COL[c.categoria])
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		h.add_child(info)
		info.add_child(_lbl(_nombre(c), 17, Color(0.85, 0.9, 1.0), true))
		info.add_child(_chips(c))
		info.add_child(_lbl(c.descripcion, 13, Color(0.6, 0.65, 0.8), true))
		var b := _btn("Agregar", _agregar.bind(i))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	_lista_nave = _panel(fila)
	_llenar_nave()
func _on_filtro(i: int) -> void:
	_filtro = "" if i == 0 else CATEGORIAS[i - 1]
	_vista_taller()
func _llenar_nave() -> void:
	_limpiar(_lista_nave)
	_lista_nave.add_child(_titulo("Tu nave", 22))
	_lista_nave.add_child(_vista_nave(170))
	if GameState.componentes.is_empty():
		_lista_nave.add_child(_lbl("Aún no hay piezas. Agrega componentes del catálogo.", 15, COL_SUAVE, true))
	for c in GameState.componentes:
		var h := _fila_panel(_lista_nave, COL_FILA, CAT_COL[c.categoria])
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		h.add_child(info)
		info.add_child(_lbl(_nombre(c), 16, Color.WHITE, true))
		info.add_child(_chips(c))
		var b := _btn("Quitar", _quitar.bind(c))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	_lista_nave.add_child(HSeparator.new())
	_lista_nave.add_child(_titulo("Requisitos del destino", 18))
	if _req_visibles():
		for req in DESTINOS[_dest()]["req"]:
			var tiene := _cumple(req)
			_lista_nave.add_child(_lbl(("[OK] " if tiene else "[  ] ") + CAT_NOMBRE[req], 15, COL_OK if tiene else COL_AVISO))
	else:
		_lista_nave.add_child(_lbl("??? No sabes qué necesita este destino. Visita el Archivo de misión.", 15, COL_AVISO, true))
	var v := _validar()
	for a in v["avisos"]:
		_lista_nave.add_child(_lbl("Aviso: " + String(a), 14, COL_AVISO, true))
	_lista_nave.add_child(_lbl("Valor científico estimado: %s" % _num(ciencia_estimada()), 15, COL_OK))
func _agregar(i: int) -> void:
	var c := _crear(CATALOGO[i])
	if c.categoria == "estructura" and _cuenta("estructura") > 0:
		_msg("Solo cabe una estructura. Quita la actual primero.", false)
		return
	if GameState.masa_total() + c.masa_kg > _masa_max():
		_msg("Esa pieza te pasa del límite de masa (%s kg)." % _num(_masa_max()), false)
		return
	if not GameState.agregar(c):
		_msg("No alcanza el presupuesto para: " + c.nombre, false)
		return
	_msg("Agregaste: " + c.nombre, true)
	_refrescar()
	_llenar_nave()
func _quitar(c: ComponentData) -> void:
	GameState.quitar(c)
	_msg("Quitaste: " + c.nombre, true)
	_refrescar()
	_llenar_nave()
func _vista_presupuesto() -> void:
	var fila := _nueva_fila()
	var base := GameState.presupuesto_inicial_taller
	var izq := _panel(fila)
	izq.add_child(_titulo("Oficina de presupuesto", 22))
	izq.add_child(_lbl("Rol sugerido: Finanzas. Negocia fondos con la agencia. Cada intento cuesta 1 día.", 14, COL_SUAVE, true))
	if GameState.nivel_actual() == "facil":
		izq.add_child(_lbl("En Fácil el presupuesto es holgado, pero puedes practicar la negociación.", 14, COL_SUAVE, true))
	izq.add_child(HSeparator.new())
	izq.add_child(_lbl("Presupuesto inicial: %s" % _num(base), 17))
	izq.add_child(_lbl("Fondos extra obtenidos: %s" % _signo(float(est["extra"])), 17, COL_OK if float(est["extra"]) >= 0.0 else COL_MAL))
	izq.add_child(_lbl("Gastado en pruebas: -%s" % _num(float(est["gasto_pruebas"])), 17, COL_AVISO))
	izq.add_child(_lbl("Presupuesto total ahora: %s" % _num(GameState.presupuesto_max), 18, Color(0.7, 0.8, 1.0)))
	izq.add_child(_lbl("Ya comprometido en la nave: %s" % _num(GameState.costo_total()), 17))
	izq.add_child(_lbl("Disponible: %s" % _num(GameState.presupuesto_max - GameState.costo_total()), 18, COL_OK))
	var bp := ProgressBar.new()
	bp.show_percentage = false
	bp.custom_minimum_size = Vector2(0, 16)
	bp.max_value = maxf(GameState.presupuesto_max, 1.0)
	bp.value = GameState.costo_total()
	bp.modulate = COL_MAL if GameState.costo_total() > GameState.presupuesto_max else Color(0.6, 1.0, 0.7)
	izq.add_child(bp)
	var der := _panel(fila)
	der.add_child(_titulo("Negociar fondos", 22))
	var quedan: int = MAX_NEGOCIACIONES - int(est["negociaciones"])
	der.add_child(_lbl("Intentos restantes: %d" % quedan, 16, COL_AVISO))
	der.add_child(_lbl("Mientras más investigaste en el Archivo, más convincente eres.", 14, COL_SUAVE, true))
	var saber := GameState.nivel_actual() != "dificil"
	var t0 := "%d %%" % int(roundf(_prob_negociacion(0) * 100.0)) if saber else "???"
	var t1 := "%d %%" % int(roundf(_prob_negociacion(1) * 100.0)) if saber else "???"
	der.add_child(_btn("Justificación científica documentada: +15 %%  (éxito: %s)" % t0, _negociar.bind(0), quedan > 0))
	der.add_child(_btn("Pedir una ampliación grande: +35 %%  (éxito: %s, si falla pierdes 5 %%)" % t1, _negociar.bind(1), quedan > 0))
	der.add_child(_lbl("Aciertos en el Archivo: %d de 3" % _correctas(), 14, COL_SUAVE))
func _prob_negociacion(opcion: int) -> float:
	var c := float(_correctas())
	if opcion == 0:
		return clampf(0.55 + 0.12 * c, 0.0, 0.95)
	return clampf(0.2 + 0.1 * c, 0.0, 0.6)
func _negociar(opcion: int) -> void:
	if int(est["negociaciones"]) >= MAX_NEGOCIACIONES:
		return
	if not _dias_ok(1):
		_msg("No te quedan días de preparación para negociar.", false)
		return
	_gastar_dias(1)
	est["negociaciones"] = int(est["negociaciones"]) + 1
	var base := GameState.presupuesto_inicial_taller
	var prob := _prob_negociacion(opcion)
	var ganancia := base * (0.15 if opcion == 0 else 0.35)
	var perdida := 0.0 if opcion == 0 else base * 0.05
	if randf() < prob:
		GameState.presupuesto_max += ganancia
		est["extra"] = float(est["extra"]) + ganancia
		_msg("¡Aprobado! La agencia te da %s de presupuesto extra." % _num(ganancia), true)
	else:
		var p := minf(perdida, GameState.presupuesto_max - GameState.costo_total())
		GameState.presupuesto_max -= p
		est["extra"] = float(est["extra"]) - p
		if p > 0.0:
			_msg("Rechazado, y pierdes %s de credibilidad (presupuesto)." % _num(p), false)
		else:
			_msg("La agencia rechazó la solicitud.", false)
	GameState.recursos_cambiaron.emit()
	_refrescar()
	_vista_presupuesto()
func _vista_simulador() -> void:
	var fila := _nueva_fila()
	var izq := _panel(fila)
	izq.add_child(_titulo("Simulador de pruebas", 22))
	izq.add_child(_lbl("Prueba tus piezas para encontrar y corregir sus fallas. Cada prueba cuesta 1 día y un poco de presupuesto. Máximo %d pruebas por pieza." % MAX_PRUEBAS, 14, COL_SUAVE, true))
	if GameState.componentes.is_empty():
		izq.add_child(_lbl("Primero ensambla piezas en el Taller de ingeniería.", 16, COL_AVISO, true))
	for c in GameState.componentes:
		var n := int(c.get_meta("pruebas", 0))
		var h := _fila_panel(izq, COL_FILA, CAT_COL[c.categoria])
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		h.add_child(info)
		info.add_child(_lbl(_nombre(c), 16, Color.WHITE, true))
		var chips := _flujo()
		var rc := COL_SUAVE
		if _riesgo_visible(c):
			rc = _col_riesgo(c.riesgo_falla)
		chips.add_child(_chip("Riesgo de falla: %s" % _txt_riesgo(c), rc))
		chips.add_child(_chip("Pruebas: %d de %d" % [n, MAX_PRUEBAS], COL_OK if n >= MAX_PRUEBAS else Color(0.7, 0.8, 1.0)))
		info.add_child(chips)
		var costo := maxf(2.0, roundf(c.costo * 0.1))
		var b := _btn("Probar (%s)" % _num(costo), _probar.bind(c), n < MAX_PRUEBAS)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	var der := _panel(fila)
	der.add_child(_titulo("¿Cómo funciona?", 20))
	der.add_child(_vista_nave(150))
	der.add_child(_lbl("Una prueba revela el riesgo real de la pieza y lo reduce (40 % la primera vez, 25 % la segunda).", 15, Color.WHITE, true))
	der.add_child(_lbl("En Difícil los riesgos aparecen como ??? hasta que los investigas. Quien no investiga falla en tránsito.", 15, COL_AVISO, true))
	var fiab := _fiabilidad()
	var f_txt := "???" if fiab < 0.0 else "%d %%" % int(roundf(fiab * 100.0))
	der.add_child(_lbl("Fiabilidad estimada de la misión: " + f_txt, 17, COL_OK))
	der.add_child(_lbl("Gastado en pruebas: %s" % _num(float(est["gasto_pruebas"])), 15, COL_AVISO))
func _probar(c: ComponentData) -> void:
	var n := int(c.get_meta("pruebas", 0))
	if n >= MAX_PRUEBAS:
		return
	var costo := maxf(2.0, roundf(c.costo * 0.1))
	if not _dias_ok(1):
		_msg("No te quedan días de preparación para más pruebas.", false)
		return
	if GameState.presupuesto_max - costo < GameState.costo_total():
		_msg("No hay fondos disponibles para esta prueba (%s)." % _num(costo), false)
		return
	_gastar_dias(1)
	GameState.presupuesto_max -= costo
	est["gasto_pruebas"] = float(est["gasto_pruebas"]) + costo
	var antes := c.riesgo_falla
	c.riesgo_falla *= (0.6 if n == 0 else 0.75)
	c.set_meta("pruebas", n + 1)
	c.set_meta("investigado", true)
	GameState.recursos_cambiaron.emit()
	_msg("%s: el riesgo bajó de %d %% a %d %%." % [c.nombre, int(roundf(antes * 100.0)), int(roundf(c.riesgo_falla * 100.0))], true)
	_refrescar()
	_vista_simulador()
func _vista_mapa() -> void:
	var fila := _nueva_fila()
	var dk := _dest()
	var rutas: Array = _rutas(dk)
	var fija: bool = bool(est.get("ruta_fija", false))
	var izq := _panel(fila)
	izq.add_child(_titulo("Mapa de rutas: " + String(DESTINOS[dk]["nombre"]), 22))
	izq.add_child(_lbl("Compara tiempo, combustible (Δv) y riesgo. Tu nave debe tener propulsión suficiente: ahora suma %s m/s." % _num(dv_total()), 14, COL_SUAVE, true))
	var vr := VistaRuta.new()
	vr.destino = dk
	vr.nombre = String(DESTINOS[dk]["nombre"])
	vr.col_dest = DEST_COL[dk]
	vr.elegida = int(est["ruta_idx"])
	if vr.elegida >= 0:
		vr.alcanza = dv_total() >= float(rutas[vr.elegida]["dv"])
	vr.custom_minimum_size = Vector2(0, 150)
	izq.add_child(vr)
	if fija:
		izq.add_child(_lbl("Esta ruta la elegiste en la Fase 1 (su costo ya salió de tu presupuesto). Aquí solo compruebas que tu nave pueda recorrerla. Para cambiarla, vuelve a la sala de Planificación: el laboratorio se reiniciará.", 14, COL_AVISO, true))
	var visible_r := _riesgo_ruta_visible()
	for i in range(rutas.size()):
		var r: Dictionary = rutas[i]
		var elegida: bool = int(est["ruta_idx"]) == i
		var h := _fila_panel(izq, COL_FILA_SEL if elegida else COL_FILA, ESTACION_COL[E_MAPA] if elegida else Color(0, 0, 0, 0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		h.add_child(info)
		info.add_child(_lbl(r["n"], 17, Color(0.85, 0.9, 1.0), true))
		var riesgo_txt := "%d %%" % int(roundf(float(r["r"]) * 100.0)) if visible_r else "???"
		var tiempo := "%d días" % int(r["dias"]) if int(r["dias"]) > 0 else "menos de 1 día"
		var alcanza := dv_total() >= float(r["dv"])
		var chips := _flujo()
		chips.add_child(_chip("Tiempo: " + tiempo, Color(0.7, 0.8, 1.0)))
		chips.add_child(_chip("Δv %s m/s" % _num(float(r["dv"])), Color(1.0, 0.7, 0.9)))
		chips.add_child(_chip("Riesgo %s" % riesgo_txt, _col_riesgo(float(r["r"])) if visible_r else COL_SUAVE))
		info.add_child(chips)
		info.add_child(_lbl(("Tu propulsión alcanza." if alcanza else "Tu propulsión NO alcanza todavía."), 13, COL_OK if alcanza else COL_AVISO, true))
		info.add_child(_lbl(r["nota"], 13, Color(0.6, 0.65, 0.8), true))
		var texto_btn := "Elegida" if elegida else ("Otra ruta" if fija else "Elegir ruta")
		var b := _btn(texto_btn, _elegir_ruta.bind(i), not elegida and not fija)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	if not visible_r:
		izq.add_child(_lbl("Los riesgos de ruta aparecen como ??? hasta que aciertes al menos 2 preguntas del Archivo de misión.", 14, COL_AVISO, true))
func _elegir_ruta(i: int) -> void:
	if bool(est.get("ruta_fija", false)):
		return   # la ruta ya quedó fijada en la Fase 1
	est["ruta_idx"] = i
	est["ambiguo"] = false
	_msg("Ruta elegida: " + String(_rutas(_dest())[i]["n"]), true)
	_refrescar()
	_vista_mapa()
func _finalizar() -> void:
	var v := _validar()
	var bl: Array = v["bloqueos"]
	if not bl.is_empty():
		return
	var r := _ruta_actual()
	GameState.ruta = String(r["n"])   # misma ruta que la Fase 1: las fases 3 a 5 la leen de aquí
	GameState.set_meta("lab_resumen", {
		"destino": _dest(),
		"ruta": r["n"],
		"dias_ruta": int(r["dias"]),
		"riesgo_ruta": float(r["r"]),
		"dv_disponible": dv_total(),
		"energia_generada": energia_generada(),
		"energia_consumida": energia_consumida(),
		"datos_mbps": datos_total(),
		"enlace_mbps": enlace_efectivo(),
		"ciencia": ciencia_estimada(),
		"faltantes": v["faltantes"],   # requisitos que no investigaste (solo Difícil)
	})
	est["completada"] = true
	GameState.set_meta("lab_estado", est)
	_mostrar_minijuego()

# ======================================================================
#   MINIJUEGO: CENTRO DE CONTROL DE MISIÓN (4 etapas + resultado)
# ======================================================================
func _mostrar_minijuego() -> void:
	_minijuego_activo = true
	_mj_etapa = 0
	_mj_puntos.clear()
	for tab in _botones_tab:
		tab.disabled = true
	_btn_fin.disabled = true
	_btn_reiniciar.disabled = true
	_lbl_msg.text = "Último procedimiento: operaciones del centro de control."
	_lbl_msg.add_theme_color_override("font_color", COL_AVISO)
	_mj_et_motor()

func _mj_siguiente() -> void:
	if not is_inside_tree():
		return
	_mj_etapa += 1
	match _mj_etapa:
		1: _mj_et_energia()
		2: _mj_et_falla()
		3: _mj_et_antena()
		_: _mj_resultado()

# ---------- base visual compartida ----------
func _mj_pips() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in range(4):
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(46, 6)
		if i < _mj_etapa:
			r.color = COL_OK
		elif i == _mj_etapa:
			r.color = COL_AVISO
		else:
			r.color = Color(0.25, 0.25, 0.4)
		h.add_child(r)
	return h

func _mj_base(titulo: String, texto: String, eclipse: bool = false, alerta: bool = false) -> VBoxContainer:
	_limpiar(_cuerpo)
	_mj_modo_barra = false
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _caja(COL_PANEL, 24))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cuerpo.add_child(panel)
	_fade(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var centro := VBoxContainer.new()
	centro.add_theme_constant_override("separation", 14)
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(centro)
	centro.add_child(_mj_pips())
	centro.add_child(_titulo(titulo, 23, Color(0.7, 0.85, 1.0)))
	centro.add_child(_vista_nave(120, eclipse, alerta))
	centro.add_child(_lbl(texto, 15, COL_SUAVE, true))
	return centro

func _mj_titulo_etapa() -> String:
	return "SIMULACIÓN DENTRO DEL LABORATORIO  ·  ETAPA %d/4: %s" % [_mj_etapa + 1, String(ETAPAS_MJ[_mj_etapa]).to_upper()]

# ---------- etapas con barra (1 y 4) ----------
func _mj_construir_barra(c: VBoxContainer, texto_btn: String) -> void:
	_mj_aciertos = 0
	_mj_intentos = 0
	_senal = 0.0
	_direccion = 1.0
	_barra = BarraSenal.new()
	_barra.custom_minimum_size = Vector2(0, 40)
	_barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(_barra)
	_mj_nueva_ventana()
	_lbl_aux = _lbl("Aciertos: 0 / 3", 18, COL_OK)
	_lbl_aux.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_lbl_aux)
	_lbl_mj = _lbl("Pulsa cuando el indicador amarillo esté dentro de la zona verde.", 16, Color.WHITE, true)
	_lbl_mj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_lbl_mj)
	_btn_mj = _btn(texto_btn, _mj_pulsar)
	_btn_mj.custom_minimum_size = Vector2(240, 48)
	c.add_child(_btn_mj)
	_mj_modo_barra = true

func _mj_nueva_ventana() -> void:
	_centro_obj = randf_range(25.0 + _ancho / 2.0, 90.0 - _ancho / 2.0)
	if is_instance_valid(_barra):
		_barra.vmin = _centro_obj - _ancho / 2.0
		_barra.vmax = _centro_obj + _ancho / 2.0

func _mj_pulsar() -> void:
	if not _mj_modo_barra:
		return
	_mj_intentos += 1
	if absf(_senal - _centro_obj) <= _ancho / 2.0:
		_mj_aciertos += 1
		_barra.flash = 1.0
		_barra.flash_col = Color(0.4, 1.0, 0.5)
		_lbl_aux.text = "Aciertos: %d / 3" % _mj_aciertos
		_lbl_mj.text = "¡Dentro de la ventana!"
		_lbl_mj.add_theme_color_override("font_color", COL_OK)
		if _mj_aciertos >= 3:
			_mj_modo_barra = false
			_btn_mj.disabled = true
			_mj_puntos.append(clampf(3.0 / float(_mj_intentos), 0.0, 1.0))
			_lbl_mj.text = "Etapa completada con %d intentos." % _mj_intentos
			await get_tree().create_timer(1.1).timeout
			_mj_siguiente()
			return
		_mj_nueva_ventana()
	else:
		_barra.flash = 1.0
		_barra.flash_col = Color(1.0, 0.4, 0.4)
		_lbl_mj.text = "Fuera de la ventana (%.0f %%). Espera mejor momento." % _senal
		_lbl_mj.add_theme_color_override("font_color", COL_MAL)

func _mj_et_motor() -> void:
	var r := _ruta_actual()
	var req := float(r["dv"])
	var margen := clampf((dv_total() - req) / maxf(req, 300.0), 0.0, 1.0)
	var dif: Array = MJ_DIF[_dest()]
	_velocidad_senal = float(dif[0])
	_ancho = float(dif[1]) + 10.0 * margen
	var c := _mj_base(_mj_titulo_etapa(),
		"Ruta: %s. Tu nave tiene %s m/s de Δv y la ruta pide %s. Más margen de combustible = ventana de ignición más ancha. Logra 3 encendidos precisos." % [r["n"], _num(dv_total()), _num(req)])
	_mj_construir_barra(c, "ENCENDER MOTOR")

func _mj_et_antena() -> void:
	var datos := datos_total()
	var ratio := 1.0 if datos <= 0.0 else clampf(enlace_efectivo() / datos, 0.0, 1.0)
	var dif: Array = MJ_DIF[_dest()]
	_velocidad_senal = float(dif[0]) * 1.1
	_ancho = float(dif[1]) * (0.6 + 0.8 * ratio)
	var c := _mj_base(_mj_titulo_etapa(),
		"Tu enlace efectivo es %s Mbps para %s Mbps de datos (%d %% de capacidad). Si tu antena es corta para tus instrumentos, la ventana de sincronía se estrecha. Logra 3 transmisiones." % [_num(enlace_efectivo()), _num(datos), int(roundf(ratio * 100.0))])
	_mj_construir_barra(c, "TRANSMITIR")

# ---------- etapa 2: balance de energía en eclipse ----------
func _mj_instrumentos() -> Array[ComponentData]:
	var l: Array[ComponentData] = []
	for c in GameState.componentes:
		if c.categoria == "instrumento":
			l.append(c)
	return l

func _mj_consumo_base() -> float:
	var t := 0.0
	for c in GameState.componentes:
		if ESENCIALES.has(c.categoria) and c.energia_w < 0.0:
			t += -c.energia_w
	return t

func _mj_disponible() -> float:
	var g := 0.0
	for c in GameState.componentes:
		if c.energia_w > 0.0 and not c.get_meta("solar", false):
			g += c.energia_w
	return maxf(g, _mj_consumo_base())

func _mj_consumo() -> float:
	var t := _mj_consumo_base()
	for c in _mj_instrumentos():
		if not _mj_apagados.has(c):
			t += -c.energia_w
	return t

func _mj_ciencia_activa() -> float:
	var s := 0.0
	for c in _mj_instrumentos():
		if not _mj_apagados.has(c):
			s += float(c.get_meta("ciencia", 0.0))
	return s

func _mj_ciencia_optima() -> float:
	var inst := _mj_instrumentos()
	var n := mini(inst.size(), 12)
	var libre := _mj_disponible() - _mj_consumo_base()
	var mejor := 0.0
	for mask in range(1 << n):
		var w := 0.0
		var s := 0.0
		for i in range(n):
			if mask & (1 << i):
				w += -inst[i].energia_w
				s += float(inst[i].get_meta("ciencia", 0.0))
		if w <= libre + 0.001 and s > mejor:
			mejor = s
	return mejor

func _mj_et_energia() -> void:
	_mj_apagados.clear()
	var c := _mj_base(_mj_titulo_etapa(),
		"La nave entra en eclipse: los paneles solares no generan. Solo cuentan las fuentes que no dependen del Sol (baterías, RTG). Apaga instrumentos hasta que el consumo no supere la energía disponible, conservando la mayor ciencia posible.", true)
	_lbl_mj = _lbl("", 17, COL_OK, true)
	c.add_child(_lbl_mj)
	_mj_gauge = ProgressBar.new()
	_mj_gauge.show_percentage = false
	_mj_gauge.custom_minimum_size = Vector2(0, 20)
	_mj_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(_mj_gauge)
	var inst := _mj_instrumentos()
	if inst.is_empty():
		c.add_child(_lbl("No llevas instrumentos que apagar.", 15, COL_SUAVE))
	for ins in inst:
		var cb := CheckButton.new()
		cb.text = "%s   (%s W, ciencia %s)" % [ins.nombre, _num(ins.energia_w), _num(float(ins.get_meta("ciencia", 0.0)))]
		cb.button_pressed = true
		cb.toggled.connect(_mj_toggle.bind(ins))
		c.add_child(cb)
	_btn_mj = _btn("CONFIRMAR CONFIGURACIÓN", _mj_confirmar_energia)
	_btn_mj.custom_minimum_size = Vector2(280, 46)
	c.add_child(_btn_mj)
	_mj_energia_refrescar()

func _mj_toggle(encendido: bool, c: ComponentData) -> void:
	if encendido:
		_mj_apagados.erase(c)
	else:
		_mj_apagados[c] = true
	_mj_energia_refrescar()

func _mj_energia_refrescar() -> void:
	var con := _mj_consumo()
	var disp := _mj_disponible()
	var ok := con <= disp + 0.001
	_lbl_mj.text = "Consumo en eclipse: %s W / Disponible: %s W   |   Ciencia activa: %s" % [_num(con), _num(disp), _num(_mj_ciencia_activa())]
	_lbl_mj.add_theme_color_override("font_color", COL_OK if ok else COL_MAL)
	_mj_gauge.max_value = maxf(disp, 1.0)
	_mj_gauge.value = con
	_mj_gauge.modulate = Color(0.6, 1.0, 0.7) if ok else COL_MAL
	_btn_mj.disabled = not ok

func _mj_confirmar_energia() -> void:
	var opt := _mj_ciencia_optima()
	var act := _mj_ciencia_activa()
	var p := 1.0 if opt <= 0.0 else clampf(act / opt, 0.0, 1.0)
	_mj_puntos.append(p)
	_btn_mj.disabled = true
	_lbl_mj.text = "Conservaste %s de %s de ciencia posible durante el eclipse." % [_num(act), _num(opt)]
	_lbl_mj.add_theme_color_override("font_color", COL_OK if p >= 0.99 else COL_AVISO)
	await get_tree().create_timer(2.0).timeout
	_mj_siguiente()

# ---------- etapa 3: anomalía ----------
func _mj_elegir_falla() -> ComponentData:
	var total := 0.0
	for c in GameState.componentes:
		total += c.riesgo_falla
	if total <= 0.0:
		return GameState.componentes[randi() % GameState.componentes.size()]
	var r := randf() * total
	for c in GameState.componentes:
		r -= c.riesgo_falla
		if r <= 0.0:
			return c
	return GameState.componentes.back()

func _mj_et_falla() -> void:
	_mj_falla_comp = _mj_elegir_falla()
	_mj_falla_fallos = 0
	_mj_falla_btns.clear()
	var datos: Dictionary = FALLAS[_mj_falla_comp.categoria]
	var c := _mj_base(_mj_titulo_etapa(), "Llega una alerta desde la nave. Decide la respuesta del equipo de vuelo.", false, true)
	c.add_child(_lbl("ALERTA en: %s" % _mj_falla_comp.nombre, 19, COL_AVISO, true))
	c.add_child(_lbl(datos["t"], 17, Color.WHITE, true))
	c.add_child(_lbl("Riesgo de falla de esta pieza: %s" % _txt_riesgo(_mj_falla_comp), 14, COL_SUAVE, true))
	var orden: Array[int] = [0, 1, 2]
	orden.shuffle()
	var descartada := -1
	if int(_mj_falla_comp.get_meta("pruebas", 0)) > 0:
		for i in orden:
			if i != 0:
				descartada = i
				break
		c.add_child(_lbl("Tus pruebas en el Simulador descartaron una respuesta.", 14, COL_OK, true))
	for i in orden:
		if i == descartada:
			continue
		var b := Button.new()
		b.text = datos["o"][i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_mj_responder_falla.bind(i, b))
		c.add_child(b)
		_mj_falla_btns.append(b)
	_lbl_mj = _lbl("", 15, Color.WHITE, true)
	c.add_child(_lbl_mj)
	_btn_continuar = _btn("CONTINUAR", _mj_siguiente, false)
	_btn_continuar.custom_minimum_size = Vector2(220, 44)
	c.add_child(_btn_continuar)

func _mj_responder_falla(i: int, b: Button) -> void:
	var datos: Dictionary = FALLAS[_mj_falla_comp.categoria]
	if i == 0:
		var p := clampf(1.0 - 0.5 * float(_mj_falla_fallos), 0.0, 1.0)
		_mj_puntos.append(p)
		_lbl_mj.text = "Correcto. " + String(datos["e"])
		_lbl_mj.add_theme_color_override("font_color", COL_OK)
		_mj_cerrar_falla()
	else:
		_mj_falla_fallos += 1
		b.disabled = true
		if _mj_falla_fallos >= 2:
			_mj_puntos.append(0.0)
			_lbl_mj.text = "Respuesta incorrecta. La correcta era: %s\n%s" % [datos["o"][0], datos["e"]]
			_lbl_mj.add_theme_color_override("font_color", COL_MAL)
			_mj_cerrar_falla()
		else:
			_lbl_mj.text = "Esa respuesta empeoraría la situación. Te queda un intento."
			_lbl_mj.add_theme_color_override("font_color", COL_MAL)

func _mj_cerrar_falla() -> void:
	for b in _mj_falla_btns:
		b.disabled = true
	_btn_continuar.disabled = false

# ---------- resultado ----------
func _mj_resultado() -> void:
	var total := 0.0
	for p in _mj_puntos:
		total += p
	var nota := roundf(100.0 * total / float(maxi(_mj_puntos.size(), 1)))
	var veredicto := "Simulación con problemas"
	var col := COL_MAL
	if nota >= 85.0:
		veredicto = "Simulación ejemplar"
		col = COL_OK
	elif nota >= 60.0:
		veredicto = "Simulación exitosa"
		col = COL_AVISO
	var c := _mj_base("RESULTADO DE LAS OPERACIONES DENTRO DE LA SIMULACION", "Así le fue a tu nave en sus primeros eventos de simulacón de vuelo.")
	for i in range(_mj_puntos.size()):
		var f := HBoxContainer.new()
		f.add_theme_constant_override("separation", 10)
		var ln := _lbl(String(ETAPAS_MJ[i]), 16, Color.WHITE)
		ln.custom_minimum_size = Vector2(250, 0)
		f.add_child(ln)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.max_value = 100.0
		pb.value = _mj_puntos[i] * 100.0
		pb.custom_minimum_size = Vector2(0, 16)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.modulate = COL_OK if _mj_puntos[i] >= 0.7 else (COL_AVISO if _mj_puntos[i] >= 0.4 else COL_MAL)
		f.add_child(pb)
		f.add_child(_lbl("%d %%" % int(roundf(_mj_puntos[i] * 100.0)), 15, Color.WHITE))
		c.add_child(f)
	var lbl_nota := _titulo("%s  (0 / 100)" % veredicto, 26, col)
	c.add_child(lbl_nota)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(lbl_nota):
			lbl_nota.text = "%s  (%d / 100)" % [veredicto, int(v)], 0.0, nota, 1.2)
	var resumen = GameState.get_meta("lab_resumen", {})
	if resumen is Dictionary:
		resumen["ops_puntaje"] = nota
		GameState.set_meta("lab_resumen", resumen)
	GameState.set_meta("lab_minijuego", {"puntaje": nota, "etapas": _mj_puntos.duplicate()})
	_btn_continuar = _btn("CONTINUAR A LA SIGUIENTE FASE", _salir_minijuego)
	_btn_continuar.custom_minimum_size = Vector2(300, 46)
	c.add_child(_btn_continuar)
	_lbl_msg.text = "Laboratorio completado. Puedes continuar."
	_lbl_msg.add_theme_color_override("font_color", COL_OK)

func _salir_minijuego() -> void:
	_minijuego_activo = false
	terminar()

func _reiniciar_lab() -> void:
	GameState.componentes.clear()
	GameState.presupuesto_max = GameState.presupuesto_inicial_taller
	GameState.recursos_cambiaron.emit()
	est = _estado_nuevo()
	GameState.set_meta("lab_estado", est)
	_ir_a(E_ARCHIVO)
	_msg("Laboratorio reiniciado.", true)
func _crear_vista_astro_3d(dk: String) -> Control:
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", _caja(Color(0.02, 0.02, 0.07), 2))
	marco.custom_minimum_size = Vector2(0, 175)
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(contenedor)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(vp)

	var escena_3d: Node3D = ESCENA_FONDO_3D.instantiate() as Node3D
	vp.add_child(escena_3d)

	var mapa_astros := {
		"tierra": "AstroTierra",
		"luna": "AstroLuna",
		"marte": "AstroMarte",
		"jupiter": "AstroJupiter",
		"sol": "AstroSol",
	}
	for clave in mapa_astros.keys():
		var malla: MeshInstance3D = escena_3d.find_child(mapa_astros[clave], true, false) as MeshInstance3D
		if malla != null:
			malla.visible = false

	var nombre_objetivo: String = mapa_astros.get(dk, "AstroTierra")
	_astro_vista_3d = escena_3d.find_child(nombre_objetivo, true, false) as MeshInstance3D
	if _astro_vista_3d != null:
		_astro_vista_3d.visible = true

	return marco
