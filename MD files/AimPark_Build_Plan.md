# AimPark — Consolidated Build Plan

**Created:** 2026-07-29
**Covers:** QA remediation (20 tester items) + Smart Slot Allocation + ESP32 gate integration

---

## 0. Scope

Two workstreams, one sequence:

1. **QA remediation** — 20 tester items (15 from the mobile round, 5 from the admin round), plus 2 bugs found during analysis that testers did not report
2. **Smart Slot Allocation** — headline capstone feature, currently not implemented in any form

Deployment target is a **miniature/scale model**, not the physical STI Baliuag lot. Gate hardware is an **ESP32** posting to the API on RFID scan.

Estimated build: **~8 working days**, excluding deferred items.

---

## 1. Root causes

Three systemic defects account for most of the findings. Fixing these fixes many symptoms at once.

### ① The notification system cannot notify one user

`Notification` has `TargetRole` but no `TargetUserId`. The only producer is the admin broadcast endpoint. `ViolationService.IssueAsync` does not inject `INotificationService` at all — issuing a violation creates zero notifications and zero pushes. Same for payment-on-exit and registration decisions.

**Consequence:** the appeal feature is unusable, because users never learn they were penalised.

### ② The client fetches once and never again

`UserShell` wraps all four tabs in an `IndexedStack`, so every tab stays mounted for the session and Riverpod's `autoDispose` never fires. Providers `build()` once and freeze. There is no polling, no WebSocket, and no lifecycle observer anywhere — the only `Timer` in the app is the OTP resend cooldown.

**Consequence:** correct backend behaviour looks broken. This is the "need to restart the app" bug.

### ③ Enumerated values are free strings with no shared source of truth

| Client sends | Server expects | Status |
|---|---|---|
| `Vandalism`, `Theft`, `Accident`, `Blocked Slot` | `Safety`, `VehicleDamage`, `SuspiciousActivity` | **Confirmed bug** (red) |
| `Car`, `Motorcycle` (registration) | `Motor`, `4 Wheels` (slots/admin) | **Latent** — blocks allocation |

**Consequence:** one live red bug, one blocker for smart allocation. Will keep recurring until there is one canonical vocabulary.

### Cross-cutting: invisible affordances in the admin panel

Incidents and Pending Registrations both use `onSelectChanged` for row navigation with **no visual cue** — no button, no chevron, `showCheckboxColumn: false`. Testers reported the incident detail view as *missing* when it is fully built and working. This is inflating the bug count with features that already exist.

---

## 2. Phases

### Phase 1 — Stop the bleeding · ~0.5 day

**Why:** unblocks group testing immediately. Nothing here depends on anything else.

| # | Change | Solves |
|---|---|---|
| 1.1 | `RefreshIndicator` on Home tab | 🔴 "need to restart" — *partially*; makes it manually refreshable |
| 1.2 | Remove logout icon from dashboard header | 🟢 logout placement + hidden push bug |
| 1.3 | Logout confirmation dialog | 🔴 no logout confirmation |
| 1.4 | Fix incident categories | 🔴 only "Other" works |
| 1.5 | `+10` → `+10 pts`, add `onTap` → payment | 🟡 confusing "+", 🟡 tap-to-pay |

**1.2 also fixes a bug testers did not report:** the dashboard logout skips `unregisterOnLogout()`, which the profile logout calls. Logging out via the home icon leaves the device registered for push — the next account on that phone can receive the previous user's notifications.

**1.5 is not a one-liner:** `ParkingHistoryEntryResponse` carries no payment reference, so it needs a `PaymentId` field added. An open session has no payment yet and must degrade gracefully.

---

### Phase 1b — Admin quick wins · ~2 hrs

**Why:** two of these unhide features that already work. Highest ratio of perceived-fix to effort in the whole plan.

- **Row-click affordance** on Incidents and Pending Registrations — trailing "View" button column. *Unhides working detail views.*
- **Payments detail / receipt dialog** — **no backend work needed.** The list response already returns source, slot, entry/exit, duration, rate, amount, status, created and paid timestamps.

---

### Phase 2 — Kill the enum bug class · ~2 hrs

**Why:** prerequisite for allocation. Vehicle type must match before any type-aware logic can work.

- `VehicleType` becomes a real enum server-side, one canonical spelling
- Mobile registration and admin panel updated to match
- Migrate existing `Vehicle` rows

---

### Phase 3 — Smart Slot Allocation v1 · ~1.5 days

**Why:** headline capstone feature, currently absent entirely.

**Layout (confirmed):** 2 gates × 10 slots. Each gate: 2 four-wheel + 8 motorcycle. Total 20 — matches existing seed count.

**Schema**
- `ParkingSlot.Gate` (int: 1 or 2)
- `ParkingSlotStatus.Reserved`
- `ParkingSlot.ReservedForUserId`, `ReservedUntil`

No `DistanceRank` — on a miniature there is no meaningful walking distance, so it would be false precision.

**Seed** — same 20 static GUIDs, new codes (preserves existing `ParkingLog.SlotId` references in the test DB):

| Gate | Codes | Type |
|---|---|---|
| 1 | `G1-C1`, `G1-C2` | 4 Wheels |
| 1 | `G1-M1` … `G1-M8` | Motor |
| 2 | `G2-C1`, `G2-C2` | 4 Wheels |
| 2 | `G2-M1` … `G2-M8` | Motor |

**Algorithm — two stages, not a weighted sum**

```
Stage 0 — tiered vehicle filter
    Car:        4 Wheels slots only. No fallback.
    Motorcycle: Tier A → Motor slots
                Tier B → 4 Wheels slots, only if all 16 Motor slots taken

Stage 1 — gate with most free compatible slots
          tie-break → user's last gate

Stage 2 — lowest SlotCode in that gate
          skip slots freed < 2 min ago
```

Deliberately **not** machine learning. With 20 slots and no training data an ML model is unexplainable and undefensible at a panel. A two-stage rule narrates in one sentence: *"Gate 2 has five free motorcycle slots against Gate 1's one, so we route you to Gate 2, position M3."*

The tiered filter honours the rule that motorcycles may use car slots, while ensuring it only triggers when the lot is ~80% full — so four scarce car spaces are never wasted while motorcycle slots sit empty.

**Concurrency — the part that will bite**

Read-then-write is racy. Use a conditional update and check the affected row count:

```csharp
var claimed = await _db.Set<ParkingSlot>()
    .Where(s => s.Id == candidateId && s.Status == ParkingSlotStatus.Available)
    .ExecuteUpdateAsync(setters => setters
        .SetProperty(s => s.Status, ParkingSlotStatus.Reserved)
        .SetProperty(s => s.ReservedForUserId, userId)
        .SetProperty(s => s.ReservedUntil, DateTime.UtcNow.AddMinutes(10)), ct);

if (claimed == 0) { /* lost the race — try next candidate */ }
```

Retry down the ranked list, cap at 3 attempts, then return lot-full.

**Hold expiry — lazy, not a background service.** A hold past `ReservedUntil` is treated as free on read. Mirrors the existing pattern in `LogEntryAsync` where an expired RFID suspension is lazily reactivated. Nothing extra resident in memory.

**Endpoint:** `POST /api/parking/recommend` — returns the pick plus runners-up, starts the hold.

**Admin parking grid** *(from tester feedback)* — replace the `DataTable` in `parking_screen.dart` with a gate-grouped visual grid. Satisfies the "Real-Time Parking Visualization" spec item, which a table does not. Built here rather than earlier because it should be laid out by `Gate`, which does not exist until this phase.

**Verify:** force Gate 1 full via the existing admin status endpoint; confirm routing to Gate 2; fire two concurrent requests and confirm different slots.

#### Phase 3b — scanning gate (amendment)

Not in the original spec; surfaced during review. Allocation assumed the driver had not yet chosen a gate, which is right for the in-app suggestion and **wrong at the barrier** — a rider scanning at Gate 1 could be sent to Gate 2 while Gate 1 had space, with the boom already up in front of them.

- `Gate` added to `LogParkingEntryDto`; `ClaimForEntryAsync(userId, atGate, ct)` ranks the scanning gate first and only falls back when it is full
- Reason text leads with the diversion when one happens: *"Gate 1 is full for your vehicle — proceed to Gate 2."*
- Admin **Log Entry** gains a "Scanning at gate" dropdown; slot picker relabelled to "Assign automatically"
- Admin **Add Slot** gains a gate picker — previously every hand-added bay silently landed at Gate 1

One parameter, two sources: set by hand during testing, supplied by the ESP32's own identity in production. No logic changes between the two.

---

### Phase 4 — Device authentication for the ESP32 · ~0.5 day

**Why:** JWTs expire in 60 minutes (`appsettings.json`) and there is **no refresh-token mechanism** in the API. An ESP32 with an embedded JWT stops working one hour into demo day, and cannot "go to a login screen."

- `GateDevice` entity — hashed API key, gate number, revocable
- `X-Api-Key` authentication on gate-only endpoints
- Resolve `ParkingLog.LoggedByUserId` for a device caller
- **Machine-readable result codes**, not prose:

```json
{ "result": "ASSIGNED", "slotCode": "G2-M3", "gate": 2, "logId": "..." }
{ "result": "LOT_FULL" }
{ "result": "RFID_SUSPENDED" }
```

The alternative — embedding Security credentials and re-logging in on 401 — is ~1 hour instead of ~4, but puts retry logic in firmware, the least comfortable place to debug. With an API key the ESP32's HTTP layer is *set header, POST, read response*. Simpler firmware is the lower-risk demo.

**Must land before firmware is written.**

---

### Phase 5 — Notifications that actually work · 1.5 days

**Why:** two red items. Root cause ①.

- `Notification.TargetUserId` + migration
- Wire `INotificationService` into `ViolationService.IssueAsync`, payment creation, registration approve/reject
- Broaden the push listener to invalidate violations, payments and history — not just notifications
- Refresh-on-resume via `WidgetsBindingObserver` (safety net for root cause ②)
- Unread badge on the bottom nav

**No polling.** Four tabs × N testers polling every 10s is exactly the load to avoid. Push plus refresh-on-resume gives better latency for free.

**Verify:** issue a violation from admin; confirm it reaches the user's phone in ~10s with no manual refresh.

---

### Phase 6 — Remaining flows · ~3 days

| Item | Priority |
|---|---|
| Pending/rejected status screen (backend already returns full status; client discards it) | 🔴 |
| T&C checkbox + `TermsAcceptedAt` on `User` | 🔴 |
| Evidence attachments on appeals (`SubmitAppealDto` is text-only) | 🔴 |
| **Violation detail view + `UpdateAsync` + expose override fields** | 🔴 |
| `DueAt` on payments + deadline display | 🟡 |
| Edit / withdraw incident reports (needs `Withdrawn` status) | 🟡 |

**On violations:** `ViolationService` has `IssueAsync`, `DismissAsync`, `DecideAppealAsync` and **no `UpdateAsync`** — a typo can only be fixed by dismiss-and-reissue, leaving a bogus record in the user's history. Separately, `IssueViolationDto` supports `PenaltyAmountOverride`, `SuspensionTypeOverride`, `SuspensionDaysOverride` and `ParkingLogId`, and the Issue dialog exposes **none** of them. The API capability is built and unreachable.

---

### Phase 7 — Allocation v2 · ~0.5 day

**Depends on:** Phase 4 + Phase 5

- Assign a slot at RFID entry inside `LogEntryAsync`
- Push the assignment to the user's phone
- Admin UI for gate/slot management

---

### Deferred

| Item | Reason |
|---|---|
| Dark mode | All screens use `AppColors.*` statics rather than `Theme.of(context)` — ~25-screen refactor |
| Help / tutorial section | Nothing exists; low risk to defer |
| Per-type parking rates | Pending professor's guidance; two-row seed change when decided |
| Ultrasonic sensor occupancy | Hardware-gated. More feasible on a miniature than a real lot |
| ALPR | Spec item, not started |

### Parked

| Item | Note |
|---|---|
| Registration filters | Set aside pending clarity on what to filter. Search on name/email is free (client-side); status filtering needs a backend parameter |

---

## 3. Sequence

```
Phase 1   Stop the bleeding         0.5d   ← start here, unblocks testers
Phase 1b  Admin quick wins          0.25d  ← unhides two working features
Phase 2   Enum vocabulary           0.25d  ← prerequisite for Phase 3
Phase 3   Allocation v1 + grid      1.5d
Phase 4   Device auth               0.5d   ← before any firmware
Phase 5   Notifications             1.5d
Phase 6   Remaining flows           3.0d
Phase 7   Allocation v2             0.5d
                                    ─────
                                    ~8.0 days
```

---

## 4. Risks

**Schema changes in Phases 3, 4, 5.** Run each migration against a copy of the database first.

**Demo-day networking.** If the API is cloud-hosted and venue WiFi is unreliable, the ESP32 gate dies. Local running is already supported via `HOW_TO_RUN.txt` — plan to run the API on the LAN and point the ESP32 at a local address.

**ESP32 TLS.** Needs the CA cert in firmware and breaks on cert rotation. `setInsecure()` is pragmatic for a LAN demo — make it a conscious, defensible decision.

**"Lot full" is normal for cars, not an edge case.** Four car slots facility-wide, and motorcycle overflow can consume them. Needs a real UI answer, not an error toast.

**Nothing has been verified on a device.** All findings are from source reading. Phase 1 should be confirmed on hardware before Phase 3 starts.

---

## 5. Open decisions

| Question | Owner | Blocking? |
|---|---|---|
| Did testers actually see the incident photo pickers? They exist and work — the real gap may be that *appeals* have no evidence field | Testers | Phase 6 only |
| "Supposed to be automatic but it's not in a dropdown" — read as *slot assignment should be automatic rather than a manual picker*. Phase 3 solves it under that reading | Testers | No |
| Per-type parking rates | Professor | No |
| Lot-full UX for cars — nearest alternative? queue position? | You | Phase 3 polish |

**Already decided:**
- Motorcycles *may* use car slots; cars may *never* use motorcycle slots — implemented as a tiered filter
- Miniature deployment, not the physical lot
- ESP32 drives the gate
- Single flat rate for now
- Registration filters parked
