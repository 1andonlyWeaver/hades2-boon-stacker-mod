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
-- The TraitText.en.sjson uses an array of objects with Id, DisplayName, Description
local supplementalHymnName = "Supplemental Hymn"
local supplementalHymnDesc = "Stackable Boons will be offered as soon as possible, and your next gains {#AltUpgradeFormat}+{$TraitData.LimitedSwapBonusTrait.ExchangeLevelBonus}{#Prev} {$Keywords.PomLevel}"

-- Hook into TraitText.en.sjson (where trait/item names are stored)
sjson.hook("Game/Text/en/TraitText.en.sjson", function(data)
    -- Iterate through all entries to find our target IDs
    for _, entry in ipairs(data) do
        if entry.Id == "LimitedSwapTraitDrop" then
            entry.DisplayName = supplementalHymnName
            entry.Description = supplementalHymnDesc
            print("BoonStacker: Modified LimitedSwapTraitDrop text")
        elseif entry.Id == "LimitedSwapBonusTrait" then
            -- This one inherits from LimitedSwapTraitDrop, but set explicitly to be safe
            entry.DisplayName = supplementalHymnName
            print("BoonStacker: Modified LimitedSwapBonusTrait text")
        end
    end
    return data
end)

