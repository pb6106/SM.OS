# DFC OpenComputers Controller

Files added:
- `dfc_controller.lua` - main controller CLI script for OpenComputers
- `config.lua` - optional config (copy and edit values as needed)

Quick start:

1. Place `dfc_controller.lua` and `config.lua` on the OpenComputers computer's filesystem.
2. From an OpenComputers shell run:

```lua
dfc_controller.lua detect
dfc_controller.lua status
dfc_controller.lua start
dfc_controller.lua monitor
```

Notes and troubleshooting:
- The script auto-detects `dfc_communicator`, `dfc_injector`, and `dfc_absorber`. If detection fails, set addresses in `config.lua`.
- The Dark Fusion Cursed Addon components may expose different field names; the script uses safe calls and fallbacks, but you may need to tune `config.maxStress`.
- This controller intentionally avoids automatic item insertion (injector writes) because injector APIs vary; if you want auto-fueling, tell me and I can add it for your setup.

Component methods reference (common)
 - `communicator.analyze()` : returns a table with detailed reactor/analyzer info (may include fields like `level`, `power`, `maxPower`, `charge`, `stress`).
 - `communicator.getLevel()` : numeric current reactor level (or nil if not available).
 - `communicator.getPower()` / `communicator.getMaxPower()` : numeric power values.
 - `communicator.getChargePercent()` : numeric 0..1 or 0..100 depending on component.
 - `communicator.setLevel(value)` : set reactor level; may accept a numeric or a table `{level=value}` depending on implementation.
 - `absorber.getLevel()` / `absorber.storedCoolant()` / `absorber.getStress()` : absorber-specific getters; `getStress` commonly returns 0.0-1.0.
 - `injector.getFuel()` / `injector.getTypes()` / `injector.getInfo()` : injector status methods; exact fields vary by addon.

Use the `describe` command in `dfc_controller.lua` to safely list available methods on your detected components and sample outputs (the describe command avoids calling methods that look like they mutate state).

If you want a modem remote-control, screen UI, or logging to a file, I can add those next.
 
Deployment options
- **GitHub (recommended):** push this folder to a GitHub repo and use the raw URL or shorthand with `deploy.lua` on the OpenComputers machine.
   - Example (from OC):
      ```lua
      deploy.lua owner/repo          -- uses branch 'main'
      deploy.lua owner/repo/branch
      deploy.lua https://raw.githubusercontent.com/owner/repo/branch/path
      ```
   - `deploy.lua` will look for `files.lua` in the provided path and download each file listed there.
- **Gist / Paste (works):** create a raw gist or paste containing a `files.lua` manifest and point `deploy.lua` at the raw URL.
- **Local host (quick dev):** run `serve_for_oc.ps1` on your host to serve files over HTTP, then run `deploy.lua http://<host-ip>:8000` on OC.

Examples (host-side):
```powershell
.\serve_for_oc.ps1   # serves dfc_controller.lua, config.lua, README.md, deploy.lua
```

Examples (OpenComputers):
```lua
deploy.lua http://192.168.1.10:8000
deploy.lua owner/repo
deploy.lua https://gist.githubusercontent.com/.../raw/files.lua
```

Quick run without args
- You can set the default repo directly inside `deploy.lua` by editing the `DEFAULT_REPO` variable near the top of the file. After that you may run `deploy.lua` with no arguments:
```lua
deploy.lua
```

Create a GitHub repo and push (quick guide)
- On your workstation, create a new repo on GitHub (or via the website) named `yourrepo` under `youruser`.
- Locally, from this folder run:
```powershell
git init
git add .
git commit -m "Initial commit: DFC controller"
git branch -M main
git remote add origin https://github.com/pb6106/SM.OS.git
git push -u origin main
```
- After pushing, edit `deploy.lua` and set `DEFAULT_REPO = "youruser/yourrepo"`.
- On each OpenComputers machine run:
```lua
deploy.lua   -- will use DEFAULT_REPO (now set to `pb6106/SM.OS`)
```
[![Discord](https://img.shields.io/badge/discord-server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/USpt3hCBgn)
[![Support](https://img.shields.io/badge/Buy%20Me%20a-Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee)](https://www.buymeacoffee.com/adidev)
[![License](https://img.shields.io/github/license/xzxADIxzx/Join-and-kill-em-together?style=for-the-badge)](https://github.com/xzxADIxzx/Join-and-kill-em-together/blob/main/LICENSE)
[![Stars](https://img.shields.io/github/stars/xzxADIxzx/Join-and-kill-em-together?style=for-the-badge&logo=githubsponsors&color=EA4AAA)](https://github.com/xzxADIxzx/Join-and-kill-em-together)
[![Devlogs](https://img.shields.io/badge/dev-logs-FF0000?style=for-the-badge&logo=youtube)](https://www.youtube.com/playlist?list=PLcTAO30JMDuRpoBTAkvu2ELKDM74j43Tz)

# Join and kill 'em together
This modification made by [me](https://github.com/xzxADIxzx) and my team adds support for multiplayer via Steamworks to ULTRAKILL. The idea to create this project came to me immediately after completing the game in a week, and since MULTIKILL is still in development, nothing stopped me from speedrunning programming.

## Features
* Integration with Steam
   * Public, friends only and private lobbies
   * Invitations via Steam or lobby code
   * Rich Presence
   * Lobby settings
* Automatic check for updates
* User interface
   * Lobby menu, player list and settings
   * Player indicators to help you find each other on the map
   * Information about teammates: their health and rail charge
   * List of public lobbies so you never get bored
   * Chat, in case you have no other means of communication
   * Interactive guide to help you understand the basics
* Interaction between players
   * Up to 5 teams, making available both the passage of the campaign and PvP
   * Emote wheel to tease your friends or bosses
   * Pointers to guide your friends in the right direction
   * SAM TTS Engine for speaking messages via /tts command
   * Sprays and moderation system for them
   * Extended V2 coins mechanic
* Synchronization of everything
   * Players, their weapons, weapons paint, fists, hook, animations, particles and even head rotation
   * All projectiles in the game and chargeback damage
   * All sorts of items such as torches, skulls and developer plushies
   * Synchronization of position and attacks of enemies
   * Synchronization of special bosses such as Leviathan, Minos' hand and Minotaur
   * Synchronization of different triggers at levels
   * Synchronization of the Cyber Grind
* Translation into many languages
   * Arabic        by Iyad
   * Portuguese    by Poyozit
   * English
   * Filipino      by Fraku
   * French        by Theoyeah
   * Italian       by sSAR, Fenicemaster
   * Polish        by Sowler
   * Russian
   * Spanish       by NotPhobos
   * Ukrainian     by Sowler

## Installation
Before installing, it's important to know that the mod requires **BepInEx** to work.  
Without it, nothing will make a *beep-beep* sound.

### Mod manager
Your mod manager will do everything itself, that's what mod managers are for.  
Personally, I recommend [r2modman](https://github.com/ebkr/r2modmanPlus).

### Manual
1. Download the mod zip archive from [Thunderstore](https://thunderstore.io/c/ultrakill/p/xzxADIxzx/Jaket).
2. Find your plugins folder.
3. Extract the content of the archive into a subfolder.  
   Example: `BepInEx/plugins/Jaket/Jaket.dll`

## Building
To compile you will need .NET SDK 6.0 and Git.  
**Important**: You don't need this if you just want to play with the mod.

1. Clone the repository with `git clone https://github.com/xzxADIxzx/Join-and-kill-em-together.git`
   1. Run `cd <path-to-cloned-repository>`
2. Run `dotnet restore`
3. Create lib folder in root directory.
   1. Copy **Assembly-CSharp.dll**, **Facepunch.Steamworks.Win64.dll**, **plog.dll**, **Unity.Addressables.dll**, **Unity.ResourceManager.dll**, **Unity.TextMeshPro.dll**, **UnityEngine.UI.dll** and **UnityUIExtensions.dll** from `ULTRAKILL\ULTRAKILL_Data\Managed`
   2. As well as **BepInEx.dll** and **0Harmony.dll** from `ULTRAKILL\BepInEx\core`
4. Compile the mod with `dotnet build`
5. At the output you will get the **Jaket.dll** file, which will be located in the `bin\Debug\netstandard2.0` folder.
   1. Copy this file to the mods folder.
   2. Copy the **jaket-assets.bundle** file and bundles folder from the assets folder to the mods folder.
   3. Copy the **manifest.json** file from the root folder.

## Afterword
I fix bugs all the time, but some of them are hidden from me.  
Anyway feel free to ping me on Discord **xzxADIxzx** or join our [server](https://discord.gg/USpt3hCBgn).

I am very grateful to all those who supported me during development. Thank you!  
Cheers~ ♡
