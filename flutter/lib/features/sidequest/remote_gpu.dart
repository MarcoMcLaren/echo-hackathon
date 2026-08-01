// Bonus, ONLINE-only offload: send a job (e.g. a message-thread summary) to
// the datacenter GPU available at the event.
//
// Port intent of src/features/sidequest/hooks/useRemoteGpu.ts. Two rules from
// the project brief carry straight into this contract: it must stay opt-in
// and separate from the on-device path (never the default), and it only ever
// summarizes content the user already sees, with consent — never raw mesh
// ciphertext, which would defeat the E2E-encryption goal. No native lib is
// needed here (authenticated network calls only), so there's no adapter split
// between "real" and "fake" transport the way BLE/camera/keystore have —
// just an availability gate and a request/response shape.
class RemoteGpuResult {
  const RemoteGpuResult.ok(String this.summary) : error = null;
  const RemoteGpuResult.failure(String this.error) : summary = null;

  final String? summary;
  final String? error;

  bool get ok => error == null;
}

abstract class RemoteGpuClient {
  /// False until an endpoint/auth is wired up at the event — callers must
  /// check this before offering the option in the UI, never assume it works.
  bool get available;

  /// Summarizes [messages] remotely. Callers must have already obtained
  /// explicit user consent — this method does not ask.
  Future<RemoteGpuResult> summarizeThread(
    List<String> messages, {
    required bool consent,
  });
}

/// No endpoint/auth exists in this build — always unavailable, and refuses
/// the request rather than silently falling back to a fake remote call.
class UnavailableRemoteGpuClient implements RemoteGpuClient {
  const UnavailableRemoteGpuClient();

  @override
  bool get available => false;

  @override
  Future<RemoteGpuResult> summarizeThread(
    List<String> messages, {
    required bool consent,
  }) async {
    return const RemoteGpuResult.failure(
      'The datacenter GPU endpoint is not configured on this build yet.',
    );
  }
}
