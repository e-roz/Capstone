# Parking Fee Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Charge parking as "first hour flat, then per minute, with a 7-minute free grace after each payment", and show drivers exactly what every bill covers.

**Architecture:** One pure function (`ParkingFeeMath.Breakdown`) prices a whole visit and returns it as ordered segments (first hour, per-minute runs, grace pauses). A small `VisitPricing` class feeds it the rate and the settled payments; the gate, pay-ahead, checkout, live fee and receipts all go through it, so no two places can disagree. Bills store the time range they cover; an open bill is re-priced every time it is touched.

**Tech Stack:** ASP.NET Core 8 + EF Core (Npgsql) API, xUnit tests with the EF in-memory provider; Flutter (Riverpod, go_router) mobile app and admin panel.

**Spec:** `docs/superpowers/specs/2026-11-21-parking-fee-redesign-design.md`. Screens: https://claude.ai/artifact/FDaLSvagRaJymLKdeujjHJ

## Global Constraints

- First hour = one hour's rate `R` for the vehicle type, flat, charged from the first second.
- After minute 60: each started minute costs `R ÷ 60`. Time is counted in whole minutes from entry; a started minute counts.
- Grace after each settled payment: **7 minutes**, never charged. Config key `Gate:PaidExitGraceMinutes`, default `7`.
- Small bills stay exact: no minimum, no rounding up. Amounts rounded to the centavo (`Math.Round(x, 2)`).
- `MinimumFee` no longer affects pricing. The column stays in the database (no destructive migration).
- The only migration is additive (two nullable columns). Do **not** run `dotnet ef database update`: the database is shared with production; the owner applies it.
- The owner runs all tests and device checks. Executors write the tests, then check compilation only: `dotnet build AimPark.API/AimPark.API.sln` and `flutter analyze` in `aimpark_mobile` and `aimpark_admin`. Never `dotnet test`, `flutter test`, `flutter run` or `flutter build`.
- Say what a command is for before running it.
- Copy rules (mobile): sentence case, no exclamation marks, every time that could be on another day shows its date.
- Commit after each task on branch `feat/fee-redesign` (create it from `main` first). Do not push.

## Review Focus

1. **A visit spanning the deploy.** Bills made before this change have no `CoversTo`. Pricing must fall back to `PaidAt` and still never charge the first hour twice. Test in Task 4.
2. **The site server learning a payment only from the snapshot** (bill `Pending` locally, settled in the cloud, no `PaidAt`). Grace must start "now", and the gate must open. Covered by the existing `At_the_site_a_bill_paid_ahead_in_the_app_reaches_the_gate_through_the_snapshot`, re-checked in Task 6.
3. **A checkout already open (`Processing`) when the driver taps the gate.** It must not be re-priced. Only time added after it goes in a new bill. Test in Task 5.
4. **Paying at minute 58**, where the grace runs past the end of the first hour. Covered to minute 65, charged from minute 66. Test in Task 1.
5. **An old, closed visit shown in the new visit screen** whose stored bills do not match the new math. The app must show the bills and hide the timeline, never a wrong total. Flag `BreakdownMatchesBills`, Task 6 and Task 12.

---

## File Structure

API (`AimPark.API/AimPark.API/`):
- `Helpers/ParkingFeeMath.cs`: **rewrite**. Pure pricing: `Breakdown(...)`, plus the types `FeeBreakdown`, `FeeSegment`, `FeeSegmentKind`, `MeterState`.
- `Services/VisitPricing.cs`: **new**. Loads the rate and bills for one visit, decides which bills are settled, calls `Breakdown`, returns `VisitPrice`.
- `Services/PaymentService.cs`: **modify**. Rate lookup fix, `BillOwedAsync` replaces four raise/reprice methods, checkout re-prices, response carries coverage.
- `Interfaces/IPaymentService.cs`: **modify** to match.
- `Services/ParkingHistoryService.cs`: **modify**. Gate hold, pay-ahead, live fee, history "leave by", exit all use `VisitPricing`.
- `Entities/PaymentTransaction.cs`: **modify**. Add `CoversFrom` and `CoversTo`.
- `Migrations/<timestamp>_AddBillCoverage.cs`: **new**, generated.
- `DTOs/ParkingHistoryResponse.cs`: **modify** (`LiveFeeResponse`). `DTOs/PaymentResponse.cs`: **modify**.
- `Services/GateOptions.cs`: grace default 7.
- `Sync/Cloud/SnapshotBuilder.cs`, `Sync/Site/SnapshotApplier.cs`, `Sync/Cloud/EventIngestor.cs`: carry the two new columns.

Tests (`AimPark.API/AimPark.API.Tests/`): `ParkingFeeMathTests.cs` (rewrite), `PayBeforeExitTests.cs`, `PayAheadTests.cs`, `CloudMigrationsTests.cs` (modify).

Mobile (`aimpark_mobile/lib/`):
- `features/parking/data/models/live_fee.dart`: **modify**. Segments, payments, state.
- `features/parking/presentation/widgets/live_fee_card.dart`: **rewrite** `build`.
- `features/parking/presentation/widgets/pay_ahead_action.dart`: **modify** copy.
- `features/parking/presentation/screens/visit_details_screen.dart`: **new**.
- `features/parking/presentation/screens/parking_history_screen.dart`, `router/app_router.dart`: route to it.
- `features/payments/data/models/payment.dart`, `features/payments/presentation/screens/payment_detail_screen.dart`, `payments_list_screen.dart`: show coverage.
- `features/dashboard/presentation/widgets/parking_rates_card.dart`, `features/payments/data/models/parking_rate.dart`: rate wording.

Admin (`aimpark_admin/lib/`): `models/payment.dart`, `screens/payments_screen.dart`, `providers/payments_provider.dart`.

---

### Task 1: Fee math as segments

**Files:**
- Modify (rewrite): `AimPark.API/AimPark.API/Helpers/ParkingFeeMath.cs`
- Test (rewrite): `AimPark.API/AimPark.API.Tests/ParkingFeeMathTests.cs`

**Interfaces:**
- Produces:
  - `enum FeeSegmentKind { FirstHour, PerMinute, Grace }`
  - `enum MeterState { Free, FirstHour, Running, Paused }`
  - `record FeeSegment(FeeSegmentKind Kind, DateTime From, DateTime To, int Minutes, decimal Amount)`
  - `record FeeBreakdown(decimal Total, int ChargedMinutes, int PerMinuteMinutes, IReadOnlyList<FeeSegment> Segments, DateTime FirstHourEndsAt, DateTime? GraceUntil, MeterState State, DateTime? NextChangeAt, decimal? NextTotal)` with method `int ChargeableMinutesBetween(DateTime from, DateTime to)`
  - `static int ParkingFeeMath.ChargedMinutes(DateTime entry, DateTime at)` (unchanged)
  - `static FeeBreakdown ParkingFeeMath.Breakdown(decimal ratePerHour, DateTime entry, DateTime at, IReadOnlyList<DateTime> settledAt, int graceMinutes, bool open = true)`
- `Price`, `Metered` and `NextChange` are deleted. Their only callers are in `PaymentService`/`ParkingHistoryService`; until Task 6 those callers still compile because Task 1 keeps a thin `Price` shim (see Step 3).

- [ ] **Step 1: Write the failing tests**

Replace the whole of `ParkingFeeMathTests.cs`:

```csharp
using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// How a visit is priced: first hour flat, then per minute, with a free grace
/// after each payment. Numbers follow the example on the design canvas: a car
/// at ₱20/hr that entered at 1:02 PM.
/// </summary>
public class ParkingFeeMathTests
{
    private static readonly DateTime Entry = new(2026, 11, 19, 5, 2, 0, DateTimeKind.Utc); // 1:02 PM Manila
    private const decimal Car = 20m;
    private const int Grace = 7;

    private static DateTime At(double minutes) => Entry.AddMinutes(minutes);

    private static FeeBreakdown Price(double atMinutes, params double[] paidAtMinutes) =>
        ParkingFeeMath.Breakdown(Car, Entry, At(atMinutes), paidAtMinutes.Select(At).ToList(), Grace);

    [Theory]
    [InlineData(1, 1)]      // one second in is a started minute
    [InlineData(60, 1)]
    [InlineData(61, 2)]
    public void A_started_minute_is_a_charged_minute(int seconds, int minutes)
        => Assert.Equal(minutes, ParkingFeeMath.ChargedMinutes(Entry, Entry.AddSeconds(seconds)));

    [Theory]
    [InlineData(1.0 / 60, 20)]   // one second
    [InlineData(39, 20)]
    [InlineData(60, 20)]         // exactly an hour
    [InlineData(61, 20.33)]
    [InlineData(150, 50)]        // 2:02–3:32 is 90 minutes: ₱30
    public void First_hour_is_flat_then_per_minute(double atMinutes, double total)
        => Assert.Equal((decimal)total, Price(atMinutes).Total);

    [Fact]
    public void Inside_the_first_hour_the_next_change_is_when_it_ends()
    {
        var b = Price(39);

        Assert.Equal(MeterState.FirstHour, b.State);
        Assert.Equal(At(60), b.FirstHourEndsAt);
        Assert.Equal(At(60), b.NextChangeAt);
        Assert.Equal(20.33m, b.NextTotal);
        var only = Assert.Single(b.Segments);
        Assert.Equal(new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m), only);
    }

    [Fact]
    public void Paying_inside_the_first_hour_covers_to_its_end()
    {
        var b = Price(40, 39);

        Assert.Equal(20m, b.Total);
        Assert.Equal(At(46), b.GraceUntil);   // grace ends inside the first hour
        Assert.Equal(At(60), b.NextChangeAt); // so the first hour's end is what counts
    }

    [Fact]
    public void Past_the_first_hour_the_meter_runs_whether_paid_or_not()
    {
        var b = Price(150, 39);

        Assert.Equal(50m, b.Total);
        Assert.Equal(MeterState.Running, b.State);
        Assert.Equal(90, b.PerMinuteMinutes);
        Assert.Equal(
            new[]
            {
                new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m),
                new FeeSegment(FeeSegmentKind.PerMinute, At(60), At(150), 90, 30m),
            },
            b.Segments);
    }

    [Fact]
    public void After_paying_the_meter_pauses_for_seven_minutes()
    {
        var b = Price(152, 39, 150);

        Assert.Equal(50m, b.Total);
        Assert.Equal(MeterState.Paused, b.State);
        Assert.Equal(At(157), b.GraceUntil);                   // 3:39 PM
        Assert.Equal(At(157), b.NextChangeAt);
        Assert.Equal(50.33m, b.NextTotal);
        Assert.Equal(new FeeSegment(FeeSegmentKind.Grace, At(150), At(157), 7, 0m), b.Segments[^1]);
    }

    [Theory]
    [InlineData(170, 54.33, 13, 4.33)]   // 3:52 PM, 13 minutes after the grace
    [InlineData(171, 54.67, 14, 4.67)]   // 3:53 PM
    public void Grace_minutes_are_never_charged(double at, double total, int lastMinutes, double lastAmount)
    {
        var b = Price(at, 39, 150);

        Assert.Equal((decimal)total, b.Total);
        Assert.Equal(new FeeSegment(FeeSegmentKind.PerMinute, At(157), At(at), lastMinutes, (decimal)lastAmount), b.Segments[^1]);
        Assert.Equal(FeeSegmentKind.Grace, b.Segments[^2].Kind);
    }

    [Fact]
    public void Paying_at_minute_58_covers_to_minute_65()
    {
        var b = Price(66, 58);

        Assert.Equal(20.33m, b.Total);
        Assert.Equal(
            new[]
            {
                new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m),
                new FeeSegment(FeeSegmentKind.Grace, At(60), At(65), 5, 0m),
                new FeeSegment(FeeSegmentKind.PerMinute, At(65), At(66), 1, 0.33m),
            },
            b.Segments);
    }

    [Fact]
    public void Two_payments_close_together_extend_the_grace()
        => Assert.Equal(At(159), Price(153, 150, 152).GraceUntil);

    [Fact]
    public void A_motorcycle_at_30_an_hour()
        => Assert.Equal(45m, ParkingFeeMath.Breakdown(30m, Entry, At(90), [], Grace).Total);

    [Fact]
    public void With_no_rate_nothing_is_charged_and_nothing_changes()
    {
        var b = ParkingFeeMath.Breakdown(0m, Entry, At(300), [], Grace);

        Assert.Equal(0m, b.Total);
        Assert.Equal(MeterState.Free, b.State);
        Assert.Empty(b.Segments);
        Assert.Null(b.NextChangeAt);
    }

    [Fact]
    public void A_closed_visit_ends_its_last_grace_at_the_exit()
    {
        // Paid 3:53, left 3:55: the grace shows as 3:53–3:55, not to 4:00.
        var b = ParkingFeeMath.Breakdown(Car, Entry, At(173), [At(39), At(150), At(171)], Grace, open: false);

        Assert.Equal(new FeeSegment(FeeSegmentKind.Grace, At(171), At(173), 2, 0m), b.Segments[^1]);
        Assert.Null(b.NextChangeAt);
    }

    [Fact]
    public void Chargeable_minutes_between_skip_the_grace()
    {
        var b = Price(171, 39, 150);

        Assert.Equal(14, b.ChargeableMinutesBetween(At(150), At(171)));
        Assert.Equal(60, b.ChargeableMinutesBetween(Entry, At(60)));
    }
}
```

`ChargedMinutes` stays as it is (0 at the exact entry instant). `Breakdown` itself treats minute 0 as minute 1, so a visit is never cheaper than the first hour.

- [ ] **Step 2: (owner) run the tests and see them fail**

Run: `dotnet test AimPark.API/AimPark.API.Tests --filter ParkingFeeMathTests`
Expected: compile errors: `Breakdown`, `FeeSegment`, `MeterState` not defined.

- [ ] **Step 3: Write the implementation**

Replace the whole of `Helpers/ParkingFeeMath.cs`:

```csharp
namespace AimPark.API.Helpers
{
    public enum FeeSegmentKind { FirstHour, PerMinute, Grace }

    /// <summary>What the meter is doing right now.</summary>
    public enum MeterState { Free, FirstHour, Running, Paused }

    /// <summary>One stretch of a visit and what it costs. Grace stretches cost nothing.</summary>
    public sealed record FeeSegment(FeeSegmentKind Kind, DateTime From, DateTime To, int Minutes, decimal Amount);

    /// <summary>A whole visit, priced. <see cref="Segments"/> is in time order.</summary>
    public sealed record FeeBreakdown(
        decimal Total,
        int ChargedMinutes,
        int PerMinuteMinutes,
        IReadOnlyList<FeeSegment> Segments,
        DateTime FirstHourEndsAt,
        DateTime? GraceUntil,
        MeterState State,
        DateTime? NextChangeAt,
        decimal? NextTotal)
    {
        /// <summary>
        /// Charged minutes (first hour and per-minute, not grace) inside
        /// [<paramref name="from"/>, <paramref name="to"/>). What one bill covers.
        /// </summary>
        public int ChargeableMinutesBetween(DateTime from, DateTime to) =>
            Segments.Where(s => s.Kind != FeeSegmentKind.Grace)
                .Sum(s =>
                {
                    var start = s.From > from ? s.From : from;
                    var end = s.To < to ? s.To : to;
                    return end > start ? (int)Math.Round((end - start).TotalMinutes) : 0;
                });
    }

    /// <summary>
    /// How a visit is priced, as plain arithmetic with no database. The gate,
    /// pay-ahead, checkout, the live fee and every receipt use this, so they
    /// can never disagree about what a stay costs.
    /// </summary>
    /// <remarks>
    /// First hour: one hour's rate, flat, from the first second. After minute 60
    /// every started minute costs rate ÷ 60. After each settled payment the meter
    /// pauses for the grace (7 minutes), and grace minutes are never charged.
    /// </remarks>
    public static class ParkingFeeMath
    {
        public const int FirstHourMinutes = 60;

        /// <summary>
        /// The minute <paramref name="at"/> falls in, counted from entry. A started
        /// minute is a charged minute.
        /// </summary>
        public static int ChargedMinutes(DateTime entry, DateTime at)
            => Math.Max(0, (int)Math.Ceiling((at - entry).TotalMinutes));

        /// <param name="settledAt">When each settled payment was made. Each starts a grace pause.</param>
        /// <param name="open">
        /// True while the car is inside: a grace still running is shown to its end.
        /// False for a finished visit: the last grace stops at the exit.
        /// </param>
        public static FeeBreakdown Breakdown(
            decimal ratePerHour, DateTime entry, DateTime at,
            IReadOnlyList<DateTime> settledAt, int graceMinutes, bool open = true)
        {
            var firstHourEnd = entry.AddMinutes(FirstHourMinutes);
            var n = Math.Max(1, ChargedMinutes(entry, at));

            if (ratePerHour <= 0m)
                return new FeeBreakdown(0m, n, 0, [], firstHourEnd, null, MeterState.Free, null, null);

            // Minutes the meter is paused for, and the latest minute any grace reaches.
            var paused = new HashSet<int>();
            var graceEnd = 0;
            foreach (var paidAt in settledAt)
            {
                var k = ChargedMinutes(entry, paidAt);
                for (var m = k + 1; m <= k + graceMinutes; m++)
                    paused.Add(m);
                graceEnd = Math.Max(graceEnd, k + graceMinutes);
            }

            bool Chargeable(int m) => m > FirstHourMinutes && !paused.Contains(m);
            decimal PerMinute(int minutes) => Math.Round(minutes * ratePerHour / 60m, 2);

            var segments = new List<FeeSegment>
            {
                new(FeeSegmentKind.FirstHour, entry, firstHourEnd, FirstHourMinutes, ratePerHour)
            };

            // Walk minutes 61.. in runs of the same kind. Past now, only a grace
            // still running is shown (an open visit), never future charges.
            var perMinute = 0;
            FeeSegmentKind? runKind = null;
            var runStart = 0;
            var last = 0;

            void Close(int endMinute)
            {
                var minutes = endMinute - runStart + 1;
                var amount = runKind == FeeSegmentKind.PerMinute ? PerMinute(minutes) : 0m;
                segments.Add(new FeeSegment(runKind!.Value,
                    entry.AddMinutes(runStart - 1), entry.AddMinutes(endMinute), minutes, amount));
            }

            var lastMinute = open ? Math.Max(n, graceEnd) : n;
            for (var m = FirstHourMinutes + 1; m <= lastMinute; m++)
            {
                var kind = Chargeable(m) ? FeeSegmentKind.PerMinute : FeeSegmentKind.Grace;
                if (m > n && kind == FeeSegmentKind.PerMinute)
                    break;
                if (kind == FeeSegmentKind.PerMinute)
                    perMinute++;
                if (runKind != kind)
                {
                    if (runKind is not null)
                        Close(m - 1);
                    runKind = kind;
                    runStart = m;
                }
                last = m;
            }
            if (runKind is not null)
                Close(last);

            var total = ratePerHour + PerMinute(perMinute);

            var state = n <= FirstHourMinutes ? MeterState.FirstHour
                : paused.Contains(n) || paused.Contains(n + 1) ? MeterState.Paused
                : MeterState.Running;

            DateTime? nextAt = null;
            decimal? nextTotal = null;
            if (open)
            {
                for (var m = n + 1; m <= n + 24 * 60; m++)
                {
                    if (!Chargeable(m)) continue;
                    nextAt = entry.AddMinutes(m - 1);
                    nextTotal = ratePerHour + PerMinute(perMinute + 1);
                    break;
                }
            }

            return new FeeBreakdown(total, n, perMinute, segments, firstHourEnd,
                graceEnd > 0 ? entry.AddMinutes(graceEnd) : null, state, nextAt, nextTotal);
        }

        /// <summary>
        /// Temporary, removed in Task 6: the old per-minute price with a floor,
        /// kept only so the callers still compile until they move to Breakdown.
        /// </summary>
        [Obsolete("Use Breakdown. Removed in Task 6.")]
        public static decimal Price(decimal ratePerHour, decimal minimumFee, int minutes)
        {
            var metered = Math.Round(ratePerHour / 60m * minutes, 2);
            return metered > 0m && metered < minimumFee ? minimumFee : metered;
        }

        [Obsolete("Use Breakdown. Removed in Task 6.")]
        public static decimal Metered(decimal ratePerHour, int minutes) => Math.Round(ratePerHour / 60m * minutes, 2);

        [Obsolete("Use Breakdown. Removed in Task 6.")]
        public static (DateTime At, decimal Amount)? NextChange(decimal ratePerHour, decimal minimumFee, DateTime entry, DateTime at)
        {
            if (ratePerHour <= 0m) return null;
            var now = ChargedMinutes(entry, at);
            var current = Price(ratePerHour, minimumFee, now);
            for (var m = now + 1; m <= now + 24 * 60; m++)
            {
                var amount = Price(ratePerHour, minimumFee, m);
                if (amount > current) return (entry.AddMinutes(m - 1), amount);
            }
            return null;
        }
    }
}
```

Check by hand against the test "Paying at minute 58": k = 58, paused 59–65. Minutes 61–65 are grace (5), minute 66 is per-minute. Segments: Grace 60→65, PerMinute 65→66. Total = 20 + 0.33.

- [ ] **Step 4: Compile**

Run: `dotnet build AimPark.API/AimPark.API.sln` (checks it compiles; `[Obsolete]` warnings are expected until Task 6).
Expected: Build succeeded.

- [ ] **Step 5: Commit**

```bash
git add AimPark.API/AimPark.API/Helpers/ParkingFeeMath.cs AimPark.API/AimPark.API.Tests/ParkingFeeMathTests.cs
git commit -m "feat(api): price a visit as first hour, per-minute and grace segments"
```

---

### Task 2: Rate comes from the visit's own vehicle type (bug: no bay = free)

**Files:**
- Modify: `AimPark.API/AimPark.API/Services/PaymentService.cs` (`RateForAsync`, around lines 62–97)
- Test: `AimPark.API/AimPark.API.Tests/PayBeforeExitTests.cs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `RateForAsync(ParkingLog log, CancellationToken ct)` unchanged signature; now reads `log.VehicleType` first.

- [ ] **Step 1: Write the failing test**

Add to `PayBeforeExitTests` (after `A_fee_of_nothing_lets_the_driver_out_at_once`):

```csharp
    [Fact]
    public async Task A_car_that_never_confirmed_a_bay_is_still_charged_the_car_rate()
    {
        var g = await GateAsync();
        // Only a Car rate exists, and the visit has no bay: the bay can't say what it is.
        g.Db.RemoveRange(g.Db.Set<ParkingRate>());
        g.Db.Add(new ParkingRate { VehicleType = VehicleType.Car, RatePerHour = 20m });
        var log = g.Db.Set<ParkingLog>().Single();
        log.SlotId = null;
        log.VehicleType = VehicleType.Car;
        await g.Db.SaveChangesAsync();

        var result = await Tap(g);

        Assert.Equal(402, Status(result));
        // 119.5 min parked = 120 charged: ₱20 first hour + 60 min × ₱20/60.
        Assert.Equal(40m, OnlyBill(g).AmountDue);
    }
```

- [ ] **Step 2: (owner) run it and see it fail**

Run: `dotnet test AimPark.API/AimPark.API.Tests --filter A_car_that_never_confirmed_a_bay`
Expected: FAIL. Status is 200 (rate 0, driver let out free).

- [ ] **Step 3: Implement**

In `RateForAsync`, replace the opening block:

```csharp
            VehicleType? vehicleType = null;
            if (log.SlotId is not null)
            {
```

with:

```csharp
            // The visit records what drove in. The bay is only a fallback for old
            // visits without it; a car that never confirmed a bay has no bay to ask.
            VehicleType? vehicleType = log.VehicleType;
            if (vehicleType is null && log.SlotId is not null)
            {
```

Keep the rest of the method (fallback to the `VehicleType == null` default rate, then the entry-time rate lock) as is.

- [ ] **Step 4: Compile**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

- [ ] **Step 5: Commit**

```bash
git add AimPark.API/AimPark.API/Services/PaymentService.cs AimPark.API/AimPark.API.Tests/PayBeforeExitTests.cs
git commit -m "fix(api): price a visit by its own vehicle type, so no bay is not free"
```

---

### Task 3: Bills record what they cover

**Files:**
- Modify: `AimPark.API/AimPark.API/Entities/PaymentTransaction.cs`
- Create (generated): `AimPark.API/AimPark.API/Migrations/<timestamp>_AddBillCoverage.cs`
- Modify: `AimPark.API/AimPark.API/DTOs/PaymentResponse.cs`, the response mapper in `Services/PaymentService.cs` (the method that builds `PaymentResponse`, around line 800–840)
- Modify: `Services/PaymentService.cs` constructor (grace option)
- Test: `AimPark.API/AimPark.API.Tests/CloudMigrationsTests.cs`

**Interfaces:**
- Produces: `PaymentTransaction.CoversFrom : DateTime?`, `PaymentTransaction.CoversTo : DateTime?`; `PaymentResponse.CoversFrom`, `CoversTo`, `GraceUntil : DateTime?`; `PaymentService` optional ctor parameter `IOptions<GateOptions>? gate = null` stored as `private readonly TimeSpan _grace`.

- [ ] **Step 1: Add the columns**

In `PaymentTransaction.cs`, after `AmountDue`:

```csharp
        /// <summary>
        /// The stretch of the visit this bill pays for. Null on violation fines and
        /// on parking bills made before 2026-11-21. Grace minutes inside it are
        /// free; <see cref="DurationMinutes"/> counts only the charged ones.
        /// </summary>
        public DateTime? CoversFrom { get; set; }
        public DateTime? CoversTo { get; set; }
```

- [ ] **Step 2: Generate the migration**

Run (creates the migration files only; it does not touch the database):
`dotnet ef migrations add AddBillCoverage --project AimPark.API/AimPark.API`

Expected: two `AddColumn<DateTime>` calls on `PaymentTransactions`, `nullable: true`, nothing else. If anything else appears (a seed `UpdateData` the model always emits is fine), stop and report it.

- [ ] **Step 3: Pin that it is additive**

In `CloudMigrationsTests`, add to the `Migrations_that_only_add_are_safe` theory:

```csharp
    [InlineData("AddBillCoverage")]
```

- [ ] **Step 4: Grace option in PaymentService**

Add a last optional constructor parameter `IOptions<GateOptions>? gate = null` and a field:

```csharp
        private readonly TimeSpan _grace;
        // in the constructor body:
        _grace = TimeSpan.FromMinutes(gate?.Value.PaidExitGraceMinutes ?? new GateOptions().PaidExitGraceMinutes);
```

DI already registers `IOptions<GateOptions>` (ParkingHistoryService uses it), so the container fills it. Existing tests construct `PaymentService` without it and get the default.

- [ ] **Step 5: Response fields**

In `PaymentResponse`, after `PaidAt`:

```csharp
        /// <summary>What part of the visit this bill pays for. Null for fines and older bills.</summary>
        public DateTime? CoversFrom { get; set; }
        public DateTime? CoversTo { get; set; }

        /// <summary>Paid parking bills only: the meter is paused until this time.</summary>
        public DateTime? GraceUntil { get; set; }
```

In the mapper that builds `PaymentResponse` from a `PaymentTransaction p`, add:

```csharp
            CoversFrom = p.CoversFrom,
            CoversTo = p.CoversTo,
            GraceUntil = p.Source == PaymentSource.ParkingFee && p.PaidAt is DateTime paid ? paid + _grace : null,
```

(If the mapper is `static`, make it an instance method; it needs `_grace`.)

- [ ] **Step 6: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

```bash
git add AimPark.API/AimPark.API/Entities/PaymentTransaction.cs AimPark.API/AimPark.API/Migrations AimPark.API/AimPark.API/DTOs/PaymentResponse.cs AimPark.API/AimPark.API/Services/PaymentService.cs AimPark.API/AimPark.API.Tests/CloudMigrationsTests.cs
git commit -m "feat(api): bills record the stretch of the visit they cover"
```

---

### Task 4: VisitPricing

**Files:**
- Create: `AimPark.API/AimPark.API/Services/VisitPricing.cs`
- Test: `AimPark.API/AimPark.API.Tests/PayAheadTests.cs` (new test at the end of "Asking to pay while parked")

**Interfaces:**
- Consumes: `ParkingFeeMath.Breakdown` (Task 1), `IPaymentService.RateForAsync`, `IEntryDues.IsSettledAsync`, `ExitPayment.IsReleased`.
- Produces:

```csharp
public sealed record VisitPrice(
    FeeBreakdown Breakdown, decimal RatePerHour, decimal Settled, decimal OwedNow,
    DateTime UnpaidFrom, IReadOnlyList<PaymentTransaction> Bills,
    IReadOnlyList<PaymentTransaction> SettledBills, DateTime At)
{
    public DateTime? CoveredUntil { get; }   // OwedNow == 0 ? Breakdown.NextChangeAt : null
}
public sealed class VisitPricing
{
    public VisitPricing(AppDbContext db, IPaymentService payments, IEntryDues dues, TimeSpan grace);
    public Task<VisitPrice> PriceAsync(ParkingLog log, DateTime at, CancellationToken ct);
}
```

- [ ] **Step 1: Write the failing test** (Review Focus 1: a visit spanning the deploy)

Add to `PayAheadTests`:

```csharp
    [Fact]
    public async Task A_bill_from_before_the_change_still_covers_the_first_hour()
    {
        var l = await LotAsync();
        // Paid ₱30 forty minutes in, before bills had CoversTo.
        var paidAt = l.Log.EntryTime.AddMinutes(40);
        l.Db.Add(new PaymentTransaction
        {
            Id = Guid.NewGuid(), Source = PaymentSource.ParkingFee, ParkingLogId = l.Log.Id, UserId = l.User.Id,
            DurationMinutes = 40, RatePerHourApplied = 30m, AmountDue = 30m, Status = PaymentStatus.Paid,
            PaidAhead = true, PaidAt = paidAt, CreatedAt = paidAt
        });
        await l.Db.SaveChangesAsync();
        var pricing = new VisitPricing(l.Db, l.Payments, new DbEntryDues(l.Db), TimeSpan.FromMinutes(7));

        var price = await pricing.PriceAsync(l.Log, DateTime.UtcNow, default);

        // 120 charged minutes at ₱30/hr: ₱30 + 60 × ₱0.50 = ₱60. ₱30 paid.
        Assert.Equal(60m, price.Breakdown.Total);
        Assert.Equal(30m, price.OwedNow);
        Assert.Equal(l.Log.EntryTime.AddMinutes(60), price.UnpaidFrom);
    }
```

This needs the `PaymentService` in the `Lot` record. Change `private sealed record Lot(...)` to add `PaymentService Payments` as the last member and pass `payments` where `Lot` is built in `LotAsync`. Also set `PaidExitGraceMinutes = 7` in `LotAsync` (it was 15), to test the real rule.

- [ ] **Step 2: (owner) run and see it fail**

Run: `dotnet test AimPark.API/AimPark.API.Tests --filter A_bill_from_before_the_change`
Expected: compile error, `VisitPricing` not defined.

- [ ] **Step 3: Implement**

Create `Services/VisitPricing.cs`:

```csharp
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>One visit, priced at a moment, with what is already settled.</summary>
    /// <param name="UnpaidFrom">
    /// Where the part nobody has paid for starts: the start of the first charged
    /// stretch after what earlier bills covered. A new bill covers from here.
    /// </param>
    public sealed record VisitPrice(
        FeeBreakdown Breakdown,
        decimal RatePerHour,
        decimal Settled,
        decimal OwedNow,
        DateTime UnpaidFrom,
        IReadOnlyList<PaymentTransaction> Bills,
        IReadOnlyList<PaymentTransaction> SettledBills,
        DateTime At)
    {
        /// <summary>Nothing owed: the barrier opens on a tap until this moment.</summary>
        public DateTime? CoveredUntil => OwedNow <= 0m ? Breakdown.NextChangeAt : null;
    }

    /// <summary>
    /// The one place a visit is priced against its bills. The gate, pay-ahead,
    /// checkout and the app's live fee all ask here.
    /// </summary>
    /// <remarks>
    /// "Settled" is asked of <see cref="IEntryDues"/>, not read from the status
    /// alone: on the site server a payment made in the app is known from the
    /// cloud's snapshot while the local row still says Pending. Such a row has no
    /// paid time here, so its grace starts at <c>at</c>: as far as the site can
    /// tell, it was just paid.
    /// </remarks>
    public sealed class VisitPricing
    {
        private readonly AppDbContext _db;
        private readonly IPaymentService _payments;
        private readonly IEntryDues _dues;
        private readonly int _graceMinutes;

        public VisitPricing(AppDbContext db, IPaymentService payments, IEntryDues dues, TimeSpan grace)
        {
            _db = db;
            _payments = payments;
            _dues = dues;
            _graceMinutes = (int)Math.Round(grace.TotalMinutes);
        }

        public async Task<VisitPrice> PriceAsync(ParkingLog log, DateTime at, CancellationToken ct)
        {
            var (rate, _) = await _payments.RateForAsync(log, ct);

            var bills = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.ParkingLogId == log.Id)
                .OrderBy(p => p.CreatedAt)
                .ToListAsync(ct);

            var settled = new List<PaymentTransaction>();
            foreach (var bill in bills)
            {
                if (bill.Status is PaymentStatus.Paid or PaymentStatus.Waived)
                {
                    settled.Add(bill);
                }
                else if (!ExitPayment.IsReleased(bill) && bill.AmountDue > 0m
                         && await _dues.IsSettledAsync(bill.Id, ct))
                {
                    bill.PaidAt ??= at; // untracked copy: only this calculation sees it
                    settled.Add(bill);
                }
            }

            var breakdown = ParkingFeeMath.Breakdown(
                rate, log.EntryTime, at,
                settled.Select(b => b.PaidAt ?? b.CreatedAt).ToList(),
                _graceMinutes, open: log.ExitTime is null);

            var settledSum = settled.Sum(b => b.AmountDue);

            // What earlier bills covered. Bills from before CoversTo existed fall
            // back to their paid time. Any settled bill paid at least the first
            // hour, so coverage never ends before it.
            var coveredTo = settled.Count == 0
                ? log.EntryTime
                : settled.Max(b => b.CoversTo ?? b.PaidAt ?? b.CreatedAt);
            if (settled.Count > 0 && coveredTo < breakdown.FirstHourEndsAt)
                coveredTo = breakdown.FirstHourEndsAt;

            var next = breakdown.Segments.FirstOrDefault(s => s.Kind != FeeSegmentKind.Grace && s.To > coveredTo);
            var unpaidFrom = next is not null && next.From > coveredTo ? next.From : coveredTo;

            return new VisitPrice(breakdown, rate, settledSum,
                Math.Max(0m, breakdown.Total - settledSum), unpaidFrom, bills, settled, at);
        }
    }
}
```

- [ ] **Step 4: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

```bash
git add AimPark.API/AimPark.API/Services/VisitPricing.cs AimPark.API/AimPark.API.Tests/PayAheadTests.cs
git commit -m "feat(api): price a visit against its settled bills in one place"
```

---

### Task 5: One way to bill what is owed

**Files:**
- Modify: `AimPark.API/AimPark.API/Services/PaymentService.cs`, `AimPark.API/AimPark.API/Interfaces/IPaymentService.cs`
- Test: `AimPark.API/AimPark.API.Tests/PayBeforeExitTests.cs`

**Interfaces:**
- Consumes: `VisitPrice` (Task 4).
- Produces (added to `IPaymentService`):

```csharp
public sealed record BillResult(PaymentTransaction Bill, bool Created, bool WasPaidAhead);
Task<BillResult?> BillOwedAsync(ParkingLog log, VisitPrice price, bool paidAhead, CancellationToken ct);
```

Old methods stay until Task 6 removes them.

- [ ] **Step 1: Write the failing test** (Review Focus 3: an open checkout is not re-priced)

Add to `PayBeforeExitTests`:

```csharp
    [Fact]
    public async Task A_checkout_already_open_is_not_repriced_only_the_time_after_it_is_billed()
    {
        var g = await GateAsync();
        await Tap(g); // ₱60 bill, Pending
        var first = OnlyBill(g);
        var tracked = g.Db.Set<PaymentTransaction>().Single();
        tracked.Status = PaymentStatus.Processing; // driver opened GCash
        g.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddMinutes(-179).AddSeconds(-30);
        await g.Db.SaveChangesAsync();

        var second = await Tap(g);

        Assert.Equal(402, Status(second));
        var bills = g.Db.Set<PaymentTransaction>().AsNoTracking().OrderBy(p => p.CreatedAt).ToList();
        Assert.Equal(2, bills.Count);
        Assert.Equal(60m, bills[0].AmountDue);              // untouched
        Assert.Equal(PaymentStatus.Processing, bills[0].Status);
        Assert.Equal(30m, bills[1].AmountDue);              // the extra hour
    }
```

(This passes only after Task 6 moves the gate to `BillOwedAsync`. Write it now; it is the target for both tasks.)

- [ ] **Step 2: Implement `BillOwedAsync`**

`IPaymentService.cs` now names `VisitPrice` (namespace `AimPark.API.Services`): add `using AimPark.API.Services;` at its top. Then, next to `ParkingFeeQuote`:

```csharp
    /// <summary>A bill for what a visit owes now. <c>Created</c>: new, not re-priced.</summary>
    public sealed record BillResult(PaymentTransaction Bill, bool Created, bool WasPaidAhead);
```

and in the interface:

```csharp
        /// <summary>
        /// Bills what <paramref name="price"/> says is owed now. Re-prices the open
        /// Pending bill if there is one, or makes a new one. A checkout already
        /// Processing is never re-priced; only time beyond it is billed. Null
        /// when nothing is owed: no ₱0 bills.
        /// </summary>
        Task<BillResult?> BillOwedAsync(ParkingLog log, VisitPrice price, bool paidAhead, CancellationToken ct);
```

In `PaymentService.cs`:

```csharp
        public async Task<BillResult?> BillOwedAsync(ParkingLog log, VisitPrice price, bool paidAhead, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException("A visitor session has no account to bill.");
            if (price.OwedNow <= 0m)
                return null;

            var settledIds = price.SettledBills.Select(b => b.Id).ToHashSet();
            var open = (await _db.Set<PaymentTransaction>()
                    .Where(p => p.ParkingLogId == log.Id
                        && (p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Processing))
                    .OrderByDescending(p => p.CreatedAt)
                    .ToListAsync(ct))
                .Where(p => !settledIds.Contains(p.Id) && !ExitPayment.IsReleased(p))
                .ToList();

            var inFlight = open.Where(p => p.Status == PaymentStatus.Processing).ToList();
            var toBill = price.OwedNow - inFlight.Sum(p => p.AmountDue);
            if (toBill <= 0m)
                return new BillResult(inFlight[0], false, inFlight[0].PaidAhead);

            // A bill paid inside the first hour covers the whole first hour.
            var coversFrom = inFlight.Count > 0
                ? inFlight.Max(p => p.CoversTo ?? p.CreatedAt)
                : price.UnpaidFrom;
            var coversTo = price.At < price.Breakdown.FirstHourEndsAt ? price.Breakdown.FirstHourEndsAt : price.At;
            var minutes = price.Breakdown.ChargeableMinutesBetween(coversFrom, coversTo);

            var pending = open.FirstOrDefault(p => p.Status == PaymentStatus.Pending);
            if (pending is not null)
            {
                var wasAhead = pending.PaidAhead;
                pending.AmountDue = toBill;
                pending.DurationMinutes = minutes;
                pending.RatePerHourApplied = price.RatePerHour;
                pending.CoversFrom = coversFrom;
                pending.CoversTo = coversTo;
                // Once the gate has held a driver for it, it stays a gate bill.
                pending.PaidAhead = pending.PaidAhead && paidAhead;
                await _payments.SaveAsync(ct);
                return new BillResult(pending, false, wasAhead);
            }

            var bill = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId.Value,
                DurationMinutes = minutes,
                RatePerHourApplied = price.RatePerHour,
                AmountDue = toBill,
                CoversFrom = coversFrom,
                CoversTo = coversTo,
                Status = PaymentStatus.Pending,
                PaidAhead = paidAhead,
                CreatedAt = DateTime.UtcNow
            };
            await _payments.AddAsync(bill, ct);
            await _payments.SaveAsync(ct);
            return new BillResult(bill, true, false);
        }
```

Note on `_payments.SaveAsync`: it is the repository's save, which saves the shared `AppDbContext`, so the tracked `pending` change is written. If `IRepository.SaveAsync` does not exist under that name, use `await _db.SaveChangesAsync(ct)` (both appear in this file today).

- [ ] **Step 3: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

```bash
git add AimPark.API/AimPark.API/Services/PaymentService.cs AimPark.API/AimPark.API/Interfaces/IPaymentService.cs AimPark.API/AimPark.API.Tests/PayBeforeExitTests.cs
git commit -m "feat(api): bill what a visit owes now, re-pricing the open bill"
```

---

### Task 6: Gate, pay-ahead, live fee and exit use the new pricing

**Files:**
- Modify: `AimPark.API/AimPark.API/Services/ParkingHistoryService.cs` (constructor; history "leave by" ~lines 105–131; `HoldForPaymentAsync` ~983–1059; `PayAheadAsync` ~1064–1103; `GetLiveFeeAsync` ~1110–1166; `LogExitAsync` ~1290–1316)
- Modify: `AimPark.API/AimPark.API/Services/PaymentService.cs`, `Interfaces/IPaymentService.cs` (remove old methods, change `CreateForCompletedLogAsync`)
- Modify: `AimPark.API/AimPark.API/DTOs/ParkingHistoryResponse.cs` (`LiveFeeResponse`)
- Modify: `AimPark.API/AimPark.API/Helpers/ParkingFeeMath.cs` (delete the `[Obsolete]` shims)
- Test: `PayBeforeExitTests.cs`, `PayAheadTests.cs`

**Interfaces:**
- Consumes: `VisitPricing`, `VisitPrice`, `BillOwedAsync`, `BillResult`.
- Produces:
  - `Task<PaymentTransaction?> CreateForCompletedLogAsync(ParkingLog log, VisitPrice price, CancellationToken ct)` (was non-null, no price).
  - `LiveFeeResponse` new members: `ExitTime`, `FirstHourEndsAt`, `GraceUntil`, `MeterState` (string), `Segments : List<FeeSegmentResponse>`, `Payments : List<FeePaymentResponse>`, `BreakdownMatchesBills : bool`. Removed: `MinimumFee`, `MeteredSoFar`.
  - `GET /api/parking/sessions/{logId}/live-fee` now also answers for a closed visit (priced at its exit).
  - Removed from `IPaymentService`: `QuoteForCompletedLogAsync`, `QuoteAsync`, `RaiseExitBillAsync`, `RaiseAheadAsync`, `RaiseOverstayBillAsync`, `RepriceOpenBillAsync`, record `ParkingFeeQuote`.

- [ ] **Step 1: Update the existing tests to the new rules**

Without grace in play, the old and new math agree for stays of 60 minutes or more (`R + (n−60)·R/60 = n·R/60`). So only tests that involve grace or re-pricing change.

In `PayBeforeExitTests`, replace `Tapping_again_before_paying_does_not_raise_a_second_bill_or_change_the_amount` with:

```csharp
    [Fact]
    public async Task Tapping_again_before_paying_reprices_the_same_bill()
    {
        var g = await GateAsync();
        await Tap(g);

        // Five hours in: ₱30 first hour + 240 min × ₱0.50.
        g.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddHours(-5);
        await g.Db.SaveChangesAsync();
        var second = await Tap(g);

        Assert.Equal(402, Status(second));
        Assert.Equal(150m, OnlyBill(g).AmountDue);
    }

    [Fact]
    public async Task Nothing_owed_at_the_exit_makes_no_zero_peso_bill()
    {
        var g = await GateAsync(ratePerHour: 0m);

        await Tap(g);

        Assert.Empty(g.Db.Set<PaymentTransaction>().AsNoTracking());
    }
```

In `PayAheadTests` (grace is now 7 in `LotAsync`, from Task 4):
- `Once_paid_the_app_is_told_when_to_leave_by`: paid at minute 120 (k = ceil(119.5) = 120), grace 121–127, so covered to entry + 127 min. Change the first assert to:
  `Assert.Equal(Session(l).EntryTime.AddMinutes(127), entry.LeaveBy);`
- `Paid_ahead_and_tapping_in_time_opens_the_barrier_at_once`: change `AddMinutes(-10)` to `AddMinutes(-5)` (minute 115, grace 116–122, still inside).
- `Tapping_after_the_window_bills_the_rest_and_holds_the_barrier`: the extra is now ₱26.50 (180 charged minutes, 7 of them grace: ₱30 + 113 × ₱0.50 = ₱86.50, minus ₱60 paid). Change `Assert.Equal(30m, extra.AmountDue);` to `Assert.Equal(26.5m, extra.AmountDue);`.
- `Staying_past_the_window_while_still_parked_raises_the_rest_from_the_app`: same arithmetic. Change `Assert.Equal(30m, again.AmountDue);` to `Assert.Equal(26.5m, again.AmountDue);`.

- [ ] **Step 2: Wire `VisitPricing` into ParkingHistoryService**

Add a field `private readonly VisitPricing _pricing;` and, at the end of the constructor (after `_paidExitGrace` is set):

```csharp
            _pricing = new VisitPricing(db, paymentService, entryDues, _paidExitGrace);
```

(Use the constructor's own parameter names for the db context, payment service and entry dues.)

- [ ] **Step 3: Replace `HoldForPaymentAsync`**

Replace the whole method body (keep its doc comment, updated) with:

```csharp
        /// <summary>
        /// Holds the barrier while the visit owes anything. Owing nothing covers
        /// paid inside the first hour, inside a grace, and a free visit. The bill
        /// is priced again at every tap, so waiting at the gate never freezes it.
        /// </summary>
        private async Task<ObjectResult?> HoldForPaymentAsync(ParkingLog log, CancellationToken ct)
        {
            var now = DateTime.UtcNow;

            // A guard has let this driver through (the bill stays owed).
            var latest = await _paymentService.FindForLogAsync(log.Id, ct);
            if (latest is not null && ExitPayment.IsReleased(latest))
                return null;

            var price = await _pricing.PriceAsync(log, now, ct);
            var billed = await _paymentService.BillOwedAsync(log, price, paidAhead: false, ct);
            if (billed is null)
                return null;

            var bill = billed.Bill;
            if (billed.Created || billed.WasPaidAhead)
            {
                await _notificationService.NotifyUserAsync(
                    log.UserId!.Value,
                    NotificationType.Payment,
                    "Pay to leave",
                    $"Your parking fee is ₱{bill.AmountDue:0.00}. Pay in the app or at the guard post, then tap your card again.",
                    new Dictionary<string, string> { ["paymentId"] = bill.Id.ToString() },
                    ct);
            }

            return new ObjectResult(new
            {
                result = AllocationResult.PaymentDue,
                message = "Pay in the app or at the guard post, then tap again.",
                paymentId = (Guid?)bill.Id,
                amountDue = bill.AmountDue,
                durationMinutes = bill.DurationMinutes,
                collectInCash = false
            })
            { StatusCode = 402 };
        }
```

- [ ] **Step 4: Replace `PayAheadAsync`'s body after the two guard checks**

```csharp
            var now = DateTime.UtcNow;
            var price = await _pricing.PriceAsync(log, now, ct);
            var billed = await _paymentService.BillOwedAsync(log, price, paidAhead: true, ct);

            if (billed is null)
                return new OkObjectResult(new PayAheadResponse
                {
                    Paid = price.Settled > 0m,
                    LeaveBy = price.CoveredUntil
                });

            return new OkObjectResult(new PayAheadResponse
            {
                PaymentId = billed.Bill.Id,
                AmountDue = billed.Bill.AmountDue,
                DurationMinutes = billed.Bill.DurationMinutes
            });
```

- [ ] **Step 5: History "leave by"**

In the history mapping block (the `openBillIds` loop), delete the `if (bill.Status is PaymentStatus.Paid or PaymentStatus.Waived) { entry.LeaveBy = ...; }` branch and turn the `else if` that sets `WaitingToLeave` into a plain `if`. Then, after that loop, price each open entry once:

```csharp
            foreach (var entry in logs.Where(e => e.ExitTime == null))
            {
                var open = await _db.Set<ParkingLog>().AsNoTracking().FirstAsync(l => l.Id == entry.LogId, ct);
                var price = await _pricing.PriceAsync(open, DateTime.UtcNow, ct);
                // Paid something: when the paid time runs (or ran) out.
                if (price.Settled > 0m)
                    entry.LeaveBy = price.CoveredUntil ?? price.UnpaidFrom;
            }
```

Use the history entry's real id property name (`LogId` in `ParkingHistoryEntryResponse`; check the class).

- [ ] **Step 6: Live fee DTOs**

In `DTOs/ParkingHistoryResponse.cs`, in `LiveFeeResponse`: delete `MinimumFee` and `MeteredSoFar`, and add:

```csharp
        /// <summary>Set when the visit is over; then everything is priced at this time.</summary>
        public DateTime? ExitTime { get; set; }

        public DateTime FirstHourEndsAt { get; set; }

        /// <summary>The latest grace's end, if any payment was made.</summary>
        public DateTime? GraceUntil { get; set; }

        /// <summary>Free, FirstHour, Running or Paused.</summary>
        public string MeterState { get; set; } = "FirstHour";

        /// <summary>The visit in time order: first hour, per-minute runs, grace pauses.</summary>
        public List<FeeSegmentResponse> Segments { get; set; } = [];

        /// <summary>Settled bills, oldest first.</summary>
        public List<FeePaymentResponse> Payments { get; set; } = [];

        /// <summary>
        /// False for an old finished visit whose bills were worked out under the
        /// previous rules: the app then shows the bills and hides the timeline.
        /// </summary>
        public bool BreakdownMatchesBills { get; set; } = true;
```

and below the class:

```csharp
    public class FeeSegmentResponse
    {
        public string Kind { get; set; } = string.Empty; // FirstHour, PerMinute, Grace
        public DateTime From { get; set; }
        public DateTime To { get; set; }
        public int Minutes { get; set; }
        public decimal Amount { get; set; }
    }

    public class FeePaymentResponse
    {
        public Guid PaymentId { get; set; }
        public decimal Amount { get; set; }
        public DateTime? PaidAt { get; set; }
        public string? Method { get; set; }
        public DateTime? CoversFrom { get; set; }
        public DateTime? CoversTo { get; set; }
    }
```

Also update the `LeaveBy` doc comment: "Nothing owed: the barrier opens on a tap until this time."

- [ ] **Step 7: Replace `GetLiveFeeAsync`'s body after the not-found check**

Delete the `ExitTime is not null` bad-request check (a closed visit is now answered, priced at its exit). Then:

```csharp
            var now = DateTime.UtcNow;
            var at = log.ExitTime ?? now;
            var open = log.ExitTime is null;
            var price = await _pricing.PriceAsync(log, at, ct);
            var b = price.Breakdown;

            static DateTime? Utc(DateTime? t) => t is DateTime v ? DateTime.SpecifyKind(v, DateTimeKind.Utc) : null;
            static DateTime U(DateTime t) => DateTime.SpecifyKind(t, DateTimeKind.Utc);

            var settledIds = price.SettledBills.Select(s => s.Id).ToHashSet();
            var processing = price.Bills.Any(p => p.Status == PaymentStatus.Processing
                && !settledIds.Contains(p.Id) && p.Provider != ExitPayment.ReleasedProvider);

            return new OkObjectResult(new LiveFeeResponse
            {
                LogId = log.Id,
                EntryTime = U(log.EntryTime),
                ExitTime = Utc(log.ExitTime),
                AsOf = now,
                DurationMinutes = b.ChargedMinutes,
                RatePerHour = price.RatePerHour,
                TotalSoFar = b.Total,
                AlreadyPaid = price.Settled,
                OwedNow = price.OwedNow,
                PaymentProcessing = open && processing,
                LeaveBy = open ? Utc(price.CoveredUntil) : null,
                NextChangeAt = Utc(b.NextChangeAt),
                NextTotal = b.NextTotal,
                FirstHourEndsAt = U(b.FirstHourEndsAt),
                GraceUntil = Utc(b.GraceUntil),
                MeterState = b.State.ToString(),
                Segments = b.Segments.Select(s => new FeeSegmentResponse
                {
                    Kind = s.Kind.ToString(), From = U(s.From), To = U(s.To), Minutes = s.Minutes, Amount = s.Amount
                }).ToList(),
                Payments = price.SettledBills.Select(p => new FeePaymentResponse
                {
                    PaymentId = p.Id, Amount = p.AmountDue, PaidAt = Utc(p.PaidAt),
                    Method = p.Method?.ToString(), CoversFrom = Utc(p.CoversFrom), CoversTo = Utc(p.CoversTo)
                }).ToList(),
                BreakdownMatchesBills = open || price.Bills.Sum(p => p.AmountDue) == b.Total,
            });
```

Update the comment above the method: it now also serves the visit details screen for finished visits.

- [ ] **Step 8: Exit**

In `PaymentService`, replace `CreateForCompletedLogAsync` with:

```csharp
        public async Task<PaymentTransaction?> CreateForCompletedLogAsync(ParkingLog log, VisitPrice price, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException("A visitor session has no account to bill.");

            var billed = await BillOwedAsync(log, price, paidAhead: false, ct);
            if (billed is null)
                return null;

            if (billed.Created)
            {
                var d = billed.Bill.DurationMinutes;
                var duration = d >= 60 ? $"{d / 60}h {d % 60}m" : $"{d}m";
                await _notificationService.NotifyUserAsync(
                    log.UserId.Value,
                    NotificationType.Payment,
                    "Parking fee",
                    $"You parked for {duration}. Amount due: ₱{billed.Bill.AmountDue:0.00}.",
                    new Dictionary<string, string> { ["paymentId"] = billed.Bill.Id.ToString() },
                    ct);
            }
            return billed.Bill;
        }
```

Update its interface signature to match.

In `LogExitAsync`, replace `var transaction = await _paymentService.CreateForCompletedLogAsync(log, ct);` and the code after it with:

```csharp
            var price = await _pricing.PriceAsync(log, log.ExitTime!.Value, ct);
            var transaction = await _paymentService.CreateForCompletedLogAsync(log, price, ct);

            var stayed = log.ExitTime!.Value - log.EntryTime;
            var stayedText = stayed.TotalHours >= 1 ? $"{(int)stayed.TotalHours}h {stayed.Minutes}m" : $"{(int)stayed.TotalMinutes}m";
            if (transaction is null)
            {
                // Settled before leaving (at the gate, or paid ahead), or nothing to pay.
                await _notificationService.NotifyUserAsync(
                    log.UserId!.Value,
                    NotificationType.Parking,
                    "You've left",
                    billRaisedAtGate || price.Settled > 0m
                        ? $"You parked for {stayedText}. Thanks for paying."
                        : $"You parked for {stayedText}. Nothing to pay.",
                    new Dictionary<string, string> { ["screen"] = "parking-history" },
                    ct);
            }

            return new OkObjectResult(new
            {
                result = AllocationResult.ExitLogged,
                message = "Exit logged.",
                paymentId = transaction?.Id,
                amountDue = transaction?.AmountDue ?? 0m,
                durationMinutes = transaction?.DurationMinutes ?? price.Breakdown.ChargedMinutes,
                collectInCash = false
            });
```

and delete the old `if (billRaisedAtGate) { ... "Thanks for paying." ... }` block it replaces.

- [ ] **Step 9: Delete the old pricing and billing**

Delete from `PaymentService` and `IPaymentService`: `QuoteForCompletedLogAsync`, `QuoteAsync`, `RaiseExitBillAsync`, `RaiseAheadAsync`, `RaiseOverstayBillAsync`, `RepriceOpenBillAsync`, and `record ParkingFeeQuote`. Delete the three `[Obsolete]` members from `ParkingFeeMath`. Then search for anything left:

Run: `grep -rn "QuoteAsync\|ParkingFeeQuote\|RaiseAheadAsync\|RaiseOverstayBillAsync\|RepriceOpenBillAsync\|RaiseExitBillAsync\|ParkingFeeMath.Price\|NextChange(" AimPark.API --include=*.cs`
Expected: no matches outside `bin/` and `obj/`.

- [ ] **Step 10: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded, no `[Obsolete]` warnings.

```bash
git add AimPark.API
git commit -m "feat(api): gate, pay-ahead, live fee and exit price the visit with grace"
```

---

### Task 7: Checkout re-prices an open parking bill

**Files:**
- Modify: `AimPark.API/AimPark.API/Services/PaymentService.cs` (`StartCheckoutAsync` ~403; `StartCheckoutAllAsync` ~470)
- Test: `AimPark.API/AimPark.API.Tests/PayAheadTests.cs`

**Interfaces:**
- Consumes: `VisitPricing`, `BillOwedAsync`.
- Produces: no signature changes.

- [ ] **Step 1: Write the failing test**

Add to `PayAheadTests` (the in-memory `NoGateway` throws on `CreateCheckoutAsync`, so assert the bill was re-priced before the gateway was reached):

```csharp
    [Fact]
    public async Task Starting_a_checkout_prices_the_bill_up_to_that_moment()
    {
        var l = await LotAsync();
        await PayAhead(l); // ₱60 at two hours
        l.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddMinutes(-179).AddSeconds(-30);
        await l.Db.SaveChangesAsync();
        var bill = Bills(l).Single();

        await Assert.ThrowsAnyAsync<Exception>(() => l.Payments.StartCheckoutAsync(l.User.Id, bill.Id, default));

        Assert.Equal(90m, Bills(l).Single().AmountDue);
    }
```

If `StartCheckoutAsync` catches the gateway exception and returns 502 instead of throwing (it does, see "The payment service could not be reached"), replace the `ThrowsAnyAsync` line with `await l.Payments.StartCheckoutAsync(l.User.Id, bill.Id, default);`.

- [ ] **Step 2: Implement**

Add a private helper to `PaymentService`:

```csharp
        /// <summary>
        /// A Pending parking bill for a visit still in progress is priced again
        /// right before it is paid, so it never charges an old amount.
        /// </summary>
        private async Task<PaymentTransaction> RepriceIfOpenAsync(PaymentTransaction bill, CancellationToken ct)
        {
            if (bill.Source != PaymentSource.ParkingFee || bill.Status != PaymentStatus.Pending
                || bill.ParkingLogId is not Guid logId)
                return bill;

            var log = await _db.Set<ParkingLog>().FirstOrDefaultAsync(l => l.Id == logId, ct);
            if (log is null || log.ExitTime is not null)
                return bill;

            var pricing = new VisitPricing(_db, this, new DbEntryDues(_db), _grace);
            var price = await pricing.PriceAsync(log, DateTime.UtcNow, ct);
            var billed = await BillOwedAsync(log, price, bill.PaidAhead, ct);
            return billed?.Bill ?? bill;
        }
```

In `StartCheckoutAsync`, right after the `Waived` check and before the `AmountDue <= 0m` check:

```csharp
            payment = await RepriceIfOpenAsync(payment, ct);
```

In `StartCheckoutAllAsync`, after the Pending bills are loaded into a list and before they are summed, re-price each:

```csharp
            for (var i = 0; i < bills.Count; i++)
                bills[i] = await RepriceIfOpenAsync(bills[i], ct);
```

(Use the list variable's real name in that method.)

- [ ] **Step 3: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

```bash
git add AimPark.API/AimPark.API/Services/PaymentService.cs AimPark.API/AimPark.API.Tests/PayAheadTests.cs
git commit -m "fix(api): a parking bill is priced again when its checkout starts"
```

---

### Task 8: Site sync carries what a bill covers

**Files:**
- Modify: `AimPark.API/AimPark.API/Sync/Cloud/SnapshotBuilder.cs` (paid-ahead projection ~lines 91–110)
- Modify: `AimPark.API/AimPark.API/Sync/Site/SnapshotApplier.cs` (`ApplyPaidAheadBillsAsync`, ~61–110)
- Modify: `AimPark.API/AimPark.API/Sync/Cloud/EventIngestor.cs` (`MergePayment`, ~194)
- Test: `AimPark.API/AimPark.API.Tests/PayAheadTests.cs`

**Interfaces:** none new.

- [ ] **Step 1: Write the failing test**

In `PayAheadTests`, extend `A_hold_at_the_site_reprices_the_clouds_unpaid_copy`: give `site` `CoversFrom = new DateTime(2026, 11, 19, 6, 2, 0, DateTimeKind.Utc), CoversTo = new DateTime(2026, 11, 19, 8, 2, 0, DateTimeKind.Utc)` and add:

```csharp
        Assert.Equal(site.CoversFrom, cloud.CoversFrom);
        Assert.Equal(site.CoversTo, cloud.CoversTo);
```

- [ ] **Step 2: Implement**

- `SnapshotBuilder`: in the `new PaymentTransaction { ... }` projection for paid-ahead bills, add `CoversFrom = p.CoversFrom, CoversTo = p.CoversTo,`.
- `SnapshotApplier.ApplyPaidAheadBillsAsync`: wherever it copies `AmountDue`/`RatePerHourApplied` from `source` onto the local bill (both the insert and the re-price branch), also copy `CoversFrom` and `CoversTo`.
- `EventIngestor.MergePayment`: in the branch that copies `AmountDue` and `DurationMinutes` from `incoming` onto `existing`, also copy `existing.CoversFrom = incoming.CoversFrom; existing.CoversTo = incoming.CoversTo;`.
- Add the two to the `PaidAheadBills` entry built by the test helper `Snapshot(...)` in `PayAheadTests` too, so the test mirrors the builder.

- [ ] **Step 3: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

```bash
git add AimPark.API/AimPark.API/Sync AimPark.API/AimPark.API.Tests/PayAheadTests.cs
git commit -m "feat(sync): carry a bill's covered stretch between site and cloud"
```

---

### Task 9: 7-minute grace and rate wording

**Files:**
- Modify: `AimPark.API/AimPark.API/Services/GateOptions.cs:33`
- Modify: any `appsettings*.json` that sets `PaidExitGraceMinutes`
- Modify: `AimPark.API/AimPark.API/Services/PaymentService.cs` (`UpsertRateAsync` and `RateChangeMessage`, ~676–757)

**Interfaces:** none.

- [ ] **Step 1: Grace**

Change `public int PaidExitGraceMinutes { get; set; } = 15;` to `= 7;` and update its comment to say the meter pauses for this long after each payment and those minutes are free.

Run: `grep -rn "PaidExitGraceMinutes" AimPark.API --include=*.json` and set any value found to `7`.

- [ ] **Step 2: Rate messages**

The push sent when an admin saves a rate must describe the new rule. In `RateChangeMessage`, return:

```csharp
            return $"{type} parking is now ₱{newRate:0.00} for the first hour, then ₱{newRate / 60m:0.00} a minute (was ₱{oldRate:0.00} an hour). Vehicles already parked keep the rate they came in with.";
```

(Drop the minimum-fee wording and the unused minimum parameters from the call sites if the compiler flags them; keep `MinimumFee` stored as sent.) In the new-rate branch of `UpsertRateAsync`, the message becomes:

```csharp
                $"{vehicleType} parking is now ₱{dto.RatePerHour:0.00} for the first hour, then ₱{dto.RatePerHour / 60m:0.00} a minute. Vehicles already parked keep the rate they came in with.",
```

- [ ] **Step 3: Compile and commit**

Run: `dotnet build AimPark.API/AimPark.API.sln`. Expected: Build succeeded.

```bash
git add AimPark.API
git commit -m "feat(api): 7-minute grace, and rate notices describe the first-hour rule"
```

---

### Task 10: Mobile live fee card (screens 1, 2, 4, 5, 6)

**Files:**
- Modify: `aimpark_mobile/lib/features/parking/data/models/live_fee.dart`
- Modify: `aimpark_mobile/lib/features/parking/presentation/widgets/live_fee_card.dart` (`build`, `_working`, `_howItGrows`)
- Modify: `aimpark_mobile/lib/features/parking/presentation/widgets/pay_ahead_action.dart` (copy only)
- Modify: `aimpark_mobile/lib/features/dashboard/presentation/widgets/parking_rates_card.dart`, `aimpark_mobile/lib/features/payments/data/models/parking_rate.dart` (rate wording)

**Interfaces:**
- Consumes: the `LiveFeeResponse` JSON from Task 6 (`segments`, `payments`, `meterState`, `firstHourEndsAt`, `graceUntil`, `exitTime`, `breakdownMatchesBills`, `leaveBy`).
- Produces (Dart): `class FeeSegment { kind, from, to, minutes, amount }`, `class FeePayment { paymentId, amount, paidAt, method, coversFrom, coversTo }`; `LiveFee` gains `exitTime`, `firstHourEndsAt`, `graceUntil`, `meterState`, `segments`, `payments`, `breakdownMatchesBills`, and getters `isCovered` and `paymentFor(FeeSegment)`; loses `minimumFee`, `meteredSoFar`. Task 12 reuses all of this.

- [ ] **Step 1: Model**

In `live_fee.dart`, remove `minimumFee` and `meteredSoFar` (constructor, fields, `fromJson`). Add the fields below and these classes at the end of the file:

```dart
/// One stretch of a visit: the flat first hour, a per-minute run, or a grace
/// pause after a payment (always free).
class FeeSegment {
  const FeeSegment({
    required this.kind,
    required this.from,
    required this.to,
    required this.minutes,
    required this.amount,
  });

  /// `FirstHour`, `PerMinute` or `Grace`.
  final String kind;
  final DateTime from;
  final DateTime to;
  final int minutes;
  final double amount;

  bool get isGrace => kind == 'Grace';
  bool get isFirstHour => kind == 'FirstHour';

  factory FeeSegment.fromJson(Map<String, dynamic> json) => FeeSegment(
    kind: json['kind'] as String,
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    minutes: (json['minutes'] as num).toInt(),
    amount: (json['amount'] as num).toDouble(),
  );
}

/// A settled bill on this visit, and the stretch it paid for.
class FeePayment {
  const FeePayment({
    required this.paymentId,
    required this.amount,
    this.paidAt,
    this.method,
    this.coversFrom,
    this.coversTo,
  });

  final String paymentId;
  final double amount;
  final DateTime? paidAt;
  final String? method;
  final DateTime? coversFrom;
  final DateTime? coversTo;

  factory FeePayment.fromJson(Map<String, dynamic> json) => FeePayment(
    paymentId: json['paymentId'] as String,
    amount: (json['amount'] as num).toDouble(),
    paidAt: LiveFee._date(json['paidAt']),
    method: json['method'] as String?,
    coversFrom: LiveFee._date(json['coversFrom']),
    coversTo: LiveFee._date(json['coversTo']),
  );
}
```

New `LiveFee` fields (add to the constructor as named parameters with these defaults):

```dart
  final DateTime? exitTime;
  final DateTime firstHourEndsAt;
  final DateTime? graceUntil;

  /// `Free`, `FirstHour`, `Running` or `Paused`.
  final String meterState;
  final List<FeeSegment> segments;
  final List<FeePayment> payments;

  /// False for an old finished visit priced under the previous rules.
  final bool breakdownMatchesBills;

  /// Paid up: nothing owed, and the barrier opens until [leaveBy].
  bool get isCovered => owedNow <= 0 && alreadyPaid > 0 && leaveBy != null;

  /// The payment that covered [s], if one did.
  FeePayment? paymentFor(FeeSegment s) {
    for (final p in payments) {
      final from = p.coversFrom, to = p.coversTo;
      if (from != null && to != null && !s.from.isBefore(from) && !s.to.isAfter(to)) {
        return p;
      }
    }
    return null;
  }
```

`isFree` becomes `bool get isFree => meterState == 'Free';`.

In `fromJson` add:

```dart
    exitTime: _date(json['exitTime']),
    // An older server does not send it: an hour after entry is the rule anyway.
    firstHourEndsAt: _date(json['firstHourEndsAt']) ??
        DateTime.parse(json['entryTime'] as String).add(const Duration(hours: 1)),
    graceUntil: _date(json['graceUntil']),
    meterState: json['meterState'] as String? ?? 'Running',
    segments: [
      for (final s in (json['segments'] as List?) ?? const [])
        FeeSegment.fromJson(s as Map<String, dynamic>),
    ],
    payments: [
      for (final p in (json['payments'] as List?) ?? const [])
        FeePayment.fromJson(p as Map<String, dynamic>),
    ],
    breakdownMatchesBills: json['breakdownMatchesBills'] as bool? ?? true,
```

- [ ] **Step 2: Card**

In `live_fee_card.dart`:

1. Add a one-second ticker that runs only while the driver is covered, so the countdown moves. In `_LiveFeeCardState` add `Timer? _tick;` and `final _sinceFetch = Stopwatch();`. In `_load` after `setState`, call `_sinceFetch..reset()..start();` and:

```dart
      _tick?.cancel();
      if (fee.isCovered) {
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
```

Cancel `_tick` in `dispose` and when paused.

2. Add a helper for "now" on the server's clock:

```dart
  DateTime get _serverNow => _fee!.asOf.add(_sinceFetch.elapsed);
```

3. Replace everything inside `Semantics(child: Column(children: [...]))` in `build` with a call to one of three builders, chosen in this order:

```dart
    final Widget body;
    if (fee.isFree) {
      body = Text('Parking is free right now.', style: context.text.bodySmall);
    } else if (fee.isCovered) {
      body = _covered(context, fee);   // screens 2 and 5
    } else if (fee.alreadyPaid == 0 && fee.meterState == 'FirstHour') {
      body = _firstHour(context, fee); // screen 1
    } else {
      body = _owing(context, fee);     // screens 4 and 6
    }
```

and render `header`, `SizedBox(height: AppSpacing.xs)`, `body`, then the existing `paymentProcessing` notice.

4. Write the three builders. Use the app's own widgets and tokens already imported (`context.text`, `context.tokens`, `AppSpacing`, `AppTypography.tabular`, `Formatters`). Copy must match the canvas.

```dart
  /// Screen 1: inside the first hour, nothing paid.
  Widget _firstHour(BuildContext context, LiveFee fee) {
    final t = context.tokens;
    final entry = fee.firstHourEndsAt.subtract(const Duration(hours: 1));
    final used = fee.durationMinutes.clamp(0, 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FIRST HOUR · FLAT FEE', style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${Formatters.peso(fee.ratePerHour)} covers '
          '${Formatters.time(entry)} – ${Formatters.time(fee.firstHourEndsAt)}',
          style: AppTypography.tabular(context.text.titleMedium!),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: used / 60,
            minHeight: 8,
            backgroundColor: t.surface.muted,
            color: t.tertiary.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          Text('$used min used', style: context.text.bodySmall),
          const Spacer(),
          Text('${60 - used} min left', style: context.text.bodySmall),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Leave any time before ${Formatters.time(fee.firstHourEndsAt)} and '
          'you pay ${Formatters.peso(fee.ratePerHour)}, no more. After that the '
          'meter counts per minute (${Formatters.peso(fee.ratePerHour / 60)} a minute).',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _totalRow(context, 'To pay before you exit', fee.owedNow, bold: true),
      ],
    );
  }

  /// Screens 2 and 5: paid up, countdown to when the meter starts again.
  Widget _covered(BuildContext context, LiveFee fee) {
    final leaveBy = fee.leaveBy!;
    var left = leaveBy.difference(_serverNow);
    if (left.isNegative) left = Duration.zero;
    final mm = left.inMinutes;
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final inFirstHour = !leaveBy.isAfter(fee.firstHourEndsAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEAVE BY ${Formatters.time(leaveBy).toUpperCase()}',
            style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text('$mm:$ss left',
            style: AppTypography.tabular(context.text.headlineMedium!)),
        Text(
          inFirstHour
              ? 'Meter is not running. Your first hour is paid until '
                  '${Formatters.time(fee.firstHourEndsAt)}.'
              : 'Paid. The meter is paused so you can leave. Tap your card at '
                  'the gate and it opens.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Still inside at ${Formatters.time(leaveBy)}? The meter starts again '
          'at ${Formatters.peso(fee.ratePerHour / 60)} a minute. '
          '${inFirstHour ? '' : 'These 7 minutes stay free.'}',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final p in fee.payments)
          _totalRow(
            context,
            'Paid ${p.paidAt == null ? '' : Formatters.time(p.paidAt!)}',
            p.amount,
          ),
      ],
    );
  }

  /// Screens 4 and 6: the breakdown, line by line, and what is still owed.
  Widget _owing(BuildContext context, LiveFee fee) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STILL TO PAY', style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(Formatters.peso(fee.owedNow),
            style: AppTypography.tabular(context.text.headlineMedium!)),
        const SizedBox(height: AppSpacing.sm),
        for (final s in fee.segments) ...[
          _segmentRow(context, fee, s, t),
          const SizedBox(height: AppSpacing.xs),
        ],
        const Divider(),
        _totalRow(context, 'Total so far', fee.totalSoFar),
        if (fee.alreadyPaid > 0) _totalRow(context, 'Already paid', -fee.alreadyPaid),
        _totalRow(context, 'Still to pay', fee.owedNow, bold: true),
        const SizedBox(height: AppSpacing.xs),
        Text(_howItGrows(fee), style: context.text.bodySmall),
      ],
    );
  }

  Widget _segmentRow(BuildContext context, LiveFee fee, FeeSegment s, AppTokens t) {
    final range = '${Formatters.time(s.from)} – ${Formatters.time(s.to)}';
    final (title, detail) = switch (s.kind) {
      'FirstHour' => ('First hour · flat', range),
      'Grace' => ('Grace · meter paused', '$range · ${s.minutes} min'),
      _ => ('Per minute', '$range · ${s.minutes} min × '
          '${Formatters.peso(fee.ratePerHour / 60)}'),
    };
    final paid = fee.paymentFor(s);
    final note = s.isGrace
        ? 'Free'
        : paid != null && paid.paidAt != null
            ? 'Paid ${Formatters.time(paid.paidAt!)}'
            : 'Not paid';
    final noteColor = s.isGrace
        ? t.text.secondary
        : paid != null ? t.status.success.fg : t.status.warning.fg;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.titleSmall),
            Text(detail, style: context.text.bodySmall),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Formatters.peso(s.amount),
              style: AppTypography.tabular(context.text.titleSmall!)),
          Text(note, style: context.text.bodySmall?.copyWith(color: noteColor)),
        ]),
      ],
    );
  }

  Widget _totalRow(BuildContext context, String label, double amount, {bool bold = false}) {
    final style = bold ? context.text.titleSmall : context.text.bodyMedium;
    final value = amount < 0
        ? '− ${Formatters.peso(-amount)}'
        : Formatters.peso(amount);
    return Row(children: [
      Text(label, style: style),
      const Spacer(),
      Text(value, style: AppTypography.tabular(style!)),
    ]);
  }
```

`AppTokens` is the type of `context.tokens`; use the real class name from `core/theme` if it differs (check `extension ... on BuildContext { ... get tokens }`).

5. Replace `_howItGrows` with:

```dart
  String _howItGrows(LiveFee fee) {
    final next = fee.nextChangeAt;
    final rate = '${Formatters.peso(fee.ratePerHour)} an hour';
    if (next == null) return '$rate, counted per minute after the first hour.';
    return '$rate, counted per minute after the first hour. Goes up to '
        '${Formatters.peso(fee.nextTotal ?? fee.totalSoFar)} at ${Formatters.time(next)}.';
  }
```

Delete `_working`.

- [ ] **Step 3: Pay-ahead copy**

In `pay_ahead_action.dart`:
- Paid notice message: `'Tap your card at the gate by ${Formatters.time(session.leaveBy!)} and the barrier opens. After that the meter starts again.'`
- `ranOut` text: `'Your paid time ended at ${Formatters.time(session.leaveBy!)}. Pay the extra time before you go to the gate.'`
- Button labels stay. Under the button add: `Text('After you pay, the meter pauses for 7 minutes so you can leave.', style: context.text.bodySmall, textAlign: TextAlign.center)`.

- [ ] **Step 4: Rate wording**

In `parking_rates_card.dart` (and `parking_rate.dart` if it builds the label), every rate line reads `'${Formatters.peso(r.ratePerHour)} for the first hour, then ${Formatters.peso(r.ratePerHour / 60)} a minute'`. Remove any "minimum" wording.

- [ ] **Step 5: Analyze and commit**

Run (static check only): `cd aimpark_mobile && flutter analyze`. Expected: No issues found (or only issues that existed before; compare with `git stash` if unsure).

```bash
git add aimpark_mobile/lib
git commit -m "feat(mobile): live fee shows first hour, per-minute and grace, with countdown"
```

---

### Task 11: Mobile bill detail says what it covers (screens 7, 8)

**Files:**
- Modify: `aimpark_mobile/lib/features/payments/data/models/payment.dart`
- Modify: `aimpark_mobile/lib/features/payments/presentation/screens/payment_detail_screen.dart` (the `AppFactsCard` around lines 331–375)

**Interfaces:**
- Consumes: `PaymentResponse.coversFrom`, `coversTo`, `graceUntil` (Task 3).
- Produces: `Payment.coversFrom`, `Payment.coversTo`, `Payment.graceUntil` (`DateTime?`), getter `bool get includesFirstHour => entryTime != null && coversFrom != null && !coversFrom!.isAfter(entryTime!)`.

- [ ] **Step 1: Model**

Add the three nullable `DateTime` fields, read in `fromJson` the same way `paidAt` is read (`json['coversFrom'] == null ? null : DateTime.parse(...)`), and the `includesFirstHour` getter.

- [ ] **Step 2: Facts**

Replace the parking (non-violation) facts in the `AppFactsCard` with:

```dart
                if (!payment.isViolation) ...[
                  if (payment.coversFrom != null && payment.coversTo != null)
                    AppFact(
                      'Covers',
                      '${Formatters.time(payment.coversFrom!)} – '
                          '${Formatters.time(payment.coversTo!)}',
                    ),
                  AppFact('Minutes', '${payment.durationMinutes} min'),
                  AppFact(
                    'Rate',
                    '${Formatters.peso(payment.ratePerHourApplied)}/hr '
                        '(${Formatters.peso(payment.ratePerHourApplied / 60)}/min)',
                  ),
                  if (payment.coversFrom != null)
                    AppFact('Calculation', _calculation(payment)),
                  if (payment.graceUntil != null && payment.paidAt != null)
                    AppFact(
                      'Grace (meter paused)',
                      '${Formatters.time(payment.paidAt!)} – '
                          '${Formatters.time(payment.graceUntil!)}',
                    ),
                  if (payment.entryTime != null)
                    AppFact('Entered', _dateTime(payment.entryTime!)),
                  if (payment.exitTime != null)
                    AppFact('Left', _dateTime(payment.exitTime!)),
                ],
                AppFact(
                  payment.isViolation ? 'Issued' : 'Created',
                  _dateTime(payment.createdAt),
                ),
                if (payment.paidAt != null)
                  AppFact('Paid', _dateTime(payment.paidAt!),
                      intent: StatusIntent.success),
```

(keep the existing `Method` and `Reference` facts after these, and drop the old `Duration`, `Rate`, date-only `Created`/`Paid` facts they replace).

Add to the state class:

```dart
  /// "Thu, Nov 19 · 3:32 PM": a bill can be paid on another day than the visit.
  String _dateTime(DateTime t) =>
      '${Formatters.date(t.toLocal())} · ${Formatters.time(t)}';

  /// "90 × ₱20.00 ÷ 60 = ₱30.00", or with the flat first hour in front.
  String _calculation(Payment p) {
    final r = p.ratePerHourApplied;
    if (p.includesFirstHour) {
      final extra = p.durationMinutes - 60;
      return extra <= 0
          ? 'First hour, flat = ${Formatters.peso(p.amountDue)}'
          : 'First hour ${Formatters.peso(r)} + $extra × ${Formatters.peso(r)} ÷ 60 '
              '= ${Formatters.peso(p.amountDue)}';
    }
    return '${p.durationMinutes} × ${Formatters.peso(r)} ÷ 60 = '
        '${Formatters.peso(p.amountDue)}';
  }
```

- [ ] **Step 3: Unpaid bill note and visit link**

Below the facts card, for a parking bill:

```dart
            if (!payment.isViolation && !payment.isPaid && payment.exitTime == null)
              Text(
                'If you wait before paying, this bill is priced again at your next '
                'tap. The meter does not stop because you tapped.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            if (!payment.isViolation && payment.parkingLogId != null)
              Align(
                child: AppTextLink(
                  label: 'See whole visit',
                  icon: Icons.chevron_right_rounded,
                  onTap: () => context.push(
                    '/home/user/parking/visits/${payment.parkingLogId}',
                  ),
                ),
              ),
```

- [ ] **Step 4: Analyze and commit**

Run: `cd aimpark_mobile && flutter analyze`. Expected: no new issues. (The route is added in Task 12; analyze does not check route strings.)

```bash
git add aimpark_mobile/lib/features/payments
git commit -m "feat(mobile): each bill shows what it covers, the sum and its grace"
```

---

### Task 12: Mobile visit details screen (screens 3, 9)

**Files:**
- Create: `aimpark_mobile/lib/features/parking/presentation/screens/visit_details_screen.dart`
- Modify: `aimpark_mobile/lib/router/app_router.dart` (next to `/home/user/payments/:paymentId`, ~line 270)
- Modify: `aimpark_mobile/lib/features/parking/presentation/screens/parking_history_screen.dart` (~line 85)

**Interfaces:**
- Consumes: `parkingRepositoryProvider.liveFee(logId)` returning `LiveFee` (Task 10; the server now answers for closed visits).
- Produces: route `/home/user/parking/visits/:logId` → `VisitDetailsScreen(logId: ...)`.

- [ ] **Step 1: Screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_facts_card.dart';
import '../../data/models/live_fee.dart';
import '../providers/parking_history_provider.dart';

/// One visit from entry to exit: what it cost, stretch by stretch, and each
/// payment. Priced by the server exactly as the gate priced it.
final _visitProvider = FutureProvider.autoDispose.family<LiveFee, String>(
  (ref, logId) => ref.read(parkingRepositoryProvider).liveFee(logId),
);

class VisitDetailsScreen extends ConsumerWidget {
  const VisitDetailsScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visit = ref.watch(_visitProvider(logId));
    return Scaffold(
      appBar: AppBar(title: const Text('Visit details')),
      body: visit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            "Couldn't load this visit. Check your connection and try again.",
            style: context.text.bodyMedium,
          ),
        ),
        data: (fee) => _Body(fee: fee),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.fee});

  final LiveFee fee;

  String _dateTime(DateTime t) =>
      '${Formatters.date(t.toLocal())} · ${Formatters.time(t)}';

  @override
  Widget build(BuildContext context) {
    final entry = fee.firstHourEndsAt.subtract(const Duration(hours: 1));
    final end = fee.exitTime ?? fee.asOf;
    final grace = fee.segments
        .where((s) => s.isGrace)
        .fold<int>(0, (sum, s) => sum + s.minutes);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppFactsCard(
          title: fee.owedNow <= 0 ? 'Paid in full' : 'Still to pay',
          facts: [
            AppFact('Entered', _dateTime(entry)),
            if (fee.exitTime != null) AppFact('Left', _dateTime(fee.exitTime!)),
            AppFact('Time parked', Formatters.duration(end.difference(entry))),
            if (fee.owedNow > 0)
              AppFact('Still to pay', Formatters.peso(fee.owedNow),
                  intent: StatusIntent.warning),
          ],
          total: AppFact('Total for this visit', Formatters.peso(fee.totalSoFar)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (fee.breakdownMatchesBills)
          AppFactsCard(
            title: 'How it was charged',
            facts: [
              for (final s in fee.segments)
                AppFact(
                  switch (s.kind) {
                    'FirstHour' => 'First hour · flat',
                    'Grace' => 'Grace · meter paused',
                    _ => 'Per minute · ${s.minutes} min',
                  },
                  '${Formatters.time(s.from)} – ${Formatters.time(s.to)}  '
                  '${Formatters.peso(s.amount)}',
                ),
              if (grace > 0) AppFact('Free grace time', '$grace min'),
            ],
            total: AppFact('Total', Formatters.peso(fee.totalSoFar)),
          )
        else
          Text(
            'This visit was charged under the earlier rules. Its payments are '
            'below.',
            style: context.text.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        AppFactsCard(
          title: 'Payments',
          facts: [
            for (final p in fee.payments)
              AppFact(
                p.paidAt == null ? 'Paid' : 'Paid ${_dateTime(p.paidAt!)}',
                '${Formatters.peso(p.amount)}${p.method == null ? '' : ' · ${p.method}'}',
                intent: StatusIntent.success,
              ),
          ],
          total: AppFact('Total paid', Formatters.peso(fee.alreadyPaid)),
        ),
        for (final p in fee.payments)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/home/user/payments/${p.paymentId}'),
              child: Text('Receipt for ${Formatters.peso(p.amount)}'),
            ),
          ),
      ],
    );
  }
}
```

Check before writing: the import path of `parkingRepositoryProvider` (the live fee card imports `../providers/parking_history_provider.dart`; use the same), and that `AppFactsCard` takes `title`, `facts`, `total` (it does in `payment_detail_screen.dart`). If the app has its own back-bar widget (look at how `PaymentDetailScreen` builds its top bar) use that instead of `AppBar`, so it looks the same.

- [ ] **Step 2: Route**

In `app_router.dart`, after the `/home/user/payments/:paymentId` route:

```dart
      GoRoute(
        path: '/home/user/parking/visits/:logId',
        builder: (context, state) => VisitDetailsScreen(
          logId: state.pathParameters['logId']!,
        ),
      ),
```

and import the screen.

- [ ] **Step 3: History opens the visit**

In `parking_history_screen.dart`, change the row's `onTap` to open the visit for every row:

```dart
                    onTap: () => context.push(
                      '/home/user/parking/visits/${log.logId}',
                    ),
```

- [ ] **Step 4: Analyze and commit**

Run: `cd aimpark_mobile && flutter analyze`. Expected: no new issues.

```bash
git add aimpark_mobile/lib
git commit -m "feat(mobile): visit details screen with the visit's timeline and payments"
```

---

### Task 13: Mobile payments list says what each bill covers (screen 10)

**Files:**
- Modify: `aimpark_mobile/lib/features/payments/presentation/screens/payments_list_screen.dart` (`_PaymentRow`, ~426–537)

**Interfaces:**
- Consumes: `Payment.coversFrom`, `coversTo`, `includesFirstHour` (Task 11).

Scope note: the canvas groups payments by visit. This task keeps the existing day sections and puts the coverage on every row. Grouping is one tap away: each bill links to "See whole visit". Say so in the hand-off. The owner decides whether full grouping is worth a follow-up.

- [ ] **Step 1: Row title and subtitle**

In `_PaymentRow`, change `title` for parking bills:

```dart
      title: isViolation
          ? 'Violation fine'
          : payment.coversFrom == null
              ? 'Parking fee'
              : payment.includesFirstHour
                  ? (payment.durationMinutes > 60 ? 'First hour + per minute' : 'First hour')
                  : 'Per-minute time',
```

and in `_when`, when `payment.coversFrom` and `coversTo` are set, return:

```dart
      return '${Formatters.dateShort(payment.coversFrom!.toLocal())} · covers '
          '${Formatters.time(payment.coversFrom!)}–${Formatters.time(payment.coversTo!)} · '
          '${payment.durationMinutes} min';
```

(before the existing entry/exit fallback, which stays for older bills).

- [ ] **Step 2: Analyze and commit**

Run: `cd aimpark_mobile && flutter analyze`. Expected: no new issues.

```bash
git add aimpark_mobile/lib/features/payments/presentation/screens/payments_list_screen.dart
git commit -m "feat(mobile): payment rows say which stretch of the visit they cover"
```

---

### Task 14: Admin panel

**Files:**
- Modify: `aimpark_admin/lib/models/payment.dart` (add coverage; remove `minimumFeeApplied` ~55–60)
- Modify: `aimpark_admin/lib/screens/payments_screen.dart` (table columns ~92–100 and rows; receipt ~127–245; rate list ~316; rate form ~440–474)
- Modify: `aimpark_admin/lib/providers/payments_provider.dart` (~95, `upsertRate`)

**Interfaces:**
- Consumes: `PaymentResponse.coversFrom`, `coversTo` (Task 3).

- [ ] **Step 1: Model**

Add `final DateTime? coversFrom; final DateTime? coversTo;` read from JSON like `paidAt`. Delete `minimumFeeApplied` and fix the two places that used it (Step 2).

- [ ] **Step 2: Payments table and receipt**

- Add `DataColumn(label: Text('Covers'))` after `Paid by`, and in each row a cell showing `from–to` times (`—` when null), formatted the way the row's other times are.
- In the receipt dialog, after `Exit`, add `_ReceiptRow(label: 'Covers', value: ...)`, and delete the `minimumFeeApplied` notice and the `Minimum fee` receipt row.

- [ ] **Step 3: Rate form**

- Remove the "Minimum fee" field and its controller and validator (~line 440).
- Label the rate field `'Hourly rate (first hour charged in full)'`, with helper text `'Charged in full for the first hour, then per minute.'`.
- The rate list line (~316) reads `'${_money.format(r.ratePerHour)} first hour, then per minute'`, with no minimum.
- `upsertRate(vehicleType!, rate)`: stop passing `minimumFee`. In `payments_provider.dart` make `minimumFee` optional and omit it from the body when null (the API keeps the stored value when it is absent).

- [ ] **Step 4: Analyze and commit**

Run: `cd aimpark_admin && flutter analyze`. Expected: no new issues.

```bash
git add aimpark_admin/lib
git commit -m "feat(admin): payments show what each bill covers; rate form drops the minimum"
```

---

### Task 15: Final checks and hand-off

**Files:**
- Modify: `docs/superpowers/specs/2026-11-21-parking-fee-redesign-design.md` (two corrections below)

- [ ] **Step 1: Align the spec with what was built**

In the spec:
- Under **Bills**, replace the `GraceUntil` column bullet with: "`GraceUntil` is not stored. Responses work it out as paid time + grace."
- Under **Screens**, note on screen 10: "Built as rows that say what they cover, inside the existing day sections. Full grouping by visit is left for later."

- [ ] **Step 2: Static checks**

Run, explaining each first:
- `dotnet build AimPark.API/AimPark.API.sln`: the API compiles with no `[Obsolete]` warnings.
- `cd aimpark_mobile && flutter analyze` and `cd aimpark_admin && flutter analyze`: no new issues.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-11-21-parking-fee-redesign-design.md
git commit -m "docs: spec matches the fee redesign as built"
```

- [ ] **Step 4: Hand-off note to the owner (not run by the executor)**

1. `dotnet test AimPark.API/AimPark.API.Tests`: all of `ParkingFeeMathTests`, `PayBeforeExitTests`, `PayAheadTests`, `CloudMigrationsTests` should pass.
2. Apply the migration only after checking `dotnet ef migrations list` (shared database): `dotnet ef database update --project AimPark.API/AimPark.API`. It only adds two nullable columns, so the deployed `main` keeps working.
3. On a phone, walk the canvas scenarios: pay inside the first hour, stay past it, pay, wait out the 7 minutes, tap out without paying, then check the bill, the visit and the payments list.
4. Not built: grouping the payments list by visit (screen 10). GCash/Maya will refuse bills under ₱20 once live PayMongo is on.
