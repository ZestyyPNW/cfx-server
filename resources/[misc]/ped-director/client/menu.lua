-- RageUI Menu Implementation for Ped Director

-- Ensure RageUI components are available
if not Panels then
    Panels = {} -- Fallback definition
    print("[ped-director] Panels not found, using fallback")
end

-- State variables for Emote Menu
local EmoteStartIndex = 1
local EmotePerPage = 15
local EmoteList = {}

-- Polyfills & Dependencies
function string.starts(String, Start)
   return string.sub(String, 1, string.len(Start)) == Start
end

if not math.round then
    function math.round(num, numDecimalPlaces)
        local mult = 10^(numDecimalPlaces or 0)
        return math.floor(num * mult + 0.5) / mult
    end
end

-- Define RMenu wrapper locally if it's not global
if not RMenu then
    RMenu = {}
    RMenu.Menus = {}

    function RMenu.Add(Type, Name, Menu)
        if not RMenu.Menus[Type] then
            RMenu.Menus[Type] = {}
        end
        RMenu.Menus[Type][Name] = Menu
    end

    function RMenu:Get(Type, Name)
        if self.Menus[Type] then
            return self.Menus[Type][Name]
        end
        return nil
    end
end

-- Notification helper needed in menu.lua as well
function Notify(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, true)
end

-- Initialization function to ensure RageUI is loaded
local function InitializeMenus()
    if RMenu:Get('ped_director', 'main') then return end -- Already initialized

    print("[ped-director] Initializing RageUI menus...")
    RMenu.Add('ped_director', 'main', RageUI.CreateMenu("Ped Director", "Main Menu"))
    RMenu.Add('ped_director', 'manage_peds', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'main'), "Manage Peds", "Select a ped to control"))
    RMenu.Add('ped_director', 'presets', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'main'), "Presets", "Save and load presets"))
    RMenu.Add('ped_director', 'ped_options', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'manage_peds'), "Ped Options", "Control specific ped"))
    RMenu.Add('ped_director', 'positioning', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'ped_options'), "Positioning", "Precise manipulation"))
    RMenu.Add('ped_director', 'clothing', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'ped_options'), "Clothing", "Customize appearance"))
    RMenu.Add('ped_director', 'clothing_edit', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'clothing'), "Edit Component", "Change drawable and texture"))
    RMenu.Add('ped_director', 'emotes', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'ped_options'), "Emotes", "Select an animation"))
    RMenu.Add('ped_director', 'walking_styles', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'ped_options'), "Walking Styles", "Set movement style"))
    RMenu.Add('ped_director', 'weapons', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'ped_options'), "Weapons", "Give weapon"))
    RMenu.Add('ped_director', 'scene_director', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'main'), "Scene Director", "Advanced scene control"))
    RMenu.Add('ped_director', 'actor_slots', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'scene_director'), "Actor Slots", "Manage actor assignments"))
    RMenu.Add('ped_director', 'global_actions', RageUI.CreateSubMenu(RMenu:Get('ped_director', 'scene_director'), "Global Actions", "Apply to all peds"))
    print("[ped-director] Menus initialized")
end

local SelectedPedIndex = nil
local SelectedPedEntity = nil
local SelectedComponent = nil -- {label, id}
local EmoteSearchText = ""
local NudgeAmount = 0.1 -- Default nudge step
local MovementModeRelative = true -- Toggle for relative vs world movement
local PendingGoBack = false
local KeepClothingCamThisFrame = false

Emotes = Emotes or {}

-- Walking Styles List
local WalkingStyles = {
    {label = "Default", value = "move_m@casual@d"},
    {label = "Gangster", value = "move_m@gangster@var_i"},
    {label = "Posh", value = "move_m@posh@person_a"},
    {label = "Tough", value = "move_m@tough_guy@"},
    {label = "Sexy", value = "move_f@sexy@a"},
    {label = "Drunk", value = "move_m@drunk@a"},
    {label = "Injured", value = "move_m@injured"},
    {label = "Cop", value = "move_m@business@b"},
}

-- Weapons List
local Weapons = {
    {label = "Pistol", value = "WEAPON_PISTOL"},
    {label = "Combat Pistol", value = "WEAPON_COMBATPISTOL"},
    {label = "Assault Rifle", value = "WEAPON_ASSAULTRIFLE"},
    {label = "Carbine Rifle", value = "WEAPON_CARBINERIFLE"},
    {label = "Pump Shotgun", value = "WEAPON_PUMPSHOTGUN"},
    {label = "Sniper Rifle", value = "WEAPON_SNIPERRIFLE"},
    {label = "Knife", value = "WEAPON_KNIFE"},
    {label = "Bat", value = "WEAPON_BAT"},
    {label = "Flashlight", value = "WEAPON_FLASHLIGHT"},
    {label = "Remove All", value = "REMOVE_ALL"},
}

-- Helper for Keyboard Input
local function KeyboardInput(text, example, maxLength)
    AddTextEntry('FMMC_KEY_TIP1', text)
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", example, "", "", "", maxLength)
    while UpdateOnscreenKeyboard() == 0 do
        Wait(0)
    end
    if GetOnscreenKeyboardResult() then
        return GetOnscreenKeyboardResult()
    end
    return nil
end

local function CountEmotes()
    local count = 0
    if Emotes then
        for _ in pairs(Emotes) do count = count + 1 end
    end
    return count
end

-- Helper to get sorted emote options
local function UpdateEmoteList()
    EmoteList = {}
    
    -- Ensure Emotes table is populated including PropEmotes
    if RP and (not Emotes or next(Emotes) == nil or CountEmotes() < 100) then
        Emotes = {}
        local function merge(target, source)
            if not source then return end
            for k,v in pairs(source) do target[k] = v end
        end
        merge(Emotes, RP.Emotes)
        merge(Emotes, RP.PropEmotes)
        merge(Emotes, RP.Dances)
        merge(Emotes, RP.Expressions)
        merge(Emotes, RP.Shared)
    end
    
    for k, v in pairs(Emotes) do
        local label = v[3] .. " (" .. k .. ")"
        if EmoteSearchText == "" or string.find(string.lower(label), string.lower(EmoteSearchText)) then
            table.insert(EmoteList, {
                value = k,
                label = label
            })
        end
    end
    table.sort(EmoteList, function(a, b) return a.label < b.label end)
end

-- Helper to get clothing max values
local function getClothingMax(ped, componentId)
    return GetNumberOfPedDrawableVariations(ped, componentId) - 1
end

local function getTextureMax(ped, componentId, drawableId)
    return GetNumberOfPedTextureVariations(ped, componentId, drawableId) - 1
end

local function QueueMenuGoBack()
    PendingGoBack = true
end

local function FocusClothingCamera(focusPart)
    if not SelectedPedEntity or not DoesEntityExist(SelectedPedEntity) then return end
    if FocusPedDirectorCamera then
        FocusPedDirectorCamera(SelectedPedEntity, focusPart or "Body")
        KeepClothingCamThisFrame = true
    end
end

local function BuildNumberLabelList(minValue, maxValue)
    local labels = {}
    local values = {}
    local minV = math.floor(tonumber(minValue) or 0)
    local maxV = math.floor(tonumber(maxValue) or minV)
    if maxV < minV then maxV = minV end

    for value = minV, maxV do
        labels[#labels + 1] = tostring(value)
        values[#values + 1] = value
    end

    return labels, values
end

local function FindListIndex(values, value)
    local target = tonumber(value) or 0
    for i = 1, #values do
        if values[i] == target then
            return i
        end
    end
    return 1
end

-- Main Loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        KeepClothingCamThisFrame = false
        
        -- Safe check for RageUI availability
        if RageUI and Items and Panels then
            local mainMenu = RMenu:Get('ped_director', 'main')
            if mainMenu then
                mainMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    
                    ItemsObject:AddButton("Spawn Ped", "Spawn a new ped by model name", {RightLabel = "→"}, function(Selected, Active)
                        if Selected then
                            local model = KeyboardInput("Enter Ped Model Name", "a_m_m_skater_01", 30)
                            if model then
                                ExecuteCommand('spawnped ' .. model)
                            end
                        end
                    end)

                    ItemsObject:AddButton("Manage Peds", "View and control spawned peds", {RightLabel = "→"}, function(Selected, Active)
                    end, RMenu:Get('ped_director', 'manage_peds'))

                    ItemsObject:AddButton("Delete All Peds", "Remove all spawned peds immediately", {RightLabel = "⚠️"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('clearallpeds')
                        end
                    end)
                    
                    ItemsObject:AddButton("Presets", "Save and load presets in-menu", {RightLabel = "→"}, function(Selected, Active)
                        if Selected and RefreshPedPresets then
                            RefreshPedPresets()
                        end
                    end, RMenu:Get('ped_director', 'presets'))

                    ItemsObject:AddButton("Scene Director", "Advanced scene control features", {RightLabel = "→"}, function(Selected, Active)
                    end, RMenu:Get('ped_director', 'scene_director'))
                end, function() end)
            end

            local presetsMenu = RMenu:Get('ped_director', 'presets')
            if presetsMenu then
                presetsMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items

                    ItemsObject:AddButton("Refresh Presets", "Reload preset list from server", {RightLabel = "↻"}, function(Selected, Active)
                        if Selected then
                            if RefreshPedPresets then
                                RefreshPedPresets()
                                Notify("Preset list refreshed.")
                            else
                                Notify("Preset refresh unavailable.")
                            end
                        end
                    end)

                    ItemsObject:AddButton("Save Nearest Ped As...", "Save the nearest spawned ped to a named preset", {RightLabel = "💾"}, function(Selected, Active)
                        if Selected then
                            local presetName = KeyboardInput("Enter Preset Name", "", 24)
                            if not presetName or presetName == "" then
                                Notify("Preset name required.")
                                return
                            end

                            if GetClosestSpawnedPed and SavePedPreset then
                                local ped = GetClosestSpawnedPed(10.0)
                                if ped then
                                    SavePedPreset(ped, presetName)
                                else
                                    Notify("No ped found nearby to save.")
                                end
                            else
                                Notify("Preset save unavailable.")
                            end
                        end
                    end)

                    ItemsObject:AddSeparator("Saved Presets")
                    local presetNames = {}
                    if GetSavedPresetNames then
                        presetNames = GetSavedPresetNames()
                    end

                    if #presetNames == 0 then
                        ItemsObject:AddSeparator("No presets found.")
                    else
                        for _, presetName in ipairs(presetNames) do
                            ItemsObject:AddButton(presetName, "Spawn this preset near you", {RightLabel = "Load"}, function(Selected, Active)
                                if Selected then
                                    if LoadPedPreset then
                                        LoadPedPreset(presetName)
                                    else
                                        Notify("Preset load unavailable.")
                                    end
                                end
                            end)
                        end
                    end
                end, function() end)
            end

            local managePedsMenu = RMenu:Get('ped_director', 'manage_peds')
            if managePedsMenu then
                managePedsMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if SpawnedPeds and #SpawnedPeds > 0 then
                        for i, ped in ipairs(SpawnedPeds) do
                            if DoesEntityExist(ped) then
                                local coords = GetEntityCoords(ped)
                                local dist = #(GetEntityCoords(PlayerPedId()) - coords)
                                local label = string.format("Ped %d | %s | %.1fm", i, GetEntityModel(ped), dist)
                                
                                ItemsObject:AddButton(label, "Click to control this ped", {RightLabel = "→"}, function(Selected, Active)
                                    if Selected then
                                        SelectedPedIndex = i
                                        SelectedPedEntity = ped
                                    end
                                end, RMenu:Get('ped_director', 'ped_options'))
                            end
                        end
                    else
                        ItemsObject:AddSeparator("No peds spawned.")
                    end
                end, function() end)
            end

            local pedOptionsMenu = RMenu:Get('ped_director', 'ped_options')
            if pedOptionsMenu then
                pedOptionsMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if not SelectedPedEntity or not DoesEntityExist(SelectedPedEntity) then
                        ItemsObject:AddSeparator("Ped no longer exists.")
                    else
                        -- Updated Play Emote Logic: Opens Submenu, refreshes list on selection
                        ItemsObject:AddButton("Play Emote", "Search and play an animation", {RightLabel = "→"}, function(Selected, Active)
                            if Selected then
                                UpdateEmoteList() -- Refresh list on open
                            end
                        end, RMenu:Get('ped_director', 'emotes'))

                        -- Follow Me Checkbox Replacement
                        local isFollowing = FollowPeds and FollowPeds[SelectedPedEntity]
                        local followLabel = isFollowing and "Follow Me [x]" or "Follow Me [ ]"
                        ItemsObject:AddButton(followLabel, "Make the ped follow you", {}, function(Selected, Active)
                            if Selected then
                                TogglePedFollow(SelectedPedEntity)
                            end
                        end)

                        ItemsObject:AddButton("Move to Me", "Teleport ped to your location", {}, function(Selected, Active)
                            if Selected then
                                local pCoords = GetEntityCoords(PlayerPedId())
                                SetEntityCoords(SelectedPedEntity, pCoords.x + 1.0, pCoords.y, pCoords.z - 1.0, false, false, false, true)
                            end
                        end)
                        
                        ItemsObject:AddButton("Walk to Waypoint", "Make ped walk to map waypoint", {}, function(Selected, Active)
                            if Selected then
                                MakePedWalkToWaypoint(SelectedPedEntity)
                            end
                        end)
                        
                        ItemsObject:AddButton("Positioning Tools", "Simple move/rotate controls", {RightLabel = "→"}, function(Selected, Active)
                        end, RMenu:Get('ped_director', 'positioning'))

                        ItemsObject:AddButton("Place In Front of Me", "Move ped to stand in front of you", {}, function(Selected, Active)
                            if Selected then
                                local playerPed = PlayerPedId()
                                local target = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.5, -1.0)
                                SetEntityCoords(SelectedPedEntity, target.x, target.y, target.z, false, false, false, true)
                                SetEntityHeading(SelectedPedEntity, GetEntityHeading(playerPed) + 180.0)
                                if not IsEntityPositionFrozen(SelectedPedEntity) then
                                    TaskStandStill(SelectedPedEntity, 500)
                                end
                            end
                        end)

                        -- Frozen Checkbox Replacement
                        local isFrozen = IsEntityPositionFrozen(SelectedPedEntity)
                        local freezeLabel = "Frozen [ ]"
                        if isFrozen then freezeLabel = "Frozen [x]" end

                        ItemsObject:AddButton(freezeLabel, "Freeze/Unfreeze ped position", {}, function(Selected, Active)
                            if Selected then
                                FreezeEntityPosition(SelectedPedEntity, not isFrozen)
                            end
                        end)

                        ItemsObject:AddButton("Customize Clothing", "Change ped components", {RightLabel = "→"}, function(Selected, Active)
                        end, RMenu:Get('ped_director', 'clothing'))
                        
                        ItemsObject:AddButton("Walking Style", "Set movement clipset", {RightLabel = "→"}, function(Selected, Active)
                        end, RMenu:Get('ped_director', 'walking_styles'))
                        
                        ItemsObject:AddButton("Give Weapon", "Equip ped with weapon", {RightLabel = "→"}, function(Selected, Active)
                        end, RMenu:Get('ped_director', 'weapons'))

                        ItemsObject:AddButton("~r~Delete Ped", "Remove this ped", {}, function(Selected, Active)
                            if Selected then
                                DeleteEntity(SelectedPedEntity)
                                if SelectedPedIndex and SpawnedPeds[SelectedPedIndex] == SelectedPedEntity then
                                    table.remove(SpawnedPeds, SelectedPedIndex)
                                end
                                QueueMenuGoBack()
                            end
                        end)
                    end
                end, function() end)
            end
            
            -- Positioning Menu
            local posMenu = RMenu:Get('ped_director', 'positioning')
            if posMenu then
                posMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) then
                        local coords = GetEntityCoords(SelectedPedEntity)
                        local heading = GetEntityHeading(SelectedPedEntity)
                        
                        ItemsObject:AddSeparator(string.format("X: %.2f Y: %.2f Z: %.2f H: %.1f", coords.x, coords.y, coords.z, heading))
                        
                        ItemsObject:AddButton("Snap to Ground", "Place ped on solid ground", {}, function(Selected, Active)
                            if Selected then
                                SnapPedToGround(SelectedPedEntity)
                            end
                        end)
                        
                        ItemsObject:AddSeparator("Nudge Settings")
                        
                        -- Toggle Movement Mode
                        local relLabel = MovementModeRelative and "Relative Movement [x]" or "Relative Movement [ ]"
                        ItemsObject:AddButton(relLabel, "Move relative to ped facing vs World North/South", {}, function(Selected, Active)
                            if Selected then
                                MovementModeRelative = not MovementModeRelative
                            end
                        end)

                        -- Nudge Amount Selector
                        local nudgeLabel = string.format("Step Size: %.2fm", NudgeAmount)
                        ItemsObject:AddButton(nudgeLabel, "Click to change step size", {}, function(Selected, Active)
                            if Selected then
                                if NudgeAmount == 0.05 then NudgeAmount = 0.1
                                elseif NudgeAmount == 0.1 then NudgeAmount = 0.5
                                elseif NudgeAmount == 0.5 then NudgeAmount = 1.0
                                else NudgeAmount = 0.05 end
                            end
                        end)
                        
                        ItemsObject:AddSeparator("Move")

                        ItemsObject:AddButton("Forward / North", "Move Forward (Relative) or North (World)", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, 0.0, NudgeAmount, 0.0, 0.0, MovementModeRelative) end
                        end)
                        
                        ItemsObject:AddButton("Backward / South", "Move Backward (Relative) or South (World)", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, 0.0, -NudgeAmount, 0.0, 0.0, MovementModeRelative) end
                        end)
                        
                        ItemsObject:AddButton("Left / West", "Move Left (Relative) or West (World)", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, -NudgeAmount, 0.0, 0.0, 0.0, MovementModeRelative) end
                        end)
                        
                        ItemsObject:AddButton("Right / East", "Move Right (Relative) or East (World)", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, NudgeAmount, 0.0, 0.0, 0.0, MovementModeRelative) end
                        end)
                        
                        ItemsObject:AddButton("Up", "Move up", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, 0.0, 0.0, NudgeAmount, 0.0, false) end
                        end)

                        ItemsObject:AddButton("Down", "Move down", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, 0.0, 0.0, -NudgeAmount, 0.0, false) end
                        end)

                        ItemsObject:AddSeparator("Rotate")

                        ItemsObject:AddButton("Rotate Left", "Rotate Counter-Clockwise", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, 0.0, 0.0, 0.0, 5.0, MovementModeRelative) end
                        end)

                        ItemsObject:AddButton("Rotate Right", "Rotate Clockwise", {}, function(Selected, Active)
                            if Selected then AdjustPedOffset(SelectedPedEntity, 0.0, 0.0, 0.0, -5.0, MovementModeRelative) end
                        end)
                        
                        ItemsObject:AddSeparator("Absolute")
                        ItemsObject:AddButton("Place In Front of Me", "Instantly position in front of you", {}, function(Selected, Active)
                            if Selected then
                                local playerPed = PlayerPedId()
                                local target = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.5, -1.0)
                                SetEntityCoords(SelectedPedEntity, target.x, target.y, target.z, false, false, false, true)
                                SetEntityHeading(SelectedPedEntity, GetEntityHeading(playerPed) + 180.0)
                            end
                        end)
                        
                        ItemsObject:AddButton("Set Coordinates manually", "Enter X, Y, Z", {}, function(Selected, Active)
                            if Selected then
                                local input = KeyboardInput("Enter X, Y, Z", string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z), 50)
                                if input then
                                    local x, y, z = string.match(input, "([^,]+),%s*([^,]+),%s*([^,]+)")
                                    if x and y and z then
                                        SetEntityCoords(SelectedPedEntity, tonumber(x), tonumber(y), tonumber(z), false, false, false, true)
                                    else
                                        Notify("Invalid format. Use X, Y, Z")
                                    end
                                end
                            end
                        end)

                    end
                end, function() end)
            end

            -- Walking Styles Menu
            local walkingMenu = RMenu:Get('ped_director', 'walking_styles')
            if walkingMenu then
                walkingMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) then
                        for _, style in ipairs(WalkingStyles) do
                            ItemsObject:AddButton(style.label, "", {RightLabel = ""}, function(Selected, Active)
                                if Selected then
                                    SetPedWalkingStyle(SelectedPedEntity, style.value)
                                end
                            end)
                        end
                    end
                end, function() end)
            end
            
            -- Weapons Menu
            local weaponsMenu = RMenu:Get('ped_director', 'weapons')
            if weaponsMenu then
                weaponsMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) then
                        for _, weapon in ipairs(Weapons) do
                            ItemsObject:AddButton(weapon.label, "", {RightLabel = ""}, function(Selected, Active)
                                if Selected then
                                    if weapon.value == "REMOVE_ALL" then
                                        RemoveAllPedWeapons(SelectedPedEntity)
                                    else
                                        GivePedWeapon(SelectedPedEntity, weapon.value)
                                    end
                                end
                            end)
                        end
                    end
                end, function() end)
            end

            -- Emote Selection Menu
            local emoteMenu = RMenu:Get('ped_director', 'emotes')
            if emoteMenu then
                emoteMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    
                    ItemsObject:AddButton("Search...", "Filter emotes by name (" .. EmoteSearchText .. ")", {RightLabel = "🔍"}, function(Selected, Active)
                        if Selected then
                            local text = KeyboardInput("Search Emotes", "", 20)
                            if text then
                                EmoteSearchText = text
                                UpdateEmoteList()
                            end
                        end
                    end)

                    -- Browse emotes functionality
                    local MaxPage = math.max(1, math.ceil(#EmoteList / EmotePerPage))
                    -- Ensure start index is valid
                    if EmoteStartIndex > #EmoteList and #EmoteList > 0 then EmoteStartIndex = 1 end
                    
                    ItemsObject:AddButton("Page " .. math.ceil(EmoteStartIndex/EmotePerPage) .. "/" .. MaxPage, "Next page", {RightLabel = "🔄"}, function(Selected, Active)
                        if Selected then
                            EmoteStartIndex = EmoteStartIndex + EmotePerPage
                            if EmoteStartIndex > #EmoteList then EmoteStartIndex = 1 end
                        end
                    end)

                    local EndIndex = math.min(EmoteStartIndex + EmotePerPage - 1, #EmoteList)

                    if #EmoteList > 0 then
                        for i = EmoteStartIndex, EndIndex do
                            local emote = EmoteList[i]
                            if emote then
                                ItemsObject:AddButton(emote.label, "Play this emote", {RightLabel = "▶"}, function(Selected, Active)
                                    if Selected then
                                        TriggerEvent('ped-director:playEmoteOnPed', SelectedPedEntity, emote.value)
                                    end
                                end)
                            end
                        end
                        
                        -- Update page info
                        local DisplayInfo = ("Showing %d-%d of %d"):format(EmoteStartIndex, EndIndex, #EmoteList)
                        ItemsObject:AddSeparator(DisplayInfo)
                    else
                        ItemsObject:AddSeparator("No emotes found.")
                    end
                end, function() end)
            end

            -- Component Selection Menu
            local clothingMenu = RMenu:Get('ped_director', 'clothing')
            if clothingMenu then
                clothingMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) then
                        FocusClothingCamera("Body")
                        
                        ItemsObject:AddButton("Copy Player Outfit", "Copy your current outfit to this ped", {RightLabel = "👕"}, function(Selected, Active)
                            if Selected then
                                local playerPed = PlayerPedId()
                                local ped = SelectedPedEntity
                                
                                -- Check if models match (roughly)
                                if IsPedMale(playerPed) ~= IsPedMale(ped) then
                                    Notify("Warning: Gender mismatch. Outfit might look weird.")
                                end

                                -- Copy components
                                for i = 0, 11 do
                                    local drawable = GetPedDrawableVariation(playerPed, i)
                                    local texture = GetPedTextureVariation(playerPed, i)
                                    local palette = GetPedPaletteVariation(playerPed, i)
                                    SetPedComponentVariation(ped, i, drawable, texture, palette)
                                end

                                -- Copy props
                                local props = {0, 1, 2, 6, 7}
                                for _, propId in ipairs(props) do
                                    local propIndex = GetPedPropIndex(playerPed, propId)
                                    if propIndex ~= -1 then
                                        local propTexture = GetPedPropTextureIndex(playerPed, propId)
                                        SetPedPropIndex(ped, propId, propIndex, propTexture, true)
                                    else
                                        ClearPedProp(ped, propId)
                                    end
                                end
                                
                                Notify("Outfit copied!")
                            end
                        end)
                        ItemsObject:AddSeparator("Components")

                        local components = {
                            {label = 'Face', id = 0},
                            {label = 'Mask', id = 1},
                            {label = 'Hair', id = 2},
                            {label = 'Torso', id = 3},
                            {label = 'Legs', id = 4},
                            {label = 'Bags/Parachute', id = 5},
                            {label = 'Shoes', id = 6},
                            {label = 'Accessories', id = 7},
                            {label = 'Undershirt', id = 8},
                            {label = 'Kevlar', id = 9},
                            {label = 'Badge', id = 10},
                            {label = 'Torso 2', id = 11},
                            -- Props
                            {label = 'Hat/Helmet', id = 0, isProp = true},
                            {label = 'Glasses', id = 1, isProp = true},
                            {label = 'Ear Accessories', id = 2, isProp = true},
                            {label = 'Watches', id = 6, isProp = true},
                            {label = 'Bracelets', id = 7, isProp = true},
                        }

                        for _, comp in ipairs(components) do
                            local currentDrawable, currentTexture
                            if comp.isProp then
                                currentDrawable = GetPedPropIndex(SelectedPedEntity, comp.id)
                                currentTexture = GetPedPropTextureIndex(SelectedPedEntity, comp.id)
                            else
                                currentDrawable = GetPedDrawableVariation(SelectedPedEntity, comp.id)
                                currentTexture = GetPedTextureVariation(SelectedPedEntity, comp.id)
                            end
                            
                            ItemsObject:AddButton(comp.label, string.format("Draw: %d | Tex: %d", currentDrawable, currentTexture), {RightLabel = "→"}, function(Selected, Active)
                                if Selected then
                                    SelectedComponent = comp
                                end
                            end, RMenu:Get('ped_director', 'clothing_edit'))
                        end
                    end
                end, function() end)
            end

            -- Component Edit Menu
            local editMenu = RMenu:Get('ped_director', 'clothing_edit')
            if editMenu then
                editMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items
                    if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) and SelectedComponent then
                        FocusClothingCamera(SelectedComponent.label or "Body")
                        local ped = SelectedPedEntity
                        local comp = SelectedComponent
                        
                        local maxDrawable, currentDrawable, maxTexture, currentTexture
                        local minDrawable = 0

                        if comp.isProp then
                            minDrawable = -1
                            maxDrawable = GetNumberOfPedPropDrawableVariations(ped, comp.id) - 1
                            currentDrawable = GetPedPropIndex(ped, comp.id)
                            if currentDrawable == -1 then
                                maxTexture = 0
                                currentTexture = 0
                            else
                                maxTexture = GetNumberOfPedPropTextureVariations(ped, comp.id, currentDrawable) - 1
                                currentTexture = GetPedPropTextureIndex(ped, comp.id)
                            end
                        else
                            maxDrawable = getClothingMax(ped, comp.id)
                            currentDrawable = GetPedDrawableVariation(ped, comp.id)
                            maxTexture = getTextureMax(ped, comp.id, currentDrawable)
                            currentTexture = GetPedTextureVariation(ped, comp.id)
                        end

                        local function updateComp(d, t)
                            if comp.isProp then
                                if d == -1 then
                                    ClearPedProp(ped, comp.id)
                                else
                                    SetPedPropIndex(ped, comp.id, d, t, true)
                                end
                            else
                                SetPedClothing(ped, comp.id, d, t)
                            end
                        end

                        local drawableLabels, drawableValues = BuildNumberLabelList(minDrawable, maxDrawable)
                        local drawableIndex = FindListIndex(drawableValues, currentDrawable)
                        ItemsObject:AddList("Drawable", drawableLabels, drawableIndex, "Use left/right to change drawable.", {}, function(Index, Selected, onListChange, Active)
                            if onListChange then
                                local newDrawable = drawableValues[Index]
                                updateComp(newDrawable, 0)
                            end
                        end)

                        local safeMaxTexture = maxTexture
                        if safeMaxTexture < 0 then safeMaxTexture = 0 end
                        local textureLabels, textureValues = BuildNumberLabelList(0, safeMaxTexture)
                        local textureIndex = FindListIndex(textureValues, currentTexture)
                        local textureDesc = "Use left/right to change texture."
                        if comp.isProp and currentDrawable == -1 then
                            textureDesc = "Set a prop drawable first to edit textures."
                        end

                        ItemsObject:AddList("Texture", textureLabels, textureIndex, textureDesc, {}, function(Index, Selected, onListChange, Active)
                            if onListChange then
                                if comp.isProp and currentDrawable == -1 then
                                    return
                                end
                                local newTexture = textureValues[Index]
                                updateComp(currentDrawable, newTexture)
                            end
                        end)

                        if comp.isProp then
                            ItemsObject:AddButton("Clear Prop", "Remove this prop slot from the ped.", {}, function(Selected, Active)
                                if Selected then
                                    ClearPedProp(ped, comp.id)
                                end
                            end)
                        end

                    else
                        QueueMenuGoBack()
                    end
                end, function() end)
            end

            if PendingGoBack then
                PendingGoBack = false
                if RageUI and RageUI.GoBack and RageUI.CurrentMenu then
                    RageUI.GoBack()
                end
            end

            if not KeepClothingCamThisFrame and ClearPedDirectorCamera then
                ClearPedDirectorCamera()
            end
        end
    end
end)

-- Command to open menu
RegisterCommand('pedmenu', function()
    if not Graphics or not RageUI or not Items then
        Notify('RageUI or Items not loaded.')
        return
    end
    
    InitializeMenus()
    local mainMenu = RMenu:Get('ped_director', 'main')
    if mainMenu then
        RageUI.Visible(mainMenu, not RageUI.Visible(mainMenu))
    end
end)

-- Scene Director Submenus
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if RageUI and Items and Panels then
            -- Scene Director Menu
            local sceneDirectorMenu = RMenu:Get('ped_director', 'scene_director')
            if sceneDirectorMenu then
                sceneDirectorMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items

                    local modeText = SceneMode == "setup" and "SETUP" or "ACTIVE"
                    ItemsObject:AddButton("Scene Mode: " .. modeText, "Toggle between setup and active modes", {RightLabel = SceneMode == "setup" and "SETUP" or "ACTIVE"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('scenemode')
                        end
                    end)

                    ItemsObject:AddButton("Actor Slots", "Assign and manage ped slots", {RightLabel = "→"}, function(Selected, Active)
                    end, RMenu:Get('ped_director', 'actor_slots'))

                    ItemsObject:AddButton("Global Actions", "Apply actions to all peds", {RightLabel = "→"}, function(Selected, Active)
                    end, RMenu:Get('ped_director', 'global_actions'))

                    ItemsObject:AddButton("Possess Nearest", "Take control of nearest ped", {RightLabel = "👁️"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('possess')
                        end
                    end)

                    ItemsObject:AddButton("Clone Nearest", "Create a copy of nearest ped", {RightLabel = "📋"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('cloneped')
                        end
                    end)

                    ItemsObject:AddButton("Reset Scene", "Clear all slots and behaviors", {RightLabel = "🔄"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('scenereset')
                        end
                    end)

                    ItemsObject:AddButton("Teleport All", "Move all peds to waypoint", {RightLabel = "📍"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('teleportall')
                        end
                    end)

                    ItemsObject:AddButton("Add Stage Light", "Create light at current position", {RightLabel = "💡"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('addlight')
                        end
                    end)
                end)
            end

            -- Actor Slots Menu
            local actorSlotsMenu = RMenu:Get('ped_director', 'actor_slots')
            if actorSlotsMenu then
                actorSlotsMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items

                    for slot = 1, 9 do
                        local ped = ActorSlots[slot]
                        local label = "Slot " .. slot
                        if ped and DoesEntityExist(ped) then
                            label = label .. " (Occupied)"
                        else
                            label = label .. " (Empty)"
                        end

                        ItemsObject:AddButton(label, "Assign/swap to this slot", {RightLabel = ped and "SWAP" or "ASSIGN"}, function(Selected, Active)
                            if Selected then
                                if ped and DoesEntityExist(ped) then
                                    ExecuteCommand('swapslot ' .. slot)
                                else
                                    ExecuteCommand('assignslot ' .. slot)
                                end
                            end
                        end)
                    end
                end)
            end

            -- Global Actions Menu
            local globalActionsMenu = RMenu:Get('ped_director', 'global_actions')
            if globalActionsMenu then
                globalActionsMenu:IsVisible(function(ItemsObject)
                    ItemsObject = ItemsObject or Items

                    ItemsObject:AddButton("Waypoint All", "Set same waypoint for all peds", {RightLabel = "📍"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('waypointall')
                        end
                    end)

                    ItemsObject:AddButton("Emote All", "Apply emote to all peds", {RightLabel = "💃"}, function(Selected, Active)
                        if Selected then
                            local emote = KeyboardInput("Enter Emote Name", "", 30)
                            if emote then
                                ExecuteCommand('emoteall ' .. emote)
                            end
                        end
                    end)

                    ItemsObject:AddButton("Stop All", "Stop animations for all peds", {RightLabel = "⏹️"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('stopall')
                        end
                    end)

                    local chaseText = IsChasingPlayer and "Stop Chase" or "Start Chase"
                    ItemsObject:AddButton(chaseText, "Vehicle chase mode", {RightLabel = "🚗"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('pedchase')
                        end
                    end)

                    local escortText = IsEscortingPlayer and "Stop Escort" or "Start Escort"
                    ItemsObject:AddButton(escortText, "Vehicle escort mode", {RightLabel = "🚙"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('pedescort')
                        end
                    end)

                    ItemsObject:AddButton("Clear Stage Lights", "Remove all stage lights", {RightLabel = "🕯️"}, function(Selected, Active)
                        if Selected then
                            ExecuteCommand('removelight')
                        end
                    end)
                end)
            end
        end
    end
end)

-- Keybind
RegisterKeyMapping('pedmenu', 'Open Ped Director Menu', 'keyboard', 'F6')

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if RageUI and RageUI.CloseAll then
        RageUI.CloseAll()
    end
end)
