// Shake to take it back.
//
// Every action a shake triggers must also have a visible control. A shake is
// undiscoverable, and unusable for anyone who cannot shake a phone — it is a
// shortcut for people who already know it exists, never the only way through.
//
// Port intent of src/hooks/useShake.ts (expo-sensors' Accelerometer,
// magnitude over a threshold with a cooldown). The real implementation reads
// the platform accelerometer; this defines the contract [ShakeService] a
// native adapter must satisfy and a fake a test or screen can trigger
// directly, with no sensor dependency.
import 'dart:async';

abstract class ShakeService {
  /// Starts listening. Safe to call more than once — a real adapter no-ops
  /// while already running.
  void start();

  /// Stops listening and releases whatever the adapter is holding.
  void stop();

  /// Fires once per shake gesture, after the adapter's own debounce.
  Stream<void> get onShake;
}

/// Headless fake: nothing reads the accelerometer. Tests (and a screen under
/// development) call [fire] to simulate a shake directly.
class MockShakeService implements ShakeService {
  final _controller = StreamController<void>.broadcast();
  bool running = false;

  @override
  void start() => running = true;

  @override
  void stop() => running = false;

  @override
  Stream<void> get onShake => _controller.stream;

  /// Simulates one shake gesture. No-ops while [stop]ped, matching a real
  /// sensor adapter that stops delivering events once told to stop.
  void fire() {
    if (!running) return;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
