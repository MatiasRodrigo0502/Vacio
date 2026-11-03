## Se hincha y suelta esporas en anillo, en todas direcciones. Cada anillo va
## girado medio hueco respecto al anterior, asi que el sitio por donde pasar
## cambia. La planta venenosa (Matias la llama «el pulpo»).
##
## Quieta hasta que se cierran las puertas de su sala; entonces te persigue,
## muy despacio al principio y cada vez mas deprisa: cada 'cada_aumento'
## segundos gana 'aumento' de velocidad, lo mismo que las Botas ligeras
## (Matias, 2026-11-03). Hay que matarla pronto. Mientras se hincha para
## disparar se para.
##
## Usa la cadencia, el aviso (tiempo_apuntar) y el proyectil de su tipo.
class_name ComportamientoAnillo
extends ComportamientoEnemigo

## Esporas por anillo.
@export var disparos: int = 8
## Lo que se hincha al cargar, respecto a su tamano.
@export var hinchado: float = 0.18

@export_group("Persecucion")
## Si te persigue cuando se cierran las puertas. Sin esto, plantada siempre.
@export var persigue: bool = true
## Su velocidad al cerrarse las puertas, en px/s: muy, muy lenta.
@export var velocidad_inicial: float = 12.0
## Lo que gana cada vez, en px/s: lo de las Botas ligeras.
@export var aumento: float = 45.0
## Cada cuantos segundos lo gana.
@export var cada_aumento: float = 2.0
## Hasta donde llega: la velocidad del mago. Sin tope, a los 20 s iria a
## 460 px/s y no habria forma de escaparse ni de esquivar su anillo.
@export var velocidad_maxima: float = 300.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["espera"] = enemigo.tipo.cadencia * randf_range(0.45, 0.9)
	enemigo.estado["apuntando"] = 0.0
	enemigo.estado["giro"] = 0.0
	# Cuanto lleva persiguiendo: desde que se cierran las puertas.
	enemigo.estado["persiguiendo"] = 0.0
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

	_perseguir(enemigo, delta)

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


## Con las puertas de su sala cerradas, hacia quien persigue, a la velocidad
## que le toque por lo que lleva persiguiendo.
func _perseguir(enemigo: Enemigo, delta: float) -> void:
	var sala := enemigo.sala()
	if not persigue or sala == null or not sala.esta_cerrada():
		return
	var lleva: float = enemigo.estado["persiguiendo"] + delta
	enemigo.estado["persiguiendo"] = lleva
	var hacia := enemigo.hacia_objetivo()
	if hacia.length() < 1.0:
		return
	# andar() va a la velocidad de su tipo por un factor: el factor que da
	# la de ahora.
	enemigo.andar(hacia.normalized(), delta,
		velocidad_ahora(lleva) / maxf(enemigo.tipo.velocidad, 1.0))


## La velocidad tras 'lleva' segundos persiguiendo: la inicial y un aumento
## por cada 'cada_aumento' segundos, hasta el tope.
func velocidad_ahora(lleva: float) -> float:
	var aumentos := floorf(lleva / maxf(cada_aumento, 0.01))
	return minf(velocidad_inicial + aumento * aumentos, velocidad_maxima)
