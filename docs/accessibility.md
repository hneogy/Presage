---
layout: default
title: Accessibility
---

# Accessibility Statement

**Last updated: 2026-05-04**

Présage is designed to be usable by everyone. This page documents the specific accessibility features supported and explains how to use them.

---

## VoiceOver

Every interactive element in Présage has either an explicit `accessibilityLabel` or an implicit one via SwiftUI's `Label` component. The reading order on each screen is deliberate:

- **Home tab** — Brier score (the headline number) is read first, then the quick stats row, then the resolving-soon section, then the mini calibration curve.
- **Predictions list** — each row reads as: claim, confidence percentage, days until resolution.
- **Insights** — reads section by section (benchmarks, year-in-pixels, by category, by horizon, by mood, trend, wall of shame, distribution).
- **Resolution flow** — Phase 1 reads the claim and criteria but **deliberately does NOT speak the original confidence percentage**, even via VoiceOver — the honesty mechanic applies to assistive tech too.

---

## Confidence dial

The custom confidence dial exposes its current value as `"N percent"` so VoiceOver users hear the current setting. Adjustment works with the standard VoiceOver rotor — swipe up/down to increment by 5% (matching the visual snap behavior).

---

## Calibration breakdowns

Each category / horizon / mood card uses `accessibilityCustomContent` to expose multiple data points cleanly:

- Category name
- Brier score
- Sample size

VoiceOver reads the primary label by default; users can request additional content via the rotor.

---

## Dynamic Type

Most text scales with iOS Settings → Accessibility → Display & Text Size → Larger Text. The exception:

- **Tab bar labels** are capped at `xLarge` to prevent the four-tab bar from overflowing on small devices. The icons remain unambiguous regardless of label size.

If any text clips at very large sizes, that's a bug — please report.

---

## Reduce Motion

When iOS Settings → Accessibility → Motion → Reduce Motion is enabled, Présage automatically simplifies:

- Score-reveal spring animations → crossfades
- Tab transitions → instant
- Onboarding page transitions → crossfades

Underlying functionality is identical; only the animation curves change.

---

## Color contrast

The dark theme is the primary experience and passes **WCAG AA** contrast on every text-on-surface pairing:

- `textPrimary (#F2EDE6)` on `surfacePrimary (#0A1218)` — well above AA
- `textSecondary (#8B9AA6)` on `surfaceSecondary (#101920)` — passes AA for body text
- `accent (#2FA8A8)` on `surfacePrimary` — passes AA for UI elements

The light theme uses a deliberately darkened accent (`#B8882E` instead of `#2FA8A8`) specifically chosen to clear AA contrast against the cream background.

If you find a color pairing that fails AA, report it as a bug.

---

## Differentiate Without Color

When iOS Settings → Accessibility → Display & Text Size → Differentiate Without Color is enabled:

- The Wall of Shame items show an `exclamationmark.octagon.fill` icon next to the claim text, in addition to the coral left border. Color alone never carries information.
- Calibration overconfident / underconfident zones in charts get textured fills in addition to color.

---

## Haptics

The confidence dial uses haptic ticks at every 5% increment, with **heavier** feedback at the decision boundaries (50%, 80%, 95%). Resolution outcomes have distinct haptic signatures:

- **Success** — soft, ascending double-tap
- **Failure** — firmer, single thud
- **Ambiguous** — medium, even tick

You can feel the resolution outcome without seeing the screen.

---

## Right-to-left languages

Every layout uses SwiftUI's `leading` / `trailing` alignment (not `left` / `right`), so layouts mirror automatically when device language is RTL. Charts mirror their axes appropriately.

---

## Keyboard support (iPad)

- **Cmd+N** — new prediction full flow
- **Cmd+R** — Quick Predict
- **Esc** — dismiss sheets and covers
- **Tab** — traverses interactive elements in source order
- **Space / Return** — activates focused element

---

## Audio descriptions / captions

Présage contains no audio or video media. No captions or descriptions are needed.

---

## Voice Control

Présage inherits VoiceOver labels for Voice Control naming. Most actions can be performed by name:

- "Tap New Prediction"
- "Tap Resolve"
- "Increment value" / "Decrement value" on the confidence dial

---

## Reporting issues

Found something that doesn't work for you? Please email:

**[honorius@neogy.dev](mailto:honorius@neogy.dev)**

Specific reports — "VoiceOver doesn't read the [thing] on the [screen]" — are most actionable.

---

[← Back to home](/) · [Privacy Policy](privacy) · [Support](support)
