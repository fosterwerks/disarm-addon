-- LIBRARIES --------------------------------------------------------------------------------------

local LAM2 = LibraryAddonMenu2

-- MENU -------------------------------------------------------------------------------------------

if not Disarm then Disarm = {}          -- Create Namespace if neccessary

function Disarm.CreateSettingsWindow()
    local panelData = {
		type = "panel",
		name = "Disarm",
		displayName = "Disarm",
		author = "Fosterwerks",
		version = CirconianStaminaBar.version,
		slashCommand = "/disarm",
		registerForRefresh = true,
		registerForDefaults = true,
    }
    
    local cntrlOptionsPanel = LAM2:RegisterAddonPanel("Disarm", panelData)

    local optionsData = {
        [1] = {
			type = "header",
			name = "Warning Indicator Settings"
		},

		[2] = {
			type = "description",
			text = "Here you can adjust how the warning indicator works."
		},

		[3] = {
			type = "checkbox",
			name = "Show Warning Indicator on Unequip",
			tooltip = "Check this box if you want a persistent warning indicator to display when you've unequipped via the addon.",
			default = true,
			getFunc = function() return Disarm.savedVariables.Indicator.visible end,
			setFunc = function(newValue)
				Disarm.savedVariables.Indicator.visible = newValue end
        },
        
        [4] = {
			type = "description",
			text = "Note: Indicator will be dismissed when re-equipping via the addon, as well as when manually re-equipping. It will not, however, appear if you unequip manually."
		}
    }
end
