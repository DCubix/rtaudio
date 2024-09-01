import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data'; // Import the 'typed_data' package
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
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
  static Future<List<AudioDevice>> _getDevicesCompute(void _) {
    // for android use Java implementation
    if (Platform.isAndroid) {
      return RtAudioAndroid.getDevices();
    }

    final devices = <AudioDevice>[];
    
    final deviceCount = using((arena) {
      final ptr = arena.allocate<ffi.Int>(ffi.sizeOf<ffi.Int>());
      _bindings.rta_get_device_count(ptr);
      return ptr.value;
    });
    
    ffi.Pointer<rta_audio_device_t> devicePtr = calloc<rta_audio_device_t>(deviceCount);
    if (_bindings.rta_get_devices(devicePtr) != rta_error.RTA_SUCCESS) {
      return Future.error('Failed to get devices');
    } else {
      for (int i = 0; i < deviceCount; i++) {
        devices.add(AudioDevice._((devicePtr + i).ref));
      }
    }
    calloc.free(devicePtr);

    return Future.value(devices);
  }

  static Future<List<AudioDevice>> getDevices() async {
    return compute(_getDevicesCompute, null);
  }

  static Future<AudioContext> createContext(AudioContextConfig config, AudioDevice device) async {
    final context = calloc<rta_audio_context_t>();
    final conf = calloc<rta_audio_context_config_t>();

    conf.ref.sampleRate = config.sampleRate;
    conf.ref.channels = config.numChannels;

    void fn(ffi.Pointer<ffi.Float> output, int numFrames) {
      final outputList = output.asTypedList(numFrames * config.numChannels);
      config.callback(outputList, numFrames, config.userData);
    }

    conf.ref.dataCallback = ffi.NativeCallable<_NativeAudioCallbackSignature>.listener(fn).nativeFunction;

    if (device._fromAndroid && Platform.isAndroid) {
      rta_error res = await compute(_contextCreateAaudio, {
        'conf': conf,
        'id': device.id,
        'context': context,
      });
      if (res != rta_error.RTA_SUCCESS) {
        return Future.error('Failed to create context');
      }
    } else {
      final devPtr = calloc<rta_audio_device_t>();

      rta_error res = await compute(_getDevice, {
        'id': device.id,
        'devPtr': devPtr,
      });
      if (res != rta_error.RTA_SUCCESS) {
        calloc.free(devPtr);
        return Future.error('Failed to get device');
      }

      res = await compute(_contextCreate, {
        'conf': conf,
        'devPtr': devPtr,
        'context': context,
      });
      if (res != rta_error.RTA_SUCCESS) {
        calloc.free(devPtr);
        return Future.error('Failed to create context');
      }
    }

    return AudioContext._(context);
  }

  static Future<rta_error> _getDevice(Map<String, dynamic> args) {
    final id = args['id'] as int;
    final devPtr = args['devPtr'] as ffi.Pointer<rta_audio_device_t>;
    return Future.value(_bindings.rta_get_device(id, devPtr));
  }

  static Future<rta_error> _contextCreate(Map<String, dynamic> args) {
    final conf = args['conf'] as ffi.Pointer<rta_audio_context_config_t>;
    final devPtr = args['devPtr'] as ffi.Pointer<rta_audio_device_t>;
    final context = args['context'] as ffi.Pointer<rta_audio_context_t>;
    return Future.value(_bindings.rta_context_create(conf, devPtr, context));
  }

  static Future<rta_error> _contextCreateAaudio(Map<String, dynamic> args) {
    final conf = args['conf'] as ffi.Pointer<rta_audio_context_config_t>;
    final id = args['id'] as int;
    final context = args['context'] as ffi.Pointer<rta_audio_context_t>;
    return Future.value(_bindings.rta_context_create_aaudio(conf, id, context));
  }

}
