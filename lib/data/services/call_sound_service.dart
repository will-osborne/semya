import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class CallSoundService {
  final AudioPlayer _player = AudioPlayer();

  /// Plays the outgoing dial/ringback tone through the voice call channel.
  /// On iOS, CallKit manages the audio session — playing via just_audio
  /// creates a conflicting AVAudioSession that interferes with CallKit's
  /// audio routing, so we skip the dial tone entirely.
  Future<void> playDialTone() async {
    if (Platform.isIOS) return;

    await _configureForVoiceCall();
    await _player.setAsset('assets/sounds/dial_tone.wav');
    await _player.setLoopMode(LoopMode.all);
    await _player.setVolume(1.0);
    await _player.play();
  }

  /// Stops playback and releases audio focus so WebRTC can take over.
  Future<void> stop() async {
    await _player.stop();
    if (Platform.isAndroid) {
      final session = await AudioSession.instance;
      await session.setActive(false);
    }
  }

  /// Reconfigures the audio session for active voice calls.
  /// On iOS, CallKit manages the audio session — this is a no-op.
  Future<void> configureForVoiceCall() => _configureForVoiceCall();

  Future<void> _configureForVoiceCall() async {
    // On iOS, CallKit manages the audio session via
    // didActivateAudioSession / didDeactivateAudioSession in AppDelegate.
    if (Platform.isIOS) return;

    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
  }

  void dispose() {
    _player.dispose();
  }
}
