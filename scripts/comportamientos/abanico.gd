## Se mueve de lado alrededor del jugador, a su distancia, y dispara varias
## bolas en abanico. Cambia de lado cada poco y al chocar. La serpiente.
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


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["espera"] = enemigo.tipo.cadencia * randf_range(0.45, 0.9)
	enemigo.estado["apuntando"] = 0.0
	enemigo.estado["lado"] = 1.0 if randf() < 0.5 else -1.0
	enemigo.estado["t_lado"] = randf() * cambio_lado
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

	# Se acerca o se aparta hasta su distancia, y a la vez de lado.
	var tipo := enemigo.tipo
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

	var espera: float = enemigo.estado["espera"] - delta
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
