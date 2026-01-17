-- Optional configuration for dfc_controller.lua
-- Adjust these values to suit your reactor and preferences.

return {
  -- target power level used by the 'start' command (0-100 or reactor-specific units)
  targetLevel = 75,

  -- seconds between polls in monitor mode
  pollInterval = 2,

  -- maximum acceptable absorber stress (0.0-1.0). If exceeded, controller will set level to 0.
  maxStress = 0.9,

  -- Optional: set explicit addresses if automatic detection doesn't find them
  -- communicator = "d8b5f198-3112-4abc-a6d3-c1b5303798b8",
  -- injector = "288279a4-ed5f-4eda-99a2-32bc3bf1f3cf",
  -- absorber = "467b887f-9228-4888-84fc-2571d426c7ff",
}
