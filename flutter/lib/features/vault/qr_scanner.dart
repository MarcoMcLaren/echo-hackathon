// The camera side of pairing: reads the QR the other phone is showing.
//
// Kept behind a small interface rather than importing mobile_scanner
// directly into TapScreen, so widget tests can fake the camera feed with a
// plain tappable placeholder instead of touching a platform camera — the
// same mock-first split used elsewhere in features/vault and features/ai.
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

abstract class QrScanner {
  /// A camera preview that calls [onDetect] with the raw text of each QR
  /// code it reads. May fire more than once for the same code while the
  /// preview stays mounted — callers decide what to do with a repeat.
  Widget preview({required ValueChanged<String> onDetect});
}

class MobileScannerQrScanner implements QrScanner {
  @override
  Widget preview({required ValueChanged<String> onDetect}) {
    return scanner.MobileScanner(
      onDetect: (capture) {
        final barcodes = capture.barcodes;
        if (barcodes.isEmpty) return;
        final value = barcodes.first.rawValue;
        if (value != null) onDetect(value);
      },
    );
  }
}
