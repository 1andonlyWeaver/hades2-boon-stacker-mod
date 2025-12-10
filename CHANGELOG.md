# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2025-12-10

- **New Feature**: Progression System
  - Replaced all-or-nothing unlock with individual slot unlocks.
  - Five slot-specific incantations: Magick, Sprint, Cast, Special, Attack.
  - Each requires different boss materials (Cinder, Pearl, Wool, Tears, Golden Apple).
  - Incantations are hidden until you discover the required materials.
- **New Feature**: Stack Limit Upgrades
  - "Rite of Triple Capacity" (2→3 stacks) – requires Eagle's Feather.
  - "Rite of Quadruple Capacity" (3→4 stacks) – requires Zodiac Sand.
  - "Rite of Infinite Capacity" (unlimited) – requires Void Lens.
- **Backwards Compatibility**: Existing saves with the old `BoonStacker_Unlock` retain full functionality.
- **Improvements**:
  - Renamed incantations with thematic names ("Superposition of...", "Rite of...").
  - Improved flavor text for all incantations.
  - Fixed incorrect voicelines in incantations.
- **Configuration**:
  - Deprecated `EasyUnlock` option (no longer used with new progression system).

## [0.4.1] - 2025-12-05

- **Configuration**:
  - Added option to turn on/off prioritization for certain boon types.
- **Fixes & Improvements**:
  - Corrected system for calculating "stacked" boon probabilities.
  - Corrected issue where all boons were being prioritized on run start.

## [0.4.0] - 2025-12-05

- **New Feature**: Supplemental Hymn
  - Repurposed "Sacrificial Hymn" (LimitedSwapTraitDrop) to "Supplemental Hymn".
  - Prioritizes offering boons for slots that are already occupied (stacking).
  - Grants a level bonus (default +2) to stacked boons acquired this way.
  - Updated in-game text and descriptions via SJSON hooks.
- **Fixes & Improvements**:
  - Refactored `GetReplacementTraits` to support stacking logic.
  - Improved trait selection and bonus application stability.

## [0.3.0] - 2025-12-03

- **Configuration**:
  - Added `SkipIncantations` option (Default: `false`). When enabled, the mod is active immediately and incantations are removed from the game.
  - Allowed for descriptions to appear when adjusting config in mod manager.
- **Documentation**:
  - Improved introduction text in README.

## [0.2.2] - 2025-12-03

- _Attempt 2 at previous patch_

## [0.2.1] - 2025-12-03

- **Bug Fixes**:
  - `StackOnly` upgrades (e.g., Pom of Power) are no longer subject to the stack penalty probability reduction.
- **Documentation**:
  - Added Feedback section to README pointing to the GitHub Issue Tracker.

## [0.2.0] - 2025-12-01

- **UI**:
  - "Stacked" boons now appear in the boon menu list.
- **Bug Fixes**:
  - Fixed a bug where stacked boons' images were causing crashes.

## [0.1.1] - 2025-12-01

- Initial release.
- **Core Logic**:
  - Implemented logic to bypass occupied slot checks (`GetPriorityTraits`).
  - Disabled boon replacement logic (`GetReplacementTraits`).
  - Overrode slot status checks (`HeroSlotFilled`).
- **Incantation System**:
  - Added "Superposition of Divine Favor" incantation to unlock the boon stacking capability.
  - Added "Separation of Divine Favor" incantation to disable the mod and refund resources.
- **Balancing**:
  - Implemented probability reduction for finding boons for slots that are already occupied (configurable).
- **Configuration**:
  - Added `config.lua` with options for `EasyUnlock` (recipe cost) and `StackPenaltyScalar` (probability balancing).

[unreleased]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.5.0...HEAD
[0.5.0]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.4.1...0.5.0
[0.4.1]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.4.0...0.4.1
[0.4.0]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.2.2...0.3.0
[0.2.2]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.2.1...0.2.2
[0.2.1]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/0.1.1...0.2.0
[0.1.1]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/compare/460451930f480b1fc003e2af594ab27e0f0d5553...0.1.1
