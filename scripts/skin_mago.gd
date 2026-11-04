## Una skin: otro aspecto para un solo mago, que sale en el gacha de monedas.
## Solo cambia como se ve, no como juega. Un .tres en resources/skins/ (los hace
## herramientas/generar_skins.py) y ya sale en el gacha.
class_name SkinMago
extends Resource

@export var nombre: String = "Skin"
## De que mago es: su PersonajeJugable.nombre. Por nombre y no con el recurso:
## asi los magos no dependen de sus skins ni al reves.
@export var mago: String = ""
## 0 = B, 1 = A, 2 = S, 3 = S+ (TiradaGacha.tiers).
@export var tier: int = 0
@export var animaciones: SpriteFrames
@export var retrato: Texture2D
## El aura que lleva a los pies en el juego (AuraSkin). Transparente, sin aura.
@export var aura: Color = Color(0.0, 0.0, 0.0, 0.0)
## El aura cambia de color sin parar (las S+).
@export var arcoiris: bool = false
