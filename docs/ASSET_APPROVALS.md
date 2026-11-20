# Asset Approvals

Nothing has been partner-approved. **No** logo, likeness, recording, music,
architectural drawing or third-party asset is used.

| Asset | Status | Source |
|---|---|---|
| Characters (player, NPCs, panel, band) | Placeholder | 3D: low-poly figures built from primitives in code (`Character3D`). 2D screens (creator, interiors, title) still use `CharacterArt`. Both read the same `look` data. |
| Crowds | Placeholder | Instanced capsule-and-head silhouettes (`Crowd3D`) |
| District (buildings, street, props, street life) | Placeholder | 3D, built in code (`District3D`) from the layout in `data/venues/locations.json`; textured with Poly Haven surfaces; street furniture from Poly Haven models (below) |
| Comedy Mothership exterior | Placeholder, **original saucer-marquee design**, not the real building | `District3D._build_mothership` |
| Title screen backdrop | Placeholder | `TitleBackdrop` |
| Interiors | Placeholder | Drawn in code (`LocationPanel.InteriorArt`) |
| Club / road / theater / arena stages | Placeholder | 3D, built in code (`Stage3D`: dive, lantern, cellar, secret, road club, theater, arena) |
| Street NPC figures | Placeholder | `Character3D`, driven by the hidden `StreetNpc` logic node |
| Kill Tony stage | Placeholder 3D blockout, **not architecturally accurate** | `KtStage3D` + `data/partner/kill_tony_stage_layout.json` (incl. `cameras_3d`) |
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
256px tile, in `assets/textures/polyhaven/`. 2D screens draw them through
`Materials`; 3D scenes map them triplanar through `Mat3D.surface`.

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

## Poly Haven models (CC0)
Since the 3D conversion, street furniture and stage props are Poly Haven
models, also CC0. Each is the 1K glTF with its textures downscaled to 256px,
in `assets/models/polyhaven/<id>/`, loaded through `ModelLib`. Some files hold
several variants (clean and rusty copies); only the named meshes are shown.

| Model | Source | Used for |
|---|---|---|
| street_lamp_02 | https://polyhaven.com/a/street_lamp_02 | lantern heads on the street-lamp poles |
| fire_hydrant | https://polyhaven.com/a/fire_hydrant | hydrants (clean variant) |
| metal_trash_can | https://polyhaven.com/a/metal_trash_can | sidewalk trash cans (clean variant) |
| utility_box_01 | https://polyhaven.com/a/utility_box_01 | utility boxes |
| potted_plant_02 | https://polyhaven.com/a/potted_plant_02 | sidewalk planters |
| exterior_aircon_unit | https://polyhaven.com/a/exterior_aircon_unit | rooftop AC units |
| bar_chair_round_01 | https://polyhaven.com/a/bar_chair_round_01 | open-mic bar stools |
| metal_stool_01 | https://polyhaven.com/a/metal_stool_01 | the stool on every club stage |
| round_wooden_table_01 | https://polyhaven.com/a/round_wooden_table_01 | Lantern Room tables |
| classic_laptop | https://polyhaven.com/a/classic_laptop | Redban's laptop |
| hanging_industrial_lamp | https://polyhaven.com/a/hanging_industrial_lamp | open-mic room lamps |
| wine_bottles_01 | https://polyhaven.com/a/wine_bottles_01 | bottles on the open-mic bar |

Poly Haven has no people, so characters are built in code. Buildings, cars,
the band's instruments and the stage risers are built in code from boxes and
cylinders.

## Real people
Tony Hinchcliffe (host) and Brian Redban appear **by name and role only**, in
`data/partner/partner_content.json`, flagged `approved: false`. Their figures
are generic placeholder looks (`Character3D`/`CharacterArt`), **not likenesses**. Guest
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
