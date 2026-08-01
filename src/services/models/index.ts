// Model service: registers the ExecuTorch resource fetcher and pre-downloads
// model files to on-device cache. Models are hosted on Hugging Face; they
// download once (over wifi) on first use, then run 100% offline.
import {
  initExecutorch,
  ResourceFetcher,
  SSDLITE_320_MOBILENET_V3_LARGE,
  OCR_ENGLISH,
  QWEN2_5_0_5B_QUANTIZED,
  WHISPER_TINY_EN_MODEL_XNNPACK,
  WHISPER_TINY_EN_TOKENIZER,
} from 'react-native-executorch';
import { ExpoResourceFetcher } from 'react-native-executorch-expo-resource-fetcher';
import { File, Paths } from 'expo-file-system';

// Register the Expo (expo-file-system) fetcher so the hooks can download +
// cache model files. Must run before any model loads — hence module scope.
initExecutorch({ resourceFetcher: ExpoResourceFetcher });

export type ModelGroup = {
  key: string;
  label: string;
  sizeLabel: string;
  /** Remote files to fetch to on-device cache. */
  sources: string[];
};

/** Small models for the blind-nav core: obstacle detection + OCR. */
export const VISION_MODELS: ModelGroup = {
  key: 'vision',
  label: 'Vision — obstacle detection + OCR',
  sizeLabel: '~50 MB',
  sources: [
    SSDLITE_320_MOBILENET_V3_LARGE.modelSource,
    OCR_ENGLISH.detectorSource,
    OCR_ENGLISH.recognizerSource,
  ],
};

/** The LLM for summaries / scene description (large — opt-in). */
export const LANGUAGE_MODEL: ModelGroup = {
  key: 'language',
  label: 'Language model — summaries / describe scene',
  sizeLabel: '~400 MB',
  sources: [
    QWEN2_5_0_5B_QUANTIZED.modelSource,
    QWEN2_5_0_5B_QUANTIZED.tokenizerSource,
    QWEN2_5_0_5B_QUANTIZED.tokenizerConfigSource,
  ],
};

/**
 * Whisper tiny.en for hold-to-talk dictation. English-only and the smallest
 * architecture the native runner supports — still the second-heaviest download
 * after the LLM, so it is worth pulling over wifi before a demo.
 */
export const SPEECH_MODEL: ModelGroup = {
  key: 'speech',
  label: 'Speech to text — dictate a message',
  sizeLabel: '~224 MB',
  sources: [WHISPER_TINY_EN_MODEL_XNNPACK, WHISPER_TINY_EN_TOKENIZER],
};

/**
 * Download a group's files to on-device cache (no RAM load). Reports progress
 * 0..1. Idempotent — already-cached files are skipped, so re-running is cheap.
 */
export async function downloadGroup(
  group: ModelGroup,
  onProgress: (p: number) => void
): Promise<void> {
  await ResourceFetcher.fetch(onProgress, ...group.sources);
}

/**
 * Records that this phone opted into the speech download.
 *
 * `ResourceFetcher` has no cached-state probe — the only way to ask whether the
 * files are on disk is to start fetching them — so a marker file is what makes
 * "already paid for" knowable. Same shape as `features/vault/api/identity.ts`:
 * `expo-file-system` is already in the build, so this costs no native module.
 */
const SPEECH_MARKER = 'echo-speech-model';

let speechOptIn: boolean | null = null;

/**
 * Whether dictation can load. Never fetches, so a screen may call it on mount:
 * at 224 MB Whisper must never download as a side effect of opening a chat.
 */
export async function speechModelReady(): Promise<boolean> {
  if (speechOptIn !== null) return speechOptIn;

  try {
    speechOptIn = new File(Paths.document, SPEECH_MARKER).exists;
  } catch {
    // Unreadable storage. Reading it as "not yet" only costs an offer to
    // download again, and a fetch over an intact cache is nearly free.
    speechOptIn = false;
  }
  return speechOptIn;
}

/**
 * Fetch the speech model, then record the opt-in. The marker is written only
 * after `downloadGroup` resolves: a half-finished download that read as ready
 * on the next launch would put a mic in the composer that cannot work.
 */
export async function downloadSpeechModel(onProgress: (p: number) => void): Promise<void> {
  await downloadGroup(SPEECH_MODEL, onProgress);

  try {
    const marker = new File(Paths.document, SPEECH_MARKER);
    marker.create({ overwrite: true });
    marker.write(new Date().toISOString());
  } catch {
    // Storage refused the marker. The model files are cached either way, so
    // dictation works for this session; the cost is being offered the download
    // again next launch, which then completes almost instantly.
  }
  speechOptIn = true;
}
