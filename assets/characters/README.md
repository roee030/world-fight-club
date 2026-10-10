# Character portrait assets

| Character ID | Hero / tile image | Palette | Notes |
|---|---|---|---|
| `bibi` | `bibi-hero.png` / `bibi-thumb.png` | midnight navy, Israeli blue | Large fighter art and a separate bust crop derived from the generated combat atlas; no source photo or text inside thumbnails. |
| `yair_golan` | `yair-golan-hero.png` / `yair-golan-thumb.png` | field olive, amber | Large fighter art and a separate bust crop derived from the generated combat atlas; no source photo or text inside thumbnails. |

The matching `*-reference.png` files preserve the supplied source photos for future art direction. Card canvases are 1024x624, matching the current Bennet and Avigdor card art dimensions. The generated 3×2 combat atlases under `output/imagegen/` are sliced into six transparent poses per fighter in `assets/characters/sprites/` by `tools/import_fighter_atlases.py`. The game uses those poses for guard, step, crouch, jab, heavy and kick animation clips.

The older `*-card.png` files are preserved but no longer used for Bibi or Yair in the menu and character select. Hero artwork and roster thumbnails are separate so small tiles do not contain tiny embedded card graphics.
