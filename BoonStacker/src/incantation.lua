---@meta _
-- incantation registration
---@diagnostic disable: lowercase-global

---@module 'BlueRaja-IncantationsAPI'
local mods = rom.mods
Incantations = mods['BlueRaja-IncantationsAPI']

Incantations.addIncantation({
	Id = "BoonStacker_Unlock",
	Name = "Superposition of Divine Favor",
	Description = "Permits multiple Blessings to inhabit the same ability slot, removing the need to Replace them.",
    FlavorText = "I will not quiet the thunder to hear the sea. Let them crash together.",
	WorldUpgradeData = {
		Icon = "GUI\\Screens\\CriticalItemShop\\Icons\\cauldron_statue",
		Cost = { 
            { Resource = "MixerIBoss", Amount = 1 }, -- Zodiac Sand
            { Resource = "MixerQBoss", Amount = 1 }, -- Void Lens
        },
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

