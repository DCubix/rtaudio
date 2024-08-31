package br.com.teknetsys.rtaudio;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class RtAudio {
    private final Context context;

    private static final Map<Integer, String> DEVICE_TYPE_MAP = new HashMap<>();
    static {
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_AUX_LINE, "auxiliary");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, "bluetooth");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE, "earpiece");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, "speaker");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_BUS, "bus");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_DOCK, "dock");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_FM, "fm");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_FM_TUNER, "fm_tuner");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_HDMI, "hdmi");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_HDMI_ARC, "hdmi_arc");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_IP, "ip");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_LINE_ANALOG, "line_analog");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_LINE_DIGITAL, "line_digital");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_TELEPHONY, "telephony");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_TV_TUNER, "tv_tuner");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_USB_ACCESSORY, "usb_accessory");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_USB_DEVICE, "usb_device");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_WIRED_HEADPHONES, "wired_headphones");
        DEVICE_TYPE_MAP.put(AudioDeviceInfo.TYPE_WIRED_HEADSET, "wired_headset");
    }

    public RtAudio(Context context) {
        this.context = context;
    }

    public List<AudioDevice> enumerateOutputDevices() {
        final AudioManager audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        final AudioDeviceInfo[] devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);

        return Arrays.stream(devices)
                .filter(AudioDeviceInfo::isSink)
                .filter(d -> d.getType() != AudioDeviceInfo.TYPE_TELEPHONY)
                .map(d -> new AudioDevice(
                        d.getId(),
                        d.getProductName().toString() +
                                " (" + DEVICE_TYPE_MAP.getOrDefault(d.getType(), "unknown") + ")"
                ))
                .collect(Collectors.toList());
    }

}
