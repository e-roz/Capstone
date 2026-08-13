# Automated Document Pre-Screening

**Status:** Design agreed, not yet implemented
**Last updated:** 2026-08-11
**Supersedes:** the document-parsing sections of [registration-enhancement-plan.md](registration-enhancement-plan.md), which describe a Python worker approach that has been dropped.

---

## 1. What this is

Automated Document Pre-Screening reads the **plate number** and **registration expiry** from the LTO Official Receipt (OR) using on-device OCR and server-side anchor rules, cross-checks them against the plate the user typed and a photo of the physical plate, and routes the result to an administrator with the findings pre-filled.

### Why it is called "pre-screening"

The name is deliberate. This system **cannot** tell whether a document is genuine — that would require a live LTO/LTMS lookup, which is not available to this project.

Calling it "verification" or "authentication" claims something the system does not do, and invites the question *"how does it know the receipt is real?"* — which has no good answer.

"Pre-screening" states the actual claim: the system reads documents automatically and flags the ones that need a closer look. That claim is fully supportable.

### Why it matters beyond registration

The plate number captured here is the **enrolment path for ALPR**. Per [AIM-Park_Features.md](../MD%20files/AIM-Park_Features.md), gate access is *Dual-Factor Verification (RFID + ALPR)*:

- **RFID** confirms the tag is registered.
- **ALPR** confirms the tag is on the correct vehicle.

The second factor is only possible if an accurate plate is on file, and this feature is the only place a plate enters the system. Without it, dual-factor collapses into single-factor.

This makes pre-screening the link between account registration and physical gate access — not merely a registration control.

---

## 2. Scope

### In scope

Exactly two fields are extracted, both from the OR:

| Field | Purpose | Accuracy requirement |
|---|---|---|
| Plate number | ALPR enrolment; stored on `Vehicle` | **Exact.** A wrong value denies gate access permanently. |
| Registration expiry | One-time pass/fail at signup | Tolerant. A wrong value is caught by an admin. |

### Out of scope

- **Owner name is not checked.** By design — campus users commonly drive vehicles registered to family members, so a name mismatch is expected and meaningless.
- **The CR is not parsed.** It is collected for the administrator's reference only.
- **The government ID is not parsed.** An administrator reviews it by eye.
- **No selfie or face matching.** Removed from the design.
- **No forgery detection.** Not possible without LTO integration.

### The expiry is a snapshot, not a stored expiration

The OR expiry is checked **once, at enrolment**. It is recorded as evidence on `DocumentVerification` and nowhere else.

It is deliberately **not** stored on `Vehicle` or `User`, and nothing monitors it afterwards. A user approved in August with an OR valid to December will still have access in January.

Consequences — all intentional:

- No background job watching for lapsing registrations
- No expiry reminder notifications
- No mid-term lapse handling or re-upload flow

---

## 3. Architecture

```
┌─────────────────── PHONE ───────────────────┐
│  1. Guided Capture                          │
│  2. Text Recognition (ML Kit, offline)      │
└──────────────────┬──────────────────────────┘
                   │  images + OCR lines (one POST)
┌──────────────────▼─── SERVER ───────────────┐
│  3. Anchor-Based Extraction                 │
│  4. Cross-Source Validation                 │
│  5. Diagnostic Feedback  ──► retry (max 3)  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼─── ADMIN ────────────────┐
│  6. Administrator Review (final decision)   │
└─────────────────────────────────────────────┘
```

### Division of responsibility

The phone **reads**. The server **decides**.

No regex, date parsing, or field interpretation runs on the device. Two reasons:

1. Rules will change as more real documents are seen. A rule fix must not require an app store release.
2. The server has to redo every comparison for evidence integrity anyway, so device-side interpretation is discarded work.

The single exception is a **quality gate** — "did OCR return anything at all" — which is user-experience feedback, not a verification rule.

---

## 4. Stage 1 — Guided Capture

**Problem being solved:** in a freeform photo, the receipt occupies roughly a third of the frame. Most of the camera's resolution lands on the desk and on the CR half of the sheet, leaving too few pixels on the small print.

**Approach:** a camera screen with a frame overlay instructing the user to fit *only the receipt* inside the box.

This yields roughly 2–3× more pixels on the target text with no hardware change, removes the rotated-CR noise at source, and encourages a straight-on shot.

**Also required:** capture at **full resolution**. The current picker downscales to `maxWidth: 1920` before the file is ever seen, and the diagnostic probe ran at 1495 px wide. Compression happens *after* OCR, for upload only.

`image_picker` cannot draw an overlay; this stage needs the `camera` package.

---

## 5. Stage 2 — Text Recognition

**On device, offline, free:** `google_mlkit_text_recognition` (Latin script).

### What the phone sends

Line-level text with bounding boxes, plus image dimensions:

```json
{
  "documentType": "OR",
  "imageWidth": 3024,
  "imageHeight": 4032,
  "qrPayloads": [],
  "lines": [
    { "text": "Plate No: 130301", "x": 185, "y": 424, "w": 153, "h": 19, "confidence": 0.90 }
  ]
}
```

**Line-level, not block or word level.** Blocks are too coarse — a whole paragraph in one box loses the geometry needed to read a value outward from its label. Words explode the payload and discard reading order within a line.

**Image dimensions are mandatory.** Without them the server reasons in device pixels, and a different phone breaks every spatial rule.

**Confidence is populated and usable.** Observed range in testing: `0.90` for a clean line versus `0.31` for junk. A low average across the document is a reliable blur signal.

**Transport:** the OCR payload rides in the *same* multipart POST as the images, as a JSON string field. A separate follow-up call would open a window in which the stored image and the OCR result could disagree — an evidence-integrity hole an administrator could not resolve.

### QR / barcode

The OR carries both a QR code and a barcode. Text recognition ignores both — they require `google_mlkit_barcode_scanning`.

**Untested as of this writing.** If LTO encodes structured data there, it bypasses the entire OCR pipeline. Worth testing before further investment.

---

## 6. Stage 3 — Anchor-Based Extraction

### 6.1 Shared cleanup

Runs before any field rule.

**Drop sideways lines.** In the Philippines the OR and CR are printed on one sheet, and the CR sits at 90°. ML Kit returns axis-aligned boxes, so rotated text produces a tall, narrow box:

```
OR line:  box=(185,424  153x19)   ← wide and short
CR line:  box=(887,349   17x246)  ← tall and narrow
```

Rule: **discard any line whose height exceeds its width.** This removed all CR noise in testing. It is ambiguous only for 1–2 character fragments, which are noise regardless.

This is preferred over splitting the image left/right, which breaks if the sheet is photographed the other way round.

**Sort by position.** ML Kit returns blocks in arbitrary order — in the sample, block 0 was at y=104, block 1 at y=224, block 2 at y=169. The concatenated "full text" output is therefore scrambled and **must never be parsed**. Sort top-to-bottom, then left-to-right within a row band.

**Fuzzy label matching.** OCR mangles labels (`Plale No`, `vaIid until`). All anchor searches allow a small edit distance rather than requiring an exact match.

**Lookalike repair.** In fields known to be numeric, map characters back:

```
O, o → 0      I, l → 1      S → 5      B → 8      G → 6      Z → 2
```

This is safe because the field type is known in advance. In the sample it repairs `o7/11/2025` → `07/11/2025`.

### 6.2 Plate extraction

```
Find "Plate No" (fuzzy)
    ↓
Take the remainder of that same line
    ↓
Repair lookalike characters
    ↓
Sanity check: 5–8 alphanumeric characters
```

The label and value share one line, so this is a split, not a spatial search:

```
"Plate No: 130301"    conf=0.90
```

**Do not enforce a plate format.** Motorcycle plates in the Philippines are digits only; car plates mix letters and digits. A regex such as "three letters then four digits" rejects valid motorcycle plates — including the test sample. The label already establishes what the value is; its shape does not need to prove it.

**Beware nearby lookalike numbers.** Directly beneath the plate sits `File No: 130300000938388`, which shares its opening digits, and the CR carries `1303-0000093838`. A generic "find some digits" rule will capture the wrong value. The label anchor is what makes this safe.

### 6.3 Expiry extraction

Three cues, run in order.

**Cue A — read it directly**

```
Find "valid until" (fuzzy)
    ↓
Take the FIRST MM/YYYY that follows
```

Two traps:

- **The sentence wraps.** On paper it reads `This payment is valid until` / `01/2026 and due for` / `renewal on 01/22/2026-` / `01/31/2026.` The anchor and the value land on *different lines*. Lines must be glued into a single stream before searching.
- **A second date follows immediately.** `01/22/2026-01/31/2026` is the renewal window, not the expiry. The rule must take the **first** match and require `MM/YYYY` shape, not `MM/DD/YYYY`.

**Cue B — the renewal window**

If "due for renewal on" is readable, its month and year give the same answer.

**Cue C — derive from the plate**

LTO staggers renewals nationally by plate number: **the last digit sets the renewal month** (1 = January … 0 = October), and the second-to-last digit sets the week.

Verified against the test sample:

| Source | Value | Result |
|---|---|---|
| Plate `130301`, last digit `1` | January | matches printed `01/2026` ✅ |
| Second-to-last digit `0` | last week | matches window `01/22–01/31` ✅ |

The **year** comes from the receipt date in the large print at the top (`Date: 07/11/2025`). Registration is annual: paid July 2025, renewing in January, so the next occurrence is **January 2026** — exactly what the document states.

This means the month and year can be derived from **two large-print fields that read reliably**, without touching the blurry paragraph at all.

> ⚠️ **Verify before relying on this.** The rule matched the test sample on both digits, which is good evidence but is a single document. Confirm against a second OR from a different vehicle before treating Cue C as dependable.

### 6.4 Plate photo comparison

The user also uploads a photo of the physical plate. This photo has **no label to anchor on** — but none is needed, because the expected value is already known from the OR.

The question is not *"what is the plate?"* but *"does `130301` appear in this photo?"* — confirmation rather than extraction, which is a far easier problem.

**Order matters:** read the OR first, then the plate photo.

Two handling notes:

- **Motorcycle plates are often stacked on two rows**, so OCR may return `"130"` and `"301"` as separate lines. Adjacent lines must be joined and re-compared.
- **Allow one character of difference** after lookalike repair. Plate photos are taken outdoors at angles in poor light; strict comparison fails on good-faith submissions.

Surrounding text (`PILIPINAS`, region names, stickers) is ignored automatically, since the rule only searches for the expected value.

---

## 7. Stage 4 — Cross-Source Validation

### Plate — three independent sources

| Source | Origin |
|---|---|
| OR | Anchor extraction from the receipt |
| Physical plate | Confirmation against the plate photo |
| User-entered | `Vehicle.PlateNumber` from the registration form |

**Never guess when sources disagree.** Unlike the expiry, the plate is not derived or inferred. If the three do not agree, the record goes to manual review and an administrator resolves it against the plate photo.

Rationale: a blank field an admin fills in is recoverable. A confidently wrong plate sits in the database until someone is denied at the gate — with a perfectly valid RFID tag and no way to understand why.

**Store in canonical form:** uppercase, no spaces, no dashes. Otherwise `ABC 1234` on file never matches `ABC1234` from the gate camera, and the failure is silent.

### Expiry — agreement between cues

| Cues agreeing | Outcome |
|---|---|
| Two or more | Pass |
| Only Cue C (derived) | Pass, recorded as derived rather than read |
| Cues disagree | Manual review |
| Nothing found | Manual review |

---

## 8. Stage 5 — Diagnostic Feedback

### Two distinct failure kinds

These must never be conflated:

- **"We cannot read it"** — retaking the photo helps.
- **"We read it and there is a problem"** — retaking helps nothing.

Telling a user with a lapsed registration that their photo is blurry sends them into an endless retake loop.

### Diagnosis ladder

Evaluated in order; first match wins.

| Signal | Diagnosis | Message to user |
|---|---|---|
| Almost no text found | Not a document, or too dark | "We couldn't find any text. Make sure the receipt is in the shot and the light is good." |
| Most lines sideways | Phone rotated | "Turn your phone so the receipt reads upright." |
| Many lines, low average confidence | Blurry | "Too blurry to read. Hold steady and get closer." |
| Clear text, no "Official Receipt" found | Wrong document | "That doesn't look like the receipt. Make sure you shot the OR, not the CR." |
| Receipt found, no plate | Too far away | "We found the receipt but couldn't read the plate. Move closer." |
| Plate found, no expiry | Small print lost | Attempt Cue C; usually silent |
| Both found, expiry in the past | Genuine problem | "Your registration expired in 01/2026. Please renew and upload the new receipt." |

Every message states **what is wrong** and **what to do next**.

### Response shape

```
canRead:    false
reason:     "blurry"
message:    "Too blurry to read. Hold steady and get closer."
gotPlate:   true
gotExpiry:  false
triesLeft:  1
```

Reporting fields individually lets the phone show partial progress — *"got the plate, we just need another shot for the date"* — rather than discarding a partly successful attempt.

### Stop after three attempts

When `triesLeft` reaches zero, the phone switches from "retake" to "submit for review."

This is a deliberate design rule. Some documents genuinely cannot be read — a faded photocopy folded down the middle, like the test sample. That is not the user's fault and no number of retakes will fix it. The system tries hard, then gets out of the way.

A loop that repeats "too blurry, try again" on an unreadable document is the worst possible outcome.

### Retain the reason for the administrator

Even when a submission is allowed through to manual review, the failure reason is written to `DocumentVerification.Notes`, so the review queue shows *"couldn't read expiry — photo too blurry"* rather than a bare unexplained row.

---

## 9. Stage 6 — Administrator Review

**The system never approves an account on its own.**

Passing every rule proves the *photo was readable*. It does not prove the document belongs to the applicant, and nothing in the pipeline examines the government ID — the only artifact bearing on whether this person is actually STI faculty, staff, or a student.

What the automation establishes:

- ✅ This is a real, current LTO receipt
- ✅ The plate on it matches the vehicle photographed
- ✅ The plate matches what the user typed
- ❌ Nothing about who the applicant is

So the record still reaches the review queue — but pre-filled and pre-judged.

**Clean pass:**

```
✅ Plate: 130301  (matches entered value and plate photo)
✅ Registration valid through 01/2026
⏳ Government ID — requires review
```

**Failed checks:**

```
⚠️ Could not read expiry — photo too blurry
⚠️ OR reads 130301, user entered 130310
```

The benefit is retained in full: a queue that was previously all multi-minute reviews becomes mostly single-tap confirmations, with attention concentrated on the records that need it.

There is also a practical argument. This is a capstone with a live test group. If a rule contains a bug, automatic approval creates bad accounts silently and the defect surfaces through testers. With a human in the loop it is caught on the first unusual record.

---

## 10. Data model

### `DocumentVerification` — required changes

The entity as currently drafted holds fields for checks no longer in the design, and cannot hold the ones that are.

**Remove:**

```
FaceMatchScore          FaceMatch
ExtractedLicenseName    NameMatch
ExtractedLicenseExpiry
```

**Add:**

```
ExtractedRegistrationExpiry   DateTime?    from the OR — evidence only
ExtractedPlatePhotoNumber     string?      read from the plate photo
PlatePhotoMatch               CheckResult  plate photo vs OR
RegistrationValidity          CheckResult  expiry is in the future
```

**Retain:** `ExtractedPlateNumber`, `PlateMatch`, `Result`, `Notes`, and the override-audit fields.

The entity is **not registered in `AppDbContext`** and has no migration. Both are outstanding.

### Where each value lives

| Value | Stored | Purpose |
|---|---|---|
| Plate | `Vehicle.PlateNumber` | ALPR enrolment — must be exact |
| OR expiry | `DocumentVerification` only | One-time pass/fail; no stored expiration anywhere |

### Existing defects to fix alongside

Both in the current registration flow:

- **The OR is never actually collected.** [register_documents_screen.dart:59-64](../aimpark_mobile/lib/features/auth/presentation/screens/register_documents_screen.dart#L59-L64) sends the *back of the government ID* under the field name `OR`, and the single OR/CR image under `CR`. The document this entire feature depends on is not being uploaded.
- **The selfie is silently discarded.** The app sends a `Selfie` field; `DocumentUploadDTO` has no such property, so ASP.NET binds three files and drops the fourth. With face matching removed from the design, the picker should be deleted from the screen.
- **A plate photo upload does not exist yet** and must be added.

---

## 11. Packages required

| Package | Purpose | Status |
|---|---|---|
| `google_mlkit_text_recognition` | OCR | Tested, works |
| `google_mlkit_barcode_scanning` | QR / barcode attempt | Not yet added |
| `camera` | Guided capture overlay | Not yet added |
| `image` | Crop, grayscale, contrast for second-pass OCR | Not yet added |

**Android model packaging:** prefer the **bundled** ML Kit model (~20 MB APK increase) over the Play Services unbundled variant. First-run reliability on campus Wi-Fi outweighs the download size — a "model not available" error on the one screen that matters is a poor first impression.

---

## 12. Optional enhancement — two-pass extraction

Held in reserve if guided capture and full-resolution capture prove insufficient for the expiry.

1. **Pass 1** — OCR the full image. Locate `Plate No` (large, reliable). This anchors the receipt's position, scale, and orientation.
2. **Crop** — cut out only the region where the expiry paragraph sits, relative to that anchor.
3. **Enhance** — grayscale, boost contrast, threshold to pure black and white. The document is grey ink on grey paper; this converts faint text to solid.
4. **Pass 2** — OCR the enhanced crop alone.

OCR performs substantially better on a tight single-paragraph crop than on a full page. Enhancement runs only on the small crop — processing a full 4000 px image in Dart is slow, a 400 px crop is immediate.

**Deferred deliberately.** Guided capture plus full-resolution capture may resolve this on its own, and that should be tested first.

---

## 13. Empirical basis

The design above is grounded in a diagnostic ML Kit run against a real LTO Official Receipt — a motorcycle registration, photographed as a fold-creased photocopy. Personal details are omitted here and the sample document is **not committed to this repository**.

**Probe conditions:** 1495 × 1052 px, Latin script, 1158 ms, 68 blocks.

### Findings

| # | Finding | Design consequence |
|---|---|---|
| 1 | `Plate No: 130301` read at **0.90 confidence** on a single line | Plate extraction is reliable; anchor on the label |
| 2 | The expiry was **entirely absent** — `"valid until"` and `01/2026` never appeared in the output | Motivates guided capture, full resolution, and Cue C |
| 3 | The one surviving fragment, `"enewal on 11/20/2"`, had **wrong digits** (paper reads `01/22`) | Small-print digits cannot be trusted even when apparently read |
| 4 | Small print corrupted throughout: `23-200161-6552388` for `23-200101-6652380` | Confirms the resolution hypothesis |
| 5 | Rotated CR text produced tall, narrow boxes; OR text wide, short | Yields the height-vs-width filter |
| 6 | Blocks returned in arbitrary order | The flat "full text" output is unusable; sort by position |
| 7 | Confidence populated on every line, `0.31`–`0.90` | Usable as a blur signal |
| 8 | The plate's last digit correctly predicted the renewal month, and the second-to-last the week | Establishes Cue C — pending a second sample |

**The clear pattern: large print survives, small print is mangled.** The plate is readable because it is printed large. Everything the design depends on follows from that observation.

> The test sample's registration expired in `01/2026`. Testing against it *should* produce an expiry failure — that is correct behaviour, not a defect.

---

## 14. Limitations

For the Scope and Limitations chapter. Stating these directly is stronger than having them raised during a defense.

1. **Forged or altered documents cannot be detected.** No LTO or LTMS integration exists. The system confirms a document is *readable and internally consistent*, not that it is authentic.

2. **Vehicle ownership is not confirmed — by design.** Campus users commonly drive vehicles registered to family members, so the name on the OR is deliberately excluded from checking.

3. **Identity is not verified.** Final approval rests with an administrator, who reviews the government ID by eye.

4. **Registration validity is a one-time snapshot.** Checked at enrolment only; lapses after approval are not monitored.

5. **Extraction accuracy depends on photograph quality.** Faded, folded, or poorly lit documents may be unreadable. **The system never rejects a submission on its own** — unreadable documents fall back to human review.

6. **Motorcycle plates are the harder case for ALPR.** Philippine motorcycle plates are frequently stacked across two rows, which is more difficult for plate recognition than single-row car plates.

Point 5 is the strongest position in this list. The system's worst-case behaviour is *asking a human* — never denying a legitimate applicant.

---

## 15. Open items

- [ ] Test the QR code and barcode — may make OCR extraction unnecessary
- [ ] Confirm the plate-digit renewal rule (Cue C) against a second OR from a different vehicle
- [ ] Re-run the probe on a full-resolution, receipt-only photograph to test the pixel-density hypothesis
- [ ] Fix the OR/CR upload field mix-up in the registration screen
- [ ] Add the plate photo upload step
- [ ] Remove the selfie picker
- [ ] Reshape `DocumentVerification`, register it in `AppDbContext`, and create the migration
- [ ] Build the guided capture screen
- [ ] Implement the rules service in `AimPark.API`
