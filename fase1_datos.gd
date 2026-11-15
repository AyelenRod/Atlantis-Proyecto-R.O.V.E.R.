extends RefCounted
## Datos de la Fase 1: niveles, destinos, roles, rutas de imágenes y Datos de prueba.

const MODO_PRUEBA := true

const FASES := ["Sala de planificación", "Sala de laboratorio", "Sala de lanzamiento", "Sala de operación", "Sala de resultados"]
const ROLES := ["Planificador", "Ingeniero", "Finanzas", "Astronauta"]
const ROL_INFO := {
	"Planificador": "Sala de planificación: destino, ruta y requisitos. En el Laboratorio revisa el Mapa de rutas.",
	"Ingeniero": "Laboratorio: arma la nave en el Taller y la prueba en el Simulador.",
	"Finanzas": "Laboratorio: Oficina de presupuesto y negociaciones; aprueba el gasto antes de confirmar la nave.",
	"Astronauta": "Sala de lanzamiento (decisiones del tránsito) y Sala de operación (pilota el minijuego).",
}
## Responsable de cada fase (índice 0-4).
const ROLES_POR_FASE := [
	["Planificador"],
	["Ingeniero", "Finanzas"],
	["Astronauta"],
	["Astronauta"],
	[],
]
## El modo equipo solo está disponible en estas dificultades.
const NIVELES_EQUIPO := ["medio", "dificil"]
const ORDEN_NIVELES := ["facil", "medio", "dificil"]

# Imágenes (carpeta res://img/).
const IMG := {
	"satelite": "res://img/satelite.png",
	"astronauta_morado": "res://img/astronauta_morado.png",
	"astronauta_amarillo": "res://img/astronauta_amarillo.png",
	"astronauta_bandera": "res://img/astronauta_bandera.png",
	"ovni": "res://img/ovni.png",
	"cohete": "res://img/cohete.png",
	"cohete_horizontal": "res://img/cohete_horizontal.png",
}

# Valores de ejemplo: ajústenlos entre todos.
# presupuesto = -1  -> libre (sin límite)   |   dias = -1 -> ilimitado
# info_oculta       -> fracción de datos/riesgos que salen como "???" hasta investigarlos
const NIVELES := {
	"facil": {
		"nombre": "Fácil",
		"resumen": "Ideal para aprender: casi toda la información está visible y no hay prisa.",
		"destinos": {
			"Órbita terrestre": {
				"objetivo": "Poner un satélite de observación en órbita alrededor de la Tierra y operarlo.",
				"nota": "Cerca y con comunicaciones rápidas: el mejor lugar para aprender.",
			},
		},
		"presupuesto": -1,
		"dias": -1,
		"info_oculta": 0.1,
		"eventos": 1,
		"txt_presupuesto": "Libre",
		"txt_info": "Casi toda visible",
		"txt_eventos": "1 simple",
		"txt_tiempo": "Ilimitado",
	},
	"medio": {
		"nombre": "Medio",
		"resumen": "Presupuesto y tiempo justos, y parte de la información viene oculta.",
		"destinos": {
			"Luna": {
				"objetivo": "Aterrizar en la Luna y ejecutar una misión científica en su superficie.",
				"nota": "Viaje corto (unos días), pero el aterrizaje no perdona errores.",
			},
			"Marte": {
				"objetivo": "Llegar a Marte, aterrizar y operar instrumentos en su superficie.",
				"nota": "Viaje de meses: necesita mucho combustible y comunicaciones con retraso.",
			},
		},
		"presupuesto": 930,
		"dias": 10,
		"info_oculta": 0.5,
		"eventos": 3,
		"txt_presupuesto": "Ajustado",
		"txt_info": "Parte oculta",
		"txt_eventos": "2 o 3",
		"txt_tiempo": "Justo",
	},
	"dificil": {
		"nombre": "Difícil",
		"resumen": "Presupuesto muy ajustado, casi todo es \"???\" y los eventos pueden encadenarse.",
		"destinos": {
			"Órbita solar": {
				"objetivo": "Colocar una sonda en órbita cercana al Sol para estudiar su actividad.",
				"nota": "Calor extremo y trayectorias muy exigentes en combustible.",
			},
			"Júpiter": {
				"objetivo": "Llegar al sistema de Júpiter y estudiar el planeta y sus lunas.",
				"nota": "Muy lejos: poca energía solar, radiación intensa y años de viaje.",
			},
		},
		"presupuesto": 750,
		"dias": 7,
		"info_oculta": 0.9,
		"eventos": 5,
		"txt_presupuesto": "Muy ajustado",
		"txt_info": "Casi toda oculta",
		"txt_eventos": "4-6, algunos en cadena",
		"txt_tiempo": "Escaso",
	},
}

# RUTAS posibles hacia cada destino (se eligen en la sala de planificación).
#   costo  = millones que cuesta la ruta (se descuenta del presupuesto del nivel)
#   dias   = días de preparación que exige (el nivel pone un máximo)
#   viaje  = días de viaje real de la nave (lo usa el Laboratorio)
#   riesgo = probabilidad de falla de la ruta, de 0.0 a 1.0 (lo usa el Laboratorio)
# Cada nivel limita presupuesto y días (ver NIVELES): una ruta que se pasa de ese límite
# se puede ver, pero no se puede confirmar en el paso de requisitos.
# Todas las rutas dejan saldo suficiente para construir una nave válida (el presupuesto de cada nivel
# se calculó con la ruta más cara + la nave mínima del Laboratorio + un margen).
const RUTAS := {
	"Órbita terrestre": {
		"Órbita baja directa": {
			"desc": "Cohete directo a unos 500 km de altura. Rápida y barata, pero ve menos zonas de la Tierra.",
			"costo": 80, "dias": 2, "viaje": 0, "dv": 0, "riesgo": 0.02,
			"nota": "Fácil de alcanzar y con buena resolución de imagen, pero entra en sombra unas 16 veces al día.",
		},
		"Órbita polar": {
			"desc": "Pasa sobre toda la superficie terrestre, siempre a la misma hora local del Sol. Observa más, pero gasta más combustible.",
			"costo": 120, "dias": 3, "viaje": 0, "dv": 150, "riesgo": 0.03,
			"nota": "Pasa siempre a la misma hora local del Sol: ideal para comparar imágenes.",
		},
		"Órbita geoestacionaria": {
			"desc": "Se queda sobre el mismo punto del ecuador, a 36 000 km. Comunica sin parar, pero llegar cuesta mucho combustible.",
			"costo": 160, "dias": 4, "viaje": 1, "dv": 1500, "riesgo": 0.06,
			"nota": "Ve siempre el mismo punto y comunica sin parar, pero llegar cuesta mucho combustible.",
		},
	},
	"Luna": {
		"Transferencia directa": {
			"desc": "Viaje de unos 4 días directo a la Luna. Rápido, pero consume mucho combustible.",
			"costo": 380, "dias": 4, "viaje": 4, "dv": 900, "riesgo": 0.06,
			"nota": "Rápida, pero gasta bastante combustible.",
		},
		"Órbita lunar y descenso": {
			"desc": "Primero se orbita la Luna y luego se desciende. Muy segura, pero cara.",
			"costo": 460, "dias": 6, "viaje": 5, "dv": 1200, "riesgo": 0.08,
			"nota": "Permite ver todo el globo lunar, pero exige un frenado preciso.",
		},
		"Trayectoria de baja energía": {
			"desc": "Ruta lenta (meses) que aprovecha la gravedad para ahorrar combustible.",
			"costo": 300, "dias": 9, "viaje": 100, "dv": 600, "riesgo": 0.05,
			"nota": "Ahorra combustible aprovechando la gravedad, pero tarda meses.",
		},
	},
	"Marte": {
		"Transferencia de Hohmann": {
			"desc": "La ruta clásica: gasta poco combustible y espera la ventana de lanzamiento correcta.",
			"costo": 420, "dias": 8, "viaje": 260, "dv": 1800, "riesgo": 0.08,
			"nota": "La más eficiente en general; tarda unos 9 meses.",
		},
		"Asistencia gravitatoria de la Tierra": {
			"desc": "Da una vuelta extra cerca de la Tierra para ganar velocidad. Ahorra combustible, pero exige más planificación.",
			"costo": 380, "dias": 10, "viaje": 330, "dv": 1400, "riesgo": 0.09,
			"nota": "Ahorra combustible dando una vuelta extra cerca de la Tierra.",
		},
		"Transferencia rápida": {
			"desc": "Menos meses de viaje, pero necesita un cohete enorme.",
			"costo": 560, "dias": 6, "viaje": 150, "dv": 3000, "riesgo": 0.10,
			"nota": "Llega antes, pero necesita mucho más combustible.",
		},
	},
	"Órbita solar": {
		"Asistencia de Venus": {
			"desc": "Un paso junto a Venus para frenar la sonda y caer hacia el Sol. Barata, pero requiere más preparación.",
			"costo": 250, "dias": 7, "viaje": 180, "dv": 1400, "riesgo": 0.10,
			"nota": "Venus ayuda a frenar y ahorra combustible.",
		},
		"Doble asistencia de Venus": {
			"desc": "Varios pasos junto a Venus para frenar y acercarse al Sol poco a poco.",
			"costo": 280, "dias": 5, "viaje": 300, "dv": 800, "riesgo": 0.09,
			"nota": "Casi no gasta combustible, pero tarda más y es más compleja de operar.",
		},
		"Frenado directo": {
			"desc": "Cancelar la velocidad de la Tierra para caer hacia el Sol. Exige muchísimo combustible.",
			"costo": 340, "dias": 4, "viaje": 120, "dv": 3000, "riesgo": 0.14,
			"nota": "Para caer hacia el Sol hay que frenar mucho: gasta combustible.",
		},
	},
	"Júpiter": {
		"Asistencia Marte-Tierra": {
			"desc": "Sobrevuelo de Marte y asistencia de la Tierra para llegar con el combustible justo.",
			"costo": 290, "dias": 5, "viaje": 1400, "dv": 2000, "riesgo": 0.11,
			"nota": "Un punto medio entre tiempo y combustible.",
		},
		"Transferencia directa": {
			"desc": "Lanzamiento directo a Júpiter. Más corto, pero necesita un cohete muy potente.",
			"costo": 330, "dias": 4, "viaje": 1000, "dv": 3800, "riesgo": 0.15,
			"nota": "Rápida pero muy costosa en combustible.",
		},
		"Asistencias Venus-Tierra-Tierra": {
			"desc": "La ruta que más combustible ahorra, pero con la preparación más larga.",
			"costo": 260, "dias": 6, "viaje": 1800, "dv": 1400, "riesgo": 0.12,
			"nota": "Tarda casi 5 años, pero ahorra mucho combustible.",
		},
	},
}

# DATOS DE PRUEBA: simulan lo que el juego ya eligió ANTES de entrar a la sala de planificación
# (modo, nivel y jugadores).
# En el juego real, el menú anterior llama a GameState.configurar_partida(modo, nivel, nombres).
const PRUEBA_ACTIVA := "equipo4_medio"
const PRUEBAS := {
	"solo_facil": {"modo": "solo", "nivel": "facil", "nombres": ["Ana"]},
	"equipo4_medio": {"modo": "equipo", "nivel": "medio", "nombres": ["Ana", "Luis", "Sofía", "Carlos"]},
	"equipo2_dificil": {"modo": "equipo", "nivel": "dificil", "nombres": ["Ana", "Luis"]},
}
