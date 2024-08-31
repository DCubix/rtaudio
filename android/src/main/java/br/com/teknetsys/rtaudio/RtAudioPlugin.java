package br.com.teknetsys.rtaudio;

import android.util.Log;

import org.jetbrains.annotations.Nullable;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.PluginRegistry;

public class RtAudioPlugin implements FlutterPlugin {

    @Nullable private RtAudio plugin;
    @Nullable private MethodCallHandlerImpl methodCallHandler;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        plugin = new RtAudio(binding.getApplicationContext());
        methodCallHandler = new MethodCallHandlerImpl(plugin);
        methodCallHandler.startListening(binding.getBinaryMessenger());
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (methodCallHandler == null) {
            Log.wtf("RtAudio", "Tried to detach from engine without a method call handler.");
            return;
        }
        methodCallHandler.stopListening();
        methodCallHandler = null;
        plugin = null;
    }

    @SuppressWarnings("deprecation")
    public static void registerWith(PluginRegistry.Registrar registrar) {
        final MethodCallHandlerImpl handler = new MethodCallHandlerImpl(new RtAudio(registrar.context()));
        handler.startListening(registrar.messenger());
    }

}
