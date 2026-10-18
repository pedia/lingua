import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalErrorNotifier extends Notifier<FlutterErrorDetails?> {
  @override
  FlutterErrorDetails? build() => null;

  void reportError(FlutterErrorDetails details) {
    state = details;
  }

  void clearError() {
    state = null;
  }
}

// Riverpod provider for the crash state
final globalErrorProvider =
    NotifierProvider<GlobalErrorNotifier, FlutterErrorDetails?>(
      GlobalErrorNotifier.new,
    );

class ErrorScreen extends ConsumerWidget {
  final FlutterErrorDetails errorDetails;

  const ErrorScreen({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.red[900],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚨 An unexpected crash occurred!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exception: ${errorDetails.exception}',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stack Trace:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorDetails.stack?.toString() ??
                        'No stack trace available',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Reset Riverpod error state to restore normal UI
                      ref.read(globalErrorProvider.notifier).clearError();
                    },
                    child: const Text('Dismiss & Restart'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
