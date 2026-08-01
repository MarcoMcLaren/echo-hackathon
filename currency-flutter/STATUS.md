# currency-flutter — status

**Not scaffolded yet.** This folder currently holds only pre-written, spec-derived source
that drops into a real Flutter project.

| File | State |
|---|---|
| `lib/wire.dart` | Written from `spec/wire.md`. **UNVERIFIED — never executed** |
| `test/wire_test.dart` | Written. **UNVERIFIED — never executed** |
| `test/vectors.json` | Copy of `spec/vectors.json`. Copied, never linked |

## Why unverified

The machine this was authored on has **no Flutter, no Dart, no Java and no Android SDK**
(a SETUP.md "Path A" contributor box). The RN counterpart *was* executed — `wire.ts`
passes all 9 vectors under Node — but nothing here has ever run.

**Treat `wire.dart` as a first draft that compiles in someone's head.** Expect to fix
something on first run.

## First steps on a machine with Flutter

```bash
flutter create --org com.echo.currency --project-name currency_flutter .
# keep lib/wire.dart and test/ — the scaffold will not overwrite them
```

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  test: ^1.25.0
```

Then, before writing any UI:

```bash
dart test
```

**All 9 vectors must pass before channel work starts.** That is the gate — the whole
cross-framework claim rests on it, and a mismatch found now costs minutes rather than
costing the demo.

If Dart and RN disagree, `uv run spec/ref.py` decides which side has the bug.

## Then

Dependencies for the channels (see `spec/wire.md` and the channels companion):

```yaml
dependencies:
  qr_flutter: ^4.1.0        # channel 1 — encode
  mobile_scanner: ^5.2.0    # channel 1 — decode
  nearby_connections: ^4.0.0 # channel 2
  nfc_manager: ^3.5.0       # channel 4
```

Application id must differ from the RN build so both install on one phone —
that is what makes interleaved benchmarking on identical hardware possible.
