import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../chunk/chunk.dart';
import 'voice.dart';
import '../log.dart';

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
  final _tts = FlutterTts();
  final Map<Lang, EngineSetting> _voices = {};

  // Tracks character progress for pause/resume slicing
  int _currentTextOffset = 0;
  Completer<void>? _utteranceCompleter;

  Engine() {
    _init();
  }
  void _init() {
    _tts.awaitSpeakCompletion(true).then((v) {
      logger.log('Engine init, awaitSpeakCompletion $v');
    });

    // Track where speech currently is within the active line
    _tts.setProgressHandler((text, start, end, word) {
      _currentTextOffset = end;
    });

    // Handle when flutter_tts finishes speaking an utterance naturally
    _tts.setCompletionHandler(() {
      logger.log('engine set complete handler ${_utteranceCompleter != null}');
      if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
        _utteranceCompleter!.complete();
      }
    });

    _tts.setCancelHandler(() {
      if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
        _utteranceCompleter!.complete();
      }
    });
  }

  // 1. Non-blocking: returns void, runs the loop asynchronously in the background
  void playLines(List<Chunk> lines) {
    if (_isPlaying) {
      logger.log('playing true, stop now');
      stop(); // Stop any existing playback session first
    }

    _lines = lines;
    _currentIndex = 0;
    _isPlaying = true;
    _isPaused = false;
    _currentTextOffset = 0;

    // Fire and forget background loop (no await needed by the caller)
    _startPlaybackLoop();
  }

  Future<void> _startPlaybackLoop() async {
    EngineSetting? preves;
    while (_isPlaying && _currentIndex < _lines.length) {
      logger.log('loop $_currentIndex');
      if (_isPaused) {
        // Wait until unpaused
        _utteranceCompleter = Completer<void>();
        await _utteranceCompleter?.future;
      }

      if (!_isPlaying) break;

      final line = _lines[_currentIndex];
      logger.log('speak $line voice length: ${_voices.length}');
      _eventController.add(Event(playback: Playback.startLine, chunk: line));

      // Determine text to speak (supports resuming from offset if paused mid-line)
      String textToSpeak = line.speak;
      if (_currentTextOffset > 0 && _currentTextOffset < textToSpeak.length) {
        textToSpeak = textToSpeak.substring(_currentTextOffset);
      }

      _utteranceCompleter = Completer<void>();

      if (preves?.lang != line.lang) {
        final v = _voices[line.lang];
        if (v != null) {
          applyEngineSetting(_tts, v);
        }
        preves = v;
      }

      // Tell flutter_tts to speak
      await _tts.speak(textToSpeak);

      // Wait for the utterance to finish, or get interrupted by pause/skip/stop
      await _utteranceCompleter?.future;

      if (!_isPlaying) break;

      // If we finished the line naturally (not paused/skipped), reset offset and emit endLine
      if (!_isPaused) {
        _eventController.add(Event(playback: Playback.endLine, chunk: line));
        _currentTextOffset = 0;
        _currentIndex++;
      }
    }

    _isPlaying = false;
    _eventController.add(const Event(playback: Playback.stop));
  }

  Future<void> pause() async {
    if (!_isPlaying || _isPaused) return;
    _isPaused = true;

    // Stop audio immediately since flutter_tts has no resume()
    await _tts.stop();

    // Interrupt current waiting future so the loop catches the pause state
    if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
      _utteranceCompleter!.complete();
    }

    _eventController.add(const Event(playback: Playback.pause));
  }

  void resume() {
    if (!_isPlaying || !_isPaused) return;
    _isPaused = false;

    // Unblock the loop; it will pick up from _currentTextOffset
    if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
      _utteranceCompleter!.complete();
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    _isPaused = false;
    _currentTextOffset = 0;

    await _tts.stop();

    if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
      _utteranceCompleter!.complete();
    }

    _eventController.add(const Event(playback: Playback.stop));
  }

  Future<void> skip(int count) async {
    if (!_isPlaying) return;

    // Stop current speech instantly
    await _tts.stop();

    // Emit EndLine for current line if moving away
    if (_currentIndex < _lines.length) {
      _eventController.add(
        Event(playback: Playback.endLine, chunk: _lines[_currentIndex]),
      );
    }

    // Reset offset and shift index
    _currentTextOffset = 0;
    _currentIndex = (_currentIndex + count).clamp(0, _lines.length - 1);

    // Unblock loop to jump to the new index
    if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
      _utteranceCompleter!.complete();
    }
  }

  void apply(List<EngineSetting> es) {
    for (var v in es) {
      _voices[v.lang] = v;
    }
  }

  void dispose() {
    stop();
    _tts.stop();
    _eventController.close();
  }
}

Future applyEngineSetting(FlutterTts tts, EngineSetting es) async {
  logger.log('set voice rate: ${es.rate}');
  await tts.setSpeechRate(es.rate);
  await tts.setPitch(es.pitch);
  if (es.volume != null) await tts.setVolume(es.volume!);

  try {
    // setLanguage must before setVoice
    await tts.setLanguage(es.language);
  } catch (e) {
    logger.log('voice setLanguage failed: $e, %v');
  }
  if (es.voice != null) await tts.setVoice(es.voice!);
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

  @override
  String toString() {
    return '${chunks.length} Chunks, $currentIndex, playing: $isPlaying, paused: $isPaused';
  }
}

class EngineNotifier extends Notifier<EngineState> {
  final Engine _engine = Engine();
  StreamSubscription? _subscription;

  @override
  EngineState build() {
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
      logger.log('engine notify enter dispose');
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

  void apply(List<EngineSetting> es) {
    _engine.apply(es);
  }
}

final engineProvider = NotifierProvider<EngineNotifier, EngineState>(
  EngineNotifier.new,
  name: 'Engine',
);
