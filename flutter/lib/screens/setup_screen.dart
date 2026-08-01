// Ported from src/screens/SetupScreen.tsx.
//
// First launch. One question, because it is the only thing we cannot work
// out for ourselves: what other people should call this phone. The id is
// minted here too (by the store's createIdentity, wired by a later pass), so
// a fresh setup is genuinely a fresh identity rather than the same phone
// wearing a new label.
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/type.dart';

const _max = 24;

class SetupScreen extends StatefulWidget {
  final Future<void> Function(String name) onCreate;
  const SetupScreen({super.key, required this.onCreate});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();
  bool get _ok => _trimmed.isNotEmpty && !_busy;

  Future<void> _go() async {
    if (!_ok) return;
    setState(() => _busy = true);
    await widget.onCreate(_trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final ok = _ok;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      color: c.paper,
      padding: EdgeInsets.fromLTRB(26, 90, 26, keyboardInset),
      child: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoText('SET UP ECHO'.toUpperCase(), size: 10),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 330,
                  child: DisplayText('What should people call you?', size: 40, style: TextStyle(height: 1.05)),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 330,
                  child: BodyText(
                    'This is the name on your pairing code, and the name in other people’s chats. Nothing '
                    'leaves this phone until you tap or scan with someone.',
                    size: 14,
                    dim: Dim.two,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.hair, width: 1.5),
                    borderRadius: BorderRadius.circular(EchoRadius.card),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _controller,
                    maxLength: _max,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _go(),
                    style: TextStyle(fontSize: 20, color: c.ink, fontFamily: EchoFont.body),
                    cursorColor: c.ink,
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: TextStyle(color: c.ink3, fontSize: 20),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                MonoText('${_trimmed.length}/$_max', size: 8.5),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset + 24),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  enabled: ok,
                  label: _busy ? 'Setting up…' : 'Start',
                  child: GestureDetector(
                    onTap: ok ? _go : null,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: touchMin),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(color: ok ? c.ink : c.sunk, borderRadius: BorderRadius.circular(10)),
                      child: DisplayText(_busy ? 'Setting up…' : 'Start', size: 16, color: ok ? c.paper : c.ink3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const MonoText('A NEW KEY IS MADE FOR THIS PHONE AND NEVER LEAVES IT', size: 8.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
