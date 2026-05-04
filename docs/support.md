---
layout: default
title: Support
---

# Support

Stuck on something? This page covers the most common questions. If yours isn't here, email **[honorius@neogy.dev](mailto:honorius@neogy.dev)** — I read every message.

---

## Quick start

1. **Tap the orange "+" button** to make your first prediction.
2. Write what you predict, set your confidence (50–99%), describe what counts as "yes," and pick a resolution date.
3. **When the date arrives, Présage notifies you.** Tap the notification.
4. Answer Yes / No / Ambiguous. Présage hides your original confidence at this step on purpose — see "The honesty mechanic" below.
5. After you answer, your Brier score updates and the calibration curve fills in.

The Knowledge Center inside the app (More → Knowledge Center) is the most thorough reference.

---

## Frequently asked questions

### Why does Présage hide my confidence at resolution time?

To prevent self-deception. If you saw "85%" before answering, you'd anchor on it and rationalize a "yes." By hiding it until you commit to an answer, your resolution reflects what actually happened — not what you wanted to have happened.

### What's a Brier score?

It's a measure of how well-calibrated your predictions are. Lower is better. 0 is perfect, 0.25 is what you'd score by always saying 50% (i.e., random guessing), 1.0 would require being maximally wrong (saying 100% on something that didn't happen). The Knowledge Center → "The method" article explains the math.

A Brier score below **0.20 over 50+ resolved predictions** is genuinely good calibration.

### Why does the slider start at 50%?

50% is "I have no information." Anything below 50% is the same forecast inverted ("30% yes" = "70% no" with the claim flipped). Présage standardizes on always asking "how confident in YES?" and provides a Flip button to invert the claim if you lean "no."

### Can I edit a resolved prediction?

No. Resolved predictions are immutable to protect your calibration history — if you could edit them, you could rewrite your past to match your present. You can edit pending (unresolved) predictions freely.

### How do I delete a prediction?

Long-press the prediction in the Predict tab → Delete. Or open the detail sheet and tap the trash icon.

### How do I sync across devices?

Settings → iCloud Sync → toggle on. Sign in with Apple if prompted. **Force-quit and relaunch Présage** for the sync setting to take effect — the SwiftData container is built once at app launch.

Sync is off by default because resolution-fudging is easier when you can resolve on one device while another shows your original confidence — Présage is designed for honest self-reflection, and forcing local-only is a small barrier that keeps you accountable.

### My widget shows old data.

Widgets refresh on their own schedule (iOS controls this, not Présage). After making a prediction, expect up to 15 minutes before the widget reflects it. If it's been longer, force-quit the main app and reopen — that triggers an immediate widget reload.

### My notifications stopped firing.

Check iOS Settings → Notifications → Présage → ensure Allow Notifications is on. Then in the app: Settings → Notifications → "Enable resolution reminders" to re-prime the system permission.

If you have more than ~64 active predictions all resolving at different times, iOS's notification budget kicks in — Présage keeps the soonest-due reminders and drops the furthest-out ones.

### Can I export my data?

Yes — More tab → Data & Account → Markdown / Obsidian export (folder of Markdown files with YAML frontmatter and `[[wikilinks]]`) or CSV via the import view's reverse path.

### How do I import from another app?

More tab → Data & Account → Import from CSV. Présage parses CSV exports from Fatebook, PredictionBook, and any spreadsheet with at least a `claim` column. The importer skips malformed rows and tells you the count.

### Will my data be lost if I uninstall?

Yes — uninstalling iOS apps removes their app container. Export your data first if you want to keep it.

If iCloud Sync was on, your data lives in your iCloud account and will restore when you reinstall and re-enable sync.

### How do I reset everything?

Settings → Danger Zone → Reset Présage. Confirmation dialog, then it erases every prediction, snapshot, training answer, flashcard, AI score, and Spotlight index entry from this device. Onboarding restarts.

If iCloud Sync was on, the next sync propagates the deletion to your other devices.

### Why is the app called Présage?

Présage is French for "an omen" or "a portent" — a forecast about what's to come. Apt for an app whose only job is making personal forecasts and then scoring them.

---

## Bug reports

Email **[honorius@neogy.dev](mailto:honorius@neogy.dev)** with:

1. iOS version (Settings → General → About → iOS Version)
2. Device model
3. Présage version (Settings → About → Version)
4. What you were doing when it happened
5. What you expected vs. what occurred

Crash logs are useful but not required. Présage has no crash reporting SDK — by privacy choice — so the only way I see crashes is through TestFlight or App Store Connect.

---

## Feature requests

Email or open an issue at [github.com/hneogy/Presage/issues](https://github.com/hneogy/Presage/issues).

I read everything. Not every request fits Présage's design philosophy (no gamification, no streaks, no social pressure, all data on-device) but everything gets considered.

---

## Privacy / security questions

See the full [Privacy Policy](privacy) for what's collected (nothing) and where data lives (your device).

For sensitive security disclosures, email directly rather than opening a public issue.

---

## Developer

**Honorius M. Neogy** — [neogy.dev](https://neogy.dev/)

[← Back to home](/)
