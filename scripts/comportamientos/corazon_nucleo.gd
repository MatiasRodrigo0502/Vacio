## El Corazon del Nucleo, el jefe del piso 12: una esfera de magma que flota, con
## un ojo. Lo trajo Matias el 2026-11-04 con los enemigos nuevos, en lugar del Mago
## Caido, el jefe de antes.
##
## SE QUEDA LA PELEA QUE TENIA EL MAGO CAIDO y se le anade la del paquete. Esa
## pelea es lo que Matias fue pidiendo (2026-10-14, «mas dificil» el 10-21, el
## aliento el 11-03), y la del paquete sola, una nova cada 3,5 s, seria un jefe
## mucho mas facil. Lo que cambia, ademas del dibujo:
##
## - Dispara BOLAS DE MAGMA en vez de rayos, con el arte del paquete.
## - La NOVA del paquete, en las tres fases: avisa con un aro, suelta una onda por
##   el suelo y un anillo de 8 bolas.
## - La furia del paquete (mas rapido por debajo del 50 %) no hace falta: ya va
##   mas rapido en cada fase (ritmo_fases).
##
## Cada pocos segundos usa una habilidad. Cuantas sabe depende de la fase, que va
## por la vida que le queda:
##
## 1. Del 100 al 66 %: la nova, el aliento de fuego y el AGUJERO NEGRO al reves:
##    se abre donde estas y tira de ti (PozoVacio). Mientras crece no tira: es el
##    aviso.
## 2. Del 66 al 33 %: ademas, el ESCUDO: una burbuja en la que tus disparos no le
##    hacen nada, y mientras la tiene suelta anillos de esquirlas de hielo que
##    frenan, como el disparo del blanco.
## 3. Del 33 % al final: ademas, el RAYO DE FUEGO: carga un rayo enorme (su linea
##    avisa y se queda quieta al final) que deja fuego por donde pasa. Un pilar lo
##    para, pero se rompe (Matias, 2026-10-14): cada pilar sirve una vez.
##
## Las bolas salen en abanico, mas en cada fase (bolas_por_fase: 1, 3 y 5).
##
## Sus efectos van en oro, como las grietas de su dibujo.
##
## Al cambiar de fase se va al centro, se protege, suelta una onda y deja un
## vendaje: un respiro, y el aviso de que ahora viene mas.
##
## No hace nada hasta que se cierran las puertas de su sala, y luego espera a
## que acabe la presentacion (BarraJefe). Hasta entonces no se le puede dar:
## sin eso, desde el umbral se le podia quitar vida sin pelear.
##
## Todos los numeros estan en su .tres (resources/jefes/corazon_nucleo.tres).
class_name ComportamientoCorazonNucleo
extends ComportamientoEnemigo

## Su color: el de las grietas de su dibujo.
const COLOR_ORO := Color(1.0, 0.8, 0.28)
const COLOR_HIELO := Color(0.7, 0.92, 1.0)
const COLOR_FUEGO := Color(1.0, 0.55, 0.15)

## Segundos desde que se cierran las puertas hasta que empieza a pelear: lo
## que dura su presentacion.
@export var presentacion: float = 2.2
## Vida (de 0 a 1) a la que pasa a la fase 2 y a la 3.
@export var paso_fase_2: float = 0.66
@export var paso_fase_3: float = 0.33
## Todo va a este ritmo en cada fase (moverse, apuntar, recargar): 1 = el de
## su .tres.
@export var ritmo_fases: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.35])
## Segundos entre una habilidad y la siguiente (a su ritmo).
@export var espera_habilidad: float = 5.0

@export_group("Agujero negro")
@export var radio_pozo: float = 170.0
@export var duracion_pozo: float = 3.4
## Lo que tarda en tirar desde que aparece: el aviso.
@export var aviso_pozo: float = 0.9
@export var dano_pozo: int = 15

@export_group("Escudo")
@export var duracion_escudo: float = 4.0
## Lo que suelta mientras tiene el escudo: esquirlas de hielo que frenan.
@export var esquirla: TipoProyectil
@export var esquirlas_por_anillo: int = 10
@export var cada_anillo: float = 1.1

@export_group("Rayo de fuego")
## Lo que carga. Los ultimos 'fija_fuego' segundos la linea ya no te sigue:
## ahi es cuando hay que apartarse.
@export var carga_fuego: float = 1.4
@export var fija_fuego: float = 0.45
@export var ancho_fuego: float = 46.0
@export var dano_fuego: int = 50
## Charcos de fuego que deja por donde pasa, y como son.
@export var charcos_fuego: int = 5
@export var radio_charco: float = 30.0
@export var duracion_charco: float = 3.0

@export_group("Aliento de fuego")
## Escupe fuego de vez en cuando, en las tres fases (Matias, 2026-11-03; ver
## AlientoFuego): empieza 'desvio_aliento' grados a un lado de donde estas al
## empezar y gira 'giro_aliento' grados hacia ti en 'duracion_aliento'
## segundos, hasta el limite de la sala. Antes avisa 'aviso_aliento'.
@export var aviso_aliento: float = 0.6
@export var duracion_aliento: float = 2.0
@export var desvio_aliento: float = 10.0
@export var giro_aliento: float = 90.0
@export var ancho_aliento: float = 44.0
## Lo que quita al tocarte, y la quemadura que te deja: segundos y lo que
## quita cada medio segundo.
@export var dano_aliento: int = 15
@export var quemadura_aliento: float = 3.0
@export var dano_quemadura_aliento: int = 3

@export_group("Nova")
## Lo que avisa, y hasta donde llega y lo que quita su onda por el suelo.
@export var aviso_nova: float = 0.9
@export var radio_nova: float = 380.0
@export var duracion_nova: float = 0.55
@export var dano_nova: int = 30
## Las bolas del anillo que sale con ella. Cada anillo, girado al azar.
@export var bolas_nova: int = 8

@export_group("Abanico de bolas")
## Cuantas bolas salen a la vez en cada fase: la del centro y las demas a los
## lados, una a cada lado por turnos.
@export var bolas_por_fase: PackedInt32Array = PackedInt32Array([1, 3, 5])
## Grados entre una bola del abanico y la de al lado.
@export var abertura_abanico: float = 16.0

@export_group("Cambio de fase")
@export var duracion_cambio: float = 1.6
@export var radio_onda: float = 300.0
@export var dano_onda: int = 25
## Lo que deja al cambiar de fase para recuperarse (el vendaje).
@export var cura: ObjetoMejora

## Lo que dura el rayo de fuego en pantalla una vez sale.
const DURACION_FUEGO: float = 0.4
## Lo que tarda en irse y en volver al teletransportarse al centro.
const DESVANECER: float = 0.35
const DURACION_DESTELLO: float = 0.2
## Lo que hay del centro de la esfera a su sombra: flota.
const ALTURA_SUELO: float = 96.0
## Lo que tarda 'atacar' en llegar a la pose 4 (a 10 por segundo), en la que sale
## la onda en su dibujo.
const HASTA_ONDA_DIBUJO: float = 0.4


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["accion"] = &"esperando"
	enemigo.estado["t"] = 0.0
	enemigo.estado["fase"] = 1
	enemigo.estado["habilidad"] = espera_habilidad * 0.6
	enemigo.estado["siguiente"] = 0
	enemigo.estado["vistos"] = enemigo.disparos
	enemigo.estado["destello"] = 0.0
	enemigo.estado["vida_fase"] = 1.0
	enemigo.mirar_a(Vector2.DOWN)


func procesar(enemigo: Enemigo, delta: float) -> void:
	var e := enemigo.estado
	e["t"] = float(e["t"]) + delta
	e["destello"] = maxf(0.0, float(e["destello"]) - delta)
	var t: float = e["t"]
	var hacia := enemigo.hacia_objetivo()
	match e["accion"]:
		&"esperando":
			enemigo.mirar_a(hacia)
			var sala := enemigo.sala()
			if sala != null and sala.esta_cerrada():
				_pasar(enemigo, &"presentacion")
		&"presentacion":
			enemigo.mirar_a(hacia)
			if t >= presentacion:
				_pasar(enemigo, &"pelea")
		&"pelea":
			_pelear(enemigo, delta, hacia)
		&"nova":
			enemigo.mirar_a(hacia)
			enemigo.brillo(t / aviso_nova)
			# Para que la onda de su dibujo salga con la de verdad.
			if t >= aviso_nova - HASTA_ONDA_DIBUJO and not e.get("gesto_nova", false):
				e["gesto_nova"] = true
				enemigo.gesto(&"atacar")
			if t >= aviso_nova:
				e.erase("gesto_nova")
				enemigo.brillo(0.0)
				_soltar_nova(enemigo)
				_pasar(enemigo, &"pelea")
		&"pozo":
			enemigo.mirar_a(hacia)
			enemigo.brillo(t / 0.5)
			if t >= 0.5:
				enemigo.brillo(0.0)
				_abrir_pozo(enemigo)
				_pasar(enemigo, &"pelea")
		&"escudo":
			enemigo.mirar_a(hacia)
			var anillos := int(t / cada_anillo)
			if anillos > int(e.get("anillos", 0)) and t < duracion_escudo:
				e["anillos"] = anillos
				_anillo_de_hielo(enemigo, anillos)
			if t >= duracion_escudo:
				_pasar(enemigo, &"pelea")
		&"cargando":
			# La linea te sigue hasta los ultimos 'fija_fuego' segundos.
			if t < carga_fuego - fija_fuego:
				e["dir"] = hacia.normalized() if hacia.length() > 1.0 else Vector2.DOWN
			enemigo.mirar_a(e["dir"])
			var linea := _linea(enemigo, e["dir"])
			e["largo"] = linea["largo"]
			e["pilar"] = linea["pilar"]
			enemigo.brillo(t / carga_fuego)
			if t >= carga_fuego:
				enemigo.brillo(0.0)
				_soltar_fuego(enemigo)
				_pasar(enemigo, &"fuego")
		&"fuego":
			if t >= DURACION_FUEGO:
				_pasar(enemigo, &"pelea")
		&"aliento":
			# Quieto mientras escupe, mirando a donde estabas al empezar.
			enemigo.mirar_a(e.get("dir_aliento", Vector2.DOWN))
			if t >= aviso_aliento + duracion_aliento:
				_pasar(enemigo, &"pelea")
		&"cambio":
			_cambiar_de_fase(enemigo, t)


## Lo normal: a su distancia, bolas con aviso y, de vez en cuando, una
## habilidad. Y si la vida ha bajado del paso de fase, a cambiar.
func _pelear(enemigo: Enemigo, delta: float, hacia: Vector2) -> void:
	var e := enemigo.estado
	var fase: int = e["fase"]
	if (fase == 1 and enemigo.fraccion_vida() <= paso_fase_2) \
			or (fase == 2 and enemigo.fraccion_vida() <= paso_fase_3):
		_pasar(enemigo, &"cambio")
		enemigo.sonar(&"teletransporte")
		return
	var ritmo := ritmo_fases[clampi(fase - 1, 0, ritmo_fases.size() - 1)]
	enemigo.pelear_a_distancia(delta * ritmo, hacia, hacia.length())
	enemigo.mirar_a(hacia)
	# Cada bola sale con las del abanico de su fase: la que ya ha salido es
	# la del centro, y las demas van a un lado y al otro, cada vez mas
	# abiertos (+1, -1, +2, -2...).
	if enemigo.disparos > int(e["vistos"]):
		e["vistos"] = enemigo.disparos
		var bolas := bolas_por_fase[clampi(fase - 1, 0, bolas_por_fase.size() - 1)]
		var centro := hacia.normalized()
		for i in range(1, bolas):
			var lado := 1.0 if i % 2 == 1 else -1.0
			var abierto := deg_to_rad(abertura_abanico) * ((i + 1) / 2) * lado
			enemigo.disparar_hacia(centro.rotated(abierto))
	e["habilidad"] = float(e["habilidad"]) - delta * ritmo
	if float(e["habilidad"]) <= 0.0 and not enemigo.esta_apuntando():
		e["habilidad"] = espera_habilidad
		_usar_habilidad(enemigo)


## Las habilidades que sabe en cada fase, por turnos: en la 3, el fuego sale
## dos de cada seis veces.
func _usar_habilidad(enemigo: Enemigo) -> void:
	var e := enemigo.estado
	var turnos: Array[StringName] = [&"nova", &"pozo", &"aliento"]
	match int(e["fase"]):
		2:
			turnos = [&"escudo", &"nova", &"pozo", &"aliento"]
		3:
			turnos = [&"cargando", &"nova", &"pozo", &"aliento", &"cargando", &"escudo"]
	var cual: StringName = turnos[int(e["siguiente"]) % turnos.size()]
	e["siguiente"] = int(e["siguiente"]) + 1
	_pasar(enemigo, cual)
	match cual:
		&"pozo", &"nova":
			enemigo.sonar(&"carga_lista")
		&"escudo":
			e["anillos"] = 0
			enemigo.sonar(&"escudo")
		&"cargando":
			e["dir"] = enemigo.hacia_objetivo().normalized()
			enemigo.sonar(&"carga_lista")
		&"aliento":
			_escupir_fuego(enemigo)


## El aliento de fuego: la referencia es donde esta el jugador ahora, al
## empezar. Sale 'desvio_aliento' grados a un lado (al azar cual) y gira
## 'giro_aliento' hacia el otro, pasando por encima de el.
func _escupir_fuego(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	var hacia := enemigo.hacia_objetivo()
	var referencia := hacia.angle() if hacia.length() > 1.0 else PI * 0.5
	var lado := 1.0 if randf() < 0.5 else -1.0
	enemigo.estado["dir_aliento"] = Vector2.RIGHT.rotated(referencia)
	MundoRed.crear_aliento(sala, enemigo.global_position,
		referencia + deg_to_rad(desvio_aliento) * lado, -deg_to_rad(giro_aliento) * lado,
		aviso_aliento, duracion_aliento, ancho_aliento, dano_aliento,
		quemadura_aliento, dano_quemadura_aliento)
	enemigo.sonar(&"carga_lista")


## La nova: la onda por el suelo, desde su sombra, y el anillo de bolas. La onda
## por MundoRed, para que salga en todos los ordenadores; las bolas ya van.
func _soltar_nova(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	MundoRed.crear_onda(sala, sala.to_local(_suelo(enemigo)), radio_nova, duracion_nova,
		dano_nova, COLOR_ORO, "Corazón del Núcleo (nova)")
	var giro := randf() * TAU / bolas_nova
	for i in bolas_nova:
		enemigo.disparar_hacia(Vector2.RIGHT.rotated(giro + i * TAU / bolas_nova))


## Debajo de el, en la pantalla: donde tiene la sombra.
func _suelo(enemigo: Enemigo) -> Vector2:
	return enemigo.global_position + Vista.en_mundo(Vector2(0.0, ALTURA_SUELO))


## Se abre donde esta a quien persigue (en cooperativo, el mas cercano). Por
## MundoRed: sale en todos los ordenadores y tira del jugador de cada uno.
func _abrir_pozo(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	var suelo := sala.rect_suelo_global().grow(-PozoVacio.NUCLEO)
	var donde := (enemigo.global_position + enemigo.hacia_objetivo()).clamp(suelo.position, suelo.end)
	MundoRed.crear_pozo(sala, donde, duracion_pozo, radio_pozo, float(dano_pozo),
		COLOR_ORO, Color(0.55, 0.36, 0.06), aviso_pozo)


## Un anillo de esquirlas alrededor. Cada anillo girado medio hueco respecto
## al anterior: asi el sitio seguro cambia y hay que moverse.
func _anillo_de_hielo(enemigo: Enemigo, numero: int) -> void:
	if esquirla == null or esquirlas_por_anillo <= 0:
		return
	var giro := (numero % 2) * PI / esquirlas_por_anillo
	for i in esquirlas_por_anillo:
		enemigo.disparar_hacia(Vector2.RIGHT.rotated(giro + i * TAU / esquirlas_por_anillo), esquirla)


## Sale el rayo de fuego: quita vida si el jugador esta en la linea (hasta la
## primera roca o muro) y deja charcos de fuego por el camino.
func _soltar_fuego(enemigo: Enemigo) -> void:
	var e := enemigo.estado
	var dir: Vector2 = e["dir"]
	var largo: float = e["largo"]
	var desde := enemigo.global_position
	var hasta := desde + dir * largo
	# Si lo ha parado un pilar, el pilar se rompe.
	var pilar: Variant = e.get("pilar")
	if pilar is Obstaculo and is_instance_valid(pilar):
		_romper_pilar(enemigo, pilar)
	# A cada jugador en la linea: por MundoRed, en cooperativo cada ordenador
	# mira el suyo.
	MundoRed.fuego(desde, hasta, ancho_fuego, dano_fuego, "Corazón del Núcleo (rayo de fuego)")
	var sala := enemigo.sala()
	if sala == null or charcos_fuego <= 0:
		return
	var objetivo := enemigo.global_position + enemigo.hacia_objetivo()
	for i in charcos_fuego:
		var punto := desde.lerp(hasta, (i + 1.0) / (charcos_fuego + 1.0))
		# Uno justo debajo del jugador seria un segundo golpe sin aviso.
		if punto.distance_to(objetivo) < radio_charco + 30.0:
			continue
		MundoRed.crear_lava(sala, sala.to_local(punto), radio_charco, duracion_charco,
			"Corazón del Núcleo (fuego)")


## Rompe el pilar que ha parado el rayo de fuego: se quita (y la sala lo
## olvida, para no seguir apartando a nadie de donde estaba) y saltan sus
## trozos.
func _romper_pilar(enemigo: Enemigo, pilar: Obstaculo) -> void:
	var sala := enemigo.sala()
	if sala != null:
		MundoRed.romper_pilar(sala, pilar)
	else:
		pilar.romper()


## El cambio de fase: se desvanece, aparece en el centro, suelta la onda y
## el corazon, y vuelve a pelear con lo nuevo.
func _cambiar_de_fase(enemigo: Enemigo, t: float) -> void:
	var e := enemigo.estado
	var sala := enemigo.sala()
	if t < DESVANECER:
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0 - t / DESVANECER)
	elif not e.get("en_el_centro", false):
		e["en_el_centro"] = true
		if sala != null:
			enemigo.global_position = sala.global_position
	elif t < DESVANECER * 2.0:
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, (t - DESVANECER) / DESVANECER)
	elif not e.get("onda", false):
		e["onda"] = true
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)
		_soltar_onda(enemigo)
	if t >= duracion_cambio:
		e["fase"] = int(e["fase"]) + 1
		e["habilidad"] = espera_habilidad * 0.5
		e.erase("en_el_centro")
		e.erase("onda")
		_pasar(enemigo, &"pelea")


func _soltar_onda(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	MundoRed.crear_onda(sala, sala.to_local(_suelo(enemigo)),
		radio_onda, 0.6, dano_onda, COLOR_ORO, "Corazón del Núcleo (onda)")
	# Un vendaje debajo del centro: lejos de los pilares y de la bajada.
	if cura != null:
		MundoRed.soltar_objeto(sala, cura, sala.to_global(Vector2(0.0, minf(sala.tamano.y * 0.32, 160.0))))


func _pasar(enemigo: Enemigo, accion: StringName) -> void:
	enemigo.estado["accion"] = accion
	enemigo.estado["t"] = 0.0


## Hasta donde llega el rayo de fuego ("largo"): la primera roca o muro. Y si
## lo para un pilar, cual ("pilar"; si no, null): al soltarlo, se rompe.
func _linea(enemigo: Enemigo, dir: Vector2) -> Dictionary:
	var maximo := 2000.0
	var rayo := PhysicsRayQueryParameters2D.create(enemigo.global_position,
		enemigo.global_position + dir * maximo, Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS)
	var golpe := enemigo.get_world_2d().direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return {"largo": maximo, "pilar": null}
	var pilar: Variant = golpe["collider"] if golpe["collider"] is Obstaculo else null
	return {"largo": enemigo.global_position.distance_to(golpe["position"]), "pilar": pilar}


func invulnerable(enemigo: Enemigo) -> bool:
	return enemigo.estado.get("accion", &"esperando") in [&"esperando", &"presentacion", &"escudo", &"cambio"]


func bloqueado(enemigo: Enemigo) -> void:
	enemigo.estado["destello"] = DURACION_DESTELLO
	enemigo.sonar(&"escudo_golpe")


func voltear(_enemigo: Enemigo) -> bool:
	return false


func marcas_vida() -> PackedFloat32Array:
	return PackedFloat32Array([paso_fase_2, paso_fase_3])


## Su final: el juego a camara lenta un momento, mientras se rompe (la explosion
## ya va en su animacion de muerte). La bajada se abre sola al morir (la sala se
## queda sin enemigos).
func al_morir(enemigo: Enemigo) -> void:
	Sonido.tocar(&"explosion")
	# A camara lenta un segundo de verdad (el temporizador no va a camara
	# lenta). Del arbol y no del enemigo, que se libera ya: asi vuelve a la
	# velocidad normal pase lo que pase.
	Engine.time_scale = 0.3
	enemigo.get_tree().create_timer(1.0, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


func dibujar(enemigo: Enemigo) -> void:
	var e := enemigo.estado
	var accion: StringName = e.get("accion", &"esperando")
	# Para lo que se mueve solo (el brillo del escudo).
	var fase := Time.get_ticks_msec() * 0.001
	match accion:
		&"nova":
			# Hasta donde va a llegar la onda: un aro en el suelo.
			var avance := clampf(float(e["t"]) / aviso_nova, 0.0, 1.0)
			enemigo.draw_set_transform(Vector2(0.0, ALTURA_SUELO), 0.0, Vector2(1.0, OndaChoque.ACHATADO))
			enemigo.draw_arc(Vector2.ZERO, radio_nova, 0.0, TAU, 64, Color(COLOR_ORO, 0.25 + 0.55 * avance), 3.0, true)
			enemigo.draw_circle(Vector2.ZERO, radio_nova * avance, Color(COLOR_ORO, 0.08))
			enemigo.draw_set_transform(Vector2.ZERO)
		&"escudo", &"cambio", &"presentacion":
			_pintar_escudo(enemigo, accion, float(e["destello"]) / DURACION_DESTELLO, fase)
		&"cargando":
			var t: float = e["t"]
			var dir: Vector2 = e.get("dir", Vector2.DOWN)
			var largo: float = e.get("largo", 600.0)
			var avance := clampf(t / carga_fuego, 0.0, 1.0)
			var fija := t >= carga_fuego - fija_fuego
			# La linea, cada vez mas gruesa; fija, parpadea: ahora no te sigue.
			var alfa := 0.25 + 0.45 * avance
			if fija:
				alfa = 0.4 + 0.5 * absf(sin(t * 30.0))
			enemigo.draw_line(Vector2.ZERO, dir * largo, Color(COLOR_FUEGO, alfa), 2.0 + 6.0 * avance)
			enemigo.draw_circle(Vector2.ZERO, 14.0 + 26.0 * avance, Color(COLOR_FUEGO, 0.25 + 0.3 * avance))
		&"fuego":
			var queda := 1.0 - clampf(float(e["t"]) / DURACION_FUEGO, 0.0, 1.0)
			var dir: Vector2 = e["dir"]
			var hasta: Vector2 = dir * float(e["largo"])
			enemigo.draw_line(Vector2.ZERO, hasta, Color(COLOR_FUEGO, 0.5 * queda), ancho_fuego * (1.4 - 0.4 * queda))
			enemigo.draw_line(Vector2.ZERO, hasta, Color(1.0, 0.85, 0.4, 0.85 * queda), ancho_fuego * 0.55)
			enemigo.draw_line(Vector2.ZERO, hasta, Color(1.0, 1.0, 0.9, queda), ancho_fuego * 0.2)


## La burbuja: la del escudo (azul hielo, la del mago blanco) y la de cuando
## no se le puede dar (presentacion, cambio de fase), de oro. Que cubra la esfera
## y casi todo lo de sus anillos.
func _pintar_escudo(enemigo: Enemigo, accion: StringName, destello: float, fase: float) -> void:
	var radio := enemigo.tipo.alto * 0.85
	var color := COLOR_HIELO if accion == &"escudo" else COLOR_ORO
	var alfa := 0.8
	if accion == &"escudo":
		var t: float = enemigo.estado["t"]
		# Parpadea cuando se le va a acabar.
		if duracion_escudo - t < 0.8:
			alfa = 0.35 + 0.65 * absf(cos(t * TAU * 3.0))
	enemigo.draw_circle(Vector2.ZERO, radio, Color(color, (0.1 + 0.15 * destello) * alfa))
	enemigo.draw_arc(Vector2.ZERO, radio, 0.0, TAU, 48, Color(color, (0.3 + 0.4 * destello) * alfa), 6.0 + 5.0 * destello, true)
	enemigo.draw_arc(Vector2.ZERO, radio, 0.0, TAU, 48, Color(color, 0.85 * alfa), 2.0, true)
	var giro := fase * 1.6
	enemigo.draw_arc(Vector2.ZERO, radio - 3.0, giro, giro + 0.9, 12, Color(1.0, 1.0, 1.0, 0.5 * alfa), 2.0, true)
	# Lo que le queda de escudo: un aro que se vacia, para saber cuando atacar.
	if accion == &"escudo":
		var queda := clampf(1.0 - float(enemigo.estado["t"]) / duracion_escudo, 0.0, 1.0)
		enemigo.draw_arc(Vector2.ZERO, radio + 9.0, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.35 * alfa), 5.0, true)
		enemigo.draw_arc(Vector2.ZERO, radio + 9.0, -PI * 0.5, -PI * 0.5 + TAU * queda, 48,
			Color(1.0, 1.0, 1.0, 0.9 * alfa), 3.5, true)
