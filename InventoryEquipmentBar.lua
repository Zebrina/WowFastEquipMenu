local isClassic = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE);

if (isClassic) then
    NUM_EQUIPMENT_BAR_BUTTONS = 17;
else
    NUM_EQUIPMENT_BAR_BUTTONS = 16;
end

EQUIPMENTBUTTON_BORDER_WIDTH = 6;
EQUIPMENTBUTTON_BORDER_HEIGHT = 7;
EQUIPMENTBUTTON_BUTTONS_PER_COLUMN = 14;
EQUIPMENTBUTTON_BUTTON_SPACING = 6;

local WEAPON_CHAIN_ENCHANTID = 37;
local MITHRIL_SPURS_ENCHANTID = 464;
local WEAPON_CHAIN_TEXTUREID = 135834;
local MITHRIL_SPURS_TEXTUREID = 132307;

local IMMUNE_TO_DISARM_ITEMS = {
    [12639] = true, -- Stronghold Gauntlets
    [16907] = true, -- Bloodfang Gloves
    [18722] = true, -- Death Grips
    -- TBC
    [23072] = true, -- Fists of the Unrelenting
    [23533] = true, -- Steelgrip Gauntlets
    [29357] = true, -- Master Thief's Gloves
};

local InventoryEquipmentBar_Events = {};
local InventoryEquipmentButton_Events = {};
local InventoryEquipmentQueueBar_Events = {};

local function InventoryEquipmentButton_GetVisible(self)
    if (true) then
        return true;
    end
    local config = FEM_GlobalOptions.InventorySlots[self.invSlotName];
    if (config) then
        local visibility = config.visibility;
        if (visibility == "CONDITIONAL") then
            return SecureCmdOptionParse(config.visibilityCondition) == "show";
        elseif (visibility == "MULTI") then
            return true;
        elseif (visibility == "MULTI_USABLE") then
            return true;
        end
        return visibility == true;
    end
    return true;
end

local function InventoryEquipmentBar_ForEachButton(self, callback)
    for i, button in ipairs(self.Buttons) do
        if (button:IsShown()) then
            callback(button, i);
        end
    end
end

local function InventoryEquipmentBar_GetVisibleButtons(self)

end

-- TODO: Unused!
local function InventoryEquipmentBar_UpdateLayout(self)
    sort(self.Buttons, function(x, y)
        if (x.placeAfter == y.invSlotName) then
            return false;
        elseif (y.placeAfter == x.invSlotName) then
            return true;
        end
        return not x.placeAfter and x.defaultOrder < y.defaultOrder;
    end);
end

function InventoryEquipmentBar_UpdatePosition(self)
    if (InCombatLockdown()) then
        self.updateAfterCombat = true;
        return;
    end

    self.updateAfterCombat = nil;

    local point, relativeTo, relativePoint, xOfs, yOfs;

    --local classicUI = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) or IsAddOnLoaded("ClassicUI");
    if (self.freePlacement) then
        self:SetPoint("CENTER", UIParent, "CENTER", self.freePosX, self.freePosY);
    --elseif (classicUI and SHOW_MULTI_ACTIONBAR_2) then
    --  self:SetPoint("BOTTOM", MultiBarBottomRightButton1, "TOP", 182, 4.5);
    --elseif (SHOW_MULTI_ACTIONBAR_1) then
    --  self:SetPoint("BOTTOMLEFT", MultiBarBottomLeft, "BOTTOMRIGHT", 0, 1);
    elseif (SHOW_MULTI_ACTIONBAR_3) then
        self:SetPoint("TOPRIGHT", SHOW_MULTI_ACTIONBAR_4 and MultiBarLeft or MultiBarRight, "TOPLEFT", -2, -2.5 + 50);
    else
        self:SetPoint("TOPRIGHT", UIParent, "RIGHT", 0, select(5, VerticalMultiBarsContainer:GetPoint()) + (VERTICAL_MULTI_BAR_HEIGHT / 2));
    end

    local numButtons = getn(self.Buttons);
    local width, height = EquippableItemButtonFrame_UpdateGridLayout(self, "BOTTOMLEFT", numButtons, numButtons, false, true);
    EquippableItemButtonFrame_UpdateGridSize(self, width, height);
end

function InventoryEquipmentBar_OnLoad(self)
    self:EnableMouse(true);
    self:SetMovable(true);
    self:SetClampedToScreen(true);

    self.ButtonsByInvSlot = {};
    InventoryEquipmentBar_ForEachButton(self, function(button, i)
        self.ButtonsByInvSlot[button.invSlot] = button;
        button.defaultOrder = i;
    end);

    self.borderSizeBottom = 4;
    self.buttonSpacing = 4;

    self.rangeTimer = -1;

    for event in pairs(InventoryEquipmentBar_Events) do
        self:RegisterEvent(event);
    end
end

function InventoryEquipmentBar_OnEvent(self, event, ...)
    InventoryEquipmentBar_Events[event](self, ...);
end

function InventoryEquipmentBar_Events.PLAYER_ENTERING_WORLD(self)
    hooksecurefunc("MultiActionBar_Update", function()
        InventoryEquipmentBar_UpdatePosition(self);
    end);

    InventoryEquipmentBar_UpdatePosition(self);
    self:Show();
end

function InventoryEquipmentBar_Events.PLAYER_REGEN_ENABLED(self)
    if (self.updateAfterCombat) then
        InventoryEquipmentBar_UpdatePosition(self);
    end
end

function InventoryEquipmentBar_Events.PLAYER_EQUIPMENT_CHANGED(self, equipmentSlot, hasCurrent)
    local button = self.ButtonsByInvSlot[equipmentSlot];
    if (button) then
        InventoryEquipmentButton_UpdateIcon(button);
        if (button:ShouldShow() ~= button:IsShown()) then
            InventoryEquipmentBar_UpdatePosition(self);
        end
    end
end

function InventoryEquipmentBar_Events.UPDATE_BINDINGS(self)
    InventoryEquipmentBar_ForEachButton(self, InventoryEquipmentButton_UpdateHotkey);
end

function InventoryEquipmentBar_OnUpdate(self, elapsed)
    local rangeTimer = self.rangeTimer;
	if (rangeTimer) then
		rangeTimer = rangeTimer - elapsed;
		if (rangeTimer <= 0) then
            InventoryEquipmentBar_ForEachButton(self, function(button)
                local checksRange, inRange = false, false;
                local itemID = GetInventoryItemID("player", button.invSlot);
                if (itemID) then
                    local _, spellID = GetItemSpell(itemID);
                    if (spellID) then
                        inRange = IsItemInRange(itemID, "target");
                        checksRange = inRange ~= nil;
                    end
                end
                ActionButton_UpdateRangeIndicator(button, checksRange, inRange);
            end);
			rangeTimer = TOOLTIP_UPDATE_TIME;
		end
		self.rangeTimer = rangeTimer;
	end

    InventoryEquipmentBar_ForEachButton(self, function(button)
		local start, duration, enable = GetInventoryItemCooldown("player", button.invSlot);
		CooldownFrame_Set(button.cooldown, start, duration, enable);
		if (GameTooltip:GetOwner() == button) then
			EquippableItemButton_OnEnter(button);
		end
    end);
end

function InventoryEquipmentBar_OnShow(self)
end

function InventoryEquipmentBar_OnHide(self)
end



InventoryEquipmentButtonMixin = {};

function InventoryEquipmentButtonMixin.GetItemLink(self)
    return GetInventoryItemLink("player", self.invSlot);
end

function InventoryEquipmentButtonMixin.ShouldShow(self)
    if (self.shouldShow) then
        return self.shouldShow();
    end
    return true;
end

function InventoryEquipmentButton_OnLoad(self)
    EquippableItemButton_OnLoad(self);

    local bindingName = _G[self.invSlotName]..(self.invSlotIndex and " "..self.invSlotIndex or "");
    _G["BINDING_NAME_CLICK "..self:GetName()..":LeftButton"] = "Use "..bindingName.." Item";

    local slotID, textureName = GetInventorySlotInfo(self.invSlotName);
    self.invSlot = slotID;
    self.emptyTextureName = textureName;
    --self:SetAttribute("item", slotID);
    self:SetAttribute("macrotext1", "/use [@mouseover,exists][]"..slotID);

    local fontName, fontHeight, fontFlags = self.Count:GetFont();
    self.Count:SetFont(fontName, fontHeight - 3, fontFlags);

    self.enchant:SetSize(11, 11);

    --[[
    -- TODO: This doesn't seem to work without changing the behavior of the character slot button.
    local thisButton = self;
    self.proxyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "RightButtonDown");
    self.proxyButton:HookScript("OnClick", function(self, button, down)
        if (button == "RightButton") then
            if (not self:IsVisible() and down) then
                thisButton:SetButtonState("PUSHED");
            else
                thisButton:SetButtonState("NORMAL");
            end
        end
    end);
    ]]

    InventoryEquipmentButton_UpdateHotkey(self);

    self:RegisterForDrag("LeftButton");

    for event in pairs(InventoryEquipmentButton_Events) do
        self:RegisterEvent(event);
    end
end

function InventoryEquipmentButton_OnEvent(self, event, ...)
    InventoryEquipmentButton_Events[event](self, ...);
end

function InventoryEquipmentButton_Events.PLAYER_ENTERING_WORLD(self)
    if (self.checkRelic and UnitHasRelicSlot("player")) then
        self.emptyTextureName = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp";
    end
    InventoryEquipmentButton_UpdateIcon(self);
    self.hasCurrent = GetInventoryItemID("player", self.invSlot) ~= nil;
end

function InventoryEquipmentButton_Events.ITEM_LOCK_CHANGED(self, bagOrSlotIndex, slotIndex)
    if (slotIndex == nil and bagOrSlotIndex == self.invSlot) then
        InventoryEquipmentButton_UpdateLocked(self);
    end
end

function InventoryEquipmentButton_Events.UPDATE_BINDINGS(self)
    InventoryEquipmentButton_UpdateHotkey(self);
end

function InventoryEquipmentButton_OnDragStart(self)
	if (not InCombatLockdown() and LOCK_ACTIONBAR ~= "1" or IsModifiedClick("PICKUPACTION")) then
		self:SetChecked(false);
		PickupInventoryItem(self.invSlot);
	end
end

function InventoryEquipmentButton_OnReceiveDrag(self)
	if (not InCombatLockdown() and GetCursorInfo() == "item") then
		self:SetChecked(false);
		PickupInventoryItem(self.invSlot);
	end
end

function InventoryEquipmentButton_OnUpdate(self, elapsed)
    EquippableItemButton_OnUpdate(self, elapsed);
end

function InventoryEquipmentButton_UpdateHotkey(self)
	local bindingKey = GetBindingKey("CLICK "..self:GetName()..":LeftButton") or
                       (self.proxyButton and GetBindingKey("CLICK "..self.proxyButton:GetName()..":RightButton"));
    local bindingText = GetBindingText(bindingKey, true);
	if (bindingText == "") then
		self.HotKey:SetText(RANGE_INDICATOR);
		self.HotKey:Hide();
	else
		self.HotKey:SetText(bindingText);
		self.HotKey:Show();
	end
end

function InventoryEquipmentButton_UpdateIcon(self)
    self.icon:SetTexture(GetInventoryItemTexture("player", self.invSlot) or self.emptyTextureName);

    local enchant = GetInventoryItemEnchant("player", self.invSlot);
    if (IMMUNE_TO_DISARM_ITEMS[itemID] or enchant == WEAPON_CHAIN_ENCHANTID) then
        -- Show weapon chain icon if immune to disarm
        self.enchant:SetTexture(WEAPON_CHAIN_TEXTUREID);
        self.enchant:Show();
    elseif (enchant == MITHRIL_SPURS_ENCHANTID) then
        self.enchant:SetTexture(MITHRIL_SPURS_TEXTUREID);
        self.enchant:Show();
    else
        self.enchant:Hide();
    end

    local queuedItemID = EQUIPQUEUE[self.invSlot];
    if (queuedItemID and queuedItemID ~= GetInventoryItemLink("player", self.invSlot)) then
        --self.cooldown:SetSwipeColor(0, 0, 0, 0.5);
        self.swapIcon:SetTexture(GetItemTexture(queuedItemID));
        self.swapIcon:Show();
    else
        --self.cooldown:SetSwipeColor(0, 0, 0);
        self.swapIcon:Hide();
    end
end

function InventoryEquipmentButton_UpdateLocked(self)
    local isLocked = IsInventoryItemLocked(self.invSlot);
    SetItemButtonDesaturated(self, isLocked);
end

function InventoryEquipmentQueueBar_OnLoad(self)
    self:EnableMouse(true);
    self:SetMovable(true);
    self:SetClampedToScreen(true);

    for event in pairs(InventoryEquipmentQueueBar_Events) do
        self:RegisterEvent(event);
    end
end

function InventoryEquipmentQueueBar_OnEvent(self, event, ...)
    InventoryEquipmentQueueBar_Events[event](self, ...);
end

function InventoryEquipmentQueueBar_OnUpdate(self, elapsed)
end

function InventoryEquipmentQueueBar_OnShow(self)
end

function InventoryEquipmentQueueBar_OnHide(self)
end
