# Billing rules and mid-session changes — owner decision needed

Status: **open — needs owner input.** No behaviour was changed; the current
behaviour is pinned by `test/domain/services/segment_change_billing_test.dart`.

## How it works today

A session is billed segment by segment. A new segment starts — at the exact
instant — whenever staff change the controllers, the game or the system. Each segment
is priced on its own with the
session's frozen price list; only the final cash rounding (nearest ₹1) is
applied once to the whole bill.

The owner-selectable rules in **Settings → Billing rules** are therefore
applied **per segment**:

| Rule | Shipped default | Effect of a mid-session change today |
|---|---|---|
| Billing unit | per minute | Exact proration. No effect. |
| Block billing (15/30/60, rounded up) | off | Each segment is rounded up on its own, so a change can add billed time. |
| Minimum charge | 0 min | Each segment is charged at least the minimum. |
| Grace | 0 min | A segment shorter than the grace is free. |

Worked example — one hour played, 20 min on 1 controller then 40 min on 2
(₹150/h and ₹280/h, standard band):

| Policy | Billed | Why |
|---|---|---|
| Default (per-minute) | ₹237 | ₹50 + ₹186.67 — exact |
| Block 30, round up | ₹355 | 20→30 min (₹75) + 40→60 min (₹280): 90 min billed for 60 played |
| Minimum charge 30 min | ₹262 | the 20-min segment is billed as 30 |
| Grace 5 min, controller added at 58 min | ₹145 | the 2-min tail is under grace, so free |

With the defaults the app ships with, billing is exact and nothing needs to
change. The question only matters if block billing, a minimum charge or a
grace period is switched on.

## The decision

When block billing, a minimum charge or grace is turned on, should it apply:

- **A — per segment (current behaviour).** Simple and already shipped, but a
  customer who adds a controller, swaps a game or moves system mid-session can
  be billed for extra blocks / minimums, or get a short tail free.
- **B — once per session.** Price each segment by the minute, then apply
  block rounding, the minimum and grace once to the session's total time. A
  change never costs extra time. Needs a change to `SegmentBilling`
  and new billing tests; existing per-minute bills unchanged.
- **C — per segment, but changes made by staff carry no extra charge** (e.g.
  no minimum/grace on segments that start because of a change). A middle
  ground; more rules to explain at the counter.

This affects controller changes, game changes and system switches
equally — it is not new with controller allocation.

## Recommendation

Leave the default (per-minute) on. If the owner wants block billing, a minimum
or grace, choose **B** so changes never cost the customer extra time. Until
then nothing changes.
