package br.com.teknetsys.rtaudio;

import com.google.gson.Gson;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import io.flutter.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.JSONUtil;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;

public final class MethodCallHandlerImpl implements MethodCallHandler {
    private final RtAudio plugin;

    @Nullable  private MethodChannel channel;

    public MethodCallHandlerImpl(RtAudio plugin) {
        this.plugin = plugin;
    }

    @Override
    public void onMethodCall(MethodCall call, @NotNull Result result) {
        switch (call.method) {
            case "enumerateOutputDevices":
                final List<AudioDevice> devices = plugin.enumerateOutputDevices();
                final String jsonStr = (new Gson()).toJson(devices);
                result.success(jsonStr);
                break;
            default:
                result.notImplemented();
        }
    }

    public void startListening(BinaryMessenger messenger) {
        if (channel != null) {
            Log.wtf("RtAudio", "Setting a method call handler before the last was disposed.");
            stopListening();
        }
        channel = new MethodChannel(messenger, "br.com.teknetsys/rtaudio");
        channel.setMethodCallHandler(this);
    }

    public void stopListening() {
        if (channel == null) {
            Log.wtf("RtAudio", "Tried to stop listening when no method call handler was set.");
            return;
        }
        channel.setMethodCallHandler(null);
        channel = null;
    }
}
