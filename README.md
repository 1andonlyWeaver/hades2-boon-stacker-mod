# BoonStacker

**BoonStacker** transforms the boon system in Hades II, unlocking the ability to **stack** boons on your core slots (Attack, Special, Cast, Sprint, Magick) rather than being forced to replace them.

Ever found a perfect boon but didn't want to sacrifice the one you already had? With BoonStacker, you don't have to choose. Combine the might of multiple Olympians on a single move to create devastating synergies and unique builds that simply weren't possible before.

This mod is integrated into the game's incantation system and allows for steady progression by gathering materials and performing incantations at the Crossroads Cauldron. Alternatively, set `SkipIncantations` to `true` in the config to unlock everything immediately.

> **Disclaimer**: This mod significantly alters the game's balance. Stacking multiple gods' effects on a single move can lead to extremely powerful combinations.

## Features

-   **Boon Stacking**: You can now accept new boons for your Attack, Special, Cast, Sprint, and Magick slots even if they are already filled. The new boon will be added alongside the existing one.
-   **No Replacements**: "Swap" or "Replace" offers are disabled for these slots. You will simply add to your arsenal.
-   **Probability Balancing**: To keep things somewhat grounded, the probability of finding a boon for a specific slot decreases slightly as you stack more boons into that slot.

## How to Use

By default, the mod uses a **progression system** unlocked through incantations at the Crossroads Cauldron.

> **Want immediate access?** Set `SkipIncantations` to `true` in the configuration to bypass all incantations and enable full mod functionality (all slots, unlimited stacking) from the start.

### Slot Unlocks
Each slot can be unlocked independently using boss materials:
-   **Superposition of Essence** (Magick) – 1 Cinder
-   **Superposition of Momentum** (Sprint) – 1 Pearl
-   **Superposition of Binding** (Cast) – 1 Wool
-   **Superposition of Finesse** (Special) – 1 Tears
-   **Superposition of Ferocity** (Attack) – 1 Golden Apple

Incantations appear once you've discovered the required material.

### Stack Limits
By default, each unlocked slot allows **2 stacked boons**. You can increase this:
-   **Rite of Triple Capacity** (2→3) – 1 Eagle's Feather
-   **Rite of Quadruple Capacity** (3→4) – 1 Zodiac Sand
-   **Rite of Infinite Capacity** (unlimited) – 1 Void Lens

## Configuration

You can adjust the mod's behavior by editing `config.lua` (if manually installed) or using the Config Editor in r2modman.

-   `SkipIncantations` (Default: `false`)
    -   **True**: Full mod functionality is active immediately—all slots unlocked, unlimited stacking. No incantations appear.
    -   **False**: Use the progression system via incantations (recommended for balanced play).
-   `StackPenaltyScalar` (Default: `1.0`)
    -   Adjusts the probability penalty for finding stacked boons. Higher values make it harder to find 3rd/4th stacks. Set to `0.0` to disable.

## Installation

### Recommended: Mod Manager
The easiest way to install is using a mod manager like [r2modman](https://hades2.thunderstore.io/package/ebkr/r2modman/) or the Thunderstore Mod Manager.

### Manual Install
If you prefer to install manually, ensure you have the following dependencies installed in your `Hades II/Content/Mods` directory (or equivalent):

1.  [Hell2Modding](https://thunderstore.io/c/hades-ii/p/Hell2Modding/Hell2Modding/)
2.  [LuaENVY](https://thunderstore.io/c/hades-ii/p/LuaENVY/ENVY/)
3.  [Chalk](https://thunderstore.io/c/hades-ii/p/SGG_Modding/Chalk/)
4.  [ReLoad](https://thunderstore.io/c/hades-ii/p/SGG_Modding/ReLoad/)
5.  [SJSON](https://thunderstore.io/c/hades-ii/p/SGG_Modding/SJSON/)
6.  [ModUtil](https://thunderstore.io/c/hades-ii/p/SGG_Modding/ModUtil/)
7.  [IncantationsAPI](https://thunderstore.io/c/hades-ii/p/BlueRaja/IncantationsAPI/)

Then, extract the `BoonStacker` folder into your `Mods` directory.

## Feedback

Please submit bug reports and feature requests via the [GitHub Issue Tracker](https://github.com/1andonlyWeaver/hades2-boon-stacker-mod/issues).

## License

MIT
