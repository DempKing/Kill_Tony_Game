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

## Poly Haven textures (CC0)
Surface textures come from [Poly Haven](https://polyhaven.com). They are
released under CC0 (public domain): free for commercial use, no attribution
required (credited here anyway). Each is the 1K diffuse map, downscaled to a
256px tile, in `assets/textures/polyhaven/`. Drawn through `Materials`.

| Texture | Source | Used for |
|---|---|---|
| red_brick_03 | https://polyhaven.com/a/red_brick_03 | hostel and Lantern facades, Rusty Spur wall, interiors |
| factory_brick | https://polyhaven.com/a/factory_brick | Spur/Cellar storefronts, road-club stage |
| plastered_wall | https://polyhaven.com/a/plastered_wall | diner, coffee shop, apartments, mart, interiors |
| concrete_wall_003 | https://polyhaven.com/a/concrete_wall_003 | Mothership facade, Cellar stage, Kill Tony backdrop |
| asphalt_01 | https://polyhaven.com/a/asphalt_01 | road, alley, back lots |
| concrete_tiles_02 | https://polyhaven.com/a/concrete_tiles_02 | sidewalks, tiled floors |
| gravel_concrete | https://polyhaven.com/a/gravel_concrete | flat roofs |
| wood_floor | https://polyhaven.com/a/wood_floor | stage floors, interior floors |
| dark_wood | https://polyhaven.com/a/dark_wood | bar counters, panel desk, Redban's station, band riser |
| velour_velvet | https://polyhaven.com/a/velour_velvet | Lantern/theater curtains, panel chairs |
| corrugated_iron | https://polyhaven.com/a/corrugated_iron | Secret Show room |
| dirty_carpet | https://polyhaven.com/a/dirty_carpet | audience floors |

Poly Haven offers mostly 3D models and HDR skies, which don't apply to this 2D
game. So only textures are used; characters and props are still drawn in code.

## Real people
Tony Hinchcliffe (host) and Brian Redban appear **by name and role only**, in
`data/partner/partner_content.json`, flagged `approved: false`. Their figures
are generic placeholder looks drawn by `CharacterArt`, **not likenesses**. Guest
panelists are fictional. Stage positions (Tony at the host seat nearest the
mic, guests along the desk, Redban at a sound station) are a best-understanding
blockout in `data/partner/kill_tony_stage_layout.json`. They are not verified
against reference footage and should be checked by the partner.

## Process for approved assets
1. Put files in `assets/approved/<category>/` and list them here with the
   approver, date and scope.
2. Reference them from `data/partner/*.json` (for example `logo_asset`) and adjust
   the stage layout: panel, band, mic, backdrop, lighting, cameras, signage.
3. Flip the relevant `approved` flags.
4. Real-person dialogue must be reviewed as a unit in `data/partner/`.
