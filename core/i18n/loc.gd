class_name Loc
extends RefCounted
## Idiomas del juego. El texto del código está en español y es la clave: en español se muestra
## tal cual; en inglés se busca en EnglishTable y, si no está, también se muestra tal cual.
## Uso: Loc.t("TEXTO") o Loc.t("PUNTOS %d") % valor. Cambiar de idioma: GameSettings.set_language().

const LANGUAGES: Array[String] = ["es", "en"]
const LANGUAGE_NAMES: Dictionary = {"es": "ESPAÑOL", "en": "ENGLISH"}

static var language: String = "es"
static var _registered: bool = false


## Activa un idioma (registra la tabla inglesa la primera vez).
static func apply(code: String) -> void:
	language = code if code in LANGUAGES else "es"
	if not _registered:
		_registered = true
		var catalog := Translation.new()
		catalog.locale = "en"
		for key in EnglishTable.TABLE:
			catalog.add_message(StringName(key), StringName(EnglishTable.TABLE[key]))
		for context in EnglishTable.CONTEXT:
			var entries: Dictionary = EnglishTable.CONTEXT[context]
			for key in entries:
				catalog.add_message(StringName(key), StringName(entries[key]), StringName(context))
		TranslationServer.add_translation(catalog)
	TranslationServer.set_locale(language)


## Traduce `message` al idioma activo.
static func t(message: String) -> String:
	if language == "es" or message.is_empty():
		return message
	return String(TranslationServer.translate(StringName(message)))


## Igual, para un texto que en español se repite con otro sentido (ver EnglishTable.CONTEXT).
static func tc(message: String, context: String) -> String:
	if language == "es" or message.is_empty():
		return message
	return String(TranslationServer.translate(StringName(message), StringName(context)))


## Carpeta de las voces del idioma activo (las de español están en assets/voice).
static func voice_dir() -> String:
	return "res://assets/voice" if language == "es" else "res://assets/voice_%s" % language
