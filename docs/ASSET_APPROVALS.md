# Asset Approvals

Nothing has been partner-approved. **No** logo, likeness, recording, music,
architectural drawing or third-party asset is used.

| Asset | Status | Source |
|---|---|---|
| Characters (player, NPCs, panel, band, crowds) | Placeholder | Shared procedural renderer `CharacterArt` (faces, expressions, 5 hair styles, walk cycle) |
| District art (sky, skyline, facades, props, street life) | Placeholder | Drawn in code (`DistrictMap`), night lighting via additive `DistrictGlow` |
| Comedy Mothership exterior | Placeholder, **original saucer-marquee design**, not the real building | `DistrictMap._draw_mothership` |
| Title screen backdrop | Placeholder | `TitleBackdrop` |
| Interiors | Placeholder | Drawn in code (`LocationPanel.InteriorArt`) |
| Club / road / theater / arena stages | Placeholder | Drawn in code (`StageArt`: dive, lantern, cellar, secret, road club, theater, arena) |
| Street NPC figures | Placeholder | Drawn in code (`StreetNpc`) |
| Kill Tony stage | Placeholder blockout, **not architecturally accurate** | `KtStageArt` + `data/partner/kill_tony_stage_layout.json` |
| Show logo / signage | Placeholder text only (`logo_asset` empty) | `data/partner/partner_content.json` |
| Panel members, host, band | Placeholder figures and names | `data/partner/partner_content.json` |
| "Redban" name and lines | Pending partner review | `data/partner/partner_content.json` |
| Comedy Mothership name | Used as a location label per project spec; exterior is fictional | `data/venues/locations.json` |
| SFX (laughs, applause, stings) | Original procedural placeholders | `scripts/core/sfx.gd` |
| Music (band loop, street bed) | Original procedural placeholders | `scripts/core/sfx.gd` |
| Joke text | Original, written for this project | `data/material/components.json` |
| Font | Godot default font, plus DejaVu Sans as a symbol fallback (Bitstream Vera/DejaVu license, free for commercial use) | engine; `assets/fonts/DejaVuSans.ttf` |
| Icon | Original placeholder | `icon.svg` |

## Process for approved assets
1. Put files in `assets/approved/<category>/` and list them here with the
   approver, date and scope.
2. Reference them from `data/partner/*.json` (for example `logo_asset`) and adjust
   the stage layout: panel, band, mic, backdrop, lighting, cameras, signage.
3. Flip the relevant `approved` flags.
4. Real-person dialogue must be reviewed as a unit in `data/partner/`.
