// Message-thread summary adapter, shown as the "catch me up" sheet.
//
// Port intent of src/features/ai/hooks/useSummarize.ts (a placeholder
// upstream too — "summarize a message thread via the on-device LLM"). The
// real implementation runs react-native-executorch's useLLM over a thread's
// messages; this defines the contract and a fake returning the store's demo
// Summary so the UI can be built without a model loaded.
import '../../store/mock.dart' as mock;

abstract class ThreadSummarizer {
  Future<mock.Summary> summarize(List<mock.Msg> messages);
}

/// Always returns the canned demo summary from store/mock.dart, tagged with
/// the actual message count so callers can see it responded to this thread.
class MockThreadSummarizer implements ThreadSummarizer {
  @override
  Future<mock.Summary> summarize(List<mock.Msg> messages) async {
    final base = mock.summary;
    return mock.Summary(
      model: base.model,
      count: messages.length,
      took: base.took,
      points: base.points,
    );
  }
}
