import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String level;

  LogEntry({required this.message, required this.level})
    : timestamp = DateTime.now();

  @override
  String toString() => '[${timestamp.toIso8601String()}] [$level]: $message';
}

class BufferedLogger {
  static final BufferedLogger _instance = BufferedLogger._internal();
  factory BufferedLogger() => _instance;
  BufferedLogger._internal();

  final int maxLogs = 500; // Keep the last 500 logs in memory
  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String message, {String level = 'INFO'}) {
    final entry = LogEntry(message: message, level: level);
    _logs.add(entry);

    if (_logs.length > maxLogs) {
      _logs.removeAt(0); // Drop the oldest log
    }

    // Also forward to debugPrint during development
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }

  void clear() {
    _logs.clear();
  }
}

// Global convenience shortcut
final logger = BufferedLogger();

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final logList = BufferedLogger().logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final allLogs = logList.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                BufferedLogger().clear();
              });
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: logList.length,
        itemBuilder: (context, index) {
          final log = logList[index];
          final isError = log.level == 'ERROR' || log.level == 'FATAL';

          return ListTile(
            dense: true,
            title: Text(
              log.message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isError ? Colors.red : Theme.of(context).highlightColor,
              ),
            ),
            subtitle: Text(
              '${log.timestamp.toLocal()} • [${log.level}]',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}

const Map<String, String> _ansiColors = {
  'black': '\x1B[30m',
  'red': '\x1B[31m',
  'green': '\x1B[32m',
  'yellow': '\x1B[33m',
  'blue': '\x1B[34m',
  'magenta': '\x1B[35m',
  'cyan': '\x1B[36m',
  'white': '\x1B[37m',
  'brightRed': '\x1B[91m',
  'brightGreen': '\x1B[92m',
  'brightYellow': '\x1B[93m',
  'brightBlue': '\x1B[94m',
};

const String _ansiReset = '\x1B[0m';

/// Converts markup like `xx[red]xx[/red]` into ANSI escape sequences.
String colorizeAnsi(String input) {
  final tagPattern = RegExp(r'\[([a-zA-Z]+)\](.*?)\[/\1\]', dotAll: true);

  return input.replaceAllMapped(tagPattern, (match) {
    final colorName = match.group(1)!;
    final content = match.group(2)!;
    final ansiCode = _ansiColors[colorName];

    if (ansiCode == null) return match.group(0)!;
    return '$ansiCode$content$_ansiReset';
  });
}

void clog(String message) {
  debugPrint(colorizeAnsi(message));
}
