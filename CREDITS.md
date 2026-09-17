# Créditos de assets

El arte de este proyecto viene de packs de terceros. **Esta lista está
incompleta a propósito**: falta rellenar autor, URL y licencia de cada pack.
Hay que completarla antes de entregar o publicar el juego, porque casi todos
los packs gratuitos exigen atribución.

## En uso

### BlueWizard — personaje jugable
- **Archivos**: `assets/personaje/*.png` (40 frames: 20 de reposo, 20 de andar)
- **Origen**: pack `assets-base.zip`, carpeta `BlueWizard`
- **Procesado**: recortados de 512×512 a la caja útil del personaje (160×280) y
  reescalados a 73×128. Los originales NO están en el repo (ver más abajo).
- **Autor**: PENDIENTE
- **URL**: PENDIENTE
- **Licencia**: PENDIENTE

### Rocas de cueva — obstáculos y decoración
- **Archivos**: `assets/obstaculos/*.png` (33 texturas) + `catalogo_cueva.tres`
- **Origen**: pack `Assets-nivel 1.zip`, carpeta `Assets 1024 Cave`
- **Procesado**: los cuatro atlas se partieron automáticamente en 100 piezas
  sueltas (detectando islas de píxeles opacos). De esas 100 se eligieron a mano
  33: cantos rodados, bloques y grupos de rocas. Se descartaron estalagmitas,
  estalactitas, esquirlas y repisas planas, porque delatan la vista lateral.
  Reescaladas a 192 px de lado máximo.
- **Autor**: PENDIENTE
- **URL**: PENDIENTE
- **Licencia**: PENDIENTE

## Descargados pero todavía sin usar

| Pack | Contenido | Uso previsto |
|---|---|---|
| `assets-base.zip` | Slimes, animaciones de plantas, Mossy Tileset | los slimes, como obstáculos móviles de la Fase 2 |
| `Assets-nivel 1.zip` | Vegetación animada, repisas de plataformas | decoración, pendiente de decidir |
| `Mobs_Personajes.zip` | Tiny RPG Character Asset Pack (Soldier y Orc) | descartado como jugador: es pixel art y no pega con el resto |

## Dónde están los originales

Fuera del repositorio, en `C:\Users\Matias\Gamedev\_assets_origen\`.

**Por qué no están versionados**: son 97 MB y unos 1.250 archivos, con PNGs
sueltos de hasta 5 MB y animaciones de 90 frames como imágenes individuales.
Git guarda todas las versiones de todo lo que entra, así que meterlos enteros
infla el repositorio para siempre aunque luego se borren. En `assets/` entra
solo lo que el juego usa de verdad, ya recortado y reescalado.

Si alguien del equipo clona el repo y necesita los originales, que pida los tres
zips y los extraiga en su propia carpeta `_assets_origen/`.
