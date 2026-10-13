## Como se mueve y ataca un tipo de enemigo. Lo lleva su TipoEnemigo
## (comportamiento) y el enemigo lo llama en cada paso mientras esta despierto.
##
## POR QUE UN RESOURCE APARTE Y NO MAS CASOS EN enemigo.gd:
## al principio todos hacian lo mismo (ir a por ti, o quedarse lejos y
## disparar). Matias pidio que cada uno hiciera algo distinto (2026-10-13), y
## con once enemigos, once ramas en el mismo script lo harian ilegible. Cada
## comportamiento es un archivo de esta carpeta con sus numeros exportados, y
## se elige en el .tres del enemigo: probar otro es cambiar una linea.
##
## OJO CON EL ESTADO: el recurso es UNO para todos los enemigos de ese tipo
## (vive en su .tres). Lo que es de cada enemigo (en que fase va, cuanto le
## queda) se guarda en enemigo.estado, nunca en variables de aqui.
##
## Sin comportamiento, el enemigo hace lo de siempre: cuerpo a cuerpo va a por
## ti; a distancia se queda a su distancia y dispara.
class_name ComportamientoEnemigo
extends Resource


## Al prepararlo y al dormirse: deja el estado y el dibujo como al empezar.
func empezar(enemigo: Enemigo) -> void:
	enemigo.estado.clear()
	enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)


## Cada paso de fisica, despierto. 'delta' ya viene frenado si el enemigo lo
## esta (el disparo del mago blanco).
func procesar(_enemigo: Enemigo, _delta: float) -> void:
	pass


## False mientras no se le puede dar ni te da al tocarte: el fantasma
## desvanecido, la planta bajo tierra. Las bolas lo atraviesan.
func tangible(_enemigo: Enemigo) -> bool:
	return true


## Avisos que se pintan con el enemigo (aros, lineas). Se llama desde su
## _draw(), asi que se dibuja con enemigo.draw_*.
func dibujar(_enemigo: Enemigo) -> void:
	pass
