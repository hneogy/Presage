---
layout: default
title: Privacy Policy
---

# Privacy Policy

**Last updated: 2026-05-04**

Présage collects nothing. This is the entire policy in one sentence. The rest of this page exists so you (and Apple's review team) can verify that claim against specifics.

---

## What we don't collect

- No analytics
- No telemetry
- No crash reporting
- No advertising identifiers
- No device identifiers
- No location
- No contacts, photos, microphone, or camera access
- No usage statistics
- No A/B testing infrastructure
- No third-party SDKs of any kind

The app's `PrivacyInfo.xcprivacy` manifest declares `NSPrivacyTracking = false` and an empty `NSPrivacyTrackingDomains` array. The corresponding App Store Privacy Nutrition Label is **"Data Not Collected."**

---

## What's stored on your device

Every prediction you create, every calibration snapshot, every training answer, every flashcard, and every AI scoring result is written to a **SwiftData store inside Présage's app container on your device**. Nothing is ever transmitted by Présage to any server we operate — because we don't operate any servers.

This data is owned by you. You can export it at any time (More tab → Data & Account → Markdown / Obsidian export, or CSV) and delete it at any time (Settings → Reset Présage).

---

## Optional iCloud sync

Off by default.

If you turn on iCloud Sync in Settings, your SwiftData store syncs through **your private CloudKit database** — visible to you across your Apple ID's devices, never to us, never to anyone else. Apple operates the CloudKit infrastructure under their privacy policy.

If you turn off iCloud Sync, the app reverts to local-only on next launch. If you reset Présage with iCloud Sync on, the next sync propagates the deletion to your other devices.

---

## Optional HealthKit access

Off by default.

If you toggle "Mood from Health" in Settings, Présage requests read access to **State of Mind** entries to optionally pre-fill mood when you create predictions. This data is read on-device only. Présage never writes to HealthKit and never transmits HealthKit data anywhere.

The `NSHealthUpdateUsageDescription` string in the Info.plist exists because the HealthKit entitlement requires it; the app explicitly does not write to HealthKit.

---

## Optional AI features

The on-device Apple Foundation Models LLM (iOS 18+ on supported devices) runs **entirely locally**. No prompts ever leave your device.

If you add your own OpenAI or Anthropic API keys (More tab → AI → AI keys), prompts go **directly from your device** to those providers. Présage never proxies, logs, or sees any of this. Your keys live in this device's keychain and are not transmitted anywhere by Présage. Your usage of those services is governed by OpenAI's and Anthropic's respective privacy policies.

---

## Optional anonymous standing

Off by default.

If you opt in to the global leaderboard, Présage submits **a single number** — your aggregated Brier score — under a pseudonym you control. No prediction text. No dates. No metadata. No account. You can opt out at any time, and the next sync removes your entry.

---

## Required-reason API declarations

iOS requires apps to declare why they use certain platform APIs. Présage uses:

- **UserDefaults** — to remember your preferences (theme, notification cadence, onboarding status)
- **File timestamp APIs** — to order your prediction history correctly
- **System boot time APIs** — to compute relative timestamps for Live Activities
- **Disk space APIs** — to warn you before exporting a vault that wouldn't fit

None of these are tied to identification, fingerprinting, advertising, or tracking. The full machine-readable manifest is shipped at `Presage/PrivacyInfo.xcprivacy` in the app bundle.

---

## App Tracking Transparency

Présage does not track. The app does not call `ATTrackingManager.requestTrackingAuthorization()` because it has nothing to ask permission for.

---

## Children's privacy

Présage is rated 4+ on the App Store and does not collect any data from any user, including children. The app contains no advertising and no in-app purchases.

---

## Changes to this policy

This policy may be updated when the app changes. Substantial changes will be highlighted in the version's release notes. The current version of this document always lives at [github.com/hneogy/Presage/blob/main/docs/privacy.md](https://github.com/hneogy/Presage/blob/main/docs/privacy.md) — version history is fully auditable.

---

## Contact

Questions about this privacy policy:

**Honorius M. Neogy** — [honorius@neogy.dev](mailto:honorius@neogy.dev)

[← Back to home](/)
