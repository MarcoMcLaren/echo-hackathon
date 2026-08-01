// Manual mock for react-native-executorch. This is a native/JSI module that
// throws on import outside a real device — the mock exists purely so files
// that import from it (e.g. useThreadSummary.ts, for its pure `toLines`
// helper) can be required under Jest at all. It does not attempt to model
// real model-loading/generation behaviour.

export const QWEN2_5_0_5B_QUANTIZED = 'mock-qwen-2.5-0.5b-quantized';

export const useLLM = jest.fn(() => ({
  isReady: false,
  isGenerating: false,
  response: '',
  error: null,
  downloadProgress: 0,
  configure: jest.fn(),
  generate: jest.fn().mockResolvedValue(undefined),
  interrupt: jest.fn(),
}));
