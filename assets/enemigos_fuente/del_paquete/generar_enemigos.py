"""Enemigos de Vacío: Gólem, Vigía, Murciélago y el jefe Corazón del Núcleo.

Cada enemigo normal tiene 3 VARIANTES DE CAPA (corteza, manto, núcleo): la misma
geometría con otro "tema" de materiales y colores.

Cada animación se exporta como un sprite sheet de 8 FILAS (direcciones, en el
orden de Vector2.angle() de Godot: E, SE, S, SO, O, NO, N, NE) x N COLUMNAS (frames).

Técnica: la misma pseudo-3D de los magos. Cada pieza vive en un ángulo phi
alrededor del cuerpo; al girar el cuerpo (theta) se proyecta con sin/cos y la
profundidad z decide si se pinta delante o detrás.

Uso:  python3 generar_enemigos.py [golem] [vigia] [murcielago] [jefe]
"""
import math, os, os, random, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generar_hechizos as gh
import generar_magos as gm
from generar_hechizos import P, TAU, blob_d, lengua, suave

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + "/enemigos"
PROF_Y = 0.2
PASO = [0, 1, 0, -1]


def sc(theta, phi=0):
    a = math.radians(theta + phi)
    return math.sin(a), math.cos(a)


def cil(theta, phi, r, cx, y):
    """Punto en un cilindro alrededor del cuerpo -> (x, y, z)."""
    s, z = sc(theta, phi)
    return cx + r * s, y + z * r * PROF_Y, z


def theta_de_fila(k):
    return 90 - 45 * k


# =============================================================== TEMAS ===
TEMAS = {
    "corteza": dict(roca=("#a2927c", "#5e5044", "#241e1a"), contorno="#120e0a", grieta="#ffb84a", grieta2="#ffe6a0",
                    intensidad=.55, ojo="#ffd36b", cristal=("#fff4d0", "#ffcf6a", "#b07a24"), membrana=("#5e4a44", "#2a1e1c"),
                    pelo=("#7a6252", "#2a201a"), polvo="#9a8a74", esclera=("#fff6d8", "#d8c08a"), extra="musgo"),
    "manto": dict(roca=("#4e3e38", "#221814", "#0a0606"), contorno="#060202", grieta="#ff6a1a", grieta2="#ffd25a",
                  intensidad=1.0, ojo="#ffb02a", cristal=("#ffe0a0", "#ff7a1a", "#8a1a08"), membrana=("#5a1e12", "#1a0604"),
                  pelo=("#3a2620", "#0e0606"), polvo="#5a4842", esclera=("#ffe8b0", "#ff9a3a"), extra="lava"),
    "nucleo": dict(roca=("#d4dae4", "#5c6472", "#1a1c24"), contorno="#0e0a08", grieta="#ffd25a", grieta2="#ffffff",
                   intensidad=1.0, ojo="#fff4c0", cristal=("#ffffff", "#ffe8a0", "#b08a3a"), membrana=("#9a7a4a", "#3a2a18"),
                   pelo=("#a8a8b2", "#3a3a44"), polvo="#7a726c", esclera=("#ffffff", "#ffe08a"), extra="metal"),
}


def defs_tema(t):
    r, c, m, pe, es = t["roca"], t["cristal"], t["membrana"], t["pelo"], t["esclera"]
    return f"""
  <style>.c{{stroke:{t['contorno']};stroke-width:2.5;stroke-linejoin:round;stroke-linecap:round}}</style>
  <radialGradient id="sombraE"><stop offset="0" stop-color="#000" stop-opacity=".5"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  <linearGradient id="roca" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="{r[0]}"/><stop offset=".5" stop-color="{r[1]}"/><stop offset="1" stop-color="{r[2]}"/></linearGradient>
  <radialGradient id="rocaR" cx=".36" cy=".3" r=".8"><stop offset="0" stop-color="{r[0]}"/><stop offset=".55" stop-color="{r[1]}"/><stop offset="1" stop-color="{r[2]}"/></radialGradient>
  <radialGradient id="brilloGrieta"><stop offset="0" stop-color="{t['grieta2']}" stop-opacity=".95"/><stop offset=".45" stop-color="{t['grieta']}" stop-opacity=".4"/><stop offset="1" stop-color="{t['grieta']}" stop-opacity="0"/></radialGradient>
  <radialGradient id="ojoE"><stop offset="0" stop-color="#ffffff" stop-opacity=".95"/><stop offset=".4" stop-color="{t['ojo']}" stop-opacity=".55"/><stop offset="1" stop-color="{t['ojo']}" stop-opacity="0"/></radialGradient>
  <linearGradient id="cristal" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="{c[0]}"/><stop offset=".45" stop-color="{c[1]}"/><stop offset="1" stop-color="{c[2]}"/></linearGradient>
  <linearGradient id="membrana" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="{m[0]}"/><stop offset="1" stop-color="{m[1]}"/></linearGradient>
  <radialGradient id="pelo" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="{pe[0]}"/><stop offset="1" stop-color="{pe[1]}"/></radialGradient>
  <radialGradient id="esclera" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="{es[0]}"/><stop offset="1" stop-color="{es[1]}"/></radialGradient>
  <radialGradient id="polvo" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="{t['polvo']}"/><stop offset="1" stop-color="{t['polvo']}" stop-opacity=".4"/></radialGradient>
  <filter id="blanco"><feColorMatrix type="matrix" values=".55 0 0 0 .45  0 .55 0 0 .45  0 0 .55 0 .45  0 0 0 1 0"/></filter>
"""


def svg(w, h, contenido, t):
    return gh.svg(w, h, contenido, defs_tema(t))


def poligono(cx, cy, tam, forma, giro=0.0, achatar=1.0):
    pts = [P(cx + tam * rr * math.cos(b + giro), cy + tam * rr * math.sin(b + giro) * achatar) for b, rr in forma]
    return "M" + " L".join(pts) + " Z"


def trazo_grieta(pts, t, ancho, op):
    """Grieta: surco oscuro + brillo del color de la capa + núcleo claro."""
    d = "M" + " L".join(P(x, y) for x, y in pts)
    return (f'<path d="{d}" fill="none" stroke="{t["contorno"]}" stroke-width="{ancho * 2.4:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity="{min(1, op + .2):.2f}"/>'
            f'<path d="{d}" fill="none" stroke="{t["grieta"]}" stroke-width="{ancho:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity="{op:.2f}" filter="url(#brillo)"/>'
            f'<path d="{d}" fill="none" stroke="{t["grieta2"]}" stroke-width="{ancho * .35:.1f}" stroke-linecap="round" opacity="{op:.2f}"/>')


# ========================================================= 1. GÓLEM ===
# Frames de 128x128 (lienzo 256). El suelo está en y = 226.
G_SUELO = 226
G_MANCHAS = [(-40, 140, 7), (22, 166, 6), (62, 128, 5), (150, 150, 7), (-130, 162, 6), (100, 178, 5), (-75, 186, 5)]
G_GRIETAS = [[(0, 150), (-10, 143), (-13, 132), (-24, 124)], [(0, 150), (12, 153), (19, 166), (30, 171)], [(0, 150), (-4, 162), (-14, 171)],
             [(0, 150), (7, 140), (9, 127)], [(180, 128), (166, 150), (176, 172)], [(-120, 138), (-106, 158), (-112, 176)],
             [(122, 150), (136, 134)], [(-48, 120), (-58, 136)], [(52, 182), (64, 196)]]
_r = random.Random(9)
G_TROZOS = sorted([(_r.uniform(-50, 50), _r.uniform(84, 212), _r.uniform(10, 17),
                    [(TAU * v / 6 + _r.uniform(-.3, .3), _r.uniform(.7, 1.1)) for v in range(6)],
                    _r.uniform(-16, 16), _r.uniform(-8, 10), _r.uniform(-1.6, 1.6)) for _ in range(16)], key=lambda c: c[5])


def pose_golem(anim, f):
    p = dict(bob=0, paso=0, lean=0, flash=False, impacto=0, grietas=0.0, roto=None, ojos=1.0)
    manos = {s: (s * 82, 64, 186, 0) for s in (-1, 1)}
    if anim == "caminar":
        p["paso"], p["bob"] = PASO[f], [0, -3, 0, -3][f]
        manos = {s: (s * 82, 64, 186, s * 12 * PASO[f]) for s in (-1, 1)}   # los brazos van al revés que las piernas
    elif anim == "atacar":   # golpe a dos manos contra el suelo; el daño se aplica en el frame 3
        K = [(75, 62, 172, -8, -2, -4), (40, 40, 100, -4, -4, -6), (25, 30, 62, 0, -7, -6),
             (18, 44, 212, 30, 6, 8), (18, 44, 214, 30, 7, 8), (60, 58, 192, 10, 2, 2)]
        ph, r, y, av, bob, lean = K[f]
        manos = {s: (s * ph, r, y, av) for s in (-1, 1)}
        p.update(bob=bob, lean=lean, impacto={3: 1, 4: 2}.get(f, 0))
    elif anim == "dano":
        p.update(lean=[-10, -6, -2][f], flash=f == 0, bob=[2, 1, 0][f])
        manos = {s: (s * 86, 66, 176 + 4 * f, -6) for s in (-1, 1)}
    elif anim == "muerte":
        if f <= 2:
            p.update(lean=[-8, -10, -10][f], bob=[2, 6, 10][f], grietas=[.4, .75, 1][f], flash=f == 0, ojos=[1, .6, .3][f])
            manos = {s: (s * 86, 66, 196 + 6 * f, -4) for s in (-1, 1)}
        else:
            p.update(roto=(f - 3) / 4, ojos=0)
    p["manos"] = manos
    return p


def brazo_golem(t, S, H, int_g, extra):
    (sx, sy), (hx, hy) = S, H
    L = math.hypot(hx - sx, hy - sy) or 1
    nx, ny = -(hy - sy) / L, (hx - sx) / L
    quad = [P(sx + nx * 13, sy + ny * 13), P(hx + nx * 10, hy + ny * 10), P(hx - nx * 10, hy - ny * 10), P(sx - nx * 13, sy - ny * 13)]
    out = f'<path class="c" d="M{" L".join(quad)} Z" fill="url(#roca)"/>'
    mx, my = (sx + hx) / 2, (sy + hy) / 2
    out += trazo_grieta([(mx + nx * 4, my + ny * 4), (mx * .5 + hx * .5, my * .5 + hy * .5)], t, 2, .6 * int_g)
    out += f'<path class="c" d="{blob_d(sx, sy, 24, 2.1, 5, .08)}" fill="url(#rocaR)"/>'
    out += (f'<path class="c" d="{blob_d(hx, hy, 22, 3.3, 5, .1)}" fill="url(#rocaR)"/>'
            f'<path d="M{hx - 10:.1f},{hy - 4:.1f} q5,-4 10,0 M{hx:.1f},{hy - 4:.1f} q5,-4 10,0" fill="none" stroke="{t["contorno"]}" stroke-width="2"/>')
    if extra == "musgo":
        out += f'<path d="{blob_d(sx - 2, sy - 18, 11, 1.4, 6, .22, achatar=.5)}" fill="#5e8a3a" stroke="#22361a" stroke-width="1.5"/>'
    elif extra == "metal":
        out += "".join(f'<circle cx="{sx + dx:.1f}" cy="{sy - 6:.1f}" r="2.2" fill="#e8e0d8" stroke="{t["contorno"]}" stroke-width="1"/>' for dx in (-8, 8))
    return out


def golem_cuerpo(t, theta, p):
    s, c = sc(theta)
    cx = 128 + 3 * s
    ig = t["intensidad"] + p["grietas"] * .6
    # piernas (primero la más lejana)
    piernas = []
    for phi, st in ((-90, p["paso"]), (90, -p["paso"])):
        x, y, z = cil(theta, phi, 24, cx, 212)
        x, y = x + 8 * st * s, y + 4 * st * c
        piernas.append((y, f'<path class="c" d="{blob_d(x, y - 6, 17, 2 + phi / 90, 5, .08)}" fill="url(#roca)"/>'
                           f'<ellipse class="c" cx="{x:.1f}" cy="{y + 8:.1f}" rx="19" ry="9" fill="url(#rocaR)"/>'))
    out = "".join(svgp for _, svgp in sorted(piernas))
    # brazos: la profundidad media de hombro y puño decide si van delante o detrás del torso
    brazos = []
    for lado in (-1, 1):
        ph, r, y, av = p["manos"][lado]
        hx, hy, zh = cil(theta, ph, r, cx, y)
        hx, hy = hx + av * s, hy + av * c * .3
        sx, sy, zs = cil(theta, lado * 90, 46, cx, 118)
        brazos.append(((zh + zs) / 2, brazo_golem(t, (sx, sy), (hx, hy), ig, t["extra"])))
    out += "".join(b for z, b in brazos if z < -0.15)
    # torso
    out += (f'<path class="c" d="{blob_d(cx, 150, 56, 1.3, 5, .07)}" fill="url(#rocaR)" stroke-width="3"/>'
            f'<ellipse cx="{cx + 20:.1f}" cy="176" rx="34" ry="22" fill="#000" opacity=".22"/>')
    for phi, y, r in G_MANCHAS:                       # manchas de la roca: giran con el cuerpo
        x, yy, z = cil(theta, phi, 44, cx, y)
        if z > .15:
            out += f'<ellipse cx="{x:.1f}" cy="{yy:.1f}" rx="{r * (.5 + .5 * z):.1f}" ry="{r * .8:.1f}" fill="#000" opacity=".28"/>'
    for linea in G_GRIETAS:
        pts = [cil(theta, phi, 50, cx, y) for phi, y in linea]
        if min(z for _, _, z in pts) > .1:
            z = sum(z for _, _, z in pts) / len(pts)
            out += trazo_grieta([(x, y) for x, y, _ in pts], t, 2.6 * (1 + 1.4 * p["grietas"]) * (.5 + .5 * z), ig * (.5 + .5 * z))
    x, y, z = cil(theta, 0, 50, cx, 150)
    if z > .2:                                        # núcleo del pecho
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{16 + 6 * p["grietas"]:.1f}" fill="url(#brilloGrieta)" opacity="{min(1, .5 + .5 * ig):.2f}"/>'
        if t["extra"] == "musgo":
            out += f'<g transform="translate({x:.1f} {y:.1f}) scale({z:.2f} 1)">{gm.prisma(0, 0, 6, 10, 9, borde=t["contorno"])}</g>'
        else:
            out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{7 * z:.1f}" ry="7" fill="{t["grieta2"]}" filter="url(#brillo)"/>'
    if t["extra"] == "metal":                         # brillo metálico
        out += f'<path d="M{cx - 44:.1f},128 Q{cx - 50:.1f},150 {cx - 40:.1f},176" fill="none" stroke="#ffffff" stroke-width="3" opacity=".3" stroke-linecap="round"/>'
    # cabeza hundida entre los hombros
    hxh = cx + 10 * s
    out += f'<path class="c" d="{blob_d(hxh, 92, 25, .7, 5, .08)}" fill="url(#rocaR)" stroke-width="3"/>'
    if t["extra"] == "musgo":
        out += (f'<path d="{blob_d(hxh - 3, 72, 14, 1, 6, .22, achatar=.5)}" fill="#5e8a3a" stroke="#22361a" stroke-width="1.5"/>'
                f'<path d="{blob_d(hxh - 6, 70, 7, 2, 5, .2, achatar=.5)}" fill="#86b04e"/>')
    for phi, rot in ((-28, 12), (28, -12)):
        se, z = sc(theta, phi)
        if z < .2 or p["ojos"] <= 0:
            continue
        x, k = hxh + 18 * se, z ** .6
        out += (f'<path d="M{x - 8 * k:.1f},86 L{x + 8 * k:.1f},89" stroke="{t["contorno"]}" stroke-width="4" stroke-linecap="round" transform="rotate({rot} {x:.1f} 88)"/>'
                f'<circle cx="{x:.1f}" cy="95" r="{10 * k:.1f}" fill="url(#ojoE)" opacity="{p["ojos"]:.2f}"/>'
                f'<ellipse cx="{x:.1f}" cy="95" rx="{5 * k:.1f}" ry="2.4" fill="{t["ojo"]}" opacity="{p["ojos"]:.2f}" transform="rotate({rot} {x:.1f} 95)"/>')
    if c > .4:
        out += f'<path d="M{hxh - 7 * c:.1f},106 L{hxh + 7 * c:.1f},106" stroke="{t["grieta"]}" stroke-width="2" opacity="{ig * p["ojos"] * .8:.2f}" filter="url(#brillo)"/>'
    out += "".join(b for z, b in brazos if z >= -0.15)
    if t["extra"] == "lava":                          # gotas de lava cayendo de las grietas
        for i, phi in enumerate((-22, 30)):
            x, y, z = cil(theta, phi, 50, cx, 170)
            if z > .2:
                yy = y + ((p["bob"] * 3 + i * 9) % 24)
                out += f'<ellipse cx="{x:.1f}" cy="{yy:.1f}" rx="2.2" ry="3.4" fill="{t["grieta2"]}" filter="url(#brillo)"/>'
    return out


def golem_impacto(t, theta, nivel):
    s, c = sc(theta)
    gx, gy = 128 + 82 * s, 224 + 26 * c
    k = 1 if nivel == 1 else 1.6
    out = (f'<ellipse cx="{gx:.1f}" cy="{gy:.1f}" rx="{30 * k:.1f}" ry="{11 * k:.1f}" fill="none" stroke="{t["polvo"]}" '
           f'stroke-width="{5 / k:.1f}" opacity="{1 / k:.2f}"/>')
    for i in range(6):
        a = math.radians(i * 60 + 15)
        out += trazo_grieta([(gx, gy), (gx + math.cos(a) * 16 * k, gy + math.sin(a) * 6 * k), (gx + math.cos(a + .3) * 26 * k, gy + math.sin(a + .3) * 10 * k)],
                            t, 1.6, t["intensidad"] * .9)
    for i in range(5):
        a = math.radians(200 + i * 35)
        d = 14 + 16 * (nivel - 1)
        out += (f'<path d="{blob_d(gx + math.cos(a) * d * 1.4, gy + math.sin(a) * d - 6 * nivel, 8 + 4 * nivel, i + nivel, 5, .15)}" '
                f'fill="url(#polvo)" opacity="{.7 / nivel:.2f}"/>')
        out += f'<path class="c" d="{poligono(gx + math.cos(a) * d * 2, gy - 10 * nivel - i * 3, 4, [(b * TAU / 5, 1) for b in range(5)], i)}" fill="url(#roca)" stroke-width="1.2"/>'
    return out


def golem_roto(t, theta, q):
    """Muerte: el gólem se rompe en trozos que caen y se quedan como un montón de escombros."""
    cx = 128 + 3 * sc(theta)[0]
    out = ""
    if q < .9:
        out += f'<path d="{blob_d(cx, 180, 50 + 40 * q, q * 4, 6, .14)}" fill="url(#polvo)" opacity="{.6 * (1 - q):.2f}" filter="url(#difuso)"/>'
    if q < .3:
        out += f'<circle cx="{cx:.1f}" cy="150" r="{70 * (1 - q):.1f}" fill="url(#brilloGrieta)" opacity="{(1 - q / .3) * t["intensidad"]:.2f}"/>'
    for x0, y0, tam, forma, dx, dy, giro in G_TROZOS:
        xi, yi = cx + x0, y0 + 10
        xf, yf = cx + x0 * 1.35 + dx, G_SUELO - 6 + dy
        x = xi + (xf - xi) * suave(q, 1.5)
        y = yi + (yf - yi) * q ** 1.6
        d = poligono(x, y, tam, forma, giro * q * 2, .85 + .15 * (1 - q))
        out += (f'<path class="c" d="{d}" fill="url(#rocaR)"/>'
                f'<path d="{d}" fill="none" stroke="{t["grieta"]}" stroke-width="1.6" opacity="{t["intensidad"] * (1 - q * .7):.2f}" filter="url(#brillo)"/>')
    if t["extra"] != "musgo" and q > .3:
        for i in range(6):
            out += f'<circle cx="{cx - 50 + i * 20:.1f}" cy="{200 - q * 60 - i * 5:.1f}" r="1.8" fill="{t["grieta2"]}" opacity="{1 - q:.2f}"/>'
    return out


def svg_golem(t, anim, theta, f):
    p = pose_golem(anim, f)
    s, c = sc(theta)
    cx = 128 + 3 * s
    out = f'<ellipse cx="{cx:.1f}" cy="228" rx="64" ry="15" fill="url(#sombraE)"/>'
    if t["extra"] == "lava":
        out += f'<ellipse cx="{cx:.1f}" cy="226" rx="54" ry="12" fill="{t["grieta"]}" opacity=".18" filter="url(#difuso)"/>'
    if p["roto"] is not None:
        return svg(256, 256, out + golem_roto(t, theta, p["roto"]), t)
    lx, ly = p["lean"] * s, p["lean"] * c * .3 + p["bob"]
    filtro = ' filter="url(#blanco)"' if p["flash"] else ""
    cuerpo = f'<g transform="translate({lx:.1f} {ly:.1f})"{filtro}>{golem_cuerpo(t, theta, p)}</g>'
    if p["impacto"]:
        imp = golem_impacto(t, theta, p["impacto"])
        cuerpo = (imp + cuerpo) if c < -.3 else (cuerpo + imp)   # de espaldas, el impacto queda detrás
    return svg(256, 256, out + cuerpo, t)


# ========================================================= 2. VIGÍA ===
# Frames de 96x96 (lienzo 192). Flota; el suelo (sombra) está en y = 172.
V_R, V_SUELO = 40, 172
V_CRISTALES = [(70, 0, 26), (55, 90, 22), (55, -90, 22), (50, 180, 26), (20, 125, 19), (20, -125, 19), (0, 180, 21),
               (-25, 70, 16), (-25, -70, 16), (-45, 160, 14), (-45, -160, 14), (85, 90, 19)]
_r = random.Random(13)
V_TROZOS = [(_r.uniform(-36, 36), _r.uniform(-34, 34), _r.uniform(8, 13), [(TAU * v / 5 + _r.uniform(-.3, .3), _r.uniform(.7, 1.1)) for v in range(5)],
             _r.uniform(-30, 30), _r.uniform(-6, 8), _r.uniform(-2, 2)) for _ in range(12)]


def pose_vigia(anim, f):
    p = dict(bob=3 * math.sin(f * math.pi / 2), off=0, carga=0, flash=False, disparo=False, parpado=0, grietas=0, roto=None, jitter=0, ojo=1)
    if anim == "atacar":   # carga y dispara en el frame 3
        p.update(carga=[.25, .55, 1, 0, 0, 0][f], disparo=f == 3, off=[0, 0, 1, -7, -4, -1][f], bob=[0, -1, -2, 1, 0, 0][f])
    elif anim == "dano":
        p.update(flash=f == 0, parpado=[.75, .5, .2][f], jitter=[4, -3, 1][f], off=[-6, -3, -1][f])
    elif anim == "muerte":
        if f <= 2:
            p.update(grietas=[.4, .75, 1][f], parpado=[.3, .6, .9][f], jitter=[3, -3, 2][f], bob=[2, 5, 9][f], flash=f == 0, ojo=[1, .6, .3][f])
        else:
            p["roto"] = (f - 3) / 4
    return p


def ojo_esfera(t, theta, cx, cy, R, tam, parpado, brillo, clip_id):
    """Ojo pegado a la esfera (latitud 22 = centro de la cara con la inclinación de la cámara)."""
    ex, ey, ez = gh.proyectar_esfera(cx, cy, R, 22, theta)
    if ez < .05:
        return ""
    k = .3 + .7 * ez
    out = (f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{tam * 1.25 * k:.1f}" ry="{tam * 1.15:.1f}" fill="{t["contorno"]}"/>'
           f'<clipPath id="{clip_id}"><ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{tam * k:.1f}" ry="{tam * .92:.1f}"/></clipPath>'
           f'<g clip-path="url(#{clip_id})">'
           f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{tam * k:.1f}" ry="{tam * .92:.1f}" fill="url(#esclera)"/>'
           f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{tam * .75:.1f}" fill="url(#ojoE)" opacity="{brillo:.2f}"/>'
           f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{tam * .55 * k:.1f}" ry="{tam * .55:.1f}" fill="{t["ojo"]}" opacity="{.4 + .6 * brillo:.2f}" stroke="{t["contorno"]}" stroke-width="1.2"/>'
           f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{tam * .14 * k:.1f}" ry="{tam * .48:.1f}" fill="#000"/>'
           f'<circle cx="{ex - tam * .25 * k:.1f}" cy="{ey - tam * .3:.1f}" r="{tam * .12:.1f}" fill="#ffffff" opacity=".85"/>')
    if parpado > 0:   # párpado de roca que baja
        out += (f'<rect x="{ex - tam * 1.3:.1f}" y="{ey - tam:.1f}" width="{tam * 2.6:.1f}" height="{tam * 2 * parpado:.1f}" fill="url(#roca)"/>'
                f'<path d="M{ex - tam * 1.3:.1f},{ey - tam + tam * 2 * parpado:.1f} L{ex + tam * 1.3:.1f},{ey - tam + tam * 2 * parpado:.1f}" stroke="{t["contorno"]}" stroke-width="2"/>')
    return out + "</g>"


def svg_vigia(t, anim, theta, f):
    p = pose_vigia(anim, f)
    s, c = sc(theta)
    out = f'<ellipse cx="96" cy="{V_SUELO}" rx="{24 - p["bob"]:.1f}" ry="7" fill="url(#sombraE)"/>'
    if p["roto"] is not None:
        q = p["roto"]
        for x0, y0, tam, forma, dx, dy, giro in V_TROZOS:
            xi, yi = 96 + x0, 90 + y0
            x = xi + (96 + x0 * 1.6 + dx - xi) * suave(q, 1.5)
            y = yi + (V_SUELO - 4 + dy - yi) * q ** 1.6
            d = poligono(x, y, tam, forma, giro * q * 2)
            out += (f'<path class="c" d="{d}" fill="url(#rocaR)" stroke-width="1.8"/>'
                    f'<path d="{d}" fill="none" stroke="{t["grieta"]}" stroke-width="1.2" opacity="{t["intensidad"] * (1 - q * .7):.2f}"/>')
        for i, (lat, lon, largo) in enumerate(V_CRISTALES[:7]):   # los cristales caen también
            x = 96 + (i - 3) * 14 * (.4 + .6 * q)
            y = 70 + (V_SUELO - 6 - 70) * q ** 1.5
            a = math.radians(i * 50 + q * 200)
            out += gm.cristal(x, y, x + math.cos(a) * largo * .7, y + math.sin(a) * largo * .7, 3.6, borde=t["contorno"], ancho=1.4)
        if q < .4:
            out += f'<circle cx="96" cy="90" r="{60 * (1 - q):.1f}" fill="url(#brilloGrieta)" opacity="{1 - q / .4:.2f}"/>'
        return svg(192, 192, out, t)
    cx = 96 + 2 * s + p["jitter"] + p["off"] * s
    cy = 88 + p["bob"] + p["off"] * c * .3
    detras = delante = ""
    for i in range(3):                     # rocas que orbitan debajo
        a = math.radians(f * 30 + i * 120)
        x, y, z = cx + 36 * math.cos(a), cy + 52 + 7 * math.sin(a), math.sin(a)
        roca = f'<path class="c" d="{poligono(x, y, 6.5 + z, [(b * TAU / 5, .8 + .2 * (b % 2)) for b in range(5)], a)}" fill="url(#rocaR)" stroke-width="1.5"/>'
        if z < 0:
            detras += roca
        else:
            delante += roca
    for lat, lon, largo in V_CRISTALES:    # cristales pegados a la esfera: giran con ella
        bx, by, z = gh.proyectar_esfera(cx, cy, V_R * .9, lat, lon + theta)
        tx, ty, _ = gh.proyectar_esfera(cx, cy, V_R * .9 + largo * (1 + .15 * p["carga"]), lat, lon + theta)
        cr = gm.cristal(bx, by, tx, ty, 6, borde=t["contorno"], ancho=1.8)
        if z < 0:
            detras += cr
        else:
            delante += f'<g filter="url(#brillo)">{cr}</g>' if p["carga"] > .5 else cr
    # energía que se concentra delante del ojo
    energia = ""
    if p["carga"] or p["disparo"]:
        ox, oy = cx + (V_R + 12) * s, cy + 4 + (V_R + 12) * c * .3
        r = 4 + 9 * p["carga"] if not p["disparo"] else 16
        energia = (f'<circle cx="{ox:.1f}" cy="{oy:.1f}" r="{r * 2:.1f}" fill="url(#brilloGrieta)"/>'
                   f'<circle cx="{ox:.1f}" cy="{oy:.1f}" r="{r * .5:.1f}" fill="{t["grieta2"]}" filter="url(#brillo)"/>')
    ig = t["intensidad"] + p["grietas"] * .6 + p["carga"] * .4
    cuerpo = (detras + (energia if c < -.2 else "")
              + f'<circle class="c" cx="{cx:.1f}" cy="{cy:.1f}" r="{V_R}" fill="url(#rocaR)" stroke-width="2.6"/>'
              + f'<g opacity="{min(1, ig):.2f}">{gh.grietas_esfera(cx, cy, V_R, theta, t["grieta"], t["grieta2"], .8 + p["grietas"])}</g>'
              + ojo_esfera(t, theta, cx, cy, V_R, 15, p["parpado"], p["ojo"] * (.6 + .4 * p["carga"] + .2), "clipOjoV")
              + delante + (energia if c >= -.2 else ""))
    filtro = ' filter="url(#blanco)"' if p["flash"] else ""
    return svg(192, 192, out + f'<g{filtro}>{cuerpo}</g>', t)


def svg_esquirla(t, f, N=4):
    """Proyectil del Vigía: esquirla de cristal que gira. Mira a la derecha; la punta está en (118, 32)."""
    w = 2.5 + 5 * abs(math.cos(TAU * f / N + .3))            # al girar sobre su eje cambia de grosor
    out = f'<ellipse cx="90" cy="32" rx="40" ry="16" fill="url(#brilloGrieta)" opacity=".7"/>'
    for dy, ancho in ((0, 3), (-4, 1.2), (4, 1.2)):
        out += f'<path d="M12,{32 + dy} L70,{32 + dy * .5}" stroke="{t["grieta"]}" stroke-width="{ancho}" stroke-linecap="round" opacity=".55"/>'
    for i in range(4):
        ph = (i / 4 + f / N) % 1
        x = 70 - ph * 56
        out += f'<circle cx="{x:.1f}" cy="{32 + (1 if i % 2 else -1) * (3 + 8 * ph):.1f}" r="{1.8 * (1 - ph) + .5:.1f}" fill="{t["grieta2"]}" opacity="{1 - ph:.2f}"/>'
    out += f'<g filter="url(#brillo)">{gm.cristal(62, 32, 120, 32, w, borde=t["contorno"], ancho=1.8)}</g>'
    return svg(128, 64, out, t)


def svg_esquirla_impacto(t, f, N=6):
    p, cx, cy = f / (N - 1), 64, 66
    e = suave(p)
    out = (f'<ellipse cx="{cx}" cy="{cy + 10}" rx="{8 + 36 * e:.1f}" ry="{(8 + 36 * e) * .4:.1f}" fill="none" stroke="{t["grieta"]}" '
           f'stroke-width="{4 * (1 - p) + .4:.1f}" opacity="{1 - p:.2f}" filter="url(#brillo)"/>')
    if f <= 1:
        out += f'<circle cx="{cx}" cy="{cy}" r="{18 + 12 * f}" fill="url(#brilloGrieta)"/>'
    for i in range(8):
        a = math.radians(i * 45 + 20)
        x, y = cx + math.cos(a) * 40 * e, cy + math.sin(a) * 30 * e + 14 * p * p
        out += (f'<g opacity="{1 - max(0, p - .6) / .4:.2f}">'
                f'{gm.cristal(x, y, x + math.cos(a + p * 3) * 9, y + math.sin(a + p * 3) * 9, 2.6, borde=t["contorno"], ancho=1.1)}</g>')
    return svg(128, 128, out, t)


# ==================================================== 3. MURCIÉLAGO ===
# Frames de 64x64 (lienzo 128). Vuela; la sombra está en y = 116.
M_SUELO = 116


def pose_murcielago(anim, f):
    p = dict(bob=[0, -2, 0, 2][f % 4], aleteo=[22, 6, -16, 6][f % 4], env=44, avance=0, boca=False, flash=False,
             lean=0, caida=0, giro=0, ojos=1, polvo=False)
    if anim == "atacar":   # se lanza a morder; el daño en el frame 2
        p.update(avance=[0, 10, 16, 6][f], boca=f in (1, 2), aleteo=[18, 10, 8, 12][f], env=[44, 36, 34, 40][f])
    elif anim == "dano":
        p.update(flash=f == 0, lean=[-8, -5, -2][f], aleteo=[-12, -6, 4][f], env=[30, 34, 40][f])
    elif anim == "muerte":
        p.update(caida=[0, 10, 24, 40, 50, 52][f], giro=[0, 30, 70, 90, 90, 90][f], env=[44, 36, 28, 22, 20, 20][f],
                 aleteo=[10, 0, -10, -14, -14, -14][f], ojos=[1, .5, 0, 0, 0, 0][f], flash=f == 0, polvo=f >= 4, bob=0)
    return p


def ala(t, theta, lado, cx, cy, p):
    sw, zw = sc(theta, lado * 90)
    S = (cx + 7 * sw, cy - 4 + zw * 7 * PROF_Y)
    span, h = p["env"], p["aleteo"]
    # .7: en perfil el ala cercana baja y la lejana sube (vista cenital), así no se aplanan en una raya
    atras = -span * .5 * abs(zw) * sc(theta)[0]          # de perfil, las alas se barren hacia atrás
    T = (S[0] + span * sw + atras, S[1] - h + span * zw * .55)
    E = (S[0] + span * .5 * sw + atras * .6, S[1] - h * .6 - 8 + span * .5 * zw * .55)
    F1 = (S[0] + (T[0] - S[0]) * .72, S[1] + (T[1] - S[1]) * .72 + 14)
    F2 = (S[0] + (T[0] - S[0]) * .42, S[1] + (T[1] - S[1]) * .42 + 16)
    B = (cx + 3 * sw, cy + 8)

    def hacia_centro(a, b):     # punto de control del festón: hacia el cuerpo
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        return P(mx + (cx - mx) * .22, my + (cy - my) * .22 - 2)

    d = (f"M{P(*S)} L{P(*E)} L{P(*T)} Q{hacia_centro(T, F1)} {P(*F1)} Q{hacia_centro(F1, F2)} {P(*F2)} "
         f"Q{hacia_centro(F2, B)} {P(*B)} Z")
    hueso = "#c8a87a" if t["extra"] == "metal" else t["grieta"] if t["extra"] == "lava" else "#8a7064"
    filtro = ' filter="url(#brillo)"' if t["extra"] == "lava" else ""
    huesos = f'M{P(*S)} L{P(*E)} L{P(*T)} M{P(*E)} L{P(*F1)} M{P(*E)} L{P(*F2)}'
    return zw, (f'<path class="c" d="{d}" fill="url(#membrana)" stroke-width="2"/>'
                f'<path d="{huesos}" fill="none" stroke="{hueso}" stroke-width="1.6" stroke-linecap="round" opacity=".9"{filtro}/>')


def svg_murcielago(t, anim, theta, f):
    p = pose_murcielago(anim, f)
    s, c = sc(theta)
    d = p["avance"] + p["lean"]
    cx, cy = 64 + d * s, 54 + p["bob"] + p["caida"] + d * c * .3
    out = f'<ellipse cx="{64 + p["avance"] * s:.1f}" cy="{M_SUELO}" rx="{14 - p["bob"] * .5:.1f}" ry="4" fill="url(#sombraE)" opacity=".8"/>'
    alas = [ala(t, theta, lado, cx, cy, p) for lado in (-1, 1)]
    cuerpo = "".join(a for z, a in alas if z < 0)
    cuerpo += f'<ellipse class="c" cx="{cx:.1f}" cy="{cy:.1f}" rx="11" ry="13" fill="url(#pelo)" stroke-width="2"/>'
    if c > -.2:
        cuerpo += f'<ellipse cx="{cx + 3 * s:.1f}" cy="{cy + 3:.1f}" rx="{6 * max(c, .3):.1f}" ry="8" fill="#ffffff" opacity=".1"/>'
    hx, hy = cx + 3 * s, cy - 13
    orejas = []
    for phi in (-35, 35):
        se, ze = sc(theta, phi)
        bx = hx + 6 * se
        orejas.append((ze, f'<path class="c" d="M{bx - 3.5:.1f},{hy - 4:.1f} L{bx + 2 * se:.1f},{hy - 20:.1f} L{bx + 3.5:.1f},{hy - 4:.1f} Z" fill="url(#pelo)" stroke-width="1.8"/>'))
    cuerpo += "".join(o for z, o in orejas if z < 0)
    cuerpo += f'<circle class="c" cx="{hx:.1f}" cy="{hy:.1f}" r="9" fill="url(#pelo)" stroke-width="2"/>'
    cuerpo += "".join(o for z, o in orejas if z >= 0)
    for phi in (-25, 25):
        se, z = sc(theta, phi)
        if z > .2 and p["ojos"] > 0:
            x = hx + 6 * se
            cuerpo += (f'<circle cx="{x:.1f}" cy="{hy:.1f}" r="5" fill="url(#ojoE)" opacity="{p["ojos"]:.2f}"/>'
                       f'<ellipse cx="{x:.1f}" cy="{hy:.1f}" rx="{2 * z:.1f}" ry="1.6" fill="{t["ojo"]}" opacity="{p["ojos"]:.2f}"/>')
    if c > .1:
        bx, by = hx + 4 * s, hy + 5
        if p["boca"]:
            cuerpo += (f'<ellipse cx="{bx:.1f}" cy="{by:.1f}" rx="{4 * c:.1f}" ry="3" fill="#1a0404"/>'
                       f'<path d="M{bx - 2.5 * c:.1f},{by - 2:.1f} l1,4 l1,-4 M{bx + .5 * c:.1f},{by - 2:.1f} l1,4 l1,-4" fill="#ffffff" stroke="#ffffff" stroke-width=".8"/>')
        else:
            cuerpo += f'<path d="M{bx - 2.5 * c:.1f},{by:.1f} l1,2.5 l1,-2.5 M{bx + .5 * c:.1f},{by:.1f} l1,2.5 l1,-2.5" fill="#ffffff"/>'
    cuerpo += "".join(a for z, a in alas if z >= 0)
    if t["extra"] != "musgo" and anim != "muerte":     # brasas o chispas
        col = t["grieta2"]
        for i in range(3):
            ph = (i / 3 + f / 4) % 1
            cuerpo += f'<circle cx="{cx - 10 + i * 10 - ph * 8 * s:.1f}" cy="{cy + 10 + ph * 20:.1f}" r="1.3" fill="{col}" opacity="{1 - ph:.2f}"/>'
    filtro = ' filter="url(#blanco)"' if p["flash"] else ""
    out += f'<g transform="rotate({p["giro"]} {cx:.1f} {cy:.1f})"{filtro}>{cuerpo}</g>'
    if p["polvo"]:
        out += f'<path d="{blob_d(cx, M_SUELO - 6, 16 + 6 * (f - 4), f, 5, .16, achatar=.6)}" fill="url(#polvo)" opacity="{.5 - .2 * (f - 4):.2f}" filter="url(#difuso)"/>'
    return svg(128, 128, out, t)


# ====================================================== 4. EL JEFE ===
# Frames de 384x384. Flota; el suelo está en y = 344.
J_R, J_SUELO = 88, 344
TEMA_JEFE = dict(TEMAS["nucleo"], roca=("#6a5a50", "#2e221c", "#0e0806"), grieta="#ffb02a", grieta2="#fff6d0",
                 ojo="#ff7a1a", esclera=("#ffffff", "#ffd25a"), cristal=("#fff8e0", "#ffd25a", "#8a5a1a"))
DEFS_JEFE = """
  <radialGradient id="auraJefe"><stop offset="0" stop-color="#fff1b8" stop-opacity=".65"/><stop offset=".45" stop-color="#ffb02a" stop-opacity=".22"/><stop offset="1" stop-color="#ff7a1a" stop-opacity="0"/></radialGradient>
  <radialGradient id="irisJefe" cx=".45" cy=".4" r=".7"><stop offset="0" stop-color="#ffe08a"/><stop offset=".5" stop-color="#ff5a14"/><stop offset="1" stop-color="#7a1206"/></radialGradient>
"""
_r = random.Random(23)
J_TROZOS_ORB = [(_r.uniform(9, 14), [(TAU * v / 6 + _r.uniform(-.3, .3), _r.uniform(.75, 1.1)) for v in range(6)]) for _ in range(6)]
J_FRAGMENTOS = [(_r.uniform(0, 360), _r.uniform(90, 190), _r.uniform(12, 22), [(TAU * v / 6 + _r.uniform(-.3, .3), _r.uniform(.7, 1.1)) for v in range(6)],
                 _r.uniform(-2, 2)) for _ in range(16)]


def anillo_orbital(cx, cy, rx, ry, incl, rot, color_runa, op=1.0):
    """Anillo de 6 segmentos metálicos; se parte en mitad de atrás y de delante."""
    detras = delante = ""
    ci, si = math.cos(math.radians(incl)), math.sin(math.radians(incl))
    for k in range(6):
        a0 = rot + k * 60
        pts = []
        for a in range(int(a0), int(a0 + 42) + 1, 3):
            r = math.radians(a)
            x, y = rx * math.cos(r), ry * math.sin(r)
            pts.append((cx + x * ci - y * si, cy + x * si + y * ci, math.sin(r)))
        mid = pts[len(pts) // 2]
        for lado, tramo in partir(pts):
            d = "M" + " L".join(P(x, y) for x, y in tramo)
            s = (f'<path d="{d}" fill="none" stroke="#0e0806" stroke-width="12" stroke-linecap="round" opacity="{op:.2f}"/>'
                 f'<path d="{d}" fill="none" stroke="#7a6a5a" stroke-width="7" stroke-linecap="round" opacity="{op:.2f}"/>'
                 f'<path d="{d}" fill="none" stroke="#c8b8a0" stroke-width="2" stroke-linecap="round" opacity="{op * .8:.2f}"/>')
            if lado:
                delante += s
            else:
                detras += s
        runa = f'<circle cx="{mid[0]:.1f}" cy="{mid[1]:.1f}" r="3.2" fill="{color_runa}" opacity="{op:.2f}" filter="url(#brillo)"/>'
        if mid[2] >= 0:
            delante += runa
        else:
            detras += runa
    return detras, delante


def partir(pts):
    tramos, actual, lado = [], [], None
    for x, y, s in pts:
        l = s >= 0
        if lado is not None and l != lado and len(actual) > 1:
            tramos.append((lado, actual))
            actual = [actual[-1]]
        actual.append((x, y))
        lado = l
    if len(actual) > 1:
        tramos.append((lado, actual))
    return tramos


def pose_jefe(anim, f):
    p = dict(bob=5 * math.sin(TAU * f / 6), giro=7.5 * f, anillos=10 * f, esc_anillo=1.0, carga=0, nova=None,
             parpado=0, jitter=0, flash=False, grietas=0, caida=0, R=J_R, luz=0, roto=None, ojo=1)
    if anim == "atacar":     # carga y suelta una onda en el frame 4
        p.update(bob=[0, -2, -4, -6, 4, 2, 0, 0][f], carga=[.2, .45, .7, 1, 0, 0, 0, 0][f],
                 anillos=[0, 25, 60, 110, 140, 150, 155, 160][f], esc_anillo=[1, .95, .88, .8, 1.15, 1.05, 1, 1][f],
                 nova=f - 4 if f >= 4 else None, giro=4 * f)
    elif anim == "dano":
        p.update(flash=f == 0, parpado=[.8, .5, .15][f], jitter=[6, -4, 2][f], bob=0, giro=0, anillos=0)
    elif anim == "muerte":
        if f <= 3:
            p.update(grietas=[.4, .7, 1, 1.3][f], parpado=[.2, .4, .7, .9][f], jitter=[4, -5, 6, -6][f], caida=f / 3,
                     flash=f == 0, bob=0, giro=0, anillos=0, ojo=1 - f * .25)
        elif f <= 6:
            p.update(grietas=1.6, parpado=1, R=J_R * [.95, .9, .88][f - 4], luz=[.6, .9, 1][f - 4], caida=1, bob=0, giro=0, anillos=0, ojo=0)
        else:
            p["roto"] = (f - 7) / 2
    return p


def svg_jefe(anim, theta, f):
    t = TEMA_JEFE
    p = pose_jefe(anim, f)
    s, c = sc(theta)
    cx, cy, R = 192 + p["jitter"], 176 + p["bob"], p["R"]
    out = f'<ellipse cx="192" cy="{J_SUELO}" rx="{118 - p["bob"]:.1f}" ry="24" fill="url(#sombraE)"/>'
    if p["roto"] is not None:          # restos tras la explosión
        q = p["roto"]
        out += f'<path d="{blob_d(192, J_SUELO - 2, 120, 1, 9, .1, achatar=.32)}" fill="#0a0604" opacity=".6"/>'
        for ang, vel, tam, forma, giro in J_FRAGMENTOS:
            a = math.radians(ang)
            xi, yi = 192 + math.cos(a) * 40, 176 + math.sin(a) * 40
            x = xi + math.cos(a) * vel * suave(q, 1.5)
            y = yi + (J_SUELO - 10 + math.sin(a) * 20 - yi) * q ** 1.4
            d = poligono(x, y, tam, forma, giro * q * 3, .85)
            out += (f'<path class="c" d="{d}" fill="url(#rocaR)"/>'
                    f'<path d="{d}" fill="none" stroke="{t["grieta"]}" stroke-width="2" opacity="{1 - q * .6:.2f}" filter="url(#brillo)"/>')
        for i in range(14):
            out += f'<circle cx="{110 + i * 12:.1f}" cy="{300 - q * 120 - (i * 37) % 60:.1f}" r="2.2" fill="{t["grieta2"]}" opacity="{(1 - q) * .9:.2f}"/>'
        out += f'<circle cx="192" cy="176" r="{200 * (1 - q * .5):.1f}" fill="url(#auraJefe)" opacity="{.8 * (1 - q):.2f}"/>'
        return gh.svg(384, 384, out, defs_tema(t) + DEFS_JEFE)
    out += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{190 + 30 * p["carga"]:.1f}" fill="url(#auraJefe)" opacity="{.6 + .4 * p["carga"] + .4 * p["luz"]:.2f}"/>'
    caida = p["caida"]
    da1, dl1 = anillo_orbital(cx, cy + 12 + 120 * caida ** 2, 150 * p["esc_anillo"], 36, -12 + 25 * caida, p["anillos"], t["grieta"], 1 - .6 * caida)
    da2, dl2 = anillo_orbital(cx, cy + 4 + 140 * caida ** 2, 132 * p["esc_anillo"], 30, 16 - 30 * caida, -p["anillos"] * 1.3 + 30, t["grieta"], 1 - .6 * caida)
    trozos_d = trozos_l = ""
    for i, (tam, forma) in enumerate(J_TROZOS_ORB):
        a = math.radians(i * 60 + p["anillos"])
        x, y, z = cx + 170 * math.cos(a), cy + 40 + 46 * math.sin(a), math.sin(a)
        y = y + (J_SUELO - 12 - y) * caida ** 2
        tz = (f'<path class="c" d="{poligono(x, y, tam, forma, a)}" fill="url(#rocaR)"/>'
              f'<path d="{poligono(x, y, tam * .45, forma, a)}" fill="{t["grieta"]}" opacity=".7" filter="url(#brillo)"/>')
        if z < 0:
            trozos_d += tz
        else:
            trozos_l += tz
    corona = []
    for k in range(8):                 # corona de cristales de hierro: gira con el cuerpo
        lon = k * 45 + 22.5 + theta
        bx, by, z = gh.proyectar_esfera(cx, cy, R * .95, 68, lon)
        tx, ty, _ = gh.proyectar_esfera(cx, cy, R + 40 + 8 * (k % 2), 74, lon)
        corona.append((z, gm.cristal(bx, by, tx, ty, 9, borde=t["contorno"], ancho=2.2)))
    ig = 1 + p["grietas"] * .8 + p["carga"] * .5
    esfera = (f'<circle class="c" cx="{cx:.1f}" cy="{cy:.1f}" r="{R:.1f}" fill="url(#rocaR)" stroke-width="4"/>'
              f'<g opacity="{min(1, ig):.2f}">{gh.grietas_esfera(cx, cy, R, theta + p["giro"], t["grieta"], t["grieta2"], .9 + p["grietas"])}</g>'
              f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{R:.1f}" fill="url(#limbo)"/>'
              f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{R - 3:.1f}" fill="none" stroke="{t["grieta"]}" stroke-width="5" opacity="{.35 + .4 * p["carga"]:.2f}" filter="url(#brillo)"/>')
    if p["luz"]:
        esfera += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{R * 1.3:.1f}" fill="url(#brilloGrieta)" opacity="{p["luz"]:.2f}"/>'
        for i in range(12):
            a = math.radians(i * 30 + 10)
            esfera += (f'<path d="M{P(cx + math.cos(a) * R * .6, cy + math.sin(a) * R * .6)} L{P(cx + math.cos(a) * R * (1.3 + p["luz"]), cy + math.sin(a) * R * (1.3 + p["luz"]))}" '
                       f'stroke="{t["grieta2"]}" stroke-width="{3 + 4 * p["luz"]:.1f}" stroke-linecap="round" opacity="{p["luz"] * .8:.2f}" filter="url(#brillo)"/>')
    ojo = f'<g filter="url(#brillo)">{ojo_esfera(t, theta, cx, cy, R, 26, p["parpado"], p["ojo"] * (.7 + .3 * p["carga"]), "clipOjoJ")}</g>'
    ojo = ojo.replace(f'fill="{t["ojo"]}" opacity', 'fill="url(#irisJefe)" opacity')
    carga = ""
    if p["carga"]:                     # partículas que convergen en el ojo
        ex, ey, _ = gh.proyectar_esfera(cx, cy, R, 22, theta)
        for i in range(12):
            a = math.radians(i * 30 + f * 13)
            d0 = 170 - 120 * ((i * .13 + p["carga"]) % 1)
            carga += (f'<path d="M{P(ex + math.cos(a) * d0, ey + math.sin(a) * d0 * .7)} L{P(ex + math.cos(a) * (d0 - 18), ey + math.sin(a) * (d0 - 18) * .7)}" '
                      f'stroke="{t["grieta2"]}" stroke-width="2.4" stroke-linecap="round" opacity="{p["carga"]:.2f}"/>')
    gotas = ""
    for i in range(3):                 # goteo de metal fundido
        ph = (i / 3 + f / 6) % 1
        gx = cx - 30 + i * 30
        gotas += f'<ellipse cx="{gx:.1f}" cy="{cy + R - 4 + ph * 80:.1f}" rx="3" ry="5" fill="{t["grieta2"]}" opacity="{(1 - ph) * .9:.2f}" filter="url(#brillo)"/>'
    filtro = ' filter="url(#blanco)"' if p["flash"] else ""
    cuerpo = (da1 + da2 + trozos_d + "".join(x for z, x in sorted(corona, key=lambda q: q[0]) if z < 0) + gotas + esfera
              + "".join(x for z, x in sorted(corona, key=lambda q: q[0]) if z >= 0) + ojo + dl1 + dl2 + trozos_l + carga)
    out += f'<g{filtro}>{cuerpo}</g>'
    if p["nova"] is not None:          # onda expansiva
        n = p["nova"]
        rx = [120, 190, 250, 300][n]
        out += (f'<ellipse cx="192" cy="{J_SUELO - 20}" rx="{rx}" ry="{rx * .3:.1f}" fill="none" stroke="{t["grieta"]}" '
                f'stroke-width="{[16, 11, 6, 3][n]}" opacity="{[1, .75, .45, .2][n]}" filter="url(#brillo)"/>'
                f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{[110, 170, 215, 250][n]}" fill="none" stroke="#ffffff" stroke-width="{[8, 5, 3, 2][n]}" opacity="{[.9, .6, .35, .15][n]}"/>')
        if n == 0:
            out += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="200" fill="url(#destello)"/>'
    if anim == "muerte" and f == 6:
        out += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="230" fill="url(#destello)"/><circle cx="{cx:.1f}" cy="{cy:.1f}" r="120" fill="#ffffff" opacity=".85"/>'
    return gh.svg(384, 384, out, defs_tema(t) + DEFS_JEFE)


# ======================================================== RENDERIZADO ===
def render_lote(trabajos):
    """trabajos: [(svg_texto, ruta_png, w, h)] -> se renderizan en paralelo con rsvg-convert."""
    def uno(tr):
        texto, ruta, w, h = tr
        with open(ruta[:-4] + ".svg", "w") as fh:
            fh.write(texto)
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), ruta[:-4] + ".svg", "-o", ruta], check=True)
    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(uno, trabajos))


def hoja_8dir(carpeta, nombre, fn, n_frames, px):
    """Renderiza una animación en las 8 direcciones y monta su hoja (8 filas x n columnas)."""
    tmp = f"{carpeta}/_tmp"
    os.makedirs(tmp, exist_ok=True)
    os.makedirs(f"{carpeta}/svg", exist_ok=True)
    trabajos = [(fn(theta_de_fila(k), f), f"{tmp}/{nombre}_{k}_{f}.png", px, px) for k in range(8) for f in range(n_frames)]
    render_lote(trabajos)
    hoja = Image.new("RGBA", (px * n_frames, px * 8))
    for k in range(8):
        for f in range(n_frames):
            hoja.alpha_composite(Image.open(f"{tmp}/{nombre}_{k}_{f}.png").convert("RGBA"), (f * px, k * px))
    hoja.save(f"{carpeta}/{nombre}.png", optimize=True)
    for k in (2,):                     # guardamos un SVG de muestra por animación (sur)
        shutil.copy(f"{tmp}/{nombre}_{k}_0.svg", f"{carpeta}/svg/{nombre}_S_0.svg")


def tira(carpeta, nombre, fn, n_frames, w, h):
    tmp = f"{carpeta}/_tmp"
    os.makedirs(tmp, exist_ok=True)
    render_lote([(fn(f), f"{tmp}/{nombre}_{f}.png", w, h) for f in range(n_frames)])
    hoja = Image.new("RGBA", (w * n_frames, h))
    for f in range(n_frames):
        hoja.alpha_composite(Image.open(f"{tmp}/{nombre}_{f}.png").convert("RGBA"), (f * w, 0))
    hoja.save(f"{carpeta}/{nombre}.png", optimize=True)


ANIMS = {"golem": {"caminar": 4, "atacar": 6, "dano": 3, "muerte": 8},
         "vigia": {"caminar": 4, "atacar": 6, "dano": 3, "muerte": 8},
         "murcielago": {"caminar": 4, "atacar": 4, "dano": 3, "muerte": 6},
         "jefe": {"flotar": 6, "atacar": 8, "dano": 3, "muerte": 10}}
FUNCIONES = {"golem": (svg_golem, 128), "vigia": (svg_vigia, 96), "murcielago": (svg_murcielago, 64)}


def generar(enemigo):
    carpeta = f"{BASE}/{enemigo}"
    if enemigo == "jefe":
        for anim, n in ANIMS["jefe"].items():
            hoja_8dir(carpeta, f"jefe_{anim}", lambda th, f, a=anim: svg_jefe(a, th, f), n, 384)
        tema_bola = dict(gh.TEMA_FUEGO, paleta=[("#c43a0c", 1.0), ("#ff8a1a", .8), ("#ffd25a", .58), ("#ffffff", .32)])
        tira(carpeta, "jefe_bola_vuelo", lambda f: gh.svg_bola_vuelo(f, tema=tema_bola), 6, 128, 64)
        tira(carpeta, "jefe_bola_impacto", lambda f: gh.svg_bola_impacto(f, tema=tema_bola), 8, 128, 128)
    else:
        fn, px = FUNCIONES[enemigo]
        for capa, t in TEMAS.items():
            for anim, n in ANIMS[enemigo].items():
                hoja_8dir(carpeta, f"{enemigo}_{capa}_{anim}", lambda th, f, a=anim, t=t: fn(t, a, th, f), n, px)
            if enemigo == "vigia":
                tira(carpeta, f"vigia_{capa}_esquirla_vuelo", lambda f, t=t: svg_esquirla(t, f), 4, 64, 32)
                tira(carpeta, f"vigia_{capa}_esquirla_impacto", lambda f, t=t: svg_esquirla_impacto(t, f), 6, 64, 64)
    if os.environ.get("BORRAR_TMP", "1") == "1":
        shutil.rmtree(f"{carpeta}/_tmp", ignore_errors=True)


if __name__ == "__main__":
    for e in (sys.argv[1:] or ["golem", "vigia", "murcielago", "jefe"]):
        generar(e)
        print(e, "ok")
