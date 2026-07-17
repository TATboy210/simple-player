# Contract Test Fixtures

Real files used by `test/contracts/*_contract.dart` and
`test/engine/fvp_engine_contract_test.dart` to exercise `FvpEngine`'s error
paths (D17: real bad-file fixtures, not scripted `FakeEngine` error
injection) and the mandatory "open to play handoff" regression gate
(T-15-07).

## Files

| File | Size | Purpose | Expected `open()` outcome |
|------|------|---------|----------------------------|
| `tiny_valid.mp4` | 788,493 bytes | Genuine playable H.264 video — powers the un-skippable "open to play handoff" gate test | `state == MediaState.idle` after `open()` succeeds, then `state == MediaState.playing` after `play()` |
| `corrupted_header.mp4` | 224 bytes | Valid `ftyp`/`isom` box signature followed by random bytes — demuxer/codec should fail after accepting the container header | `lastError.value isA<PlayerError>()` and `state == MediaState.error` |
| `empty_file.mp4` | 0 bytes | Zero-length file with a valid extension — no data to demux at all | `lastError.value isA<PlayerError>()` and `state == MediaState.error` |
| `not_a_video.txt` | 106 bytes | Plain UTF-8 text file, wrong format entirely (not even a container) | `lastError.value isA<PlayerError>()` and `state == MediaState.error` |
| `unsupported_codec.avi` | 212 bytes | `RIFF`/`AVI ` container signature followed by random bytes — no valid stream/codec data | `lastError.value isA<PlayerError>()` and `state == MediaState.error` |

## Provenance

- `tiny_valid.mp4` — downloaded from the public W3Schools HTML5 video sample
  (`https://www.w3schools.com/html/mov_bbb.mp4`), itself a re-encode of the
  "Big Buck Bunny" open movie (© Blender Foundation, CC BY 3.0,
  https://peach.blender.org/). Chosen because it is a well-known, freely
  redistributable, genuinely decodable H.264/AAC MP4 — no `ffmpeg` was
  available on the executing machine to synthesize a smaller clip, so an
  existing legal public sample was committed instead (per plan fallback
  instructions). SHA-256 recorded below for integrity verification.
- `corrupted_header.mp4` / `unsupported_codec.avi` — synthetically generated
  (`ftyp`/`RIFF` header bytes + random payload) specifically for this test
  suite. Not derived from any third-party media.
- `empty_file.mp4` / `not_a_video.txt` — synthetically generated for this
  test suite.

## SHA-256 Checksums

```
ca7dece011c5abc2ddae9dcb32cbf1f01d8d500cbc6627ee26d246ee1468c81e  corrupted_header.mp4
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  empty_file.mp4
7a1c0af92c1d66a516829963cac55d3029c029a53f1b2265ea41f07869a3d93e  not_a_video.txt
3bb938fb70049e3e45f533b37ccae995ae96516e04c2f35b0c1142e47b2a39c1  tiny_valid.mp4
2be24cd74048880dbd9d235566fc701547033b4b4bcafac03f9284fd3e129d27  unsupported_codec.avi
```

Verify with:

```bash
sha256sum -c <(printf '%s\n' \
  "ca7dece011c5abc2ddae9dcb32cbf1f01d8d500cbc6627ee26d246ee1468c81e  corrupted_header.mp4" \
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  empty_file.mp4" \
  "7a1c0af92c1d66a516829963cac55d3029c029a53f1b2265ea41f07869a3d93e  not_a_video.txt" \
  "3bb938fb70049e3e45f533b37ccae995ae96516e04c2f35b0c1142e47b2a39c1  tiny_valid.mp4" \
  "2be24cd74048880dbd9d235566fc701547033b4b4bcafac03f9284fd3e129d27  unsupported_codec.avi")
```

## Baseline-capture scope (D16/D20)

These fixtures exist to capture `FvpEngine`'s **current** observable
behavior for contract-freeze purposes (Phase 15). They intentionally do
NOT probe timing/race conditions or new `LifecyclePhase` semantics — those
are deferred to Phase 20/21.
