// Funcion de Supabase «subir-puntuacion» (Matias, 2026-11-19): el unico sitio que
// escribe en la clasificacion de GitHub.
//
// POR QUE UN INTERMEDIARIO Y NO EL JUEGO DIRECTAMENTE:
// para escribir en GitHub hace falta un token con permiso de escritura, y todo lo
// que va dentro del juego se puede sacar de la build. Aqui el token vive en los
// secretos de Supabase (GITHUB_TOKEN) y solo tiene permiso sobre el repositorio de
// la clasificacion, no sobre el del juego. Leer si lo hace el juego directo, de
// raw.githubusercontent.com.
//
// Lo que comprueba antes de escribir:
// - La sesion: pide la cuenta a Supabase con el token que trae (Authorization). Sin
//   cuenta, o con el correo sin confirmar, no sube nada.
// - El apodo: lo saca de la tabla perfiles con la clave de servicio, no de lo que
//   mande el juego; si el juego manda otro, se rechaza.
// - Los datos (validar): formato, precision entre 0 y 100 y que cuadre con los
//   impactos y disparos, y un tiempo razonable para el piso al que llego.
//
// Solo se guarda la mejor partida de cada jugador (Matias): mas hondo y, a igual
// piso, ganar antes que perder y menos tiempo (esMejor). Si no mejora, no se
// escribe nada en GitHub.
//
// Un solo archivo a proposito: se puede pegar tal cual en el editor de funciones
// del panel de Supabase. Lo de arriba (validar, esMejor, ponerEnTabla) no depende de
// Deno, para poder probarlo aparte.

export type Partida = {
  mago: string;
  dispositivo: string;
  control: string;
  piso: number;
  victoria: boolean;
  tiempo_s: number;
  precision: number;
  disparos: number;
  impactos: number;
  version_juego: string;
};

export type Entrada = Partida & { apodo: string; fecha: string };

export type Tabla = { version: number; actualizado: string; entradas: Entrada[] };

export const PISOS = 12;
export const DISPOSITIVOS = ["pc", "movil", "navegador"];
// De menos a mas: el juego manda el mas alto que se haya usado en la partida.
export const CONTROLES = ["botones", "joysticks", "raton", "automatico"];
// Un piso no se cruza en menos de esto (salas con enemigos que hay que limpiar), y
// una partida de mas de 10 h no es una partida.
export const SEGUNDOS_MINIMOS_POR_PISO = 10;
export const SEGUNDOS_MAXIMOS = 10 * 3600;
// El mas rapido es el rocio del verde (9 por segundo) con un arma de varias bolas.
export const DISPAROS_MAXIMOS_POR_SEGUNDO = 60;

function esEntero(valor: unknown, minimo: number, maximo: number): boolean {
  return typeof valor === "number" && Number.isInteger(valor) && valor >= minimo && valor <= maximo;
}

function esNumero(valor: unknown, minimo: number, maximo: number): boolean {
  return typeof valor === "number" && Number.isFinite(valor) && valor >= minimo && valor <= maximo;
}

// Lo que manda el juego, comprobado campo a campo. Devuelve la partida limpia (solo
// los campos conocidos, redondeados) o el porque.
export function validar(datos: unknown): { ok: true; partida: Partida } | { ok: false; error: string } {
  if (typeof datos !== "object" || datos === null || Array.isArray(datos)) {
    return { ok: false, error: "no es un objeto" };
  }
  const d = datos as Record<string, unknown>;
  if (typeof d.mago !== "string" || !/^[a-z0-9_]{1,40}$/.test(d.mago)) return { ok: false, error: "mago" };
  if (typeof d.dispositivo !== "string" || !DISPOSITIVOS.includes(d.dispositivo)) {
    return { ok: false, error: "dispositivo" };
  }
  if (typeof d.control !== "string" || !CONTROLES.includes(d.control)) return { ok: false, error: "control" };
  if (!esEntero(d.piso, 1, PISOS)) return { ok: false, error: "piso" };
  if (typeof d.victoria !== "boolean") return { ok: false, error: "victoria" };
  // Ganar es pasar el ultimo piso.
  if (d.victoria && d.piso !== PISOS) return { ok: false, error: "victoria sin llegar al final" };
  const piso = d.piso as number;
  if (!esNumero(d.tiempo_s, piso * SEGUNDOS_MINIMOS_POR_PISO, SEGUNDOS_MAXIMOS)) {
    return { ok: false, error: "tiempo" };
  }
  const tiempo = d.tiempo_s as number;
  if (!esEntero(d.disparos, 0, Math.ceil(tiempo * DISPAROS_MAXIMOS_POR_SEGUNDO))) {
    return { ok: false, error: "disparos" };
  }
  const disparos = d.disparos as number;
  if (!esEntero(d.impactos, 0, disparos)) return { ok: false, error: "impactos" };
  const impactos = d.impactos as number;
  if (!esNumero(d.precision, 0, 100)) return { ok: false, error: "precision" };
  // La precision es impactos / disparos: si no cuadra, alguien la ha escrito a mano.
  const esperada = disparos === 0 ? 0 : (impactos / disparos) * 100;
  if (Math.abs((d.precision as number) - esperada) > 0.1) return { ok: false, error: "precision no cuadra" };
  if (typeof d.version_juego !== "string" || d.version_juego.length > 40) {
    return { ok: false, error: "version_juego" };
  }
  return {
    ok: true,
    partida: {
      mago: d.mago,
      dispositivo: d.dispositivo,
      control: d.control,
      piso,
      victoria: d.victoria,
      tiempo_s: Math.round(tiempo * 10) / 10,
      precision: Math.round(esperada * 10) / 10,
      disparos,
      impactos,
      version_juego: d.version_juego,
    },
  };
}

// Mas hondo; a igual piso, ganar antes que perder (en el 12 se puede morir contra
// el jefe); y luego menos tiempo.
export function esMejor(nueva: Partida, vieja: Partida): boolean {
  if (nueva.piso !== vieja.piso) return nueva.piso > vieja.piso;
  if (nueva.victoria !== vieja.victoria) return nueva.victoria;
  return nueva.tiempo_s < vieja.tiempo_s;
}

export function ordenar(entradas: Entrada[]): Entrada[] {
  return [...entradas].sort((a, b) => (esMejor(a, b) ? -1 : esMejor(b, a) ? 1 : 0));
}

// Pone la partida en la tabla si es la primera de ese apodo o mejora la suya. El
// apodo viene de la tabla perfiles, que no deja dos iguales sin mirar mayusculas;
// aqui se compara igual por si acaso.
export function ponerEnTabla(tabla: Tabla, entrada: Entrada): { tabla: Tabla; mejora: boolean; puesto: number } {
  const clave = entrada.apodo.toLowerCase();
  const vieja = tabla.entradas.find((e) => e.apodo.toLowerCase() === clave);
  if (vieja !== undefined && !esMejor(entrada, vieja)) {
    return { tabla, mejora: false, puesto: tabla.entradas.indexOf(vieja) + 1 };
  }
  const otras = tabla.entradas.filter((e) => e.apodo.toLowerCase() !== clave);
  const entradas = ordenar([...otras, entrada]);
  return {
    tabla: { version: 1, actualizado: entrada.fecha, entradas },
    mejora: true,
    puesto: entradas.indexOf(entrada) + 1,
  };
}

export function tablaVacia(): Tabla {
  return { version: 1, actualizado: new Date(0).toISOString(), entradas: [] };
}

// --- Lo que habla con Supabase y con GitHub -------------------------------------

type Entorno = { get(nombre: string): string | undefined };

// La version web llama desde otra direccion (GitHub Pages, Vercel): el navegador
// pregunta antes (OPTIONS) y necesita estas cabeceras en todas las respuestas.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(estado: number, cuerpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function aBase64(texto: string): string {
  const bytes = new TextEncoder().encode(texto);
  let binario = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binario += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binario);
}

function deBase64(base64: string): string {
  const binario = atob(base64.replace(/\s/g, ""));
  return new TextDecoder().decode(Uint8Array.from(binario, (c) => c.charCodeAt(0)));
}

// Las claves de Supabase: las nuevas (sb_publishable_, sb_secret_) llegan en un
// diccionario JSON; las de antes (anon, service_role), sueltas, y Supabase las quita a
// finales de 2026. Primero las nuevas.
function clave(entorno: Entorno, diccionario: string, vieja: string): string {
  try {
    const claves = JSON.parse(entorno.get(diccionario) ?? "{}") as Record<string, string>;
    const nueva = claves.default ?? Object.values(claves)[0];
    if (nueva) return nueva;
  } catch {
    // No es JSON: se usa la de antes.
  }
  return entorno.get(vieja) ?? "";
}

// La cuenta de quien llama, preguntando a Supabase con su token: si esta caducado o
// es falso, no hay cuenta.
async function leerUsuario(entorno: Entorno, token: string): Promise<Record<string, unknown> | null> {
  const respuesta = await fetch(`${entorno.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: clave(entorno, "SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"),
    },
  });
  if (!respuesta.ok) return null;
  return await respuesta.json();
}

async function leerApodo(entorno: Entorno, id: string): Promise<string | null> {
  const servicio = clave(entorno, "SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  // Las nuevas solo van en apikey; la de antes es un token y va tambien en Authorization.
  const cabeceras: Record<string, string> = { apikey: servicio };
  if (!servicio.startsWith("sb_")) cabeceras.Authorization = `Bearer ${servicio}`;
  const url = `${entorno.get("SUPABASE_URL")}/rest/v1/perfiles?id=eq.${encodeURIComponent(id)}&select=apodo`;
  const respuesta = await fetch(url, { headers: cabeceras });
  if (!respuesta.ok) return null;
  const filas = await respuesta.json();
  return Array.isArray(filas) && filas.length === 1 ? String(filas[0].apodo) : null;
}

function cabecerasGitHub(entorno: Entorno): Record<string, string> {
  return {
    Authorization: `Bearer ${entorno.get("GITHUB_TOKEN")}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "vacio-clasificacion",
  };
}

function urlArchivo(entorno: Entorno): string {
  const repositorio = entorno.get("GITHUB_REPO");
  const archivo = entorno.get("GITHUB_ARCHIVO") ?? "clasificacion.json";
  return `https://api.github.com/repos/${repositorio}/contents/${archivo}`;
}

// La tabla de ahora y su sha (lo pide GitHub para cambiarla). Sin archivo, vacia.
async function leerTabla(entorno: Entorno): Promise<{ tabla: Tabla; sha?: string }> {
  const rama = entorno.get("GITHUB_RAMA") ?? "main";
  const respuesta = await fetch(`${urlArchivo(entorno)}?ref=${encodeURIComponent(rama)}`, {
    headers: cabecerasGitHub(entorno),
  });
  if (respuesta.status === 404) return { tabla: tablaVacia() };
  if (!respuesta.ok) throw new Error(`GitHub ${respuesta.status} al leer`);
  const archivo = await respuesta.json();
  const tabla = JSON.parse(deBase64(archivo.content)) as Tabla;
  if (!Array.isArray(tabla.entradas)) throw new Error("la tabla de GitHub no tiene entradas");
  return { tabla, sha: archivo.sha };
}

// Un commit con la tabla nueva. «conflicto» si otro la ha cambiado entre medias
// (otro jugador subiendo a la vez): se vuelve a leer y a intentar.
async function escribirTabla(entorno: Entorno, tabla: Tabla, sha: string | undefined, mensaje: string): Promise<"ok" | "conflicto"> {
  const cuerpo: Record<string, unknown> = {
    message: mensaje,
    content: aBase64(JSON.stringify(tabla, null, 1) + "\n"),
    branch: entorno.get("GITHUB_RAMA") ?? "main",
  };
  if (sha !== undefined) cuerpo.sha = sha;
  const respuesta = await fetch(urlArchivo(entorno), {
    method: "PUT",
    headers: { ...cabecerasGitHub(entorno), "Content-Type": "application/json" },
    body: JSON.stringify(cuerpo),
  });
  if (respuesta.status === 409 || respuesta.status === 422) return "conflicto";
  if (!respuesta.ok) throw new Error(`GitHub ${respuesta.status} al escribir`);
  return "ok";
}

const INTENTOS = 4;

export async function atender(peticion: Request, entorno: Entorno): Promise<Response> {
  if (peticion.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (peticion.method !== "POST") return responder(405, { error: "metodo" });

  const token = (peticion.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (token === "") return responder(401, { error: "sin_sesion" });
  const usuario = await leerUsuario(entorno, token);
  if (usuario === null || typeof usuario.id !== "string") return responder(401, { error: "sesion_caducada" });
  if (!usuario.email_confirmed_at) return responder(403, { error: "correo_sin_confirmar" });
  const apodo = await leerApodo(entorno, usuario.id);
  if (apodo === null) return responder(403, { error: "sin_apodo" });

  let datos: unknown;
  try {
    datos = await peticion.json();
  } catch {
    return responder(400, { error: "datos_invalidos", detalle: "no es JSON" });
  }
  // El apodo que dice el juego tiene que ser el de la cuenta con la que ha entrado.
  const pedido = (datos as Record<string, unknown> | null)?.apodo;
  if (typeof pedido === "string" && pedido.toLowerCase() !== apodo.toLowerCase()) {
    return responder(403, { error: "apodo_ajeno" });
  }
  const validado = validar(datos);
  if (!validado.ok) return responder(400, { error: "datos_invalidos", detalle: validado.error });

  const entrada: Entrada = { ...validado.partida, apodo, fecha: new Date().toISOString() };
  try {
    for (let intento = 0; intento < INTENTOS; intento++) {
      const { tabla, sha } = await leerTabla(entorno);
      const puesta = ponerEnTabla(tabla, entrada);
      if (!puesta.mejora) return responder(200, { subida: false, puesto: puesta.puesto });
      const mensaje = `${apodo}: piso ${entrada.piso}${entrada.victoria ? " (victoria)" : ""} en ${entrada.tiempo_s} s`;
      if ((await escribirTabla(entorno, puesta.tabla, sha, mensaje)) === "ok") {
        return responder(200, { subida: true, puesto: puesta.puesto });
      }
    }
    return responder(503, { error: "ocupado" });
  } catch (fallo) {
    console.error(fallo);
    return responder(502, { error: "github" });
  }
}

// En Supabase (Deno). Fuera de Deno (las pruebas) no se arranca nada.
declare const Deno: { env: Entorno; serve(manejador: (peticion: Request) => Promise<Response>): void } | undefined;
if (typeof Deno !== "undefined" && typeof Deno.serve === "function") {
  const deno = Deno;
  deno.serve((peticion) => atender(peticion, deno.env));
}
