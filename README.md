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
```
- After pushing, edit `deploy.lua` and set `DEFAULT_REPO = "youruser/yourrepo"`.
- On each OpenComputers machine run:
# DFC OpenComputers Controller

This repository contains a small OpenComputers controller for the Dark Fusion Cursed (DFC) reactor components.

Files
- `dfc_controller.lua` — CLI controller (start/stop/status/monitor/auto/describe/detect)
- `dfc_lib.lua` — library with safe wrappers and helpers
- `deploy.lua`, `files.lua` — deploy helper to fetch files from GitHub
- `config.lua` — local configuration (copy and edit as needed)
- `serve_for_oc.ps1` — optional host helper to serve files over HTTP for local testing

Quick start
1. Push this folder to a GitHub repo (recommended) or serve it locally.
2. On the OpenComputers machine, ensure an `internet` card is present.
3. Download `deploy.lua` and run:
```lua
deploy.lua --verbose
```
4. Run the controller commands:
```lua
dfc_controller.lua detect
dfc_controller.lua describe
dfc_controller.lua status
dfc_controller.lua start
dfc_controller.lua monitor
dfc_controller.lua auto
```

Notes
- `describe` safely lists methods and samples non-mutating getters for all detected components (`dfc_communicator`, `dfc_injector`, `dfc_absorber`, `dfc_emitter`).
- `detect` prints addresses of all detected components.
- `auto` mode will shutdown on high absorber stress and attempt a conservative restart once stress drops below a configurable threshold.

Configuration
- Edit `config.lua` to adjust `targetLevel`, `pollInterval`, `maxStress`, `resumeStress`, `primaryCommunicator`, and other settings.

Deployment
- Keep `files.lua` at the repo root so `deploy.lua` can fetch it as `https://raw.githubusercontent.com/<owner>/<repo>/main/files.lua`.

If you want, I can clean up the repo further, add logging, or implement secure remote control.
