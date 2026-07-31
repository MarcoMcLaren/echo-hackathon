// Placeholder -- send a job (e.g. a message-thread summary) to the remote datacenter GPU.
// ONLINE (breaks the 100%-offline story) -- keep opt-in; the on-device LLM stays the default.
// Also: sending message content off-device conflicts with the E2E-encryption goal -- only
// summarize content the user already sees, with consent. Wire endpoint/auth at the event.
export function useRemoteGpu() {
  return { available: false };
}
