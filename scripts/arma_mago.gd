## Un arma: sale en el gacha de diamantes y la lleva el mago, sea cual sea. Lo
## pidio Matias el 2026-11-04, y cada tier da mas que el anterior:
##
##   raro        solo cambia el aspecto
##   epico       el aspecto y la forma de disparar
##   legendario  ademas, una animacion al matar
##   mitico      ademas, varios modos de ataque (la rueda del raton)
##
## Un .tres en resources/armas/ (los hace herramientas/generar_armas.py) y ya
## sale en el gacha. Solo cambia el disparo normal: el ataque especial sigue
## siendo del mago, y sus efectos (la quemadura del rojo, el frio del blanco)
## siguen en las bolas.
class_name ArmaMago
extends Resource

## Lo que quita una bola de un arma con el multiplicador a 1. Es lo de un mago
## normal: el rocio del verde (1 por gota, 18 por segundo) se cambia por el arma.
const DANO_BASE: float = 10.0

const RARO: int = 0
const EPICO: int = 1
const LEGENDARIO: int = 2
const MITICO: int = 3

@export var nombre: String = "Arma"
@export_multiline var descripcion: String = ""
@export var tier: int = RARO
## Dibujada mirando a la derecha: flota junto al mago, apuntando (ArmaFlotante).
@export var icono: Texture2D
## Centro y resplandor de sus bolas.
@export var color: Color = Color.WHITE
@export var halo: Color = Color.WHITE
## Como se pinta la bola (BolaMagica.Estilo).
@export var estilo: int = 0
## La animacion al matar (AnimacionMuerte.Tipo). 0 = ninguna.
@export var muerte: int = 0
## Sus formas de disparar. Un raro tiene una con todo a 1.
@export var modos: Array[ModoArma] = []


## El raro no cambia como se dispara: al mago verde le deja su rocio.
func solo_aspecto() -> bool:
	return tier == RARO


func tiene_modos() -> bool:
	return modos.size() > 1
