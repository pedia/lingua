import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../epub/epub.dart';
import '../epub/lang.dart';
import 'dualtts.dart';

enum Playback { startLine, endLine, pause, stop }

class Event {
  final Playback playback;
  final Chunk? chunk;
  const Event({required this.playback, this.chunk});
}

class Engine {
  final _eventController = StreamController<Event>.broadcast();
  Stream<Event> get events => _eventController.stream;

  List<Chunk> _lines = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  Completer<void>? _delayCompleter;
  final tts = FlutterTts();
  final Map<Lang, EngineSetting> ss = {};

  // 1. Non-blocking: returns void, runs the loop asynchronously in the background
  void playLines(List<Chunk> lines) {
    if (_isPlaying) {
      stop(); // Stop any existing playback session first
    }

    _lines = lines;
    _currentIndex = 0;
    _isPlaying = true;
    _isPaused = false;

    // Fire and forget background loop (no await needed by the caller)
    _startPlaybackLoop();
  }

  Future<void> _startPlaybackLoop() async {
    while (_isPlaying && _currentIndex < _lines.length) {
      // Handle pause state blocking
      while (_isPaused && _isPlaying) {
        _delayCompleter = Completer<void>();
        await _delayCompleter?.future;
      }

      if (!_isPlaying) break;

      final line = _lines[_currentIndex];

      // Emit StartLine
      _eventController.add(Event(playback: Playback.startLine, chunk: line));

      // Simulate TTS duration for the current line
      int durationMs = line.text.length * 50;
      _delayCompleter = Completer<void>();

      try {
        await Future.any([
          Future.delayed(Duration(milliseconds: durationMs)),
          _delayCompleter!
              .future, // Allows breaking out early when skipped, paused, or stopped
        ]);
      } catch (_) {}

      if (!_isPlaying) break;

      // Emit EndLine (only if we didn't skip past it or stop)
      _eventController.add(Event(playback: Playback.endLine, chunk: line));

      // Advance to the next line (unless skip() modified _currentIndex)
      _currentIndex++;
    }

    _isPlaying = false;
    _eventController.add(const Event(playback: Playback.stop));
  }

  // 2. Skip function: supports forward (+10) and backward (-10) jumps
  void skip(int count) {
    if (!_isPlaying) return;

    // Optional: Emit EndLine for the line we are abruptly leaving
    if (_currentIndex < _lines.length) {
      _eventController.add(
        Event(playback: Playback.endLine, chunk: _lines[_currentIndex]),
      );
    }

    // Update index safely within bounds
    _currentIndex = (_currentIndex + count).clamp(0, _lines.length - 1);

    // Interrupt the active line timer so the loop immediately jumps to the new index
    if (_delayCompleter != null && !_delayCompleter!.isCompleted) {
      _delayCompleter!.complete();
    }
  }

  void pause() {
    _isPaused = true;
    _eventController.add(const Event(playback: Playback.pause));
  }

  void resume() {
    _isPaused = false;
    if (_delayCompleter != null && !_delayCompleter!.isCompleted) {
      _delayCompleter!.complete();
    }
  }

  void stop() {
    _isPlaying = false;
    _isPaused = false;
    if (_delayCompleter != null && !_delayCompleter!.isCompleted) {
      _delayCompleter!.complete();
    }
    _eventController.add(const Event(playback: Playback.stop));
  }

  void apply(List<EngineSetting> vs) {}

  void dispose() {
    stop();
    _eventController.close();
  }
}

class EngineState {
  final List<Chunk> chunks;
  final int? currentIndex;
  final bool isPlaying;
  final bool isPaused;

  const EngineState({
    this.chunks = const [],
    this.currentIndex,
    this.isPlaying = false,
    this.isPaused = false,
  });

  EngineState copyWith({
    List<Chunk>? chunks,
    int? currentIndex,
    bool? isPlaying,
    bool? isPaused,
  }) {
    return EngineState(
      chunks: chunks ?? this.chunks,
      currentIndex: currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

// --- Riverpod Notifier ---
class EngineNotifier extends Notifier<EngineState> {
  late final Engine _engine;
  StreamSubscription? _subscription;

  @override
  EngineState build() {
    _engine = Engine();

    // Listen to the background stream from TtsEngine
    _subscription = _engine.events.listen((event) {
      switch (event.playback) {
        case Playback.startLine:
          final index = event.chunk != null
              ? state.chunks.indexWhere((l) => l.idx == event.chunk!.idx)
              : null;
          state = state.copyWith(
            currentIndex: index != -1 ? index : null,
            isPlaying: true,
            isPaused: false,
          );
          break;
        case Playback.pause:
          state = state.copyWith(isPaused: true);
          break;
        case Playback.stop:
          state = state.copyWith(
            isPlaying: false,
            isPaused: false,
            currentIndex: null,
          );
          break;
        case Playback.endLine:
          // Handled or can be used for secondary triggers
          break;
      }
    });

    // Clean up subscription and engine when provider is disposed
    ref.onDispose(() {
      _subscription?.cancel();
      _engine.dispose();
    });

    return const EngineState();
  }

  void play(List<Chunk> lines) {
    state = state.copyWith(chunks: lines, isPlaying: true, isPaused: false);
    _engine.playLines(lines);
  }

  void pause() {
    _engine.pause();
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    _engine.resume();
    state = state.copyWith(isPaused: false);
  }

  void stop() {
    _engine.stop();
    state = state.copyWith(
      isPlaying: false,
      isPaused: false,
      currentIndex: null,
    );
  }

  void skip(int count) {
    _engine.skip(count);
  }

  void apply(List<EngineSetting> vs) {
    _engine.apply(vs);
  }
}

final engineProvider = NotifierProvider<EngineNotifier, EngineState>(
  EngineNotifier.new,
);
