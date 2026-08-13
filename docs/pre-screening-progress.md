# Pre-Screening — Build Progress

**Last worked:** 2026-08-11
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
| Mobile layer | ⬜ Not started |

**51 tests passing.** API builds clean.

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

## Next up

**1. Dev-only extraction endpoint** — *agreed, not built.*
`POST /api/dev/extract` taking pasted ML Kit JSON, returning what the rules extracted. Gated to `Development` environment only. Lets rules be tested against new documents in seconds with no phone.

**2. Mobile debug screen** — camera with frame overlay, full-resolution capture, ML Kit, results on screen. Hidden route so registration can be skipped. Not throwaway: this becomes the real capture screen.

**3. Stage 4** — admin diff view (what we read vs what the user typed), the semester end-date field, and copying confirmed values to `User`/`Vehicle` on approval.

---

## Known gaps

- **`POST /api/vehicles` has no document check.** Requires an approved account, but the vehicle itself is unverified until Stage 4 wires pre-screening into it.
- **The mobile app cannot complete registration.** It still posts the old field names to the removed `POST /registration/documents`.
- **Orphaned blobs.** Re-scanning deletes the previous `Document` rows but not the stored files.
- **RAF rules are calibrated against one form.** Collect 3–5 more, ideally different courses and year levels.
- **Cue C rests on one receipt.** Confirm the plate-digit renewal rule against a second OR from a different vehicle.
- **`UnitTest1.cs`** is the empty `dotnet new` placeholder; safe to delete.

---

## Things learned from the real samples

Both worth keeping in mind when the rules next change.

**The STI RAF mixes two layouts on one form.** `SY & Term:`, `Program:` and `Year Level:` print their value in the cell to the *right*, as a separate OCR line. `Student No` and the three name cells print the label *beneath* the value. Neither is a same-line read, and row-band sorting separates them — `Year Level:` sits at y=372 while its own value sits at y=359. Box geometry is required.

**Two traps are pinned in the test fixture:**
- `Student Information` is within edit tolerance of the label `Student No` and appears first — taking the first match instead of the closest returned nothing at all.
- `J4Y1` falls in the vertical gap above `Middle Name` and is only excluded by the column-overlap check.

**Timing:** the RAF took 5.1s to process at 3200×4154, versus 1.2s for the receipt. Run OCR during the screen transition, not after the user taps.

**Sample documents are not committed.** The test fixture reproduces the real geometry and OCR damage with invented personal values.
