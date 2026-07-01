# Ash Company art next steps

## Immediate goal

Add art without changing the combat rules yet.

The first pass should make the battlefield feel alive while keeping the code simple:

1. Add a static or animated side-view sprite to the combatant display.
2. Use the High Forest character as a temporary hero placeholder.
3. Use the High Forest snail or boar as the first temporary Ashling/enemy placeholder.
4. Keep the current text/HP UI until the sprite layout feels stable.
5. Export edited sprites from Aseprite into `assets/art/exported/` and leave original/vendor assets untouched.

## Suggested first Aseprite exercise

1. Open `assets/art/vendor/anokolisa/legacy-fantasy-high-forest/Character/Idle/Idle.aseprite`.
2. Save a copy as `assets/art/source/heroes/vanguard.aseprite`.
3. Recolor the character toward Ash Company: darker clothes, ash-gray shadows, one strong accent color.
4. Export the idle sheet to `assets/art/exported/heroes/vanguard_idle.png`.
5. Repeat with an enemy sprite as `assets/art/source/enemies/ashling_basic.aseprite`.

## Keep in mind

- Vendor assets should stay unchanged.
- Edited Ash Company art should live under `assets/art/source/`.
- Godot should use exported PNG/spritesheets under `assets/art/exported/`.
- Non-redistributable packs should stay under `assets/art/local-only/`, which is ignored by Git.
