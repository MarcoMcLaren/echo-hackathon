# App contract

Companion to `SPEC.md`. Everything both apps must agree on above the wire. The byte
format lives in `../../../spec/wire.md`; this is the behaviour around it.

Both apps implement this independently. Where they differ visibly, the comparison is
measuring the wrong thing.

---

## 1. Bearer vs directed falls out of the channel

A transfer rewrites `holder` to the recipient's device id. **But a one-way channel has no
back-channel, so the sender cannot learn who is about to receive.** That single fact
decides the mode per channel — it is not a preference:

| Channel | Mode | Why |
|---|---|---|
| Static QR | **BEARER** | The sender cannot know who will scan the code |
| NFC tag | **BEARER** | The sender cannot know who will tap the tag |
| Nearby Connections | **DIRECTED** | Endpoint discovery yields the peer's id first |
| Multi-hop relay | **DIRECTED** | Routing needs a destination |

**Consequence: relay only runs over Nearby.** A bearer note has no destination to route
toward, so relaying one is meaningless. This matches the build order — relay is layered
on channel 2.

A BEARER note sets `flags` bit 0 and `holder` to all-zero. First device to claim it wins;
that is the intended semantic, not a weakness.

## 2. The human is the acknowledgement

Fire-and-forget means **no ACK**. So when does the sender delete its copy?

- Delete when the QR is displayed → if nobody scans, the money is destroyed.
- Delete never → double-spend.

**Neither is acceptable, and no protocol trick fixes it on a one-way channel.** The
resolution: the person holding the phone is the acknowledgement.

### Send state machine

```
HELD ──user picks note + channel──> IN_FLIGHT ──user taps "Delivered"──> GONE (deleted)
                                        │
                                        └──user taps "Cancel"──────────> HELD
```

`IN_FLIGHT` notes are **locked**: excluded from the balance fold, not selectable for a
second send. That is what prevents double-spend in v0 — not cryptography.

The two buttons must be equally prominent. A confirm-by-default flow loses money the
first time a scan fails, on stage.

### Receive pipeline

```
payload ──> fromB64url ──> decode ──> [wire errors surface here]
        ──> seen.has(note_id, lamport)?          ──> reject "duplicate"
        ──> bearer OR holder == myDeviceId?      ──> no: reject "not_holder"
        ──> accept: add to wallet, add to seen
```

On accept over a directed channel the receiver rewrites `holder` to its own id and
increments `lamport` **before** storing. On a bearer channel it does the same, converting
the note from bearer to directed-at-me.

## 3. Device identity

- 16 random bytes, generated on first launch, persisted forever. This is `holder`.
- Framework prefix is a **compile-time constant**: `rn` or `fl`.
- Nearby endpoint name is `<prefix>:<first 4 bytes of device id, hex>` — see
  `../../../spec/wire.md`.

No key material in v0. The device id is an identifier, not a credential — say so in the
pitch rather than implying otherwise.

## 4. Storage

One JSON blob. AsyncStorage on RN, SharedPreferences on Flutter. **No database.**

```json
{
  "schemaVersion": 1,
  "deviceId": "aabbccddeeff00112233445566778899",
  "notes": [
    { "ver": 0, "flags": 0, "note_id": "...", "value": 100,
      "holder": "...", "lamport": 0, "state": "HELD" }
  ]
}
```

`state` is `HELD` or `IN_FLIGHT` and is **local only** — it never goes on the wire.

The `seen` set is in-memory and is deliberately not persisted; a restart during the demo
re-opens a small double-spend window, which is an accepted v0 limitation.

## 5. Preload — the mint is faked

On first launch, seed a **fixed, identical** set in both apps. Not random: identical
starting state on every device makes the demo repeatable and makes screenshots
comparable.

| Denomination | Count | Value each |
|---|---|---|
| 1 | 10 | 100 |
| 5 | 6 | 500 |
| 20 | 3 | 2000 |
| 100 | 1 | 10000 |

Twenty notes, total 22 500 minor units (225.00). `note_id` is derived from
`deviceId + index` so no two devices mint colliding ids. `lamport` starts at 0.

Twenty notes, not a hundred — enough to scroll, few enough to eyeball during a demo.
The 100k-row rendering benchmark uses a **generated in-memory list**, never the wallet.

## 6. The three views

State enum, no navigation library.

**Wallet** — list of notes grouped by denomination; total as a fold over `HELD` only;
`IN_FLIGHT` notes greyed with a Cancel affordance. Two buttons: Send, Receive.

**Send** — pick a note, pick a channel from those where `available()` is true, then the
channel's own surface (QR image / peer list / "hold near tag"). Delivered and Cancel
both always visible.

**Receive** — listening on every available channel at once. Camera preview for QR, peer
list for Nearby, tag prompt for NFC. Accepted notes animate into the wallet; rejections
show the error code verbatim.

**Show the error codes.** `unsupported_version`, `bad_length`, `bad_flags`, `duplicate`,
`not_holder` — displayed literally, not softened into "something went wrong". They are
the fastest debugging tool on the day and they demonstrate the version-skew story.

## 7. The cross-framework toggle

One boolean in Wallet, persisted. Off (default) → Nearby ignores endpoints whose prefix
differs from this build's. On → accept every endpoint.

Affects **discovery only**. QR and NFC are unaffected — they were always
framework-blind, which is why cross-framework works there for free.

**This toggle is the headline demo beat.** Make it a visible switch, not a settings item.

## 8. Deliberately absent

No settings screen · no onboarding · no auth or biometric gate · no animations beyond
the default · no dark mode · no i18n · no accessibility pass beyond default labels ·
no empty states beyond one line of text · no error recovery beyond Cancel.

Each of these is a real product need and none of them discriminates between the two
frameworks, which is the only criterion that earns a feature a place here.
