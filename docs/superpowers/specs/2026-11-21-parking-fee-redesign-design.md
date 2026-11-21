# Parking fee redesign — design

Date: 2026-11-21
Status: draft, waiting for review
Screens: https://claude.ai/artifact/FDaLSvagRaJymLKdeujjHJ (10 phone screens, one example visit)

## Why

Testing on Nov 19–21 showed that the fee math was right but drivers could not
follow it, and four real bugs:

1. A visit with no confirmed bay is free. `RateForAsync` takes the vehicle type
   from the bay; no bay → no rate → ₱0/hr.
2. A ₱0 bill is saved as `Pending`, so the app shows "Amount due ₱0.00" and a
   "Pay ₱0.00" button.
3. The bill made at the exit tap is never priced again. Tap out, wait, pay the
   old amount, leave: the time in between is free.
4. "Paid ₱20" never says when, or what time it covered. No bill says what
   time it covers.

## The rules (agreed with the owner)

1. **Entry.** The gate checks for unpaid fees and violations, as it does now.
   Nothing is paid at entry.
2. **First hour is flat.** Entry to entry + 60 min costs one hour's rate `R`
   for the vehicle type (car ₱20, motorcycle ₱30), whether the stay is 1 second
   or 59 minutes. It must be paid before exit.
3. **After the first hour, per minute.** Every minute after minute 60 costs
   `R ÷ 60`, paid or not.
4. **7-minute grace after each payment.** The meter pauses for 7 minutes after
   a payment is settled. Grace minutes are never charged. If the driver is still
   inside after the grace, the meter runs again from the end of the grace.
5. **Paying inside the first hour** covers the driver until whichever is later:
   the end of the first hour, or 7 minutes after paying. This falls out of
   rules 2 and 4; it needs no extra code.
6. **Every bill says what it covers:** from–to time, minutes, the calculation,
   when it was paid, and when its grace ends.
7. **Small bills stay exact.** A ₱4.67 bill is ₱4.67. There is no minimum and
   no rounding up. (Owner's decision, 2026-11-21.)

The admin sets only `R` per vehicle type. The old "minimum fee" no longer
affects pricing.

## How the fee is worked out

One pure function prices a visit. Everything else (live fee, gate, bills,
receipts) calls it, so they can never disagree.

```
Price(entryTime, at, rate, settledPaymentTimes, graceMinutes) -> FeeBreakdown
```

Time is counted in whole minutes from entry; a started minute counts as a
whole one (same as today).

1. Minute `m` is the minute that ends `m` minutes after entry. `at` falls in
   minute `ceil((at − entry) / 1 min)`.
2. Minutes 1–60: the **first hour**. Flat `R`. Charged as soon as the visit
   starts.
3. Each settled payment at time `p` makes a **grace pause** over the 7 minutes
   after the minute `p` falls in.
4. Minutes after 60 that are not in any grace pause are **per-minute** minutes,
   each `R ÷ 60`.
5. Total = `R` + per-minute minutes × `R ÷ 60`, rounded to the centavo.
6. Owed now = total − (sum of settled bills), never below zero.

`FeeBreakdown` holds the total, the per-minute count, and an ordered list of
**segments**: `{kind: FirstHour | PerMinute | Grace, from, to, minutes, amount}`.
The app draws the breakdown and the visit timeline straight from this list
(screens 4, 6, 9).

Check against the example on the canvas (car, ₱20/hr, entry 1:02 PM):

| Moment | Segments | Total | Paid | Owed |
|---|---|---|---|---|
| 1:41 PM | first hour | ₱20.00 | ₱0 | ₱20.00 |
| 3:32 PM | first hour, per-minute 2:02–3:32 (90) | ₱50.00 | ₱20 | ₱30.00 |
| 3:34 PM | … + grace 3:32–3:39 | ₱50.00 | ₱50 | ₱0.00 |
| 3:52 PM | … + per-minute 3:39–3:52 (13) | ₱54.33 | ₱50 | ₱4.33 |
| 3:53 PM | … + per-minute 3:39–3:53 (14) | ₱54.67 | ₱50 | ₱4.67 |

## Gate rule

The exit gate opens when **owed now is ₱0**. That one test covers "paid inside
the first hour", "inside the grace" and "nothing to pay". It replaces the
special cases in `HoldForPaymentAsync` (paid-ahead, overstay, grace window).
A guard's manual release stays as it is.

## Bills

A bill is made when the driver asks to pay (app "Pay now") or taps out owing
money. It is for **owed now**, and it records what it covers.

Two new nullable columns on `PaymentTransactions` (additive, safe on the
shared database before merge):

- `CoversFrom` — end of what earlier bills covered (entry time for the first).
- `CoversTo` — the moment the bill was priced.
- `GraceUntil` is not stored. Responses work it out as paid time + grace.

Behaviour:

- An open (`Pending`) bill is **priced again** at every gate tap and every
  checkout start, so it never freezes (bug 3).
- A bill whose checkout is already `Processing` is not re-priced. Its checkout
  carries the old amount; anything added after it is a new bill.
- **No ₱0 bills.** When owed now is ₱0 at exit, no bill is created (bug 2).
- Bills for past visits keep their stored amounts; nothing is re-priced
  after exit.

## Rate lookup

`RateForAsync` uses the visit's own `VehicleType` (stored on `ParkingLogs`),
with the bay's type only as a fallback, then the default rate (bug 1). The
"rate locked at entry" rule (`PreviousRatePerHour`) stays.

## Live fee for the app

`LiveFeeResponse` gains:

- `segments` — the list above.
- `firstHourEndsAt`, `graceUntil` (latest, if any), `meterState` —
  `FirstHour | Running | Paused`.
- `payments` — each settled bill: amount, paid time, method, covers from–to.

`MinimumFee` and `MeteredSoFar` are dropped from the response.

## Screens (see canvas)

| # | Screen | Where in the app |
|---|---|---|
| 1 | Parked, first hour: covers 1:02–2:02 PM, minutes left, pay button | live fee card |
| 2 | Paid inside first hour: "free to leave", countdown to 2:02 PM | live fee card |
| 3 | Visit receipt, left inside first hour | parking history detail |
| 4 | Meter running: line-by-line breakdown, total − paid = owed | live fee card |
| 5 | Paid, grace countdown "Leave by 3:39 PM" | live fee card |
| 6 | Grace over: grace shown as free, only new minutes owed | live fee card |
| 7 | Tapped out unpaid: bill priced at the tap, "priced again next tap" | bill detail + gate notice |
| 8 | One bill receipt: covers, calculation, grace, visit, "bill 2 of 3" | payment detail |
| 9 | Whole visit: timeline of segments, total | parking history detail |
| 10 | Each payment row says what it covers (built inside the existing day sections; full grouping by visit is left for later) | payments list |

Every time shown with a date where the day could be unclear.

## Admin panel

- Rate form: one field per vehicle type, "Hourly rate (first hour is charged
  in full)". The minimum-fee field is hidden. The column stays in the
  database for now.
- Payments table: add "Covers" (from–to) and "Paid at" columns.

## Gate and local site server

The site server runs the same API code, so it gets the new pricing for free.
Two things to carry over:

- `GateOptions.PaidExitGraceMinutes` becomes 7 (config + default).
- The site sync (`SnapshotApplier`, `EventIngestor`) must copy the three new
  bill columns.

## Site sync

The site re-prices an open gate bill at every tap. When the cloud merges a
site bill that is still Pending, it takes the site's price and coverage if the
site's `CoversTo` is later than its own, so the app never charges a stale
amount.

## Not in scope

- The ₱20 minimum of GCash/Maya. Small bills stay exact (rule 7). With
  Simulated payments this works today; with live PayMongo a bill under ₱20
  would have to be paid to the guard. Revisit when PayMongo goes live.
- Re-pricing past visits.

## Testing

- Unit tests on `Price(...)` for every row of the example table, plus: a
  1-second visit (₱20), a visit leaving at exactly 60 min, paying at minute 58
  (covered to minute 65), two payments inside one grace, a ₱30/hr motorcycle,
  and a rate of 0.
- Service tests: gate opens only at owed ₱0; an open bill is re-priced at a
  second tap; no ₱0 bill at exit; a visit with no bay is charged the car rate.
- The owner runs the device tests on the app and the gate.
