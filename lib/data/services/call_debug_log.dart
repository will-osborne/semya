import 'dart:developer' as dev;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// In-memory ring buffer for call/WebRTC debug logs, with disk persistence
/// so logs survive a native crash. Call [init] once at app start.
class CallDebugLog {
  CallDebugLog._();

  static const int _maxLines = 500;
  static final List<String> _lines = [];
  static IOSink? _sink;

  /// Opens (or creates) the log file. Call once from main() before runApp.
  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/call_debug.log');
      // Truncate if it's grown large (keep last 50 KB).
      if (await file.exists() && await file.length() > 50 * 1024) {
        final lines = await file.readAsLines();
        final trimmed = lines.length > 200 ? lines.sublist(lines.length - 200) : lines;
        await file.writeAsString('${trimmed.join('\n')}\n');
        _lines.addAll(trimmed);
      } else if (await file.exists()) {
        _lines.addAll(await file.readAsLines());
      }
      _sink = file.openWrite(mode: FileMode.append);
    } catch (e) {
      dev.log('CallDebugLog.init failed: $e', name: 'CallDebugLog');
    }
  }

  static void add(String message, {String name = 'Call'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final line = '$timestamp [$name] $message';
    dev.log(message, name: name);
    if (_lines.length >= _maxLines) _lines.removeAt(0);
    _lines.add(line);
    try {
      _sink?.writeln(line);
      // Flush immediately so the line reaches disk before a possible crash.
      _sink?.flush();
    } catch (_) {}
  }

  static String get all => _lines.join('\n');

  static Future<void> clear() async {
    _lines.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/call_debug.log');
      if (await file.exists()) await file.writeAsString('');
    } catch (_) {}
  }

  static int get length => _lines.length;
}
