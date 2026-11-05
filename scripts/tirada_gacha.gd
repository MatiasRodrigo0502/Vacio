## Un gacha: cuanto cuesta tirar, con que se paga y que probabilidad tiene cada
## tier. Pedido por Matias el 2026-11-04: uno de skins (monedas; B 70 %, A 20 %,
## S 9 %, S+ 1 %) y otro de armas (diamantes; raro, epico, legendario y mitico,
## con los mismos porcentajes). Son resources/gacha/*.tres: equilibrar el gacha
## es cambiar numeros ahi.
class_name TiradaGacha
extends Resource

@export var nombre: String = "Gacha"
## Cuanto cuesta una tirada, en monedas o, si 'usa_diamantes', en diamantes.
@export var coste: int = 100
@export var usa_diamantes: bool = false
## Un tier por posicion, del mas comun al mas raro: nombre, color, probabilidad
## en % (tienen que sumar 100) y lo que da si sale uno que ya se tiene.
@export var tiers: PackedStringArray = PackedStringArray()
@export var colores: PackedColorArray = PackedColorArray()
@export var probabilidades: PackedFloat32Array = PackedFloat32Array()
@export var devolucion: PackedInt32Array = PackedInt32Array()

@export_group("Tiradas de diez y garantia")
## Lo que cuestan diez de golpe. Con 0, diez veces 'coste'. Algo menos que diez
## sueltas: es lo que anima a juntar para tirar diez.
@export var coste_diez: int = 0
## En diez de golpe, al menos una sale de este tier o mejor (si las nueve
## primeras no lo traen, la decima lo trae). Con 0, ninguna garantia.
@export var garantia_diez: int = 1
## Cada cuantas tiradas sin el tier mas alto sale seguro (lo que en los gachas
## se llama "pity"). Con el 1 %, sin esto hay quien tira 300 veces sin verlo.
## Con 0, sin garantia.
@export var garantia_maxima: int = 0


## El tier que sale, segun las probabilidades. 'azar' es de 0 a 100; se le pasa
## para poder comprobar el reparto sin depender de la suerte.
func tier_para(azar: float) -> int:
	var acumulado := 0.0
	for i in probabilidades.size():
		acumulado += probabilidades[i]
		if azar < acumulado:
			return i
	return probabilidades.size() - 1


func sacar_tier() -> int:
	return tier_para(randf() * 100.0)


## Lo que cuestan 'veces' tiradas de golpe.
func coste_de(veces: int) -> int:
	if veces == 10 and coste_diez > 0:
		return coste_diez
	return coste * veces


func tier_maximo() -> int:
	return probabilidades.size() - 1


func moneda() -> String:
	return "diamantes" if usa_diamantes else "monedas"
