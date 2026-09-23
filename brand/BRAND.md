---
tagline: "Sweep your Mac's stray processes clean"
one_liner: "A native macOS menu bar app that surfaces stray and zombie processes and lets you kill them safely with one click."
description: "Pidlyse is a native macOS menu bar app (Swift + SwiftUI, Apple Silicon) that scans for stray dev servers, zombie processes, and idle Docker containers, classifying each as safe or needs-review before you kill it. Kills always try SIGTERM first with a SIGKILL fallback, and every kill is verified — gone means gone, not just signaled. A terminal companion (`pidlyse`) and Shortcuts/Spotlight/Raycast integrations bring the same engine outside the menu bar."
---

# Brand

The three fields above are this project's public blurb — the one place a
card, a catalog entry, a README index, or a social post should quote from.
Fill all three; keep them public-safe. Caps are caps, not targets:

- `tagline` — ≤ 8 words. The catchphrase.
- `one_liner` — ≤ 25 words. One sentence: what it is and for whom.
- `description` — ≤ 80 words. The paragraph a card could carry whole.

Below this line the file is free — longer copy, voice notes, what not to
say. Standard: `~/Code/natabula/docs/DESIGN-STANDARDS.md` §"Brand kit".

## Voice notes

- Two classification buckets only (`safe` / `needsReview`) — never imply
  an auto-kill or "cleans itself" claim. The user always clicks.
- "Verified kill" / "gone means gone" is the honest differentiator — avoid
  vaguer competitor language like "terminates" or "cleans up" without the
  verification nuance.

## What not to say

- Don't call it a "task manager" or "Activity Monitor replacement" — it is
  narrower and opinionated (stray/zombie detection), not general process
  management.
