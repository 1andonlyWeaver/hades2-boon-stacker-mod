---@meta _
-- Boon Stacker Logic

BoonStacker = public.BoonStacker or {}
public.BoonStacker = BoonStacker

local guaranteedSlots = {"Melee", "Secondary", "Ranged", "Rush", "Mana"}

-- Supplemental Hymn state tracking
-- When ForceSwaps trait is active and BoonStacker is unlocked, we repurpose it
-- to prioritize stackable boons (boons in already-filled slots) with +2 level bonus
BoonStacker.SupplementalHymnActive = false
BoonStacker.SupplementalHymnLevelBonus = 0

-- Capture originals
-- We use a check to avoid re-capturing our own wrappers on reload if this file is re-run without a clean state
-- (Though ideally reloading cleans up, but we'll be safe)
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

function public.BoonStacker.IsUnlocked()
    if config and config.SkipIncantations then
        return true
    end
    if game.GameState and game.GameState.WorldUpgrades and game.GameState.WorldUpgrades.BoonStacker_Unlock then
        return true
    end
    return false
end

function public.BoonStacker.EnableLogic()
    if not game.TraitData then return end
    print("BoonStacker: Enabling Logic (modifying TraitData)")
    for name, trait in pairs(game.TraitData) do
        if trait.Slot and game.Contains(guaranteedSlots, trait.Slot) then
            trait.OriginalSlot = trait.Slot
            trait.Slot = nil
        end
    end
end

function public.BoonStacker.DisableLogic()
    if not game.TraitData then return end
    print("BoonStacker: Disabling Logic (restoring TraitData)")
    for name, trait in pairs(game.TraitData) do
        if trait.OriginalSlot and game.Contains(guaranteedSlots, trait.OriginalSlot) then
            trait.Slot = trait.OriginalSlot
        end
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

-- Override GetPriorityTraits
function game.GetPriorityTraits( traitNames, lootData, args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetPriorityTraits(traitNames, lootData, args)
    end

	-- print("BoonStacker: GetPriorityTraits called")
	if traitNames == nil or lootData == nil then
		return {}
	end
	args = args or {}

	-- Reset any stale Supplemental Hymn state from previous uncompleted selections
	BoonStacker.SupplementalHymnActive = false
	BoonStacker.SupplementalHymnLevelBonus = 0

	-- Check for Supplemental Hymn (ForceSwaps trait) - repurposed for stacking
	local forceSwapTrait = game.HasHeroTraitValue("ForceSwaps")
	local supplementalHymnActive = forceSwapTrait and forceSwapTrait.Uses and forceSwapTrait.Uses > 0
	
	if supplementalHymnActive then
		-- Store state for level bonus application
		BoonStacker.SupplementalHymnActive = true
		BoonStacker.SupplementalHymnLevelBonus = game.GetTotalHeroTraitValue("ExchangeLevelBonus") or 2
		-- Mark loot data so the trait gets consumed after selection
		lootData.UseSwapTrait = true
		-- print("BoonStacker: Supplemental Hymn active, will prioritize stackable boons with +" .. tostring(BoonStacker.SupplementalHymnLevelBonus) .. " levels")
	end

	local priorityOptions = {}
	local traitsWithGuaranteedSlot = {}
	local traitsInOccupiedSlots = {} -- For Supplemental Hymn: traits that would stack
	local occupiedSlots = {}

    -- Robustly check for occupied slots
    local hero = game.CurrentRun and game.CurrentRun.Hero
    if hero and hero.Traits then
        for _, trait in pairs(hero.Traits) do
            if trait.Name then
                local tData = game.TraitData[trait.Name]
                if tData then
                    local slot = tData.Slot or tData.OriginalSlot
                    if slot then
                        -- Manual check for guaranteed slots to avoid dependency issues
                        for _, gSlot in ipairs(guaranteedSlots) do
                            if gSlot == slot then
                                occupiedSlots[slot] = true
                                -- print("BS_DEBUG: Slot " .. tostring(slot) .. " occupied by " .. tostring(trait.Name))
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
                local isGuaranteedSlot = false
                if slot then
                    for _, gSlot in ipairs(guaranteedSlots) do
                        if gSlot == slot then isGuaranteedSlot = true break end
                    end
                end

                -- Only add to priority options if the slot is NOT occupied (or it's not a guaranteed slot type)
                -- This ensures filled slots are not forced, but can still appear via general loot logic
				if not isGuaranteedSlot or not occupiedSlots[slot] then
					local data = { ItemName = traitName, Type = "Trait"}
					table.insert(priorityOptions, data)
					
					if isGuaranteedSlot then
						table.insert(traitsWithGuaranteedSlot, traitName)
					end
				end
				
				-- For Supplemental Hymn: also track traits that WOULD stack (in occupied slots)
				if supplementalHymnActive and isGuaranteedSlot and occupiedSlots[slot] then
					table.insert(traitsInOccupiedSlots, traitName)
				end
			end
		end
	end

	-- Supplemental Hymn: Prioritize stackable boons (traits in already-filled slots)
	if supplementalHymnActive and not game.IsEmpty(traitsInOccupiedSlots) then
		-- print("BoonStacker: Supplemental Hymn - Found " .. tostring(#traitsInOccupiedSlots) .. " stackable trait options")
		
		-- Replace priority options with stackable traits, ensuring at least one is included
		local stackableOptions = {}
		for _, traitName in ipairs(traitsInOccupiedSlots) do
			table.insert(stackableOptions, { ItemName = traitName, Type = "Trait" })
		end
		
		-- Trim to max loot choices
		while game.TableLength(stackableOptions) > game.GetTotalLootChoices() do
			game.RemoveRandomValue(stackableOptions)
			stackableOptions = game.CollapseTable(stackableOptions)
		end
		
		-- If we have stackable options, use them; otherwise fall back to normal priority
		if not game.IsEmpty(stackableOptions) then
			return stackableOptions
		end
	end

	while game.TableLength( priorityOptions ) > game.GetTotalLootChoices() do
		game.RemoveRandomValue( priorityOptions )
		priorityOptions = game.CollapseTable( priorityOptions )
	end
	local hasGuarantee = false

	for i, option in ipairs(priorityOptions) do
		local traitData = game.TraitData[option.ItemName]
		if traitData then
			local slot = traitData.Slot or traitData.OriginalSlot
            local isGuaranteedSlot = false
            if slot then
                for _, gSlot in ipairs(guaranteedSlots) do
                    if gSlot == slot then isGuaranteedSlot = true break end
                end
            end

			if isGuaranteedSlot and not occupiedSlots[slot] then
				hasGuarantee = true
			end
		end
	end

	if not hasGuarantee and not game.IsEmpty(traitsWithGuaranteedSlot) and not game.IsEmpty(priorityOptions) then
		local firstOption = priorityOptions[1]
		if firstOption then
			local validGuaranteedTraits = {}
			for _, traitName in ipairs(traitsWithGuaranteedSlot) do
				if not game.HeroHasTrait(traitName) then
					table.insert(validGuaranteedTraits, traitName)
				end
			end
			if not game.IsEmpty(validGuaranteedTraits) then
				firstOption.ItemName = game.GetRandomValue( validGuaranteedTraits )
			end
		end
	end
	return priorityOptions
end

-- Override GetReplacementTraits
function game.GetReplacementTraits( ... )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetReplacementTraits(...)
    end
	-- print("BoonStacker: GetReplacementTraits blocking replacement")
	return {}
end

-- Override GetEligibleUpgrades to reduce probability of stacked boons
function game.GetEligibleUpgrades( upgradeOptions, lootData, upgradeChoiceData )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetEligibleUpgrades(upgradeOptions, lootData, upgradeChoiceData)
    end

    -- If this is a StackOnly upgrade (like Pom of Power), use original logic immediately
    -- This prevents the penalty from applying to upgrades of existing boons
    if lootData and lootData.StackOnly then
        return originals.GetEligibleUpgrades(upgradeOptions, lootData, upgradeChoiceData)
    end

    -- Get the original list of eligible upgrades
    local eligibleOptions = originals.GetEligibleUpgrades(upgradeOptions, lootData, upgradeChoiceData)
    
    -- Count existing traits in guaranteed slots
    local slotCounts = {}
    local hero = game.CurrentRun and game.CurrentRun.Hero
    if hero and hero.Traits then
        for _, trait in pairs(hero.Traits) do
            if trait.Name then
                local tData = game.TraitData[trait.Name]
                if tData then
                    local slot = tData.Slot or tData.OriginalSlot
                    if slot then
                        -- Check if it's a guaranteed slot
                        for _, gSlot in ipairs(guaranteedSlots) do
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

    -- Filter based on probability
    local filteredOptions = {}
    for i, option in ipairs(eligibleOptions) do
        local keep = true
        local traitData = game.TraitData[option.ItemName]
        if traitData then
            local slot = traitData.Slot or traitData.OriginalSlot
            if slot and slotCounts[slot] and slotCounts[slot] > 0 then
                -- Calculate probability: 1 / (1 + (count * scalar))
                -- Default Scalar 1.0:
                -- Count = 1 -> 50% chance
                -- Count = 2 -> 33% chance
                local scalar = 1.0
                if config and config.StackPenaltyScalar then
                    scalar = config.StackPenaltyScalar
                end
                
                local probability = 1.0 / (1 + (slotCounts[slot] * scalar))
                
                if not game.RandomChance(probability) then
                    keep = false
                    -- print("BoonStacker: Reducing probability for " .. tostring(option.ItemName) .. " in slot " .. tostring(slot) .. " (Count: " .. tostring(slotCounts[slot]) .. ") - REMOVED")
                else
                    -- print("BoonStacker: Reducing probability for " .. tostring(option.ItemName) .. " in slot " .. tostring(slot) .. " (Count: " .. tostring(slotCounts[slot]) .. ") - KEPT")
                end
            end
        end
        
        if keep then
            table.insert(filteredOptions, option)
        end
    end

    return filteredOptions
end

-- Override AddTraitToHero to apply Supplemental Hymn level bonus
function game.AddTraitToHero( args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.AddTraitToHero(args)
    end
    
    -- Check if Supplemental Hymn is active and should apply level bonus
    if BoonStacker.SupplementalHymnActive and BoonStacker.SupplementalHymnLevelBonus > 0 then
        -- Always reset the state when AddTraitToHero is called while active
        -- This prevents incorrect bonus application to subsequent traits
        local levelBonus = BoonStacker.SupplementalHymnLevelBonus
        BoonStacker.SupplementalHymnActive = false
        BoonStacker.SupplementalHymnLevelBonus = 0
        
        local traitData = args.TraitData
        if traitData then
            local slot = traitData.Slot or traitData.OriginalSlot
            local isGuaranteedSlot = false
            if slot then
                for _, gSlot in ipairs(guaranteedSlots) do
                    if gSlot == slot then 
                        isGuaranteedSlot = true 
                        break 
                    end
                end
            end
            
            -- Only apply bonus to boons in guaranteed slots (the stackable ones)
            if isGuaranteedSlot then
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

	if game.Contains(guaranteedSlots, slotName) then
		-- print("BoonStacker: HeroSlotFilled forcing false for " .. tostring(slotName))
		return false
	end
	return originals.HeroSlotFilled( slotName, ... )
end

-- UI Overrides

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
    -- Even if locked, we might want to clean up if we were previously unlocked?
    -- But if locked, just use original.
    if not public.BoonStacker.IsUnlocked() then
        return originals.ShowTraitUI(args)
    end

	-- print("BS_DEBUG: ShowTraitUI called")
	
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
	
    -- Cycling removed
	return result
end
