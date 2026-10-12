# Steal a Slime: game choice, money plan and growth plan

_Researched October 12, 2026._

## The decision

**Build a "Steal a ___" game: buy slimes off a conveyor belt, they earn cash in your base, steal other players' slimes, defend your own.**

### Why this genre

- **It's the biggest proven formula on Roblox right now.** The #1 game on the platform in early October 2026 is *Steal an Egg* (launched July 25, 2026; about 1.2–1.6M players online at once and 3B+ visits). Steal a Brainrot reached 25M concurrent players, the platform record. Grow a Garden and Steal a Brainrot are the breakouts Roblox itself points to.
  Sources: [endgametools chart, Oct 4](https://endgametools.com/en/roblox/charts), [9to5gaming](https://9to5gaming.com/roblox-games-play/), [Wikipedia: Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot), [creation.dev genre data](https://www.creation.dev/learn/best-roblox-game-ideas-2026).
- **It matches what Roblox's recommendation system rewards.** Since June 2026, Roblox ranks games on:
  - play-through rate (people who see the game and click it),
  - first-play bounce rate,
  - day 1, day 2–7 and day 8–28 retention,
  - co-play (playing with friends),
  - spend days and Robux per user.

  A steal game scores well on all of these, because other players *are* the content. Sources: [Roblox newsroom, June 2026](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [Discovery docs](https://create.roblox.com/docs/discovery), [DevForum announcement](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575).
- **It's cheap to build and to copy ourselves.** All of the art is generated from code, so a reskin (Steal a Pet, Steal a Gem…) is mostly a config change.

### Why slimes instead of brainrots or eggs

- Cute collectibles that kids get attached to (Adopt Me / Pet Sim psychology).
- No IP risk. Brainrot characters are memes we don't own.
- 31 variations come from colors, materials, hats and mutations, with no 3D artist needed.
- Easy seasonal skins. A Halloween event is live in the code right now (Pumpkin, Ghost, Witch and Phantom slimes, plus the Haunted mutation, until Nov 4).

### Honest odds

Roblox money is extremely hit-driven. Creators earned about $1.7B through DevEx in the year to June 2026, but the **median creator made about $1,500** while the top 10 averaged $65.7M ([TweakTown](https://www.tweaktown.com/news/113585/robloxs-top-10-creators-averaged-dollars65-7-million-each-while-the-median-made-dollars1500-and-roblox-everywhere-is-the-fix/index.html)).
Nobody can guarantee a hit. The way to beat the odds is **many cheap, fast shots plus fast iteration on data**. This codebase is built for that:

- Every number is in `src/shared/Config/`.
- Every key step is logged to Roblox Analytics.
- Reskinning the game for a second shot takes days, not weeks.

---

## What's in the game (v1)

| System | Why it's there |
|---|---|
| Slime Belt: random slimes for cash, Epic+ also for Robux | Core loop and the main Robux sink (Steal a Brainrot's best earner) |
| 7 rarities, 31 slimes, 4 mutations (Gold x2, Diamond x3, Haunted x4, Rainbow x6) | "One more roll" excitement, and server-wide announcements on rare spawns |
| Stealing (hold E, carry it home) + Bonk Bat to make thieves drop it | Social conflict means co-play, longer sessions and revenge return visits |
| Base lock (60s, then 30s recharge) + Instant Lock product | Defense tension, plus an impulse purchase |
| Passive income on pedestals, step on pads to collect | A reason to stay in your base, and the Auto Collect pass |
| Rebirth (keeps slimes, +50% cash, +2 slots) | Long-term goal (day 8–28 retention) |
| Index: +2% cash per unique slime discovered | Collection completion |
| Daily streak (7 days, day 7 = free Epic) | Day 1–7 retention |
| Playtime gifts (3–60 min) | Session length |
| Slime Rain every 20 min (3x luck, 2x spawns) | "Wait for the next rain" sessions, synced across all servers |
| Server Luck product, announced to the whole server | Social purchase that benefits everyone |
| Friend boost (+10% per friend, max +50%), invite button | Co-play signal plus free viral growth |
| Group bonus (+10%) | Builds a group we can message about updates and codes |
| Codes | Free search traffic ("steal a slime codes") |
| Offline earnings (25%, 1h; 4h for VIP) | A reason to come back |
| Guided tutorial with arrow | Low first-play bounce, a top ranking signal |

No Robux purchase gives a random item, so the game stays clear of Roblox's paid random item rules.

---

## The money

Roblox keeps 30% of each pass or product sale. The standard DevEx rate is **$0.0038 per Robux** ([source](https://www.bloxbot.ai/guide/roblox-devex-rate-increase-r15-2026)).
So a 399 R$ pass earns about 279 R$, which is about **$1.06** cashed out.

Example with **assumed** numbers (not a forecast), to show why scale is everything:

| Daily players | Buyers/day (2%) | Avg spend | Net Robux/day | ≈ USD/day |
|---|---|---|---|---|
| 1,000 | 20 | 150 R$ | 2,100 | $8 |
| 20,000 | 400 | 150 R$ | 42,000 | $160 |
| 200,000 | 4,000 | 150 R$ | 420,000 | $1,600 |

The lever that matters most is **getting the algorithm to recommend us**. That means retention and co-play first, then monetization tuning.

---

## Launch plan

### Before launch (you, about 1–2 days)

1. Do the first publish and settings in [SETUP.md](SETUP.md).
2. Create the passes and products and paste their IDs.
3. **Icon + 3 thumbnails.** These decide play-through rate, so they matter as much as the game.
   Prompts for any AI image tool:
   - Icon: *"Roblox game icon, glossy cute green slime with a golden crown and big shiny eyes, a sneaky cartoon thief in a black mask carrying it and running, bright purple background, bold bubbly text 'STEAL A SLIME', 3D render, vibrant, high contrast."*
   - Thumbnail 1: *"Roblox gameplay scene, colorful conveyor belt of cute slimes with price tags, players running between bases, a giant glowing rainbow slime in the center, text 'SECRET SLIME!'"*
   - Thumbnail 2: *"Cartoon kid bonking a thief with a baseball bat to save a glowing slime, red forcefield base lock behind, text 'PROTECT YOUR BASE'"*
   - Halloween version: same as the icon, with a pumpkin hat and an orange-purple night sky. Title it `Steal a Slime 🎃 [HALLOWEEN]`.

   Roblox requires thumbnails to represent the actual game, so screenshot the real game and touch it up rather than inventing features.
4. **Title and description.** Put the keywords players search first: *"Steal a Slime 🟢 [HALLOWEEN]"*. The description should cover what you do, the rarities, and today's codes.
5. Do a playtest with 5–10 friends in one server. Check stealing, locking, bonking and saving.

### Launch week

- **Day 1:** go public. Post codes `RELEASE`, `SLIME`, `LUCKY`, `SPOOKY` in the description and the group.
- **Days 1–5: ads test** in [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager).
  - Use the **Plays** objective with a small daily cap you're comfortable losing.
  - Roblox says campaigns need 3–5 days to show results. If they don't, fix onboarding before spending more.
  - The point of the ads is to *buy data*: does the game retain players?
- **Short videos, every day.** TikTok, YouTube Shorts and Reels. Formats that work for steal games:
  - "I stole a SECRET slime 😱"
  - "Rarest slime pull at Slime Rain"
  - "Base defense fail"
  - "Rating every slime"

  Record in-game with 2 accounts.

### Decide on day 7: keep going or pivot

Check Creator Hub → Analytics against these bars. They're our own rules of thumb, not Roblox numbers:

| Metric | Keep investing if… | If not, fix… |
|---|---|---|
| Onboarding funnel step 2 (bought first slime) | ≥ 80% of new players | Tutorial text and arrow, belt prices |
| Day 1 retention | ≥ 15% | Daily rewards, early progression speed (Economy.luau), events |
| Avg. session length | ≥ 12 min | Gift timers, rain frequency, stealing balance |
| Play-through rate | Rising week over week | Icon, thumbnails, title |
| Payer conversion | ≥ 1% of daily players | Shop placement, prices, pass value |

If the numbers are far off after two rounds of fixes, **reskin and relaunch.** A different theme on the same code, a few days of work, is a new shot.
Candidate next themes: gems/crystals, pets, food, cars.

### After launch: weekly updates

Ship one update a week: new slimes, a new event or a new mechanic. Put `[UPD]` in the title.
Fresh content keeps day 8–28 retention up, and update days bring returning players.

Roadmap ideas, in rough priority order:

1. Christmas event (add it to `Config/Events.luau`; snow slimes, Frozen mutation)
2. Fuse machine: 3 of the same slime become 1 of a higher rarity (proven in Steal an Egg)
3. Global leaderboards (richest, most steals)
4. Sound effects and music
5. Guarded "wild slime" zones to raid (Steal an Egg's escape loop)
6. Rewarded video ads, as an extra revenue stream
7. Real 3D slime models from a modeler, once the game proves itself
