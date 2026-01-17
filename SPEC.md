# SM.OS DFC Controller — Specification

Purpose
- Provide a safe, auditable controller for the Dark Fusion Cursed (DFC) reactor components running on OpenComputers.

MVP Goals
- Detect `dfc_communicator`, `dfc_injector`, and `dfc_absorber` components.
- Provide CLI commands: `start`, `stop`, `status`, `monitor`, `describe`.
- Offer an `auto` mode that safely shuts down the reactor when absorber stress is high and restarts when safe.
- Deployable via `deploy.lua` from GitHub (single-command update).

Safety and constraints
- All mutating actions are explicit and opt-in where possible.
- `auto` mode must use conservative defaults and be configurable via `config.lua`:
  - `maxStress` (default 0.9)
  - `resumeStress` (optional; default `maxStress * 0.8`)
  - `autoRestartDelay` (seconds; default 5)
  - `maxRestartsPerHour` (to avoid restart loops; optional)
- Avoid writing to injectors unless `injectorAutoFuel = true` in config and explicit mapping is provided.

Logging & debugging
- Add optional verbose mode and file logging; log critical events (shutdown, restart attempts, failures).
- Logs should be readable and rotate or be limited by size if persistent logging is enabled.

AUTO mode behavior (recommended)
1. Monitor at `pollInterval` seconds.
2. If `stress >= maxStress`: set reactor level to 0 and record event.
3. Periodically poll until `stress < resumeStress`.
4. Wait `autoRestartDelay` seconds and attempt to set reactor to `targetLevel`.
5. Track restart counts and enforce `maxRestartsPerHour` to prevent thrashing.

Advanced features (future)
- Injector auto-fueling module (pluggable drivers per injector type).
- Secure remote-control via modem with authentication and ACLs.
- Per-server roles for the rack (e.g., one server is master + three display nodes).
- Screen-based dashboard for front displays.
- Unit tests and a mock harness for `dfc_lib.lua`.

Deployment & workflow
- Keep repository root as deploy base so `files.lua` and `deploy.lua` are at `https://raw.githubusercontent.com/<owner>/repo/main/`.
- Developer workflow: edit locally → commit → push → `deploy.lua` on each OC machine.

Next steps
- Implement logging and config validation.
- Harden `auto` mode (backoff, max restarts, alerting).
- Add optional injector fueling as opt-in.
