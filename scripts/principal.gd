## Escena raiz de la partida. Es deliberadamente "tonta": no decide reglas,
## solo reacciona a las senales del autoload GestorProgreso y monta/desmonta
## la escena de piso que toque.
##
## POR QUE ESTA SEPARACION:
## el dia que haya menu principal, selector de capitulo o modo contrarreloj,
## las reglas ya viven en el gestor y aqui solo habria que enchufar otra vista.
extends Node2D

const ESCENA_PISO := preload("res://scenes/Piso.tscn")
const ESCENA_BOLA := preload("res://scenes/BolaMagica.tscn")

@onready var _contenedor_piso: Node2D = $ContenedorPiso
@onready var _pool: PoolObstaculos = $PoolObstaculos
@onready var _jugador: Jugador = $Jugador
@onready var _camara: CamaraJuego = $CamaraJuego
@onready var _hud: Hud = $Hud
@onready var _pantalla_final: PantallaFinal = $PantallaFinal
@onready var _menu_pausa: MenuPausa = $MenuPausa

var _piso_actual: Piso = null


func _ready() -> void:
	GestorProgreso.piso_cambiado.connect(_al_cambiar_piso)
	GestorProgreso.partida_ganada.connect(_al_ganar)
	GestorProgreso.partida_perdida.connect(_al_perder)

	_jugador.vida_cambiada.connect(_hud.actualizar_vida)
	_jugador.sin_vida.connect(GestorProgreso.terminar_por_derrota)
	_jugador.bola_lanzada.connect(_al_lanzar_bola)
	_jugador.mejora_recogida.connect(_hud.anunciar_mejora)
	_jugador.especial_cambiado.connect(_al_cambiar_especial)
	_jugador.caido.connect(_al_caer)
	# Temblor corto con cada golpe: 7 px que se calman en un cuarto de segundo.
	_jugador.dano_recibido.connect(_camara.sacudir.bind(7.0))
	_pantalla_final.reinicio_solicitado.connect(_reiniciar)
	_pantalla_final.menu_solicitado.connect(_volver_al_menu)
	_menu_pausa.reinicio_solicitado.connect(_reiniciar)
	_menu_pausa.menu_solicitado.connect(_volver_al_menu)

	# El mago elegido en el menu, antes de que el HUD lea la vida: la ventaja
	# puede cambiar cuantos corazones tiene.
	_jugador.usar_personaje(GestorProgreso.personaje_elegido)

	_pantalla_final.ocultar()
	# El _ready() de los hijos se ejecuta antes que el del padre, asi que la
	# primera senal vida_cambiada del jugador se emitio cuando aun no habia
	# nadie escuchando: sincronizamos el HUD a mano una vez.
	_hud.actualizar_vida(_jugador.vida_actual, _jugador.vida_maxima)

	# Atajos para probar (F1 invencible, F2/F3 piso, F4 limpiar sala). Solo al
	# jugar desde Godot: en el .exe exportado is_debug_build() es false y el
	# nodo ni se crea.
	if OS.is_debug_build():
		add_child(AtajosPrueba.new(_jugador, func() -> Piso: return _piso_actual))

	GestorProgreso.iniciar_partida()


## Monta el piso indicado. Se llama tanto en el primer piso como en cada avance.
func _al_cambiar_piso(numero_piso: int, datos: DatosPiso) -> void:
	_descargar_piso()

	var piso: Piso = ESCENA_PISO.instantiate()
	_contenedor_piso.add_child(piso)
	# configurar() va despues de add_child() porque necesita los @onready del piso.
	piso.configurar(datos, numero_piso, _pool, GestorProgreso.obtener_mecanicas_activas(numero_piso))
	piso.salida_alcanzada.connect(_al_alcanzar_salida)
	piso.sala_cambiada.connect(_al_cambiar_sala)
	_piso_actual = piso

	_jugador.reubicar(piso.punto_entrada())

	# Las mecanicas tambien pueden tocar al jugador (velocidad, friccion...).
	for mecanica in GestorProgreso.obtener_mecanicas_activas(numero_piso):
		mecanica.aplicar_a_jugador(_jugador)

	# La camara salta de golpe a la nueva posicion (es otro piso, no un
	# desplazamiento) pero el zoom se interpola: el cierre de vision se nota.
	# El zoom antes que el limite: el limite se calcula con el zoom de ahora.
	var primer_piso := numero_piso == 1
	_camara.aplicar_radio_vision(datos.radio_vision, primer_piso)
	_camara.limitar_a(piso.sala_actual().rect_con_muros())
	_camara.seguir(_jugador, true)

	_hud.actualizar_piso(numero_piso, GestorProgreso.total_pisos(), datos.nombre_capa)
	_hud.mostrar_mapa(piso)


## La bola cuelga del piso, no de Principal: asi al cambiar de piso se va con el
## y no queda ninguna volando de un piso al siguiente.
func _al_lanzar_bola(desde: Vector2, direccion: Vector2, cargada: bool) -> void:
	if _piso_actual == null:
		return
	var bola: BolaMagica = ESCENA_BOLA.instantiate()
	bola.direccion = direccion
	# La bola hereda lo que hayan mejorado los objetos recogidos.
	bola.velocidad = _jugador.velocidad_bola
	bola.radio = _jugador.radio_bola
	bola.limite = _piso_actual.sala_actual().rect_con_muros()
	# Cada mago dispara de su color.
	bola.color = _jugador.color_cargado if cargada else _jugador.color_disparo
	bola.color_halo = _jugador.halo_cargado if cargada else _jugador.halo_disparo
	# Lo que quita y lo que frena el disparo normal es de cada mago.
	bola.dano = _jugador.dano_disparo
	bola.frena = _jugador.frena_disparo
	if cargada:
		# El ataque cargado parte de los numeros ya mejorados y los multiplica,
		# para que los objetos recogidos tambien se noten en el.
		bola.cargada = true
		bola.radio *= _jugador.factor_radio_cargada
		bola.velocidad *= _jugador.factor_velocidad_cargada
		bola.dano = _jugador.dano_bola_cargada
		bola.frena = 0.0
		# Atraviesa enemigos: es lo que hace que valga la pena esperar. Las
		# rocas siguen parandola, como el disparo normal, porque son el terreno.
		bola.atraviesa = true
		_ajustar_al_mago(bola)
	_piso_actual.add_child(bola)
	bola.global_position = desde


## Lo que la bola cargada tiene de cada mago: hasta donde llega y si abre un
## agujero negro al acabarse (el mago oscuro).
func _ajustar_al_mago(bola: BolaMagica) -> void:
	var mago := _jugador.mago
	if mago == null:
		return
	if mago.alcance_cargado > 0.0:
		bola.alcance = mago.alcance_cargado
	if mago.agujero_negro:
		bola.apagada.connect(_abrir_agujero.bind(_piso_actual.sala_actual()))


func _abrir_agujero(punto: Vector2, sala: Sala) -> void:
	if _piso_actual == null or not is_instance_valid(sala):
		return
	var mago := _jugador.mago
	var agujero := AgujeroNegro.new(sala, mago.duracion_agujero, mago.radio_agujero,
		mago.dano_agujero, _jugador.color_cargado, _jugador.halo_cargado)
	# Si la bola se ha apagado contra el muro, el agujero se abre en el suelo,
	# no medio metido en la pared.
	var suelo := sala.rect_suelo_global().grow(-AgujeroNegro.NUCLEO)
	_piso_actual.add_child(agujero)
	agujero.global_position = punto.clamp(suelo.position, suelo.end)


func _al_cambiar_especial(disponible: bool) -> void:
	var mago := _jugador.mago
	if mago != null:
		_hud.actualizar_especial(disponible, mago.nombre_especial(), mago.color)


## Al pasar a otra sala, la camara se encaja en ella. No salta: se desliza,
## porque sigue al jugador con suavizado.
func _al_cambiar_sala(sala: Sala) -> void:
	_camara.limitar_a(sala.rect_con_muros())


## El jugador ha caido por un agujero: vuelve a la entrada de la sala. El
## jugador no sabe donde esta eso y el piso no sabe quien ha caido; aqui se
## juntan las dos cosas.
func _al_caer() -> void:
	if _piso_actual != null:
		_jugador.reaparecer(_piso_actual.punto_reaparicion())


func _al_alcanzar_salida() -> void:
	# call_deferred es obligatorio aqui: esta llamada llega desde el body_entered
	# de la zona de salida, es decir, en mitad de un paso de fisica. Destruir el
	# piso (con sus cuerpos de colision) en ese momento provoca el error
	# "Can't change this state while flushing queries" del motor.
	GestorProgreso.avanzar_piso.call_deferred()


func _al_ganar() -> void:
	_jugador.bloquear_control()
	_pantalla_final.mostrar_victoria(GestorProgreso.total_pisos())


func _al_perder() -> void:
	_jugador.bloquear_control()
	_pantalla_final.mostrar_derrota(GestorProgreso.piso_actual)


## Vuelve al menu. Cambiar de escena tira la partida entera, que es justo lo que
## queremos: no hay estado que limpiar a mano.
func _volver_al_menu() -> void:
	# La pausa no es de la escena sino del arbol: si se cambiara de escena con
	# el arbol en pausa, el menu naceria congelado.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")


func _reiniciar() -> void:
	# El mago elegido en el menu, antes de que el HUD lea la vida: la ventaja
	# puede cambiar cuantos corazones tiene.
	_jugador.usar_personaje(GestorProgreso.personaje_elegido)

	_pantalla_final.ocultar()
	_jugador.restaurar_vida()
	# Las mejoras se pierden al empezar otra partida; sus iconos tambien.
	_hud.vaciar_mejoras()
	GestorProgreso.reiniciar_partida()


## Devuelve los obstaculos al pool ANTES de destruir el piso: si no, los nodos
## reciclables se irian con la escena y el pool se quedaria vacio.
func _descargar_piso() -> void:
	if _piso_actual == null:
		return
	_piso_actual.devolver_obstaculos()
	_piso_actual.salida_alcanzada.disconnect(_al_alcanzar_salida)
	_piso_actual.sala_cambiada.disconnect(_al_cambiar_sala)
	_contenedor_piso.remove_child(_piso_actual)
	_piso_actual.queue_free()
	_piso_actual = null
