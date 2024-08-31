import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data'; // Import the 'typed_data' package
import 'package:ffi/ffi.dart';
import 'package:rtaudio/rtaudio_android.dart';
import 'rtaudio_bindings_generated.dart';

extension ArrayCharExtensions on ffi.Array<ffi.Char> {
  String toDartString() {
    var bytesBuilder = BytesBuilder();
    int index = 0;
    while (this[index] != 0) {
      bytesBuilder.addByte(this[index] & 0xFF);
      ++index;
    }
    var bytes = bytesBuilder.takeBytes();
    return utf8.decode(bytes);
  }
}

const String _libName = 'rtaudio';

/// The dynamic library in which the symbols for [RtaudioBindings] can be found.
final ffi.DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final RtaudioBindings _bindings = RtaudioBindings(_dylib);

class AudioDevice {
  late final String _name;
  late final int _id;
  late final ma_device_info _info;
  late final bool _fromAndroid;

  String get name => _name;
  int get id => _id;
  ma_device_info get info => _info;

  AudioDevice._(rta_audio_device_t device) {
    _name = device.name.toDartString();
    _id = device.id;
    _info = device.info;
    _fromAndroid = false;
  }

  AudioDevice._ctor(this._name, this._id, this._fromAndroid);

  factory AudioDevice.fromMap(Map<String, dynamic> map) {
    return AudioDevice._ctor(map['name'], map['id'], true);
  }
}

typedef AudioCallback = void Function(List<double> output, int numFrames, [dynamic userData]);
typedef _NativeAudioCallbackSignature = ffi.Void Function(ffi.Pointer<ffi.Float> output, ffi.Int numFrames);

class AudioContextConfig {
  final int sampleRate;
  final int numChannels;
  final AudioCallback callback;
  final dynamic userData;

  AudioContextConfig({
    this.sampleRate = 44100,
    this.numChannels = 2,
    required this.callback,
    this.userData,
  });
}

class AudioContext {
  late final ffi.Pointer<rta_audio_context_t> _context;
  AudioContext._(this._context);

  void dispose() {
    using((arena) {
      _bindings.rta_context_destroy(_context);
    });
  }
}

class RtAudio {
  static Future<List<AudioDevice>> getDevices() async {
    // for android use Java implementation
    if (Platform.isAndroid) {
      return RtAudioAndroid.getDevices();
    }

    final completer = Completer<List<AudioDevice>>();
    final devices = <AudioDevice>[];
    
    final deviceCount = using((arena) {
      final ptr = arena.allocate<ffi.Int>(ffi.sizeOf<ffi.Int>());
      _bindings.rta_get_device_count(ptr);
      return ptr.value;
    });
    
    ffi.Pointer<rta_audio_device_t> devicePtr = calloc<rta_audio_device_t>(deviceCount);
    if (_bindings.rta_get_devices(devicePtr) != rta_error.RTA_SUCCESS) {
      completer.completeError('Failed to get devices');
    } else {
      for (int i = 0; i < deviceCount; i++) {
        devices.add(AudioDevice._((devicePtr + i).ref));
      }
      completer.complete(devices);
    }
    calloc.free(devicePtr);

    return completer.future;
  }

  static Future<AudioContext> createContext(AudioContextConfig config, AudioDevice device) async {
    final completer = Completer<AudioContext>();

    final conf = calloc<rta_audio_context_config_t>();
    conf.ref.sampleRate = config.sampleRate;
    conf.ref.channels = config.numChannels;

    void fn(ffi.Pointer<ffi.Float> output, int numFrames) {
      final outputList = output.asTypedList(numFrames * config.numChannels);
      config.callback(outputList, numFrames, config.userData);
    }

    conf.ref.dataCallback = ffi.NativeCallable<_NativeAudioCallbackSignature>.listener(fn).nativeFunction;

    final context = calloc<rta_audio_context_t>();
    
    if (device._fromAndroid && Platform.isAndroid) {
      if (_bindings.rta_context_create_aaudio(conf, device.id, context) != rta_error.RTA_SUCCESS) {
        completer.completeError('Failed to create audio context');
        return completer.future;
      }
    } else {
      final devPtr = calloc<rta_audio_device_t>();
      if (_bindings.rta_get_device(device.id, devPtr) != rta_error.RTA_SUCCESS) {
        calloc.free(devPtr);
        completer.completeError('Failed to get device info');
        return completer.future;
      }

      if (_bindings.rta_context_create(conf, devPtr, context) != rta_error.RTA_SUCCESS) {
        calloc.free(devPtr);
        completer.completeError('Failed to create audio context');
        return completer.future;
      }
    }
    
    completer.complete(AudioContext._(context));

    return completer.future;
  }
}
