# Vacío — magos y hechizos

Cuatro magos jugables en 8 direcciones, cada uno con su ataque normal y su ultimate,
y los enemigos de los 12 niveles (3 criaturas con 3 variantes de capa + el jefe final).
Todo es vectorial (los `.svg` están en cada carpeta `svg/`) y se puede regenerar
con los scripts de `scripts/`.

| Mago | Ataque normal | Ultimate |
|---|---|---|
| **Piromante** (fuego) | Bola de fuego | Bola de fuego gigante (meteoro) |
| **Envenenador** (veneno) | 3 dardos en abanico (envenenan) | Lluvia de veneno |
| **Criomante** (hielo) | Lanza de hielo (ralentiza) | Escudo de hielo |
| **Mago del Vacío** (vacío) | Bola de fuego morada | Agujero negro |

## Magos — `magos/<mago>/<mago>_spritesheet_8dir.png`

- 4 columnas (frames de caminar) × 8 filas (direcciones), frames de **128×128**.
- Filas en el orden de `Vector2.angle()`: 0=E, 1=SE, 2=S, 3=SO, 4=O, 5=NO, 6=N, 7=NE.
- El frame 0 sirve de reposo. El Mago del Vacío **levita**: no da pasos, oscila en el aire.
- Script: `godot/mago_8_direcciones.gd` (`hframes = 4`, `vframes = 8`).
- Filtro de textura: **Linear** (no es pixel art).

## Hechizos — `hechizos/<mago>/`

El **desfase** es el `offset` del `AnimatedSprite2D` para que el punto importante
(la punta del proyectil, el centro de la explosión, el suelo...) quede en el origen del nodo.
Todos los proyectiles están dibujados mirando a la **derecha**: `rotation = direccion.angle()`.

### Envenenador
| Archivo | Frames (cuadrícula) | Tamaño frame | FPS | Desfase |
|---|---|---|---|---|
| `dardo_vuelo.png` | 4 (4×1), bucle | 96×32 | 12 | (-42, 0) |
| `dardo_impacto.png` | 6 (6×1) | 96×96 | 16 | (0, -4) |
| `estado_envenenado.png` | 6 (6×1), bucle | 96×96 | 10 | (0, -38) a los pies |
| `lluvia_nube_aparece.png` | 6 (3×2) | 384×192 | 10 | nube en (0, -150) |
| `lluvia_nube_bucle.png` | 6 (3×2), bucle | 384×192 | 8 | nube en (0, -150) |
| `lluvia_gota.png` | 3 (3×1), bucle | 24×48 | 12 | (0, -20) |
| `lluvia_salpicadura.png` | 6 (6×1) | 96×64 | 16 | (0, -16) |
| `lluvia_zona_toxica.png` | 6 (3×2), bucle | 384×192 | 8 | (0, 0) |

Para que la nube desaparezca: `play_backwards("aparece")`.

### Criomante
| Archivo | Frames (cuadrícula) | Tamaño frame | FPS | Desfase |
|---|---|---|---|---|
| `lanza_vuelo.png` | 4 (4×1), bucle | 128×48 | 12 | (-55, 0) |
| `lanza_impacto.png` | 8 (8×1) | 128×128 | 16 | (0, 2) |
| `estado_ralentizado.png` | 6 (6×1), bucle | 96×96 | 10 | (0, -38) a los pies |
| `escudo_aparece_detras/delante.png` | 8 (4×2) | 256×256 | 14 | (0, 0) centrado en el mago |
| `escudo_bucle_detras/delante.png` | 6 (3×2), bucle | 256×256 | 8 | (0, 0) |
| `escudo_rompe_detras/delante.png` | 8 (4×2) | 256×256 | 14 | (0, 0) |

El escudo va en **dos capas**: `Detras` con `z_index = -1` y `Delante` con `z_index = 1`,
así el mago queda dentro de la burbuja.

### Mago del Vacío
| Archivo | Frames (cuadrícula) | Tamaño frame | FPS | Desfase |
|---|---|---|---|---|
| `bola_morada_vuelo.png` | 6 (6×1), bucle | 128×64 | 12 | (-26, 0) |
| `bola_morada_impacto.png` | 8 (8×1) | 128×128 | 16 | (0, 2) |
| `agujero_orbe_vuelo.png` | 6 (6×1), bucle | 128×64 | 12 | (-26, 0) |
| `agujero_abrir.png` | 8 (4×2) | 384×384 | 12 | (0, -4) |
| `agujero_bucle.png` | 8 (4×2), bucle | 384×384 | 12 | (0, -4) |
| `agujero_colapso.png` | 8 (4×2) | 384×384 | 14 | (0, -4) |

### Piromante
Ver la cabecera de `godot/proyectil_fuego.gd` y `godot/ultimate_fuego.gd`.

## Enemigos — `enemigos/<enemigo>/`

Cada enemigo normal tiene **3 variantes de capa**: `corteza` (niveles 1-4), `manto` (5-8) y
`nucleo` (9-11). El **jefe** es para el nivel 12 (núcleo interno).
Cada animación es una hoja de **8 filas** (direcciones, mismo orden que los magos) × N columnas.
Nombre de archivo: `<enemigo>_<capa>_<animación>.png`.

| Enemigo | Rol | Frame | caminar | atacar | daño | muerte | Golpea en | Desfase pies |
|---|---|---|---|---|---|---|---|---|
| **Gólem** | Cuerpo a cuerpo (golpe a dos manos) | 128×128 | 4 | 6 | 3 | 8 | frame 3 | (0, -49) |
| **Vigía** | A distancia (dispara esquirlas) | 96×96 | 4 (flota) | 6 | 3 | 8 | frame 3 | (0, -37) |
| **Murciélago** | Enjambre (mordisco en picado) | 64×64 | 4 (vuela) | 4 | 3 | 6 | frame 2 | (0, -26) |
| **Corazón del Núcleo** | Jefe (nova + anillo de bolas) | 384×384 | `flotar` 6 | 8 | 3 | 10 | frame 4 | (0, -148) |

FPS recomendados: caminar 8, atacar 12, daño 12, muerte 10 (jefe: flotar 8, atacar 10, muerte 8).

Proyectiles:
- Vigía: `vigia_<capa>_esquirla_vuelo.png` (4 frames 64×32, desfase (-27, 0)) y
  `vigia_<capa>_esquirla_impacto.png` (6 frames 64×64).
- Jefe: `jefe_bola_vuelo.png` (6 de 128×64, desfase (-26, 0)) y `jefe_bola_impacto.png` (8 de 128×128).
- Usa `proyectil_magico.gd` y pon las **capas de colisión** para que los proyectiles enemigos
  solo detecten al jugador (si no, el Vigía se dispararía a sí mismo).

Scripts:
| Script | Para qué |
|---|---|
| `sprite_frames_8dir.gd` | Crea por código las 32 animaciones (4 × 8 direcciones) a partir de las hojas |
| `enemigo.gd` | IA del Gólem, Vigía y Murciélago: perseguir, atacar, daño, muerte, ralentizado, empuje |
| `jefe_nucleo.gd` | IA del jefe: flota, nova cada pocos segundos, furia por debajo del 50 % |

Los enemigos se añaden al grupo `"objetivos"` (los hechizos de los magos ya los encuentran)
y buscan al jugador en el grupo `"jugador"`. Activa **Y-sort** en el nodo que los contiene.

## Scripts de Godot — `godot/`

| Script | Para qué |
|---|---|
| `mago_8_direcciones.gd` | Movimiento y animación en 8 direcciones |
| `proyectil_magico.gd` | Proyectil genérico (dardo, lanza, bola morada) con estado opcional |
| `ataques_normales.gd` | Cómo dispara cada mago (abanico de dardos, etc.) |
| `estado_alterado.gd` | Componente para enemigos: veneno (daño por tiempo) y ralentización |
| `lluvia_veneno.gd` + `gota_veneno.gd` | Ultimate del Envenenador |
| `escudo_hielo.gd` | Ultimate del Criomante |
| `agujero_negro.gd` | Ultimate del Mago del Vacío |
| `proyectil_fuego.gd`, `ultimate_fuego.gd` | Ataques del Piromante |

Los scripts buscan a los enemigos en el grupo `"objetivos"` y les llaman a
`recibir_danio(cantidad)`; el agujero negro usa `empujar(vector)` si existe.

## Regenerar

```bash
python3 scripts/generar_magos.py              # los 4 magos (o: criomante vacio ...)
python3 scripts/generar_hechizos.py           # hechizos del Piromante
python3 scripts/generar_hechizos_magos.py     # Envenenador, Criomante y Vacío
python3 scripts/demo_magos.py                 # GIF de demostración
python3 scripts/generar_enemigos.py           # enemigos (o: golem vigia murcielago jefe)
python3 scripts/galeria_enemigos.py           # galerías animadas de los enemigos
```
Requiere Python 3 con Pillow y `rsvg-convert` (librsvg).
