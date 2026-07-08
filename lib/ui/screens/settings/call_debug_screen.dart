import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:semya/data/services/call_debug_log.dart';

class CallDebugScreen extends StatefulWidget {
  const CallDebugScreen({super.key});

  @override
  State<CallDebugScreen> createState() => _CallDebugScreenState();
}

class _CallDebugScreenState extends State<CallDebugScreen> {
  late String _logs;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _logs = CallDebugLog.all);

  Future<void> _clear() async {
    await CallDebugLog.clear();
    _refresh();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _logs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: _logs.isEmpty ? null : _copy,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _logs.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Text(
                'No logs yet.\nMake a call to see logs here.',
                textAlign: TextAlign.center,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _logs,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
    );
  }
}
