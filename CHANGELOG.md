## 0.1.0

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
