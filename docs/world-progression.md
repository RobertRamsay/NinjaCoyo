# World and progression update

Restart the Studio play session after Rojo syncs these files. The world is rebuilt at server startup.

## Movement and combat

- Ninja Jump levels 0–2: existing double jump.
- Level 3: forward flips.
- Level 7: three jumps per landing, with spinning air flips.
- Katana Power gradually widens the slash from 180 degrees to 360 degrees at level 10. Higher levels add longer trails, colour changes and a layered whoosh at level 20. Damage and hit range retain their existing server rules.

## Dogs and clothing

Wolf Pack levels 0–3 create 1–4 companions: Coyo, Kiba, Yuki and Hana. The first pack upgrade immediately adds Kiba. In Dressing House → Dog Pack, select a dog before equipping its look. Each dog's choice saves separately; existing saves keep their previous shared coat until individual choices are made.

| Look | Gameplay unlock |
|---|---|
| Coyote / Amber Shiba | Free |
| Snow Wolf | Wolf Pack level 1 |
| Shadow Fox | Ninja Jump level 3 |
| Fire Fox | Coyo Bite level 5 |
| Spirit Wolf | Wolf Pack level 3 |
| Crimson Ninja | Free |
| Shadow Ninja | Ninja Jump level 3 |
| Jade Ninja | Ninja Vitality level 3 |
| Golden Samurai | Katana Power level 10 |

Existing pass ownership remains valid. StudioOwnsEverything still allows all cosmetics in Studio; disable it in Config to check the progression locks. Dog looks are cosmetic. Outfits use built-in fabric materials, layered lapels, stitched pockets, thigh pouches and padded guards, so they need no uploaded clothing textures.

## World

The meadow now uses twelve pickup regions spanning X −245…245 and Z −110…235, staying outside the first locked area. There are 100 meadow coins and 10 chests. Five grassy treasure terraces have stepping-stone approaches; summit chests take priority when refilling. Buildings and statues reserve their footprints to prevent hidden pickups. Dressing houses are in Meadow, Bamboo and Sakura; tea houses and wolf guardians add landmarks.

## Original ambience: upload still required

The original, synthesised audio is in assets/sounds:

- NinjaCoyo_wind.wav — 28-second seamless wind loop.
- NinjaCoyo_chimes.wav — 9-second chime phrase, played intermittently.

Upload both as Roblox audio assets accessible to this experience. Set Config.Ambience.WindId and Config.Ambience.ChimesId to their rbxassetid:// IDs. They deliberately remain empty until real IDs are available. Ambient wind fades near the first gate and stops outside the meadow; chimes play at random 13–24-second intervals. Volume controls are beside the asset IDs. Neither changes the gate music.

## Checks and playtest

Automated checks cover save migration, pack counts, coat permissions and slot validation, pickup distribution, rotated scenery clearance, jump limits and animation cleanup. Run `node tests/run.cjs` with the Luau CLI on PATH, or set LUAU to its executable path. These tests use mocked Roblox services and do not replace Studio playtesting.

In Studio, check jumps at levels 0, 3 and 7, katana sweeps at 0, 5, 10 and 20, Kiba appearing after the first pack upgrade, separate coats across respawns, terrace access and summit chests, wardrobe entrances, and audio fading after the uploads. Test with two players to check remote jump and sword visuals. Live visual appearance and audio playback have not yet been verified.
