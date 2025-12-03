local config = {
  enabled = true,
  EasyUnlock = true,
  SkipIncantations = false,
  StackPenaltyScalar = 1.0,
}

local description = {
  enabled = "Enable or disable the mod.",
  EasyUnlock = "Toggle to use easier recipe (1 Moly) for the unlock incantation. If false, requires 1 Zodiac Sand and 1 Void Lens.",
  SkipIncantations = "Toggle to skip incantations and enable mod effects by default.",
  StackPenaltyScalar = "Multiplier for the probability penalty of stacked boons. Higher values make it less likely to find stacked boons (Default: 1.0). Set to 0.0 to disable the penalty."
}

return config, description
