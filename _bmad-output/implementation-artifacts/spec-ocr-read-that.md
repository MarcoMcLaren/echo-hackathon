---
title: 'OCR "Read that" — point, tap, hear the text'
type: 'feature'
created: '2026-08-01'
status: 'done'
baseline_commit: '813846ef5df79627f6f3e7de5b2c4b7a2897ead4'
review_loop_iteration: 1
context:
  - '{project-root}/docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Echo's headline accessibility beat — point at a sign, tap, hear it read aloud — is a 4-line placeholder (`useReadText` returns `{}`). Nothing in the app reaches the camera or the OS speech engine, so the OCR pillar cannot be demoed.

**Approach:** Add a "Read" tab: rear-camera preview, one large capture button, `expo-camera` snapshot → executorch `useOCR().forward(uri)` → detections sorted into reading order → spoken via `expo-speech`, with a haptic tick on capture and a success/failure notification. Offline, pure JS, no new native dependency — so no new APK.

## Boundaries & Constraints

**Always:**
- Pure JS on the **existing** dev client. `expo-camera`, `expo-speech`, `expo-haptics` and `react-native-executorch` are already in `package.json`, and `expo-camera` is already a plugin in `app.json` with a permission string. A new native dep would invalidate every teammate's APK.
- Reading-order and text-composition logic stays **pure** in `src/utils/ocr.ts` — no RN, Expo or executorch imports — and is unit-tested.
- Guard every `forward()` on `isReady && !isGenerating`: in executorch 0.9.2 it **throws** when the models are unloaded or already processing.
- Speech is the primary output, the on-screen transcript secondary. Every control has an `accessibilityLabel` and clears `TOUCH_MIN` (48dp).
- Reuse existing tokens (`useTheme`, `space`, `TOUCH_MIN`) and the `Display`/`Mono` components. No new colours.
- Capture silently: `shutterSound: false`, `animateShutter={false}`.

**Ask First:**
- Adding any npm dependency, including a test runner.
- Altering or removing an existing `App.tsx` route or `BottomNav` tab.
- Changing the OCR language away from `OCR_ENGLISH`.

**Never:**
- **React Native only** — the root Expo 57 / RN 0.86.2 project under `src/`. Do not touch `currency-flutter/` or `currency-rn/`; do not create a new project.
- No object detection, proximity haptics, or LLM scene description — separate stories.
- No runtime network calls.
- No `skipProcessing: true` — on Android it skips EXIF rotation, handing OCR a sideways image.
- No continuous or automatic capture loop; capture is user-initiated only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Happy path | Model ready, sign in frame, tap Read | Haptic tick; detections ≥0.5 sorted into reading order, joined, spoken and shown | N/A |
| No text found | No text in frame, or every detection <0.5 | Speaks "No text found."; transcript shows the same | N/A |
| Model still loading | `isReady === false` | Button disabled, labelled "Loading model NN%" from `downloadProgress` | N/A |
| Double tap | `isGenerating === true` | Second tap ignored; no second `forward()` | Guard prevents the throw |
| Permission missing | `useCameraPermissions` not granted | Preview replaced by explanation + "Allow camera" button | Permanently denied → text directing user to system settings |
| Capture or OCR failure | `forward` rejects, or hook `error` set | Failure haptic; speaks "Couldn't read that."; transcript shows the message | Caught; state reset so button re-enables |
| Text over TTS limit | Composed text > `Speech.maxSpeechInputLength` | Truncated at a word boundary before speaking | N/A |
| Tab switched mid-read | User taps another tab while generating | Tab switching is blocked until the read settles; no state update or speech after unmount | Nav disabled while busy, so `useOCR` cleanup can never call `delete()` mid-generation — it throws `ModelGenerating`. A mounted ref additionally suppresses late feedback. *(Amended iteration 1: the original "cancelled via a mounted ref" is provably insufficient — a ref cannot stop a synchronous throw in effect cleanup.)* |
| Model fails to load | `useOCR` reports `error`, or the resource fetcher was never initialised | Failure haptic + spoken "Reader unavailable"; a Retry control remounts the reader | Never render "Loading model 0%" while `error` is set |

</frozen-after-approval>

## Code Map

- `src/features/ai/hooks/useReadText.ts` — the 4-line placeholder to replace.
- `src/services/models/index.ts` — imports `OCR_ENGLISH` and, at module scope, calls `initExecutorch()`. **This module must be imported for its side effect** (`src/App.tsx` does so); `ModelPreloadScreen` is the only other importer and nothing mounts it, so relying on that screen leaves the fetcher unregistered and every load fails silently.
- `src/components/Chrome.tsx:90` — `Tab` union + `BottomNav` items; needs a 4th entry.
- `src/App.tsx:15-71` — hand-rolled tab switch, renders only the active tab (so OCR loads lazily on tab open).
- `src/styles/theme.ts` / `src/components/Type.tsx` — `useTheme`, `space`, `TOUCH_MIN`; `Display`, `Mono`.
- `currency-rn/test/wire.test.ts` — test convention to copy (`node:test`, explicit `.ts` import extensions).

## Tasks & Acceptance

**Execution:**
- [x] `src/features/ai/types/index.ts` — declare `TextBox` (`{ bbox: {x1,y1,x2,y2}; text: string; score: number }`) and the read-state type, structurally compatible with executorch's `OCRDetection` so `utils/ocr.ts` needs no library import.
- [x] `src/utils/ocr.ts` — pure `toReadingOrder(boxes)` (group into lines by vertical overlap; lines top→bottom, boxes left→right) and `composeSpeech(boxes, { minScore, maxChars })` returning the joined string or `''`.
- [x] `test/ocr.test.ts` — cover the pure-logic Matrix rows: ordering, score filter, empty result, word-boundary truncation.
- [x] `src/features/feedback/api/index.ts` — `speak(text)` (stops any current utterance first), `stopSpeaking()`, `tick()`, `notifyOk()`, `notifyFail()` over expo-speech / expo-haptics.
- [x] `src/features/ai/hooks/useReadText.ts` — wrap `useOCR({ model: OCR_ENGLISH })`; expose `{ isReady, isBusy, downloadProgress, error, transcript, read(uri) }`; guard and cancel per Boundaries.
- [x] `src/screens/ReadScreen.tsx` — `CameraView` preview, permission gate, full-width capture button, transcript panel, status line; calls `read()` then the feedback API.
- [x] `src/components/Chrome.tsx` — extend `Tab` with `'read'`, add the nav item (glyph `⌾`, label `READ`).
- [x] `src/App.tsx` — render `ReadScreen` when `tab === 'read'`, leaving existing routes untouched.
- [x] `src/screens/index.ts`, `src/utils/index.ts` — export the new surface through the barrels.
- [x] `tsconfig.json` — unplanned but required by the approved Verification section: add `allowImportingTsExtensions` and `types: ["node", "react"]`. No new dependency (`@types/node` was already installed transitively); this also repairs the pre-existing `currency-rn/test/wire.test.ts` typecheck failure that predates this story.

**Remediation (iteration 1 — blocking first):**
- [x] `src/App.tsx` or `src/services/models/index.ts` — guarantee `initExecutorch` runs before any `useOCR` mounts. Importing the models service for its module-scope side effect is enough; do not rely on `ModelPreloadScreen`, which nothing mounts.
- [x] `src/screens/ReadScreen.tsx` + `useReadText` — pass `preventLoad` so the ~50 MB detector+recognizer only load once camera permission is granted, and keep the screen from unmounting mid-read (or otherwise prevent `controller.delete()` firing while `isGenerating`).
- [x] `src/screens/ReadScreen.tsx` — speak and buzz on model-load/download failure; never render "Loading model 0%" while `error` is set; expose a retry.
- [x] `src/features/ai/hooks/useReadText.ts` — serialise reads with a `useRef` latch, not render-time state, so two taps in one batch cannot both reach `forward()`.
- [x] `src/screens/ReadScreen.tsx` — suppress haptic/speech feedback when the read resolved after unmount; gate the button on `onCameraReady`, handle `onMountError`, and handle a null camera ref.
- [x] `src/features/feedback/api/index.ts` — fix `maxSpeechChars` (`Number.isFinite(Number.MAX_VALUE)` is `true`, so the current guard never fires) and surface `Speech.speak`'s `onError`.
- [x] `src/utils/ocr.ts` + `test/ocr.test.ts` — group lines against the running line extent instead of the first box, and normalise/drop degenerate bboxes (`y2 <= y1`). Add regression tests for mixed-height signage and inverted boxes.
- [x] `src/screens/ReadScreen.tsx` — treat an empty error string as no error; clear the previous transcript when a new read starts.
- [x] `src/App.tsx` — make the final branch an explicit `tab === 'read'` test rather than a catch-all `else`.

**Acceptance Criteria:**
- Given a physical arm64 device with vision models cached, when the user opens the Read tab, then the preview appears and the capture button enables once the model reports ready.
- Given airplane mode with models cached, when the user taps Read at printed text, then the text is spoken aloud — proving the offline path.
- Given the existing Reach / Wallet / Meet tabs, when the Read tab is added, then all three still render and navigate exactly as before.

## Spec Change Log

### Iteration 1 — review findings (Blind Hunter + Edge Case Hunter)

**Triggering finding (blocking):** the feature could never work. `initExecutorch({ resourceFetcher: ExpoResourceFetcher })` sits at module scope in `src/services/models/index.ts`, whose only importer is `ModelPreloadScreen` — which nothing mounts. Verified in the installed library: `initExecutorch` is the sole caller of `ResourceFetcher.setAdapter`, there is no default adapter, `getAdapter()` throws, and `BaseOCRController.internalLoad` catches exactly `ResourceFetcherAdapterNotInitialized` and calls only `Logger.error` — it never invokes `errorCallback`. Result: `isReady` false, `error` null, `downloadProgress` 0, permanently. The Read tab would sit on "Loading model 0%" forever with no error, no haptic and no speech.

**Known-bad state avoided:** a spec whose Code Map assumed model availability was already solved by `ModelPreloadScreen`, with no task making the ExecuTorch resource fetcher a precondition of mounting `useOCR`.

**Second blocking finding:** the frozen Matrix row "Tab switched mid-read" prescribes "Cancelled via a mounted ref". Verified insufficient: `useOCR`'s unmount cleanup calls `controller.delete()`, which throws `ModelGenerating` when a read is in flight. A mounted ref only suppresses `setState`; it cannot stop a synchronous throw inside effect cleanup, and there is no error boundary in `App.tsx`. **This remedy sits inside `<frozen-after-approval>` and needs human amendment.**

**KEEP (must survive re-derivation):**
- The pinned 0.9.2 contract: `useOCR({ model: OCR_ENGLISH })`, `forward(uri) → Promise<OCRDetection[]>`, `forward` throws on both `!isReady` (`ModuleNotLoaded`) and `isGenerating` (`ModelGenerating`). Confirmed against the installed source.
- Pure `src/utils/ocr.ts` with zero runtime imports, unit-tested under `node --experimental-strip-types`. The 9 existing tests all pass and must keep passing.
- `skipProcessing` stays off (Android EXIF rotation), `shutterSound: false`, `animateShutter={false}`.
- The `tsconfig.json` repair: `allowImportingTsExtensions` plus a `types` pin is the *only* combination that typechecks the tests — `allowImportingTsExtensions` alone still fails with TS2591. This also fixed the pre-existing `currency-rn` breakage.
- Reuse of existing chrome (`MeshStatus`, `AppBar`, `Display`/`Mono`, theme tokens) rather than new UI primitives.

**Amendments (new tasks added below, unchecked):** initialise the resource fetcher; gate loading with `preventLoad`; serialise taps with a ref rather than React state; speak model-load failures; correct the `maxSpeechChars` guard; anchor line-grouping on the running line extent; handle degenerate bboxes; suppress post-unmount feedback.

## Design Notes

Reading order, not detector order: boxes arrive in model order, so speaking them unsorted scrambles the text. Group boxes into a line when their vertical extents overlap by more than half the shorter box's height, then sort lines by `y1` and boxes within a line by `x1`.

```ts
const sameLine = (a: Bbox, b: Bbox) => {
  const overlap = Math.min(a.y2, b.y2) - Math.max(a.y1, b.y1);
  return overlap > 0.5 * Math.min(a.y2 - a.y1, b.y2 - b.y1);
};
```

## Verification

**Commands:**
- `npm install` — succeeds and runs the `scripts/fix-nearby-prefab.js` postinstall. `node_modules` is currently absent, so this precedes the checks below.
- `node --experimental-strip-types --test test/ocr.test.ts` — all pure-logic tests pass.
- `npx tsc --noEmit` — no errors.

**Manual checks (physical arm64 device, dev client):**
- Read tab: preview renders; button shows "Loading model NN%" then enables.
- Tap at printed text → haptic tick, then spoken transcript matching the screen.
- Airplane mode with cached models → identical behaviour.
- Blank wall → speaks "No text found."

## Suggested Review Order

**Why it works at all (start here)**

- The one-line side effect that registers the ExecuTorch fetcher; without it every load hangs silently.
  [`App.tsx:16`](../../src/App.tsx#L16)

- `initExecutorch()` at module scope — the only caller of `setAdapter` in the whole app.
  [`models/index.ts:15`](../../src/services/models/index.ts#L15)

**The read pipeline**

- Orchestrates tick → capture → OCR → speak, and stays silent if the user left mid-read.
  [`ReadScreen.tsx:144`](../../src/screens/ReadScreen.tsx#L144)

- Ref latch, not React state: two taps in one batch would both pass a state guard.
  [`useReadText.ts:65`](../../src/features/ai/hooks/useReadText.ts#L65)

- `preventLoad` keeps ~50 MB of models out of RAM until the camera is actually usable.
  [`useReadText.ts:40`](../../src/features/ai/hooks/useReadText.ts#L40)

- Post-unmount guard — the difference between silence and talking over the next screen.
  [`ReadScreen.tsx:170`](../../src/screens/ReadScreen.tsx#L170)

**Reading order (pure, unit-tested)**

- Height-ratio guard: stops a tall heading swallowing the rows above and below it.
  [`ocr.ts:24`](../../src/utils/ocr.ts#L24)

- Normalises inverted/zero-height boxes, then groups by vertical overlap.
  [`ocr.ts:45`](../../src/utils/ocr.ts#L45)

- Lines top-to-bottom, boxes left-to-right — detector order alone reads as gibberish.
  [`ocr.ts:65`](../../src/utils/ocr.ts#L65)

**Eyes-free feedback**

- `Number.isFinite(Number.MAX_VALUE)` is true, so only a safe-integer check works here.
  [`feedback/api:17`](../../src/features/feedback/api/index.ts#L17)

- Speech can fail silently; buzz the failure so a success haptic is never a lie.
  [`feedback/api:44`](../../src/features/feedback/api/index.ts#L44)

- Speaks model-load failure once — red text alone is useless to a blind user.
  [`ReadScreen.tsx:132`](../../src/screens/ReadScreen.tsx#L132)

**Shell wiring**

- Nav locks mid-read: unmounting then makes executorch's cleanup throw `ModelGenerating`.
  [`Chrome.tsx:114`](../../src/components/Chrome.tsx#L114)

- Explicit `tab === 'read'` rather than a catch-all else, so a future tab can't land here.
  [`App.tsx:80`](../../src/App.tsx#L80)

- Camera-readiness gate; without it an early tap yields a false "Couldn't read that."
  [`ReadScreen.tsx:226`](../../src/screens/ReadScreen.tsx#L226)

- Retry remounts the reader — the only way to make `useOCR` re-attempt a failed load.
  [`ReadScreen.tsx:89`](../../src/screens/ReadScreen.tsx#L89)

**Peripherals**

- Regression test for the line-grouping defect both reviewers found independently.
  [`ocr.test.ts:95`](../../test/ocr.test.ts#L95)

- `TextBox` mirrors `OCRDetection` so the pure helpers need no library import.
  [`types/index.ts:13`](../../src/features/ai/types/index.ts#L13)

- Lets tests typecheck; also repaired the pre-existing `currency-rn` failure.
  [`tsconfig.json:8`](../../tsconfig.json#L8)
