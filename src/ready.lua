---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload.lua`.

import 'BoonStacker.lua'
import 'incantation.lua'

-- Try multiple approaches for text modification

-- Approach 1: SJSON hook (if available)
if sjson and sjson.hook then
    local success, err = pcall(function()
        sjson.hook("Game/Text/en/HelpText.en.sjson", function(data)
            data.LimitedSwapTraitDrop = "Supplemental Hymn"
            data.LimitedSwapBonusTrait = "Supplemental Hymn"
            print("BoonStacker: Applied SJSON text modifications")
            return data
        end)
    end)
    if not success then
        print("BoonStacker: SJSON hook failed - " .. tostring(err))
    end
end

-- Approach 2: Direct modutil data modification (if ConsumableData exists)
modutil.once_loaded.game(function()
    -- Modify ConsumableData if it exists
    if game.ConsumableData and game.ConsumableData.LimitedSwapTraitDrop then
        -- Try to set a custom name property
        game.ConsumableData.LimitedSwapTraitDrop.CustomName = "Supplemental Hymn"
        print("BoonStacker: Modified ConsumableData.LimitedSwapTraitDrop")
    end
    
    -- Modify TraitData if it exists
    if game.TraitData and game.TraitData.LimitedSwapBonusTrait then
        game.TraitData.LimitedSwapBonusTrait.CustomName = "Supplemental Hymn"
        print("BoonStacker: Modified TraitData.LimitedSwapBonusTrait")
    end
end)

