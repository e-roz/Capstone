# RFID + ALPR dual-factor — database plan

Scope of this doc: schema only. No endpoints, no services, no UI — just what
tables/columns need to exist before any of that can be built. Decided so far
(2026-09-09): local `fast-alpr` on a separate desktop app per gate, pushing
results to the API; RFID identifies the card holder, ALPR checks the plate
actually in front of the camera matches something registered to that holder;
a mismatch is flagged, not treated the same as an invalid card.

## What's already there (no changes needed)

- **`Vehicle.PlateNumber`** and **`VisitorPass.PlateNumber`** — both already
  stored uppercase/unspaced. This is what ALPR's reading gets compared
  against. Visitors are already covered: a guard typing a visitor's plate in
  at issue time (`SecurityController.IssuePass`) means ALPR can check
  visitors too, not just registered users.
- **`GateDevice`** — hardware already authenticates with a long-lived API key
  bound to one `Gate` number, via `AdminGateDevicesController` /
  `ApiKeyDefaults`. The ALPR desktop app should register as one of these,
  the same way the ESP32 reader does. No new auth mechanism.
- **`AdminParkingController.LogEntry`** — already resolves `dto.Gate` from
  the *device's own claim*, not the request body, so a leaked key can't log
  against the wrong gate. Same protection should extend to ALPR's device.

## New: `GateDeviceType` enum

```csharp
public enum GateDeviceType
{
    RfidReader,
    AlprCamera,
}
```

Add a `DeviceType` column to `GateDevice` (default `RfidReader` so the
existing rows/migration stay valid). Reason to bother: without it, a leaked
RFID reader key could post fake ALPR plate reads, or vice versa. Each
endpoint checks the caller's device type, not just that *some* device key was
presented.

## New entity: `AlprReading`

The raw feed of what a camera saw — one row per plate the ALPR app reports,
independent of whether an RFID tap ever shows up to match it.

```csharp
public class AlprReading
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// Which barrier, taken from the device's own claim — same
    /// anti-spoofing rule as ParkingLog.
    public int Gate { get; set; }

    /// Normalized uppercase/unspaced, matching Vehicle.PlateNumber.
    public string PlateNumber { get; set; } = string.Empty;

    /// fast-alpr's OCR confidence (0–1), so a low-confidence read can be
    /// weighted differently than a clean one instead of trusted equally.
    public double? Confidence { get; set; }

    public Guid DeviceId { get; set; }
    public GateDevice Device { get; set; } = null!;

    public DateTime ReadAt { get; set; } = DateTime.UtcNow;

    /// Set once an RFID entry has matched against this reading, so the same
    /// camera frame can't be reused for a second car.
    public DateTime? ConsumedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

Matching happens when `LogEntryAsync` runs: look up the most recent
*unconsumed* `AlprReading` for that gate within a short window (open question
below), mark it consumed, compare its plate against the card holder's
registered vehicles (or the visitor pass's plate).

## Extend `ParkingLog`

So the outcome of the check survives on the record, not just the moment it
happened:

```csharp
public Guid? AlprReadingId { get; set; }
public AlprReading? AlprReading { get; set; }

/// Denormalized copy of what was read, kept even if the AlprReading row
/// is ever pruned — same reasoning as RfidCard.LastUserName.
public string? AlprPlateNumber { get; set; }

/// Null = no camera reading was available to check against (camera
/// offline, or nothing arrived in the matching window).
/// True = the read plate matched a plate registered to this card holder.
/// False = a plate was read but didn't match anything on file.
public bool? AlprMatched { get; set; }
```

## Decided (2026-09-09): mismatch and camera failure

A mismatch means no entry — but it gets logged, not silently dropped. And a
broken ALPR camera should degrade to the same fallback the RFID reader
already has, not invent a second one: **the guard clears it by hand from
Gate Check**, exactly like they do today when a reader won't scan.

This means denied attempts need to be recorded somewhere. They can't go into
`ParkingLog` — that table's whole invariant, leaned on everywhere (occupancy
counts, active-session lists, fee calc on exit), is "a row here means this
vehicle actually got in." A denied car was never inside. Mixing the two
means either every one of those queries needs a status filter bolted on, or
occupancy silently double-counts a car that got turned away. So denials get
their own table, and only a granted/overridden attempt ever writes to
`ParkingLog`.

### New entity: `GateAccessAttempt`

```csharp
public enum GateAccessOutcome
{
    /// RFID valid, ALPR read a plate, it didn't match anything on file.
    PlateMismatch,

    /// RFID valid, but no usable ALPR reading — camera confirmed down
    /// (stale heartbeat) or nothing arrived in the matching window. Logged
    /// the same way either way; a guard's fix is identical regardless of
    /// which one it was.
    AlprUnavailable,
}

public class GateAccessAttempt
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public int Gate { get; set; }
    public string RfidTagId { get; set; } = string.Empty;

    /// Whoever the tag resolved to — exactly one of these two, same as
    /// ParkingLog's UserId/VisitorPassId split.
    public Guid? UserId { get; set; }
    public Guid? VisitorPassId { get; set; }

    public string? AlprPlateNumber { get; set; }
    public double? AlprConfidence { get; set; }

    public GateAccessOutcome Outcome { get; set; }

    /// Set once a guard has looked at this and made a call.
    public Guid? ReviewedByUserId { get; set; }
    public DateTime? ReviewedAt { get; set; }

    /// Set if the guard overrode it and let the vehicle in — points at the
    /// ParkingLog row Gate Check created, so the attempt and the eventual
    /// entry stay traceable to each other.
    public Guid? ResultingLogId { get; set; }

    public DateTime AttemptedAt { get; set; } = DateTime.UtcNow;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

### Detecting a dead camera

`GateDevice.LastSeenAt` already exists ("last time this device successfully
authenticated") but today that only updates when a device happens to call
something. The ALPR app needs to call the API on a steady interval —
whether or not it currently sees a plate — so `LastSeenAt` reflects "the
camera process is alive and reachable," not just "it happened to read a
plate recently." A gate's camera counts as down when its `AlprCamera`
device's `LastSeenAt` is older than some threshold (open question below).

Note this is a real policy choice, not a neutral default: it means every
car gets stopped and needs a guard's eyes whenever the camera hiccups, in
exchange for never silently letting a car through unverified. If that's
too strict once you're testing it live — e.g. it turns out ALPR drops out
often enough that guards are doing this constantly — the alternative is
fail-open (RFID alone is enough when the camera's confirmed dead, logged
as `AlprUnavailable` but not blocking). Easy to flip later; starting strict
since that's what you described.

## Open questions — need your call before I write the migration

1. **Matching window.** How long after an RFID tap should the system wait
   for a plate to have been read (or look back for one already read)? Too
   short and a slightly early/late camera read gets missed; too long and it
   risks matching the wrong car's plate to this tap. I'd guess 5–8 seconds
   but you know the physical gate layout better than I do.

2. **Heartbeat staleness threshold.** How long without a ping before a
   gate's camera counts as "down"? Needs to be longer than the heartbeat
   interval by a comfortable margin so one dropped network packet doesn't
   flag it — I'd guess a 15–20s heartbeat with a 45–60s staleness
   threshold, but this is a live-tuning question more than a design one.

## Explicitly not in this pass

Endpoint for the ALPR app to post a reading, the matching logic inside
`LogEntryAsync`, the Python service itself, and any UI changes (Gate Check,
System Logs) all come after the schema and the three questions above are
settled.
