// Pure-Dart QR rendering — ported from src/features/vault/components/QrCode.tsx.
// Consecutive dark modules in a row are merged into one filled rect, the same
// run-length-encode trick the RN version uses to keep the render cheap.
import 'package:flutter/material.dart';
import 'package:qr/qr.dart' as qrgen;

/// Always rendered dark-on-light, in both themes. The code is a physical
/// thing another phone's camera has to read — inverting it for dark mode
/// would look consistent and scan badly.
class QrCode extends StatelessWidget {
  final String value;
  final double size;
  final int quiet;

  const QrCode({super.key, required this.value, this.size = 200, this.quiet = 2});

  @override
  Widget build(BuildContext context) {
    final qrCode = qrgen.QrCode.fromData(data: value, errorCorrectLevel: qrgen.QrErrorCorrectLevel.M);
    final image = qrgen.QrImage(qrCode);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(size: Size(size, size), painter: _QrPainter(code: image, quiet: quiet)),
    );
  }
}

class _QrPainter extends CustomPainter {
  final qrgen.QrImage code;
  final int quiet;
  const _QrPainter({required this.code, required this.quiet});

  @override
  void paint(Canvas canvas, Size size) {
    final n = code.moduleCount;
    final total = n + quiet * 2;
    final m = size.width / total;
    final paint = Paint()..color = const Color(0xFF0D1A16);

    for (var r = 0; r < n; r++) {
      var start = -1;
      for (var col = 0; col < n; col++) {
        final on = code.isDark(r, col);
        if (on && start < 0) start = col;
        if ((!on || col == n - 1) && start >= 0) {
          final end = on && col == n - 1 ? col + 1 : col;
          canvas.drawRect(
            Rect.fromLTWH((start + quiet) * m, (r + quiet) * m, (end - start) * m, m),
            paint,
          );
          start = -1;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.code != code;
}
