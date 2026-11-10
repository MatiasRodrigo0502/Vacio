## La ficha de una cosa del gacha, al pulsarla en la coleccion: en grande (la
## skin dando vueltas, el arma flotando), su tier, su nombre, que hace y, si se
## tiene, el boton de ponersela. Lo que aun no se tiene sale en silueta, con lo
## que cuesta sacarlo. Pedida por Matias el 2026-11-05, con el gacha nuevo.
class_name DetalleGacha
extends Control

signal cerrado

## Lo que le pasa al enemigo que mata un arma, por AnimacionMuerte.Tipo.
const AL_MATAR := ["", "lo fulmina un rayo", "se lo traga un torbellino", "arde en una llamarada",
		"se le escapa el alma", "estalla en esquirlas"]
## Como se llama lo que dispara un arma, por BolaMagica.Estilo: singular, plural y
## si es femenino. Asi la ficha dice «tres flechas» o «dos filos», y no «bolas».
const PROYECTILES := [["bola", "bolas", true], ["estrella", "estrellas", true],
		["flecha", "flechas", true], ["runa", "runas", true], ["filo", "filos", false],
		["rayo", "rayos", false]]
const NUMEROS := ["", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho"]
## Cada cuanto dispara un mago normal (Jugador.cadencia_disparo de fabrica), para
## decir el ritmo de un arma en segundos.
const RITMO_NORMAL: float = 0.5
const GRIS := "[color=#9a948e]%s[/color]"
## Lo ancho de la columna de texto. Con 400, la ficha de una mitica, con sus tres
## modos explicados, no cabia de alto en la pantalla.
const ANCHO_TEXTO: float = 470.0
const COLOR_TEXTO := Color(0.85, 0.82, 0.78)
const COLOR_APAGADO := Color(0.62, 0.58, 0.55)

var _cosa: Resource
var _tirada: TiradaGacha
## El mago de la fila, cuando es la de serie de un mago (PersonajeJugable).
var _giro: GiroGacha
var _tier: Label
var _nombre: Label
var _debajo: Label
var _texto: RichTextLabel
var _estado: Label
var _boton_poner: Button
var _boton_cerrar: Button
var _marco: StyleBoxFlat


func _init() -> void:
	name = "DetalleGacha"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var oscuro := ColorRect.new()
	oscuro.color = Color(0.0, 0.0, 0.0, 0.75)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Pulsar fuera la cierra, como cualquier ventana de este tipo.
	oscuro.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed:
			_cerrar())
	add_child(oscuro)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var panel := PanelContainer.new()
	_marco = StyleBoxFlat.new()
	_marco.bg_color = Color(0.07, 0.055, 0.08)
	_marco.set_border_width_all(3)
	_marco.set_corner_radius_all(12)
	_marco.set_content_margin_all(18.0)
	_marco.shadow_size = 18
	panel.add_theme_stylebox_override("panel", _marco)
	centro.add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 22)
	panel.add_child(fila)
	_giro = GiroGacha.new()
	_giro.custom_minimum_size = Vector2(320.0, 360.0)
	fila.add_child(_giro)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(ANCHO_TEXTO, 0.0)
	caja.add_theme_constant_override("separation", 6)
	fila.add_child(caja)
	_tier = _etiqueta(24, COLOR_TEXTO)
	caja.add_child(_tier)
	_nombre = _etiqueta(32, Color.WHITE)
	caja.add_child(_nombre)
	_debajo = _etiqueta(17, COLOR_APAGADO)
	caja.add_child(_debajo)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.custom_minimum_size = Vector2(ANCHO_TEXTO, 0.0)
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.add_theme_font_size_override("normal_font_size", 16)
	_texto.add_theme_font_size_override("bold_font_size", 16)
	_texto.add_theme_color_override("default_color", COLOR_TEXTO)
	caja.add_child(_texto)
	_estado = _etiqueta(15, COLOR_APAGADO)
	caja.add_child(_estado)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 12)
	caja.add_child(botones)
	_boton_poner = Button.new()
	_boton_poner.custom_minimum_size = Vector2(190.0, 44.0)
	_boton_poner.add_theme_font_size_override("font_size", 18)
	_boton_poner.pressed.connect(_poner)
	botones.add_child(_boton_poner)
	_boton_cerrar = Button.new()
	_boton_cerrar.text = "Cerrar"
	_boton_cerrar.custom_minimum_size = Vector2(140.0, 44.0)
	_boton_cerrar.add_theme_font_size_override("font_size", 18)
	_boton_cerrar.pressed.connect(_cerrar)
	botones.add_child(_boton_cerrar)


func _etiqueta(tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(ANCHO_TEXTO, 0.0)
	return etiqueta


## Una SkinMago, un ArmaMago, un PersonajeJugable (la de serie de ese mago) o
## null (sin arma).
func ensenar(cosa: Resource, tirada: TiradaGacha) -> void:
	_cosa = cosa
	_tirada = tirada
	visible = true
	_rellenar()
	_boton_cerrar.grab_focus()


func _rellenar() -> void:
	var tengo := _tengo()
	var tier := _tier_de(_cosa)
	var color: Color = tirada_color(tier)
	_marco.border_color = color
	_marco.shadow_color = Color(color, 0.35)
	_giro.mostrar(_cosa)
	_giro.visible = _cosa != null
	_giro.silueta = not tengo
	_giro.color_tier = Color(color, 1.0) if tengo and tier >= 0 else Color(0.0, 0.0, 0.0, 0.0)
	_giro.velocidad = 1.6
	_tier.text = _tirada.tiers[tier] if tier >= 0 else "De serie"
	_tier.add_theme_color_override("font_color", color)
	_nombre.text = _nombre_de(_cosa) if tengo else "???"
	_debajo.text = ""
	var texto := ""
	if _cosa is SkinMago:
		_debajo.text = _cosa.mago
		texto = _cosa.descripcion
		if tengo:
			texto += "\n\n[color=#9a948e]Solo cambia cómo se ve.[/color]"
	elif _cosa is PersonajeJugable:
		_debajo.text = _cosa.nombre
		texto = "El aspecto de siempre."
	elif _cosa is ArmaMago:
		_debajo.text = "Para cualquier mago: " + ("solo cambia cómo se ve." if _cosa.solo_aspecto() \
				else "cambia su disparo normal.")
		texto = describir_arma(_cosa)
	else:
		texto = "Sin arma: el disparo de cada mago, como siempre."
	_texto.text = texto
	if not tengo:
		# Lo que hace si se ve: es lo que anima a buscarla.
		_texto.text = "[color=#9a948e]%s[/color]" % texto
	_estado.text = _texto_estado(tengo, tier)
	_poner_boton(tengo)


func tirada_color(tier: int) -> Color:
	return _tirada.colores[tier] if tier >= 0 else COLOR_APAGADO


func _texto_estado(tengo: bool, tier: int) -> String:
	if tengo:
		return "La llevas puesta." if _puesta() else "Es tuya."
	# La probabilidad de esa en concreto: la de su tier, entre las de su tier.
	var iguales := Coleccion.catalogo_de(_tirada).filter(func(otra: Resource) -> bool: return otra.tier == tier).size()
	var por_ciento := _tirada.probabilidades[tier] / maxf(1.0, iguales)
	return "Aún no la tienes. Sale con un %s %% en cada tirada." % String.num(por_ciento, 2).replace(".", ",")


func _poner_boton(tengo: bool) -> void:
	_boton_poner.visible = tengo
	_boton_poner.disabled = false
	var puesta := _puesta()
	if _cosa is ArmaMago:
		_boton_poner.text = "Quitarla" if puesta else "Llevarla"
	elif _cosa == null:
		_boton_poner.text = "Sin arma"
		_boton_poner.disabled = puesta
	elif _cosa is PersonajeJugable:
		_boton_poner.text = "Ponérsela"
		_boton_poner.disabled = puesta
	else:
		_boton_poner.text = "Quitársela" if puesta else "Ponérsela"


func _poner() -> void:
	var puesta := _puesta()
	if _cosa is SkinMago:
		Coleccion.poner_skin(_cosa.mago, null if puesta else _cosa)
	elif _cosa is PersonajeJugable:
		Coleccion.poner_skin(_cosa.nombre, null)
	elif _cosa is ArmaMago:
		Coleccion.poner_arma(null if puesta else _cosa)
	else:
		Coleccion.poner_arma(null)
	Sonido.tocar(&"objeto")
	_rellenar()


func _tengo() -> bool:
	if _cosa is SkinMago or _cosa is ArmaMago:
		return Coleccion.tiene(_cosa)
	return true


func _puesta() -> bool:
	if _cosa is SkinMago:
		return Coleccion.skin_puesta(_cosa.mago) == _cosa
	if _cosa is PersonajeJugable:
		return Coleccion.skin_puesta(_cosa.nombre) == null
	if _cosa is ArmaMago:
		return Coleccion.arma_puesta() == _cosa
	return Coleccion.arma_puesta() == null


static func _tier_de(cosa: Resource) -> int:
	if cosa is SkinMago or cosa is ArmaMago:
		return cosa.tier
	return -1


static func _nombre_de(cosa: Resource) -> String:
	if cosa is PersonajeJugable:
		return "De serie"
	return cosa.nombre if cosa != null else "Sin arma"


## Lo que hace un arma, en palabras y con los numeros de verdad: los de un mago sin
## ventajas, que ninguna sube el dano. Sale de sus modos, asi que un arma nueva se
## explica sola. Antes eran los multiplicadores tal cual («daño ×0,45, más lento»)
## y costaba entenderlo (Matias, 2026-11-10): parecia peor un arma que, con sus
## tres filos, quita mas que el disparo normal.
static func describir_arma(arma: ArmaMago) -> String:
	var lineas: PackedStringArray = [arma.descripcion, ""]
	if arma.solo_aspecto():
		lineas.append(GRIS % "Dispara y quita lo mismo que tu mago sin ella.")
		return "\n".join(lineas)
	if arma.tiene_modos():
		lineas.append("[b]Cambiar de forma[/b]: rueda del ratón, Q o el botón del móvil.")
		for modo in arma.modos:
			var frases: PackedStringArray = [_mayuscula(_que_sale(modo, arma)) + "."]
			var vuelo := _como_vuelan(modo)
			if not vuelo.is_empty():
				frases.append(_mayuscula(_enumerar(vuelo)) + ".")
			if not _ritmo(modo).is_empty():
				frases.append("Dispara %s." % _ritmo(modo))
			lineas.append("• [b]%s[/b]: %s" % [modo.nombre, " ".join(frases)])
	else:
		var modo: ModoArma = arma.modos[0]
		lineas.append("• [b]Cada disparo[/b]: %s." % _que_sale(modo, arma))
		if not _ritmo(modo).is_empty():
			lineas.append("• [b]Ritmo[/b]: %s." % _ritmo(modo))
		var vuelo := _como_vuelan(modo)
		if not vuelo.is_empty():
			lineas.append("• [b]Además[/b]: %s." % _enumerar(vuelo))
	if arma.muerte > 0:
		lineas.append("• [b]Al matar[/b]: %s (solo se ve)." % AL_MATAR[arma.muerte])
	lineas.append(GRIS % ("Sin arma: una bola de unos %d cada %s s."
			% [roundi(ArmaMago.DANO_BASE), _numero(RITMO_NORMAL)]))
	return "\n".join(lineas)


## Que sale en cada disparo y cuanto quita: «tres filos seguidos, de unos 5 cada
## uno (unos 14 si dan los tres)». Lo que quita lleva «unos» porque cada golpe sube
## al azar hasta un 30 % (BolaMagica.VARIACION).
static func _que_sale(modo: ModoArma, arma: ArmaMago) -> String:
	var proyectil: Array = PROYECTILES[modo.estilo if modo.estilo >= 0 else arma.estilo]
	var femenino: bool = proyectil[2]
	var a_la_vez := maxi(modo.proyectiles, 1)
	var seguidos := maxi(modo.rafaga, 1)
	var total := a_la_vez * seguidos
	var dano := ArmaMago.DANO_BASE * modo.dano
	var que := "%s %s" % [_cuantos(total, femenino), proyectil[1] if total > 1 else proyectil[0]]
	if a_la_vez > 1 and seguidos > 1:
		que = "%s %s a la vez, %s veces seguidas" % [_cuantos(a_la_vez, femenino), proyectil[1], _cuantos(seguidos, true)]
	elif a_la_vez > 1:
		que += " a la vez, en abanico" if modo.apertura > 0.0 else " a la vez"
	elif seguidos > 1:
		que += " seguidas" if femenino else " seguidos"
	if total == 1:
		return "%s de unos %d" % [que, roundi(dano)]
	var si_dan := "si dan todas" if femenino else "si dan todos"
	if total <= 3:
		si_dan = "si dan %s %s" % ["las" if femenino else "los", _cuantos(total, femenino)]
	return "%s, de unos %d %s (unos %d %s)" % [que, roundi(dano), "cada una" if femenino else "cada uno",
			roundi(dano * total), si_dan]


## Cada cuanto dispara, si no es lo normal. Por debajo de un 10 % no se nota jugando,
## y decirlo solo liaria.
static func _ritmo(modo: ModoArma) -> String:
	if absf(modo.cadencia - 1.0) < 0.1:
		return ""
	return "cada %s s, %s" % [_numero(RITMO_NORMAL * modo.cadencia),
			"más despacio" if modo.cadencia > 1.0 else "más deprisa"]


## Lo que hacen por el camino, lo que mas se nota primero. En singular si sale una
## sola («una bola... vuela»).
static func _como_vuelan(modo: ModoArma) -> PackedStringArray:
	var varias := maxi(modo.proyectiles, 1) * maxi(modo.rafaga, 1) > 1
	var n := "n" if varias else ""
	var partes: PackedStringArray = []
	if modo.velocidad >= 1.5:
		partes.append("vuela%s mucho más rápido" % n)
	elif modo.velocidad > 1.05:
		partes.append("vuela%s más rápido" % n)
	elif modo.velocidad < 0.95:
		partes.append("vuela%s más despacio" % n)
	if modo.radio >= 1.1:
		partes.append("son más grandes" if varias else "es más grande")
	if modo.onda > 0.0:
		partes.append("hacen eses y se cruzan" if modo.proyectiles > 1 else "hace%s eses" % n)
	if modo.busca > 0.0:
		partes.append("busca%s al enemigo más cercano" % n)
	if modo.atraviesa:
		partes.append("atraviesa%s enemigos (puede%s dar a varios)" % [n, n])
	if modo.rebotes > 0:
		partes.append("rebota%s %s en muros y rocas" % [n, "una vez" if modo.rebotes == 1 else "%d veces" % modo.rebotes])
	if modo.explosion > 0.0:
		# La mitad de su dano, como BolaMagica._explotar, tambien al que ha tocado.
		partes.append("explota%s al chocar (unos %d más a los de alrededor)"
				% [n, roundi(ArmaMago.DANO_BASE * modo.dano * 0.5)])
	return partes


## «a, b y c».
static func _enumerar(partes: PackedStringArray) -> String:
	if partes.size() == 1:
		return partes[0]
	return "%s y %s" % [", ".join(partes.slice(0, partes.size() - 1)), partes[partes.size() - 1]]


## El numero en letra si es pequeno («una», «un», «tres»); si no, en cifras.
static func _cuantos(numero: int, femenino: bool) -> String:
	if numero == 1 and not femenino:
		return "un"
	return NUMEROS[numero] if numero < NUMEROS.size() else str(numero)


static func _mayuscula(texto: String) -> String:
	return texto.left(1).to_upper() + texto.substr(1)


## Con coma y sin ceros de mas: 0,75, 0,8.
static func _numero(valor: float) -> String:
	return String.num(valor, 2).replace(".", ",")


func _cerrar() -> void:
	visible = false
	cerrado.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()
