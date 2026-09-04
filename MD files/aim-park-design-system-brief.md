# AIM-Park — Emotional Design System Brief

**For:** Claude Code (Flutter implementation)
**Status:** Specification. Decisions below are settled — implement, don't re-litigate.

---

## 1. What this system is for

AIM-Park is a campus smart-parking app. The user is usually in a vehicle, in a hurry, often in direct sunlight, using one hand, and glancing between the screen and the gate.

**The core inversion:** unlike engagement-driven apps, success here is the user leaving the app quickly. The target emotions are **relief, confidence, and calm** — never delight, guilt, or streak anxiety. There is no mascot and no gamification. Emotion is carried by **color, motion, haptics, and copy** only.

**The one rule that governs everything:** a red state must always carry an alternative. The app never presents a dead end.

---

## 2. Personality: warm competence

Three voice rules:

1. **Fact first, help second.** The user should never read personality before information. Warmth lives in the second sentence.
2. **Never blame the user.** "Didn't catch that," not "Invalid RFID."
3. **Warmth rises as urgency falls.** Coldest and shortest while the user is driving. Warmest and most helpful when something has gone wrong.

Language: **English only**, sentence case throughout, no all-caps labels.

---

## 3. Color

Grounded in parking vernacular: asphalt, painted lot markings, sodium lamp light. Chosen for sunlight legibility, not screenshot appeal.

### Base

| Token | Hex | Role |
|---|---|---|
| `surface.asphalt` | `#23262B` | Primary dark surface, map background |
| `surface.raised` | `#2E3238` | Cards, sheets on dark |
| `paint.white` | `#F2F4F1` | Primary text on dark, lot markings |
| `paint.muted` | `#A3A9A6` | Secondary text, inactive markings |
| `signal.blue` | `#2F6FD0` | All interactive elements — buttons, links, controls |

### Availability confidence (status only)

| Token | Hex | Meaning |
|---|---|---|
| `avail.open` | `#1E9E5A` | Comfortable — plenty of space |
| `avail.filling` | `#E08A18` | Filling up — the emotional state; user decides whether to hurry |
| `avail.full` | `#C0492F` | Full — muted brick, not alarm red |

**Hard rule:** availability colors are reserved for availability. Never use green for a confirm button or red for a destructive action. Interactive intent is always `signal.blue`. This keeps status readable at a glance without the user parsing context.

`avail.filling` is the most important state in the system. It deserves the most design attention — it is the moment the user is actually making a decision.

---

## 4. Typography

**Family: Barlow** (single family, weight-differentiated). Chosen deliberately — Barlow descends from American road signage, which matches the domain and gives clean, unambiguous numerals for slot IDs and counts.

Use **Barlow Semi Condensed** for large numerals only (slot counts, slot IDs), where horizontal space is tight and the number must dominate.

| Role | Size / Weight | Notes |
|---|---|---|
| Slot count display | 48 / 600, Semi Condensed | The hero number on the availability screen |
| Slot ID | 32 / 600, Semi Condensed | e.g. "B-14" |
| Screen title | 24 / 600 | |
| Section heading | 18 / 600 | |
| Body | 16 / 400 | Minimum body size — outdoor legibility |
| Support / caption | 14 / 400 | Never smaller than this anywhere in the app |

No all-caps labels. No eyebrow labels above headings. No monospace for data.

---

## 5. Motion

**One curve for the whole app:** firm ease-out, no bounce. Confident, not playful.

| Token | Duration | Curve |
|---|---|---|
| `motion.micro` | 120ms | easeOutCubic — taps, toggles, state flips |
| `motion.standard` | 200ms | easeOutCubic — transitions, sheets, map updates |
| `motion.gate` | 380ms | easeOutBack, minimal overshoot |

**`motion.gate` is the only exception in the entire app** and is used exclusively for the gate-open confirmation. It is the single signature motion moment. Because everything else is calm, this one moment carries real emotional weight. Do not reuse it elsewhere — reusing it destroys it.

Respect the platform reduced-motion setting: fall back to a cross-fade at `motion.standard`, and never remove the state change itself.

---

## 6. Haptics

Critical for this app — the user's eyes are on the gate, not the screen. The haptic is often the real feedback channel.

| Event | Pattern |
|---|---|
| Success (gate open, registration complete) | One medium impact |
| Warning (lot filling, low balance) | Two light impacts, ~80ms apart |
| Error (RFID not read, payment failed) | One light impact, or none |

Errors get the *weakest* haptic. Do not punish the user for a failure the system caused.

**Sound: off by default.** A parking lot is loud; audio is wasted and intrusive.

---

## 7. Voice and tone matrix

| State | Copy |
|---|---|
| Gate open | You're in. Slot B-14 is open. |
| Gate open, returning user | Welcome back, Jean. |
| Lot filling | Gate A is filling up — 4 slots left. |
| Lot full | Gate A is full right now. Gym Lot has 6 open — about a 2-minute walk. |
| RFID not read | Didn't catch that. Move a little closer to the reader. |
| Pre-arrival suggestion | Based on your Monday schedule, Gate A is usually still open around 8:10. |
| Onboarding start | Let's get your vehicle registered. Takes about a minute. |
| Empty history | Nothing here yet. Your parking history appears after your first entry. |
| Connection lost | Can't reach the gate system. Showing your last known status from 2 minutes ago. |

Note the pattern: the longest, warmest copy is on the failure states. That is where trust is built.

Buttons name their action and keep that name through the flow — a button that says "Register vehicle" produces a confirmation that says "Vehicle registered."

---

## 8. Components to build

Priority order. The first two are cheap and carry most of the emotional payload — build them first.

1. **Gate feedback view** — full-bleed status, `motion.gate`, success haptic, minimal copy. The peak moment of the app.
2. **Failure / alternative card** — the component that enforces the "red always carries an alternative" rule. It must structurally require an alternative action; make the alternative a required parameter, not an optional one.
3. **Availability header** — the hero slot count with confidence color.
4. **Slot map cell** — three availability states plus a selected state.
5. **Onboarding step** — single task per screen, progress visible, no celebration until the end.
6. **Pre-arrival suggestion card** — depends on the ML feature; build last.

---

## 9. Accessibility floor

- Minimum tap target 48dp — the user may be wearing gloves or bracing against a steering wheel.
- All status must be distinguishable without color alone: pair every availability color with a label or count.
- Contrast tested against outdoor sunlight, not indoor screenshots. Verify `avail.filling` on `surface.asphalt` specifically — amber on dark is the most likely failure.
- Never rely on the haptic alone; it always accompanies a visible state change.

---

## 10. Out of scope

Do not add: mascots or characters, streaks, points, badges, celebratory confetti, sounds, animated illustrations, or a second motion curve. Every one of these has been considered and deliberately rejected. If a screen feels flat, the fix is better copy and clearer hierarchy, not more decoration.
