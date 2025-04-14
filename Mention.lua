-- Mention - Addon for @name autocomplete in chat
local addonName, addon = ...

-- Use only the addon table for all functionality, avoiding global namespace pollution
local MentionFrame = CreateFrame("Frame")
local autocompleteFrame = nil
local cachedPlayerNames = {} -- Cached player names with priorities
local currentPrefix = "@"
local MAX_SUGGESTIONS = 8 -- Maximum number of suggestions to show
local selectedIndex = 1 -- Currently selected item in the dropdown
local currentMatches = {} -- Current list of matching players

-- Sound options
local soundEnabled = true
local currentSound = "Interface\\AddOns\\Mention\\Sounds\\Mention.ogg"
local defaultSounds = {
    ["None"] = "",
    ["Mention"] = "Interface\\AddOns\\Mention\\Sounds\\Mention.ogg",
    ["Whisper"] = "Interface\\AddOns\\Mention\\Sounds\\Whisper.ogg",
    ["Ding"] = "Sound\\Interface\\iAbilitiesOpenFail.ogg",
    ["Raid Warning"] = "Sound\\Interface\\RaidWarning.ogg",
    ["Ready Check"] = "Sound\\Interface\\ReadyCheck.ogg"
}

-- Error reporting function (simplified without pcall)
local function ReportError(message)
    print("|cffff0000Mention Error:|r " .. (message or "Unknown error"))
end

-- Named sort function to avoid creating closures
local function SortPlayersByPriority(a, b)
    if a.priority == b.priority then
        return a.name < b.name  -- Alphabetically if same priority
    else
        return a.priority > b.priority  -- Higher priority first
    end
end

-- Forward declarations for functions called before their definitions
local UpdateCachedPlayerNames, UpdateGroupRoster, UpdateGuildRoster

-- Update party/raid members in cache
UpdateGroupRoster = function()
    -- Check if in a group
    if IsInGroup() then
        local playerName = UnitName("player")
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local name = GetRaidRosterInfo(i)
                if name and name ~= "" and name ~= _G.UNKNOWNOBJECT and name ~= playerName then
                    cachedPlayerNames[name] = 2 -- High priority
                end
            end
        else
            for i = 1, 4 do
                local name = UnitName("party"..i)
                if name and name ~= "" and name ~= _G.UNKNOWNOBJECT and name ~= playerName then
                    cachedPlayerNames[name] = 2 -- High priority
                end
            end
        end
    end
end

-- Update guild members in cache
UpdateGuildRoster = function()
    if not IsInGuild() then return end
    
    local playerName = UnitName("player")
    local numMembers = GetNumGuildMembers()
    if numMembers > 0 then
        for i = 1, numMembers do
            local name = GetGuildRosterInfo(i)
            if name and name ~= "" and name ~= playerName then
                -- Extract name without realm if it contains a hyphen
                if string.find(name, "-") then
                    local shortName = string.match(name, "([^-]+)")
                    if shortName and shortName ~= "" then
                        -- Only add the short name (without server) for better display
                        cachedPlayerNames[shortName] = 1 -- Medium priority
                    end
                else
                    -- If no hyphen, just add the name as is
                    cachedPlayerNames[name] = 1 -- Medium priority
                end
            end
        end
    end
end

-- Update cached player names (both group and guild)
UpdateCachedPlayerNames = function()
    -- Clear the current cache
    wipe(cachedPlayerNames)
    
    -- Always add yourself first with highest priority
    local playerName = UnitName("player")
    if playerName then
        cachedPlayerNames[playerName] = 3 -- Highest priority
    end
    
    -- Update party/raid roster
    UpdateGroupRoster()
    
    -- Update guild roster
    if IsInGuild() then
        UpdateGuildRoster()
    end
end

-- Initialize saved variables and set up event handlers
function MentionFrame:OnLoad()
    if not MentionDB then
        MentionDB = {
            prefix = "@",
            soundEnabled = true,
            sound = "Interface\\AddOns\\Mention\\Sounds\\Mention.ogg"
        }
    end
    
    -- Initialize variables from saved settings
    currentPrefix = MentionDB.prefix
    soundEnabled = MentionDB.soundEnabled
    
    -- Use saved sound if it exists, otherwise use default
    if MentionDB.sound then
        currentSound = MentionDB.sound
    end
    
    -- Register for events to update player caches
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    
    -- Initialize our cached player lists
    UpdateCachedPlayerNames()
    
    print("|cff00ff00Mention|r addon loaded. Type " .. currentPrefix .. "name to mention players")
end

-- Create a simple autocomplete dropdown
local function CreateAutocompleteFrame()
    -- Create main frame
    local frame = CreateFrame("Frame", "MentionAutocompleteFrame", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetWidth(160)
    frame:SetHeight(20 * MAX_SUGGESTIONS) -- Height for 8 items
    -- No backdrop needed for Classic Era
    frame:Hide()
    
    -- Create simple background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Pre-create buttons for efficiency
    frame.buttons = {}
    for i = 1, MAX_SUGGESTIONS do
        local button = CreateFrame("Button", nil, frame)
        button:SetHeight(20)
        button:SetWidth(160)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20 * (i-1))
        
        -- Text for player name
        local text = button:CreateFontString(nil, "OVERLAY")
        text:SetFontObject("GameFontHighlight")
        text:SetPoint("LEFT", button, "LEFT", 5, 0)
        text:SetWidth(155)
        text:SetJustifyH("LEFT")
        button.text = text
        
        -- Highlight on mouse over
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.2)
        button.highlight = highlight
        
        button:Hide()
        frame.buttons[i] = button
    end
    
    return frame
end

-- Use cached player names for maximum performance
local function GetPlayerNames(searchText)
    local results = {}
    local count = 0
    searchText = string.lower(searchText or "")
    
    -- Iterate through our cached player names (much more efficient)
    for name, priority in pairs(cachedPlayerNames) do
        -- Check if name matches search text
        if searchText == "" or string.find(string.lower(name), searchText, 1, true) then
            count = count + 1
            results[count] = {name = name, priority = priority}
        end
    end
    -- Sort results using a named function to avoid creating closures
    -- We sort in reverse order so higher priority values are at the top
    table.sort(results, SortPlayersByPriority)
    
    -- Only return top MAX_SUGGESTIONS results
    local finalResults = {}
    for i = 1, math.min(MAX_SUGGESTIONS, #results) do
        finalResults[i] = results[i]
    end
    
    return finalResults
end

-- Select the name at the given index
local function SelectName(editBox, index)
    -- Make sure index is valid
    if index < 1 or index > #currentMatches then return end
    
    -- Replace with the selected match, but remove the prefix
    local text = editBox:GetText() or ""
    local pattern = currentPrefix .. "[^%s]*"
    
    -- Check for secure command to avoid taint issues
    local firstWord = string.match(text, "^(/[^ ]+)") or ""
    local isSecure = firstWord:find("/cast") or firstWord:find("/use") or 
                   firstWord:find("/target") or firstWord:find("/tar") or 
                   firstWord:find("/focus") or firstWord:find("/click")
    
    if isSecure then
        -- For secure commands, don't auto-replace text - could cause taint
        autocompleteFrame:Hide()
        return
    end
    
    -- Insert the name without the prefix
    local newText = string.gsub(text, pattern, currentMatches[index].name .. " ")
    editBox:SetText(newText)
    editBox:SetCursorPosition(#newText)
    
    -- Hide the autocomplete frame
    if autocompleteFrame then autocompleteFrame:Hide() end
end

-- No explicit up/down navigation due to key binding conflicts in WoW UI

-- Accept the currently selected suggestion (used by tab completion)
local function AcceptSelection(editBox)
    if not autocompleteFrame or not autocompleteFrame:IsShown() or #currentMatches == 0 then return false end
    
    -- Select the name at the current index
    SelectName(editBox, selectedIndex)
    return true
end

-- Update the autocomplete dropdown with player names
local function UpdateAutocomplete(editBox, searchText)
    if not autocompleteFrame then
        autocompleteFrame = CreateAutocompleteFrame()
    end
    
    -- If searchText is provided, get new matches
    if searchText ~= nil then
        -- Get matching player names
        currentMatches = GetPlayerNames(searchText)
        selectedIndex = 1 -- Reset selection to top when getting new matches
    end
    
    -- If no matches, hide frame and return
    if #currentMatches == 0 then
        autocompleteFrame:Hide()
        return
    end
    
    -- Calculate frame position - above or below edit box depending on screen position
    autocompleteFrame:ClearAllPoints()
    
    -- Get screen dimensions and editBox position
    local _, edgeBottom = editBox:GetCenter()
    local screenHeight = GetScreenHeight()
    local height = math.min(#currentMatches * 20, MAX_SUGGESTIONS * 20)
    
    -- Determine if there's enough space below the edit box
    if edgeBottom < (screenHeight * 0.3) then
        -- Not enough space below, position above
        autocompleteFrame:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 5)
    else
        -- Enough space below, position below
        autocompleteFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -5)
    end
    
    -- Update height based on number of players
    autocompleteFrame:SetHeight(height)
    
    -- Update and show buttons
    for i = 1, MAX_SUGGESTIONS do
        local button = autocompleteFrame.buttons[i]
        if i <= #currentMatches then
            button.text:SetText(currentMatches[i].name)
            
            -- Use the same highlight style that was created during button initialization
            -- for both tab selection and mouseover
            if i == selectedIndex then
                -- Selected button - use a simple background color for selection
                local selectionBg = button.selectionBg or button:CreateTexture(nil, "BACKGROUND")
                if not button.selectionBg then
                    selectionBg:SetAllPoints()
                    selectionBg:SetColorTexture(1, 1, 1, 0.2) -- Same style as mouseover
                    button.selectionBg = selectionBg
                end
                button.selectionBg:Show()
                -- Change text color to yellow when highlighted
                button.text:SetTextColor(1, 1, 0) -- Yellow text
                button:SetAlpha(1.0)
            else
                -- Not selected - hide selection background
                if button.selectionBg then
                    button.selectionBg:Hide()
                end
                -- Reset text color to default white
                button.text:SetTextColor(1, 1, 1) -- Default white text
                button:SetAlpha(0.85)
            end
            
            button:SetScript("OnClick", function()
                -- Replace the search text with the player name
                SelectName(editBox, i)
            end)
            
            -- Update mouseover behavior to change selection
            button:SetScript("OnEnter", function()
                selectedIndex = i
                UpdateAutocomplete(editBox)
            end)
            
            button:Show()
        else
            button:Hide()
        end
    end
    
    autocompleteFrame:Show()
end

-- Process chat box text and show mention dropdown
local function ProcessChatText(editBox)
    -- Get current text and cursor position
    local text = editBox:GetText() or ""
    local cursorPos = editBox:GetCursorPosition()
    
    -- Don't proceed if the text is too short
    if #text < 1 or cursorPos < 1 then 
        if autocompleteFrame then autocompleteFrame:Hide() end
        return 
    end
    
    -- Get text up to cursor position
    local textBeforeCursor = string.sub(text, 1, cursorPos)
    
    -- Look for the mention prefix at the end of the text
    local lastWord = string.match(textBeforeCursor, "[^ ]+$") or ""
    
    -- If it doesn't start with our prefix, hide dropdown and return
    if string.sub(lastWord, 1, #currentPrefix) ~= currentPrefix then
        if autocompleteFrame then autocompleteFrame:Hide() end
        return
    end
    
    -- Extract the search text after the prefix
    local searchText = string.sub(lastWord, #currentPrefix + 1)
    
    -- Update autocomplete with the search text
    UpdateAutocomplete(editBox, searchText)
end

-- Cycle through the list of suggestions when Tab is pressed
local function CycleTabCompletion(editBox)
    -- If autocomplete is visible, cycle to next item
    if autocompleteFrame and autocompleteFrame:IsShown() and #currentMatches > 0 then
        -- Move selection to next item
        selectedIndex = selectedIndex + 1
        if selectedIndex > #currentMatches then selectedIndex = 1 end
        
        -- Update the highlighting
        UpdateAutocomplete(editBox)
        return true
    end
    
    -- If no dropdown is visible yet, check if we're typing a name with prefix
    local text = editBox:GetText() or ""
    local cursorPos = editBox:GetCursorPosition()
        
    -- Check if we're in the middle of mentioning someone
    local textBeforeCursor = string.sub(text, 1, cursorPos)
    local lastWord = string.match(textBeforeCursor, "[^ ]+$") or ""
    
    -- If it doesn't start with our prefix, don't tab complete
    if string.sub(lastWord, 1, #currentPrefix) ~= currentPrefix then
        return false
    end
    
    -- Extract the search text after the prefix
    local searchText = string.sub(lastWord, #currentPrefix + 1)
    
    -- Get matching player names and show dropdown
    UpdateAutocomplete(editBox, searchText)
    
    -- If we got matches, return true to indicate we handled the tab
    if autocompleteFrame and autocompleteFrame:IsShown() then
        return true
    end
    
    return false
end

-- Add an Enter keybinding to select the current name
local function AddNameSelectionKeybind(editBox)
    -- Create a special keybinding frame for this edit box if it doesn't exist
    if not editBox.mentionKeybindFrame then
        editBox.mentionKeybindFrame = CreateFrame("Frame", nil, editBox)
        editBox.mentionKeybindFrame:SetAllPoints()
        editBox.mentionKeybindFrame:EnableKeyboard(true)
        editBox.mentionKeybindFrame:SetPropagateKeyboardInput(true)
        
        -- Store the original script so we can restore it
        editBox.originalOnEnterPressed = editBox:GetScript("OnEnterPressed")
    end
    
    -- Update the OnEnterPressed script to handle our dropdown
    editBox:SetScript("OnEnterPressed", function(self)
        -- If dropdown is visible, select name and don't send message
        if autocompleteFrame and autocompleteFrame:IsShown() and #currentMatches > 0 then
            SelectName(self, selectedIndex)
            -- No need to call original handler - we want to prevent sending
            return -- Explicitly return (don't send message)
        else
            -- Normal enter behavior - call original if it exists
            if autocompleteFrame then autocompleteFrame:Hide() end
            
            -- Call original handler if available
            if self.originalOnEnterPressed then
                self.originalOnEnterPressed(self)
            end
        end
    end)
    
    -- Add key handling for custom keys that don't conflict with chat
    editBox.mentionKeybindFrame:SetScript("OnKeyDown", function(_, key)
        -- Implement special key handling without using arrow keys
        if key == "SPACE" and IsControlKeyDown() then
            -- Ctrl+Space selects current name
            if autocompleteFrame and autocompleteFrame:IsShown() and #currentMatches > 0 then
                SelectName(editBox, selectedIndex)
                return
            end
        end
        
        -- Let other keys pass through to normal handling
        editBox.mentionKeybindFrame:SetPropagateKeyboardInput(true)
    end)
    
    -- Add classic handlers for various states
    editBox:HookScript("OnTabPressed", function(self)
        -- If we handle the tab press, return true to prevent default tab completion
        if CycleTabCompletion(self) then
            return true
        end
    end)
    
    -- Hide autocomplete when edit box is hidden or escape is pressed
    editBox:HookScript("OnHide", function()
        if autocompleteFrame then autocompleteFrame:Hide() end
    end)
    
    editBox:HookScript("OnEscapePressed", function()
        if autocompleteFrame then autocompleteFrame:Hide() end
    end)
end

-- Hook special key handlers for tab completion and enter selection
local function HookSpecialKeys(editBox)
    AddNameSelectionKeybind(editBox)
end

-- Hook into all chat edit boxes
local function HookChatFrames()
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame"..i]
        if chatFrame and chatFrame.editBox then
            local editBox = chatFrame.editBox
            
            -- Hook the OnTextChanged event
            editBox:HookScript("OnTextChanged", function(self)
                ProcessChatText(self)
            end)
            
            -- Hook the special key handlers
            HookSpecialKeys(editBox)
        end
    end
end

-- Check if a message contains the player's name and play a sound if it does
local function CheckMessageForNameMention(message, sender)
    -- Don't play a sound for your own messages
    if sender == UnitName("player") then return end
    
    -- Get player name
    local playerName = UnitName("player")
    if not playerName then return end
    
    -- Check if message contains player name as a whole word
    -- Use pattern matching to find the name with word boundaries
    local pattern = "%f[%a]" .. playerName .. "%f[^%a]"
    if string.find(message, pattern) then
        -- Play sound if enabled
        if soundEnabled and currentSound and currentSound ~= "" then
            PlaySoundFile(currentSound, "Master")
        end
    end
end

-- Hook all chat frames to monitor for mentions
local function HookChatFramesForNameMention()
    -- Hook all relevant chat events
    local chatEvents = {
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER"
    }
    
    for i = 1, #chatEvents do
        local event = chatEvents[i]
        MentionFrame:RegisterEvent(event)
    end
end

-- Get available sounds
local function GetAvailableSounds()
    local sounds = {}
    
    -- Add our default sounds
    for name, path in pairs(defaultSounds) do
        sounds[name] = path
    end
    
    -- Add WeakAuras sounds if available
    if WeakAuras and WeakAuras.sound_types then
        for name, path in pairs(WeakAuras.sound_types) do
            if type(path) == "string" then
                sounds[name] = path
            end
        end
    end
    
    return sounds
end

-- Register events
MentionFrame:RegisterEvent("ADDON_LOADED")
MentionFrame:RegisterEvent("PLAYER_LOGIN")

-- Event handler
MentionFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    if event == "ADDON_LOADED" and arg1 == addonName then
        self:OnLoad()
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            -- Request guild roster update (for Classic)
            if IsInGuild() then
                GuildRoster()
            end
            -- Initialize player names and hook chat frames
            HookChatFrames()
            HookChatFramesForNameMention()
        end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Group composition changed, update cached player names
        UpdateGroupRoster()
    elseif event == "GUILD_ROSTER_UPDATE" then
        -- Guild roster updated, refresh cached guild members
        UpdateGuildRoster()
    -- Process chat messages for name mentions
    elseif event:find("CHAT_MSG_") then
        local message = arg1
        local sender = arg2
        CheckMessageForNameMention(message, sender)
    end
end)

-- Expose functions for options panel
local function SetPrefix(prefix)
    if prefix and prefix ~= "" then
        currentPrefix = prefix
        MentionDB.prefix = prefix
        print("|cff00ff00Mention:|r Prefix updated to: " .. prefix)
    end
end

local function GetPrefix()
    return currentPrefix
end

-- Sound functions for options panel
local function EnableSound(enable)
    soundEnabled = enable
    MentionDB.soundEnabled = enable
    if enable then
        print("|cff00ff00Mention:|r Sound notifications enabled")
    else
        print("|cff00ff00Mention:|r Sound notifications disabled")
    end
end

local function IsSoundEnabled()
    return soundEnabled
end

local function SetSound(soundPath)
    currentSound = soundPath
    MentionDB.sound = soundPath
    -- Play a preview of the sound
    if soundPath and soundPath ~= "" then
        PlaySoundFile(soundPath, "Master")
        print("|cff00ff00Mention:|r Sound updated")
    else
        print("|cff00ff00Mention:|r Sound disabled")
    end
end

local function GetSound()
    return currentSound
end

local function GetSoundList()
    return GetAvailableSounds()
end

-- Add functions to the addon namespace only
-- This avoids global namespace pollution
addon.SetPrefix = SetPrefix
addon.GetPrefix = GetPrefix
addon.EnableSound = EnableSound
addon.IsSoundEnabled = IsSoundEnabled
addon.SetSound = SetSound
addon.GetSound = GetSound
addon.GetSoundList = GetSoundList

-- Slash command for controlling the addon
SLASH_MENTION1 = "/mention"
SlashCmdList["MENTION"] = function(msg)
    if msg == "debug" then
        print("|cff00ff00Mention Debug:|r")
        print("Current prefix: " .. currentPrefix)
        print("Saved prefix: " .. (MentionDB and MentionDB.prefix or "nil"))
        print("Sound enabled: " .. (soundEnabled and "Yes" or "No"))
        print("Current sound: " .. (currentSound or "None"))
    elseif msg:match("^prefix (.+)$") then
        local newPrefix = msg:match("^prefix (.+)$")
        addon.SetPrefix(newPrefix)
    elseif msg == "sound on" then
        addon.EnableSound(true)
    elseif msg == "sound off" then
        addon.EnableSound(false)
    elseif msg:match("^sound (.+)$") then
        local soundName = msg:match("^sound (.+)$")
        local sounds = GetAvailableSounds()
        local found = false
        
        -- Check if it's a valid sound name
        for name, path in pairs(sounds) do
            if name:lower() == soundName:lower() then
                addon.SetSound(path)
                found = true
                break
            end
        end
        
        if not found then
            print("|cff00ff00Mention:|r Unknown sound '" .. soundName .. "'. Use '/mention sounds' to see available sounds.")
        end
    elseif msg == "sounds" then
        print("|cff00ff00Available Mention Sounds:|r")
        local sounds = GetAvailableSounds()
        for name, _ in pairs(sounds) do
            print(" - " .. name)
        end
    elseif msg == "options" or msg == "config" then
        -- Show the options panel
        InterfaceOptionsFrame_OpenToCategory(addonName)
        InterfaceOptionsFrame_OpenToCategory(addonName) -- Call twice to ensure it opens
    elseif msg == "help" then
        -- Detailed help command
        print("|cff00ff00Mention - Help Guide|r")
        print("\n|cffFFD100Basic Usage:|r")
        print("Type " .. currentPrefix .. "name in chat to mention players. Example: " .. currentPrefix .. "john")
        print("As you type, a dropdown will appear with matching player names.")
        print("Press Tab to cycle through available names.")
        print("Press Enter to select the highlighted name (without sending the message).")
        print("When a player's name is mentioned in chat, a sound will play (if enabled).")
        
        print("\n|cffFFD100Sound Notifications:|r")
        print("Mention can play a sound when your name is mentioned in chat.")
        print("Use /mention sound on|off to enable/disable sounds.")
        print("Use /mention sound NAME to set a specific sound.")
        print("Use /mention sounds to see all available sounds.")
        
        print("\n|cffFFD100Configuration:|r")
        print("Use /mention options to open the configuration panel.")
        print("You can change the prefix symbol (default: " .. currentPrefix .. ") and sound settings.")
        
        print("\n|cffFFD100Commands:|r")
        print("/mention help - Show this help message")
        print("/mention prefix X - Change mention prefix to X")
        print("/mention sound on|off - Enable/disable sound notifications")
        print("/mention sound NAME - Set notification sound")
        print("/mention sounds - List available sounds")
        print("/mention options - Open options panel")
        print("/mention debug - Show diagnostic information")
    else
        print("|cff00ff00Mention Commands:|r")
        print("/mention help - Show detailed help information")
        print("/mention prefix X - Change mention prefix to X")
        print("/mention sound on|off - Enable/disable sound notifications")
        print("/mention sound NAME - Set notification sound")
        print("/mention sounds - List available sounds")
        print("/mention options - Open options panel")
    end
end
