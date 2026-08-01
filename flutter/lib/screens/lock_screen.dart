// The door. Nothing behind it renders until the device owner has proved who
// they are — a phone left unlocked on a table is exactly the case this
// covers.
//
// On a phone with no fingerprint or PIN set up there is nothing to verify,
// so this offers rather than insists. Turning the lock on is a deliberate
// tap, because that is the point where Android may ask the user to enrol a
// fingerprint, and no app should spring that on someone.
//
// Port of src/screens/LockScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/type.dart';
import '../features/vault/lock.dart';
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

enum _Phase {
  checking,
  prompting, // lock is on, waiting for the owner
  locked, // they declined or it failed
  offer, // lock is off — ask before creating anything
  error,
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.checking;
  String? _detail;
  bool _hasHardware = true;
  bool _ran = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Only animates while actually busy (checking/prompting), so a settled
  /// phase (offer/locked/error) never leaves a ticker running forever.
  void _syncPulse({required bool active}) {
    if (active) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  Future<void> _boot() async {
    if (_ran) return;
    _ran = true;
    final lock = context.read<AppLock>();
    final hasHardware = await lock.hasBiometricHardware();
    if (!mounted) return;
    setState(() => _hasHardware = hasHardware);

    if (await lock.isEnabled()) {
      await _attemptUnlock();
    } else if (mounted) {
      setState(() => _phase = _Phase.offer);
    }
  }

  Future<void> _attemptUnlock() async {
    if (mounted) setState(() => _phase = _Phase.prompting);
    final result = await context.read<AppLock>().unlock();
    if (!mounted) return;
    if (result.ok) {
      widget.onUnlocked();
      return;
    }
    if (result.reason == LockFailureReason.error) {
      setState(() {
        _detail = result.message;
        _phase = _Phase.error;
      });
    } else {
      setState(() => _phase = _Phase.locked);
    }
  }

  Future<void> _turnOn() async {
    setState(() => _phase = _Phase.checking);
    final created = await context.read<AppLock>().enable();
    if (!mounted) return;
    if (!created.ok) {
      setState(() {
        _detail = created.message;
        _phase = created.reason == LockFailureReason.error ? _Phase.error : _Phase.offer;
      });
      return;
    }
    await _attemptUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final busy = _phase == _Phase.checking || _phase == _Phase.prompting;
    final bad = _phase == _Phase.error;
    _syncPulse(active: !reduceMotion && busy);

    final String heading = switch (_phase) {
      _Phase.offer => 'Lock Echo to this phone',
      _Phase.locked => 'Locked',
      _Phase.error => 'Could not unlock',
      _Phase.checking || _Phase.prompting => 'Unlock Echo',
    };

    final String blurb = switch (_phase) {
      _Phase.offer => _hasHardware
          ? 'Ask for a fingerprint or face every time Echo opens, so an unlocked phone on a table is not an open inbox.'
          : 'This phone has no fingerprint or face set up, so there is nothing for Echo to check. Add a screen lock in Settings to use this.',
      _Phase.locked => 'Echo stays locked until you confirm it is you.',
      _Phase.error => 'The phone would not complete the check. Make sure a screen lock is set up, then try again.',
      _Phase.checking || _Phase.prompting => 'Use your fingerprint or face. Your messages, keys and wallet stay on this phone.',
    };

    return ColoredBox(
      color: c.paper,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final opacity = !reduceMotion && busy ? 0.45 + _pulse.value * 0.55 : 1.0;
                          return Opacity(opacity: opacity, child: child);
                        },
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: bad ? c.direct : c.ink, width: 2),
                          ),
                          child: Display('◉', size: 26, color: bad ? c.direct : c.ink),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Display(heading, size: 34, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      Body(blurb, size: 13.5, dim: 2, textAlign: TextAlign.center),
                      if (bad && _detail != null) ...[
                        const SizedBox(height: 18),
                        Mono(_detail!.substring(0, _detail!.length > 90 ? 90 : _detail!.length).toUpperCase(), size: 8.5),
                      ],
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  if (_phase == _Phase.offer && _hasHardware) ...[
                    _LockButton(label: 'Turn on unlock', onTap: _turnOn, colors: c, filled: true),
                    const SizedBox(height: 10),
                  ],
                  if (_phase == _Phase.locked || bad) ...[
                    _LockButton(label: 'Try again', onTap: _attemptUnlock, colors: c, filled: true),
                    const SizedBox(height: 10),
                  ],
                  if (_phase == _Phase.offer) ...[
                    _LockButton(
                      label: _hasHardware ? 'Not now' : 'Continue without a lock',
                      onTap: widget.onUnlocked,
                      colors: c,
                      filled: false,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Mono('HARDWARE-BACKED · KEYS NEVER LEAVE THIS PHONE', size: 8.5),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockButton extends StatelessWidget {
  const _LockButton({required this.label, required this.onTap, required this.colors, required this.filled});

  final String label;
  final VoidCallback onTap;
  final tokens.Palette colors;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: tokens.touchMin),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? c.ink : null,
            border: filled ? null : Border.all(color: c.hair, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Display(label, size: 15, color: filled ? c.paper : c.ink),
        ),
      ),
    );
  }
}
