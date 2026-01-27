SM.OS — Deployment and first-boot guide

This document explains how to prepare the repository, create role manifests, and install the code to OpenComputers machines.

Prerequisites
- On your development machine: PowerShell (Windows), Git, and Lua (for local tests).
- On the OpenComputers machine: Lua runtime (OpenOS), plus any components you plan to use (modem, GPU, NTM device).

1) Prepare the repository (dev machine)
- Clone the repo and run the unit tests locally:

```powershell
cd C:\path\to\SM.OS
lua tests/run_tests.lua
```

- Edit role-specific config files in `configs/` (example: `configs/primary_config.lua`) and set real component addresses and safety flags:
  - `ntm_address`, `gpu_address`, `screen_address`, `modem` settings
  - `core` thresholds (`max_level`, `safe_stress_threshold`, `max_rate_per_second`)
  - `safe_start` = true for first boot to prevent auto-starting reactors

2) Select install method

Option A — Offline packager (dev → OC manual transfer)
- Generate a single package you can transfer to the OC machine:

```powershell
cd C:\path\to\SM.OS
.\deploy\create_install_package.ps1
```

- This writes `install_package.lua` in the repo root. Transfer `install_package.lua` and `deploy/install_package_runner.lua` to the OC machine (paste or file transfer).
- On OC run:

```lua
lua install_package_runner.lua
```

Option B — GitHub installer (OC downloads directly)
- Create an install manifest in the repo root that lists the files to install. Examples are provided in the repo:
  - `install_manifest.lua` (default)
  - `install_manifest_primary.lua` (primary server)
  - `install_manifest_display.lua` (display server)

- On the OC machine, copy `deploy/install.lua` (wrapper) into the machine and run:

```lua
lua deploy/install.lua owner/repo [branch] [role|manifest]
```

Examples:
- Use default manifest in repo root:
  `lua deploy/install.lua myuser/SM.OS`
- Use role manifest `install_manifest_primary.lua`:
  `lua deploy/install.lua myuser/SM.OS main primary`

Notes on manifests
- A manifest is a Lua file that returns a table of file paths, e.g.:

```lua
return {
  'main.lua',
  'app.lua',
  'core/reactor.lua',
  'adapters/ntm_adapter.lua',
  'display.lua',
  'ui/reactor_screen.lua',
  'configs/primary_config.lua',
}
```

- Keep role manifests small and focused (only files needed by that server). Manifests included in repo: `install_manifest_primary.lua`, `install_manifest_display.lua`.

3) First boot safety
- Set `safe_start = true` in your role config so the controller does not automatically apply restored state or start reactors.
- After install, run `lua main.lua` on the OC machine. The app will:
  - Load `sleep_state.lua` if present and pass it into the runtime (resume option).
  - Show the boot animation (if display attached).

4) State persistence and restore
- On restart the app saves state via `files.save_state()` to `sleep_state.lua`.
- On boot `main.lua` loads `sleep_state.lua` and `app.run()` will call `core.reactor.restore_state()` after adapters are attached.

5) Verifying and troubleshooting
- Run local tests regularly:

```powershell
lua tests/run_tests.lua
```

- If an install fails, check for `.bak` files — the installer backs up existing files with a `.bak` suffix.
- If adapter binding fails on OC, ensure component addresses in `configs/*_config.lua` are correct and the hardware exists.

6) Helpful tips
- For first in-game test set `safe_start` and confirm all addresses before allowing the reactor to start.
- If you want the installer to target a specific manifest file name, pass it as the `role|manifest` argument to `deploy/install.lua`.
- To automate packaging per role, I can add a packager option to generate `install_manifest_<role>.lua` automatically.

Need help with a role manifest or creating configs for your OC machines? Tell me which server roles you have (primary, display, watchdog, etc.) and I will generate example manifests and config templates.
