# resources/armas/

Un `.tres` por arma (`ArmaMago`, `scripts/arma_mago.gd`), con sus `ModoArma`. `Coleccion`
lee esta carpeta y el gacha de diamantes las reparte según su `tier`. **Las genera
`herramientas/generar_armas.py`, de su tabla `ARMAS`**: para cambiar una, se cambia allí
y se vuelve a ejecutar (lo que se toque aquí a mano se pierde).

| Tier | Qué cambia | Cómo se ve en los datos |
|---|---|---|
| Raro | solo el aspecto | un modo con todo a 1, `muerte` 0 |
| Épico | y la forma de disparar | un modo con sus números, `muerte` 0 |
| Legendario | y una animación al matar | `muerte` distinto de 0 |
| Mítico | y varios modos de ataque | varios modos |

Un `ModoArma` son multiplicadores sobre un disparo normal (10 de daño, uno cada 0,5 s) y
su forma: `proyectiles` y `apertura`, `rafaga` y `pausa_rafaga`, `onda`, `atraviesa`,
`rebotes`, `busca` y `explosion`. `estilo` es cómo se pinta la bola (`BolaMagica.Estilo`)
y `muerte`, la animación (`AnimacionMuerte.Tipo`).
