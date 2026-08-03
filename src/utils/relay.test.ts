import {
  DEFAULT_TTL,
  SeenCache,
  decode,
  encode,
  hopsTaken,
  isGroup,
  newEnvelope,
  relayedBy,
  route,
  type Envelope,
} from './relay';

const base = (overrides: Partial<Envelope> = {}): Envelope => ({
  id: 'msg-1',
  from: 'a',
  to: 'b',
  kind: 'msg',
  body: 'hello',
  ttl: DEFAULT_TTL,
  path: [],
  at: 0,
  ...overrides,
});

describe('newEnvelope', () => {
  it('defaults ttl and starts with an empty path', () => {
    const e = newEnvelope({ id: '1', from: 'a', to: 'b', kind: 'msg', body: 'hi', at: 0 });
    expect(e.ttl).toBe(DEFAULT_TTL);
    expect(e.path).toEqual([]);
  });

  it('honours an explicit ttl', () => {
    const e = newEnvelope({ id: '1', from: 'a', to: 'b', kind: 'msg', body: 'hi', at: 0, ttl: 1 });
    expect(e.ttl).toBe(1);
  });
});

describe('hopsTaken / relayedBy', () => {
  it('reports zero hops and no relay for a direct envelope', () => {
    const e = base({ path: [] });
    expect(hopsTaken(e)).toBe(0);
    expect(relayedBy(e)).toBeUndefined();
  });

  it('reports hop count and the last relay in the path', () => {
    const e = base({ path: ['x', 'y'] });
    expect(hopsTaken(e)).toBe(2);
    expect(relayedBy(e)).toBe('y');
  });
});

describe('SeenCache', () => {
  it('reports false the first time an id is seen, true after', () => {
    const seen = new SeenCache();
    expect(seen.check('id-1')).toBe(false);
    expect(seen.check('id-1')).toBe(true);
  });

  it('tracks distinct ids independently', () => {
    const seen = new SeenCache();
    seen.check('id-1');
    expect(seen.check('id-2')).toBe(false);
    expect(seen.size).toBe(2);
  });

  it('forgets the oldest id once the limit is exceeded', () => {
    const seen = new SeenCache(2);
    seen.check('id-1');
    seen.check('id-2');
    seen.check('id-3'); // evicts id-1
    expect(seen.check('id-1')).toBe(false); // forgotten, so "new" again
    expect(seen.size).toBe(2);
  });
});

describe('route', () => {
  it('drops as duplicate on the second delivery of the same id', () => {
    const seen = new SeenCache();
    const e = base({ id: 'dup', to: 'someone-else' });
    route(e, 'me', seen); // first pass records the id
    expect(route(e, 'me', seen)).toEqual({ action: 'drop', why: 'duplicate' });
  });

  it('drops as a loop if our own id is already in the path', () => {
    const seen = new SeenCache();
    const e = base({ to: 'someone-else', path: ['me'] });
    expect(route(e, 'me', seen)).toEqual({ action: 'drop', why: 'loop' });
  });

  it('delivers when addressed to us', () => {
    const seen = new SeenCache();
    const e = base({ to: 'me' });
    expect(route(e, 'me', seen)).toEqual({ action: 'deliver', envelope: e });
  });

  it('drops as expired when ttl is exhausted and not addressed to us', () => {
    const seen = new SeenCache();
    const e = base({ to: 'someone-else', ttl: 0 });
    expect(route(e, 'me', seen)).toEqual({ action: 'drop', why: 'expired' });
  });

  it('relays otherwise, burning a hop and recording our id in the path', () => {
    const seen = new SeenCache();
    const e = base({ to: 'someone-else', ttl: 2, path: ['a'] });
    const decision = route(e, 'me', seen, 'peer-1');
    expect(decision).toEqual({
      action: 'relay',
      envelope: { ...e, ttl: 1, path: ['a', 'me'] },
      excludePeer: 'peer-1',
    });
  });
});

describe('isGroup', () => {
  it('recognises the g: prefix', () => {
    expect(isGroup('g:braai')).toBe(true);
    expect(isGroup('thabo')).toBe(false);
  });
});

describe('encode / decode', () => {
  it('round-trips a valid envelope', () => {
    const e = base();
    expect(decode(encode(e))).toEqual(e);
  });

  it('returns null for malformed JSON instead of throwing', () => {
    expect(decode('not json')).toBeNull();
  });

  it('returns null when required fields are missing or the wrong type', () => {
    expect(decode(JSON.stringify({ id: 'x' }))).toBeNull();
    expect(decode(JSON.stringify({ ...base(), ttl: 'three' }))).toBeNull();
    expect(decode(JSON.stringify({ ...base(), path: 'not-an-array' }))).toBeNull();
  });
});
