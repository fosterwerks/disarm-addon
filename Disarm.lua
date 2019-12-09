-- DECLARATIONS -----------------------------------------------------------------------------------
Disarm = {}
Disarm.name = "Disarm"
Disarm.version = 10

Disarm.Default = {
    indicator = true,
    offsetX = 25,
    offsetY = 25
}

-- LIBRARIES --------------------------------------------------------------------------------------

local LAM2 = LibAddonMenu2

-- OnAddonLoaded ----------------------------------------------------------------------------------

function Disarm.OnAddOnLoaded(event, addonName)
    -- The event fires each time any addon loads; check to see that it is our addon that's loading
    if addonName ~= Disarm.name then return end

    -- Unregister 'addon loaded' callback
    EVENT_MANAGER:UnregisterForEvent(Disarm.name, EVENT_ADD_ON_LOADED)

    -- Associate our variable with the appropriate 'saved variables' file
    Disarm.savedVariables = ZO_SavedVars:NewAccountWide("DisarmSavedVariables", Disarm.version, nil, Disarm.Default)

    -- Begin initialization
    Disarm:Initialize()
end

-- INITIALIZATION ---------------------------------------------------------------------------------

function Disarm:Initialize()

    -- Create settings window
    Disarm.CreateSettingsWindow()

    -- Restore indicator's position based on saved data
    self:RestoreIndicatorPosition()

    -- Register event handlers
    EVENT_MANAGER:RegisterForEvent(Disarm.name, EVENT_PLAYER_COMBAT_STATE, Disarm.OnPlayerCombatState)
    EVENT_MANAGER:RegisterForEvent(Disarm.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Disarm.OnInvSlotUpdate)
    -- Restrict InvSlotUpdate events to only fire for worn slots
    EVENT_MANAGER:AddFilterForEvent(Disarm.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

    -- Initialize flags
    self.unequipped = false
    self.inCombat = IsUnitInCombat("player")
end

-- OTHER FUNCTIONS --------------------------------------------------------------------------------

function Disarm:RestoreIndicatorPosition()

    local left = self.savedVariables.offsetX
    local top = self.savedVariables.offsetY

    -- Only try to restore position if position was ever saved
    if (left and top) then
        DisarmIndicator:ClearAnchors()
        DisarmIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    end
end

-- SETTINGS MENU ----------------------------------------------------------------------------------

function Disarm.CreateSettingsWindow()

    local panelData = {
		type = "panel",
		name = "Disarm",
		displayName = "Disarm",
		author = "Fosterwerks",
		version = string.format("%.1f", Disarm.version / 10.0),
		slashCommand = "/disarm",
		registerForRefresh = true,
		registerForDefaults = true,
    }
    
    local cntrlOptionsPanel = LAM2:RegisterAddonPanel("Disarm_Panel", panelData)

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
			tooltip = "Check this box if you want a persistent warning indicator.", -- to display when you've unequipped via the addon.",
			default = true,
			getFunc = function() return Disarm.savedVariables.indicator end,
            setFunc = function(newValue)
                Disarm.savedVariables.indicator = newValue
                if newValue == false then DisarmIndicator:SetHidden(true)
                elseif Disarm.unequipped then DisarmIndicator:SetHidden(false) end
            end
        },
        
        [4] = {
            type = "description",
			text = "Note: Indicator will be dismissed when re-equipping via the addon, as well as when manually re-equipping. It will not, however, appear if you unequip manually."
		}
    }

    LAM2:RegisterOptionControls("Disarm_Panel", optionsData)
end

-- MAIN FUNCTIONS ---------------------------------------------------------------------------------

function Disarm:SwapWeaponsState()
    if self.unequipped then
        Disarm:ReequipWeapons()
    else
        if Disarm:StoreCurrentWeapons() ~= 0 and not IsUnitInCombat("player") then
            Disarm:UnequipWeapons()
        end
    end
end

function Disarm:StoreCurrentWeapons()
    local count = 0
    -- create a table to store weapons that are being unequipped
    self.unequippedWeapons = {}

    -- Fill table by EquipSlot, InstanceId
    self.unequippedWeapons[EQUIP_SLOT_MAIN_HAND] =
        GetItemInstanceId(BAG_WORN, EQUIP_SLOT_MAIN_HAND)
    if self.unequippedWeapons[EQUIP_SLOT_MAIN_HAND] then count = count + 1 end

    self.unequippedWeapons[EQUIP_SLOT_OFF_HAND] =
        GetItemInstanceId(BAG_WORN, EQUIP_SLOT_OFF_HAND)
    if self.unequippedWeapons[EQUIP_SLOT_OFF_HAND] then count = count + 1 end

    self.unequippedWeapons[EQUIP_SLOT_BACKUP_MAIN] =
        GetItemInstanceId(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN)
    if self.unequippedWeapons[EQUIP_SLOT_BACKUP_MAIN] then count = count + 1 end
    
    self.unequippedWeapons[EQUIP_SLOT_BACKUP_OFF] =
        GetItemInstanceId(BAG_WORN, EQUIP_SLOT_BACKUP_OFF)
    if self.unequippedWeapons[EQUIP_SLOT_BACKUP_OFF] then count = count + 1 end

    return count
end

function Disarm:UnequipWeapons()
    -- CONSTANTS
    local SHEATHE_TDELAY = 1000
    local UNEQUIP_TDELAY = 500

    -- Step through current weapons and unequip
    local t = 0
    if not ArePlayerWeaponsSheathed() then
        TogglePlayerWield()                                     -- Weapons must be sheathed or weird stuff happens
        t = t + SHEATHE_TDELAY
    end
    for slot in pairs(self.unequippedWeapons) do
        zo_callLater(function() UnequipItem(slot) end, t)       -- Need to space out unequipping action
        t = t + UNEQUIP_TDELAY
    end

    zo_callLater(function() 
        if Disarm.savedVariables.indicator then         -- Only show indicator if user has Show Indicator selected in options
            DisarmIndicator:SetHidden(false)                    -- Makes indicator appear only after last weapon is unequipped
        end
        self.unequipped = true                                  -- Ensures we don't interfere with InvSlotUpdate event handler
    end, t)
end

function Disarm:ReequipWeapons()
    -- Step through each unequipped weapon
    for eSlot, target in pairs(self.unequippedWeapons) do
        -- And compare InstanceIds to item in backpack until a match is found
        local slot = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
        while slot do
            id = GetItemInstanceId(BAG_BACKPACK, slot)
            if id == target then
                EquipItem(BAG_BACKPACK, slot, eSlot)
                break
            end
            slot = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slot)
        end
    end

    DisarmIndicator:SetHidden(true)
    self.unequipped = false
end

-- EVENT HANDLER FUNCTIONS ------------------------------------------------------------------------


function Disarm.OnPlayerCombatState(event, inCombat)
    -- Re-equip weapons if entering combat and unarmed
    if Disarm.unequipped and inCombat then Disarm:ReequipWeapons() end
end

function Disarm.OnInvSlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    if Disarm.unequipped and (slotIndex == EQUIP_SLOT_MAIN_HAND or slotIndex == EQUIP_SLOT_OFF_HAND or
       slotIndex == EQUIP_SLOT_BACKUP_MAIN or slotIndex == EQUIP_SLOT_BACKUP_OFF) then
        DisarmIndicator:SetHidden(true)
        Disarm.unequipped = false
    end
end

-- XML EVENT HANDLER FUNCTIONS --------------------------------------------------------------------

function Disarm.OnIndicatorMoveStop()
    -- Save "No Weapon" indicator position on move
    Disarm.savedVariables.offsetX = DisarmIndicator:GetLeft()
    Disarm.savedVariables.offsetY = DisarmIndicator:GetTop()
end

-- EVENT REGISTRATIONS ----------------------------------------------------------------------------

-- Register our event handler function to be called when the proper event occurs
EVENT_MANAGER:RegisterForEvent(Disarm.name, EVENT_ADD_ON_LOADED, Disarm.OnAddOnLoaded)
