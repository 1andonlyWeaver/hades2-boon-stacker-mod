---@meta _
-- Boon Stacker Logic

BoonStacker = public.BoonStacker or {}
public.BoonStacker = BoonStacker

-- All possible stackable slots (in unlock order: Magick first, Attack last)
local allStackableSlots = {"Mana", "Rush", "Ranged", "Secondary", "Melee"}

-- Slot display names for UI
local slotDisplayNames = {
    Mana = "Magick",
    Rush = "Sprint",
    Ranged = "Cast",
    Secondary = "Special",
    Melee = "Attack"
}

-- Progression state (persisted via WorldUpgrades)
-- These are the incantation IDs that correspond to each unlock
local slotUnlockIds = {
    Mana = "BoonStacker_Slot_Mana",
    Rush = "BoonStacker_Slot_Rush",
    Ranged = "BoonStacker_Slot_Ranged",
    Secondary = "BoonStacker_Slot_Secondary",
    Melee = "BoonStacker_Slot_Melee"
}

local stackLimitIds = {
    "BoonStacker_Stack_Limit_3",   -- Upgrades limit to 3
    "BoonStacker_Stack_Limit_4",   -- Upgrades limit to 4
    "BoonStacker_Stack_Unlimited"  -- Removes limit entirely
}

-- Default stack limit when a slot is first unlocked
local DEFAULT_STACK_LIMIT = 2

-- Build priority slots based on config (which slots get guaranteed offers when empty)
local function GetPrioritySlots()
    local slots = {}
    if config and config.PrioritizeAttack then
        table.insert(slots, "Melee")
    end
    if config and config.PrioritizeSpecial then
        table.insert(slots, "Secondary")
    end
    if config and config.PrioritizeCast then
        table.insert(slots, "Ranged")
    end
    if config and config.PrioritizeSprint then
        table.insert(slots, "Rush")
    end
    if config and config.PrioritizeMagick then
        table.insert(slots, "Mana")
    end
    return slots
end

-- Supplemental Hymn state tracking
-- When ForceSwaps trait is active and BoonStacker is unlocked, we repurpose it
-- to prioritize stackable boons (boons in already-filled slots) with +2 level bonus
BoonStacker.SupplementalHymnActive = false
BoonStacker.SupplementalHymnLevelBonus = 0

-- Capture originals
-- We use a check to avoid re-capturing our own wrappers on reload if this file is re-run without a clean state
if not BoonStacker.Originals then
    BoonStacker.Originals = {
        GetPriorityTraits = game.GetPriorityTraits,
        GetReplacementTraits = game.GetReplacementTraits,
        HeroSlotFilled = game.HeroSlotFilled,
        IsShownInHUD = game.IsShownInHUD,
        TraitUIAdd = game.TraitUIAdd,
        TraitUIRemove = game.TraitUIRemove,
        ShowTraitUI = game.ShowTraitUI,
        GetEligibleUpgrades = game.GetEligibleUpgrades,
        Load = game.Load,
        StartNewGame = game.StartNewGame,
        AddTraitToHero = game.AddTraitToHero
    }
end

local originals = public.BoonStacker.Originals

-- ============================================================================
-- PROGRESSION SYSTEM FUNCTIONS
-- ============================================================================

-- Check if mod should skip incantations entirely (config option)
function public.BoonStacker.ShouldSkipIncantations()
    return config and config.SkipIncantations
end

-- Check if user has the legacy unlock (old single incantation system)
function public.BoonStacker.IsLegacyUser()
    -- If migration completed, treat as non-legacy even if old flag exists
    if public.BoonStacker.HasLegacyMigration() then
        return false
    end
    if game.GameState and game.GameState.WorldUpgrades and game.GameState.WorldUpgrades.BoonStacker_Unlock then
        return true
    end
    return false
end

-- Check if user has completed the legacy migration
function public.BoonStacker.HasLegacyMigration()
    if game.GameState and game.GameState.WorldUpgrades and game.GameState.WorldUpgrades.BoonStacker_Legacy_Migration then
        return true
    end
    return false
end

-- Check if user has the old legacy unlock flag (regardless of migration status)
-- Used by migration incantation to determine visibility
function public.BoonStacker.HasOldLegacyUnlock()
    if game.GameState and game.GameState.WorldUpgrades and game.GameState.WorldUpgrades.BoonStacker_Unlock then
        return true
    end
    return false
end

-- Perform migration from legacy system to new progression system
function public.BoonStacker.PerformLegacyMigration()
    if game.GameState and game.GameState.WorldUpgrades then
        -- Set migration flag
        game.GameState.WorldUpgrades.BoonStacker_Legacy_Migration = true
        -- Note: We keep BoonStacker_Unlock for historical record, IsLegacyUser() now checks migration flag first
        -- Refresh logic to use new progression state
        public.BoonStacker.RefreshLogic()
        print("BoonStacker: Legacy migration completed - new progression system now active")
    end
end

-- Check if a specific slot is unlocked for stacking
function public.BoonStacker.IsSlotUnlocked(slotName)
    -- Skip incantations means all slots are unlocked
    if public.BoonStacker.ShouldSkipIncantations() then
        return true
    end
    
    -- Legacy users with migration have all slots unlocked
    if public.BoonStacker.IsLegacyUser() or public.BoonStacker.HasLegacyMigration() then
        return true
    end
    
    -- Check if the specific slot's incantation has been purchased
    local incantationId = slotUnlockIds[slotName]
    if incantationId and game.GameState and game.GameState.WorldUpgrades and game.GameState.WorldUpgrades[incantationId] then
        return true
    end
    
    return false
end

-- Get list of currently unlocked stackable slots
function public.BoonStacker.GetUnlockedSlots()
    local unlocked = {}
    for _, slot in ipairs(allStackableSlots) do
        if public.BoonStacker.IsSlotUnlocked(slot) then
            table.insert(unlocked, slot)
        end
    end
    return unlocked
end

-- Check if ANY slot is unlocked (replaces old IsUnlocked for backwards compat)
function public.BoonStacker.IsUnlocked()
    if public.BoonStacker.ShouldSkipIncantations() then
        return true
    end
    if public.BoonStacker.IsLegacyUser() or public.BoonStacker.HasLegacyMigration() then
        return true
    end
    -- Check if any slot is unlocked
    for _, slot in ipairs(allStackableSlots) do
        if public.BoonStacker.IsSlotUnlocked(slot) then
            return true
        end
    end
    return false
end

-- Get the current stack limit for all slots (global limit)
function public.BoonStacker.GetStackLimit()
    -- Skip incantations means unlimited
    if public.BoonStacker.ShouldSkipIncantations() then
        return nil -- nil means unlimited
    end
    
    -- Legacy users have unlimited
    if public.BoonStacker.IsLegacyUser() or public.BoonStacker.HasLegacyMigration() then
        return nil
    end
    
    if not game.GameState or not game.GameState.WorldUpgrades then
        return DEFAULT_STACK_LIMIT
    end
    
    -- Check stack limit upgrades in reverse order (highest first)
    if game.GameState.WorldUpgrades.BoonStacker_Stack_Unlimited then
        return nil -- unlimited
    elseif game.GameState.WorldUpgrades.BoonStacker_Stack_Limit_4 then
        return 4
    elseif game.GameState.WorldUpgrades.BoonStacker_Stack_Limit_3 then
        return 3
    else
        return DEFAULT_STACK_LIMIT
    end
end

-- Count how many boons are currently stacked in a slot
function public.BoonStacker.GetCurrentStackCount(slotName)
    local count = 0
    local hero = game.CurrentRun and game.CurrentRun.Hero
    if hero and hero.Traits then
        for _, trait in pairs(hero.Traits) do
            if trait.Name then
                local tData = game.TraitData[trait.Name]
                if tData then
                    local slot = tData.Slot or tData.OriginalSlot
                    if slot == slotName then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- Check if a slot can accept more stacked boons
function public.BoonStacker.CanStackMore(slotName)
    if not public.BoonStacker.IsSlotUnlocked(slotName) then
        return false
    end
    
    local limit = public.BoonStacker.GetStackLimit()
    if limit == nil then
        return true -- unlimited
    end
    
    local currentCount = public.BoonStacker.GetCurrentStackCount(slotName)
    return currentCount < limit
end

-- Get dynamically filtered stackable slots (only those unlocked)
local function GetStackableSlots()
    return public.BoonStacker.GetUnlockedSlots()
end

-- ============================================================================
-- CORE LOGIC (EnableLogic/DisableLogic)
-- ============================================================================

function public.BoonStacker.EnableLogic()
    if not game.TraitData then return end
    local unlockedSlots = GetStackableSlots()
    print("BoonStacker: Enabling Logic for " .. #unlockedSlots .. " unlocked slots")
    
    for name, trait in pairs(game.TraitData) do
        if trait.Slot and game.Contains(unlockedSlots, trait.Slot) then
            trait.OriginalSlot = trait.Slot
            trait.Slot = nil
        end
    end
end

function public.BoonStacker.DisableLogic()
    if not game.TraitData then return end
    print("BoonStacker: Disabling Logic (restoring TraitData)")
    for name, trait in pairs(game.TraitData) do
        if trait.OriginalSlot then
            trait.Slot = trait.OriginalSlot
        end
    end
end

-- Refresh logic when progression changes (e.g., new slot unlocked)
function public.BoonStacker.RefreshLogic()
    -- Restore all slots first
    public.BoonStacker.DisableLogic()
    -- Then re-enable for currently unlocked slots
    if public.BoonStacker.IsUnlocked() then
        public.BoonStacker.EnableLogic()
    end
end

-- Initial check on load
if public.BoonStacker.IsUnlocked() then
    public.BoonStacker.EnableLogic()
else
    public.BoonStacker.DisableLogic()
end

-- Override Load to check status on save load
function game.Load( data )
    originals.Load(data)
    -- Reset Supplemental Hymn state on load
    BoonStacker.SupplementalHymnActive = false
    BoonStacker.SupplementalHymnLevelBonus = 0
    
    if public.BoonStacker.IsUnlocked() then
        public.BoonStacker.EnableLogic()
    else
        public.BoonStacker.DisableLogic()
    end
end

-- Override StartNewGame to reset/check status
function game.StartNewGame( mapName )
    originals.StartNewGame(mapName)
    -- Reset Supplemental Hymn state on new game
    BoonStacker.SupplementalHymnActive = false
    BoonStacker.SupplementalHymnLevelBonus = 0
    
    if public.BoonStacker.IsUnlocked() then
        public.BoonStacker.EnableLogic()
    else
        public.BoonStacker.DisableLogic()
    end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Helper: Calculate slot counts for existing traits in unlocked slots
local function CalculateSlotCounts()
    local slotCounts = {}
    local hero = game.CurrentRun and game.CurrentRun.Hero
    local unlockedSlots = GetStackableSlots()
    
    if hero and hero.Traits then
        for _, trait in pairs(hero.Traits) do
            if trait.Name then
                local tData = game.TraitData[trait.Name]
                if tData then
                    local slot = tData.Slot or tData.OriginalSlot
                    if slot then
                        for _, gSlot in ipairs(unlockedSlots) do
                            if gSlot == slot then
                                slotCounts[slot] = (slotCounts[slot] or 0) + 1
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return slotCounts
end

-- Helper: Calculate weights for a list of trait options based on slot occupancy
-- Returns weights table and hasAnyPenalty flag
local function CalculateWeightsForOptions(options, slotCounts, logPrefix)
    local weights = {}
    local hasAnyPenalty = false
    local scalar = (config and config.StackPenaltyScalar) or 1.0
    
    logPrefix = logPrefix or "BoonStacker"
    print(logPrefix .. ": Calculating weights (Scalar: " .. scalar .. "):")
    
    for i, option in ipairs(options) do
        local weight = 1.0  -- default weight (no penalty)
        local traitName = option.ItemName or option
        local traitData = game.TraitData[traitName]
        local slotName = nil
        
        if traitData then
            local slot = traitData.Slot or traitData.OriginalSlot
            slotName = slot
            if slot and slotCounts[slot] and slotCounts[slot] > 0 then
                -- Check if we can stack more in this slot
                if not public.BoonStacker.CanStackMore(slot) then
                    -- At limit, set weight to 0 to exclude
                    weight = 0
                    hasAnyPenalty = true
                else
                    -- Calculate weight: 1 / (1 + (count * scalar))
                    weight = 1.0 / (1 + (slotCounts[slot] * scalar))
                    hasAnyPenalty = true
                end
            end
        end
        weights[i] = weight
        local slotStr = slotName or "none"
        local penaltyStr = (weight < 1.0) and " [PENALIZED]" or ""
        if weight == 0 then penaltyStr = " [EXCLUDED - AT LIMIT]" end
        print("  " .. i .. ". " .. tostring(traitName) .. " (slot: " .. slotStr .. ") -> weight: " .. string.format("%.3f", weight) .. penaltyStr)
    end
    
    return weights, hasAnyPenalty
end

-- Weighted random selection without replacement
-- Selects 'count' items from 'options' based on their weights
local function WeightedSelectWithoutReplacement(options, weights, count, debugInfo)
    local selected = {}
    local remainingWeights = {}
    local totalWeight = 0
    
    -- Copy weights
    for i, w in ipairs(weights) do
        remainingWeights[i] = w
        totalWeight = totalWeight + w
    end
    
    print("BoonStacker: WeightedSelect - Total weight: " .. string.format("%.3f", totalWeight) .. ", Selecting " .. count .. " items")
    
    -- Select 'count' items
    for j = 1, count do
        if totalWeight <= 0 then break end
        
        local roll = game.RandomNumber() * totalWeight
        local cumulative = 0
        
        for i, option in ipairs(options) do
            if remainingWeights[i] and remainingWeights[i] > 0 then
                cumulative = cumulative + remainingWeights[i]
                if roll <= cumulative then
                    table.insert(selected, option)
                    local itemName = option.ItemName or "Unknown"
                    local itemWeight = weights[i] or 0
                    print("BoonStacker: WeightedSelect [" .. j .. "] Selected '" .. itemName .. "' (weight: " .. string.format("%.3f", itemWeight) .. ", roll: " .. string.format("%.3f", roll) .. "/" .. string.format("%.3f", totalWeight) .. ")")
                    totalWeight = totalWeight - remainingWeights[i]
                    remainingWeights[i] = 0
                    break
                end
            end
        end
    end
    
    return selected
end

-- ============================================================================
-- GAME FUNCTION OVERRIDES
-- ============================================================================

-- Override GetPriorityTraits
function game.GetPriorityTraits( traitNames, lootData, args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetPriorityTraits(traitNames, lootData, args)
    end

	print("BoonStacker:GetPriorityTraits - called with " .. (traitNames and #traitNames or 0) .. " trait names")
	if traitNames == nil or lootData == nil then
		return {}
	end
	args = args or {}

	local priorityOptions = {}
	local traitsWithGuaranteedSlot = {}
	local occupiedSlots = {}
    local unlockedSlots = GetStackableSlots()

    -- Robustly check for occupied slots
    local hero = game.CurrentRun and game.CurrentRun.Hero
    if hero and hero.Traits then
        for _, trait in pairs(hero.Traits) do
            if trait.Name then
                local tData = game.TraitData[trait.Name]
                if tData then
                    local slot = tData.Slot or tData.OriginalSlot
                    if slot then
                        for _, gSlot in ipairs(unlockedSlots) do
                            if gSlot == slot then
                                occupiedSlots[slot] = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

	for index, traitName in ipairs(traitNames) do
		local traitData = game.TraitData[traitName]
		if traitData and (lootData.StripRequirements or game.IsTraitEligible( traitData )) then
			if not game.HeroHasTrait(traitName) then
				local slot = traitData.Slot or traitData.OriginalSlot
                local isPrioritySlot = false
                local isUnlockedSlot = false
                
                if slot then
                    for _, pSlot in ipairs(GetPrioritySlots()) do
                        if pSlot == slot then isPrioritySlot = true break end
                    end
                    for _, uSlot in ipairs(unlockedSlots) do
                        if uSlot == slot then isUnlockedSlot = true break end
                    end
                end

                -- Only include PRIORITY SLOT boons that are in UNLOCKED slots
                -- AND only if their slot is still EMPTY (not yet filled)
                if isPrioritySlot and isUnlockedSlot and not occupiedSlots[slot] then
                    local data = { ItemName = traitName, Type = "Trait"}
                    table.insert(priorityOptions, data)
                    table.insert(traitsWithGuaranteedSlot, traitName)
                end
			end
		end
	end
	
	print("BoonStacker:GetPriorityTraits - Priority pool size: " .. #priorityOptions)

	-- Use weighted selection instead of uniform random removal
	local numToSelect = game.GetTotalLootChoices()
	if game.TableLength(priorityOptions) > numToSelect then
		local slotCounts = CalculateSlotCounts()
		local weights, hasAnyPenalty = CalculateWeightsForOptions(priorityOptions, slotCounts, "BoonStacker:GetPriorityTraits")
		
		if hasAnyPenalty then
			print("BoonStacker:GetPriorityTraits - Applying weighted selection (" .. #priorityOptions .. " -> " .. numToSelect .. ")")
			priorityOptions = WeightedSelectWithoutReplacement(priorityOptions, weights, numToSelect)
		else
			-- No penalties, use original random removal for efficiency
			print("BoonStacker:GetPriorityTraits - No penalties, using uniform random selection")
			while game.TableLength(priorityOptions) > numToSelect do
				game.RemoveRandomValue(priorityOptions)
				priorityOptions = game.CollapseTable(priorityOptions)
			end
		end
	end
	local hasGuarantee = false

	-- Log the final selected options
	print("BoonStacker:GetPriorityTraits - Final options after selection:")
	for i, option in ipairs(priorityOptions) do
		local traitData = game.TraitData[option.ItemName]
		if traitData then
			local slot = traitData.Slot or traitData.OriginalSlot
            local isPrioritySlot = false
            if slot then
                for _, pSlot in ipairs(GetPrioritySlots()) do
                    if pSlot == slot then isPrioritySlot = true break end
                end
            end
			local slotStatus = occupiedSlots[slot] and "OCCUPIED" or "empty"
			local priorityStr = isPrioritySlot and " [PRIORITY]" or ""
			print("  " .. i .. ". " .. option.ItemName .. " (slot: " .. tostring(slot) .. " " .. slotStatus .. ")" .. priorityStr)

			if isPrioritySlot and not occupiedSlots[slot] then
				hasGuarantee = true
			end
		end
	end
	
	print("BoonStacker:GetPriorityTraits - hasGuarantee: " .. tostring(hasGuarantee))
	print("BoonStacker:GetPriorityTraits - traitsWithGuaranteedSlot count: " .. #traitsWithGuaranteedSlot)

	if not hasGuarantee and not game.IsEmpty(traitsWithGuaranteedSlot) and not game.IsEmpty(priorityOptions) then
		local firstOption = priorityOptions[1]
		if firstOption then
			local validGuaranteedTraits = {}
			for _, traitName in ipairs(traitsWithGuaranteedSlot) do
				if not game.HeroHasTrait(traitName) then
					local traitData = game.TraitData[traitName]
					local slot = traitData and (traitData.Slot or traitData.OriginalSlot)
					if slot and not occupiedSlots[slot] then
						table.insert(validGuaranteedTraits, traitName)
					end
				end
			end
			if not game.IsEmpty(validGuaranteedTraits) then
				local originalName = firstOption.ItemName
				firstOption.ItemName = game.GetRandomValue( validGuaranteedTraits )
				print("BoonStacker:GetPriorityTraits - GUARANTEE SWAP: " .. originalName .. " -> " .. firstOption.ItemName)
			else
				print("BoonStacker:GetPriorityTraits - No valid guaranteed traits to swap (all priority slots occupied)")
			end
		end
	end
	return priorityOptions
end

-- Override GetReplacementTraits
function game.GetReplacementTraits( priorityUpgrades, ... )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetReplacementTraits(priorityUpgrades, ...)
    end
    
    local unlockedSlots = GetStackableSlots()
    
    -- Check for Supplemental Hymn (ForceSwaps trait) - repurposed for stacking
    local forceSwapTrait = game.HasHeroTraitValue("ForceSwaps")
    local supplementalHymnActive = forceSwapTrait and forceSwapTrait.Uses and forceSwapTrait.Uses > 0
    
    -- Reset any stale state unconditionally
    BoonStacker.SupplementalHymnActive = false
    BoonStacker.SupplementalHymnLevelBonus = 0

    if supplementalHymnActive and priorityUpgrades then
        -- Find occupied slots
        local occupiedSlots = {}
        local hero = game.CurrentRun and game.CurrentRun.Hero
        if hero and hero.Traits then
            for _, trait in pairs(hero.Traits) do
                if trait.Name then
                    local tData = game.TraitData[trait.Name]
                    if tData then
                        local slot = tData.Slot or tData.OriginalSlot
                        if slot then
                            for _, gSlot in ipairs(unlockedSlots) do
                                if gSlot == slot then
                                    occupiedSlots[slot] = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Find traits that would stack (in already-occupied slots)
        local stackableOptions = {}
        for _, traitName in ipairs(priorityUpgrades) do
            local traitData = game.TraitData[traitName]
            if traitData and game.IsTraitEligible(traitData) then
                if not game.HeroHasTrait(traitName) then
                    local slot = traitData.Slot or traitData.OriginalSlot
                    local isUnlockedSlot = false
                    if slot then
                        for _, gSlot in ipairs(unlockedSlots) do
                            if gSlot == slot then 
                                isUnlockedSlot = true 
                                break 
                            end
                        end
                    end
                    
                    -- Only include traits in OCCUPIED UNLOCKED slots (stackable) that can accept more
                    if isUnlockedSlot and occupiedSlots[slot] and public.BoonStacker.CanStackMore(slot) then
                        table.insert(stackableOptions, { ItemName = traitName, Type = "Trait" })
                    end
                end
            end
        end
        
        -- If we found stackable options, return them
        if not game.IsEmpty(stackableOptions) then
            -- Store state for level bonus application
            BoonStacker.SupplementalHymnActive = true
            BoonStacker.SupplementalHymnLevelBonus = (game.TraitData.LimitedSwapBonusTrait and game.TraitData.LimitedSwapBonusTrait.ExchangeLevelBonus) or 2
            
            print("BoonStacker:GetReplacementTraits - Supplemental Hymn active - found " .. tostring(#stackableOptions) .. " stackable options")
            
            -- Trim to max loot choices using weighted selection
            local numToSelect = game.GetTotalLootChoices()
            if game.TableLength(stackableOptions) > numToSelect then
                local slotCounts = CalculateSlotCounts()
                local weights, hasAnyPenalty = CalculateWeightsForOptions(stackableOptions, slotCounts, "BoonStacker:GetReplacementTraits")
                
                if hasAnyPenalty then
                    print("BoonStacker:GetReplacementTraits - Applying weighted selection (" .. #stackableOptions .. " -> " .. numToSelect .. ")")
                    stackableOptions = WeightedSelectWithoutReplacement(stackableOptions, weights, numToSelect)
                else
                    -- No penalties, use original random removal
                    print("BoonStacker:GetReplacementTraits - No penalties, using uniform random selection")
                    while game.TableLength(stackableOptions) > numToSelect do
                        game.RemoveRandomValue(stackableOptions)
                        stackableOptions = game.CollapseTable(stackableOptions)
                    end
                end
            end
            
            return stackableOptions
        else
            print("BoonStacker: Supplemental Hymn active but no stackable options found - no slots filled yet?")
        end
    end
    
    -- Default: block all replacements when BoonStacker is active
    return {}
end

-- Override GetEligibleUpgrades to reduce probability of stacked boons and enforce limits
function game.GetEligibleUpgrades( upgradeOptions, lootData, upgradeChoiceData )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetEligibleUpgrades(upgradeOptions, lootData, upgradeChoiceData)
    end

    -- If this is a StackOnly upgrade (like Pom of Power), use original logic immediately
    if lootData and lootData.StackOnly then
        return originals.GetEligibleUpgrades(upgradeOptions, lootData, upgradeChoiceData)
    end

    -- Get the original list of eligible upgrades
    local eligibleOptions = originals.GetEligibleUpgrades(upgradeOptions, lootData, upgradeChoiceData)
    
    -- Use helper functions for slot counts and weights
    local slotCounts = CalculateSlotCounts()
    
    -- Log slot counts
    print("BoonStacker:GetEligibleUpgrades - " .. #eligibleOptions .. " eligible options")
    for slot, count in pairs(slotCounts) do
        local limit = public.BoonStacker.GetStackLimit()
        local limitStr = limit and tostring(limit) or "unlimited"
        print("BoonStacker:GetEligibleUpgrades - Slot '" .. slot .. "' has " .. count .. " existing boon(s) (limit: " .. limitStr .. ")")
    end

    -- Calculate weights using helper function (this now respects stack limits)
    local weights, hasAnyPenalty = CalculateWeightsForOptions(eligibleOptions, slotCounts, "BoonStacker:GetEligibleUpgrades")

    -- Filter out options with 0 weight (at stack limit)
    local filteredOptions = {}
    for i, option in ipairs(eligibleOptions) do
        if weights[i] > 0 then
            table.insert(filteredOptions, option)
        end
    end
    
    if #filteredOptions < #eligibleOptions then
        print("BoonStacker:GetEligibleUpgrades - Filtered out " .. (#eligibleOptions - #filteredOptions) .. " options at stack limit")
        eligibleOptions = filteredOptions
        
        -- Recalculate weights for remaining options
        weights, hasAnyPenalty = CalculateWeightsForOptions(eligibleOptions, slotCounts, "BoonStacker:GetEligibleUpgrades (post-filter)")
    end

    -- If no penalties apply, return list unchanged
    if not hasAnyPenalty then
        print("BoonStacker:GetEligibleUpgrades - No penalties apply, returning list")
        return eligibleOptions
    end

    -- Use weighted selection to pick boons for the pool
    local numToSelect = #eligibleOptions
    print("BoonStacker:GetEligibleUpgrades - Applying weighted selection...")
    local finalOptions = WeightedSelectWithoutReplacement(eligibleOptions, weights, numToSelect)
    
    print("BoonStacker:GetEligibleUpgrades - Weighted selection complete, " .. #finalOptions .. " options in final pool")

    return finalOptions
end

-- Override AddTraitToHero to apply Supplemental Hymn level bonus
function game.AddTraitToHero( args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.AddTraitToHero(args)
    end
    
    local unlockedSlots = GetStackableSlots()
    
    -- Check if Supplemental Hymn is active and should apply level bonus
    if BoonStacker.SupplementalHymnActive and BoonStacker.SupplementalHymnLevelBonus > 0 then
        -- Capture bonus before reset
        local levelBonus = BoonStacker.SupplementalHymnLevelBonus
        
        -- Reset state unconditionally to ensure it's consumed by this call
        BoonStacker.SupplementalHymnActive = false
        BoonStacker.SupplementalHymnLevelBonus = 0
        
        local traitData = args.TraitData
        if traitData then
            local slot = traitData.Slot or traitData.OriginalSlot
            local isUnlockedSlot = false
            if slot then
                for _, gSlot in ipairs(unlockedSlots) do
                    if gSlot == slot then 
                        isUnlockedSlot = true 
                        break 
                    end
                end
            end
            
            -- Only apply bonus to boons in unlocked slots (the stackable ones)
            if isUnlockedSlot then
                local currentStackNum = traitData.StackNum or 1
                local newStackNum = currentStackNum + levelBonus
                traitData.StackNum = newStackNum
                print("BoonStacker: Supplemental Hymn applied +" .. tostring(levelBonus) .. " levels to " .. tostring(traitData.Name) .. " (now level " .. tostring(newStackNum) .. ")")
            end
        end
    end
    
    return originals.AddTraitToHero(args)
end

-- Override HeroSlotFilled
function game.HeroSlotFilled( slotName, ... )
    if not public.BoonStacker.IsUnlocked() then
        return originals.HeroSlotFilled(slotName, ...)
    end
    
    local unlockedSlots = GetStackableSlots()

	if game.Contains(unlockedSlots, slotName) then
		-- Check if we can stack more
		if public.BoonStacker.CanStackMore(slotName) then
			return false
		else
			-- At limit, report as filled
			return true
		end
	end
	return originals.HeroSlotFilled( slotName, ... )
end

-- ============================================================================
-- UI OVERRIDES
-- ============================================================================

game.BoonStacker_StackedTraits = {}
game.BoonStacker_CurrentTraitIndex = {}

local function GetTraitSlot(trait)
	return trait.Slot or trait.OriginalSlot
end

local function IsHudSlot(slot)
	if not slot then return false end
	return game.ScreenData and game.ScreenData.HUD and game.ScreenData.HUD.SlottedTraitOrder 
		and game.Contains(game.ScreenData.HUD.SlottedTraitOrder, slot)
end

function game.IsShownInHUD( trait )
    if not public.BoonStacker.IsUnlocked() then
        return originals.IsShownInHUD(trait)
    end

	if trait.Hidden then
		return false
	end
	local slot = GetTraitSlot(trait)
	if IsHudSlot(slot) then
		-- Check if trait is stacked and NOT the current/oldest one
		if game.BoonStacker_StackedTraits[slot] then
			local currentIndex = game.BoonStacker_CurrentTraitIndex[slot] or 1
			for i, t in ipairs(game.BoonStacker_StackedTraits[slot]) do
				if t == trait then
					if i ~= currentIndex then
						return false
					end
					break
				end
			end
		end

		local prevSlot = trait.Slot
		trait.Slot = slot
		local isShown = originals.IsShownInHUD(trait)
		trait.Slot = prevSlot
		return isShown
	end
	return originals.IsShownInHUD( trait )
end

function game.TraitUIAdd( trait, args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.TraitUIAdd(trait, args)
    end

	local slot = GetTraitSlot(trait)
	
	if IsHudSlot(slot) then
		if not game.BoonStacker_StackedTraits[slot] then
			game.BoonStacker_StackedTraits[slot] = {}
		end
		
		local found = false
		for _, t in ipairs(game.BoonStacker_StackedTraits[slot]) do
			if t == trait then found = true break end
		end
		if not found then
			table.insert(game.BoonStacker_StackedTraits[slot], trait)
		end
		
		if game.BoonStacker_CurrentTraitIndex[slot] == nil or game.BoonStacker_CurrentTraitIndex[slot] < 1 or game.BoonStacker_CurrentTraitIndex[slot] > #game.BoonStacker_StackedTraits[slot] then
			game.BoonStacker_CurrentTraitIndex[slot] = 1
		end
		
		local currentIndex = game.BoonStacker_CurrentTraitIndex[slot]
		local currentTrait = game.BoonStacker_StackedTraits[slot][currentIndex]
		
		if currentTrait and trait == currentTrait then
			local prevSlot = trait.Slot
			trait.Slot = slot
			local status, result = pcall(originals.TraitUIAdd, trait, args)
			trait.Slot = prevSlot
			
			if not status then
				print("BS_DEBUG: Error adding trait UI: " .. tostring(result))
				error(result)
			end
			
			return result
		end
        -- Do not show stacked traits (Oldest remains shown)
		return nil
	end
	
	local prevSlot = trait.Slot
	if trait.OriginalSlot and not trait.Slot then
		trait.Slot = trait.OriginalSlot
		local status, result = pcall(originals.TraitUIAdd, trait, args)
		trait.Slot = prevSlot
		
		if not status then
			print("BS_DEBUG: Error in fallback TraitUIAdd: " .. tostring(result))
			error(result)
		end
		
		return result
	end
	
	return originals.TraitUIAdd( trait, args )
end

function game.TraitUIRemove( trait )
    if not public.BoonStacker.IsUnlocked() then
        return originals.TraitUIRemove(trait)
    end

	local slot = GetTraitSlot(trait)
	if IsHudSlot(slot) then
        local wasCurrent = false
		if game.BoonStacker_StackedTraits[slot] then
			for i, t in ipairs(game.BoonStacker_StackedTraits[slot]) do
				if t == trait then
                    local currentIndex = game.BoonStacker_CurrentTraitIndex[slot] or 1
                    if i == currentIndex then 
						wasCurrent = true 
					elseif i < currentIndex then
						-- If we remove an item before the current index, shift current index down
						game.BoonStacker_CurrentTraitIndex[slot] = currentIndex - 1
					end

					table.remove(game.BoonStacker_StackedTraits[slot], i)
					break
				end
			end
		end

		local prevSlot = trait.Slot
		trait.Slot = slot
		local status, result = pcall(originals.TraitUIRemove, trait)
		trait.Slot = prevSlot
		
		if not status then
			error(result)
		end

        -- If we removed the current one (Oldest), update to show the new Oldest
        if wasCurrent and game.BoonStacker_StackedTraits[slot] and #game.BoonStacker_StackedTraits[slot] > 0 then
             game.BoonStacker_CurrentTraitIndex[slot] = 1
             local newTrait = game.BoonStacker_StackedTraits[slot][1]
             if newTrait then
                 local status, err = pcall(function() game.TraitUIAdd(newTrait, { Show = true }) end)
                 if not status then
                    print("BS_DEBUG: Error updating trait UI: " .. tostring(err))
                 end
             end
        end
		
		return result
	end
	return originals.TraitUIRemove( trait )
end

function game.ShowTraitUI( args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.ShowTraitUI(args)
    end

	if game.BoonStacker_CurrentTraitIndex == nil then
		game.BoonStacker_CurrentTraitIndex = {}
	end
	
	game.BoonStacker_StackedTraits = {}
	
	local slotCounts = {}
	if game.CurrentRun and game.CurrentRun.Hero and game.CurrentRun.Hero.Traits then
		for _, trait in pairs(game.CurrentRun.Hero.Traits) do
			local addToStack = false
			if not trait.Hidden then
				local slot = GetTraitSlot(trait)
				if IsHudSlot(slot) then
					local prevSlot = trait.Slot
					trait.Slot = slot
					if originals.IsShownInHUD(trait) then
						addToStack = true
					end
					trait.Slot = prevSlot
				end
			end

			if addToStack then
				local slot = GetTraitSlot(trait)
				if IsHudSlot(slot) then
					slotCounts[slot] = (slotCounts[slot] or 0) + 1
					
					if not game.BoonStacker_StackedTraits[slot] then
						game.BoonStacker_StackedTraits[slot] = {}
					end
					table.insert(game.BoonStacker_StackedTraits[slot], trait)
				end
			end
		end
	end
	
	local slotsToClear = {}
	local slotsToReset = {}
	for slot, index in pairs(game.BoonStacker_CurrentTraitIndex) do
		local count = slotCounts[slot] or 0
		if count == 0 then
			table.insert(slotsToClear, slot)
		elseif index > count then
			table.insert(slotsToReset, slot)
		end
	end
	
	for _, slot in ipairs(slotsToClear) do
		game.BoonStacker_CurrentTraitIndex[slot] = nil
	end
	
	for _, slot in ipairs(slotsToReset) do
		game.BoonStacker_CurrentTraitIndex[slot] = 1
	end
	
	local result = originals.ShowTraitUI( args )
	
	return result
end
