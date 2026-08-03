// Manual mock for expo-file-system, covering only what identity.ts uses:
// `new File(dir, name)` with `.exists`, `.text()`, `.create()`, `.write()`.
// Backed by an in-memory map instead of the real filesystem.
//
// Stashed on globalThis rather than module scope: tests simulate an app
// restart via jest.isolateModules, which gives identity.ts a fresh module (so
// its cached-in-memory id is gone, like a real restart) but must NOT also
// wipe this mock's "disk" — a real filesystem survives a JS reload. Module
// scope would be re-created on every isolateModules call; globalThis is the
// one thing that isn't.
const KEY = '__expoFileSystemMockStore__';
const store: Map<string, string> = (globalThis as any)[KEY] ?? new Map();
(globalThis as any)[KEY] = store;

export const Paths = { document: 'mock-document-dir' };

export class File {
  private key: string;

  constructor(_dir: unknown, name: string) {
    this.key = name;
  }

  get exists(): boolean {
    return store.has(this.key);
  }

  async text(): Promise<string> {
    return store.get(this.key) ?? '';
  }

  create(_opts?: { overwrite?: boolean }): void {
    if (!store.has(this.key)) store.set(this.key, '');
  }

  write(content: string): void {
    store.set(this.key, content);
  }
}

/** Reset between tests so a persisted identity doesn't leak across cases. */
export function __reset() {
  store.clear();
}
