# Light ML for the Mobile App — Brainstorm

**Status: exploratory. Nothing decided, nothing started.** Captured 2026-08-24 so the
thread can be picked up later.

Starting question: *"what light ML can we add into the mobile app? I'm thinking the user
gives his/her schedule, then the app suggests the best time to park."*

---

## What data we already have

No new tracking is needed for most of this. The relevant entities exist today:

- `ParkingLog` — `UserId`, `SlotId`, `EntryTime`, `ExitTime`, `LoggedByDeviceId`
- `ParkingSlot` — `SlotCode`, `Gate` (1 or 2), `VehicleType`, `Status`
- `Violation` — links to `ParkingLog` + `PolicyRule`, has `PenaltyAmount`
- `User` — affiliation, RFID card
- Push delivery already built: `FcmPushSender`, `DeviceToken`

Physical scale: 2 gates, 20 slots, hundreds to low-thousands of users.

## On the original schedule idea

It's sound, but it splits into two halves and only one is ML:

- **Schedule = input.** User enters class hours (or we infer them from their own entry
  history — see idea 2). This gives the arrival *window* to score.
- **ML = the occupancy curve.** Learn P(full) per gate per 15-min bucket per day-of-week
  from `ParkingLog`. Output: *"Your 7:30 class — arrive by 6:55, Gate 2. By 7:15 the lot
  is usually 92% full."*

At our data scale this is a smoothed histogram, not a deep model. That is fine, but it
should be *described* honestly ("time-bucketed occupancy model") rather than oversold.

---

## Idea list

### Uses data we already collect

1. **Occupancy forecast + best-arrival-window** — the original idea, refined. Features:
   day-of-week, time bucket, gate, vehicle type, week-of-semester. Output: predicted %
   full. Renders as a green/amber/red heat strip by hour.

2. **Personal habit model** — *"you usually arrive 7:08 on MWF."* Per-user, ~20 rows,
   median + variance over that user's own entries. Powers a 6:40 push: *"Leave 12 min
   earlier than usual — Gate 1 is filling faster than normal today."* Roughly 30 lines of
   code and demos very well because it feels personal.

3. **Turnover ETA** — *"a slot frees up in ~7 min."* Regress `ExitTime - EntryTime` on
   entry hour, affiliation, vehicle type, day. Then predict how many parked cars leave in
   the next 15 min. Turns "lot full, go away" into "wait 6 minutes."

4. **Smart gate steering** — upgrade `ParkingAllocationService` to pick the gate with the
   most free capacity at the user's *predicted arrival time*, not right now. Same model as
   idea 1, different consumer.

5. **Overstay risk warning** — mid-session, predict whether the user exceeds allowed
   duration. Push at 80% risk: *"On track to overstay by ~25 min (₱X)."* Ties ML directly
   into the existing violations module; admins get a risk-sorted queue.

6. **RFID anomaly detection** — card sharing / buddy punching. Same card entering while
   already inside, impossible turnaround times, vehicle-type mismatch against the
   registered vehicle. Rules + z-score baseline, or Isolation Forest. Gives the capstone a
   security angle; flags surface in the admin panel.

### Reuses ML Kit (already in the mobile stack)

7. **Document quality gate** — blur / glare / edge-crop check on RAF, licence and OR
   *before* upload. Improves the existing OCR pipeline and cuts admin rejections.
   Cheapest win on the list. Note: needs no ML — variance-of-Laplacian on a downscaled
   greyscale frame via the pure-Dart `image` package.

8. **Incident photo auto-tagging** — image labeling on `IncidentEvidence` suggests a
   category (scratch, dent, blocked driveway, flooding); admin confirms. Feeds triage.

9. **Incident / appeal text triage** — classify the free-text `Description` on
   `Incident` and `ViolationAppeal` into category + urgency so the admin queue self-sorts.

### Considered and set aside

- Payment / no-show prediction — poor optics for a school project.
- Semantic search or an in-app LLM assistant — not "light."

---

## Shortlist

**Ideas 2 + 3 + 5** form one coherent story: the app knows your habit, tells you when to
leave and which gate, tells you to wait if a slot is about to free, and warns you before
you overstay.

Plus **idea 7** as a separate quick win, since ML Kit is already wired into
`aimpark_mobile/lib/core/ocr/document_scanner.dart`.

---

## Two constraints to settle before building

**Where it runs.** Server-side C# for ideas 1–6 (the data lives there, retrain nightly,
ship the app a small JSON forecast). On-device only for the camera work in 7–8. Don't ship
a model to the phone to predict something the server already knows.

**Cold start.** There is no historical parking data yet, and nothing above works without
it. Either seed a synthetic semester (realistic bimodal arrival peaks) so the feature is
demoable, or design every prediction to fall back to a sane default until ~2 weeks of real
data exists. This is what usually kills ML capstone features — not the model.

---

## Tooling

### Step 0 — no new tools

The "best time to park" feature is a SQL query before it is a model:

- **EF Core / raw SQL** — `date_trunc`, `generate_series`, window functions over
  `ParkingLog` to build occupancy by (day-of-week × 15-min bucket × gate). Store as a
  summary table or a materialized view refreshed nightly.
- **Synthetic history seeder** — `Bogus` (NuGet) is convenient, but plain loops with two
  arrival peaks is enough. Behind a dev-only admin endpoint. Note there is already an
  `AimPark.Seeder` project in the solution that may be the right home.

Worth trying to ship idea 1 on this alone. If the histogram looks right, the feature is
delivered, and *then* we judge whether a model beats it.

### Step 1 — server-side ML, if step 0 isn't enough

**ML.NET**, because it is in-process C#: no Python sidecar, no second deploy target, no
ONNX plumbing, trains in seconds at our volume, serialises to a `.zip` loaded at startup.

| Package | Purpose |
| --- | --- |
| `Microsoft.ML` | Core pipeline + trainers |
| `Microsoft.ML.FastTree` | Boosted trees — dwell-time regression (3), overstay classification (5) |
| `Microsoft.Extensions.ML` | `PredictionEnginePool`. **Not optional** — raw `PredictionEngine` is not thread-safe |
| `Microsoft.ML.TimeSeries` | Only if going time-series (`SsaForecasting`) or SR-CNN anomaly detection (6). Skip initially |

Skip `Microsoft.ML.LightGbm` — native binaries for no gain at a few thousand rows.

**Retraining:** a `BackgroundService` + `PeriodicTimer` from the BCL. Nightly retrain,
write the `.zip`, swap the pool. Hangfire adds a dashboard at the cost of a schema — not
worth it here. Caveat: if the API is deployed somewhere that idles containers to sleep, a
timer won't fire reliably; trigger from an admin endpoint or external cron instead.

### Step 2 — mobile

Mostly nothing new; ideas 1–5 are one more Dio call and a Riverpod provider.

- `fl_chart` — occupancy heat strip / hourly bars
- `image` (pure Dart) — blur detection for idea 7
- `google_mlkit_image_labeling` — idea 8; same family as the existing
  `google_mlkit_text_recognition`, so no new native setup
- **Not** `tflite_flutter` — nothing here needs an on-device model

### Data exploration

Use the Supabase SQL editor and its chart view. Avoid standing up a Python/pandas notebook
— a second toolchain to maintain for work that gets rewritten in C# anyway.

---

## Why not TensorFlow or PyTorch

Not that they're worse — they're aimed at a different problem.

1. **Language boundary.** Both are Python; the API is C#. That means either a second
   service (FastAPI/Flask) the .NET API calls over HTTP — two runtimes, two deploys, auth
   between them, and on a free tier a second thing that sleeps and cold-starts — or train
   in Python and export **ONNX** to serve via `Microsoft.ML.OnnxRuntime`, which avoids the
   second service but still keeps a Python environment around for every retrain. Either
   way the ops surface roughly doubles, and that is the expensive part for a solo dev on a
   deadline.

2. **The data is tabular and small.** Deep learning earns its keep on unstructured data
   (images, audio, text, long sequences) and on lots of it. Occupancy prediction is ~6
   features over a few thousand rows. On tabular data at that scale, gradient-boosted trees
   consistently match or beat neural nets — a well-documented result, not a preference. A
   net on 2,000 parking rows overfits, and the time goes into regularisation instead of
   the feature.

3. **Weight.** PyTorch CPU-only wheels run a few hundred MB; with CUDA, multiple GB.
   ML.NET is three NuGet packages inside the container we already build.

### Where they would be the right call

- **Custom on-device vision** — incident-photo classification (idea 8) trained on *our*
  labelled photos (scratch / dent / blocked / flooded) is a genuine Keras transfer-learning
  job (MobileNetV3 + new head) exported to TFLite via `tflite_flutter`. ML Kit's generic
  labeler won't know "blocked driveway."
- **Custom plate recognition**, if ML Kit's text recognizer proves unreliable on PH plates.
- **Sequence models** over occupancy history — but that needs a year-plus of real data
  before an LSTM beats a lookup table.

### On capstone optics

If the worry is that the panel wants to see "real ML":

- **We already run TensorFlow.** `google_mlkit_text_recognition` is TensorFlow Lite under
  the hood — that is how ML Kit works. It is accurate to say the app runs on-device TF Lite
  inference for document OCR.
- **"Why not a neural net" defends better than a bad neural net.** Saying *"tabular, ~3k
  rows, 6 features — boosted trees outperform deep nets in this regime, and inference is
  in-process so there's no second service to keep alive"* reads as engineering judgment. An
  overfit LSTM predicting parking occupancy invites a question about the validation split.

### If PyTorch is wanted anyway

Middle path that doesn't wreck the architecture: train in Colab (free GPU, and the notebook
is showable to the panel), export ONNX, serve in .NET with `Microsoft.ML.OnnxRuntime`. One
runtime in production, Python only at training time. Legitimate — as long as it's adopted
for the training story, not for capacity we don't need.

---

## Open questions for next session

- Which of the shortlist actually gets built, and does it fit before the October deadline?
- Synthetic seed data vs. a real pilot window to collect logs — which, and when?
- Does the class schedule get typed in by the user, or inferred from entry history?
