-- Optional configuration for dfc_controller.lua
-- Adjust these values to suit your reactor and preferences.

return {
  -- target power level used by the 'start' command (0-100 or reactor-specific units)
  targetLevel = 75,

  -- seconds between polls in monitor mode
  pollInterval = 2,

  -- maximum acceptable absorber stress (0.0-1.0). If exceeded, controller will set level to 0.
  maxStress = 0.9,

  -- Preset profiles for automatic control. Use `dfc_controller.lua auto <preset>`
  -- to run AUTO mode with one of these profiles.
  presets = {
    conservative = {
      targetLevel = 50,
      maxStress = 0.75,
      resumeStress = 0.6,
      pollInterval = 3,
      autoRestartDelay = 10,
    },
    balanced = {
      targetLevel = 75,
      maxStress = 0.85,
      resumeStress = 0.7,
      pollInterval = 2,
      autoRestartDelay = 5,
    },
    aggressive = {
      targetLevel = 90,
      maxStress = 0.95,
      resumeStress = 0.85,
      pollInterval = 1,
      autoRestartDelay = 3,
    },
  },

  -- Optional: set explicit addresses if automatic detection doesn't find them
  -- communicator = "d8b5f198-3112-4abc-a6d3-c1b5303798b8",
  -- injector = "288279a4-ed5f-4eda-99a2-32bc3bf1f3cf",
  -- absorber = "467b887f-9228-4888-84fc-2571d426c7ff",
  -- Optional: screen UUIDs for per-screen agents (recommended)
  displayScreens = {
    emitters = "366385c4-353a-4fea-8c2b-c04244fcb443",
    core     = "be203944-69b8-4616-bf2c-1a9374194e67",
    stabilizers = "fbec3a19-0949-4f2e-9bfd-248c2f88502b",
  },

  -- Display network settings (optional)
  displayPort = 12345,
  displayToken = "secret-token",
  -- Controller local screen UUID (display on controller machine)
  controllerScreen = "edc00d0a-8c38-4f75-a467-0e77547e5fb0",
}
