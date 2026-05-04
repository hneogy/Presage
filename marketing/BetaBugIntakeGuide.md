# Bug Intake — How to Use

> A real intake template, not Google's default. Each column has a reason. The point is to catch bugs that audits cannot, in a structure that maps directly to commit-and-fix.

---

## Severity

- **P0** — App-breaking: crashes, data loss, can't open the app
- **P1** — Feature-broken: signature mechanic doesn't work (resolution doesn't reveal, prediction won't save)
- **P2** — Wrong-but-recoverable: bad copy, visual regression, notification mistimed
- **P3** — Polish: nice-to-have, animation jitter, minor accessibility miss
- **P4** — Idea / wishlist: not a bug, write down for later

Beta phase: fix every **P0** within 24 hours, every **P1** before next 5 testers, every **P2** before App Store submit.

## Category

Use these — they map to specific Pari source files so triage is quick:

- `Onboarding flow`
- `Resolution flow`
- `New prediction creation`
- `Quick predict`
- `Calibration display`
- `Insights`
- `Notifications`
- `Watch app`
- `Widget`
- `Settings`
- `App Intents / Siri`
- `Performance`
- `Accessibility`
- `Other`

## What to capture

The best bug reports answer four questions:

1. **What did the user do?** Specific tap-by-tap reproduction
2. **What did they expect?** Reveals brand alignment failures
3. **What actually happened?** The defect itself
4. **What device and OS?** Always always always

Less helpful: "the app is broken." Helpful: "I tapped Yes on a 7-day prediction, expected to see the reveal screen, got dismissed back to home."

## Triage process

Once a day during beta:

1. Sort by severity descending
2. For each P0/P1: assign to a fix file, give it a PR slot
3. For each P2: batch into next sprint
4. For each P3/P4: review weekly, decide whether to ship or skip

## Aggregating signal

After 20 testers:
- Count bugs by category. Where you have ≥3 reports, **that area needs a redesign, not a bug fix**.
- Count by reporter. If one user files 80% of bugs, weight their feedback differently than the silent 19.
- Count "expected vs. actual" gaps where the user expected something the app explicitly does. **That's a UX failure, not a bug.** Different fix.

---

## What you're allowed to ignore

This is the discipline:

- **Feature requests disguised as bugs.** "I expected to see X" where X isn't a feature you've decided to build → P4, file for later.
- **One-off device weirdness with no reproduction.** Note it. Move on.
- **Polish nits during beta.** Ship something that works first. Polish at App Store submit.
- **Disagreements with brand decisions.** "It needs streaks" is not a bug. It's a brand argument and the answer is no.

---

## When to stop fixing and ship

The honest signal: when 5 consecutive testers in batch 4 file zero P0/P1 bugs in the first 60 seconds. That's your "the onboarding works, ship it" moment.

Until that point, keep iterating. After it, click submit.
