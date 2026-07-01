# Ash Company art credits

This file tracks every third-party art source used by Ash Company.

The goal is to keep the repository safe to publish and easy to audit later. When editing an asset in Aseprite, keep the original source here and describe the changes made.

## Repository art structure

```text
assets/art/vendor/      Third-party asset packs added to the repository.
assets/art/source/      Ash Company editable source files, usually .aseprite.
assets/art/exported/    PNG/GIF/spritesheet exports used by Godot.
assets/art/local-only/  Local-only references that must not be committed.
```

## Added vendor assets

### Kenney - Roguelike/RPG Pack

- Source: Kenney Roguelike/RPG Pack
- Website: https://kenney.nl/assets/roguelike-rpg-pack
- Author: Kenney Vleugels / Kenney
- Local path: `assets/art/vendor/kenney/roguelike-rpg-pack/`
- License: Creative Commons Zero, CC0
- License file in repository: `assets/art/vendor/kenney/roguelike-rpg-pack/License.txt`
- Intended use in Ash Company: prototype tiles, small props, UI/background experiments, and dungeon/ruin layout tests.
- Notes: Do not use these as final side-view characters. The pack is more useful for top-down/map-like elements and small environmental pieces.

### Anokolisa - Legacy Fantasy / High Forest

- Source: Legacy Fantasy - High Forest
- Website: https://anokolisa.itch.io/sidescroller-pixelart-sprites-asset-pack-forest-16x16
- Author: Anokolisa
- Local path: `assets/art/vendor/anokolisa/legacy-fantasy-high-forest/`
- License summary from the asset page/package: free for commercial use and edits; credits optional/appreciated.
- Intended use in Ash Company: first side-view animated placeholder for heroes, enemies, background layers, and Aseprite learning/editing.
- Notes: This is currently the best starting point for side-view combat because it includes animated side-view character/enemy assets and editable `.aseprite` files.

### Anokolisa - Hero's Journey / Moon Graveyard

- Source: Hero's Journey - Moon Graveyard
- Website: https://anokolisa.itch.io/moon-graveyard
- Author: Anokolisa
- Local path: `assets/art/vendor/anokolisa/moon-graveyard/`
- License summary from the package note: free for commercial use; credits optional/appreciated.
- License/source note in repository: `assets/art/vendor/anokolisa/moon-graveyard/Social/Autor_note.txt`
- Intended use in Ash Company: mood reference, background studies, future ruins/graveyard visual direction, and palette experiments.
- Notes: The background dimensions are larger than the current compact battle panel, so this should probably be cropped/adapted before being used in-game.

## Not committed

### Seth Boyles - 32rogues

- Source: 32rogues
- Website: https://sethbb.itch.io/32rogues
- Author: Seth Boyles
- Recommended local-only path: `assets/art/local-only/32rogues/`
- License summary from package: commercial/non-commercial use and modification are allowed, but redistribution/resale of the pack is not allowed.
- Repository decision: do not commit the original pack to this public repository.
- Intended use: local reference, Aseprite study, icon inspiration, or personal experimentation outside Git.

## Change log for edited Ash Company art

Use this section when creating modified art under `assets/art/source/` and exporting final PNGs to `assets/art/exported/`.

```text
Asset:
Based on:
Original author:
Original license:
Local source file:
Exported file:
Changes made:
Date:
```
