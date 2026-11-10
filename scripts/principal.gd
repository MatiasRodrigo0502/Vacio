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
## Cada cuanto suena el soplo del rocio del mago verde, como mucho. Dura un
## poco mas que esto, asi que seguidos no dejan hueco.
const SEPARACION_ROCIO_MS: int = 130
## Del centro del mago (de donde salen sus bolas) a su parte delantera: su
## circulo de choque. Lo de la bola que queda detras no se ve (BolaMagica.recortar_desde).
const FRENTE_MAGO: float = 16.0

@onready var _contenedor_piso: Node2D = $ContenedorPiso
@onready var _pool: PoolObstaculos = $PoolObstaculos
@onready var _jugador: Jugador = $Jugador
@onready var _camara: CamaraJuego = $CamaraJuego
@onready var _hud: Hud = $Hud
@onready var _pantalla_final: PantallaFinal = $PantallaFinal
@onready var _menu_pausa: MenuPausa = $MenuPausa

var _piso_actual: Piso = null
## Apunta cada partida en user://partidas/ para equilibrar con datos.
var _registro: RegistroPartida
## Solo en una partida cooperativa (Red.cooperativo()): los demas magos, sus
## disparos y los objetos compartidos. Jugando solo es null.
var _cooperativo: Cooperativo = null


func _ready() -> void:
	GestorProgreso.piso_cambiado.connect(_al_cambiar_piso)
	GestorProgreso.partida_ganada.connect(_al_ganar)
	GestorProgreso.partida_perdida.connect(_al_perder)

	_jugador.vida_cambiada.connect(_hud.actualizar_vida)
	_jugador.bola_lanzada.connect(_al_lanzar_bola)
	_jugador.veneno_lanzado.connect(_al_lanzar_veneno)
	_jugador.modo_arma_cambiado.connect(_hud.actualizar_arma)
	_jugador.mejora_recogida.connect(_hud.anunciar_mejora)
	_jugador.especial_cambiado.connect(_al_cambiar_especial)
	_jugador.caido.connect(_al_caer)
	# Temblor corto con cada golpe: 7 px que se calman en un cuarto de segundo.
	_jugador.dano_recibido.connect(_camara.sacudir.bind(7.0))
	# Lo que te quita cada golpe, en rojo, encima del mago.
	_jugador.golpeado.connect(func(cantidad: int, _origen: String) -> void:
		NumeroDano.soltar(self, _jugador.centro_colision() + Vector2(0.0, -40.0), cantidad,
			NumeroDano.Estilo.JUGADOR))
	# Y lo que quita el veneno poco a poco, en verde y mas pequeno.
	# Y lo que quita la quemadura, en naranja, como la que hace el mago rojo.
	_jugador.quemadura_quita.connect(func(cantidad: int, _origen: String) -> void:
		NumeroDano.soltar(self, _jugador.centro_colision() + Vector2(0.0, -40.0), cantidad,
			NumeroDano.Estilo.FUEGO))
	_jugador.veneno_quita.connect(func(cantidad: int, _origen: String) -> void:
		NumeroDano.soltar(self, _jugador.centro_colision() + Vector2(0.0, -40.0), cantidad,
			NumeroDano.Estilo.VENENO))
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
	_registro = RegistroPartida.new(_jugador)
	add_child(_registro)
	# Lo de fuera de la sala en la que se juega, a oscuras.
	add_child(Penumbra.new(_camara))
	# En el movil, los dos joysticks y los botones del especial y la pausa.
	if ControlesTactiles.hace_falta():
		add_child(ControlesTactiles.new(_jugador))

	if Red.cooperativo():
		_preparar_cooperativo()
	else:
		# En cooperativo, quedarse sin vida no acaba la partida (ver
		# Cooperativo.al_caer_yo).
		_jugador.sin_vida.connect(GestorProgreso.terminar_por_derrota)
		if OS.is_debug_build():
			# En cooperativo no: cambiar de piso o matar enemigos en un solo
			# ordenador dejaria a cada uno en una partida distinta.
			var atajos := AtajosPrueba.new(_jugador, func() -> Piso: return _piso_actual)
			atajos.usado.connect(_registro.marcar_trucos)
			add_child(atajos)

	GestorProgreso.iniciar_partida()


## La partida es cooperativa: los demas magos y lo que cambia por jugar
## varios. La pausa no congela nada (los demas siguen jugando): solo para a
## este mago mientras el menu esta abierto. Reiniciar no tiene sentido para
## uno solo, asi que no esta, ni en la pausa ni al acabar.
func _preparar_cooperativo() -> void:
	_cooperativo = Cooperativo.new(_jugador, self, _hud, _camara)
	add_child(_cooperativo)
	_jugador.sin_vida.connect(_cooperativo.al_caer_yo)
	_pantalla_final.modo_cooperativo()
	_menu_pausa.modo_cooperativo()
	_menu_pausa.visibility_changed.connect(func() -> void:
		if _menu_pausa.visible:
			_jugador.bloquear_control()
		else:
			_jugador.desbloquear_control())


## Monta el piso indicado. Se llama tanto en el primer piso como en cada avance.
func _al_cambiar_piso(numero_piso: int, datos: DatosPiso) -> void:
	_descargar_piso()

	var piso: Piso = ESCENA_PISO.instantiate()
	_contenedor_piso.add_child(piso)
	# configurar() va despues de add_child() porque necesita los @onready del piso.
	piso.configurar(datos, numero_piso, _pool, GestorProgreso.obtener_mecanicas_activas(numero_piso))
	piso.salida_alcanzada.connect(_al_alcanzar_salida)
	piso.sala_cambiada.connect(_al_cambiar_sala)
	piso.secreta_descubierta.connect(func(_sala: Sala) -> void:
		_hud.avisar("¡Has encontrado una sala secreta!", Cofre.COLOR_ORO))
	_piso_actual = piso

	_jugador.reubicar(piso.punto_entrada())
	if _cooperativo != null:
		_jugador.global_position += _cooperativo.desfase_salida()
		_cooperativo.al_nuevo_piso(piso)

	# Las mecanicas tambien pueden tocar al jugador (velocidad, friccion...).
	for mecanica in GestorProgreso.obtener_mecanicas_activas(numero_piso):
		mecanica.aplicar_a_jugador(_jugador)

	# La camara salta de golpe a la nueva posicion (es otro piso, no un
	# desplazamiento). El zoom es el mismo en todos los pisos; si se viene de
	# la sala del jefe (reiniciar), vuelve al suyo sin corte. El zoom antes
	# que el limite: el limite se calcula con el zoom de ahora.
	var primer_piso := numero_piso == 1
	_camara.aplicar_radio_vision(datos.radio_vision, primer_piso)
	_camara.limitar_a(piso.sala_actual().rect_con_muros())
	_jugador.sala_actual = piso.sala_actual()
	_camara.seguir(_jugador, true)

	_hud.actualizar_piso(numero_piso, GestorProgreso.total_pisos(), datos.nombre_capa)
	# La musica es del piso (DatosPiso.musica). Si es la misma que la del
	# anterior, sigue sin cortarse.
	Sonido.poner_musica(datos.musica)
	_hud.mostrar_mapa(piso)
	_registro.nuevo_piso(numero_piso, datos, piso)
	var sala_jefe := piso.sala_de_tipo(MapaSalas.Tipo.JEFE)
	if sala_jefe != null:
		sala_jefe.pelea_empezada.connect(_al_empezar_jefe)


## La bola cuelga del piso, no de Principal: asi al cambiar de piso se va con el
## y no queda ninguna volando de un piso al siguiente.
func _al_lanzar_bola(desde: Vector2, direccion: Vector2, cargada: bool) -> void:
	if _piso_actual == null:
		return
	var arma := _jugador.arma
	if arma != null and not cargada and not arma.solo_aspecto():
		_disparar_arma(desde, direccion, arma, _jugador.modo_actual())
		return
	var bola := _bola_del_jugador(direccion, cargada)
	# Un arma rara solo cambia el aspecto del disparo normal.
	if arma != null and not cargada:
		bola.usar_arma(arma, arma.modos[0], _piso_actual.sala_actual())
	_soltar_bola(bola, desde, cargada)
	# Donde se apaga puede ser la pared de la puerta secreta.
	bola.apagada.connect(_piso_actual.golpe_de_bola)
	# A los demas, la bola ya hecha: lleva lo que haya mejorado este mago.
	if _cooperativo != null:
		_cooperativo.mandar_disparo(bola, desde, _jugador.mago)


## Un disparo de un arma: sus bolas, repartidas en abanico si son varias, y, si es
## una rafaga, las siguientes un poco despues, desde donde este ya el mago.
func _disparar_arma(desde: Vector2, direccion: Vector2, arma: ArmaMago, modo: ModoArma) -> void:
	var piso := _piso_actual
	var cuantas := maxi(modo.proyectiles, 1)
	for vuelta in maxi(modo.rafaga, 1):
		if vuelta > 0:
			await get_tree().create_timer(modo.pausa_rafaga, false).timeout
			if _piso_actual != piso or not _jugador.sigue_vivo():
				return
			desde = _jugador.centro_colision()
		for i in cuantas:
			var giro := 0.0
			if cuantas > 1:
				giro = deg_to_rad(modo.apertura) * (float(i) / (cuantas - 1) - 0.5)
			var bola := _bola_de_arma(direccion.rotated(giro), arma, modo)
			# Con la onda, una hacia cada lado: se cruzan.
			if i % 2 == 1:
				bola.signo_onda = -1.0
			_soltar_bola(bola, desde, false)
			bola.apagada.connect(_piso_actual.golpe_de_bola)
			if _cooperativo != null:
				_cooperativo.mandar_disparo(bola, desde, _jugador.mago)


## Parte de la del mago (sus objetos, su frio, su fuego) y le pone lo del arma.
## El dano parte de ArmaMago.DANO_BASE y no del mago: el verde quita 1 por gota,
## porque tira 18 por segundo.
func _bola_de_arma(direccion: Vector2, arma: ArmaMago, modo: ModoArma) -> BolaMagica:
	var bola := _bola_del_jugador(direccion, false)
	bola.direccion = direccion
	bola.dano = ArmaMago.DANO_BASE * modo.dano
	bola.velocidad = _jugador.velocidad_bola * modo.velocidad
	bola.radio = _jugador.radio_bola * modo.radio
	bola.usar_arma(arma, modo, _piso_actual.sala_actual())
	return bola


## La bola de un disparo de otro jugador, con lo que manda su ordenador. En
## el anfitrion es la que da a los enemigos (con su frio y su fuego); en los
## demas solo se ve (MundoRed).
func lanzar_bola_remota(datos: Dictionary, mago: PersonajeJugable) -> void:
	if _piso_actual == null:
		return
	var bola: BolaMagica = ESCENA_BOLA.instantiate()
	bola.direccion = datos.direccion
	bola.velocidad = datos.velocidad
	bola.radio = datos.radio
	bola.color = datos.color
	bola.color_halo = datos.color_halo
	bola.dano = datos.dano
	bola.frena = datos.get("frena", 0.0)
	bola.quema = datos.get("quema", 0.0)
	bola.dano_quema = datos.get("dano_quema", 0.0)
	bola.cargada = datos.cargada
	bola.rocio = datos.get("rocio", false)
	bola.atraviesa = datos.atraviesa
	bola.alcance = datos.alcance
	bola.solo_ver = Red.es_espejo()
	bola.arte = mago.arte_especial if datos.cargada else mago.arte_disparo
	var sala := _piso_actual.sala_en(datos.desde)
	var arma := Coleccion.arma_por_indice(datos.get("arma", -1))
	if arma != null:
		bola.usar_arma(arma, arma.modos[datos.get("modo", 0)], sala)
		bola.signo_onda = datos.get("signo_onda", 1.0)
	if sala != null:
		bola.limite = sala.rect_con_muros()
		if datos.agujero:
			bola.apagada.connect(_abrir_agujero.bind(sala, mago))
		elif datos.cargada and mago.arte_especial != null and mago.arte_especial.tiene(&"explosion"):
			bola.apagada.connect(_explotar_especial.bind(sala, mago))
	_soltar_bola(bola, datos.desde, datos.cargada)


func _soltar_bola(bola: BolaMagica, desde: Vector2, cargada: bool) -> void:
	_piso_actual.add_child(bola)
	bola.global_position = desde
	# Nace en el centro del mago, pero solo se ve desde su parte delantera.
	bola.recortar_desde(desde + bola.direccion * FRENTE_MAGO)
	if bola.rocio:
		# Un soplo largo cada poco, no uno por gota: 9 "fiu" por segundo
		# serian una sirena. Seguidos, suenan a un chorro.
		Sonido.tocar(&"rocio", SEPARACION_ROCIO_MS)
	else:
		Sonido.tocar(&"disparo_cargado" if cargada else &"disparo")


## La bola de un disparo de este jugador, con lo suyo y lo que ha mejorado.
func _bola_del_jugador(direccion: Vector2, cargada: bool) -> BolaMagica:
	var bola: BolaMagica = ESCENA_BOLA.instantiate()
	bola.direccion = direccion
	# En cooperativo, fuera del anfitrion, solo se ve: alli otra igual es la
	# que da a los enemigos (MundoRed).
	bola.solo_ver = Red.es_espejo()
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
	# La quemadura del mago rojo, en las dos bolas.
	if _jugador.mago != null:
		bola.arte = _jugador.mago.arte_especial if cargada else _jugador.mago.arte_disparo
		bola.quema = _jugador.mago.quemadura_duracion
		bola.dano_quema = _jugador.mago.quemadura_dano
		# El rocio del mago verde: cada gota un poco torcida y a su
		# velocidad, para que el chorro se abra como un spray y no sea una
		# fila de bolas.
		if _jugador.mago.rocio and not cargada:
			bola.rocio = true
			var abre := deg_to_rad(_jugador.mago.dispersion_disparo)
			bola.direccion = direccion.rotated(randf_range(-abre, abre))
			bola.velocidad *= randf_range(0.92, 1.08)
	if cargada:
		# El ataque cargado parte de los numeros ya mejorados y los multiplica,
		# para que los objetos recogidos tambien se noten en el. Salvo el tamano,
		# en el mago que lo tiene fijo.
		bola.cargada = true
		if _jugador.mago != null and _jugador.mago.cargada_tamano_fijo:
			bola.radio = _jugador.radio_bola_sin_objetos()
		bola.radio *= _jugador.factor_radio_cargada
		bola.velocidad *= _jugador.factor_velocidad_cargada
		bola.dano = _jugador.dano_bola_cargada
		bola.frena = 0.0
		# Atraviesa enemigos: es lo que hace que valga la pena esperar. Las
		# rocas siguen parandola, como el disparo normal, porque son el terreno.
		bola.atraviesa = true
		_ajustar_al_mago(bola)
	return bola


## Lo que la bola cargada tiene de cada mago: hasta donde llega y si abre un
## agujero negro al acabarse (el mago oscuro).
func _ajustar_al_mago(bola: BolaMagica) -> void:
	var mago := _jugador.mago
	if mago == null:
		return
	if mago.alcance_cargado > 0.0:
		bola.alcance = mago.alcance_cargado
	if mago.agujero_negro:
		bola.apagada.connect(_abrir_agujero.bind(_piso_actual.sala_actual(), mago))
	elif mago.arte_especial != null and mago.arte_especial.tiene(&"explosion"):
		bola.apagada.connect(_explotar_especial.bind(_piso_actual.sala_actual(), mago))


## El ataque especial del mago verde: sus proyectiles de veneno, repartidos
## en circulo alrededor de el, el primero hacia donde apunta. Cuelgan del
## piso, como las bolas.
func _al_lanzar_veneno(desde: Vector2, direccion: Vector2) -> void:
	if _piso_actual == null or _jugador.mago == null:
		return
	_soltar_veneno(desde, direccion, _jugador.mago, _piso_actual.sala_actual(), Red.es_espejo())
	if _cooperativo != null:
		_cooperativo.mandar_veneno(desde, direccion)


## Los proyectiles de veneno de otro jugador. En el anfitrion envenenan; en
## los demas solo se ven, como sus bolas.
func lanzar_veneno_remoto(desde: Vector2, direccion: Vector2, mago: PersonajeJugable) -> void:
	if _piso_actual == null:
		return
	_soltar_veneno(desde, direccion, mago, _piso_actual.sala_en(desde), Red.es_espejo())


func _soltar_veneno(desde: Vector2, direccion: Vector2, mago: PersonajeJugable, sala: Sala,
		solo_ver: bool) -> void:
	var cuantos := maxi(mago.proyectiles_veneno, 1)
	for i in cuantos:
		var bola := BolaVenenosa.new()
		bola.direccion = direccion.rotated(TAU * i / cuantos)
		bola.arte = mago.arte_especial
		bola.velocidad = mago.velocidad_veneno
		bola.salida = mago.salida_veneno
		bola.giro = deg_to_rad(mago.giro_veneno)
		bola.veneno_duracion = mago.veneno_duracion
		bola.veneno_dano = mago.veneno_dano
		bola.sala = sala
		bola.solo_ver = solo_ver
		_piso_actual.add_child(bola)
		bola.global_position = desde
	Sonido.tocar(&"veneno_lanzado")


## Donde se acaba el meteoro del mago rojo: su explosion y la marca que deja en
## el suelo. SOLO SE VE: el dano lo hace la bola al pasar (atraviesa y quita lo
## suyo a cada enemigo). Si el dia de manana tiene que quitar vida, es aqui.
## En el suelo aunque se apague contra el muro, como el agujero negro.
func _explotar_especial(punto: Vector2, sala: Sala, mago: PersonajeJugable) -> void:
	if _piso_actual == null or not is_instance_valid(sala):
		return
	var suelo := sala.rect_suelo_global().grow(-AgujeroNegro.NUCLEO)
	var sitio := punto.clamp(suelo.position, suelo.end)
	EfectoHechizo.soltar(_piso_actual, mago.arte_especial, &"explosion", sitio)
	EfectoHechizo.dejar_marca(_piso_actual, mago.marca_especial, sitio)
	Sonido.tocar(&"explosion")


func _abrir_agujero(punto: Vector2, sala: Sala, mago: PersonajeJugable) -> void:
	if _piso_actual == null or not is_instance_valid(sala):
		return
	var agujero := AgujeroNegro.new(sala, mago.duracion_agujero, mago.radio_agujero,
		mago.dano_agujero, mago.color_cargado, mago.halo_cargado, mago.arte_especial)
	# Si la bola se ha apagado contra el muro, el agujero se abre en el suelo,
	# no medio metido en la pared.
	var suelo := sala.rect_suelo_global().grow(-AgujeroNegro.NUCLEO)
	_piso_actual.add_child(agujero)
	agujero.global_position = punto.clamp(suelo.position, suelo.end)
	Sonido.tocar(&"agujero_negro")


func _al_cambiar_especial(disponible: bool) -> void:
	var mago := _jugador.mago
	if mago != null:
		_hud.actualizar_especial(disponible, mago.nombre_especial(), mago.color)


## Al pasar a otra sala, la camara se encaja en ella. No salta: se desliza,
## porque sigue al jugador con suavizado.
func _al_cambiar_sala(sala: Sala) -> void:
	_jugador.sala_actual = sala
	_camara.limitar_a(sala.rect_con_muros())
	# La sala del jefe se ve entera; al salir de ella, lo de siempre del piso.
	if sala.tipo == MapaSalas.Tipo.JEFE:
		_camara.ver_entera(sala.rect_con_muros())
	elif _piso_actual != null:
		_camara.aplicar_radio_vision(_piso_actual.datos.radio_vision)


## Se han cerrado las puertas de la sala del jefe: su presentacion, su barra
## de vida y su musica.
func _al_empezar_jefe(sala: Sala) -> void:
	for enemigo in sala.enemigos():
		if is_instance_valid(enemigo) and enemigo.tipo.jefe:
			_hud.mostrar_jefe(enemigo)
			break
	if _piso_actual != null and _piso_actual.datos.musica_jefe != null:
		Sonido.poner_musica(_piso_actual.datos.musica_jefe, 0.6)


## El jugador ha caido por un agujero: vuelve a la entrada de la sala. El
## jugador no sabe donde esta eso y el piso no sabe quien ha caido; aqui se
## juntan las dos cosas.
func _al_caer() -> void:
	if _piso_actual != null:
		_jugador.reaparecer(_piso_actual.punto_reaparicion())


func _al_alcanzar_salida() -> void:
	# En cooperativo se baja juntos: lo decide el anfitrion para todos.
	if _cooperativo != null:
		_cooperativo.pedir_bajar()
		return
	# call_deferred es obligatorio aqui: esta llamada llega desde el body_entered
	# de la zona de salida, es decir, en mitad de un paso de fisica. Destruir el
	# piso (con sus cuerpos de colision) en ese momento provoca el error
	# "Can't change this state while flushing queries" del motor.
	GestorProgreso.avanzar_piso.call_deferred()
	Sonido.tocar(&"bajar")


func _al_ganar() -> void:
	_jugador.bloquear_control()
	Sonido.tocar_final(&"victoria")
	_pantalla_final.mostrar_victoria(GestorProgreso.total_pisos())


func _al_perder() -> void:
	_jugador.bloquear_control()
	Sonido.tocar_final(&"derrota")
	_pantalla_final.mostrar_derrota(GestorProgreso.piso_actual)


## Vuelve al menu. Cambiar de escena tira la partida entera, que es justo lo que
## queremos: no hay estado que limpiar a mano.
func _volver_al_menu() -> void:
	# En cooperativo, tambien se deja la sala: los demas se enteran solos.
	if _cooperativo != null:
		Red.volver_al_menu()
		return
	# La pausa no es de la escena sino del arbol: si se cambiara de escena con
	# el arbol en pausa, el menu naceria congelado.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")


func _reiniciar() -> void:
	# Antes que nada: restaurar la vida contaria como vida recuperada en la
	# partida que se deja.
	_registro.terminar("reiniciada")
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
