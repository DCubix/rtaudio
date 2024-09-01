import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:rtaudio/rtaudio.dart' as rtaudio;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class SineWave {
  double phase;

  SineWave() : phase = 0;
}

class _MyAppState extends State<MyApp> {

  rtaudio.AudioContext? _audioContext;
  List<rtaudio.AudioDevice> _devices = [];

  final SineWave _sineWave = SineWave();

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final devices = await rtaudio.RtAudio.getDevices();
      for (final device in devices) {
        print('Device: ${device.name}, id: ${device.id}');
      }
      setState(() {
        _devices = devices;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),

                for (final device in _devices)
                  ListTile(
                    title: Text(device.name),
                    subtitle: Text('ID: ${device.id}'),
                    onTap: () async {
                      final acc = rtaudio.AudioContextConfig(
                        callback: (output, numFrames, [userdata]) {
                          final wave = userdata as SineWave;

                          for (var i = 0; i < numFrames; i++) {
                            final value = sin(wave.phase) * 0.4;
                            output[i * 2 + 0] = value;
                            output[i * 2 + 1] = value;

                            wave.phase += (pi * 2.0 * 440.0) / 44100.0;
                            if (wave.phase > pi * 2.0) {
                              wave.phase -= pi * 2.0;
                            }
                          }
                        },
                        userData: _sineWave,
                        numChannels: 2
                      );

                      _audioContext?.dispose();
                      _audioContext = await rtaudio.RtAudio.createContext(acc, device);
                      print(device.name);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
