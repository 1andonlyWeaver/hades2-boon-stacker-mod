---@meta _
-- Boon Stacker Logic

-- Override GetPriorityTraits to ignore occupied slots
function game.GetPriorityTraits( traitNames, lootData, args )
	if traitNames == nil then
		return {}
	end
	args = args or {}

	local priorityOptions = {}
	local heroHasPriorityTrait = false
	-- BoonStacker: We don't care about occupied slots
	-- local occupiedSlots = {} 
	local guaranteedSlots = {"Melee", "Secondary"} 
	local traitsWithGuaranteedSlot = {}

	-- BoonStacker: Removed occupiedSlots population loop

	for index, traitName in ipairs(traitNames) do

		-- Use game.TraitData, game.IsTraitEligible etc to ensure we hit the game globals
		if game.TraitData[traitName] and (lootData.StripRequirements or game.IsTraitEligible( game.TraitData[traitName] )) then
			-- BoonStacker: Removed occupiedSlots check
			if not game.HeroHasTrait(traitName) then
				local data = { ItemName = traitName, Type = "Trait"}
				table.insert(priorityOptions, data)
				if game.Contains(guaranteedSlots, game.TraitData[traitName].Slot) then
					table.insert(traitsWithGuaranteedSlot, traitName)
				end
			else
				heroHasPriorityTrait = true
			end
		end
	end

	if heroHasPriorityTrait then
		return { game.GetRandomValue(priorityOptions) }
	end
	while game.TableLength( priorityOptions ) > game.GetTotalLootChoices() do
		game.RemoveRandomValue( priorityOptions )
		priorityOptions = game.CollapseTable( priorityOptions )
	end
	local hasGuarantee = false
	if game.IsEmpty(traitsWithGuaranteedSlot)  then
		hasGuarantee = true
	end
	
	for i, option in pairs(priorityOptions) do
		if game.Contains(guaranteedSlots, game.TraitData[option.ItemName].Slot) then
			hasGuarantee = true
		end
	end
	if not hasGuarantee then
		priorityOptions[1].ItemName = game.GetRandomValue( traitsWithGuaranteedSlot )
	end
	return priorityOptions
end

-- Override GetReplacementTraits to disable replacements (swapping)
function game.GetReplacementTraits( traitNames, onlyFromLootName )
	return {}
end

-- Override HeroSlotFilled to trick the game into thinking slots are always free
function game.HeroSlotFilled( slotName )
	return false
end

