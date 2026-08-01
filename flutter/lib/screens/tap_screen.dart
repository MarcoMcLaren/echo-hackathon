// Port of src/screens/TapScreen.tsx.
//
// ShowMode's QR payload is generated from the real SecureVault adapter
// (features/vault/vault.dart) rather than a hardcoded constant, so the pairing
// flow actually proves out "keys never leave the device, only the public key
// travels". It also carries this phone's mesh deviceId (`id=`), which is what
// MeshStore.pair() needs to actually create a conversation — the vault key
// alone identifies the crypto, not the mesh peer. ScanMode reads the camera
// through the [QrScanner] adapter rather than importing mobile_scanner
// directly, so it can be faked in widget tests.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/chrome.dart' show MeshStatus, EchoAppBar;
import '../components/type.dart';
import '../features/vault/qr_code.dart';
import '../features/vault/qr_scanner.dart';
import '../features/vault/reset_sheet.dart';
import '../features/vault/vault.dart';
import '../store/mesh_store.dart';
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

enum _Mode { tap, show, scan }

/// What the other phone reads. Same payload either way, so NFC and QR are
/// two doors into one pairing flow rather than two features.
({String id, String key, String name})? _readPairPayload(String raw) {
  if (!raw.startsWith('echo://pair')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final id = uri.queryParameters['id'];
  final key = uri.queryParameters['k'];
  if (id == null || key == null) return null;
  final name = uri.queryParameters['n'];
  return (id: id, key: key, name: (name == null || name.isEmpty) ? id : name);
}

class TapScreen extends StatefulWidget {
  const TapScreen({super.key});

  @override
  State<TapScreen> createState() => _TapScreenState();
}

class _TapScreenState extends State<TapScreen> {
  _Mode _mode = _Mode.tap;
  String? _scanned;
  bool _confirmReset = false;

  static const _segs = [(_Mode.tap, 'TAP'), (_Mode.show, 'SHOW CODE'), (_Mode.scan, 'SCAN')];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mesh = context.watch<MeshStore>();
    final reachable = mesh.peers.length;

    return Stack(
      children: [
        Column(
          children: [
            MeshStatus(right: _mode == _Mode.tap ? 'NFC READY' : 'CAMERA PAIRING'),
            const EchoAppBar(title: 'Meet a phone', sub: 'Adds a contact and swaps keys'),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  for (final (id, label) in _segs)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Segment(
                          label: label,
                          selected: id == _mode,
                          colors: c,
                          onTap: () => setState(() {
                            _mode = id;
                            _scanned = null;
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: switch (_mode) {
                _Mode.tap => const _TapMode(),
                _Mode.show => const _ShowMode(),
                _Mode.scan => _ScanMode(
                  scanned: _scanned,
                  onScan: (v) => setState(() => _scanned = v),
                ),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border.all(color: c.hair2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Mono(
                            'YOU ARE ${mesh.me.display.toUpperCase()} · ${_fingerprint(mesh.me.deviceId)}',
                            size: 9,
                            dim: 1,
                          ),
                          Mono('${mesh.contacts.length} CONTACTS · $reachable NODES IN RANGE', size: 8.5),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Reset this phone',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => setState(() => _confirmReset = true),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: tokens.touchMin, minHeight: tokens.touchMin),
                          alignment: Alignment.center,
                          child: Mono('RESET', size: 9, color: c.direct),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_confirmReset)
          ResetSheet(
            onCancel: () => setState(() => _confirmReset = false),
            onConfirm: () {
              setState(() => _confirmReset = false);
              mesh.resetApp();
            },
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.colors, required this.onTap});

  final String label;
  final bool selected;
  final tokens.Palette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.ink : Colors.transparent,
            border: Border.all(color: selected ? c.ink : c.hair, width: 1.5),
            borderRadius: BorderRadius.circular(tokens.AppRadius.pill),
          ),
          child: Mono(label, size: 9, color: selected ? c.paper : c.ink2),
        ),
      ),
    );
  }
}

const _core = 52.0;
const _max = 150.0;

/// NFC: the fastest path when both phones have the hardware.
class _TapMode extends StatelessWidget {
  const _TapMode();

  @override
  Widget build(BuildContext context) {
    return const _Zone(
      children: [
        _Sonar(),
        SizedBox(height: 16),
        Display('Hold the phones back to back', size: 28, textAlign: TextAlign.center),
        SizedBox(height: 16),
        Body(
          'Keep them together until both buzz. Keys are generated and stored on each phone — nothing is uploaded.',
          size: 13,
          dim: 2,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        Mono('WAITING FOR THE OTHER PHONE', size: 9),
        SizedBox(height: 4),
        Mono('NO NFC ON ONE OF THEM? USE SHOW CODE', size: 9, dim: 2),
      ],
    );
  }
}

/// The fallback half you hold up, keyed by this device's real vault public
/// key so the QR carries an actual (mock) key rather than a fixture string.
class _ShowMode extends StatefulWidget {
  const _ShowMode();

  @override
  State<_ShowMode> createState() => _ShowModeState();
}

class _ShowModeState extends State<_ShowMode> {
  late final Future<String> _publicKey;

  @override
  void initState() {
    super.initState();
    _publicKey = context.read<SecureVault>().setUp();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final me = context.read<MeshStore>().me;

    return FutureBuilder<String>(
      future: _publicKey,
      builder: (context, snapshot) {
        final key = snapshot.data;
        if (key == null) {
          return const _Zone(children: [Mono('GENERATING KEYS ON THIS PHONE', size: 10)]);
        }
        // The vault key proves this phone's crypto identity; the deviceId is
        // what MeshStore.pair() needs to actually create a conversation —
        // the two are not (yet) the same value.
        final payload =
            'echo://pair?id=${Uri.encodeComponent(me.deviceId)}&k=$key&n=${Uri.encodeComponent(me.display)}';
        return _Zone(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: c.hair), borderRadius: BorderRadius.circular(12)),
              child: VaultQrCode(value: payload, size: 196),
            ),
            const SizedBox(height: 16),
            const Display('Let the other phone scan this', size: 26, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Body(
              'Works on any phone with a camera. The code carries who this phone is, nothing else.',
              size: 13,
              dim: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: c.hair2),
                color: c.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Mono(_fingerprint(key), size: 10, dim: 1),
            ),
            const SizedBox(height: 8),
            const Mono('CHECK THIS MATCHES ON THEIR SCREEN', size: 8.5),
          ],
        );
      },
    );
  }
}

/// Not a real cryptographic fingerprint — the mock vault's key isn't hex — but
/// chunked the same way so the "compare these on both screens" affordance
/// still reads correctly.
String _fingerprint(String key) {
  final upper = key.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  final tail = upper.length > 12 ? upper.substring(upper.length - 12) : upper.padLeft(12, '0');
  final groups = <String>[];
  for (var i = 0; i < tail.length; i += 4) {
    groups.add(tail.substring(i, math.min(i + 4, tail.length)));
  }
  return groups.join(' ');
}

/// The fallback half that reads. The camera comes from [QrScanner] — a real
/// preview on device, a tappable placeholder under test — so a detected
/// payload always arrives through the same [onScan] callback either way.
class _ScanMode extends StatelessWidget {
  const _ScanMode({required this.scanned, required this.onScan});

  final String? scanned;
  final ValueChanged<String> onScan;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mesh = context.watch<MeshStore>();

    if (scanned != null) {
      final theirs = _readPairPayload(scanned!);
      final ok = theirs != null;
      final alreadyPaired = ok && mesh.contacts.containsKey(theirs.id);
      return _Zone(
        children: [
          Display(
            ok ? theirs.name : 'That is not an Echo code',
            size: 28,
            textAlign: TextAlign.center,
            color: ok ? c.ink : c.direct,
          ),
          const SizedBox(height: 16),
          Body(
            ok
                ? 'Check this fingerprint matches the one on their screen, then confirm.'
                : 'Point the camera at the code on the other phone’s Show code screen.',
            size: 13,
            dim: 2,
            textAlign: TextAlign.center,
          ),
          if (ok) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: c.hair2),
                color: c.card,
                borderRadius: BorderRadius.circular(8),
              ),
              // Theirs, not ours — comparing our own code to itself proves
              // nothing.
              child: Mono(_fingerprint(theirs.key), size: 10, dim: 1),
            ),
          ],
          if (alreadyPaired) ...[
            const SizedBox(height: 8),
            Mono('ALREADY IN YOUR CONTACTS', size: 8.5, color: c.relay),
          ],
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: ok ? 'Add contact' : 'Scan again',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                // Scanning the code is the whole point: it is what turns a
                // phone that was merely in range into someone you can talk
                // to.
                if (theirs != null) mesh.pair(theirs.id, theirs.name);
                onScan('');
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: ok ? c.ink : Colors.transparent,
                  border: ok ? null : Border.all(color: c.hair, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Display(ok ? 'Add contact' : 'Scan again', size: 15, color: ok ? c.paper : c.ink),
              ),
            ),
          ),
        ],
      );
    }

    return _Zone(
      children: [
        Container(
          width: 210,
          height: 210,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: c.hair),
            borderRadius: BorderRadius.circular(14),
          ),
          child: context.read<QrScanner>().preview(onDetect: onScan),
        ),
        const SizedBox(height: 16),
        const Display('Point at their code', size: 26, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Mono('LOOKING FOR AN ECHO CODE', size: 9),
      ],
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

class _SonarState extends State<_Sonar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: tokens.AppMotion.sonar)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      width: _max,
      height: _max,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (reduceMotion)
            Opacity(
              opacity: 0.3,
              child: Container(
                width: _max,
                height: _max,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.coin, width: 1.5)),
              ),
            )
          else
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++) _ring(i, c),
                  ],
                );
              },
            ),
          Container(
            width: _core,
            height: _core,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.coin),
            child: const Display('NFC', size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _ring(int i, tokens.Palette c) {
    final stagger = tokens.AppMotion.sonarStagger.inMilliseconds / tokens.AppMotion.sonar.inMilliseconds;
    final phase = (_controller.value + i * stagger) % 1.0;
    final scale = 1 + phase * (_max / _core - 1);
    final opacity = 0.85 * (1 - phase);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: _core,
          height: _core,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.coin, width: 1.5)),
        ),
      ),
    );
  }
}

/// Centers its content, but scrolls rather than overflows on a short viewport
/// (a small phone in landscape, or this suite's fixed test surface).
class _Zone extends StatelessWidget {
  const _Zone({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
