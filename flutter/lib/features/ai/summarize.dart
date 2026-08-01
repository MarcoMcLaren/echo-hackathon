// "Catch me up" — summarise a backlog with a small model running on this
// phone.
//
// Nothing leaves the device, which is the whole point: the mesh carries
// ciphertext between phones, so shipping the plaintext to a server to
// summarise it would undo the thing the app is for.
//
// Port intent of src/features/ai/hooks/useThreadSummary.ts. The real
// implementation runs react-native-executorch's useLLM (Qwen 2.5 0.5B,
// quantized) over the thread's recent messages; this defines the contract
// and a fake that emits the same state shape — loading, generating, done,
// error — so the sheet can be built and tested without a model loaded.
import '../../store/mock.dart' as mock;

/// Shown on the sheet. The claim of "on device" is worth nothing if the UI
/// doesn't say which model ran and where.
const String summaryModel = 'Qwen 2.5 0.5B · on this phone';

/// A 0.5B model will happily write an essay. Stop it once it has said enough.
const int maxSummaryLines = 4;

/// One tick of summarisation state, mirroring useThreadSummary.ts's hook
/// return shape.
class SummaryState {
  const SummaryState({
    required this.lines,
    required this.isReady,
    required this.isGenerating,
    required this.downloadProgress,
    required this.done,
    this.tookMs,
    this.error,
  });

  final List<String> lines;

  /// Model is in RAM and can generate.
  final bool isReady;
  final bool isGenerating;

  /// 0..1 while the model downloads on first use.
  final double downloadProgress;
  final bool done;
  final int? tookMs;
  final String? error;
}

abstract class ThreadSummarizer {
  /// Streams state as the model loads (first use only) and generates. Never
  /// throws — a failure surfaces as a state with [SummaryState.error] set.
  Stream<SummaryState> summarize(mock.Thread thread, int unread);
}

/// Loads once per instance — mirrors the real model staying warm in RAM for
/// the life of the app — then "generates" a few lines drawn from the
/// thread's own recent messages, so a different thread reads differently.
class MockThreadSummarizer implements ThreadSummarizer {
  MockThreadSummarizer({
    this.loadDelay = const Duration(milliseconds: 20),
    this.lineDelay = const Duration(milliseconds: 15),
  });

  final Duration loadDelay;
  final Duration lineDelay;
  bool _ready = false;

  @override
  Stream<SummaryState> summarize(mock.Thread thread, int unread) async* {
    if (!_ready) {
      for (final progress in const [0.4, 0.8, 1.0]) {
        await Future<void>.delayed(loadDelay);
        yield SummaryState(
          lines: const [],
          isReady: false,
          isGenerating: false,
          downloadProgress: progress,
          done: false,
        );
      }
      _ready = true;
    }

    yield const SummaryState(
      lines: [],
      isReady: true,
      isGenerating: true,
      downloadProgress: 1,
      done: false,
    );

    final lines = _linesFor(thread, unread);
    final emitted = <String>[];
    final start = DateTime.now();
    for (final line in lines) {
      await Future<void>.delayed(lineDelay);
      emitted.add(line);
      yield SummaryState(
        lines: List.of(emitted),
        isReady: true,
        isGenerating: true,
        downloadProgress: 1,
        done: false,
      );
    }
    yield SummaryState(
      lines: List.of(emitted),
      isReady: true,
      isGenerating: false,
      downloadProgress: 1,
      done: true,
      tookMs: DateTime.now().difference(start).inMilliseconds,
    );
  }

  List<String> _linesFor(mock.Thread thread, int unread) {
    final backlog = unread > 0 && unread <= thread.messages.length
        ? thread.messages.sublist(thread.messages.length - unread)
        : thread.messages;
    if (backlog.isEmpty) return const ['Nothing new to summarise.'];

    final senders = <String>{
      for (final m in backlog)
        if (m.from != 'me') m.from,
    };
    final lines = <String>[
      '${backlog.length} message${backlog.length == 1 ? '' : 's'} from '
          '${senders.isEmpty ? 'the group' : senders.join(', ')}.',
    ];
    if (backlog.any((m) => m.coin != null)) {
      lines.add('Echocoin changed hands while you were out of range.');
    }
    String? openQuestion;
    for (final m in backlog.reversed) {
      if (m.text != null && m.text!.trim().endsWith('?')) {
        openQuestion = m.text;
        break;
      }
    }
    if (openQuestion != null) lines.add('Still open: $openQuestion');
    return lines.take(maxSummaryLines).toList();
  }
}
