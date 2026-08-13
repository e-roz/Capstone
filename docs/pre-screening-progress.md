# Pre-Screening — Build Progress

**Last worked:** 2026-08-14
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
| Mobile capture + confirm | ✅ Rebuilt 2026-08-14, unverified on a device |

API builds clean. `flutter analyze` clean on both apps. **The test suite has not been
run since the 2026-08-14 changes** — four new date tests were added and the plate
comparison changed shape.

---

## Design changes since the design doc was written

The doc still describes the old two-field, OR-only design. What actually got built:

1. **Three documents, not one.** RAF (students) or school ID (faculty/staff), driver's licence, OR — plus a photo of the physical plate.
2. **Name matching is back**, but RAF-vs-licence, not against the OR. Both belong to the applicant, so the old objection (students drive family vehicles) doesn't apply.
3. **No CR collected.** Nothing read it.
4. **The user confirms every extracted value** on screen and may edit any of it — *except the plate*. Both readings are kept (`Extracted*` and `Confirmed*`).
5. **Upload is two calls**: `POST /registration/documents/scan` then `POST /registration/documents/confirm`.
6. **Cue A and Cue C both implemented** for the registration expiry — read it if the print survived, otherwise derive from plate digit + receipt date.

---

## The 2026-08-14 rebuild

Driven by one question from testing: *why is the user typing vehicle details the app
is about to read by itself one screen later?*

### Documents now come before the vehicle

Registration used to be profile → vehicle → documents, and the plate was typed on
the vehicle step. But the plate is printed on the OR, which was photographed on the
*next* screen. The order is now profile → documents → summary, and the vehicle
record is created at the end from what the receipt gave.

- `CompleteProfile*` advances straight to `RegistrationStep.DocumentUpload`.
- `ScanDocumentsAsync` no longer refuses when the user has no vehicle.
- `ConfirmDocumentsAsync` creates the `Vehicle`, and sets `RegistrationValidThrough`
  and `RegistrationRenewalMonth` while it has the expiry to hand — nothing set those
  before.
- `POST /api/auth/register/vehicle` is gone, along with the service method, the
  interface member, the mobile repository call and the endpoint constant.

**`RegistrationStep.VehicleInfo` stays in the enum.** It is persisted as an integer,
so removing it would renumber `DocumentUpload` and move every stored account one
step backwards. `CarryPastRetiredVehicleStep` moves any account still sitting on it
forwards on its next scan or confirm, and `jwt_utils` routes that token value to the
first document screen.

### The plate is no longer typed

It is read off the OR and shown read-only. Two consequences, both handled:

- **The old plate check became a tautology.** `CheckPlate` used to compare the
  receipt against a plate the user typed. With the vehicle built *from* the receipt,
  that comparison always passes. It now checks that the plate committed is the plate
  the scan stored — a difference means the value did not come from the screen the
  user saw.
- **Correctness now rests on two readings agreeing.** `ConfirmPlateInPhoto` returns a
  new `PlateAgreement` — `Agreed`, `Differs` or `NotChecked` — instead of a bare
  string, so "we could not read your photo" and "your photo shows another vehicle"
  are no longer the same answer. The summary shows all three differently, and the
  first two offer a retake of just the plate photo.

Nobody is ever blocked. An unreadable plate completes registration with a note
telling the reviewer to add the vehicle by hand; a plate already registered to
another account does the same rather than creating a duplicate.

### Four documents, four screens

`register_documents_screen.dart` (one screen, four tiles) and
`register_vehicle_screen.dart` are deleted. In their place
`register_document_step_screen.dart` renders one document per screen, indexed by
`/register/documents/:index`, each stating what that document is *for*.

Photos accumulate in `RegistrationNotifier.captured` and upload in one call from the
last screen, which keeps the single scan endpoint. When the server sends something
back, the flow jumps to that document's screen carrying the server's own wording,
rather than listing four verdicts nobody can act on at once.

The progress bar stays on step 4 and adds "2 of 4" — advancing it four times would
overstate how much of registration is done.

### Brand and model are optional

Nothing reads them: the gate matches on the plate, allocation on the type. Required
in neither `documents/confirm` nor `POST /api/vehicles`. **No column was dropped** —
that would be a destructive migration on the shared database, which is what took
production down on 2026-08-13.

### Colour and type are taps, not OCR

Text recognition returns words. It cannot see that a car is red, and the OR does not
print a colour — that is on the CR, which is deliberately not collected. So the
summary offers two chips for the type and a ten-swatch grid for the colour. The whole
vehicle flow now needs no keyboard.

---

## The expiry bug found on 2026-08-14

`DateExtraction.FindMonthYear` accepted **only** `MM/YYYY`, guarding against picking
up the renewal window that trails the expiry. A real receipt reads:

```
This payment is valid until 01/31/2026 and due or renewal on 01/22/2026 - 01/31/2026
```

That is a full date. The rule found `31/2026`, rejected month 31, found `22/2026`,
rejected month 22, and returned nothing — so Cue A failed silently and the expiry was
derived from the plate digit instead of read. The rule had been calibrated against a
receipt worded `valid until 01/2026`.

`FindExpiry` replaces it: cut the text at `due`/`renewal`, then take the earliest date
left in either shape. Both wordings now give 31 January 2026. Four tests cover it,
including the string above verbatim with its OCR damage (`due or renewal`).

**Worth watching on the next real receipt:** if the plate-digit fallback was quietly
covering for this, test accounts made before today may hold a derived expiry where
they should hold a read one.

---

## Next up

**1. Verify on a phone.** Nothing here has run on hardware. Watch the Risks below.

**2. Run the test suite.** Not run since these changes. Stop the local API first —
it holds `AimPark.API.exe` and the build fails on the copy, which reads as a build
error rather than a lock.

**3. Dev-only extraction endpoint** — *agreed, not built.*
`POST /api/dev/extract` taking pasted ML Kit JSON, returning what the rules
extracted. Gated to `Development` only. `/dev/ocr` produces the JSON to paste in.

**4. Stage 4** — admin diff view (what we read vs what the user typed), the semester
end-date field, and copying confirmed values to `User` on approval. The vehicle half
of this is now done at confirm time.

---

## Risks to check on the first device run

- **Photo size vs the 8MB per-file cap.** `ResolutionPreset.max` on a high-megapixel phone can exceed it. The app checks before uploading and says which photo was too big, but if this fires on ordinary handsets the cap or the preset has to move.
- **Box coordinates vs image dimensions.** The boxes come from ML Kit and the dimensions from Flutter's decoder. If they disagree about EXIF rotation every anchor rule misses. `/dev/ocr` shows a red warning when any box falls outside the image — check that it stays quiet.
- **Confidence on iOS.** Only Android reports per-line confidence. A missing value is sent as 1.0, so blur detection is Android-only. Fine for an APK deliverable, wrong the day iOS matters.
- **The plate has no keyboard fallback.** If a plate reads wrong on real photos and the two readings still agree on the wrong value, nothing in the flow catches it — only the reviewer. Watch what the summary shows against real plates before deciding whether that is acceptable.

---

## Known gaps

- **`POST /api/vehicles` has no document check.** Requires an approved account, but the vehicle itself is unverified until Stage 4 wires pre-screening into it.
- **Orphaned blobs.** Re-scanning deletes the previous `Document` rows but not the stored files.
- **RAF rules are calibrated against one form.** Collect 3–5 more, ideally different courses and year levels — `/dev/ocr` is how.
- **Cue C rests on one receipt.** Confirm the plate-digit renewal rule against a second OR from a different vehicle.
- **Where registration lands.** After confirming, the app still goes to `/login/sign-in`; because a token exists by then, the router forwards to `/home/user`. Unchanged behaviour, not verified as the intended one.

---

## Things learned from the real samples

Both worth keeping in mind when the rules next change.

**The STI RAF mixes two layouts on one form.** `SY & Term:`, `Program:` and `Year Level:` print their value in the cell to the *right*, as a separate OCR line. `Student No` and the three name cells print the label *beneath* the value. Neither is a same-line read, and row-band sorting separates them — `Year Level:` sits at y=372 while its own value sits at y=359. Box geometry is required.

**Receipts word the expiry line two ways**, and one of them prints a full date. See the bug above. Assume the next sample words it a third way.

**Two traps are pinned in the test fixture:**
- `Student Information` is within edit tolerance of the label `Student No` and appears first — taking the first match instead of the closest returned nothing at all.
- `J4Y1` falls in the vertical gap above `Middle Name` and is only excluded by the column-overlap check.

**Timing:** the RAF took 5.1s to process at 3200×4154, versus 1.2s for the receipt. Run OCR during the screen transition, not after the user taps.

**Sample documents are not committed.** The test fixture reproduces the real geometry and OCR damage with invented personal values.
