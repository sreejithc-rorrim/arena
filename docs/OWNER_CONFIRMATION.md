# OWNER CONFIRMATION REQUIRED

These are **business rules not yet confirmed by the owner**. Each is implemented as a configurable
field on `BillingPolicy` / config (never hidden in a widget). The **Default** below is a safe,
documented assumption chosen only so the engine is testable — it is **not** a permanent decision.
The owner confirms the real value later with **no code redesign**.

Legend: 🟡 = pending owner confirmation · ✅ = fixed rule the spec already states (implemented, not a choice).

| # | Rule | Default (assumption) | Alternatives | Where |
|---|------|----------------------|--------------|-------|
| 1 | Partial-time billing granularity | 🟡 `perMinute` | 15 / 30 / 60-min blocks | `BillingPolicy.billingUnit` |
| 2 | Block rounding | 🟡 `roundUp` | `nearest` | `BillingPolicy.blockRounding` |
| 3 | Grace period | 🟡 `0 min` | any minutes | `BillingPolicy.graceMinutes` |
| 4 | Minimum session charge | 🟡 `0 min` | any minutes | `BillingPolicy.minimumChargeMinutes` |
| 5 | Early exit billing | 🟡 `actualTime` | `plannedDuration` | `BillingPolicy.earlyExit` |
| 6 | Happy-hour boundary | ✅ decided 2026-10-15: happy hours are a pricing rule; the session's start decides it for the whole session (replaces the spec §16 split) | split at window edges | `pricing_rules`, `_pr_rule` |
| 7 | Rounding scope | 🟡 `wholeSession` | `perSegment` | `BillingPolicy.roundingScope` |
| 8 | Late arrival basis | 🟡 `actualStart` | `plannedBooking` | `BillingPolicy.lateArrival` |
| 9 | Mid-session controller change | 🟡 not supported in MVP | reprice from change moment | documented seam in `SessionService` |
| 10 | Happy-hour eligible: VR | ✅ per rule: the rule's station types (seeded rule: PS5 and Pool) | — | `pricing_rules.activity_codes` |
| 11 | Happy-hour eligible: Lounge | ✅ per rule, as #10 | — | `pricing_rules.activity_codes` |
| 12 | VR partial unit billing | 🟡 `roundUpUnit` (₹200 / 30 min, 31 min → 2 units) | per-minute prorate / nearest | `BillingPolicy.vrUnitRounding` |
| 13 | RIFT concurrency (PS5 ⊕ VR) | ✅ mutually exclusive (hard rule) | — | `AvailabilityService` |
| 14 | Lounge min duration / included resources | 🟡 `60 min`, none bundled | any | `Activity`/`BillingPolicy` |
| 15 | Public holiday list | 🟡 empty (each rule says any / only / not on holidays; happy hours: not on holidays) | owner-populated | `holidays` table |
| 16 | Money rounding | 🟡 nearest `₹1` (100 paise) | ₹5 / ₹10 / up vs nearest | `BillingPolicy.moneyRounding` |
| 17 | Payment timing | 🟡 `either` | at start / at end | `BillingPolicy.paymentTiming` |
| 18 | Extend beyond 11 PM | 🟡 `blocked` | allowed | `BillingPolicy.allowExtendPastClose` |
| 19 | Station change during session | 🟡 not supported in MVP | supported | documented seam |
| 20 | Pause support | 🟡 not supported in MVP | supported | documented seam |
| 21 | Discounts / complimentary & approval | ✅ decided 2026-10-14: owner-defined presets and coupons (% or ₹, cap, minimum bill, types, dates/expiry, use limit) plus manual staff discounts up to Settings › Billing's max %, with a reason when required; one discount per bill, off the subtotal before cash rounding; recorded per bill (`bill_discounts`). Waive stays separate | — | `discounts`, `bill_discounts`, `_discount_apply` |
| 22 | GST treatment / receipt rules | 🟡 none in MVP (out of §3 scope) | GST invoicing | later phase |
| 23 | Cleaning / setup gap between sessions | 🟡 `0 min` | any minutes | `BillingPolicy.cleaningGapMinutes` |
| 24 | ~~**Group multi-system billing**~~ — group sessions removed 2026-10-24 (to be rebuilt from scratch; reopen this row then). Was: 🟡 `perSystem` (each system billed for its own time at the rate for the controllers on it; 3 systems cost ~3× one system — a 3-controller price is **not** assumed to cover 3 systems) | `sharedControllerPool` (purchased controllers billed once at the single-system multi-controller rate regardless of how many systems) | `BillingPolicy.groupBillingMode` (captured per group in its pricing snapshot) |

| 25 | **Monday trading** | 🟡 `closed` (per the brief: open Tue–Sun) | open Mon–Sun | Settings → Opening hours |
| 26 | Public holiday = closed, or open without happy hour? | 🟡 `open`, with a per-holiday "closed" switch; rules follow their holiday mode | always closed | Settings → Holidays |
| 27 | Walk-in identity | 🟡 one customer record **per visit**, named "Walk-in", hidden from the member directory | a single shared "Walk-in" record | `CustomerRepository.createGuest` |
| 28 | Booking vs a live session on the same resource (server check) | 🟡 checked on the floor app only; the server refuses booking-vs-booking overlaps | server refuses a booking that overlaps a live session (open-ended sessions: until when?) | `_booking_free` (docs/GENERALIZATION.md phase 5) |
| 29 | Turf / court bookings: deposit or prepayment | 🟡 none; payment is taken on the checked-in session | deposit at booking, refundable or not | needs payments on bookings (phase 6) |
| 30 | Overtime past the booked end | ✅ decided 2026-10-15: the live amount stops at the booked end (only Extend raises it); at End the bill shows the booked price and the overtime price; an owner-set **overtime grace per station type** (Pricing › the type, next to Charged per; default None) bills only the booked time when the session ends within it, and the whole actual time beyond it; the type the session ends on decides. The actual end is always stored. | — | `activities.overtime_grace_minutes`, `_pr_session_bill`, `overtimeBillUntil` |

> **#25 note (brief §8).** The brief states *"Operating hours: Tuesday–Sunday, 2 PM–11 PM. Monday is closed"*
> and *"Happy Hours: Tuesday–Friday, 2 PM–5 PM"*. The earlier spec in this repo said open Mon–Sun with
> happy hour Mon–Fri, and the code matched the older reading. The brief now wins: the seeded schedule is
> **closed Monday, happy Tue–Fri**, and the two Monday happy-hour tests were rewritten accordingly.
> Since 2026-10-15 happy hours are a pricing rule the owner edits on the dashboard, not a fixed window.
> Hours are persisted and editable, so if Monday really does trade, change it in
> Settings → Opening hours — no code change, and sessions already billed keep the hours they ran under.

> **#27 note (brief §4, §12).** A walk-in still needs *a* customer row, because a session is billed to
> someone. One row per visit keeps the visit countable (footfall, history, reports) without inventing a
> name; the alternative — one shared "Walk-in" record — would collapse every anonymous visit into a
> single "customer" and understate footfall.

> **#24 note (group feature §9; history — groups removed 2026-10-24).** When a group spreads across several PS5s, the price depends entirely on this rule, so it is **owner-confirmation-required**. The default `perSystem` is the conservative reading of the spec's warning ("do not automatically assume a three-controller price permits three separate PS5 systems at the same price"): co-located players on one system are combined onto that system's controller rate, while separate systems each bill their own controllers. `sharedControllerPool` is the alternative where the party pays once for the controllers they bought, however many systems they use. The mode is stored on each `GroupSession` (via its snapshot) so historical groups re-price identically; changing the policy only affects new groups.

## Staff module: attendance, leave and salary (removed 2026-10-24)

**Removed 2026-10-24:** the whole staff-time module (attendance, GPS clock-in, shifts, leave, pay
setup, payroll) was dropped before any release and can be rebuilt from the git tag
`staff-module-archive` (which also holds `docs/STAFF.md` and `docs/STAFF_API.md`). The rows below
are kept as the decisions to start from if it is rebuilt; none of them is in force.

Originally decided 2026-10-15: staff clock in on their own phone or on a
registered arena tablet; clock in/out needs a connection and the server stamps the time; who's in,
leave approvals and flagged review are floor screens gated by permission; leave notifications use
real push (FCM). Rows marked 🟡 are still open, and the design runs on their default until they
are answered.

| # | Rule | Default (assumption) | Alternatives | Where |
|---|------|----------------------|--------------|-------|
| S1 | Day rate for monthly staff (used for deductions) | ✅ decided 2026-10-15: calendar days in the period; holidays are configured per arena and work on them counts (S2) | — | `pay_policies.policy.day_divisor` |
| S2 | Work on a week-off or holiday | ✅ decided 2026-10-15: every minute worked is extra hours | — | `_att_day_facts` |
| S3 | Extra hours | ✅ decided 2026-10-15: minutes beyond a **standard day** (arena default 8 h, per-person override) are extra hours, including on planned long days (a 12 h Sunday = 4 h extra). Paid per person when switched on, at their own extra rate or a derived rate (monthly: salary ÷ days ÷ standard hours; daily: day rate ÷ standard hours; hourly: hourly rate), × the arena multiplier (default 1). "Fixed + overtime" = Monthly with extra hours on | — | `staff_pay_rates.extra_hours_paid`, `extra_hourly_paise`; `pay_policies.policy.extra_multiplier`; `standard_day_min` |
| S4 | Late marks cut pay for hourly staff | 🟡 no (monthly and daily only) | all pay types | `pay_policies.policy.late_applies_to` |
| S5 | Leave year and allowance | ✅ decided 2026-10-15: no leave types or carry-forward. Paid-leave days per year (arena default, per-person override), visible to staff in their profile; the year runs from the joining date. Staff apply planned or unplanned; the approver sets the paid / LOP split from the balance; LOP is deducted from salary | — | `settings.leave_rules`, `staff_hr_profiles.paid_leave_days`, `leave_requests.paid_days/lop_days` |
| S6 | Paid leave beyond balance | ✅ decided 2026-10-15: not refused; the approver marks the excess as LOP | — | `op_leave_decide` |
| S7 | Approving your own leave / correcting your own attendance (also: adjusting or recording your own leave, and your own HR profile, pay rate and pay-run deductions and adjustments) | 🟡 owner only | anyone holding the permission | `_own_record`: `op_leave_decide`, `op_leave_record`, `op_leave_adjust`, `op_attendance_correct`, `op_attendance_review`, `op_hr_profile_save`, `op_pay_rate_add`, `op_salary_run_set_deduction`, `op_salary_adjustment_add`, `op_salary_adjustment_reverse` |
| S8 | Staff holidays | 🟡 own list, separate from pricing holidays, with "Copy from arena holidays" | reuse the pricing `holidays` list | `staff_holidays` |
| S9 | When rule changes take effect | 🟡 time rules: every period not yet finalised; pay rules and rates: from an effective date | everything effective-dated | `settings.attendance`, `pay_policies`, `staff_pay_rates` |
| S10 | Half-day and absent thresholds | 🟡 full day at ≥ 75% of scheduled minutes, half-day at ≥ 40%, otherwise absent | other percentages / fixed hours | `settings.attendance.hours` |
| S11 | Weekly overtime across a pay-period boundary | 🟡 counted in the period holding the week's last day | split by day | `_pay_build_line` |
| S12 | Map tiles | 🟡 OpenStreetMap now; a keyed provider before many arenas | MapTiler / Stadia from day one | admin Leaflet, floor `flutter_map` |
| S13 | PDF export | 🟡 print-styled page, saved as PDF from the browser | a generated PDF file | Admin › Payroll |
| S14 | Forgotten clock-out | 🟡 auto-out at the scheduled end, paid, flagged for review | unpaid until reviewed | `_att_close_stale` |
| S15 | Who is tracked | 🟡 staff yes, owner no (per-person switch) | everyone | `staff_hr_profiles.tracks_attendance` |
| S16 | Record the payout itself | 🟡 out of scope | "mark paid" with date and method | later phase |
| S17 | One person at two arenas | 🟡 separate profile, pay and leave per arena | combined payslip | per-arena tables |
| S18 | Kiosk PIN | 🟡 4 digits; 5 wrong tries lock it for 15 minutes | other length / lockout | `settings.attendance.kiosk` |
| S19 | Changes inside a finalised period | 🟡 refused; an adjustment goes in the next run | reopen the run | `period_finalised` check |
| S20 | Salary advance recovery | 🟡 one deduction in the chosen run | instalments | `salary_adjustments` |
| S21 | Rounding applied to | 🟡 the day's total, after the break | each entry | `_att_day_facts` |
| S22 | Push for approvers who only use admin web | 🟡 phones only at first | browser push | later phase |
| S23 | Salary reductions | ✅ decided 2026-10-15: at the end of the period the owner gets a timesheet and decides, per person and per deduction (absent, LOP, half-day, late), whether to reduce pay. The system only suggests; suggestions start as applied | — | `salary_deduction_decisions`, `salary_run.set_deduction` |
| S24 | Salary in the staff app | ✅ decided 2026-10-15: none. No rates, salary or payslips on the floor app; pay lives on admin web for `payroll` holders only | — | RLS on `staff_pay_rates`, `salary_run_lines` |

## Fixed facts from the spec (not assumptions)

- Operating hours: **Tue–Sun 14:00–23:00 IST; Monday closed** (brief §8). Editable, see #25.
- Happy Hours: **Tue–Fri 14:00–17:00 IST** (2:00 PM – 5:00 PM); never at the weekend; never on a
  public holiday. Since 2026-10-15 this is a pricing rule ("Happy hours": those days and hours, not on
  holidays, PS5 and Pool, 20% lower), not a separate rate band. A rule changes every price by one percent or ₹ per
  hour, so the brief's happy rates are approximated: 20% lower gives ₹120 / ₹224 / ₹312 / ₹384 for
  1–4 controllers instead of ₹120 / ₹220 / ₹310 / ₹380 (Pool's ₹220 is exact).
- Rate card (current, snapshotted per session): see `seed.sql` / rate seed.
  - PS5 1c ₹150 · 2c ₹280 · 3c ₹390 · 4c ₹480 per hour (brief's happy rates ₹120/₹220/₹310/₹380: see above)
  - VR ₹200 / 30 min · Pool ₹275 per hour (brief's happy rate ₹220) · Lounge ₹2000 / hour
- Resources: HEX, VOID, GHOST, RIFT (PS5); RIFT also VR; Pool Table 1; Private Lounge.
- Session statuses: active / completed / voided. Payment: unpaid / partial / paid / waived.
  Overtime is **not** a status.

## Admin dashboard controls waiting on these decisions

The admin dashboard shows these controls disabled with a
"Not connected yet" note. Each one changes what a bill is worth, so it is built only after the
owner answers the questions below. Every answer has to hold identically in the server pricer
(`_pr_*`) and the floor app (`PricingService`), and in the pricing snapshot a session captures.

| Control (admin screen) | Rule | Decisions needed |
|---|---|---|
| ~~Discount on a bill~~ — **decided (#21), built on server + dashboard**: Sales discount row, Overview "Discounts given", Settings › Billing limits. Still open: "Discounts · 30 days" (Users) | #21 | Answered: % or ₹; off the subtotal before cash rounding; staff capped by the Settings max %, owners (Settings permission) not; free-text reason when required; manual needs the `discount` permission, presets and coupons do not. |
| GST %, Prices include GST, Invoice prefix (Settings › Billing); GST row (Sales) | #22 | Is the arena GST-registered? Rate (18%?) and HSN/SAC code? Rates inclusive (back out tax) or exclusive (add on top)? Rounding of the tax line? Invoice series: one per arena, per financial year, gap-free? What happens to the number of a voided bill? Are receipts printed/shared with the GSTIN? |
| ~~Percentage / flat pricing rules~~ — **decided 2026-10-14, built on server + dashboard** | #6, #15, #26 | Rules sit on top of the one standard price per type and controller count; percent or flat ₹ per hour, up or down; the session's start decides the rule for the whole session; overlapping rules: the first by priority wins; each rule says any / only / not on holidays. 2026-10-15: happy hours are no longer built in, they are a rule like any other (no happy rate band, window or per-type flag). |
| Membership plans ("Weekday 10h", "Gamer 25h"; Members) | — | Prepaid hours or a discount tier? Price, validity and expiry? Which station types and times may use plan hours? How plan minutes appear on a bill (₹0 line, separate payment method?) and in takings? Refunds of unused hours? |

Already connected on the dashboard (no owner decision needed): game age rating and media, arena
name / area / phone, payment methods offered, session start durations and end warning
(`floor_options`), and member birth year.
