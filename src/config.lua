local config = {
  enabled = true,
  EasyUnlock = true,
  SkipIncantations = false,
  StackPenaltyScalar = 1.0,
  PrioritizeAttack = true,
  PrioritizeSpecial = true,
  PrioritizeCast = false,
  PrioritizeSprint = false,
  PrioritizeMagick = false,
}

local description = {
  enabled = "Enable or disable the mod.",
  EasyUnlock = "Toggle to use easier recipe (1 Moly) for the unlock incantation. If false, requires 1 Zodiac Sand and 1 Void Lens.",
  SkipIncantations = "Toggle to skip incantations and enable mod effects by default.",
  StackPenaltyScalar = "Multiplier for the probability penalty of stacked boons. Higher values make it less likely to find stacked boons (Default: 1.0). Set to 0.0 to disable the penalty.",
  PrioritizeAttack = "Include Attack boons in priority offers (guaranteed when slot is empty). Default: true (vanilla behavior).",
  PrioritizeSpecial = "Include Special boons in priority offers (guaranteed when slot is empty). Default: true (vanilla behavior).",
  PrioritizeCast = "Include Cast boons in priority offers (guaranteed when slot is empty). Default: false (vanilla behavior).",
  PrioritizeSprint = "Include Sprint boons in priority offers (guaranteed when slot is empty). Default: false (vanilla behavior).",
  PrioritizeMagick = "Include Magick boons in priority offers (guaranteed when slot is empty). Default: false (vanilla behavior).",
}

return config, description
