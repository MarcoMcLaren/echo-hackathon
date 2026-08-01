// Ported from src/screens/LockScreen.tsx.
//
// The door. Nothing behind it renders until the device owner has proved who
// they are — a phone left unlocked on a table is exactly the case this
// covers.
//
// On a phone with no fingerprint or PIN set up there is nothing to verify, so
// this offers rather than insists. Turning the lock on is a deliberate tap,
// because that is the point where Android may ask the user to enrol a
// fingerprint, and no app should spring that on someone.
import 'package:flutter/material.dart';
import '../features/lock.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/type.dart';

enum _Phase {
  checking,
  prompting, // lock is on, waiting for the owner
  locked, // they declined or it failed
  offer, // lock is off — ask before creating anything
  error,
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ran) return;
    _ran = true;
    _init();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final hasHardware = await hasBiometricHardware();
    if (!mounted) return;
    setState(() => _hasHardware = hasHardware);
    if (await isLockEnabled()) {
      await _attemptUnlock();
    } else if (mounted) {
      setState(() => _phase = _Phase.offer);
    }
  }

  Future<void> _attemptUnlock() async {
    setState(() => _phase = _Phase.prompting);
    final result = await unlock();
    if (!mounted) return;
    if (result.ok) {
      widget.onUnlocked();
      return;
    }
    if (result.reason == LockFailReason.error) {
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
    final created = await enableLock();
    if (!mounted) return;
    if (!created.ok) {
      setState(() {
        _detail = created.message;
        _phase = created.reason == LockFailReason.error ? _Phase.error : _Phase.offer;
      });
      return;
    }
    await _attemptUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final still = MediaQuery.disableAnimationsOf(context);
    final busy = _phase == _Phase.checking || _phase == _Phase.prompting;
    final bad = _phase == _Phase.error;

    if (busy && !still) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }

    final heading = _phase == _Phase.offer
        ? 'Lock Echo to this phone'
        : _phase == _Phase.locked
            ? 'Locked'
            : bad
                ? 'Could not unlock'
                : 'Unlock Echo';

    final blurb = _phase == _Phase.offer
        ? (_hasHardware
            ? 'Ask for a fingerprint or face every time Echo opens, so an unlocked phone on a table is not an open inbox.'
            : 'This phone has no fingerprint or face set up, so there is nothing for Echo to check. Add a screen lock in Settings to use this.')
        : _phase == _Phase.locked
            ? 'Echo stays locked until you confirm it is you.'
            : bad
                ? 'The phone would not complete the check. Make sure a screen lock is set up, then try again.'
                : 'Use your fingerprint or face. Your messages, keys and wallet stay on this phone.';

    return Container(
      color: c.paper,
      padding: EdgeInsets.fromLTRB(28, 60, 28, MediaQuery.paddingOf(context).bottom + 24),
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
                      final opacity = (still || !busy) ? 1.0 : 0.45 + 0.55 * _pulse.value;
                      return Opacity(opacity: opacity, child: child);
                    },
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: bad ? c.direct : c.ink, width: 2)),
                      child: DisplayText('◉', size: 26, color: bad ? c.direct : c.ink),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(width: 300, child: DisplayText(heading, size: 34, textAlign: TextAlign.center)),
                  const SizedBox(height: 18),
                  SizedBox(width: 300, child: BodyText(blurb, size: 13.5, dim: Dim.two, textAlign: TextAlign.center)),
                  if (bad && _detail != null) ...[
                    const SizedBox(height: 12),
                    MonoText(_detail!.substring(0, _detail!.length.clamp(0, 90)).toUpperCase(), size: 8.5),
                  ],
                ],
              ),
            ),
          ),
          Column(
            children: [
              if (_phase == _Phase.offer && _hasHardware) _LockButton(label: 'Turn on unlock', onTap: _turnOn, filled: true),
              if (_phase == _Phase.locked || bad) _LockButton(label: 'Try again', onTap: _attemptUnlock, filled: true),
              if (_phase == _Phase.offer)
                _LockButton(label: _hasHardware ? 'Not now' : 'Continue without a lock', onTap: widget.onUnlocked, filled: false),
              const SizedBox(height: 10),
              const MonoText('HARDWARE-BACKED · KEYS NEVER LEAVE THIS PHONE', size: 8.5),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _LockButton({required this.label, required this.onTap, required this.filled});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: touchMin),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: filled ? c.ink : null,
            border: filled ? null : Border.all(color: c.hair, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DisplayText(label, size: 15, color: filled ? c.paper : null),
        ),
      ),
    );
  }
}
