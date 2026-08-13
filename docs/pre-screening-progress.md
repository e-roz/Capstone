# Pre-Screening — Build Progress

**Last worked:** 2026-08-13
**Design doc:** [document-pre-screening.md](document-pre-screening.md) — **partly out of date**, see "Design changes" below.

---

## Where we are

| Stage | State |
|---|---|
| Database layer | ✅ Done, both migrations applied |
| Stage 1 — plumbing | ✅ Done |
| Stage 2 — scan/confirm endpoints | ✅ Done |
| Stage 3 — extraction + verdicts | ✅ Done |
| Stage 4 — admin surface | ⬜ Not started |
| Mobile capture + confirm | ✅ Built, unverified on a device |

**51 tests passing.** API builds clean. `flutter analyze` clean on both apps.

---

## Design changes since the design doc was written

The doc still describes the old two-field, OR-only design. What actually got built:

1. **Three documents, not one.** RAF (students) or school ID (faculty/staff), driver's licence, OR — plus a photo of the physical plate.
2. **Name matching is back**, but RAF-vs-licence, not against the OR. Both belong to the applicant, so the old objection (students drive family vehicles) doesn't apply.
3. **No CR collected.** Nothing read it.
4. **The user confirms every extracted value** on screen and may edit any of it. This is the biggest change — extraction accuracy stopped being load-bearing. Both readings are kept (`Extracted*` and `Confirmed*`).
5. **Upload is two calls now**: `POST /registration/documents/scan` then `POST /registration/documents/confirm`.
6. **Cue A and Cue C both implemented** for the registration expiry — read it if the print survived, otherwise derive from plate digit + receipt date.

---

## What the mobile layer does now

Built 2026-08-13, none of it run on a phone yet.

- **`/dev/ocr`** — hidden route, not linked from anywhere. Pick a document type, photograph it, and see the image size, line count, mean confidence, every line with its box, and a **Copy payload JSON** button. This is the tool for widening the RAF corpus: photograph a form, copy the JSON, paste it into a test fixture.
- **Capture screen** — `camera` at `ResolutionPreset.max` with a document-shaped guide frame, capture orientation locked to portrait, ML Kit run immediately on the shot.
- **Documents step** — four tiles (RAF *or* school ID, licence, OR, plate photo), each captured through that screen, posted to `documents/scan` with its payload. Failures come back per document with the server's own retake wording.
- **Confirm screen** — every extracted value editable, `NotFound` and `Derived` flags rendered as separate sentences, then `documents/confirm`.
- **Affiliation** is now chosen on the profile step and sent. It previously was not, so every account defaulted to Student. The phone-number field, which the server had stopped accepting, is gone.

---

## Next up

**1. Verify on a phone.** Nothing here has run on hardware. Watch three things in particular — see Risks below.

**2. Dev-only extraction endpoint** — *agreed, not built.*
`POST /api/dev/extract` taking pasted ML Kit JSON, returning what the rules extracted. Gated to `Development` only. Now genuinely useful, because `/dev/ocr` produces the JSON to paste into it.

**3. Stage 4** — admin diff view (what we read vs what the user typed), the semester end-date field, and copying confirmed values to `User`/`Vehicle` on approval. Until that last part runs, an approved account has no plate on its vehicle record and the gate has nothing to match.

---

## Risks to check on the first device run

- **Photo size vs the 8MB per-file cap.** `ResolutionPreset.max` on a high-megapixel phone can exceed it. The app checks before uploading and says which photo was too big, but if this fires on ordinary handsets the cap or the preset has to move.
- **Box coordinates vs image dimensions.** The boxes come from ML Kit and the dimensions from Flutter's decoder. If they disagree about EXIF rotation every anchor rule misses. `/dev/ocr` shows a red warning when any box falls outside the image — check that it stays quiet.
- **Confidence on iOS.** Only Android reports per-line confidence. A missing value is sent as 1.0, so blur detection is Android-only. Fine for an APK deliverable, wrong the day iOS matters.

---

## Known gaps

- **`POST /api/vehicles` has no document check.** Requires an approved account, but the vehicle itself is unverified until Stage 4 wires pre-screening into it.
- **Orphaned blobs.** Re-scanning deletes the previous `Document` rows but not the stored files.
- **RAF rules are calibrated against one form.** Collect 3–5 more, ideally different courses and year levels — `/dev/ocr` is how.
- **Cue C rests on one receipt.** Confirm the plate-digit renewal rule against a second OR from a different vehicle.
- **Where registration lands.** After confirming, the app still goes to `/login/sign-in` as it did before; because a token exists by then, the router forwards to `/home/user`. Unchanged behaviour, not verified as the intended one.

---

## Things learned from the real samples

Both worth keeping in mind when the rules next change.

**The STI RAF mixes two layouts on one form.** `SY & Term:`, `Program:` and `Year Level:` print their value in the cell to the *right*, as a separate OCR line. `Student No` and the three name cells print the label *beneath* the value. Neither is a same-line read, and row-band sorting separates them — `Year Level:` sits at y=372 while its own value sits at y=359. Box geometry is required.

**Two traps are pinned in the test fixture:**
- `Student Information` is within edit tolerance of the label `Student No` and appears first — taking the first match instead of the closest returned nothing at all.
- `J4Y1` falls in the vertical gap above `Middle Name` and is only excluded by the column-overlap check.

**Timing:** the RAF took 5.1s to process at 3200×4154, versus 1.2s for the receipt. Run OCR during the screen transition, not after the user taps.

**Sample documents are not committed.** The test fixture reproduces the real geometry and OCR damage with invented personal values.
