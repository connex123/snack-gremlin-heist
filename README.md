# snack-gremlin-heist

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/connex123/snack-gremlin-heist/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/connex123/snack-gremlin-heist/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Snack Gremlin Heist** is a Roblox brainrot game set in a sunset night market on a lagoon. Snack Gremlins,
absurd creatures born from street food (Puff-Puff Paladin, Suya Samurai, Zobo Zeppelin, Danfo Dragon, Generator
Seraph and 37 more), hatch from the Snack Kitchen and ride the Snack Belt past the stalls. Buy one, carry it over
your head to your stall, and it earns cash every second on a pedestal. Climb 8 rarities (Common to Secret) and 6
mutations (Gold, Pepper, Diamond, Lagoon, Neon, Rainbow). Every minute a Lagoon Surge wave sweeps the market and
washes away anything you carry unless you are home or up a safe deck; Pocket Pirates row in to steal from
unlocked stalls. Lock your shutter, whack the thieves, buy upgrades, rebirth for a lasting multiplier, and fill
the Gremlin Index. Market events (Jollof Rain x2 income, Pepper Hour mutations x4, Belt Rush) keep it moving.
Everything is built from Parts and scripts: no uploaded assets.

Controls: walk to the belt and press **E** to buy, walk into your stall to place it. **L** Shutter Lock,
**F** Whack a Pocket Pirate, **U** Upgrades, **R** Rebirth, **I** Index.

Screenshots in Roblox Studio: press Play, then **1** cover, **2** buy moment, **3** threat (surge, pirate, lock),
**4** progression panels, **0** back to normal play. The shot director (`ReplicatedStorage.Shared.ShotDirector`
and `ServerScriptService.ShotDirectorServer`) only runs in Studio; TOUR.json lists the keys per screenshot.

Layout: `src/shared` (cast, rarities, mutations, config, remotes) → ReplicatedStorage.Shared, `src/server`
(one module per system; all player state in PlayerState) → ServerScriptService.Server, `src/client` (HUD) →
StarterPlayerScripts.Client. Pure-logic tests: `lune run tests/catalog.luau`; screenshot framing (cameras, label overlap, HUD clearance at 768x480): `lune run tests/shots.luau`. Owner steps for the screenshots: SHOTS.md.

## Run it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

---

<sub>Entered on [make.fun](https://make.fun/?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
