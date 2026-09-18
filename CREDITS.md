# Créditos de assets

Todo el arte del juego viene de packs de terceros publicados en itch.io.

> **Falta un dato**: la licencia exacta de cada pack. No he podido abrir las
> páginas de itch.io desde aquí para leer sus términos, así que en vez de
> suponerlos los dejo marcados como *sin verificar*. Antes de entregar o
> publicar el juego, entra en cada enlace y copia aquí lo que diga su sección
> de licencia o el `README`/`LICENSE` del propio pack. Lo que hay que mirar es
> si permite uso comercial y si exige atribución; casi todos los packs
> gratuitos la exigen, y esta página es precisamente la atribución.

## En uso

### BlueWizard — personaje jugable

- **Pack**: Mossy Cavern
- **Autor**: maaot
- **URL**: https://maaot.itch.io/mossy-cavern
- **Licencia**: sin verificar
- **Archivos**: `assets/personaje/*.png` (40 frames) + `animaciones_mago.tres`
- **Procesado**: recortados de 512×512 a la caja útil del personaje (160×280) y
  reescalados a 73×128. Los originales no están en el repo (ver más abajo).

### Musgo — arte del piso 2

- **Pack**: Mossy Cavern
- **Autor**: maaot
- **URL**: https://maaot.itch.io/mossy-cavern
- **Licencia**: sin verificar
- **Archivos**: `assets/musgo/*.png` (41 texturas) + `catalogo_musgo.tres`
- **Procesado**: los atlas `Decorations&Hazards`, `FloatingPlatforms` y
  `MossyHills` se partieron en piezas sueltas y se eligieron matorrales, rocas
  con musgo y lianas con pinchos (que en el pack original ya son peligros, así
  que aquí también hacen daño). Las plantas animadas aportan un frame cada una.

### Cueva — arte del piso 1 y base de los pisos 3 al 12

- **Pack**: 2D Brown Cave Assets
- **Autor**: maaot
- **URL**: https://maaot.itch.io/2d-browncave-assets
- **Licencia**: sin verificar
- **Archivos**: `assets/cueva/*.png` (53 texturas) + `catalogo_cueva.tres` y
  `catalogo_cueva_vegetal.tres`
- **Procesado**: los cuatro atlas de cueva se partieron automáticamente en 100
  piezas sueltas (detectando islas de píxeles opacos) y se eligieron a mano las
  que funcionan en vista cenital: cantos rodados, bloques, grupos de rocas y
  repisas planas para plataformas. Se descartaron estalagmitas, estalactitas y
  esquirlas, porque delatan la vista lateral. Más su vegetación seca.

## Descargado y descartado

### Tiny RPG Character Asset Pack (Soldier & Orc)

- **Autor**: Zerie
- **URL**: https://zerie.itch.io/tiny-rpg-character-asset-pack
- **Licencia**: sin verificar
- **Por qué no se usa**: es pixel art y los otros dos packs son arte
  renderizado. Mezclarlos canta mucho. Se valoró como personaje jugable (es el
  único con animación de golpe y de muerte) y se descartó por eso.

**No hay ningún archivo suyo en el repositorio**, así que hoy por hoy no
requiere atribución. Si algún día se usa, hay que moverlo a la lista de arriba.

## Pendiente de usar

| Pack | Contenido sin usar | Uso previsto |
|---|---|---|
| Mossy Cavern | Slimes | obstáculos móviles de la Fase 2 |
| 2D Brown Cave Assets | secuencias completas de animación | animar la vegetación |

## Dónde están los originales

Fuera del repositorio, en `C:\Users\Matias\Gamedev\_assets_origen\`.

**Por qué no se versionan**: son 97 MB y unos 1.250 archivos, con PNGs sueltos
de hasta 5 MB y animaciones de 90 frames como imágenes individuales. Git guarda
todas las versiones de todo lo que entra, así que meterlos enteros infla el
repositorio para siempre aunque luego se borren. En `assets/` entra solo lo que
el juego usa de verdad, ya recortado y reescalado.

Si alguien del equipo clona el repo y necesita los originales, que se los baje
de los enlaces de arriba y los extraiga en su propia carpeta `_assets_origen/`.
