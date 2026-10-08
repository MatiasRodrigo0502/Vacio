## Como es la pared que rodea las salas de un piso: su roca, la cara que se ve
## de frente en la pared de arriba, los pilares de las puertas y lo que crece,
## cuelga o sobresale de ella.
##
## Cada piso tiene el suyo (assets/bordes/piso_NN/estilo_borde.tres), porque
## cada piso es una capa distinta de la Tierra. Las texturas y este .tres salen
## de herramientas/generar_bordes.py: para cambiar el borde de un piso se
## cambia su tema alli y se vuelve a ejecutar.
class_name EstiloBorde
extends Resource

@export_group("Texturas")
## La roca vista desde arriba. Se repite sin costuras, alineada con el mundo.
@export var muro: Texture2D
## La cara vertical de la pared de arriba. Se repite en horizontal: arriba el
## labio que coge luz, abajo el pie que toca el suelo.
@export var cara: Texture2D
@export var pilar: Texture2D

@export_group("Piezas")
## Lo que crece o asoma encima de la pared, junto al canto: hierba, setas,
## cristales... No choca: esta sobre la roca.
@export var adornos: Array[Texture2D] = []
## Lo que cuelga de la cara de la pared de arriba: raices, estalactitas, gotas.
@export var colgantes: Array[Texture2D] = []
## Piezas grandes que salen de la pared hacia la sala. Chocan: se ven solidas
## y el jugador tiene que poder fiarse de lo que ve.
@export var salientes: Array[Texture2D] = []

@export_group("Colores")
## El canto de la pared, que coge la luz.
@export var color_luz: Color = Color(0.85, 0.78, 0.6)
## La raya oscura del pie de la pared y la sombra que echa sobre el suelo.
@export var color_sombra: Color = Color(0.06, 0.04, 0.03)

@export_group("Forma")
## Alto de la cara de la pared de arriba, en pixeles.
@export var alto_cara: float = 50.0
## Cuanto se mete la pared en la sala, de media, en pixeles.
@export var entrada: float = 18.0
## Cuanto va y viene el canto alrededor de esa media. Es lo que hace que el
## limite sea roca y no una raya recta.
@export var ondulacion: float = 12.0

@export_group("Cuantas piezas")
## Cada cuantos pixeles de canto va un adorno (de media).
@export var adornos_cada: float = 60.0
## Cada cuantos pixeles de la pared de arriba cuelga algo.
@export var colgantes_cada: float = 80.0
@export var salientes_por_sala: int = 3
