# Pari TestFlight Beta — Invite Email

> Send this to your first 20 beta testers. Goal: capture the four classes of feedback that audits cannot — confusion, friction, novelty resistance, and abandonment moments. Each "thing to look for" maps to a specific failure mode the dev team genuinely cannot detect from code alone.

---

## Subject line options (A/B-test these with your first batch)

A. **You think you know yourself. Help me prove you don't.**
B. **Quick favor: 60 seconds + a prediction**
C. **Pari beta — making the gap visible**

---

## Email body

```
Hey [Name],

Short version: I've been building Pari, a tiny iOS app that scores how well your beliefs about your own life actually match reality. I'd love your read on it before I ship.

The pitch in three lines:
• Make a prediction with a confidence percentage.
• When it resolves, Pari hides what you originally said and asks what happened first.
• That gap — between what you claimed and what you got right — gets quantified over time.

It's the opposite of a habit tracker. Habit trackers measure what you did. Pari measures the gap between what you said you'd do and what actually happened.

What I'm asking:

1. Open the TestFlight link below.
2. Make ONE prediction in the next 60 seconds. Something you think will happen this week.
3. Come back when it resolves. Tell me what you noticed.

That's it. If you only have time for that, it's already valuable.

If you have more time, the four things I most want you to tell me:

— Did the first 60 seconds feel weird? Confusing? Lost?
— When you came back to resolve, did the "you answer first, we hide your bet" thing feel honest or annoying?
— Was there a moment where you almost closed the app and didn't open it again? What was that moment?
— Anything that felt like it didn't work or wasn't there?

There's no right answer. The wrong move is silence — even "I forgot about it after day 2" is the most useful single sentence I could get back.

TestFlight link: [PASTE LINK]
Bug / "wait, what?" intake: [PASTE LINK to spreadsheet or use plain reply]

Thanks for the time.

— [Your name]

PS — there's deliberately no streak count, no badges, no virtual pet. The score is the score. If that's annoying, tell me that too.
```

---

## What you're hoping to surface from each tester

This is the framework — don't share it with them, but use it to read their replies.

### The four failure modes audits cannot detect

| Failure mode | How it sounds in their reply | If you hear it, fix this |
|---|---|---|
| **Confusion** | "I didn't know what to type" / "what's a Brier score" / "wait, what's resolve?" | Onboarding copy, the first-prediction prompt |
| **Friction** | "I gave up after the keyboard closed twice" / "the dial was hard to use" / "it took too many taps" | Specific UX micro-flow that broke |
| **Novelty resistance** | "I get it, but why would I bother?" / "feels like work" / "isn't this just journaling?" | Brand position is unclear; the value prop hasn't landed in 60 seconds |
| **Abandonment** | "I forgot it existed" / "didn't open it after day 1" / "the notification was annoying" | The retention loop (Day 1/3/7 push, prediction recurrence, calibration moment) |

### What to count vs. what to read

**Count** these — they're proxies for retention math:

- % who tap "Get started" / "Make my first prediction"
- % who actually save a first prediction (vs. typing then closing)
- % who come back on day 7+ to resolve (the moment of truth)
- % who make a SECOND prediction after their first resolution
- Number who delete the app within 7 days (TestFlight tells you this)

**Read** these — they're irreplaceable:

- Anything they wrote about the "resolve before reveal" moment. This is the brand. If they don't notice it, the design didn't land. If they say "weird but actually I get it," it landed.
- Anything where they used the word "fair" or "honest" — that's brand resonance.
- Anything where they hesitated to delete a bad prediction. That's the honesty mechanic at work.

### The emails you reply to

Don't reply with thanks. Reply with one specific question:

- If they said "I made a prediction": "What confidence did you set, and what was the wording?"
- If they said "I bounced": "What screen were you on?"
- If they said "this is interesting": "Would you pay $5.99 for the Pro version after 30 days? Genuine question."

Each reply gets you one more bit of signal.

---

## After the first 20

If 8+ make a first prediction → product-market fit signal is decent, expand.
If 4–7 → onboarding has a bottleneck, fix it before round 2.
If <4 → the pitch isn't landing, rewrite the email and try again with a different 20.

If 5+ come back to resolve on day 7 → calibration loop is real, ship to App Store.
If 1–4 → notification budget or push copy is wrong, iterate.
If 0 → the retention thesis is broken; this is the moment to be honest about whether to keep going.

---

## Who to invite first

Order matters. The first 20 should be:

1. 5 friends who will use the app honestly and tell you the truth
2. 5 people in the rationalist / forecasting / quantified-self adjacent communities (LessWrong, EA Forum, Manifold). They'll give the most informed feedback on the calibration math itself.
3. 5 indie hackers / designers — they catch UX issues but rate design polish too generously
4. 5 people who would *not* describe themselves as "nerdy about predictions" — these are the canary for whether the app reaches outside the obvious audience

Don't invite all 20 the same day. 5 per day for 4 days lets you fix obvious bugs between batches.
