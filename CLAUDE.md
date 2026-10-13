# Steal a Slime — notes for Claude

Roblox "Steal a ___" game written as code (Rojo + Luau). Goal: players and Robux.
Read `docs/STRATEGY.md` for the why, and `docs/SETUP.md` for how it gets to Roblox.

## Layout

- `src/shared/` → ReplicatedStorage.Shared (configs, utils, SlimeBuilder, Remotes)
  - `Config/*.luau` holds **all tuning**: slimes, rarities, mutations, economy, prices/IDs, events, codes, map layout. Balance changes go here, not in services.
- `src/server/` → ServerScriptService.Server. `init.server.luau` requires `Services/*` in dependency order, calls `Init()` on all, then `Start()`.
  - Dependency order (no cycles): Net, Data, Telemetry, Pass, World, Event, Economy, Plot, Conveyor, Steal, Character, Monetization, Reward, Tutorial. Lower services expose `Signal`s; higher ones subscribe.
  - `DataService`: session-locked DataStore; `DataTemplate.luau` defines saved data, and new fields auto-fill on load.
  - All cash and slot changes go through `EconomyService`, which logs analytics.
  - Receipts: `MonetizationService` only returns PurchaseGranted after the grant is saved.
- `src/client/` → StarterPlayerScripts.Client: `Store` (merged server state), `UI/` (Kit, Hud, Panels), `Controllers.luau`, `Effects.luau` (juice from the `Fx` remote: merge, grow, cash, rare, pass offers; jelly wobble; Haunted Rain).
- Slimes grow (`SlotData.Age`) and merge (`SlotData.Tier`; `EconomyService.Merge`, recipes via `Slimes.MergeInto`). Income/size always go through `SlimeInfo` with tier and age.
- The map is generated at runtime by `WorldService`. Slime models are built from parts by `SlimeBuilder`, so there are no asset IDs.

## Commands

- `scripts/check.sh`: strict type check (luau-lsp + Roblox types in `types/`), stylua, Lune unit tests, place build. **Run it before every commit.**
- `lune run tests/unit/run.luau`: unit tests and balance sim. Only pure modules load under Lune (see `tests/unit/loader.luau`).
- `rojo build default.project.json -o build/StealASlime.rbxlx`: build the place.
- `python scripts/create_products.py [--only KEY]`: creates passes/products with `Id = 0` in `Config/Monetization.luau` on Roblox (Open Cloud) and writes the IDs back.
- `python scripts/upload_sfx.py`: uploads `assets/sfx/*.mp3` listed in `Config/Sounds.luau` with id 0 (needs `ROBLOX_CREATOR_USER_ID`).
- `python3 scripts/roblox_cloud.py check|publish|run <file>`: Open Cloud. Needs `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID` and network access to `apis.roblox.com`. `check` saves a non-live version and runs `tests/smoke.luau` on a real server. Never `publish` (live) without the user's go-ahead.

## Conventions

- `--!strict` everywhere; keep the type check at zero diagnostics.
- Server is authoritative: validate every client action. Clients only send `Action` remote names (rate-limited in NetService).
- No paid random items: Robux purchases always grant a specific thing.
- Seasonal content: add to `Config/Events.luau` Seasonal and tag slimes/mutations with `Event = "<Id>"`.

## Roblox Studio MCP

When running on the user's own machine with Studio open, the Roblox Studio MCP server may be connected (see docs/SETUP.md).
Use it to:
- inspect the running game,
- playtest (start/stop play, read console output),
- insert Creator Store models.

Persist code changes in `src/` (Rojo syncs them). Never leave changes only in Studio.
