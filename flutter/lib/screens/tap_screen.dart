// Ported from src/screens/TapScreen.tsx.
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/avatar.dart';
import '../widgets/chrome.dart';
import '../widgets/qr_code.dart';
import '../widgets/type.dart';

const _core = 52.0;
const _max = 150.0;

// What the other phone reads. Same payload either way, so NFC and QR are two
// doors into one pairing flow rather than two features.
const _myPairPayload = 'echo://pair?id=rf7k2m&k=9fA2c4Be71D0&n=Reon';
const _myFingerprint = '9FA2 C4BE 71D0';

enum _Mode { tap, show, scan }

class TapScreen extends StatefulWidget {
  const TapScreen({super.key});

  @override
  State<TapScreen> createState() => _TapScreenState();
}

class _TapScreenState extends State<TapScreen> {
  _Mode mode = _Mode.tap;
  String? scanned;

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    const segs = [(id: _Mode.tap, label: 'TAP'), (id: _Mode.show, label: 'SHOW CODE'), (id: _Mode.scan, label: 'SCAN')];

    return Column(
      children: [
        MeshStatusBar(right: mode == _Mode.tap ? 'NFC READY' : 'CAMERA PAIRING'),
        const EchoAppBar(title: 'Meet a phone', sub: 'Adds a contact and swaps keys'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              for (final sg in segs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        mode = sg.id;
                        scanned = null;
                      }),
                      child: Semantics(
                        button: true,
                        selected: sg.id == mode,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 36),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(EchoRadius.pill),
                            border: Border.all(color: sg.id == mode ? c.ink : c.hair, width: 1.5),
                            color: sg.id == mode ? c.ink : Colors.transparent,
                          ),
                          child: MonoText(sg.label, size: 9, color: sg.id == mode ? c.paper : c.ink2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (mode) {
            _Mode.tap => const _TapMode(),
            _Mode.show => const _ShowMode(),
            _Mode.scan => _ScanMode(
                scanned: scanned,
                onScan: (v) => setState(() => scanned = v),
              ),
          },
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 16 + MediaQuery.paddingOf(context).bottom),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.card, border: Border.all(color: c.direct), borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Avatar(initials: 'SD', hops: 0, size: 30),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      MonoText('PAIRED WITH SIPHO DLAMINI', size: 9, dim: Dim.one),
                      MonoText('KEYS EXCHANGED · SCANNED CODE · 09:47', size: 8.5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// NFC: the fastest path when both phones have the hardware.
class _TapMode extends StatelessWidget {
  const _TapMode();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Sonar(),
            const SizedBox(height: 16),
            const SizedBox(
              width: 260,
              child: DisplayText('Hold the phones back to back', size: 28, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 270,
              child: BodyText(
                'Keep them together until both buzz. Keys are generated and stored on each phone — nothing is uploaded.',
                size: 13,
                dim: Dim.two,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const MonoText('WAITING FOR THE OTHER PHONE', size: 9),
            const SizedBox(height: 16),
            const MonoText('NO NFC ON ONE OF THEM? USE SHOW CODE', size: 9, dim: Dim.two),
          ],
        ),
      ),
    );
  }
}

/// The fallback half you hold up.
class _ShowMode extends StatelessWidget {
  const _ShowMode();

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: c.hair), borderRadius: BorderRadius.circular(12)),
              child: const QrCode(value: _myPairPayload, size: 196),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 260,
              child: DisplayText('Let the other phone scan this', size: 26, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 270,
              child: BodyText('Works on any phone with a camera. The code carries your public key, nothing else.', size: 13, dim: Dim.two, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: c.hair2), color: c.card, borderRadius: BorderRadius.circular(8)),
              child: const MonoText(_myFingerprint, size: 10, dim: Dim.one),
            ),
            const SizedBox(height: 16),
            const MonoText('CHECK THIS MATCHES ON THEIR SCREEN', size: 8.5),
          ],
        ),
      ),
    );
  }
}

/// The fallback half that reads — real camera scanning via mobile_scanner.
class _ScanMode extends StatelessWidget {
  final String? scanned;
  final ValueChanged<String> onScan;
  const _ScanMode({required this.scanned, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;

    if (scanned != null && scanned!.isNotEmpty) {
      final ok = scanned!.startsWith('echo://pair');
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: DisplayText(ok ? 'Code read' : 'That is not an Echo code', size: 28, textAlign: TextAlign.center, color: ok ? null : c.direct),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 270,
                child: BodyText(
                  ok ? 'Check the fingerprint matches what the other phone shows, then confirm.' : 'Point the camera at the code on the other phone’s Show code screen.',
                  size: 13,
                  dim: Dim.two,
                  textAlign: TextAlign.center,
                ),
              ),
              if (ok) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: c.hair2), color: c.card, borderRadius: BorderRadius.circular(8)),
                  child: const MonoText(_myFingerprint, size: 10, dim: Dim.one),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => onScan(''),
                child: Container(
                  constraints: const BoxConstraints(minHeight: touchMin),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ok ? c.ink : Colors.transparent,
                    border: ok ? null : Border.all(color: c.hair, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DisplayText(ok ? 'Add contact' : 'Scan again', size: 15, color: ok ? c.paper : c.ink),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 210,
              height: 210,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(border: Border.all(color: c.hair), borderRadius: BorderRadius.circular(14), color: Colors.black),
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final value = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
                      if (value != null) onScan(value);
                    },
                  ),
                  for (final corner in _corners) _Bracket(corner: corner, color: c.relay),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const DisplayText('Point at their code', size: 26, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const MonoText('LOOKING FOR AN ECHO CODE', size: 9),
          ],
        ),
      ),
    );
  }
}

enum _Corner { tl, tr, bl, br }

const _corners = [_Corner.tl, _Corner.tr, _Corner.bl, _Corner.br];

class _Bracket extends StatelessWidget {
  final _Corner corner;
  final Color color;
  const _Bracket({required this.corner, required this.color});

  @override
  Widget build(BuildContext context) {
    const side = BorderSide.none;
    final border = switch (corner) {
      _Corner.tl => Border(top: BorderSide(color: color, width: 3), left: BorderSide(color: color, width: 3), right: side, bottom: side),
      _Corner.tr => Border(top: BorderSide(color: color, width: 3), right: BorderSide(color: color, width: 3), left: side, bottom: side),
      _Corner.bl => Border(bottom: BorderSide(color: color, width: 3), left: BorderSide(color: color, width: 3), right: side, top: side),
      _Corner.br => Border(bottom: BorderSide(color: color, width: 3), right: BorderSide(color: color, width: 3), left: side, top: side),
    };
    final radius = switch (corner) {
      _Corner.tl => const BorderRadius.only(topLeft: Radius.circular(6)),
      _Corner.tr => const BorderRadius.only(topRight: Radius.circular(6)),
      _Corner.bl => const BorderRadius.only(bottomLeft: Radius.circular(6)),
      _Corner.br => const BorderRadius.only(bottomRight: Radius.circular(6)),
    };
    return Positioned(
      top: corner == _Corner.tl || corner == _Corner.tr ? 10 : null,
      bottom: corner == _Corner.bl || corner == _Corner.br ? 10 : null,
      left: corner == _Corner.tl || corner == _Corner.bl ? 10 : null,
      right: corner == _Corner.tr || corner == _Corner.br ? 10 : null,
      child: Container(width: 26, height: 26, decoration: BoxDecoration(border: border, borderRadius: radius)),
    );
  }
}

/// Three staggered rings — the only looping animation in the app. It says
/// "still listening", which is the one thing you need while holding two
/// phones together.
class _Sonar extends StatefulWidget {
  const _Sonar();

  @override
  State<_Sonar> createState() => _SonarState();
}

class _SonarState extends State<_Sonar> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 2600)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      for (var i = 0; i < _controllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 650), () {
          if (mounted) _controllers[i].repeat();
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final still = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      width: _max,
      height: _max,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final controller in _controllers)
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final t = still ? 1.0 : Curves.easeOut.transform(controller.value);
                final scale = still ? _max / _core : 1 + (_max / _core - 1) * t;
                final opacity = still ? 0.3 : 0.85 * (1 - t);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: _core,
                      height: _core,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.coin, width: 1.5)),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: _core,
            height: _core,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.coin),
            child: const DisplayText('NFC', size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
