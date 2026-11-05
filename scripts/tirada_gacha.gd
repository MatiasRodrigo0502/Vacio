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


func moneda() -> String:
	return "diamantes" if usa_diamantes else "monedas"
