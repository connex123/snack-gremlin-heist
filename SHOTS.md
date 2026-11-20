# Taking the four screenshots (Roblox Studio, about 10 minutes, one try)

The shot keys only work in Roblox Studio. Each key builds its scene through the game's real systems
(cash, stall, belt, events, surge, pirates, lock, boss, orders) and then sets the camera. You do not need
to play first. Every step of a scene is set up separately: if one part fails, the camera is still set
and the rest of the scene still appears.

## Steps

1. Plug the laptop in if you can. Open the place in Roblox Studio: **Snack Gremlin Heist**
   (place 87862033840794). Maximise the Studio window. Open **View > Output**.
2. Press **Play** (F5, the solo Play button, not "Run").
3. **Wait until the Output shows these three lines** (about 10-20 seconds on a laptop):
   - `[SnackGremlinHeist] server ready`
   - `[ShotDirector] server ready`
   - `[ShotDirector] ready: press 1 cover, 2 buy, 3 threat, 4 progress, 0 back to play`

   Then **wait 5 more seconds**.
4. **Click once on the 3D game view**, so the keyboard goes to the game and not to the Explorer or the chat.
5. Press **1** and **wait 4 seconds**. The Output shows `[ShotDirector] staged cover`. Capture the game
   view and save it as `1-cover.jpg`.
6. Press **2**, wait **4 seconds**, capture → `2-buy.jpg`.
7. Press **3**, wait **4 seconds**, capture → `3-threat.jpg`.
8. Press **4**, wait **4 seconds**, capture → `4-progress.jpg`.
9. Select everything in the Output (click in it, Ctrl+A, Ctrl+C) and keep it with the screenshots.
10. Press **0** (normal camera), then Stop.

Shots can be taken in any order, and any key can be pressed again.

## What each shot should show

All four shots have a thin dark strip along the very top of the screen listing the game's real counts, for
example `64 GREMLINS · 8 RARITIES · 8 MUTATIONS · 6 STALLS · 5 EVENTS · SURGE · PIRATES · BOSS · LOCK ·
FUSE · ORDERS · REBIRTH`. Below the strip on the right is the game title. Under the title is the
**TONIGHT'S ORDERS** panel with three orders, each with a progress bar and a reward.

**1 — cover.** You look down into your stall from above the lane. It should show:
- Ten gremlins in two rows of five. Each has a label: its name in white, the rarity in a solid coloured
  pill, and a big green `+$…/s`. No label overlaps another.
- Five glowing mutations: **Gold** Jollof Jetpack, **Owambe Lace** Zobo Zeppelin (purple with a band of
  gold dots), **Rainbow** Generator Seraph (colour-cycling), **Neon** Plantain Pharaoh (pink) and
  **Harmattan** Infinite Puff-Puff Paradox (golden haze).
- Glowing rings and light pillars under the Mythic, Divine and Secret gremlins in the back row.
- Your character at the right-hand edge of the stall, and a pink Fuse Pot in the front-left corner.
- Top left: the cash panel showing about **$48M**, a green rate, and `STALL 10/10 · REBIRTH x…`.
- An orange **JOLLOF RAIN!** banner at the top centre, and the five buttons along the bottom.

**2 — buy.** Your character on the lane next to the Snack Belt, seen from behind. It should show:
- A **Danfo Dragon (Legendary)** held above your head, with its label.
- Three gremlins on the belt with price lines: Kilishi Knight, a red Pepper Okra Octopus and a teal
  Lagoon Chin-Chin Cheetah.
- A **CARRYING: RUN HOME!** card under the cash panel.

**3 — threat.** You look along the lane from its west end. It should show:
- A red **OGA PEPPERPOT RAID!** banner at the top and a blue **LAGOON SURGE INCOMING!** banner below it.
- On the left, **Oga Pepperpot**: a giant red chef gremlin with a white hat, a pot and a ladle. His apron
  reads `OGA PEPPERPOT` and `WHACK 2/6 (F)`. The cash panel is hidden in this shot on purpose, so it
  does not cover his hat.
- On the right, your stall front behind a glowing blue shutter (`LOCKED …s`), with a **Pocket Pirate**
  in front of it labelled **LOCKED OUT!**, and your character facing that pirate.
- Across the belt, a second pirate (`STEALING!`) holding a gold Ogbono Overlord.
- Far back, the surge wave rising out of the lagoon.

**4 — progress.** It should show:
- The **UPGRADES** panel on the left: four upgrades and the purple Rebirth box.
- The **GREMLIN INDEX** on the right: found and total for each of the 8 rarities.
- The orders panel above the Index, and your stall and character between the two panels.
- A red **PEPPER HOUR!** banner at the top.

## If a key fails (fallback)

1. **Nothing happens after a key.** Click the 3D view once more, wait 2 seconds and press the key again.
   If the Output says `no reply from the server` or `could not stage`, press the key once more after
   5 seconds.
2. **Part of a scene is missing** (for example no boss): take the screenshot anyway. The Output names the
   step that was skipped (`[ShotDirector] threat: step 'Oga Pepperpot' skipped: …`).
3. **A shot still fails after two tries:** press **0**, walk your character (WASD) out of the stall to
   the Snack Belt and back so your stall fills the view, and capture that normal play view under the
   shot's file name.
4. In every case, copy the whole Output (Ctrl+A, Ctrl+C) and send it with the screenshots.
