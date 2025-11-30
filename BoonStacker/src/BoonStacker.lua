---@meta _
-- Boon Stacker Logic

local guaranteedSlots = {"Melee", "Secondary", "Ranged", "Rush", "Mana"}

-- Strip slots from TraitData to prevent replacement logic
if game.TraitData then
	for name, trait in pairs(game.TraitData) do
		if trait.Slot and game.Contains(guaranteedSlots, trait.Slot) then
			trait.OriginalSlot = trait.Slot
			trait.Slot = nil
		end
	end
end

-- Override GetPriorityTraits to ignore occupied slots
function game.GetPriorityTraits( traitNames, lootData, args )
	print("BoonStacker: GetPriorityTraits called")
	if traitNames == nil or lootData == nil then
		return {}
	end
	args = args or {}

	local priorityOptions = {}
	local traitsWithGuaranteedSlot = {}

	-- BoonStacker: Removed occupiedSlots population loop

	for index, traitName in ipairs(traitNames) do

		-- Use game.TraitData, game.IsTraitEligible etc to ensure we hit the game globals
		local traitData = game.TraitData[traitName]
		if traitData and (lootData.StripRequirements or game.IsTraitEligible( traitData )) then
			-- BoonStacker: Removed occupiedSlots check
			if not game.HeroHasTrait(traitName) then
				local data = { ItemName = traitName, Type = "Trait"}
				table.insert(priorityOptions, data)
				
				local slot = traitData.Slot or traitData.OriginalSlot
				if slot and game.Contains(guaranteedSlots, slot) then
					table.insert(traitsWithGuaranteedSlot, traitName)
				end
			end
		end
	end

	-- If we have priority traits but we haven't ensured guarantees yet, we shouldn't return early if we want to be strict.
	-- The logic below is: if we found valid priority options, return one of them. 
	-- BUT we must respect guaranteed slots if possible.
	
	-- (Removing early return block)

	while game.TableLength( priorityOptions ) > game.GetTotalLootChoices() do
		game.RemoveRandomValue( priorityOptions )
		priorityOptions = game.CollapseTable( priorityOptions )
	end
	local hasGuarantee = false

	for i, option in pairs(priorityOptions) do
		local traitData = game.TraitData[option.ItemName]
		if traitData then
			local slot = traitData.Slot or traitData.OriginalSlot
			if slot and game.Contains(guaranteedSlots, slot) then
				hasGuarantee = true
			end
		end
	end

	if not hasGuarantee and not game.IsEmpty(traitsWithGuaranteedSlot) and not game.IsEmpty(priorityOptions) then
		local key, firstOption = next(priorityOptions)
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

-- Override GetReplacementTraits to disable replacements (swapping)
function game.GetReplacementTraits( ... )
	print("BoonStacker: GetReplacementTraits blocking replacement")
	return {}
end

-- Capture original function to call for non-guaranteed slots
local originalHeroSlotFilled = game.HeroSlotFilled

-- Override HeroSlotFilled to trick the game into thinking slots are always free
function game.HeroSlotFilled( slotName, ... )
	if game.Contains(guaranteedSlots, slotName) then
		print("BoonStacker: HeroSlotFilled forcing false for " .. tostring(slotName))
		return false
	end
	return originalHeroSlotFilled( slotName, ... )
end

-- UI Overrides for Boon Stacking / Cycling

-- Global state for cycling
game.BoonStacker_StackedTraits = {}
game.BoonStacker_CurrentTraitIndex = {}
game.BoonStacker_CycleId = 0

-- Helper to safely check if a trait belongs to a HUD slot
local function GetTraitSlot(trait)
	return trait.Slot or trait.OriginalSlot
end

local function IsHudSlot(slot)
	return slot and game.Contains(game.ScreenData.HUD.SlottedTraitOrder, slot)
end

-- Override IsShownInHUD to respect OriginalSlot
local originalIsShownInHUD = game.IsShownInHUD
function game.IsShownInHUD( trait )
	if trait.Hidden then
		return false
	end
	local slot = GetTraitSlot(trait)
	if IsHudSlot(slot) then
		return true
	end
	return originalIsShownInHUD( trait )
end

-- Override TraitUIAdd to manage stacking
local originalTraitUIAdd = game.TraitUIAdd
function game.TraitUIAdd( trait, args )
	local slot = GetTraitSlot(trait)
	
	if IsHudSlot(slot) then
		-- Initialize stack list for this slot if needed
		if not game.BoonStacker_StackedTraits[slot] then
			game.BoonStacker_StackedTraits[slot] = {}
		end
		
		-- Add to stack list if not present
		local found = false
		for _, t in ipairs(game.BoonStacker_StackedTraits[slot]) do
			if t == trait then found = true break end
		end
		if not found then
			table.insert(game.BoonStacker_StackedTraits[slot], trait)
		end
		
		-- Initialize index if needed
		if game.BoonStacker_CurrentTraitIndex[slot] == nil then
			game.BoonStacker_CurrentTraitIndex[slot] = 1
		end
		
		-- Only draw if this is the currently active trait for this slot
		local currentIndex = game.BoonStacker_CurrentTraitIndex[slot]
		local currentTrait = game.BoonStacker_StackedTraits[slot][currentIndex]
		
		if currentTrait and trait == currentTrait then
			-- Temporarily restore Slot so original function places it correctly
			trait.Slot = slot
			local status, result = pcall(originalTraitUIAdd, trait, args)
			trait.Slot = nil
			
			if not status then
				error(result)
			end
			return result
		end
		return nil
	end
	
	return originalTraitUIAdd( trait, args )
end

-- Override TraitUIRemove to handle missing Slot
local originalTraitUIRemove = game.TraitUIRemove
function game.TraitUIRemove( trait )
	local slot = GetTraitSlot(trait)
	if IsHudSlot(slot) then
		trait.Slot = slot
		local status, result = pcall(originalTraitUIRemove, trait)
		trait.Slot = nil
		
		if not status then
			error(result)
		end
		return result
	end
	return originalTraitUIRemove( trait )
end

-- Cycle logic
function game.BoonStacker_CycleSlots( cycleId )
	-- print("BoonStacker: Cycle thread started for ID " .. tostring(cycleId))
	
	local cycleInterval = 3.0
	
	-- Initialize next cycle time if needed (using absolute world time)
	if not game.BoonStacker_NextCycleTime then
		if _worldTime then
			game.BoonStacker_NextCycleTime = _worldTime + cycleInterval
		end
	end

	while game.ShowingCombatUI and cycleId == game.BoonStacker_CycleId do
		local waitDuration = cycleInterval
		
		-- Calculate remaining time to next cycle point
		if _worldTime and game.BoonStacker_NextCycleTime then
			waitDuration = game.BoonStacker_NextCycleTime - _worldTime
			-- Ensure we don't wait negative or too small time
			if waitDuration < 0.05 then waitDuration = 0.05 end
		end
		
		game.wait(waitDuration) 
		
		if not game.ShowingCombatUI or cycleId ~= game.BoonStacker_CycleId then break end
		
		-- Update target time for next cycle
		if _worldTime then
			-- If we fell behind significantly (e.g. pause/lag), reset to now + interval
			if game.BoonStacker_NextCycleTime < _worldTime then
				game.BoonStacker_NextCycleTime = _worldTime + cycleInterval
			else
				game.BoonStacker_NextCycleTime = game.BoonStacker_NextCycleTime + cycleInterval
			end
		end
		
		for slot, traits in pairs(game.BoonStacker_StackedTraits) do
			if #traits > 1 then
				local currentIndex = game.BoonStacker_CurrentTraitIndex[slot] or 1
				local oldTrait = traits[currentIndex]
				
				-- Increment index
				currentIndex = currentIndex + 1
				if currentIndex > #traits then currentIndex = 1 end
				game.BoonStacker_CurrentTraitIndex[slot] = currentIndex
				
				local newTrait = traits[currentIndex]
				
				-- Swap visuals
				-- We use pcall to avoid crashing the thread if UI state is mid-transition
				pcall(function()
					if oldTrait then game.TraitUIRemove(oldTrait) end
					if newTrait then game.TraitUIAdd(newTrait, { Show = true }) end
				end)
			end
		end
	end
end

-- Override ShowTraitUI to start the cycler
local originalShowTraitUI = game.ShowTraitUI
function game.ShowTraitUI( args )
	
	-- Ensure index table exists
	if game.BoonStacker_CurrentTraitIndex == nil then
		game.BoonStacker_CurrentTraitIndex = {}
	end
	
	-- Pre-calculate counts to fix stale indices before we try to draw
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

	-- Clamp indices if they are out of bounds for the new counts
	for slot, index in pairs(game.BoonStacker_CurrentTraitIndex) do
		local count = slotCounts[slot] or 0
		if index > count then
			game.BoonStacker_CurrentTraitIndex[slot] = 1
		end
	end

	-- Reset stacks tracking on fresh show
	game.BoonStacker_StackedTraits = {}
	
	originalShowTraitUI( args )
	
	-- Increment cycle ID to kill old threads
	game.BoonStacker_CycleId = (game.BoonStacker_CycleId or 0) + 1
	local currentId = game.BoonStacker_CycleId
	
	game.thread( function() game.BoonStacker_CycleSlots(currentId) end )
end
