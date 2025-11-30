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
			firstOption.ItemName = game.GetRandomValue( traitsWithGuaranteedSlot )
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
