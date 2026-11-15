extends Node
## Autoload "Red": multijugador en red local (Wi-Fi / LAN) con ENet.

signal lobby_cambio                          # cambió la lista de jugadores de la sala
signal conexion_fallida(motivo: String)      # no se pudo entrar a la sala
signal desconectado(motivo: String)          # se perdió al anfitrión
signal estado_actualizado                    # llegó el estado compartido tras completar una fase
signal jugador_se_fue(nombre: String)        # alguien se desconectó en partida

const PUERTO := 9999
const MAX_JUGADORES := 4
const ESCENA_PARTIDA := "res://scenes/main.tscn"

var activo := false
var es_host := false
var partida_en_curso := false
## [{"id": int, "nombre": String, "conectado": bool}].
## (el mismo que usa GameState.asignaciones y GameState.config.nombres).
var jugadores: Array = []
var _nombre_local := "Jugador"


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_peer_se_fue)
	multiplayer.connected_to_server.connect(_al_conectar)
	multiplayer.connection_failed.connect(_al_fallar)
	multiplayer.server_disconnected.connect(_host_se_fue)


# ---------------------------------------------------------------- sala

## IPs de esta computadora dentro de la red local (para que los demás se unan).
func ips_locales() -> PackedStringArray:
	var r := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.contains(":"):
			continue
		var p := a.split(".")
		var privada: bool = a.begins_with("192.168.") or a.begins_with("10.") \
			or (p.size() == 4 and p[0] == "172" and int(p[1]) >= 16 and int(p[1]) <= 31)
		if privada:
			r.append(a)
	return r


func crear_sala(nombre: String) -> Error:
	cerrar()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PUERTO, MAX_JUGADORES - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	activo = true
	es_host = true
	jugadores = [{"id": 1, "nombre": _limpiar(nombre), "conectado": true}]
	lobby_cambio.emit()
	return OK


func unirse(ip: String, nombre: String) -> Error:
	cerrar()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PUERTO)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	activo = true
	es_host = false
	_nombre_local = _limpiar(nombre)
	jugadores = []
	return OK


## Cierra la conexión y deja todo como al principio (sin avisar a nadie localmente).
func cerrar() -> void:
	var estaba := activo
	activo = false
	es_host = false
	partida_en_curso = false
	jugadores = []
	GameState.mi_indice = -1
	if estaba and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _limpiar(nombre: String) -> String:
	var n := nombre.strip_edges().substr(0, 20)
	return n if n != "" else "Jugador"


func _indice_de(id: int) -> int:
	for k in jugadores.size():
		if int(jugadores[k]["id"]) == id:
			return k
	return -1


func _nombre_repetido(n: String) -> bool:
	for j in jugadores:
		if String(j["nombre"]) == n:
			return true
	return false


func _asign_a_array() -> Array:
	var a: Array = []
	for v in GameState.asignaciones:
		a.append(v)
	return a


func _al_conectar() -> void:
	_srv_registrar.rpc_id(1, _nombre_local)


func _al_fallar() -> void:
	cerrar()
	conexion_fallida.emit("No se pudo conectar. Revisa la IP y que estén en la misma red Wi-Fi.")


func _host_se_fue() -> void:
	if not activo:
		return
	desconectado.emit("El anfitrión cerró la sala.")
	cerrar()


@rpc("any_peer", "reliable")
func _srv_registrar(nombre: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if partida_en_curso or jugadores.size() >= MAX_JUGADORES:
		_cli_rechazo.rpc_id(id, "La sala está llena o la partida ya empezó.")
		await get_tree().create_timer(0.4).timeout
		if activo and multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var base := _limpiar(nombre)
	var nombre_ok := base
	var k := 2
	while _nombre_repetido(nombre_ok):
		nombre_ok = "%s %d" % [base, k]
		k += 1
	jugadores.append({"id": id, "nombre": nombre_ok, "conectado": true})
	_difundir_lobby()


func _difundir_lobby() -> void:
	_cli_lobby.rpc(jugadores)
	lobby_cambio.emit()


@rpc("authority", "reliable")
func _cli_lobby(lista: Array) -> void:
	jugadores = lista
	lobby_cambio.emit()


@rpc("authority", "reliable")
func _cli_rechazo(motivo: String) -> void:
	cerrar()
	conexion_fallida.emit(motivo)


# ---------------------------------------------------------------- inicio de la partida

## Solo el anfitrión: reparte las fases y manda a todos a la base.
func iniciar_partida(nivel_id: String) -> void:
	if not es_host or jugadores.size() < 2:
		return
	if not GameState.nivel_permite_multijugador(nivel_id):
		return   # el multijugador solo existe en Medio y Difícil
	partida_en_curso = true
	var nombres: Array = []
	for j in jugadores:
		nombres.append(j["nombre"])
	GameState.mi_indice = 0
	GameState.configurar_partida("red", nivel_id, nombres)   # también sortea GameState.asignaciones
	_cli_iniciar.rpc(nivel_id, nombres, _asign_a_array(), jugadores)
	Transicion.ir_a(ESCENA_PARTIDA)


@rpc("authority", "reliable")
func _cli_iniciar(nivel_id: String, nombres: Array, asign: Array, lista: Array) -> void:
	jugadores = lista
	partida_en_curso = true
	var yo := multiplayer.get_unique_id()
	for k in jugadores.size():
		if int(jugadores[k]["id"]) == yo:
			GameState.mi_indice = k
	GameState.configurar_partida("red", nivel_id, nombres)
	GameState.asignaciones.clear()          # se usa el reparto del anfitrión, no uno propio
	for v in asign:
		GameState.asignaciones.append(int(v))
	GameState.turno_cambio.emit()
	Transicion.ir_a(ESCENA_PARTIDA)


# ---------------------------------------------------------------- estado compartido

## Llamar DESPUÉS de GameState.completar_fase(i) en el dispositivo que jugó la fase i.
func fase_completada(i: int) -> void:
	if not activo:
		return
	var snap := GameState.exportar_estado()
	if multiplayer.is_server():
		_aplicar_y_difundir(i, snap, 0)
	else:
		_srv_fase_completada.rpc_id(1, i, snap)


@rpc("any_peer", "reliable")
func _srv_fase_completada(i: int, snap: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_aplicar_y_difundir(i, snap, _indice_de(multiplayer.get_remote_sender_id()))


func _aplicar_y_difundir(i: int, snap: Dictionary, quien: int) -> void:
	if i < 0 or i >= GameState.asignaciones.size():
		return
	if quien == -1 or GameState.asignaciones[i] != quien:
		return   # solo el dueño de la fase puede completarla
	GameState.importar_estado(snap)
	GameState.fases_completadas[i] = true
	_cli_estado.rpc(GameState.exportar_estado())


@rpc("authority", "call_local", "reliable")
func _cli_estado(snap: Dictionary) -> void:
	GameState.importar_estado(snap)
	estado_actualizado.emit()


# ---------------------------------------------------------------- desconexiones

func _peer_se_fue(id: int) -> void:
	if not activo or not multiplayer.is_server():
		return
	var idx := _indice_de(id)
	if idx == -1:
		return
	if not partida_en_curso:
		jugadores.remove_at(idx)
		_difundir_lobby()
		return
	if GameState.todas_completas():
		return
	jugadores[idx]["conectado"] = false
	_reasignar(idx)
	_cli_reasignar.rpc(_asign_a_array(), jugadores, String(jugadores[idx]["nombre"]))


## Pasa las fases pendientes del jugador que se fue a quien tenga menos fases por hacer.
func _reasignar(idx: int) -> void:
	var cuenta := {}
	for j in jugadores.size():
		if jugadores[j]["conectado"]:
			cuenta[j] = 0
	if cuenta.is_empty():
		return
	for i in GameState.asignaciones.size():
		var due: int = GameState.asignaciones[i]
		if not GameState.fases_completadas[i] and cuenta.has(due):
			cuenta[due] += 1
	for i in GameState.asignaciones.size():
		if GameState.asignaciones[i] == idx and not GameState.fases_completadas[i]:
			var mejor := -1
			for j in cuenta:
				if mejor == -1 or cuenta[j] < cuenta[mejor]:
					mejor = j
			GameState.asignaciones[i] = mejor
			cuenta[mejor] += 1


@rpc("authority", "call_local", "reliable")
func _cli_reasignar(asign: Array, lista: Array, nombre: String) -> void:
	jugadores = lista
	GameState.asignaciones.clear()
	for v in asign:
		GameState.asignaciones.append(int(v))
	jugador_se_fue.emit(nombre)
	GameState.turno_cambio.emit()
	GameState.progreso_cambio.emit()
