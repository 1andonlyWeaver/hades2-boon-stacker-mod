---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload.lua`.

import 'BoonStacker.lua'
import 'incantation.lua'

-- Supplemental Hymn text modifications using SJSON hooks
-- The text might be in different files, so we hook multiple
local supplementalHymnName = "Supplemental Hymn"
local supplementalHymnDesc = "Stackable Boons will be offered as soon as possible, and your next gains +2 Lv."

-- Hook into TraitText.en.sjson (where trait/item names are stored)
sjson.hook("Game/Text/en/TraitText.en.sjson", function(data)
    -- Try various possible key formats
    data.LimitedSwapTraitDrop = supplementalHymnName
    data.LimitedSwapBonusTrait = supplementalHymnName
    -- Also try with _Short suffix for descriptions
    data.LimitedSwapTraitDrop_Short = supplementalHymnDesc
    data.LimitedSwapBonusTrait_Short = supplementalHymnDesc
    print("BoonStacker: Applied TraitText SJSON modifications")
    return data
end)

-- Hook into HelpText.en.sjson as backup
sjson.hook("Game/Text/en/HelpText.en.sjson", function(data)
    data.LimitedSwapTraitDrop = supplementalHymnName
    data.LimitedSwapBonusTrait = supplementalHymnName
    data.LimitedSwapTraitDrop_Short = supplementalHymnDesc
    data.LimitedSwapBonusTrait_Short = supplementalHymnDesc
    print("BoonStacker: Applied HelpText SJSON modifications")
    return data
end)

