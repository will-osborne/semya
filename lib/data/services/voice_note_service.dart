import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // In-flight (and completed, including negative) metadata fetches keyed by
  // URL, so each legacy voice note costs at most one roundtrip per session
  // regardless of how many bubbles ask concurrently.
  final Map<String, Future<Duration?>> _durationFetches = {};

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

  /// Stops the active recording and returns the local file path. The file is
  /// kept on disk until [uploadVoiceNote] confirms the upload so a failed
  /// upload can be retried from the same recording.
  Future<String> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw StateError('No recording to stop');
    }
    _currentRecordingPath = null;
    return path;
  }

  /// Uploads a recorded voice note and returns its download URL. The local
  /// file is deleted only after the upload has succeeded.
  Future<String> uploadVoiceNote({
    required String filePath,
    required String conversationId,
    required String messageId,
  }) async {
    final file = File(filePath);

    // Measure duration before uploading so we can store it in metadata.
    final tempPlayer = AudioPlayer();
    Duration? recordedDuration;
    try {
      // On iOS this probe can fail for some freshly-recorded files depending on
      // the active AVAudioSession state. Upload should still proceed.
      recordedDuration = await tempPlayer.setFilePath(filePath);
    } catch (_) {
      recordedDuration = null;
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
      // Persist the measured duration onto the message document so every
      // client renders the note's length without a Storage metadata
      // roundtrip. The sender owns the doc (rules allow the update) and the
      // write merges with the pending create in the offline queue.
      // Best-effort: display falls back to the metadata fetch on failure.
      unawaited(
        FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId)
            .update({'durationMs': recordedDuration.inMilliseconds})
            .catchError((_) {}),
      );
    }

    // Clean up the temp file only now that the upload has succeeded.
    await file.delete().catchError((_) => file);

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
  /// custom metadata. Fetches at most once per URL per session — results
  /// (including misses) are memoized so recycled bubbles never refetch.
  Future<Duration?> getDuration(String url) {
    final cached = _durationCache[url];
    if (cached != null) return Future.value(cached);

    return _durationFetches.putIfAbsent(url, () => _fetchDuration(url));
  }

  Future<Duration?> _fetchDuration(String url) async {
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
    await _setSource(url);
    await _player.play();
  }

  /// Seeks within [url]. If it is not the current source it is loaded first
  /// (paused), so scrubbing an inactive bubble sets its start point without
  /// starting playback — a subsequent [play] resumes from [position].
  Future<void> seek(String url, Duration position) async {
    if (_currentlyPlayingUrl != url) {
      await _player.stop();
      _currentlyPlayingUrl = url;
      await _setSource(url);
    }
    await _player.seek(position);
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

  /// Voice bubbles mid-upload hold a local file path instead of a download
  /// URL — load those from disk.
  Future<Duration?> _setSource(String url) {
    return url.startsWith('http')
        ? _player.setUrl(url)
        : _player.setFilePath(url);
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
