# Launch checklist

Everything that still needs a human, in the order it has to happen. Art and copy
are already written; the work left is clicking through the Creator Hub with your
account logged in.

Art lives in [`assets/store/`](../assets/store) (icon + thumbnails) and
[`assets/monetization/`](../assets/monetization) (one 512x512 icon per pass and
product, named after its `Key` in `Config/Monetization.luau`).

---

## 1. First publish

1. Studio, place open: **File -> Publish to Roblox As... -> Create new experience**. Name it `Steal a Slime`.
2. Creator Hub -> the experience -> **Places -> Start place -> Server size: 8**. The map generates exactly 8 bases; more players than plots breaks assignment.
3. **Settings -> Security -> Enable Studio Access to API Services: ON**, so DataStores work when you test in Studio.
4. **Settings -> Basic Info**: Genre `Simulation`, Devices: all of them. Answer the maturity questionnaire — cartoon bonking, no blood, no gore.
5. Copy the **Universe ID** and **Start Place ID** (experience -> `...` -> Copy Universe ID / Copy Start Place ID) into `.env`:

   ```
   ROBLOX_UNIVERSE_ID=...
   ROBLOX_PLACE_ID=...
   ```

   With those set, `python3 scripts/roblox_cloud.py check` saves a non-live version
   and runs `tests/smoke.luau` on a real Roblox server.
6. Leave the experience **Private** until step 4 of this document is done.

## 2. Store art

**Settings -> Basic Info -> icon:** `assets/store/icon-512.png`

**Thumbnails**, in this order — position 1 is the only one most players ever see:

| Position | File |
|---|---|
| 1 | `assets/store/thumb1-secret-slime.png` |
| 2 | `assets/store/thumb2-protect-base.png` |
| 3 | `assets/store/thumb3-collection.png` |

Swap `assets/store/icon-halloween-512.png` in for the event and back out after
November 4, when the seasonal content in `Config/Events.luau` expires.

Moderation takes a few minutes per image. Upload before going public.

## 3. Title and description

Title:

```
Steal a Slime 🟢 Merge & Grow [HALLOWEEN]
```

Description, ready to paste:

```
Buy slimes off the belt, stack them in your base, and watch the cash roll in.
Then steal everyone else's.

🟢 31 slimes across 7 rarities — Common all the way to SECRET
✨ 4 mutations: Gold x2, Diamond x3, Haunted x4, Rainbow x6
🔒 Lock your base before a thief walks out with your best slime
🏏 Grab the Bonk Bat and make them drop it
🌧️ Slime Rain every 20 minutes: 3x luck, double spawns
👻 HALLOWEEN: Pumpkin, Ghost, Witch and Phantom slimes, plus the Haunted
   mutation — gone after November 4

🧪 MERGE 3 of the same slime into a GIANT, then a COLOSSAL
🌱 Slimes GROW the longer you keep them: bigger, richer, juicier to steal
🎃 Brew a Jack-o'-Slime or a Poltergeist in the Halloween cauldron

CODES (use the Codes button):
RELEASE · SLIME · LUCKY · SPOOKY · CAULDRON · STREAM · MERGE

Join the group for +10% cash and new codes every update.
```

Keywords go first in the title because that is what search matches on.

## 4. Passes and products

**Done.** All 7 passes and 11 developer products exist on Roblox, with their
icons, at the prices in `src/shared/Config/Monetization.luau` (created by
`python scripts/create_products.py`, which wrote the IDs into that file). The
Starter Pack (R$49) and Halloween Bundle (R$199) have no icon yet: upload one
in Creator Hub -> Monetization -> Developer Products.

To add another item later: add it to `Monetization.luau` with `Id = 0` and
run `python scripts/create_products.py --only <Key>`.

Make a Roblox group and put its ID in `GroupId` in `Monetization.luau` for the +10%
bonus and a channel to announce codes through.

## 5. Test with real players

Everything in the core loop has been verified solo in Studio: buying off the
belt, collecting income, locking the base, selling, rebirth, and the Index
discovery bonus. Two things cannot be tested with one player and still need a
real session with 5-10 friends:

- **Stealing** — walk into someone else's base, hold E, carry the slime home.
- **Bonking** — hit a carrier with the bat and confirm they drop it.

Also confirm during that session that data saves: earn some cash, leave, rejoin,
and check the balance survived. That path is dead in an unpublished place and
only works once step 1 is done.

Set `STUDIO_GRANT_ALL = true` in `src/server/Services/PassService.luau` to try
pass perks in Studio. It has no effect on live servers.

## 6. Go public

**Settings -> Permissions -> Public.** Then post the codes in the description
and the group, and start the ads test described in
[STRATEGY.md](STRATEGY.md#launch-week).
