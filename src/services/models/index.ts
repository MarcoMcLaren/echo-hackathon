// Model service: registers the ExecuTorch resource fetcher and pre-downloads
// model files to on-device cache. Models are hosted on Hugging Face; they
// download once (over wifi) on first use, then run 100% offline.
import {
  initExecutorch,
  ResourceFetcher,
  SSDLITE_320_MOBILENET_V3_LARGE,
  OCR_ENGLISH,
  QWEN2_5_0_5B_QUANTIZED,
} from 'react-native-executorch';
import { ExpoResourceFetcher } from 'react-native-executorch-expo-resource-fetcher';

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
 * Download a group's files to on-device cache (no RAM load). Reports progress
 * 0..1. Idempotent — already-cached files are skipped, so re-running is cheap.
 */
export async function downloadGroup(
  group: ModelGroup,
  onProgress: (p: number) => void
): Promise<void> {
  await ResourceFetcher.fetch(onProgress, ...group.sources);
}
