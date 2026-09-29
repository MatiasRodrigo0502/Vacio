## Charco de lava: quema siempre que lo pisas.
##
## Hay dos: los fijos, que reparte la mecanica de peligros en los pisos hondos,
## y los que deja el magma del golem al caer, que se enfrian y desaparecen
## (duracion > 0).
##
## El dibujo sale de herramientas/generar_peligros.py (tres charcos distintos)
## y lo anima shaders/lava.gdshader: el calor late y lo fundido ondula. Aqui
## solo se eligen charco y tamano, y se pintan las burbujas.
class_name Lava
extends Peligro

const DANO: int = 1
## Lo que tarda en apagarse al final, para que no desaparezca de golpe.
const ENFRIADO: float = 0.8
## Lo que tarda en crecer al aparecer. Los charcos del magma se ven caer.
const CRECER: float = 0.18

## Radio del charco dentro de su textura: lo de fuera es el resplandor sobre
## el suelo. Tiene que cuadrar con RADIO_CHARCO del generador.
const RADIO_EN_TEXTURA: float = 0.78

const TEXTURAS: Array[Texture2D] = [
	preload("res://assets/peligros/lava_00.png"),
	preload("res://assets/peligros/lava_01.png"),
	preload("res://assets/peligros/lava_02.png"),
]
const CALOR: Array[Texture2D] = [
	preload("res://assets/peligros/lava_00_calor.png"),
	preload("res://assets/peligros/lava_01_calor.png"),
	preload("res://assets/peligros/lava_02_calor.png"),
]
const SHADER := preload("res://shaders/lava.gdshader")

var radio: float = 50.0
## Segundos que dura. 0 = para siempre.
var duracion: float = 0.0

var _variante: int = 0
## Un material por charco: cada uno late a su ritmo y se enfria por su cuenta.
var _material: ShaderMaterial = null


func _ready() -> void:
	tamano = Vector2.ONE * radio * 2.0
	# El charco y su ritmo salen de la posicion: fijos para cada charco, sin
	# gastar numeros del generador del piso.
	var semilla := absf(position.x * 0.0131 + position.y * 0.0071)
	_variante = int(semilla * 97.0) % TEXTURAS.size()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("calor", CALOR[_variante])
	_material.set_shader_parameter("semilla", fmod(semilla, 10.0))
	material = _material
	super()


func _crear_forma() -> Shape2D:
	var circulo := CircleShape2D.new()
	# Lo fundido, sin el reborde de basalto: el borde se puede pisar.
	circulo.radius = radio * 0.82
	return circulo


func _physics_process(delta: float) -> void:
	super(delta)
	if duracion > 0.0 and _fase >= duracion:
		queue_free()


func _al_pisar(cuerpo: Node2D) -> void:
	# Un charco que se esta enfriando ya no quema: si se ve apagandose, que
	# no pegue.
	if _enfriandose():
		return
	if cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(DANO)


func _enfriandose() -> bool:
	return duracion > 0.0 and _fase >= duracion - ENFRIADO


func _draw() -> void:
	var enfriado := 0.0
	if _enfriandose():
		enfriado = clampf(1.0 - (duracion - _fase) / ENFRIADO, 0.0, 1.0)
	_material.set_shader_parameter("enfriado", enfriado)
	var crecer := clampf(_fase / CRECER, 0.0, 1.0) if duracion > 0.0 else 1.0

	var lado := radio * 2.0 / RADIO_EN_TEXTURA * crecer
	var opacidad := 1.0 - enfriado * enfriado
	draw_texture_rect(TEXTURAS[_variante], Rect2(-Vector2.ONE * lado * 0.5, Vector2.ONE * lado),
		false, Color(1.0, 1.0, 1.0, opacidad))
	if enfriado <= 0.0:
		_pintar_burbujas(crecer)


## Burbujas que se hinchan y revientan en lo caliente del centro. Cada una
## tiene su ciclo; al reventar deja un aro que se abre y se apaga.
func _pintar_burbujas(crecer: float) -> void:
	var semilla := float(_variante) * 1.7 + absf(position.x) * 0.01
	for i in 3:
		var ciclo := fmod(_fase * 0.55 + i * 0.37 + semilla, 1.0)
		var sitio := Vector2.RIGHT.rotated(semilla * 3.0 + i * 2.1) \
			* radio * (0.12 + 0.18 * i) * crecer
		var tope := radio * 0.075
		if ciclo < 0.75:
			var r := tope * ciclo / 0.75
			draw_circle(sitio, r, Color(1.0, 0.72, 0.25, 0.9))
			draw_circle(sitio - Vector2(r, r) * 0.3, r * 0.4, Color(1.0, 0.95, 0.75, 0.9))
			draw_arc(sitio, r, 0.0, TAU, 12, Color(0.55, 0.14, 0.04, 0.8), 1.0, true)
		else:
			var reventar := (ciclo - 0.75) / 0.25
			draw_arc(sitio, tope * (1.0 + reventar * 1.2), 0.0, TAU, 14,
				Color(1.0, 0.85, 0.45, 1.0 - reventar), 1.5, true)
