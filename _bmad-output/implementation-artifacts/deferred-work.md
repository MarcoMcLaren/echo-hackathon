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

- source_spec: `spec-ocr-read-that.md`
  summary: `ReadResult.boxes` is returned but never consumed — no bounding-box overlay on the preview.
  evidence: `ReadScreen` discards `outcome.result.boxes`. Harmless, but the design spec's demo moment describes drawing detection boxes "for the audience", so this is the hook for that feature rather than dead code to delete.
