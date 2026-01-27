SM.OS — OpenComputers runtime for DFC (NTM)
===========================================

This repository is a consolidated, testable OpenComputers runtime scaffold for controlling DFC reactors and related NTM devices from HBM's Nuclear Tech.

This README documents how to install and run the runtime in-game, how to configure it for real hardware (GPUs/screens/NTM components), and how to run local tests using the included mocks.

Prerequisites
-------------
- Minecraft with OpenComputers and HBM's Nuclear Tech installed.
- A computer in OpenComputers with enough RAM to load the runtime and bind GPUs/screens.
- Familiarity with OpenOS commands (`components`, `pastebin`, `edit`, etc.) and with copying component addresses (Analyzer or `components` list).

Quick overview of files
-----------------------
- `main.lua` — single-entrypoint that runs the `app` orchestrator.
- `app.lua` — boots subsystems, binds adapters, runs main loop.
- `core/` — pure logic modules (e.g., `core/reactor.lua`).
- `display.lua` — display orchestration and UI rendering glue.
- `adapters/` — hardware adapters (e.g., `ntm_adapter.lua`, `gpu_adapter.lua`).
- `oc_mocks/` — local test shims that emulate `component` and `event` APIs for off-game testing.
- `ui/` — small UI screens (e.g., `ui/reactor_screen.lua`).
- `install.lua`, `upgrade.lua` — installer/upgrade stubs to run in-game.
- `doc/NTM_API.md` — notes and mappings for NTM / DFC OpenComputers API.

Installation (in-game)
----------------------
Recommended approach: copy the repository files into a folder on the OpenComputers computer (for example `/home/sm.os`) and register `main.lua` as startup.

Example in-game install steps (run on the target computer):

```lua
-- on the OC computer shell
mkdir /home/sm.os
cd /home/sm.os
-- copy/transfer files (use pastebin/raw hosting or an archive unpacker tool)
-- for a simple manual install, paste each file into /home/sm.os/<name>.lua
-- register startup (OpenOS):
mkdir -p /etc/rc.d
edit /etc/rc.d/start-smos
-- inside the file add: cd /home/sm.os && lua5.3 main.lua
-- then make it executable via filesystem (OpenOS auto-runs scripts in rc.d)
```

If you prefer an automated installer, implement `install.lua` to write files into `/home/sm.os` and create the startup entry. The scaffold includes a placeholder installer (`install.lua`) you can extend.

Configuration
-------------
Create a simple `config.lua` in the runtime folder (e.g., `/home/sm.os/config.lua`) with the addresses of your components and runtime tuning. Example minimal config:

```lua
return {
	ntm_address = 'd8b5f198-3112-4abc-a6d3-c1b5303798b8', -- example from discovery
	gpu_address = '6d96e7db-24d4-4a6d-a187-c6b510cf713f',
	screen_address = 'edc00d0a-8c38-4f75-a467-0e77547e5fb0',
	tick_delay = 0.5,
	core = {
		max_level = 100,
		safe_stress_threshold = 0.8,
		stabilizer_durability_threshold = 10,
		max_rate_per_second = 20,
	},
}
```

Notes:
- Use `components` in the OpenOS shell or the Analyzer tool to find exact addresses for `ntm`, `gpu`, and `screen` components.
- For multi-monitor setups, specify a simple table mapping of logical monitors to `{ gpu_address, screen_address }` and update `files.load_display_config()` to return it.

Running
-------
Once files and `config.lua` are in place, start the runtime on the target computer by running:

```lua
lua5.3 main.lua
```

Or rely on the startup entry you created in `/etc/rc.d` so it launches on boot.

Behavior and safety features
----------------------------
- The runtime consolidates control into a single process. It monitors telemetry and enforces safety policies in `core/reactor.lua`.
- Emergency shutdown conditions include:
	- Stress exceeding configured thresholds.
	- Stabilizer durability at or below `stabilizer_durability_threshold` (percent).
	- Rate-limit violations for control level changes.
- The runtime logs emergency statuses to stderr; use the OpenComputers console or attach a logging peripheral for persistent logs.

Testing locally (desktop Lua using mocks)
----------------------------------------
You can run unit tests off-game using the included mocks in `oc_mocks/`.

Example (on your Windows dev machine with Lua installed):

```powershell
cd 'C:\Users\cring\OneDrive\Documents\SM.OS'
lua tests/test_reactor.lua
```

The mocks emulate basic `ntm` and `component` behavior so core logic and emergency shutdowns can be validated locally.

Development notes
-----------------
- Add or extend adapters in `adapters/` to map device-specific `getInfo()`/`get*()` return values into the normalized telemetry keys expected by `core/reactor.lua` (e.g., `level`, `power`, `maxPower`, `stress`, `maxStress`, `stabilizer_durability`).
- Keep pure logic in `core/` and side-effecting code in `adapters/` so unit tests remain simple.
- UI screens in `ui/` are intentionally minimal text renderers; implement richer rendering or image stitching across multiple screens as a follow-up.

Troubleshooting
---------------
- "No adapter available" when booting: ensure `config.lua` contains valid component addresses or that `install.lua` was run on the target computer to install the files.
- Runtime crashes on start: inspect `/var/log` if present or run `lua5.3 main.lua` manually to see stderr output.
- If displays are blank: verify `gpu.bind()` and `screen.turnOn()` usage in your GPU adapter and that the GPU has sufficient resolution/buffer memory.

Next steps / extension ideas
---------------------------
- Implement `install.lua` to automate copying files and registering startup.
- Expand `adapters/ntm_adapter.lua` with full mapping for `dfc_emitter`, `dfc_stabilizer`, `dfc_communicator`, and other NTM device types using the wiki's return index tables.
- Implement a more advanced UI that can render a single large image across multiple screens (image tiling / stitching) while maintaining low CPU usage.
- Add integration tests that run on a dedicated in-game test computer to validate real hardware.

If you want, I can now:
- implement the full NTM adapter mapping using the wiki doc you provided, or
- implement a multi-monitor image tiling renderer, or
- finish the `install.lua` automated installer for in-game deployment.

Contact
-------
Open a workspace issue or reply here with the next task you want prioritized.

