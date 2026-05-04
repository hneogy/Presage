# Pari Launch Readiness Checklist

> The product is finished enough. The strategy is mapped. **What's missing is execution of the launch.** This document is the missing artifact: a sequenced punch list that converts Pari's position into actual users.
>
> Critical insight from Round 5 research: **the App Store algorithm boosts new apps for ~48 hours after release**, evaluating conversion to decide future organic visibility. Everything below is sequenced to make that 48-hour window count.

---

## T-30 days: The problem post

The single highest-leverage pre-launch artifact is a 1,500-word essay titled something like:

> **"You think you know yourself. The data is brutal about it."**

Posted to: personal Substack, cross-posted to LessWrong, Hacker News, and an X thread.

**Content beats:**
- The honest claim: most adults are systematically overconfident about their own future behavior
- Cite Tetlock's research, ForecastBench's superforecaster numbers (0.081), GPT-4.5's number (0.101)
- Show one piece of personal calibration data — your own gym predictions, or whatever
- Name the gap: "I said 90% — I was right 71% of the time"
- *Don't pitch the product.* The whole point is the problem post.
- Closing: "I built something for this. Email if you want it." Capture emails.

This essay does three things:
1. Earns SEO for the long-tail terms that will matter on launch day
2. Builds the email list that becomes the 48-hour conversion engine
3. Gives every reviewer/launcher a credible artifact to point at

---

## T-21 days: Twitter / X build-in-public arc

Three threads spaced one week apart:

**Thread 1: "Why I'm building Pari"** — the problem post compressed into 8 tweets with screenshots from the app. Pin to profile.

**Thread 2: "The 7 cognitive biases your prediction app should be telling you about"** — uses the BiasLibrary content as a rationalist-bait listicle. Each bias has a screenshot of Pari's correlation engine catching it.

**Thread 3: "I scored my own ChatGPT calibration for 30 days"** — uses the Pari for AI feature. Shows real Brier scores for your queries to GPT-5/Claude. Most viral of the three.

Each thread links to a beta signup, not the App Store. Goal: 1,000+ email signups before launch.

---

## T-14 days: App Store listing finalized

- [ ] Screenshots rendered at 1290 × 2796 with the 8 captions from `AppStoreListing.md`
- [ ] App preview video (15-30s) showing the resolution-before-reveal moment
- [ ] Keywords field final: `forecast,prediction,calibration,brier,superforecaster,journal,decision,confidence,probability,bayesian,tetlock,metaculus,manifold,fatebook,review`
- [ ] Description copy proofread, all keywords front-loaded
- [ ] App icon final (already shipped from `icon.jpg`)
- [ ] Promotional text (170 char) finalized
- [ ] Age rating, privacy disclosures (Pari is genuinely "Data Not Collected" — defensible)
- [ ] Category: Productivity (primary), Lifestyle (secondary)
- [ ] Pricing: free with IAP; Pari Pro $5.99 one-time, Pari Cloud $24.99/yr

---

## T-7 days: Soft beta to TestFlight list

- 100 beta users from the email signups
- Three-question survey embedded in app: "Did you make it past first prediction? Did you understand 'resolve before reveal'? Will you keep using this?"
- Ship a build that adds an `MetricKit` listener to capture crash signal
- Get retention signal: D3 retention should hit 40%+ in beta (vs 28% iOS baseline) — if not, the onboarding still has friction

---

## T-3 days: Launch coordination

- [ ] **Product Hunt** — schedule for a Tuesday or Wednesday at 12:01am PT. Hunt should be an established hunter.
- [ ] **Hacker News** — Show HN post drafted, scheduled for 7am ET (peak EU + US).
- [ ] **Indie Hackers** — milestone post written.
- [ ] **/r/ProductivityApps**, **/r/iOSProgramming**, **/r/quantifiedself**, **/r/slatestarcodex**, **/r/superforecasting** — drafted, ready to post.
- [ ] **Email blast** to the signup list scheduled for launch morning.
- [ ] **App Raven / 9to5Toys / AppRaven submissions** — these scrape App Store API for new launches with introductory offers.

---

## T-0: Launch day. The 48-hour window.

**The bet**: every metric in this 48-hour window determines the next 6 months of organic search visibility on the App Store.

| Hour | Action |
|------|--------|
| 0:00 | Build live in App Store, Product Hunt post live, X thread live, email blast sent |
| 0:30 | Reply to every Product Hunt comment within 30 minutes |
| 2:00 | Hacker News post live |
| 4:00 | Reply to every HN comment within 1 hour for the first 8 hours |
| 6:00 | Subreddit posts go live, staggered |
| 12:00 | Mid-day Twitter recap thread with first metrics |
| 24:00 | "24 hours in" recap post on Substack — drives D2 engagement |
| 36:00 | Outreach to writers covering the rationalist / forecasting / iOS productivity beat (Garry Tan, Cleo Abram, Eli Bressert, Nuño Sempere) |
| 48:00 | The window closes. Whatever Apple's algorithm has decided about Pari's keyword authority will lock in. |

**The conversion target during the window**: 40%+ from product page visit to install. Pari's product page is keyword-loaded, the screenshots are caption-rich, the icon is distinctive. 40% is ambitious but plausible with this setup.

---

## T+7 days: Post-launch retention signal

Day 7 is when the Day-1/3/7 push sequence completes for first-day-1 users. The metric that matters:

- **D7 retention ≥ 30%** would be exceptional (iOS baseline ~17%)
- **D7 retention 20-30%** is good
- **D7 retention < 20%** means the onboarding/push/first-resolution flow needs another rev

If D7 is below 20%, **stop adding features** (still!) and rev the onboarding instead.

---

## T+30 days: First retention review

Look at the data, not the roadmap. The questions to answer:
1. **Conversion**: What % of product page visitors install? (target 35%+)
2. **First prediction**: What % of installs make a prediction? (target 70%+)
3. **First resolution**: What % of first-prediction users resolve? (target 50%+ — this is the "got the gap" moment)
4. **D7 / D30 retention**: ≥ 30% / ≥ 15% would put Pari well above baseline
5. **Conversion to Pro**: What % of D30 retained users buy Pari Pro $5.99? (target 5-8%)

---

## What NOT to do for the next 90 days

This is the discipline list. Adding any of these would be productive procrastination:

- ❌ A new feature anyone has suggested
- ❌ A redesign of an existing screen
- ❌ A new color theme
- ❌ A new chart type
- ❌ "Just one more competitive research round"
- ❌ Localization (English-only is fine for first launch)
- ❌ Android version (don't dilute focus)
- ❌ Web version (the iOS-native posture is the moat)
- ❌ A blog with 10 articles (one problem post is enough)
- ❌ A Discord community (the App Store reviews are the community)
- ❌ Refactoring the codebase
- ❌ Bumping to iOS 19 minimum
- ❌ Adding Apple Intelligence features that don't exist yet

---

## The single hardest part

Looking at the position Pari has earned across 9 phases — the design language, the honesty mechanics, the calibration math, the AI extension, the on-device privacy posture, the brand — **none of it matters if it isn't shipped to users.**

The next thing to do is not write more code.

The next thing to do is ship.
