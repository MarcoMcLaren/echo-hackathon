// Renders the pairing QR code shown in the tap/pair screen.
//
// Port of src/features/vault/components/QrCode.tsx. The TS version hand-rolls
// QR rendering to avoid a new native dependency; Flutter has no such
// constraint, so this wraps qr_flutter directly (already vetted and in
// pubspec.yaml).
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Always rendered dark-on-light in both themes — the code is a physical
/// thing another phone's camera has to read, so inverting it for dark mode
/// would look consistent and scan badly. Mirrors QrCode.tsx's fixed colors.
class VaultQrCode extends StatelessWidget {
  const VaultQrCode({
    super.key,
    required this.value,
    this.size = 200,
    this.quiet = 2,
  });

  final String value;
  final double size;

  /// Quiet-zone width in modules, matching QrCode.tsx's `quiet` prop.
  final int quiet;

  static const _dark = Color(0xFF0D1A16);
  static const _light = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _light,
        borderRadius: BorderRadius.circular(8),
      ),
      child: QrImageView(
        data: value,
        version: QrVersions.auto,
        size: size,
        backgroundColor: _light,
        padding: EdgeInsets.all(quiet * (size / 33)),
        gapless: true,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _dark),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: _dark,
        ),
      ),
    );
  }
}
