// Ported from src/features/ai/hooks/useThreadSummary.ts.
//
// Summarises a thread's unread backlog with a small language model that runs
// entirely on this phone — no network call, so summarising unread chat
// content locally never defeats the app's offline/E2E story. RN uses
// react-native-executorch's useLLM hook with Qwen 2.5 0.5B quantized; this
// ports the same model (litert-community/Qwen2.5-0.5B-Instruct, q8
// quantized .task bundle) onto flutter_gemma, which wraps Google's MediaPipe
// LLM Inference API.
//
// flutter_gemma's real API differs from the shape RN's useLLM hook exposes,
// so this class adapts rather than mirroring 1:1 — see notes inline:
//   - There is no `preventLoad` flag: install/create-model/create-chat is one
//     imperative sequence run from `summarise()` itself, updating
//     `isReady`/`downloadProgress` as it goes, instead of a hook effect.
//   - There is no `configure({ chatConfig: { systemPrompt } })`: flutter_gemma's
//     `Message` has no system role (mobile/flutter_gemma_mobile.dart only
//     ever sends `isUser` true/false). The system prompt is prepended to the
//     single user turn instead.
//   - `generationConfig.repetitionPenalty` has no equivalent in
//     `InferenceModel.createChat`/`createSession` (temperature/topK/topP/
//     randomSeed only), so it is dropped.
//   - `downloadProgress` is RN's 0..1 double; the installer's `withProgress`
//     callback reports an int 0..100, divided by 100 here to match.
//   - RN's `llm.interrupt()` rejects the in-flight `generate()` promise, so
//     the hook has to swallow that specific rejection as "not a failure".
//     flutter_gemma's `stopGeneration()` instead makes the response stream
//     end normally (the native side fires its completion event), so the
//     `await for` loop here just exits — no exception to special-case.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/mock.dart';

/// Shown on the sheet next to "Catch me up" — matches RN's SUMMARY_MODEL.
const summaryModel = 'Qwen 2.5 0.5B · on this phone';

const _maxLines = 4;
const _maxMessages = 40;

// litert-community/Qwen2.5-0.5B-Instruct ships several MediaPipe-ready
// variants; this is the q8-quantized multi-prefill .task bundle (~547MB),
// the same quantization tier as RN's QWEN2_5_0_5B_QUANTIZED. Confirmed present
// at this exact filename via the repo's file listing. Public, non-gated
// (Apache-2.0) — no auth token required.
const _modelUrl =
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';

final _systemPrompt = [
  'You summarise a group chat backlog for someone who was away.',
  'Reply with at most $_maxLines short lines.',
  'Each line is one fact the reader must act on or know.',
  'Prefer times, places, amounts, and who owes what.',
  'End with any question that was asked and never answered.',
  'No greeting, no preamble, no markdown, no bullet characters.',
  'One fact per line, plain sentences.',
].join(' ');

final _bulletRe = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*');

/// Strips leading bullet/number markers, trims, drops empties, caps at
/// [_maxLines] — a direct port of RN's `toLines`.
List<String> toLines(String raw) {
  return raw
      .split('\n')
      .map((l) => l.replaceFirst(_bulletRe, '').trim())
      .where((l) => l.length > 1)
      .take(_maxLines)
      .toList();
}

String _transcript(Thread thread, int unread) {
  final n = unread > 0 ? unread : _maxMessages;
  final count = n < _maxMessages ? n : _maxMessages;
  final messages = thread.messages;
  final recent = messages.length <= count ? messages : messages.sublist(messages.length - count);
  return recent.map((m) {
    final who = m.from == 'me' ? 'Me' : m.from;
    final body = m.text ?? 'sent ${(m.coin ?? 0).toStringAsFixed(2)} echocoin';
    return '$who: $body';
  }).join('\n');
}

/// Dart port of RN's `useThreadSummary` hook. Not a widget — a ChangeNotifier
/// so `CatchMeUpSheet` can listen and rebuild, same pattern as `AppStore`.
class ThreadSummary extends ChangeNotifier {
  List<String> lines = [];
  bool isReady = false;
  bool isGenerating = false;

  /// 0..1 while the model downloads on first use; null once installed
  /// (matches RN's `downloadProgress` semantics from `useLLM`).
  double? downloadProgress;

  bool done = false;
  int? tookMs;
  String? error;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _capped = false;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _ensureModel() async {
    if (isReady && _model != null) return;

    await FlutterGemma.initialize();

    final installer = FlutterGemma.installModel(
      modelType: ModelType.qwen,
      fileType: ModelFileType.task,
    );
    await installer.fromNetwork(_modelUrl).withProgress((p) {
      downloadProgress = p / 100.0;
      _notify();
    }).install();

    downloadProgress = null;
    _notify();

    // preventLoad-equivalent: nothing above touches RAM until this call —
    // the ~500MB model is only paged in once summarise() is actually asked
    // for, same reasoning as RN's `preventLoad: !enabled`.
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.cpu,
    );

    isReady = true;
    _notify();
  }

  /// Cuts generation off once [lines] has what the caller asked for —
  /// mirrors RN's effect that calls `llm.interrupt()` once
  /// `complete.length > MAX_LINES`.
  void _maybeCap(String bufferSoFar) {
    if (_capped) return;
    final complete = bufferSoFar.split('\n').where((l) => l.trim().length > 1).length;
    if (complete > _maxLines) {
      _capped = true;
      final chat = _chat;
      if (chat != null) {
        unawaited(chat.stopGeneration());
      }
    }
  }

  /// Small quantized models can fall into a deterministic repeat loop —
  /// MediaPipe's LLM Inference API has no repetition-penalty knob to prevent
  /// this the way RN's executorch config did (see the file header). This is
  /// the client-side backstop: if the tail of the buffer is just the same
  /// short chunk repeating, stop rather than let it run to the token limit
  /// producing nothing useful.
  bool _looksStuck(String bufferSoFar) {
    const window = 8;
    const minRepeats = 6;
    if (bufferSoFar.length < window * minRepeats) return false;
    final tail = bufferSoFar.substring(bufferSoFar.length - window * minRepeats);
    final chunk = tail.substring(tail.length - window);
    if (chunk.trim().isEmpty) return true; // repeating whitespace/newlines only
    return chunk * minRepeats == tail;
  }

  Future<void> summarise(Thread thread, int unread) async {
    error = null;
    done = false;
    tookMs = null;
    lines = [];
    _capped = false;
    _notify();
    final startedAt = DateTime.now().millisecondsSinceEpoch;

    try {
      await _ensureModel();

      // Fresh chat per summary: isolates temperature/systemPrompt config and
      // retry state per call, mirroring RN calling `llm.configure()` fresh
      // before every `llm.generate()`. InferenceChat itself has no public
      // close() — only its underlying InferenceModelSession does — and a
      // model only tracks one live session at a time, so the prior session
      // must be closed before a new chat/session is created for a retry.
      await _chat?.session.close();
      _chat = await _model!.createChat(
        // Without a repetition-penalty knob, a low temperature is what was
        // driving the degenerate repeat loop — raised, plus nucleus sampling
        // via topP, to give the model enough entropy to escape one.
        temperature: 0.7,
        randomSeed: 1,
        topK: 40,
        topP: 0.95,
        tokenBuffer: 256,
        modelType: ModelType.qwen,
      );

      isGenerating = true;
      _notify();

      final prompt = '$_systemPrompt\n\n${_transcript(thread, unread)}';
      await _chat!.addQuery(Message.text(text: prompt, isUser: true));

      final buffer = StringBuffer();
      var stuck = false;
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is! TextResponse) continue;
        buffer.write(response.token);
        final text = buffer.toString();
        lines = toLines(text);
        _notify();
        _maybeCap(text);
        if (!stuck && _looksStuck(text)) {
          stuck = true;
          final chat = _chat;
          if (chat != null) unawaited(chat.stopGeneration());
        }
      }

      tookMs = DateTime.now().millisecondsSinceEpoch - startedAt;
      if (stuck) {
        error = 'The model got stuck repeating itself instead of summarising.';
      } else {
        done = true;
      }
      isGenerating = false;
      _notify();
    } catch (e) {
      isGenerating = false;
      error = e.toString();
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // `_model.close()` closes its live session too (same object `_chat.session`
    // holds — a model only ever tracks one session, see
    // MobileInferenceModel.close() in flutter_gemma_mobile_inference_model.dart),
    // so there's nothing separate to close on `_chat`. Fire-and-forget: freeing
    // the model is best-effort cleanup, not something the sheet's close
    // animation should wait on.
    unawaited(_model?.close());
    super.dispose();
  }
}
