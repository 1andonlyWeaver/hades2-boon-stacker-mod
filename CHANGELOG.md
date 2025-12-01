# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

-   Initial release.
-   **Core Logic**:
    -   Implemented logic to bypass occupied slot checks (`GetPriorityTraits`).
    -   Disabled boon replacement logic (`GetReplacementTraits`).
    -   Overrode slot status checks (`HeroSlotFilled`).
-   **Incantation System**:
    -   Added "Superposition of Divine Favor" incantation to unlock the boon stacking capability.
    -   Added "Separation of Divine Favor" incantation to disable the mod and refund resources.
-   **Balancing**:
    -   Implemented probability reduction for finding boons for slots that are already occupied (configurable).
-   **Configuration**:
    -   Added `config.lua` with options for `EasyUnlock` (recipe cost) and `StackPenaltyScalar` (probability balancing).

[Unreleased]: https://github.com/1andonlyWeaver/hades2-boon-stacker-mod
