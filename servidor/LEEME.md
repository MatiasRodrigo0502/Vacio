# Servidor de Vacío: cuentas y clasificación

Lo que el juego necesita fuera de él para las cuentas (correo, contraseña y apodo)
y la clasificación. Todo en el plan gratis de Supabase y en GitHub, sin tarjeta.
Godot no mira esta carpeta (`.gdignore`).

```
Juego ──(correo y contraseña)──▶ Supabase Auth ──▶ sesión (token) guardada en user://sesion.cfg
Juego ──(token + partida)──▶ función «subir-puntuacion» ──(token de GitHub, secreto)──▶ commit en Vacio-clasificacion
Juego ◀──(clasificacion.json, lectura libre)── raw.githubusercontent.com
```

- `supabase/migrations/20261119000000_perfiles.sql`: la tabla `perfiles` (el apodo de
  cada cuenta, único sin mirar mayúsculas y de 1 a 16 caracteres), el disparador que
  la rellena al registrarse y `apodo_libre`, para avisar antes de enviar.
- `supabase/functions/subir-puntuacion/index.ts`: comprueba la sesión, que el correo
  esté confirmado, que el apodo sea el de esa cuenta y los datos (formato, precisión
  entre 0 y 100 y que cuadre con impactos y disparos, tiempo razonable). Si es la
  mejor partida de ese jugador, hace el commit; si no, no escribe nada.
- `supabase/config.toml`: la función va sin la comprobación de la pasarela
  (`verify_jwt = false`), porque comprueba la sesión ella misma y así la versión web
  puede hacer la pregunta previa del navegador.

## Qué hay que crear (una vez)

### 1. El proyecto de Supabase
1. En <https://supabase.com>, *New project* (plan Free; región en Europa).
2. *SQL Editor* → *New query* → pega entero `supabase/migrations/20261119000000_perfiles.sql` → *Run*.
3. *Authentication* → *Sign In / Providers* → *Email*: activado y con **Confirm email**
   puesto (viene así). **Y un servidor de correo propio** (*Authentication* → *Emails* →
   *SMTP Settings*): sin él, Supabase solo manda correos a los miembros del proyecto (2
   por hora), y nadie más podría confirmar su cuenta. Supabase nombra Resend, AWS SES,
   Postmark, SendGrid, ZeptoMail y Brevo. Si no se pone, hay que **quitar Confirm
   email** (el juego y la función sirven igual de las dos formas).
4. *Authentication* → *URL Configuration* → *Site URL*:
   `https://matiasrodrigo0502.github.io/Vacio/`. Es a donde lleva el enlace del correo
   de confirmación. Si quieres, en *Emails* se puede poner el texto del correo en
   castellano.

### 2. El repositorio de la clasificación (GitHub)
1. Un repositorio **público** nuevo, `Vacio-clasificacion`. Tiene que ser público
   para que el juego lo lea sin token, y aparte del juego: cada push a `main` de
   Vacío publica una versión nueva, y cada puntuación sacaría una. No hace falta
   crear el JSON: lo crea la función con la primera partida.
2. Un token: *Settings* (tu perfil) → *Developer settings* → *Personal access tokens* →
   *Fine-grained tokens* → *Generate new token*. *Repository access*: **Only select
   repositories** → `Vacio-clasificacion`. *Permissions* → *Contents*: **Read and
   write**. Nada más. Caduca como mucho al año: apúntate cuándo, y al renovarlo
   cambia el secreto del paso 3.

### 3. La función, en Supabase
1. *Edge Functions* → *Deploy a new function* → *Via Editor*. Nombre:
   `subir-puntuacion`. Pega entero `supabase/functions/subir-puntuacion/index.ts` y
   *Deploy*. En sus ajustes (*Details*), **quita «Enforce JWT verification»**.
   (Con el CLI: `supabase functions deploy subir-puntuacion --no-verify-jwt` desde
   esta carpeta.)
2. *Edge Functions* → *Secrets* (Manage secrets):
   - `GITHUB_TOKEN`: el token del paso 2.
   - `GITHUB_REPO`: `MatiasRodrigo0502/Vacio-clasificacion`.
   - (opcionales) `GITHUB_RAMA` (`main`) y `GITHUB_ARCHIVO` (`clasificacion.json`).

   `SUPABASE_URL` y las claves (`SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`, y
   las de antes) ya las pone Supabase.

### 4. El juego
*Project Settings* → *API Keys*: copia **Project URL** y la clave **publishable** en
`resources/cuentas/servicio.tres` (`url_supabase` y `clave_publica`), o pásamelas.
**Estas dos sí pueden ir en el repositorio**: están hechas para ir dentro de las apps
y no dejan hacer nada que no permitan las reglas de la tabla. Lo que **nunca** va en
el repositorio ni en el juego: el token de GitHub y las claves *secret* y *service_role*.

## A tener en cuenta
- **Un proyecto gratis se pausa tras una semana sin uso**: se reactiva desde el panel
  de Supabase (*Restore*). Mientras está pausado, entrar y subir fallan; jugar no.
- **No impide hacer trampas del todo**: quien tenga cuenta puede mandar una partida
  inventada con formato válido. La función corta lo imposible (precisión que no
  cuadra, pisos que no existen, tiempos absurdos), no lo improbable.
- La clasificación se lee de `raw.githubusercontent.com`, que guarda copias unos
  minutos: una partida recién subida puede tardar en salir.
