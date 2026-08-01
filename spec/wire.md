# Echo currency — wire format v0

**FROZEN.** Both implementations follow this document. When RN and Flutter disagree,
`ref.py` is right and the disagreeing side has a bug.

Files in this folder:

| File | Role |
|---|---|
| `wire.md` | this contract |
| `vectors.json` | 9 frozen conformance vectors — both projects run these in unit tests |
| `ref.py` | Python reference. `uv run spec/ref.py` verifies. Depended on by neither app |

> **Segregation note.** `spec/` contains documents, JSON and one Python file. **No Gradle
> file, no `pubspec.yaml`, no `package.json` may reference anything in here.** Copy
> `vectors.json` into each project's test fixtures; do not link to it.

---

## Design rules

- **Fixed-width fields only.** No length prefixes, no varints, no schema library.
  Canonical form is then trivial, and there is no Dart-vs-JS serialization mismatch to
  debug — historically the likeliest cause of a failed cross-framework demo.
- **Big-endian** for every multi-byte integer.
- **One version byte at the head.** Unknown value → refuse, surface
  `unsupported_version`.
- **The note carries no framework identity.** Framework tagging lives in the transport.
  This is what makes cross-framework payment work.

## The note — exactly 42 bytes

| Offset | Len | Field | Type | Notes |
|---|---|---|---|---|
| 0 | 1 | `ver` | u8 | `0x00` for v0 |
| 1 | 1 | `flags` | u8 | bit 0: `0` directed, `1` bearer. **Bits 1–7 reserved, must be `0`** |
| 2 | 16 | `note_id` | bytes | Random at mint, stable for the note's life |
| 18 | 4 | `value` | u32 BE | Minor units |
| 22 | 16 | `holder` | bytes | Device id of current holder. All-zero = bearer |
| 38 | 4 | `lamport` | u32 BE | Increments on every transfer. `0` at mint |

**Denominations:** 1 → `100`, 5 → `500`, 20 → `2000`, 100 → `10000`.

### Worked example

`mint-1-directed`: `ver=0`, `flags=0`, `note_id=0102…0f10`, `value=100`,
`holder=aabb…8899`, `lamport=0`

```
00 00 0102030405060708090a0b0c0d0e0f10 00000064 aabbccddeeff00112233445566778899 00000000
└ver └flags └────────note_id──────────┘ └value─┘ └──────────holder────────────┘ └lamport┘
```

base64url → `AAABAgMEBQYHCAkKCwwNDg8QAAAAZKq7zN3u_wARIjNEVWZ3iJkAAAAA` (56 chars)

## Encoding — base64url on every channel

**Transmit base64url of the 42 raw bytes: 56 characters, no padding.** Not raw bytes.

QR libraries disagree on byte-mode across ecosystems, and NDEF text records are far
simpler than custom MIME types. Base64url is boring, identical everywhere, and costs 14
bytes. Take the trade.

| Channel | Encoding |
|---|---|
| Static QR | QR **text** mode, error correction **M**, ≥240 dp |
| Nearby Connections | `BYTES` payload, UTF-8 of the base64url string |
| Multi-hop relay | as Nearby, wrapped — see below |
| NFC tag | NDEF **text** record, UTF-8 |

## Transfer semantics

One-way, fire-and-forget. **There is no ACK**, so a transmitted note must be
independently verifiable on arrival.

A transfer rewrites `holder` to the recipient's device id and increments `lamport`.
**The sender deletes its copy on successful hand-off.**

- **Dedupe key: `(note_id, lamport)`.** Already seen → ignore. This is what makes relay
  safe.
- **Bearer notes** (`flags` bit 0 set, `holder` all-zero) are claimable by anyone in
  range, first come.
- **Conflict** — the same `(note_id, lamport)` from two different senders, or two
  divergent `lamport` lineages for one `note_id`. *Detection is out of scope in v0; the
  dedupe set exists for correctness, not fraud.*

## Relay envelope

```
R|<ttl>|<base64url-note>
```

`ttl` decimal, **starts at 3**, decremented per forward, dropped at `0`. A note the
device is not the holder of is forwarded, never claimed.

```
on receive(text):
  env = parseRelay(text)                      # null if not "R|"
  if env == null: handleDirect(text); return
  (ttl, b64) = env
  note = decode(fromB64url(b64))
  if seen.has(note.note_id, note.lamport): return
  seen.add(note.note_id, note.lamport)
  if note.holder == myDeviceId: claim(note); return
  if ttl <= 1: return
  broadcast(`R|${ttl-1}|${b64}`) to all endpoints except the sender
```

`seen` is in-memory; it need not survive restart.

## Transport identity — how the cross-framework switch works

**Nearby `serviceId` is constant: `echo.currency.v0`.** Both frameworks always advertise
on it. The framework tag lives in the **endpoint name**:

```
<framework>:<device-id-hex-8>        rn:a3f19c2b        fl:7d0e4411
```

- **Same-app mode (default):** ignore endpoints whose prefix ≠ own framework.
- **Cross-framework mode (the toggle):** accept every endpoint.

One boolean, client-side filtering only. No re-advertising, no second service.
**That toggle is the headline demo beat.**

Strategy `P2P_CLUSTER`, payload type `BYTES`.

NFC tags carry **no** framework identity — a tag written by either app is readable by
both. (HCE would have needed distinct AIDs; tag-based NFC sidesteps that entirely.)

## Error taxonomy — return these strings verbatim on both sides

`unsupported_version` · `bad_length` · `bad_flags` · `duplicate` · `conflict` ·
`not_holder`

`vectors.json` asserts on the first three. The rest are app-level.

## Conformance

```
uv run spec/ref.py          # verify vectors.json
uv run spec/ref.py --emit   # recompute (only before the freeze)
```

Both projects load `vectors.json` in their own unit tests and must pass all 9 —
6 encode round-trips (each denomination, bearer flag, `lamport` at u32 max) and
3 rejections (unknown major, reserved flags set, wrong length).

**Vector values were cross-checked against an independent base64 implementation, not
only against `ref.py`.** If you regenerate them, do that again.

## v1 — reserved, not built

v1 appends a 32-byte holder pubkey and a 64-byte ed25519 signature over bytes `0..37`,
giving a 138-byte tip, behind `ver = 0x01`.

**v0 is unsigned. Do not claim signature-based forger identification.**
