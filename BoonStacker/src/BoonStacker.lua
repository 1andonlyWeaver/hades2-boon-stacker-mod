---@meta _
-- Boon Stacker Logic

BoonStacker = public.BoonStacker or {}
public.BoonStacker = BoonStacker

local guaranteedSlots = {"Melee", "Secondary", "Ranged", "Rush", "Mana"}

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
        ShowTraitUI = game.ShowTraitUI
    }
end

local originals = public.BoonStacker.Originals

function public.BoonStacker.IsUnlocked()
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
end

-- Override GetPriorityTraits
function game.GetPriorityTraits( traitNames, lootData, args )
    if not public.BoonStacker.IsUnlocked() then
        return originals.GetPriorityTraits(traitNames, lootData, args)
    end

	print("BoonStacker: GetPriorityTraits called")
	if traitNames == nil or lootData == nil then
		return {}
	end
	args = args or {}

	local priorityOptions = {}
	local traitsWithGuaranteedSlot = {}
	local occupiedSlots = {}

	if game.CurrentRun and game.CurrentRun.Hero and game.CurrentRun.Hero.Traits then
		for _, trait in pairs(game.CurrentRun.Hero.Traits) do
			if trait.Name and game.TraitData[trait.Name] then
				local tData = game.TraitData[trait.Name]
				local slot = tData.Slot or tData.OriginalSlot
				if slot and game.Contains(guaranteedSlots, slot) then
					occupiedSlots[slot] = true
				end
			end
		end
	end

	for index, traitName in ipairs(traitNames) do
		local traitData = game.TraitData[traitName]
		if traitData and (lootData.StripRequirements or game.IsTraitEligible( traitData )) then
			if not game.HeroHasTrait(traitName) then
				local data = { ItemName = traitName, Type = "Trait"}
				table.insert(priorityOptions, data)
				
				local slot = traitData.Slot or traitData.OriginalSlot
				if slot and game.Contains(guaranteedSlots, slot) and not occupiedSlots[slot] then
					table.insert(traitsWithGuaranteedSlot, traitName)
				end
			end
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
			if slot and game.Contains(guaranteedSlots, slot) and not occupiedSlots[slot] then
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
	print("BoonStacker: GetReplacementTraits blocking replacement")
	return {}
end

-- Override HeroSlotFilled
function game.HeroSlotFilled( slotName, ... )
    if not public.BoonStacker.IsUnlocked() then
        return originals.HeroSlotFilled(slotName, ...)
    end

	if game.Contains(guaranteedSlots, slotName) then
		print("BoonStacker: HeroSlotFilled forcing false for " .. tostring(slotName))
		return false
	end
	return originals.HeroSlotFilled( slotName, ... )
end

-- UI Overrides

-- Global state for cycling
game.BoonStacker_StackedTraits = {}
game.BoonStacker_CurrentTraitIndex = {}
game.BoonStacker_CycleId = 0
game.BoonStacker_CyclingUpdates = false

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
		if not game.BoonStacker_CyclingUpdates and game.BoonStacker_StackedTraits[slot] then
			for i, t in ipairs(game.BoonStacker_StackedTraits[slot]) do
				if t == trait then
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
		
		return result
	end
	return originals.TraitUIRemove( trait )
end

function game.BoonStacker_CycleSlots( cycleId, expectedCounts )
	print("BS_DEBUG: Cycle thread started for ID " .. tostring(cycleId))
	
	if expectedCounts then
		local retries = 20
		while retries > 0 do
			local allReady = true
			for slot, count in pairs(expectedCounts) do
				local current = game.BoonStacker_StackedTraits[slot] and #game.BoonStacker_StackedTraits[slot] or 0
				if current < count then
					allReady = false
					break
				end
			end
			
			if allReady then break end
			
			game.wait(0.05)
			retries = retries - 1
			
			if not game.ShowingCombatUI or cycleId ~= game.BoonStacker_CycleId then return end
		end
	end
	
	local cycleInterval = 3.0
	
	if not game.BoonStacker_NextCycleTime then
		if _worldTime then
			game.BoonStacker_NextCycleTime = _worldTime + cycleInterval
		end
	end

	while game.ShowingCombatUI and cycleId == game.BoonStacker_CycleId do
		local waitDuration = cycleInterval
		
		if _worldTime and game.BoonStacker_NextCycleTime then
			waitDuration = game.BoonStacker_NextCycleTime - _worldTime
			if waitDuration < 0.05 then waitDuration = 0.05 end
		end
		
		game.wait(waitDuration) 
		
		if not game.ShowingCombatUI or cycleId ~= game.BoonStacker_CycleId then 
			break 
		end
		
		if _worldTime then
			if not game.BoonStacker_NextCycleTime then
				game.BoonStacker_NextCycleTime = _worldTime + cycleInterval
			elseif game.BoonStacker_NextCycleTime < _worldTime then
				game.BoonStacker_NextCycleTime = _worldTime + cycleInterval
			else
				game.BoonStacker_NextCycleTime = game.BoonStacker_NextCycleTime + cycleInterval
			end
		end
		
		for slot, traits in pairs(game.BoonStacker_StackedTraits) do
			if #traits > 1 then
				local currentIndex = game.BoonStacker_CurrentTraitIndex[slot]
				if not currentIndex or currentIndex < 1 or currentIndex > #traits then
					currentIndex = 1
				end
				local oldTrait = traits[currentIndex]
				
				currentIndex = currentIndex + 1
				if currentIndex > #traits then currentIndex = 1 end
				game.BoonStacker_CurrentTraitIndex[slot] = currentIndex
				
				local newTrait = traits[currentIndex]
				
				game.BoonStacker_CyclingUpdates = true
				pcall(function()
					if oldTrait then game.TraitUIRemove(oldTrait) end
					if newTrait then game.TraitUIAdd(newTrait, { Show = true }) end
				end)
				game.BoonStacker_CyclingUpdates = false
			end
		end
	end
end

function game.ShowTraitUI( args )
    -- Even if locked, we might want to clean up if we were previously unlocked?
    -- But if locked, just use original.
    if not public.BoonStacker.IsUnlocked() then
        return originals.ShowTraitUI(args)
    end

	print("BS_DEBUG: ShowTraitUI called")
	
	game.BoonStacker_CycleId = (game.BoonStacker_CycleId or 0) + 1
	game.BoonStacker_NextCycleTime = nil
	
	if game.BoonStacker_CurrentTraitIndex == nil then
		game.BoonStacker_CurrentTraitIndex = {}
	end
	
	local slotCounts = {}
	if game.CurrentRun and game.CurrentRun.Hero and game.CurrentRun.Hero.Traits then
		for _, trait in pairs(game.CurrentRun.Hero.Traits) do
			if game.IsShownInHUD(trait) then
				local slot = GetTraitSlot(trait)
				if IsHudSlot(slot) then
					slotCounts[slot] = (slotCounts[slot] or 0) + 1
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

	game.BoonStacker_StackedTraits = {}
	
	local result = originals.ShowTraitUI( args )
	
	slotCounts = {}
	if game.CurrentRun and game.CurrentRun.Hero and game.CurrentRun.Hero.Traits then
		for _, trait in pairs(game.CurrentRun.Hero.Traits) do
			if game.IsShownInHUD(trait) then
				local slot = GetTraitSlot(trait)
				if IsHudSlot(slot) then
					slotCounts[slot] = (slotCounts[slot] or 0) + 1
				end
			end
		end
	end
	
	for slot, traits in pairs(game.BoonStacker_StackedTraits) do
		local count = #traits
		local index = game.BoonStacker_CurrentTraitIndex[slot]
		if index and index > count then
			game.BoonStacker_CurrentTraitIndex[slot] = 1
		end
	end
	
	local currentId = game.BoonStacker_CycleId
	
	game.thread( function() game.BoonStacker_CycleSlots(currentId, slotCounts) end )
	return result
end
