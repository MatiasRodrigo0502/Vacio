## Se mueve de lado alrededor del jugador, a su distancia, y dispara varias
## bolas en abanico. Cambia de lado cada poco y al chocar. La serpiente.
##
## Busca tenerte a tiro (Matias, 2026-11-03): cada poco mira si entre ella y
## el jugador hay una roca o un muro; si lo hay, busca alrededor el sitio mas
## cercano desde el que no lo haya y va alli, y mientras no dispara (la rafaga
## se gastaria en la roca). Antes daba vueltas a su distancia y disparaba
## igual, aunque tuviera una roca delante.
##
## Usa el aviso de siempre de los de distancia (se para y brilla
## tiempo_apuntar segundos) y su proyectil, cadencia y distancia_preferida.
class_name ComportamientoAbanico
extends ComportamientoEnemigo

## Bolas por rafaga.
@export var disparos: int = 3
## Angulo total del abanico, en grados.
@export var apertura: float = 34.0
## Segundos hacia un lado antes de cambiar al otro.
@export var cambio_lado: float = 2.2
## Cuanto se mueve de lado, respecto a su velocidad.
@export var factor_lateral: float = 0.9
## Cada cuantos segundos mira si te tiene a tiro y, si no, donde te tendria.
@export var cada_busqueda: float = 0.35
## Hasta donde busca, alrededor de donde esta, un sitio con tiro.
@export var radio_busqueda: float = 240.0

## Sitios que prueba alrededor al buscar: direcciones y distancias.
const DIRECCIONES_BUSQUEDA: int = 12
const DISTANCIAS_BUSQUEDA: Array[float] = [0.35, 0.7, 1.0]
## Lo que mira por delante, de lado, antes de seguir yendo hacia alli.
const MIRA_LADO: float = 45.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["espera"] = enemigo.tipo.cadencia * randf_range(0.45, 0.9)
	enemigo.estado["apuntando"] = 0.0
	enemigo.estado["lado"] = 1.0 if randf() < 0.5 else -1.0
	enemigo.estado["t_lado"] = randf() * cambio_lado
	enemigo.estado["a_tiro"] = true
	enemigo.estado["busqueda"] = 0.0
	enemigo.estado["destino"] = enemigo.global_position
	enemigo.brillo(0.0)


func procesar(enemigo: Enemigo, delta: float) -> void:
	var hacia := enemigo.hacia_objetivo()
	var distancia := maxf(hacia.length(), 1.0)
	var radial := hacia / distancia

	var apuntando: float = enemigo.estado["apuntando"]
	if apuntando > 0.0:
		apuntando -= delta
		enemigo.estado["apuntando"] = apuntando
		enemigo.brillo(1.0 - apuntando / maxf(enemigo.tipo.tiempo_apuntar, 0.01))
		if apuntando <= 0.0:
			_rafaga(enemigo, radial)
		return

	var busqueda: float = enemigo.estado["busqueda"] - delta
	if busqueda <= 0.0:
		busqueda = cada_busqueda
		var a_tiro := _tiene_tiro(enemigo, enemigo.global_position)
		enemigo.estado["a_tiro"] = a_tiro
		if not a_tiro:
			enemigo.estado["destino"] = _sitio_con_tiro(enemigo)
		else:
			# Con tiro, que ir de lado no se lo quite: si un poco mas alla ya
			# no lo tendria, cambia de lado antes de llegar. Sin esto volvia a
			# meterse detras de la roca cada poco.
			var lado_ahora: float = enemigo.estado["lado"]
			var un_poco_mas := enemigo.global_position + radial.orthogonal() * lado_ahora * MIRA_LADO
			if not _tiene_tiro(enemigo, un_poco_mas):
				enemigo.estado["lado"] = -lado_ahora
				enemigo.estado["t_lado"] = 0.0
	enemigo.estado["busqueda"] = busqueda

	var tipo := enemigo.tipo
	var espera: float = enemigo.estado["espera"] - delta
	if not enemigo.estado["a_tiro"]:
		# Sin tiro: hacia el sitio desde el que lo tendria. La rafaga espera.
		var destino: Vector2 = enemigo.estado["destino"]
		var falta := destino - enemigo.global_position
		if falta.length() > 6.0:
			enemigo.andar(falta.normalized(), delta)
		enemigo.estado["espera"] = maxf(espera, 0.0)
		return

	# Se acerca o se aparta hasta su distancia, y a la vez de lado.
	var avance := 0.0
	if distancia > tipo.distancia_preferida + 40.0:
		avance = 1.0
	elif distancia < tipo.distancia_preferida - 80.0:
		avance = -1.0
	var lado: float = enemigo.estado["lado"]
	var t_lado: float = enemigo.estado["t_lado"] + delta
	var direccion := radial * avance + radial.orthogonal() * lado * factor_lateral
	var antes := enemigo.global_position
	if direccion.length() > 0.01:
		enemigo.andar(direccion.normalized(), delta)
	# Cambia de lado cada poco, o si se ha quedado contra algo.
	var bloqueado := enemigo.global_position.distance_to(antes) < tipo.velocidad * delta * 0.3
	if t_lado >= cambio_lado or bloqueado:
		lado = -lado
		t_lado = 0.0
	enemigo.estado["lado"] = lado
	enemigo.estado["t_lado"] = t_lado

	if espera <= 0.0:
		espera = tipo.cadencia
		if tipo.tiempo_apuntar > 0.0:
			enemigo.estado["apuntando"] = tipo.tiempo_apuntar
		else:
			_rafaga(enemigo, radial)
	enemigo.estado["espera"] = espera


func _rafaga(enemigo: Enemigo, hacia: Vector2) -> void:
	enemigo.brillo(0.0)
	var abierto := deg_to_rad(apertura)
	for i in disparos:
		var reparto := 0.0 if disparos <= 1 else float(i) / (disparos - 1) - 0.5
		enemigo.disparar_hacia(hacia.rotated(abierto * reparto))


## True si desde 'desde' nada para un disparo hacia el jugador: ni roca ni
## muro en la linea, con lo ancho que es su bola (dos rayos a los lados).
func _tiene_tiro(enemigo: Enemigo, desde: Vector2) -> bool:
	var hasta := enemigo.global_position + enemigo.hacia_objetivo()
	var linea := hasta - desde
	if linea.length() < 1.0:
		return true
	var lado := linea.normalized().orthogonal() * _radio_bola(enemigo)
	var espacio := enemigo.get_world_2d().direct_space_state
	for desvio in [Vector2.ZERO, lado, -lado]:
		var rayo := PhysicsRayQueryParameters2D.create(desde + desvio, hasta + desvio,
			Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS)
		if not espacio.intersect_ray(rayo).is_empty():
			return false
	return true


## El sitio mas a mano, alrededor, desde el que te tendria a tiro: dentro del
## suelo, fuera de rocas y agujeros, y a ser posible a su distancia. Si no hay
## ninguno, donde esta (y sigue de lado, a ver).
func _sitio_con_tiro(enemigo: Enemigo) -> Vector2:
	var sala := enemigo.sala()
	var aqui := enemigo.global_position
	if sala == null:
		return aqui
	var radio := enemigo.tipo.alto * 0.4
	var suelo := sala.rect_suelo_global().grow(-enemigo.tipo.alto)
	var jugador := aqui + enemigo.hacia_objetivo()
	var mejor := aqui
	var mejor_coste := INF
	for i in DIRECCIONES_BUSQUEDA:
		var direccion := Vector2.RIGHT.rotated(TAU * i / DIRECCIONES_BUSQUEDA)
		for parte in DISTANCIAS_BUSQUEDA:
			var punto := aqui + direccion * radio_busqueda * parte
			if not suelo.has_point(punto) or sala.pozo_en(punto, radio) != null:
				continue
			if not sala.sacar_de_las_rocas(punto, radio).is_equal_approx(punto):
				continue
			if not _tiene_tiro(enemigo, punto):
				continue
			# Cerca de donde esta, y si puede, a su distancia del jugador.
			var coste := punto.distance_to(aqui) 				+ absf(punto.distance_to(jugador) - enemigo.tipo.distancia_preferida) * 0.5
			if coste < mejor_coste:
				mejor_coste = coste
				mejor = punto
	return mejor


func _radio_bola(enemigo: Enemigo) -> float:
	return enemigo.tipo.proyectil.radio if enemigo.tipo.proyectil != null else 8.0
