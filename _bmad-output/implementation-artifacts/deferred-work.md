# Deferred work

Findings surfaced by review that are real but out of scope for the spec that
found them. Append-only.

- source_spec: `spec-ocr-read-that.md`
  summary: Node globals (`Buffer`, `process`, `__dirname`) typecheck cleanly inside `src/`, so app code can reference them and only fail at runtime under Hermes.
  evidence: Pre-existing — an unset `types` field also pulled in `@types/node`. Iteration 1 pinned `types: ["node", "react"]` to make the tests typecheck, which keeps the leak. A separate tsconfig scoping `node` types to `test/` only would close it without losing test coverage.

- source_spec: `spec-ocr-read-that.md`
  summary: Every capture writes a JPEG to the cache directory and nothing ever deletes it.
  evidence: `ReadScreen` calls `takePictureAsync` per tap and uses only `shot.uri`; there is no cleanup on success, failure or unmount. Unbounded growth across a long demo session. Fix is a `FileSystem.deleteAsync(uri, { idempotent: true })` in the `finally`.

- source_spec: `spec-ocr-read-that.md`
  summary: A wedged camera HAL or stalled inference leaves the button reading "Reading…" forever with no recovery.
  evidence: `onRead` awaits `takePictureAsync` and `read()` with no timeout. If either never settles, `capturing` stays true, the nav stays locked, and nothing is spoken. Needs a `Promise.race` timeout plus a spoken failure.

- source_spec: `spec-voice-dictation-messaging.md`
  summary: Backing out of a chat mid-transcription lets executorch delete the Whisper module while native inference is still running.
  evidence: `useDictation` guards the state update after unmount but nothing defers `useSpeechToText`'s effect cleanup, which calls `moduleInstance.delete()` on unmount. The OCR story hit the identical hazard and solved it by locking navigation while busy (`Chrome.tsx` `BottomNav disabled`), but chat is a route reached via `App.tsx`'s `BackHandler`, so the same remedy needs a decision about what the back button does mid-transcribe.

- source_spec: `spec-voice-dictation-messaging.md`
  summary: A locked hands-free take keeps recording when the app is backgrounded or the screen locks, and Android silently feeds it silence.
  evidence: `app.json` sets `androidForegroundService: false` — correct while the finger holds the button, but locked mode deliberately outlives the finger. Nothing observes `AppState`, so a locked take can run to the 29 s ceiling and transcribe nothing. Either observe `AppState` and stop the take, or enable the foreground service with `androidFSTypes: ['microphone']` (which needs a new APK).

- source_spec: `spec-voice-dictation-messaging.md`
  summary: An incoming call or other audio-focus loss during a take is not observed, so the take continues over dead input.
  evidence: `react-native-audio-api` exposes `AudioManager.observeAudioInterruptions` and an `interruption` system event; `DictationRecorder` subscribes to neither. `rec.onError` only fires if the native recorder itself reports a fault, which focus loss does not guarantee.

- source_spec: `spec-voice-dictation-messaging.md`
  summary: `scripts/fix-audio-api-bash-path.js` reconstructs the Gradle line from a memorised argument list, so a compatible upstream release could be silently reverted to stale arguments.
  evidence: The finder matches only on `commandLine` + `bash.exe` + `download-prebuilt-binaries.sh`, then rewrites the line with hardcoded args. `package.json` pins `^0.13.2`, so a minor bump that changes those args still matches and gets rewritten. It also assumes single-quoted Groovy strings. Worth an assertion on the arguments it expects to replace.

- source_spec: `spec-voice-dictation-messaging.md`
  summary: Nothing in `package.json` runs the unit tests — both `test/ocr.test.ts` and `test/dictation.test.ts` are runnable only by copying the command out of a file header.
  evidence: Pre-existing; `scripts` is `start`/`android`/`ios`/`web`/`postinstall`. The dictation tests exist specifically to pin Whisper's native constants against silent drift, which is exactly the thing a CI-runnable `npm test` protects.

- source_spec: `spec-ocr-read-that.md`
  summary: `ReadResult.boxes` is returned but never consumed — no bounding-box overlay on the preview.
  evidence: `ReadScreen` discards `outcome.result.boxes`. Harmless, but the design spec's demo moment describes drawing detection boxes "for the audience", so this is the hook for that feature rather than dead code to delete.
