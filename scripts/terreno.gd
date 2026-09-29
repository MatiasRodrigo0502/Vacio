## Pregunta al motor de fisica si un disparo choca con el terreno (rocas,
## plataformas o muros) en el tramo que acaba de recorrer.
##
## POR QUE HACE FALTA Y NO BASTA CON body_entered:
## en Godot 4.7 un Area2D no avisa cuando toca un StaticBody2D. Las bolas y los
## proyectiles son Area2D y las rocas StaticBody2D, asi que las rocas nunca
## paraban ningun disparo, aunque el juego se diseno para que sirvieran de
## parapeto. Se comprobo con una roca del pool, una movida y una recien creada:
## las tres dejaban pasar la bola. Al jugador (CharacterBody2D) si lo detecta.
##
## Se mira el TRAMO entero (del punto anterior al nuevo) y ademas el circulo
## en el punto nuevo: el rayo avanza mas de 20 px por fotograma, y mirando
## solo donde acaba podria saltarse una roca estrecha.
class_name Terreno
extends RefCounted

const CAPA_MUROS: int = 2
const CAPA_ROCAS: int = 4


## Lo primero con lo que choca un disparo de ese radio al ir de 'desde' a
## 'hasta', o null si el camino esta libre.
static func choque(mundo: World2D, desde: Vector2, hasta: Vector2, radio: float,
		mascara: int) -> Object:
	var espacio := mundo.direct_space_state

	var rayo := PhysicsRayQueryParameters2D.create(desde, hasta, mascara)
	rayo.collide_with_areas = false
	var golpe := espacio.intersect_ray(rayo)
	if not golpe.is_empty():
		return golpe["collider"]

	var circulo := CircleShape2D.new()
	circulo.radius = radio
	var forma := PhysicsShapeQueryParameters2D.new()
	forma.shape = circulo
	forma.transform = Transform2D(0.0, hasta)
	forma.collision_mask = mascara
	forma.collide_with_areas = false
	var tocados := espacio.intersect_shape(forma, 1)
	if not tocados.is_empty():
		return tocados[0]["collider"]
	return null
