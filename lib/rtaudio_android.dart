import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:rtaudio/rtaudio.dart';

class RtAudioAndroid {
  static const MethodChannel _channel = MethodChannel('br.com.teknetsys/rtaudio');

  static Future<List<AudioDevice>> getDevices() async {
    final String devicesJsonStr = await _channel.invokeMethod('enumerateOutputDevices');
    final List<dynamic> devices = json.decode(devicesJsonStr);
    return devices.map((device) => AudioDevice.fromMap(device)).toList();
  }

}
