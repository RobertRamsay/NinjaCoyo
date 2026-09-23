# NinjaCoyo

A Roblox ninja-and-coyote collecting game. All game code lives in `src/` and is synced into Roblox Studio with [Rojo](https://rojo.space).

## Layout

| File | Becomes in Studio |
|---|---|
| `src/ReplicatedStorage/NinjaCoyoConfig.luau` | ModuleScript in ReplicatedStorage |
| `src/ReplicatedStorage/NinjaCoyoSounds.luau` | ModuleScript in ReplicatedStorage |
| `src/ServerScriptService/NinjaCoyoServer.server.luau` | Script in ServerScriptService |
| `src/ServerScriptService/NinjaCoyoWorld.luau` | ModuleScript in ServerScriptService |
| `src/ServerScriptService/NinjaCoyoEnemies.luau` | ModuleScript in ServerScriptService |
| `src/ServerScriptService/NinjaCoyoWardrobe.luau` | ModuleScript in ServerScriptService |
| `src/StarterPlayerScripts/NinjaCoyoClient.client.luau` | LocalScript in StarterPlayer > StarterPlayerScripts |
| `src/StarterPlayerScripts/NinjaCoyoFx.client.luau` | LocalScript in StarterPlayer > StarterPlayerScripts |
| `src/StarterPlayerScripts/NinjaCoyoWardrobeUI.client.luau` | LocalScript in StarterPlayer > StarterPlayerScripts |

`assets/sounds/` holds the original sound effects (already uploaded; their IDs are in `Config.Sounds`).

## Working on it

1. `rojo serve` in this folder.
2. In Studio: Plugins > Rojo > Connect.
3. Edit files here (or apply a patch with `git apply <name>.patch`); Studio updates live.

Edit scripts in the files, not in Studio: Rojo syncs files into Studio, not the other way.
