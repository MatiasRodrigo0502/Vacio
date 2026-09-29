## Pinchos que salen del suelo a ratos.
##
## POR QUE A RATOS Y NO SIEMPRE FUERA:
## unos pinchos siempre fuera son una roca que duele: se rodean y ya. Saliendo
## y metiendose, hay que mirar el ritmo y cruzar cuando estan dentro, que es
## lo que hace que el suelo sea algo con lo que jugar y no solo un estorbo.
## Antes de salir asoman y tiemblan un momento: el aviso es lo que los hace
## justos.
##
## El arte sale de herramientas/generar_peligros.py: una placa con agujeros, un
## pincho suelto y el labio de delante de los agujeros. Cada pincho se pinta
## saliendo de su agujero (primero la punta), y el labio va encima, para que
## se vea salir de dentro y no aparecer encima de la placa.
class_name Pinchos
extends Peligro

const DENTRO: float = 1.5
const AVISO: float = 0.45
const FUERA: float = 1.0
const DANO: int = 1

## Lo que tardan en subir del todo, en bajar y en asomar para avisar.
const SUBIDA: float = 0.06
const BAJADA: float = 0.15
const ASOMAR: float = 0.1
## Cuanto asoman durante el aviso.
const ASOMADO: float = 0.24

const PLACA := preload("res://assets/peligros/pinchos_base.png")
const LABIO := preload("res://assets/peligros/pinchos_frente.png")
const PINCHO := preload("res://assets/peligros/pincho.png")

# Donde estan los agujeros en la placa, en fraccion del lado. Son los mismos
# numeros que MARGEN, GROSOR, FILAS y AGUJERO_* del generador: si se cambian
# alli, aqui tambien.
const MARGEN: float = 0.05
const GROSOR: float = 0.08
const FILAS: int = 3
const AGUJERO_ANCHO: float = 0.26
const AGUJERO_ALTO: float = 0.52

## Donde empieza su ciclo. El reparto le da uno distinto a cada trampa para
## que no salgan todas a la vez.
var desfase: float = 0.0
## Tinte del piso, como el de las rocas: la placa es de la misma piedra y
## metal que el resto del piso.
var tinte: Color = Color.WHITE


func _ciclo() -> float:
	return fmod(_fase + desfase, DENTRO + AVISO + FUERA)


func estan_fuera() -> bool:
	return _ciclo() >= DENTRO + AVISO


func _al_pisar(cuerpo: Node2D) -> void:
	if estan_fuera() and cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(DANO)


## Cuanto han salido, de 0 (dentro) a 1 (fuera del todo).
##
## Suben de golpe y bajan un poco mas despacio: la subida es el golpe y tiene
## que ser seca. Al bajar ya no hacen dano aunque se vean un instante: mejor
## que el jugador sienta que ha pasado justo a que le han pinchado sin estar.
func _salida() -> float:
	var ciclo := _ciclo()
	if ciclo < DENTRO:
		return 1.0 - clampf(ciclo / BAJADA, 0.0, 1.0)
	if ciclo < DENTRO + AVISO:
		var asomar := clampf((ciclo - DENTRO) / ASOMAR, 0.0, 1.0)
		# Tiemblan mientras avisan: se lee como "van a salir".
		return ASOMADO * asomar + sin(_fase * 70.0) * 0.025 * asomar
	return ASOMADO + (1.0 - ASOMADO) * clampf((ciclo - DENTRO - AVISO) / SUBIDA, 0.0, 1.0)


func _draw() -> void:
	var caja := Rect2(-tamano * 0.5, tamano)
	draw_texture_rect(PLACA, caja, false, tinte)

	var salida := _salida()
	var metal := Color.WHITE.lerp(tinte, 0.4)
	var margen := MARGEN * tamano
	var celda := Vector2((tamano.x - margen.x * 2.0) / FILAS,
		(tamano.y - margen.y * 2.0 - GROSOR * tamano.y) / FILAS)
	var semieje := celda.x * AGUJERO_ANCHO
	var ancho := semieje * 2.0 * 0.75
	var alto := ancho * PINCHO.get_height() / PINCHO.get_width()
	var tam_labio := LABIO.get_size()

	# Fila a fila, de atras hacia delante: los pinchos de una fila tapan a los
	# de la de detras, y el labio de cada agujero va encima de su pincho.
	for fila in FILAS:
		var y := caja.position.y + margen.y + (fila + 0.5) * celda.y
		if salida > 0.0:
			for columna in FILAS:
				var x := caja.position.x + margen.x + (columna + 0.5) * celda.x
				var pie := y + semieje * AGUJERO_ALTO * 0.3
				var visible_alto := alto * salida
				# Solo la parte de arriba del pincho: es la que ha salido.
				draw_texture_rect_region(PINCHO,
					Rect2(x - ancho * 0.5, pie - visible_alto, ancho, visible_alto),
					Rect2(0.0, 0.0, PINCHO.get_width(), PINCHO.get_height() * salida), metal)
		var banda_desde := MARGEN + fila * celda.y / tamano.y
		var banda := Rect2(0.0, banda_desde * tam_labio.y, tam_labio.x, celda.y / tamano.y * tam_labio.y)
		draw_texture_rect_region(LABIO,
			Rect2(caja.position.x, caja.position.y + banda_desde * tamano.y, tamano.x, celda.y),
			banda, tinte)
