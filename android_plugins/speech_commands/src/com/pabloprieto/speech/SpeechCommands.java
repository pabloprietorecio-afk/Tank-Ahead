package com.pabloprieto.speech;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

/**
 * Reconocimiento de voz de Android (SpeechRecognizer) para las órdenes del juego.
 * Usa el servicio de voz del sistema (normalmente el de Google), sin interfaz propia.
 * Señales: listening_started(), partial_results(texto), final_results(texto), speech_error(código),
 * listening_ended(). Los textos llevan las alternativas separadas por saltos de línea.
 */
public class SpeechCommands extends GodotPlugin {
    private SpeechRecognizer recognizer;

    public SpeechCommands(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "SpeechCommands";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("listening_started"));
        signals.add(new SignalInfo("partial_results", String.class));
        signals.add(new SignalInfo("final_results", String.class));
        signals.add(new SignalInfo("speech_error", Integer.class));
        signals.add(new SignalInfo("listening_ended"));
        return signals;
    }

    /** Hay un servicio de reconocimiento de voz instalado. */
    @UsedByGodot
    public boolean isAvailable() {
        Activity activity = getActivity();
        return activity != null && SpeechRecognizer.isRecognitionAvailable(activity);
    }

    /** Empieza a escuchar en el idioma indicado (etiqueta BCP 47, p. ej. "es-ES"). */
    @UsedByGodot
    public void startListening(final String language, final String[] hints) {
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                destroyRecognizer();
                try {
                    recognizer = SpeechRecognizer.createSpeechRecognizer(activity);
                } catch (Exception e) {
                    recognizer = null;
                }
                if (recognizer == null) {
                    emit("speech_error", Integer.valueOf(SpeechRecognizer.ERROR_CLIENT));
                    emit("listening_ended");
                    return;
                }
                recognizer.setRecognitionListener(new Listener());
                Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, language);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, language);
                intent.putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, true);
                intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
                intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5);
                intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.getPackageName());
                // Pistas de vocabulario (Android 13+; los servicios que no las admiten las ignoran).
                if (hints != null && hints.length > 0) {
                    ArrayList<String> list = new ArrayList<>();
                    for (String hint : hints) {
                        list.add(hint);
                    }
                    intent.putStringArrayListExtra("android.speech.extra.BIASING_STRINGS", list);
                }
                try {
                    recognizer.startListening(intent);
                } catch (Exception e) {
                    destroyRecognizer();
                    emit("speech_error", Integer.valueOf(SpeechRecognizer.ERROR_CLIENT));
                    emit("listening_ended");
                }
            }
        });
    }

    /** Deja de escuchar y descarta lo oído. */
    @UsedByGodot
    public void cancel() {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                boolean was = recognizer != null;
                destroyRecognizer();
                if (was) {
                    emit("listening_ended");
                }
            }
        });
    }

    @Override
    public void onMainPause() {
        super.onMainPause();
        boolean was = recognizer != null;
        destroyRecognizer();
        if (was) {
            emit("listening_ended");
        }
    }

    @Override
    public void onMainDestroy() {
        destroyRecognizer();
        super.onMainDestroy();
    }

    /** Las señales se emiten en el hilo de Godot, no en el de la interfaz de Android. */
    private void emit(final String name, final Object... args) {
        runOnRenderThread(new Runnable() {
            @Override
            public void run() {
                emitSignal(name, args);
            }
        });
    }

    private void destroyRecognizer() {
        if (recognizer != null) {
            try {
                recognizer.cancel();
                recognizer.destroy();
            } catch (Exception ignored) {
            }
            recognizer = null;
        }
    }

    private static String join(Bundle bundle) {
        if (bundle == null) {
            return "";
        }
        ArrayList<String> texts = bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (texts == null) {
            return "";
        }
        StringBuilder out = new StringBuilder();
        for (String text : texts) {
            if (text == null) {
                continue;
            }
            if (out.length() > 0) {
                out.append('\n');
            }
            out.append(text);
        }
        return out.toString();
    }

    private class Listener implements RecognitionListener {
        @Override
        public void onReadyForSpeech(Bundle params) {
            emit("listening_started");
        }

        @Override
        public void onBeginningOfSpeech() {
        }

        @Override
        public void onRmsChanged(float rmsdB) {
        }

        @Override
        public void onBufferReceived(byte[] buffer) {
        }

        @Override
        public void onEndOfSpeech() {
        }

        @Override
        public void onError(int error) {
            destroyRecognizer();
            emit("speech_error", Integer.valueOf(error));
            emit("listening_ended");
        }

        @Override
        public void onResults(Bundle results) {
            String text = join(results);
            destroyRecognizer();
            emit("final_results", text);
            emit("listening_ended");
        }

        @Override
        public void onPartialResults(Bundle partialResults) {
            String text = join(partialResults);
            if (!text.isEmpty()) {
                emit("partial_results", text);
            }
        }

        @Override
        public void onEvent(int eventType, Bundle params) {
        }
    }
}
