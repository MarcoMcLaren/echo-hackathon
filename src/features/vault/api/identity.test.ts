// Uses jest.isolateModules so each test gets a fresh identity.ts module (the
// `cached` variable is module-level, so re-requiring is the only way to
// simulate "a new app launch"). Must use `require`, not dynamic `import()` —
// Jest's module registry swap only applies to synchronous requires.
import * as FS from 'expo-file-system';

const freshIdentity = () => {
  let mod: typeof import('./identity');
  jest.isolateModules(() => {
    mod = require('./identity');
  });
  return mod!;
};

beforeEach(() => {
  (FS as any).__reset();
});

describe('deviceIdentity', () => {
  it('mints an id on first launch and persists it to storage', async () => {
    const { deviceIdentity } = await freshIdentity();
    const id = await deviceIdentity();
    expect(id).toEqual(expect.any(String));
    expect(id.length).toBeGreaterThan(0);
  });

  it('returns the same id for repeated calls within one launch', async () => {
    const { deviceIdentity } = await freshIdentity();
    const first = await deviceIdentity();
    const second = await deviceIdentity();
    expect(second).toBe(first);
  });

  it('restores the previous id after a simulated restart', async () => {
    const first = await freshIdentity();
    const original = await first.deviceIdentity();

    // Simulate the app restarting: a fresh module (cached === null again),
    // but the same underlying file-system contents.
    const second = await freshIdentity();
    const restored = await second.deviceIdentity();

    expect(restored).toBe(original);
  });
});
