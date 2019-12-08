-- Create addon's namespace
Disarm = {}
Disarm.name = "Disarm"
Disarm.version = 3
Disarm.Default = {
    Indicator.visible = true,
    Indicator.Position.X = 25,
    Indicator.Position.Y = 25
}
-- INITIALIZATION ---------------------------------------------------------------------------------

function Disarm:Initialize()
    -- Associate our variable with the appropriate 'saved variables' file
    self.savedVariables = ZO_SavedVars:NewAccountWide("DisarmSavedVariables", Disarm.version, nil, Disarm.Default)


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

    local left = self.savedVariables.Indicator.Position.X
    local top = self.savedVariables.Indicator.Position.Y

    -- Only try to restore position if position was ever saved
    if (left and top) then
        DisarmIndicator:ClearAnchors()
        DisarmIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    end
end

-- MAIN FUNCTIONS --------------------------------------------------------------------------------

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
        DisarmIndicator:SetHidden(false)        -- Makes indicator appear only after last weapon is unequipped
        self.unequipped = true                  -- Ensures we don't interfere with InvSlotUpdate event handler
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

function Disarm.OnAddOnLoaded(event, addonName)
    -- The event fires each time any addon loads; check to see that it is our addon that's loading
    if addonName == Disarm.name then return end

    -- Unregister 'addon loaded' callback
    EVENT_MANAGER:UnregisterForEvent(Disarm.name, EVENT_ADD_ON_LOADED)

    -- Begin initialization
    Disarm:Initialize()
end

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
    Disarm.savedVariables.Indicator.Position.X = DisarmIndicator:GetLeft()
    Disarm.savedVariables.Indicator.Position.Y = DisarmIndicator:GetTop()
end

-- EVENT REGISTRATIONS ----------------------------------------------------------------------------

-- Register our event handler function to be called when the proper event occurs
EVENT_MANAGER:RegisterForEvent(Disarm.name, EVENT_ADD_ON_LOADED, Disarm.OnAddOnLoaded)
