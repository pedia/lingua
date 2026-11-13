import 'dart:async';

void main() {
  // Even with a broadcast controller, if a listener blocks the event/microtask loop,
  // or if re-entrancy occurs, execution freezes.
  final streamController = StreamController<int>.broadcast();

  // A rogue listener that enters an infinite loop or heavy blocking operation
  streamController.stream.listen((event) {
    print('Listener received: $event');

    // TRAP: This infinite synchronous loop traps the execution thread
    // right when the event is processed!
    while (true) {
      // Doing heavy work or getting stuck here prevents the main stack from returning
    }
  });

  print('1');

  // When you call add(1), the controller schedules/dispatches the event.
  // If a listener locks up the execution thread synchronously or via microtasks,
  // control never returns to the next line.
  streamController.add(1);

  print('2'); // <-- This will NEVER be reached!
}
