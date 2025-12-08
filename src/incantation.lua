---@meta _
-- incantation registration
---@diagnostic disable: lowercase-global

---@module 'BlueRaja-IncantationsAPI'
local mods = rom.mods
Incantations = mods['BlueRaja-IncantationsAPI']

-- ============================================================================
-- PROGRESSION CONFIGURATION
-- ============================================================================

-- Slot unlock order (Magick first, Attack last)
-- Costs are boss/guardian rewards in progression order
local slotProgression = {
    { 
        id = "BoonStacker_Slot_Mana", 
        slot = "Mana", 
        displayName = "Magick",
        name = "Layering of Mana Flows",
        description = "Permits multiple {#Emph}Magick Blessings{#Prev} to inhabit the same ability slot, removing the need to Replace them.",
        flavorText = "Let the power flow through many channels at once.",
        cost = { MixerFBoss = 1 }, -- Cinder (Hecate/Erebus Guardian)
        requires = nil,
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
    },
    { 
        id = "BoonStacker_Slot_Rush", 
        slot = "Rush", 
        displayName = "Sprint",
        name = "Layering of Swift Strides",
        description = "Permits multiple {#Emph}Sprint Blessings{#Prev} to inhabit the same ability slot, removing the need to Replace them.",
        flavorText = "Run with the speed of many gods.",
        cost = { MixerGBoss = 1 }, -- Pearl (Scylla/Oceanus Guardian)
        requires = nil,
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
    },
    { 
        id = "BoonStacker_Slot_Ranged", 
        slot = "Ranged", 
        displayName = "Cast",
        name = "Layering of Distant Stars",
        description = "Permits multiple {#Emph}Cast Blessings{#Prev} to inhabit the same ability slot, removing the need to Replace them.",
        flavorText = "Cast forth the light of many heavens.",
        cost = { MixerNBoss = 1 }, -- Wool (City of Ephyra Guardian)
        requires = nil,
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
    },
    { 
        id = "BoonStacker_Slot_Secondary", 
        slot = "Secondary", 
        displayName = "Special",
        name = "Layering of Hidden Arts",
        description = "Permits multiple {#Emph}Special Blessings{#Prev} to inhabit the same ability slot, removing the need to Replace them.",
        flavorText = "Master the secret techniques of the divine.",
        cost = { MixerHBoss = 1 }, -- Tears (Mourning Fields Guardian)
        requires = nil,
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
    },
    { 
        id = "BoonStacker_Slot_Melee", 
        slot = "Melee", 
        displayName = "Attack",
        name = "Layering of Raw Force",
        description = "Permits multiple {#Emph}Attack Blessings{#Prev} to inhabit the same ability slot, removing the need to Replace them.",
        flavorText = "Strike with the fury of all Olympus combined.",
        cost = { MixerOBoss = 1 }, -- Golden Apple (Rift of Thessaly Guardian)
        requires = nil,
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
    },
}

-- Stack limit upgrades (2 -> 3 -> 4 -> unlimited)
-- Uses later-game boss drops that aren't used for slot unlocks
local stackLimitProgression = {
    {
        id = "BoonStacker_Stack_Limit_3",
        name = "Expansion of Divine Capacity I",
        description = "Increases the maximum number of Blessings that can occupy each ability slot from {#Emph}2{#Prev} to {#Emph}3{#Prev}.",
        flavorText = "The cauldron grows to hold more blessings.",
        cost = { MixerPBoss = 1 }, -- Eagle's Feather
        requires = nil, -- No prerequisite

        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_blessing",
    },
    {
        id = "BoonStacker_Stack_Limit_4",
        name = "Expansion of Divine Capacity II",
        description = "Increases the maximum number of Blessings that can occupy each ability slot from {#Emph}3{#Prev} to {#Emph}4{#Prev}.",
        flavorText = "The boundaries of mortal power stretch further.",
        cost = { MixerIBoss = 1 }, -- Zodiac Sand (Chronos/Tartarus Guardian)
        requires = "BoonStacker_Stack_Limit_3",
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_blessing",
    },
    {
        id = "BoonStacker_Stack_Unlimited",
        name = "Transcendence of Divine Limits",
        description = "Removes all limits on the number of Blessings that can occupy each ability slot. {#Emph}Stack without bounds.{#Prev}",
        flavorText = "I will not quiet the thunder to hear the sea. Let them crash together.",
        cost = { MixerQBoss = 1 }, -- Void Lens (Chaos/Final boss)
        requires = "BoonStacker_Stack_Limit_4",
        icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_blessing",
    },
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Build GameStateRequirements for a slot unlock
local function BuildSlotRequirements(slotData)
    local requirements = {}
    
    -- Require that the player has discovered the material used for this incantation
    for resourceId, _ in pairs(slotData.cost) do
        table.insert(requirements, {
            Path = { "GameState", "LifetimeResourcesGained", resourceId },
            Comparison = ">=",
            Value = 1,
        })
    end
    
    if slotData.requires then
        table.insert(requirements, {
            PathTrue = { "GameState", "WorldUpgrades", slotData.requires },
        })
    end
    
    return requirements
end

-- Build GameStateRequirements for a stack limit upgrade
local function BuildStackLimitRequirements(limitData)
    local requirements = {}
    
    -- Require that the player has discovered the material used for this incantation
    for resourceId, _ in pairs(limitData.cost) do
        table.insert(requirements, {
            Path = { "GameState", "LifetimeResourcesGained", resourceId },
            Comparison = ">=",
            Value = 1,
        })
    end
    
    if limitData.requires then
        table.insert(requirements, {
            PathTrue = { "GameState", "WorldUpgrades", limitData.requires },
        })
    end
    
    return requirements
end

-- OnEnabled callback for slot unlocks
local function OnSlotUnlocked(source, incantationId, slotName)
    print("BoonStacker: Slot '" .. slotName .. "' unlocked via " .. source)
    if BoonStacker and BoonStacker.RefreshLogic then
        BoonStacker.RefreshLogic()
    end
end

-- OnEnabled callback for stack limit upgrades
local function OnStackLimitUpgraded(source, incantationId, newLimit)
    local limitStr = newLimit and tostring(newLimit) or "unlimited"
    print("BoonStacker: Stack limit upgraded to " .. limitStr .. " via " .. source)
    -- No need to refresh logic, limits are checked dynamically
end

-- ============================================================================
-- INCANTATION REGISTRATION
-- ============================================================================

-- Note: Backwards compatibility is automatic - users with old BoonStacker_Unlock
-- are detected by BoonStacker.IsLegacyUser() and get full access without any migration

-- Only register incantations if not skipped via config
if not (config and config.SkipIncantations) then
    
    -- Register slot unlock incantations
    for i, slotData in ipairs(slotProgression) do
        local slotName = slotData.slot
        Incantations.addIncantation({
            Id = slotData.id,
            Name = slotData.name,
            Description = slotData.description,
            FlavorText = slotData.flavorText,
            WorldUpgradeData = {
                Icon = slotData.icon,
                Cost = slotData.cost,
                GameStateRequirements = BuildSlotRequirements(slotData),
                IncantationVoiceLines = {
                    {
                        PreLineWait = 0.3,
                        { Cue = "/VO/Melinoe_5611", Text = "{#Emph}Gods and Goddesses upon Olympus, fight!" },
                    },
                },
            },
            OnEnabled = function(source, incantationId)
                OnSlotUnlocked(source, incantationId, slotName)
            end,
        })
        print("BoonStacker: Registered slot unlock incantation: " .. slotData.id)
    end
    
    -- Register stack limit upgrade incantations
    for i, limitData in ipairs(stackLimitProgression) do
        local newLimit = nil
        if limitData.id == "BoonStacker_Stack_Limit_3" then
            newLimit = 3
        elseif limitData.id == "BoonStacker_Stack_Limit_4" then
            newLimit = 4
        else
            newLimit = nil -- unlimited
        end
        
        Incantations.addIncantation({
            Id = limitData.id,
            Name = limitData.name,
            Description = limitData.description,
            FlavorText = limitData.flavorText,
            WorldUpgradeData = {
                Icon = limitData.icon,
                Cost = limitData.cost,
                GameStateRequirements = BuildStackLimitRequirements(limitData),
                IncantationVoiceLines = {
                    {
                        PreLineWait = 0.3,
                        { Cue = "/VO/Melinoe_4825", Text = "{#Emph}Boil, Tears of Sorrow, and return to your essential form." },
                    },
                },
            },
            OnEnabled = function(source, incantationId)
                OnStackLimitUpgraded(source, incantationId, newLimit)
            end,
        })
        print("BoonStacker: Registered stack limit incantation: " .. limitData.id)
    end
    
    print("BoonStacker: All incantations registered successfully!")
end
