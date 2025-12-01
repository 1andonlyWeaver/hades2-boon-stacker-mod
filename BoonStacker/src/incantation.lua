---@meta _
-- incantation registration
---@diagnostic disable: lowercase-global

---@module 'BlueRaja-IncantationsAPI'
local mods = rom.mods
Incantations = mods['BlueRaja-IncantationsAPI']

local unlockCost = { 
    MixerIBoss = 1, -- Zodiac Sand
    MixerQBoss = 1, -- Void Lens
}

if config.UseEasyUnlock then
    unlockCost = {
        PlantFMoly = 1, -- Moly
    }
end

Incantations.addIncantation({
	Id = "BoonStacker_Unlock",
	Name = "Superposition of Divine Favor",
	Description = "Permits multiple Blessings to inhabit the same ability slot, removing the need to Replace them.",
    FlavorText = "I will not quiet the thunder to hear the sea. Let them crash together.",
	WorldUpgradeData = {
		Icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
		Cost = unlockCost,
		GameStateRequirements = {
			-- No special requirements other than resources for now
		},
        IncantationVoiceLines = {
            {
                PreLineWait = 0.3,
                { Cue = "/VO/Melinoe_5611", Text = "{#Emph}Gods and Goddesses upon Olympus, fight!" },
            },
        },
	},
	OnEnabled = function(source, incantationId)
		if BoonStacker and BoonStacker.EnableLogic then
            print("BoonStacker: Incantation enabled, activating logic.")
			BoonStacker.EnableLogic()
        else
            print("BoonStacker: Incantation enabled, but logic not found!")
        end

        -- When we unlock the mod, we should reset the 'Disable' incantation history
        -- so that it can be bought again (if the user previously disabled it).
        if game.GameState and game.GameState.WorldUpgradesAdded then
            game.GameState.WorldUpgradesAdded.BoonStacker_Disable = nil
        end
	end,
    OnDisabled = function(source, incantationId)
        if BoonStacker and BoonStacker.DisableLogic then
            print("BoonStacker: Incantation disabled, deactivating logic.")
            BoonStacker.DisableLogic()
        else
            print("BoonStacker: Incantation disabled, but logic not found!")
        end
    end,
})

Incantations.addIncantation({
    Id = "BoonStacker_Disable",
    Name = "Separation of Divine Favor",
    Description = "Disables the boon stacking effect and refunds the resources used to unlock it.",
    FlavorText = "Maybe you can have too much of a good thing.",
    WorldUpgradeData = {
        InheritFrom = { "DefaultMinorItem" },
        Icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue", 
        Cost = {
            PlantFMoly = 1,
        },
        AlwaysRevealImmediately = true,
        GameStateRequirements = {
             {
                 PathTrue = { "GameState", "WorldUpgrades", "BoonStacker_Unlock" },
             },
        },
        IncantationVoiceLines = {
            {
                PreLineWait = 0.3,
                { Cue = "/VO/Melinoe_1076", Text = "{#Emph}Kataskion aski!" },
            },
        },
    },
    OnEnabled = function(source, incantationId)
        -- Refund
        for name, amount in pairs(unlockCost) do
            game.AddResource(name, amount, "BoonStacker_Refund")
        end
        -- Refund the token cost as well
        game.AddResource("PlantFMoly", 1, "BoonStacker_Refund")

        -- Disable Logic
        if BoonStacker and BoonStacker.DisableLogic then
            print("BoonStacker: Disable Incantation enabled, deactivating logic.")
            BoonStacker.DisableLogic()
        end

        -- Cleanup State
        if game.GameState then
            -- Reset this incantation so it can be used again if needed
            -- We do this in a thread to ensure we don't interfere with the current frame's processing
            -- and to ensure the game doesn't re-add flags immediately.
            game.thread(function()
                game.wait(0.5) -- Wait longer to ensure processing completes
                
                if game.GameState.WorldUpgrades then
                     game.GameState.WorldUpgrades.BoonStacker_Unlock = nil
                     game.GameState.WorldUpgrades.BoonStacker_Disable = nil
                end
                
                if game.GameState.WorldUpgradesAdded then
                     game.GameState.WorldUpgradesAdded.BoonStacker_Unlock = nil
                     
                     -- We leave BoonStacker_Disable in history to prevent it from reappearing
                     -- until the user buys Unlock again.
                end
            end)
        end
    end,
})

