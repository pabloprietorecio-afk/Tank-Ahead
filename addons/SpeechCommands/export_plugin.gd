@tool
extends EditorPlugin
## Añade al APK/AAB el plugin de Android SpeechCommands (reconocimiento de voz del sistema).
## El .aar se compila en GitHub Actions con android_plugins/speech_commands/build.sh.

var export_plugin: SpeechExportPlugin


func _enter_tree() -> void:
	export_plugin = SpeechExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class SpeechExportPlugin extends EditorExportPlugin:
	const NAME := "SpeechCommands"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([NAME + "/bin/debug/" + NAME + "-debug.aar"])
		return PackedStringArray([NAME + "/bin/release/" + NAME + "-release.aar"])

	## Hardware que Google Play da por obligatorio sin serlo y que deja fuera dispositivos:
	## - el micrófono, por el permiso RECORD_AUDIO (las órdenes por voz son opcionales);
	## - la pantalla apaisada, porque la actividad está fijada en horizontal (lo avisa la consola:
	##   afecta a teléfonos, tabletas, ordenadores, Play Games en PC y Android XR).
	## Declarados como no obligatorios, esos dispositivos pueden instalar el juego.
	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return """    <uses-feature android:name="android.hardware.microphone" android:required="false" />
    <uses-feature android:name="android.hardware.screen.landscape" android:required="false" />
"""

	func _get_name() -> String:
		return NAME
