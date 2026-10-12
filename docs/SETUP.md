# Setup: from this repo to a live Roblox game

There are three pieces:

1. **Get the game into Roblox once** (you, ~15 minutes).
2. **Connect Claude to Roblox** so it can keep building: live in Studio over MCP, and/or from the cloud over Open Cloud.
3. **Turn on the money**: game passes, developer products and settings.

---

## 1. First publish (one time)

1. Install [Roblox Studio](https://create.roblox.com/) and log in.
2. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (it syncs this repo's code into Studio).
   - Easiest: install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit add rojo-rbx/rojo` in this folder.
   - Then install the Rojo Studio plugin with `rojo plugin install`.
3. Build the place file: `rojo build default.project.json -o build/StealASlime.rbxlx`
4. Open `build/StealASlime.rbxlx` in Studio and press **Play** to try it.
5. **File → Publish to Roblox → Create new experience.** Name it `Steal a Slime`.
6. In the Creator Hub, open the experience and set:
   - **Places → Start place → Server size: 8** (the map has exactly 8 bases).
   - **Settings → Security → Enable Studio Access to API Services: ON** (lets you test saving in Studio).
   - **Questionnaire** (maturity): answer it. It's cartoon bonking, no blood or gore.
   - **Genre**: Simulation. **Devices**: all of them (most players are on phones).
7. Write down the **Universe ID** and **Place ID** (Creator Hub → experience → ⋯ → Copy Universe ID / Copy Start Place ID).

From now on, edit code in `src/` and either:
- run `rojo serve` and click **Connect** in the Rojo plugin (live sync while Studio is open), or
- rebuild the `.rbxlx` file and publish.

---

## 2. Connect Claude to Roblox

### Option A: Claude controls Studio live (MCP)

Studio only runs on Windows or Mac, so this runs on **your computer**, not in the cloud.

1. Install [Claude Code](https://code.claude.com/) on your computer and clone this repo.
2. In Roblox Studio, open the **Assistant** panel → ⚙️ settings → **MCP Servers** → **Quick connect** → turn on **Claude Code**.
   Roblox's guide: <https://create.roblox.com/docs/studio/mcp>
   - If your Studio doesn't have Quick connect yet, use Roblox's official server instead:
     download the installer from <https://github.com/Roblox/studio-rust-mcp-server/releases>, run it, then:
     ```
     claude mcp add --transport stdio Roblox_Studio -- "<path to the installed rbx-studio-mcp>" --stdio
     ```
3. Open the place in Studio, then run `claude` in this folder and check with `/mcp` that **Roblox Studio** is connected.
4. Optional: run `claude remote-control` in this folder so the session also shows up in the Claude app on your phone.
   You can then ask Claude to build things in Studio from anywhere while your computer is on.

Claude can then run Luau in Studio, insert Creator Store models, start and stop playtests, and read the console output.
**Code changes still go in `src/`.** That way they're saved in git, and Rojo syncs them into Studio.

### Option B: Claude works from the cloud (Open Cloud)

This lets a Claude cloud session (like the one that built this) publish builds and run Luau on real Roblox servers, with no Studio involved.

1. Creator Hub → **Open Cloud → API Keys → Create API Key**.
   - Access permissions → add your experience with:
     - `universe-places`: **write** (publishing)
     - `luau-execution-sessions`: **read + write** (running code and tests)
   - Security → Accepted IP addresses: `0.0.0.0/0` (cloud sessions don't have a fixed IP).
2. In the Claude cloud environment's settings (environment menu → **Edit**):
   - **Network access**: add `apis.roblox.com` to the allowed domains.
   - **Environment variables / secrets**:
     - `ROBLOX_API_KEY` = the key
     - `ROBLOX_UNIVERSE_ID` = universe ID from step 1.7
     - `ROBLOX_PLACE_ID` = place ID from step 1.7
3. Start a new session. Claude can now run:
   ```
   python3 scripts/roblox_cloud.py check            # save a test version + run smoke tests on a real server
   python3 scripts/roblox_cloud.py publish          # push the current code LIVE
   python3 scripts/roblox_cloud.py run some.luau    # run any Luau on a server and print results
   ```

Never paste the API key into a chat. Store it only in the environment settings.

---

## 3. Turn on the money

### Game passes and developer products

Create each one in Creator Hub → your experience → **Monetization**, then paste its ID into
[`src/shared/Config/Monetization.luau`](../src/shared/Config/Monetization.luau) (replace the `0`).
Anything left at `0` shows as "Coming soon", so the game works before this is done.

| Key | Type | Name | Suggested price (R$) |
|---|---|---|---|
| DoubleCash | Pass | 2x Cash | 399 |
| VIP | Pass | VIP | 249 |
| ExtraSlots | Pass | +6 Slots | 199 |
| AutoCollect | Pass | Auto Collect | 149 |
| LongLock | Pass | Long Lock | 99 |
| SpeedBoots | Pass | Speed Boots | 99 |
| GoldenBat | Pass | Golden Bat | 79 |
| CashSmall | Product | Cash Bag | 29 |
| CashMedium | Product | Cash Crate | 99 |
| CashLarge | Product | Cash Vault | 399 |
| ServerLuck | Product | Server Luck x2 | 99 |
| InstantLock | Product | Instant Lock | 19 |
| BeltEpic | Product | Buy Epic Slime | 49 |
| BeltLegendary | Product | Buy Legendary Slime | 99 |
| BeltMythic | Product | Buy Mythic Slime | 199 |
| BeltSecret | Product | Buy Secret Slime | 399 |

Each pass and product needs an icon. Simple, bright emoji-style art on a colored background works fine.
Once there are a few hundred players a day, turn on **price optimization** for products in the Creator Hub, so Roblox tests prices for you.

### Group bonus

Create a Roblox group for the game and put its ID in `GroupId` in the same file. Members get +10% cash, and the group lets you announce updates and codes.

### Test pass perks in Studio

Set `STUDIO_GRANT_ALL = true` in `src/server/Services/PassService.luau` while testing in Studio. It has no effect on live servers.
