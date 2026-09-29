## Pinchos que salen del suelo a ratos.
##
## POR QUE A RATOS Y NO SIEMPRE FUERA:
## unos pinchos siempre fuera son una roca que duele: se rodean y ya. Saliendo
## y metiendose, hay que mirar el ritmo y cruzar cuando estan dentro, que es
## lo que hace que el suelo sea algo con lo que jugar y no solo un estorbo.
## Antes de salir asoman un momento: el aviso es lo que los hace justos.
class_name Pinchos
extends Peligro

const DENTRO: float = 1.5
const AVISO: float = 0.45
const FUERA: float = 1.0
const DANO: int = 1

## Donde empieza su ciclo. El reparto le da uno distinto a cada trampa para
## que no salgan todas a la vez.
var desfase: float = 0.0


func _ciclo() -> float:
	return fmod(_fase + desfase, DENTRO + AVISO + FUERA)


func estan_fuera() -> bool:
	return _ciclo() >= DENTRO + AVISO


func _al_pisar(cuerpo: Node2D) -> void:
	if estan_fuera() and cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(DANO)


func _draw() -> void:
	var caja := Rect2(-tamano * 0.5, tamano)
	draw_rect(caja, color_suelo.darkened(0.35))
	draw_rect(caja, Color(color_borde.r, color_borde.g, color_borde.b, 0.5), false, 2.0)

	# Cuanto asoman: nada dentro, un poco en el aviso, del todo fuera.
	var ciclo := _ciclo()
	var salida := 0.0
	if ciclo >= DENTRO + AVISO:
		salida = 1.0
	elif ciclo >= DENTRO:
		salida = 0.3

	var filas := 3
	var paso := tamano / filas
	var metal := Color(0.82, 0.8, 0.78).lerp(Color(1.0, 0.95, 0.9), salida)
	for fila in filas:
		for columna in filas:
			var centro := -tamano * 0.5 + paso * Vector2(columna + 0.5, fila + 0.5)
			# El agujero siempre se ve: asi se sabe que ahi hay trampa aunque
			# los pinchos esten dentro.
			draw_circle(centro, minf(paso.x, paso.y) * 0.18, Color(0.02, 0.01, 0.01, 0.9))
			if salida <= 0.0:
				continue
			var ancho := minf(paso.x, paso.y) * 0.22
			var alto := minf(paso.x, paso.y) * 0.62 * salida
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-ancho, ancho * 0.4),
				centro + Vector2(ancho, ancho * 0.4),
				centro + Vector2(0.0, ancho * 0.4 - alto)]), metal)
