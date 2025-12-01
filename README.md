# BoonStacker

**BoonStacker** is a Hades II mod that fundamentally changes the boon system by allowing you to **stack** boons on your core slots (Attack, Special, Cast, Sprint, Magick) instead of replacing them.

> **Disclaimer**: This mod significantly alters the game's balance. Stacking multiple gods' effects on a single move can lead to extremely powerful combinations.

For players seeking a more "earned" progression, this mod is integrated into the game's incantation system. You can disable `EasyUnlock` in the config file to require endgame materials, treating it as a powerful mid-to-late game upgrade rather than a default capability.

## Features

-   **Boon Stacking**: You can now accept new boons for your Attack, Special, Cast, Sprint, and Magick slots even if they are already filled. The new boon will be added alongside the existing one.
-   **No Replacements**: "Swap" or "Replace" offers are disabled for these slots. You will simply add to your arsenal.
-   **Probability Balancing**: To keep things somewhat grounded, the probability of finding a boon for a specific slot decreases slightly as you stack more boons into that slot.

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

## How to Use

Installing the mod does not enable its effects immediately. You must unlock it within the game at the Crossroads Cauldron.

1.  **Superposition of Divine Favor**: Perform this incantation to enable Boon Stacking.
    *   *Cost (Default)*: 1 Moly
2.  **Separation of Divine Favor**: If you wish to disable the mod's effects and return to standard rules, perform this incantation. It will refund the materials used for the unlock.

## Configuration

You can adjust the mod's behavior by editing `config.lua` (if manually installed) or using the Config Editor in r2modman.

-   `EasyUnlock` (Default: `true`)
    -   **True**: The incantation costs **1 Moly**. Useful for immediate access or testing.
    -   **False**: The incantation costs **1 Zodiac Sand** and **1 Void Lens**. This setting is intended for a balanced playthrough where this ability is treated as a significant mid-game upgrade that must be earned.
-   `StackPenaltyScalar` (Default: `1.0`)
    -   Adjusts the probability penalty for finding stacked boons. Higher values make it harder to find 3rd/4th stacks for the same slot. Set it to `0.0` for no penalization.

## License

MIT
