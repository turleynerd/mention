local addonName, addon = ...

-- No need for a safety check anymore as we're using the shared addon table
-- This will be directly available from the addon's lua files

-- We don't need any proxy functions or global table access
-- The addon table should already contain all the functions we need

-- Create the options panel
local optionsPanel = CreateFrame("Frame")
optionsPanel.name = "Mention"

-- Create title
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Mention Options")

-- Create prefix input box
local prefixLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
prefixLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
prefixLabel:SetText("Mention Prefix:")

local prefixInput = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
prefixInput:SetSize(50, 20)
prefixInput:SetPoint("LEFT", prefixLabel, "RIGHT", 10, 0)
prefixInput:SetAutoFocus(false)

-- Description text
local description = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
description:SetPoint("TOPLEFT", prefixLabel, "BOTTOMLEFT", 0, -10)
description:SetText("Enter the symbol you want to use for mentions (default: @)")

-- Save button
local saveButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
saveButton:SetSize(80, 22)
saveButton:SetText("Save")
saveButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)

-- Add a divider
local divider = optionsPanel:CreateTexture(nil, "ARTWORK")
divider:SetHeight(2)
divider:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
divider:SetPoint("TOPLEFT", saveButton, "BOTTOMLEFT", -10, -20)
divider:SetPoint("RIGHT", optionsPanel, "RIGHT", -30, 0)

-- Create sound options header
local soundTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
soundTitle:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 10, -10)
soundTitle:SetText("Name Mention Notifications")

-- Create sound enable checkbox
local soundCheckbox = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
soundCheckbox:SetPoint("TOPLEFT", soundTitle, "BOTTOMLEFT", 0, -10)
soundCheckbox.text:SetText("Play sound when your name is mentioned")

-- Create sound dropdown label
local soundLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
soundLabel:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 4, -15)
soundLabel:SetText("Sound:")

-- Create sound dropdown menu
local soundDropdown = CreateFrame("Frame", "MentionSoundDropdown", optionsPanel, "UIDropDownMenuTemplate")
soundDropdown:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -15, -5)

-- Create play button
local playButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
playButton:SetSize(60, 22)
playButton:SetText("Play")
playButton:SetPoint("LEFT", soundDropdown, "RIGHT", 15, 2)

-- Initialize sound dropdown
local selectedSound = ""

local function SoundDropdown_OnClick(self, arg1, arg2, checked)
    selectedSound = arg1
    UIDropDownMenu_SetText(soundDropdown, arg2)
    CloseDropDownMenus()
    
    -- Save the selection
    if selectedSound then
        addon.SetSound(selectedSound)
    end
end

local function SoundDropdown_Initialize(self, level)
    local info = UIDropDownMenu_CreateInfo()
    local sounds = addon.GetSoundList()
    local currentSound = addon.GetSound()
    
    -- Get the sound name from the path
    local currentSoundName = "None"
    for name, path in pairs(sounds) do
        if path == currentSound then
            currentSoundName = name
            break
        end
    end
    
    -- Set the initial text
    UIDropDownMenu_SetText(soundDropdown, currentSoundName)
    
    -- Add all available sounds
    for name, path in pairs(sounds) do
        info.text = name
        info.arg1 = path
        info.arg2 = name
        info.checked = (path == currentSound)
        info.func = SoundDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

-- Initialize panel
optionsPanel:SetScript("OnShow", function()
    -- Prefix
    prefixInput:SetText(addon.GetPrefix())
    
    -- Sound enable checkbox
    soundCheckbox:SetChecked(addon.IsSoundEnabled())
    
    -- Setup sound dropdown
    UIDropDownMenu_Initialize(soundDropdown, SoundDropdown_Initialize)
    UIDropDownMenu_SetWidth(soundDropdown, 150)
    
    -- Get current sound name
    local currentSound = addon.GetSound()
    local sounds = addon.GetSoundList()
    local currentSoundName = "None"
    for name, path in pairs(sounds) do
        if path == currentSound then
            currentSoundName = name
            break
        end
    end
    
    UIDropDownMenu_SetText(soundDropdown, currentSoundName)
end)

-- Handle save button click
saveButton:SetScript("OnClick", function()
    local newPrefix = prefixInput:GetText()
    if newPrefix and newPrefix ~= "" then
        addon.SetPrefix(newPrefix)
        print("|cff00ff00Mention:|r Prefix updated to: " .. newPrefix)
    end
end)

-- Handle sound checkbox click
soundCheckbox:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    addon.EnableSound(checked)
end)

-- Handle play button click
playButton:SetScript("OnClick", function()
    local currentSound = addon.GetSound()
    if currentSound and currentSound ~= "" then
        PlaySoundFile(currentSound, "Master")
    else
        print("|cff00ff00Mention:|r No sound selected")
    end
end)

-- Register in the Interface Options (Classic Era compatible)
optionsPanel.okay = function(self)
    -- This function is called when the player clicks the okay button.
    local newPrefix = prefixInput:GetText()
    if newPrefix and newPrefix ~= "" then
        addon.SetPrefix(newPrefix)
    end
    
    -- Save sound settings
    addon.EnableSound(soundCheckbox:GetChecked())
end

optionsPanel.cancel = function(self)
    -- This function is called when the player clicks the cancel button.
    prefixInput:SetText(addon.GetPrefix())
    
    -- Reset sound settings
    soundCheckbox:SetChecked(addon.IsSoundEnabled())
    
    -- Reset dropdown text
    local currentSound = addon.GetSound()
    local sounds = addon.GetSoundList()
    local currentSoundName = "None"
    for name, path in pairs(sounds) do
        if path == currentSound then
            currentSoundName = name
            break
        end
    end
    
    UIDropDownMenu_SetText(soundDropdown, currentSoundName)
end

optionsPanel.default = function(self)
    -- This function is called when the player clicks the default button.
    addon.SetPrefix("@")
    prefixInput:SetText("@")
    
    -- Reset sound to default
    addon.EnableSound(true)
    addon.SetSound("Interface\\AddOns\\Mention\\Sounds\\Mention.ogg")
    soundCheckbox:SetChecked(true)
    
    -- Update dropdown text
    UIDropDownMenu_SetText(soundDropdown, "Mention")
end

-- Register in the Classic Era way
SLASH_MENTION_OPTIONS1 = "/mentionoptions"
SlashCmdList["MENTION_OPTIONS"] = function()
    -- Create a simple interface panel
    if not InterfaceOptionsFrame:IsShown() then
        InterfaceOptionsFrame:Show()
    end
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end

-- Add the panel to the Interface Options
if Settings and Settings.RegisterCanvasLayoutCategory then
    -- For newer versions that support Settings API
    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Mention")
    Settings.RegisterAddOnCategory(category)
else
    -- For Classic Era
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    else
        -- Fallback for very old clients
        print("Mention: Options can be accessed with /mentionoptions")
    end
end
