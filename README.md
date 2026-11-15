# Misión Espacial

**Misión Espacial** es un juego 2D hecho en Godot 4 para el NASA Space Apps Challenge 2026 (reto *Space Mission Design Game*).
Eres el equipo de una agencia espacial: planeas una misión, construyes la nave pieza por pieza, la lanzas, operas la llegada
y al final recibes un reporte que explica, con números, por qué tu misión funcionó o falló.

Creado por el equipo **Polipops** de la **Universidad Politécnica de Chiapas**.
Desarrollado por **Ayelen Rodríguez, Montserrat Nolasco, Melissa Castañón, Jonathan Meza y Bruno Cruz**.

## El juego en una partida

Recorres una estación orbital con tu astronauta. Cada módulo de la estación es una fase de la misión y sus compuertas se abren
conforme avanzas:

1. **Sala de planificación.** Eliges el destino de tu nivel, una ruta (cada una con costo, días de preparación, Δv y riesgo) y
   compruebas que cumpla los requisitos del nivel. Lo que no gastes en la ruta es el presupuesto de la nave.
2. **Laboratorio.** Cinco estaciones: Archivo de misión (investigas el destino), Oficina de presupuesto (negocias fondos),
   Taller (armas la nave con un catálogo de 25 piezas: estructuras, energía, comunicaciones, computadoras, propulsión, control
   térmico e instrumentos), Simulador (pruebas piezas para bajar su riesgo) y Mapa de rutas (verificas que tu propulsión alcance).
   La nave debe cerrar en energía, masa, presupuesto y Δv.
3. **Sala de lanzamiento.** La nave viaja sola mientras bajan el combustible y, con los eventos del tránsito (desviaciones,
   tormentas solares, micrometeoritos...), decides entre reparar o arriesgar. Más eventos en los niveles altos.
4. **Sala de operación.** Un minijuego de habilidad según tu destino: desplegar un satélite en órbita, aterrizar en la Luna y
   recoger muestras, posar un rover en Marte, sobrevolar la corona solar o esquivar asteroides y escanear las lunas de Júpiter.
5. **Sala de resultados.** Puntaje de 0 a 100 con ocho revisiones (presupuesto, energía, masa, sistemas críticos, fiabilidad,
   tránsito, operación y ciencia), estrellas, y una explicación de qué salió bien y qué falló.

## Niveles

| Nivel | Destinos | Presupuesto | Preparación | Información | Eventos |
|---|---|---|---|---|---|
| Fácil | Órbita terrestre | Libre | Ilimitada | Casi toda visible | 1 |
| Medio | Luna o Marte | 930 M | 10 días | Parte oculta (se investiga) | 3 |
| Difícil | Órbita solar o Júpiter | 750 M | 7 días | Casi toda oculta | 5 |

Las cifras de rutas, piezas y destinos (distancia, luz solar disponible, retardo de comunicación, radiación) están inspiradas en
misiones reales: paneles solares que rinden el 43 % en Marte y el 4 % en Júpiter, generadores RTG que no dependen del Sol,
transferencias de Hohmann, asistencias gravitatorias y sondas con escudo térmico.

## Multijugador

En Medio y Difícil se puede jugar **en equipo (2 a 4 jugadores)**:
- **En la misma computadora, por relevos.** Las cinco fases se reparten entre los jugadores; cada uno tiene un color de astronauta
  y, al abrir su sala, el juego pide que tome el control. El reporte final muestra qué aportó cada quien.
- **En red local (Wi-Fi).** Un jugador crea la sala y los demás se unen con su IP desde el lobby; cada quien juega sus fases en
  su dispositivo y el anfitrión sincroniza el estado de la misión.

Los roles de la tripulación (Planificador, Ingeniero, Finanzas y Astronauta) se asignan en la Sala de planificación y aparecen
en la ficha de misión y en el reporte.

## Cómo jugar

- Descarga Godot 4.3 o más nuevo, importa `project.godot` y presiona F5. O abre la versión web (ver `deploy/README.md`).
- Controles en la estación: WASD o flechas para moverte, **E** para entrar a una sala, **M** para el mapa, **Esc** para salir de
  una sala. Cada minijuego muestra sus controles antes de empezar.
- Tecla **F1** en la partida: modo prueba, abre todas las compuertas.

## Tecnología

Godot 4 (GDScript), arte dibujado por código (estación, astronauta, consolas), fondos 3D con texturas reales de los planetas
en los minijuegos, multijugador LAN con ENet. Exportable a escritorio y a web (HTML5), publicable en Railway, Vercel o itch.io.

---

# Documentación técnica

## Estructura
- Raíz: `menu.tscn` + `menu_interfaz.gd` (pantalla de inicio), `fase1.tscn` + `fase1_interfaz.gd` + `fase1_logica.gd` + `fase1_datos.gd` (sala de planificación), `tema_espacial.gd` (tema visual compartido), `fondo_espacial.gd` (fondo de galaxia) e `img/` (imágenes).
- `scenes/` y `scripts/`: una escena y un script por fase (`fase2_laboratorio`, `fase3_lanzamiento`, `fase4_operacion`, `fase5_resultados`), más `hub.tscn`, `main.tscn`.
- `scripts/hub.gd`: la base. Para cambiar el mapa edita `AREAS` (salas y pasillos, en tiles de 32 px) y `PUERTAS`; las paredes y colisiones se generan solas.
- `scripts/astronauta.gd`: astronauta de la Tierra (traje blanco, casco con visor dorado, mochila, parche con bandera en `bandera`) dibujado por código, con animación de caminar, respiración, giro y polvo. `scripts/estilo.gd`: texto con contorno negro.
- `scripts/game_state.gd`: autoload `GameState` (estado global: ficha de misión, progreso de fases y nave). `scripts/mesa_mando.gd` (botón rojo que pulsa), `scripts/transicion.gd` (autoload `Transicion`: fundido entre escenas y destello).
- `scripts/puerta.gd`, `scripts/minimapa.gd`, `scripts/zona.gd` (consola de tarea con el marcador amarillo "!").
- `scripts/zona.gd`: zona de una fase. `scripts/player.gd`: el astronauta.
- `data/componentes/`: una pieza de la nave por archivo `.tres` (copia `panel_solar_basico.tres`). Hoy el Laboratorio usa su propio `CATALOGO` dentro de `fase2_laboratorio.gd`; el `.tres` es el formato para cuando se migre.
- `img/`: imágenes. Opcional: `fonts/Poppins-Regular.ttf` y `Poppins-Bold.ttf` (si existen, el tema las usa).

## Datos que se comparten entre fases (fuente única)
- **Niveles, destinos y rutas: solo en `fase1_datos.gd`.** Cada ruta tiene `costo` y `dias` (Fase 1: presupuesto y preparación) y `viaje`, `dv`, `riesgo`, `nota` (Fase 2: Mapa de rutas y validación de la nave). Para agregar o cambiar una ruta, edita SOLO ahí.
- El `nombre` de cada destino en `fase1_datos.gd` debe coincidir con el de `DESTINOS` en `fase2_laboratorio.gd` (así el Laboratorio sabe a qué destino se refiere la ficha).
- Toda ruta deja saldo para construir una nave válida en el Laboratorio (presupuesto del nivel = ruta más cara + nave mínima + margen). Si cambias costos o el presupuesto de un nivel, vuelve a comprobarlo.
- Ruta y destino en `GameState`: `GameState.destino` es el nombre del destino y `GameState.ruta` es el nombre de la ruta, tal como están en `fase1_datos.gd`.

## Contrato entre fases (importante)
- Cada fase hereda de `PhaseBase` (`extends PhaseBase`) y su nodo raíz es un `Control` que llena toda la pantalla.
- Lee y escribe SOLO en el autoload `GameState`.
- Al completarse, llama `terminar()`.
- Deja libre la esquina superior derecha (ahí va el botón "Volver a la base").
- Nadie cambia nombres ni variables de `GameState` sin avisar al equipo.
- Fases 3, 4 y 5 son pantallas provisionales (`crear_placeholder`): reemplaza esa llamada por tu fase real. Lee `GameState.ficha`, `GameState.componentes` y `GameState.get_meta("lab_resumen")` para usar lo que dejaron las fases 1 y 2.

## Cómo probar tu fase
- **Sola:** abre tu escena y presiona F6. Si `GameState` está vacío, carga datos de prueba en tu `_ready()`.
- **Dentro del juego:** ejecuta con F5, elige modo, dificultad y nombres en la pantalla de inicio y presiona **F1** para desbloquear todas las zonas (modo prueba).

## Reglas de equipo
- Cada quien edita solo SUS escenas y scripts.
- Para agregar contenido: archivos en `data/`, `assets/` e `img/`.
- Antes de empezar a trabajar: `git pull`. Al terminar: commit y `git push`.

## Fase 5: Sala de resultados
- `scripts/fase5_resultados.gd` (interfaz, mismo diseño que la Fase 1), `scripts/fase5/evaluacion_mision.gd` (lógica: 6 revisiones y puntaje 0-100) y `scripts/fase5/datos_demo_fase5.gd` (nave de prueba si llega vacía).
- Lee `GameState.ficha`, `componentes`, `ruta`, `eventos_resueltos`, `datos_cientificos`; escribe solo `GameState.puntaje`.
- Revisiones: Presupuesto (20), Energía (20), Masa (15), Sistemas críticos (20), Fiabilidad (15), Ciencia (10). Si falla una crítica, la misión falla y el puntaje se topa en 49. Constantes de balance arriba de `evaluacion_mision.gd` (`MASA_MAX`, `META_CIENCIA`).
- La Fase 3 puede llenar `GameState.eventos_resueltos` (lista de nombres) y la Fase 4 `GameState.datos_cientificos` (Mbps): el reporte los muestra solo.

## Estructura recomendada de cada fase (lógica separada de interfaz)
| Archivo | Qué es | Reglas |
|---|---|---|
| `scripts/faseN_nombre.gd` | **Interfaz**. `extends PhaseBase`. | Solo crea nodos, muestra datos, conecta botones y anima. No calcula reglas. Llama a `terminar()`. |
| `scripts/faseN/faseN_logica.gd` | **Lógica**. `extends RefCounted`. | Cálculos y reglas. Lee/escribe `GameState`. Cero nodos. Se puede probar sin abrir la escena. |
| `scripts/faseN/faseN_datos.gd` | **Datos**. `extends RefCounted`, `const`. | Números, textos, tablas y datos de prueba. |

Ejemplos: Fase 1 (`fase1_datos` / `fase1_logica` / `fase1_interfaz`) y Fase 5 (`fase5/` + `fase5_resultados.gd`).
Tema visual: `theme = TemaEspacial.crear()` y `FondoEspacial` como primer hijo. Dentro del hub, dejar 64 px de margen superior para no tapar "Volver a la base".

## Fase 4: Sala de operación (minijuego)
- Código del minijuego en `phase4/` (niveles 1-3, HUD, fondo, efectos) + autoload `Phase4Manager` (registra controles `p4_*`, elige nivel por dificultad y perfil de nave por piezas de propulsión, acumula métricas).
- `scripts/fase4_operacion.gd` es la ventana dentro del hub: pantalla de inicio → nivel (Node2D con `z_index = 1`) → resultado → `GameState.operacion` + `terminar()`.
- Adaptaciones respecto al original: el manager ya no cambia de escena (emite `nivel_completado` / `mision_fallida`); el fondo del nivel es hijo con `z_index -1` en vez de `CanvasLayer`; el HUD es un `Control` y su panel empieza al 10 % de alto para no tapar "Volver a la base". Su menú y su pantalla de resultados propios quedaron en `_to_delete/phase4_original/` (los sustituyen el hub y la Fase 5).
- Ramificaciones por destino: nivel 2 Luna (ciencia en superficie) o Marte (rover); nivel 3 Sonda solar o Júpiter (asteroides y lunas). Se eligen solas según `GameState.ficha.destino`; en `MODO_PRUEBA` se pueden alternar en la pantalla de inicio.
- Controles dentro del nivel: flechas/WASD, Espacio/E acción, F medir. Esc vuelve a la base sin completar.

## Fase 3: Sala de lanzamiento y tránsito
- Portada del proyecto original de la fase (Godot 3, recuperado del `.gdc`) a Godot 4 con la estructura del equipo: `scripts/fase3/fase3_datos.gd` (ritmo por nivel y catálogo de eventos), `scripts/fase3/fase3_logica.gd` (viaje, eventos, fallo/éxito) y `scripts/fase3_lanzamiento.gd` (interfaz con el tema).
- Jugabilidad: al lanzar, el progreso avanza solo y el combustible baja; en ciertos porcentajes aparece un evento con dos opciones que cambian combustible e integridad (reparar cuesta combustible, arriesgar cuesta integridad). Se falla si alguno llega a 0. Número de eventos = `ficha.eventos_transito` (Fácil 1, Medio 3, Difícil 5).
- Escribe `GameState.eventos_resueltos` (decisiones tomadas) y `GameState.transito` (exito, motivo, combustible_pct, integridad_pct). La Fase 5 lo califica en la revisión "Tránsito".

## Multijugador (relevos) y colores
- Disponible solo en **Medio y Difícil** (`NIVELES_EQUIPO` en `fase1_datos.gd`): el menú deshabilita "Multijugador" en Fácil y `GameState.configurar_partida()` degrada a solo si llega otra cosa.
- **Relevos en la misma computadora**: las 5 fases se reparten al azar entre 2 a 4 jugadores (`GameState.asignaciones`); como cada fase necesita la anterior, juega el dueño de la primera fase pendiente. Al cambiar de dueño aparece la pantalla de RELEVO ("Pasa el control a …") y el astronauta de la base cambia al color de ese jugador.
- Colores fijos por jugador: azul, rojo, verde, morado (`COLORES_JUGADOR`). Se ven en el menú (nombres), en "TURNO DE", en el reparto, en el traje del astronauta y en el aporte del reporte final.
- **Red local (Wi‑Fi)**: `scripts/red.gd` (autoload `Red`, ENet puerto 9999) + `lobby.tscn`. Cada quien juega SUS fases en su dispositivo; el anfitrión sincroniza el estado. Está completo pero no tiene botón en el menú: para activarlo, agrega un botón que llame `_ir_lobby()` en `menu_interfaz.gd`.
- Los roles (`ROLES`, `ROL_INFO`) siguen en `fase1_datos.gd` para la ficha; el reparto por fases es lo que manda en el juego.

## Exportar a web y publicar (Railway / itch.io)
Ver `deploy/README.md`: preset **Web** ya configurado (exporta a `deploy/web/`), servidor Node con cabeceras COOP/COEP y pasos para Railway.
