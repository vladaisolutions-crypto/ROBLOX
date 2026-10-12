# Steal a Slime 🟢

A Roblox game in the "Steal a ___" genre, the formula behind the platform's biggest 2025–26 hits:

1. Buy slimes off the conveyor belt.
2. They earn cash in your base.
3. Steal other players' slimes and run home.
4. Bonk thieves and lock your base to defend yours.

The whole game is code. The map, the 31 slimes and the UI are all generated from Luau, so it builds straight into a Roblox place file without needing any art assets.

- **Why this game, and how we grow it and make money:** [docs/STRATEGY.md](docs/STRATEGY.md)
- **Getting it on Roblox, connecting Claude (MCP / Open Cloud), setting up passes:** [docs/SETUP.md](docs/SETUP.md)

## Quick start

```bash
rojo build default.project.json -o build/StealASlime.rbxlx   # open this in Roblox Studio and press Play
```

For live editing, run `rojo serve` and connect with the Rojo Studio plugin.

## Features

- Slime Belt with 7 rarities (Common → Secret), 4 mutations, and server-wide announcements for rare spawns
- Stealing with carry-home, a Bonk Bat to make thieves drop slimes, and a base lock with a forcefield
- Passive income pads, rebirths, a collection Index with a permanent bonus, and offline earnings
- Daily streak, playtime gifts, Slime Rain every 20 minutes, a Halloween event, and redeemable codes
- 7 game passes and 9 developer products, with save-before-grant receipt handling
- Session-locked saving, Roblox Analytics onboarding funnel and economy events
- Mobile-friendly UI and a first-play tutorial arrow

## Development

| Command | What it does |
|---|---|
| `scripts/check.sh` | Strict type check, formatting, unit tests and place build |
| `lune run tests/unit/run.luau` | Config, formula and balance tests |
| `python3 scripts/roblox_cloud.py check` | Uploads a test version and runs smoke tests on a real Roblox server |
| `python3 scripts/roblox_cloud.py publish` | Publishes live |

Tuning lives in `src/shared/Config/`. See [CLAUDE.md](CLAUDE.md) for the architecture.
