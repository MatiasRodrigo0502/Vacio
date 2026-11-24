## Donde estan las cuentas y la clasificacion (Matias, 2026-11-19): el proyecto de
## Supabase y el JSON de GitHub. Un recurso (resources/cuentas/servicio.tres) y no
## constantes en el codigo, para cambiar de proyecto sin tocar scripts.
##
## NADA DE ESTO ES SECRETO: la URL y la clave publica de Supabase estan
## hechas para ir dentro de las apps; lo que protege los datos son las reglas de la
## base de datos (servidor/supabase/migrations). Lo secreto (el token de GitHub y la
## clave de servicio) vive en Supabase, nunca aqui. Ver servidor/LEEME.md.
class_name ConfiguracionCuentas
extends Resource

## https://<proyecto>.supabase.co, sin barra al final. Vacio: cuentas apagadas.
@export var url_supabase: String = ""
## La «publishable» de Supabase (sb_publishable_..., Project Settings → API Keys). La
## «anon» de antes tambien vale, pero Supabase la quita a finales de 2026.
@export var clave_publica: String = ""
## El JSON de la clasificacion, en crudo: https://raw.githubusercontent.com/<dueno>/<repo>/main/clasificacion.json
@export var url_clasificacion: String = ""


func cuentas_listas() -> bool:
	return url_supabase != "" and clave_publica != ""
