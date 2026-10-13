## Plantada en su sitio: se hincha y suelta esporas en anillo, en todas
## direcciones. Cada anillo va girado medio hueco respecto al anterior, asi que
## el sitio por donde pasar cambia. La planta venenosa.
##
## Usa la cadencia, el aviso (tiempo_apuntar) y el proyectil de su tipo; su
## velocidad no, porque no se mueve.
class_name ComportamientoAnillo
extends ComportamientoEnemigo

## Esporas por anillo.
@export var disparos: int = 8
## Lo que se hincha al cargar, respecto a su tamano.
@export var hinchado: float = 0.18


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["espera"] = enemigo.tipo.cadencia * randf_range(0.45, 0.9)
	enemigo.estado["apuntando"] = 0.0
	enemigo.estado["giro"] = 0.0
	enemigo.brillo(0.0)


func procesar(enemigo: Enemigo, delta: float) -> void:
	var tipo := enemigo.tipo
	var apuntando: float = enemigo.estado["apuntando"]
	if apuntando > 0.0:
		apuntando -= delta
		enemigo.estado["apuntando"] = apuntando
		var avance := 1.0 - apuntando / maxf(tipo.tiempo_apuntar, 0.01)
		enemigo.brillo(avance)
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE * (1.0 + hinchado * avance), 1.0)
		if apuntando <= 0.0:
			_anillo(enemigo)
		return

	var espera: float = enemigo.estado["espera"] - delta
	if espera <= 0.0:
		espera = tipo.cadencia
		if tipo.tiempo_apuntar > 0.0:
			enemigo.estado["apuntando"] = tipo.tiempo_apuntar
		else:
			_anillo(enemigo)
	enemigo.estado["espera"] = espera


func _anillo(enemigo: Enemigo) -> void:
	enemigo.brillo(0.0)
	enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)
	var paso := TAU / maxf(disparos, 1)
	var giro: float = enemigo.estado["giro"]
	for i in disparos:
		enemigo.disparar_hacia(Vector2.RIGHT.rotated(giro + paso * i))
	enemigo.estado["giro"] = giro + paso * 0.5
