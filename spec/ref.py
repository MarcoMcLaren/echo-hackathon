"""Reference implementation for the Echo currency wire format, v0.

Depended on by NEITHER app. This exists to settle arguments: when the React Native
build and the Flutter build disagree, this is right and the disagreeing side has a bug.

    uv run spec/ref.py            # verify vectors.json
    uv run spec/ref.py --emit     # recompute vectors.json from the cases below

See spec/wire.md for the byte layout.
"""

import base64
import json
import sys
from pathlib import Path

VERSION = 0
NOTE_LEN = 42

# field offsets — must match wire.md exactly
OFF_VER, OFF_FLAGS, OFF_NOTE_ID, OFF_VALUE, OFF_HOLDER, OFF_LAMPORT = 0, 1, 2, 18, 22, 38

FLAG_BEARER = 0x01
FLAGS_RESERVED = 0xFE  # bits 1-7 must be zero

VECTORS = Path(__file__).with_name("vectors.json")


class WireError(Exception):
    """Carries one of the taxonomy codes both implementations must return verbatim."""

    def __init__(self, code):
        super().__init__(code)
        self.code = code


def encode(note):
    """dict -> 42 bytes. Fixed-width, big-endian, no length prefixes."""
    out = bytearray(NOTE_LEN)
    out[OFF_VER] = note["ver"]
    out[OFF_FLAGS] = note["flags"]
    out[OFF_NOTE_ID:OFF_NOTE_ID + 16] = bytes.fromhex(note["note_id"])
    out[OFF_VALUE:OFF_VALUE + 4] = note["value"].to_bytes(4, "big")
    out[OFF_HOLDER:OFF_HOLDER + 16] = bytes.fromhex(note["holder"])
    out[OFF_LAMPORT:OFF_LAMPORT + 4] = note["lamport"].to_bytes(4, "big")
    return bytes(out)


def decode(raw):
    """42 bytes -> dict. Raises WireError with a taxonomy code."""
    if len(raw) != NOTE_LEN:
        raise WireError("bad_length")
    ver = raw[OFF_VER]
    if ver != VERSION:
        raise WireError("unsupported_version")
    flags = raw[OFF_FLAGS]
    if flags & FLAGS_RESERVED:
        raise WireError("bad_flags")
    return {
        "ver": ver,
        "flags": flags,
        "note_id": raw[OFF_NOTE_ID:OFF_NOTE_ID + 16].hex(),
        "value": int.from_bytes(raw[OFF_VALUE:OFF_VALUE + 4], "big"),
        "holder": raw[OFF_HOLDER:OFF_HOLDER + 16].hex(),
        "lamport": int.from_bytes(raw[OFF_LAMPORT:OFF_LAMPORT + 4], "big"),
    }


def to_b64url(raw):
    """42 bytes -> 56 chars, no padding. This is what every channel transmits."""
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def from_b64url(text):
    pad = "=" * (-len(text) % 4)
    try:
        return base64.urlsafe_b64decode(text + pad)
    except Exception:
        raise WireError("bad_length")


def is_bearer(note):
    return bool(note["flags"] & FLAG_BEARER)


def dedupe_key(note):
    """What relay and double-spend checks key on."""
    return (note["note_id"], note["lamport"])


# ---------------------------------------------------------------- relay envelope

RELAY_TTL_START = 3


def wrap_relay(b64, ttl=RELAY_TTL_START):
    return f"R|{ttl}|{b64}"


def parse_relay(text):
    """-> (ttl, b64) or None if this is a direct transfer, not a relay envelope."""
    if not text.startswith("R|"):
        return None
    _, ttl, b64 = text.split("|", 2)
    return int(ttl), b64


# ---------------------------------------------------------------- vectors

ENCODE_CASES = [
    ("mint-1-directed", 0, 0, "0102030405060708090a0b0c0d0e0f10", 100,
     "aabbccddeeff00112233445566778899", 0),
    ("mint-5-directed", 0, 0, "1112131415161718191a1b1c1d1e1f20", 500,
     "aabbccddeeff00112233445566778899", 0),
    ("mint-20-directed", 0, 0, "2122232425262728292a2b2c2d2e2f30", 2000,
     "aabbccddeeff00112233445566778899", 1),
    ("mint-100-directed", 0, 0, "3132333435363738393a3b3c3d3e3f40", 10000,
     "aabbccddeeff00112233445566778899", 7),
    ("bearer-holder-zero", 0, FLAG_BEARER, "4142434445464748494a4b4c4d4e4f50", 500,
     "00000000000000000000000000000000", 2),
    ("lamport-max", 0, 0, "5152535455565758595a5b5c5d5e5f60", 10000,
     "aabbccddeeff00112233445566778899", 0xFFFFFFFF),
]


def build():
    encode_vectors = []
    for name, ver, flags, note_id, value, holder, lamport in ENCODE_CASES:
        note = {"ver": ver, "flags": flags, "note_id": note_id,
                "value": value, "holder": holder, "lamport": lamport}
        raw = encode(note)
        assert decode(raw) == note, f"{name} did not round-trip"
        encode_vectors.append({
            "name": name,
            "note": note,
            "expect_hex": raw.hex(),
            "expect_b64url": to_b64url(raw),
        })

    good = encode(dict(ver=0, flags=0, note_id="0102030405060708090a0b0c0d0e0f10",
                       value=100, holder="aabbccddeeff00112233445566778899", lamport=0))

    bad_major = bytearray(good); bad_major[OFF_VER] = 0x01
    bad_flags = bytearray(good); bad_flags[OFF_FLAGS] = 0x02
    short = good[:-1]

    decode_vectors = [
        {"name": "reject-unknown-major", "input_b64url": to_b64url(bytes(bad_major)),
         "expect_error": "unsupported_version"},
        {"name": "reject-reserved-flags", "input_b64url": to_b64url(bytes(bad_flags)),
         "expect_error": "bad_flags"},
        {"name": "reject-short", "input_b64url": to_b64url(short),
         "expect_error": "bad_length"},
    ]
    return {"version": VERSION, "note_len": NOTE_LEN,
            "encode": encode_vectors, "decode": decode_vectors}


def verify():
    data = json.loads(VECTORS.read_text())
    failures = []

    for case in data["encode"]:
        raw = encode(case["note"])
        if raw.hex() != case["expect_hex"]:
            failures.append(f"{case['name']}: hex {raw.hex()} != {case['expect_hex']}")
        if to_b64url(raw) != case["expect_b64url"]:
            failures.append(f"{case['name']}: b64url mismatch")
        if len(raw) != NOTE_LEN:
            failures.append(f"{case['name']}: length {len(raw)} != {NOTE_LEN}")
        if decode(raw) != case["note"]:
            failures.append(f"{case['name']}: round-trip mismatch")

    for case in data["decode"]:
        try:
            decode(from_b64url(case["input_b64url"]))
            failures.append(f"{case['name']}: expected {case['expect_error']}, got success")
        except WireError as e:
            if e.code != case["expect_error"]:
                failures.append(f"{case['name']}: got {e.code}, want {case['expect_error']}")

    if failures:
        for f in failures:
            print("FAIL", f)
        return 1
    total = len(data["encode"]) + len(data["decode"])
    print(f"OK  {total} vectors pass")
    return 0


if __name__ == "__main__":
    if "--emit" in sys.argv:
        VECTORS.write_text(json.dumps(build(), indent=2) + "\n")
        print(f"wrote {VECTORS}")
        sys.exit(verify())
    sys.exit(verify())
