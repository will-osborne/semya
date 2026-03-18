import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceNoteService {
  VoiceNoteService() {
    _playerCompleteSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        _currentlyPlayingUrl = null;
        unawaited(_releasePlaybackSession());
      }
    });
  }

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerCompleteSub;

  String? _currentRecordingPath;
  String? _currentlyPlayingUrl;

  // Cache of URL → duration fetched from Storage metadata.
  final Map<String, Duration> _durationCache = {};

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentRecordingPath = path;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
  }

  Future<String> stopRecordingAndUpload({
    required String conversationId,
    required String messageId,
  }) async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw StateError('No recording to stop');
    }

    final file = File(path);

    // Measure duration before uploading so we can store it in metadata.
    final tempPlayer = AudioPlayer();
    Duration? recordedDuration;
    try {
      recordedDuration = await tempPlayer.setFilePath(path);
    } finally {
      await tempPlayer.dispose();
    }

    final durationMs = (recordedDuration?.inMilliseconds ?? 0).toString();
    final storagePath = 'voice_notes/$conversationId/$messageId.m4a';
    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {'durationMs': durationMs},
      ),
    );
    final downloadUrl = await ref.getDownloadURL();

    // Cache locally so this sender sees it immediately.
    if (recordedDuration != null) {
      _durationCache[downloadUrl] = recordedDuration;
    }

    // Clean up temp file.
    await file.delete().catchError((_) => file);
    _currentRecordingPath = null;

    return downloadUrl;
  }

  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_currentRecordingPath != null) {
      await File(_currentRecordingPath!).delete().catchError((_) => File(''));
      _currentRecordingPath = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Returns the duration for a voice note URL, fetched from Firebase Storage
  /// custom metadata. Results are cached in memory.
  Future<Duration?> getDuration(String url) async {
    final cached = _durationCache[url];
    if (cached != null) return cached;

    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final metadata = await ref.getMetadata();
      final ms = metadata.customMetadata?['durationMs'];
      if (ms != null) {
        final duration = Duration(milliseconds: int.parse(ms));
        _durationCache[url] = duration;
        return duration;
      }
    } catch (_) {
      // Metadata fetch failed — duration will show after playback starts.
    }
    return null;
  }

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<Duration> get positionStream => _player.positionStream;

  Duration? get duration => _player.duration;

  String? get currentlyPlayingUrl => _currentlyPlayingUrl;

  Future<void> play(String url) async {
    await _configureForPlayback();

    // If already playing the same URL, just resume.
    if (_currentlyPlayingUrl == url && !_player.playing) {
      await _player.play();
      return;
    }

    // Stop any current playback and load new URL.
    await _player.stop();
    _currentlyPlayingUrl = url;
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentlyPlayingUrl = null;
    await _releasePlaybackSession();
  }

  void dispose() {
    _playerCompleteSub.cancel();
    _recorder.dispose();
    _player.dispose();
  }

  Future<void> _configureForPlayback() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);
    await _player.setVolume(1.0);
  }

  Future<void> _releasePlaybackSession() async {
    final session = await AudioSession.instance;
    await session.setActive(false);
  }
}
