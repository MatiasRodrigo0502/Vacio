# resources/gacha/

Los dos gachas (`TiradaGacha`, `scripts/tirada_gacha.gd`): cuánto cuesta una tirada, con
qué se paga, y por cada tier su nombre, su color, su probabilidad (tienen que sumar 100)
y lo que da si sale algo que ya se tiene (`devolucion`). Equilibrarlos es cambiar números
aquí: el panel del gacha los lee de estos archivos.

Una skin repetida da 20, 50, 100 o 250 monedas según su tier (Matías, 2026-11-05, puso
los 20 de la B; lo demás, a ojo: cada tier, más o menos el doble). Una tirada cuesta 100,
así que una S la recupera y una S+ da para dos y media, pero salen tan poco que **de
media se recuperan unas 35 de cada 100**, aunque ya se tengan todas: repetir no da
dinero. Un arma repetida da 1, 2, 3 o 5 diamantes, de los 5 que cuesta.

- `coste_diez`: lo que cuestan diez de golpe (0 = diez veces `coste`).
- `garantia_diez`: en diez de golpe, al menos una de este tier o mejor (0 = ninguna).
- `garantia_maxima`: cada cuántas tiradas sin el tier más alto sale seguro (0 = nunca).
  La cuenta la guarda `Coleccion` y sigue entre partidas. Con ella, lo de arriba sale
  más que su porcentaje: con 60 y el 1 %, en un ~2,2 % de las tiradas.

Las monedas y los diamantes los dan los enemigos al morir: `monedas` y `diamantes` en su
`.tres` de `resources/enemigos/` y `resources/jefes/`. Los diamantes, solo los jefes.
