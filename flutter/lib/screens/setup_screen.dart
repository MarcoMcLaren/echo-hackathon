// First launch. One question, because it is the only thing we cannot work
// out for ourselves: what other people should call this phone. The identity
// is minted here too, so a fresh setup is genuinely a fresh identity rather
// than the same phone wearing a new label. Port of src/screens/SetupScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/type.dart';
import '../store/mesh_store.dart';
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

const _maxNameLength = 24;

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty || _busy) return;
    setState(() => _busy = true);
    // MeshStore.ready flips true on success; main.dart swaps this screen out
    // from under the mesh, so there is nothing left to set local state on.
    await context.read<MeshStore>().createIdentity(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final trimmed = _name.text.trim();
    final ok = trimmed.isNotEmpty && !_busy;

    return Material(
      color: c.paper,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(26, 32, 26, 24 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Mono('SET UP ECHO', size: 10),
                      const SizedBox(height: 10),
                      const Display('What should people call you?', size: 40),
                      const SizedBox(height: 14),
                      Body(
                        'This is the name on your pairing code, and the name in other '
                        'people’s chats. Nothing leaves this phone until you tap or scan '
                        'with someone.',
                        size: 14,
                        dim: 2,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _name,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _go(),
                        maxLength: _maxNameLength,
                        style: TextStyle(color: c.ink, fontSize: 20),
                        decoration: InputDecoration(
                          hintText: 'Your name',
                          hintStyle: TextStyle(color: c.ink3),
                          counterText: '',
                          filled: true,
                          fillColor: c.card,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                            borderSide: BorderSide(color: c.hair, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                            borderSide: BorderSide(color: c.hair, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Mono('${trimmed.length}/$_maxNameLength', size: 8.5),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    enabled: ok,
                    label: _busy ? 'Setting up' : 'Start',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: ok ? _go : null,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: tokens.touchMin),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ok ? c.ink : c.sunk,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Display(
                          _busy ? 'Setting up…' : 'Start',
                          size: 16,
                          color: ok ? c.paper : c.ink3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Mono(
                    'A NEW KEY IS MADE FOR THIS PHONE AND NEVER LEAVES IT',
                    size: 8.5,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
