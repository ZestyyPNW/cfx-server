--[[
    Ped Director v2.0 - RageUI Menu
    SINGLE render loop. All menus drawn in one CreateThread(Wait(0)).
    Reads/writes state via the PedDir global table from client.lua.
]]

-- =============================================
-- RAGEUI LOADER
-- =============================================

local function TryLoadRageUI(resName)
    local files = {
        'src/RageUI.lua', 'src/Menu.lua', 'src/MenuController.lua',
        'src/components/Audio.lua', 'src/components/Graphics.lua',
        'src/components/Keys.lua', 'src/components/Util.lua', 'src/components/Visual.lua',
        'src/elements/ItemsBadge.lua', 'src/elements/ItemsColour.lua', 'src/elements/PanelColour.lua',
        'src/items/Items.lua', 'src/items/Panels.lua',
    }
    for _, path in ipairs(files) do
        local content = LoadResourceFile(resName, path)
        if type(content) ~= 'string' or content == '' then return false end
        local chunk, err = load(content, ('@@%s/%s'):format(resName, path))
        if not chunk then return false end
        chunk()
    end
    return RageUI ~= nil and Items ~= nil and Panels ~= nil
end

local function EnsureRageUI()
    if RageUI and Items and Panels then return true end
    if TryLoadRageUI('RageUI') then return true end
    return false
end

local function WaitForRageUI(timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 10000)
    while not (RageUI and Items and Panels) do
        EnsureRageUI()
        if GetGameTimer() > deadline then return false end
        Wait(100)
    end
    return true
end

-- =============================================
-- RMENU POLYFILL
-- =============================================

if not RMenu then
    RMenu = { Menus = {} }
    function RMenu.Add(_, Type, Name, Menu)
        RMenu.Menus[Type] = RMenu.Menus[Type] or {}
        RMenu.Menus[Type][Name] = Menu
    end
    function RMenu:Get(Type, Name)
        return self.Menus[Type] and self.Menus[Type][Name] or nil
    end
end

-- =============================================
-- POLYFILLS
-- =============================================

function string.starts(s, prefix)
    return s:sub(1, #prefix) == prefix
end

if not math.round then
    function math.round(num, dp)
        local mult = 10 ^ (dp or 0)
        return math.floor(num * mult + 0.5) / mult
    end
end

-- =============================================
-- LOCAL STATE
-- =============================================

local ALIVE = true
local MenusInitialized = false
local SelectedPedIndex = nil
local SelectedPedEntity = nil
local SelectedComponent = nil
local EmoteSearchText = ''
local EmoteStartIndex = 1
local EmotePerPage = 15
local EmoteList = {}
local NudgeAmount = 0.1
local MovementRelative = true
local PendingGoBack = false
local KeepClothCam = false

local WalkingStyles = {
    { label = 'Default',  value = 'move_m@casual@d' },
    { label = 'Gangster', value = 'move_m@gangster@var_i' },
    { label = 'Posh',     value = 'move_m@posh@person_a' },
    { label = 'Tough',    value = 'move_m@tough_guy@' },
    { label = 'Sexy',     value = 'move_f@sexy@a' },
    { label = 'Drunk',    value = 'move_m@drunk@a' },
    { label = 'Injured',  value = 'move_m@injured' },
    { label = 'Cop',      value = 'move_m@business@b' },
}

local Weapons = {
    { label = 'Pistol',         value = 'WEAPON_PISTOL' },
    { label = 'Combat Pistol',  value = 'WEAPON_COMBATPISTOL' },
    { label = 'Assault Rifle',  value = 'WEAPON_ASSAULTRIFLE' },
    { label = 'Carbine Rifle',  value = 'WEAPON_CARBINERIFLE' },
    { label = 'Pump Shotgun',   value = 'WEAPON_PUMPSHOTGUN' },
    { label = 'Sniper Rifle',   value = 'WEAPON_SNIPERRIFLE' },
    { label = 'Knife',          value = 'WEAPON_KNIFE' },
    { label = 'Bat',            value = 'WEAPON_BAT' },
    { label = 'Flashlight',     value = 'WEAPON_FLASHLIGHT' },
    { label = 'Remove All',     value = 'REMOVE_ALL' },
}

-- =============================================
-- HELPERS
-- =============================================

local function Notify(msg)
    if PedDir and PedDir.Notify then PedDir.Notify(msg) return end
    SetNotificationTextEntry('STRING')
    AddTextComponentString(tostring(msg))
    DrawNotification(false, true)
end

local function KeyboardInput(title, example, maxLen)
    AddTextEntry('FMMC_KEY_TIP1', title)
    DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP1', '', example, '', '', '', maxLen)
    while UpdateOnscreenKeyboard() == 0 do Wait(0) end
    return GetOnscreenKeyboardResult()
end

local function BuildNumberList(minVal, maxVal)
    local labels, values = {}, {}
    for v = math.floor(minVal), math.floor(maxVal) do
        labels[#labels + 1] = tostring(v)
        values[#values + 1] = v
    end
    return labels, values
end

local function FindListIndex(values, target)
    target = tonumber(target) or 0
    for i = 1, #values do
        if values[i] == target then return i end
    end
    return 1
end

local function UpdateEmoteList()
    EmoteList = {}
    local src = Emotes or {}
    for k, v in pairs(src) do
        local label = (v[3] or k) .. ' (' .. k .. ')'
        if EmoteSearchText == '' or string.find(string.lower(label), string.lower(EmoteSearchText)) then
            EmoteList[#EmoteList + 1] = { value = k, label = label }
        end
    end
    table.sort(EmoteList, function(a, b) return a.label < b.label end)
end

-- =============================================
-- MENU INITIALIZATION
-- =============================================

local function InitMenus()
    if MenusInitialized then return end
    if not RageUI or not RMenu then return end

    RMenu:Add('pd', 'main',          RageUI.CreateMenu('Ped Director', 'Main Menu'))
    RMenu:Add('pd', 'manage',        RageUI.CreateSubMenu(RMenu:Get('pd', 'main'),    'Manage Peds',    'Select a ped'))
    RMenu:Add('pd', 'presets',        RageUI.CreateSubMenu(RMenu:Get('pd', 'main'),    'Presets',        'Save and load'))
    RMenu:Add('pd', 'ped_opts',       RageUI.CreateSubMenu(RMenu:Get('pd', 'manage'),  'Ped Options',    'Control ped'))
    RMenu:Add('pd', 'positioning',    RageUI.CreateSubMenu(RMenu:Get('pd', 'ped_opts'), 'Positioning',   'Move & rotate'))
    RMenu:Add('pd', 'clothing',       RageUI.CreateSubMenu(RMenu:Get('pd', 'ped_opts'), 'Clothing',      'Customize'))
    RMenu:Add('pd', 'clothing_edit',  RageUI.CreateSubMenu(RMenu:Get('pd', 'clothing'), 'Edit Component','Drawable & texture'))
    RMenu:Add('pd', 'emotes',         RageUI.CreateSubMenu(RMenu:Get('pd', 'ped_opts'), 'Emotes',        'Animations'))
    RMenu:Add('pd', 'walks',          RageUI.CreateSubMenu(RMenu:Get('pd', 'ped_opts'), 'Walking Styles','Movement'))
    RMenu:Add('pd', 'weapons',        RageUI.CreateSubMenu(RMenu:Get('pd', 'ped_opts'), 'Weapons',       'Equip'))
    RMenu:Add('pd', 'scene',          RageUI.CreateSubMenu(RMenu:Get('pd', 'main'),    'Scene Director', 'Advanced'))
    RMenu:Add('pd', 'actor_slots',    RageUI.CreateSubMenu(RMenu:Get('pd', 'scene'),   'Actor Slots',    'Manage slots'))
    RMenu:Add('pd', 'global_actions', RageUI.CreateSubMenu(RMenu:Get('pd', 'scene'),   'Global Actions', 'All peds'))

    MenusInitialized = true
end

-- =============================================
-- SINGLE RENDER LOOP
-- =============================================

CreateThread(function()
    while ALIVE do
        Wait(0)
        KeepClothCam = false

        if not (RageUI and Items and Panels and MenusInitialized) then
            Wait(500)
            goto continue
        end

        -- MAIN MENU
        local mainMenu = RMenu:Get('pd', 'main')
        if mainMenu then
            mainMenu:IsVisible(function(I)
                I = I or Items
                I:AddButton('Spawn Ped', 'Spawn by model name', { RightLabel = '>' }, function(Sel)
                    if Sel then
                        local m = KeyboardInput('Ped Model', 'a_m_m_skater_01', 30)
                        if m then PedDir.SpawnPed(m) end
                    end
                end)
                I:AddButton('Manage Peds', 'View and control', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'manage'))
                I:AddButton('Delete All', 'Remove all peds', { RightLabel = '!' }, function(Sel)
                    if Sel then PedDir.DeleteAll(); Notify('All deleted') end
                end)
                I:AddButton('Presets', 'Save & load', { RightLabel = '>' }, function(Sel)
                    if Sel then PedDir.RefreshPresets() end
                end, RMenu:Get('pd', 'presets'))
                I:AddButton('Scene Director', 'Advanced features', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'scene'))
            end, function() end)
        end

        -- PRESETS MENU
        local presetsMenu = RMenu:Get('pd', 'presets')
        if presetsMenu then
            presetsMenu:IsVisible(function(I)
                I = I or Items
                I:AddButton('Refresh', 'Reload from server', {}, function(Sel)
                    if Sel then PedDir.RefreshPresets(); Notify('Refreshed') end
                end)
                I:AddButton('Save Nearest As...', 'Save nearest ped', {}, function(Sel)
                    if Sel then
                        local name = KeyboardInput('Preset Name', '', 24)
                        if not name or name == '' then return end
                        local ped = PedDir.GetClosest(10.0)
                        if ped then PedDir.SavePreset(ped, name) else Notify('No ped nearby') end
                    end
                end)
                I:AddSeparator('Saved Presets')
                local names = PedDir.GetPresetNames()
                if #names == 0 then
                    I:AddSeparator('None found')
                else
                    for _, n in ipairs(names) do
                        I:AddButton(n, 'Load this preset', { RightLabel = 'Load' }, function(Sel)
                            if Sel then PedDir.LoadPreset(n) end
                        end)
                    end
                end
            end, function() end)
        end

        -- MANAGE PEDS
        local manageMenu = RMenu:Get('pd', 'manage')
        if manageMenu then
            manageMenu:IsVisible(function(I)
                I = I or Items
                PedDir.Prune()
                if #PedDir.peds > 0 then
                    for i, ped in ipairs(PedDir.peds) do
                        if DoesEntityExist(ped) then
                            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))
                            local label = string.format('Ped %d | %.1fm', i, dist)
                            I:AddButton(label, 'Select', { RightLabel = '>' }, function(Sel)
                                if Sel then SelectedPedIndex = i; SelectedPedEntity = ped end
                            end, RMenu:Get('pd', 'ped_opts'))
                        end
                    end
                else
                    I:AddSeparator('No peds spawned')
                end
            end, function() end)
        end

        -- PED OPTIONS
        local pedOptsMenu = RMenu:Get('pd', 'ped_opts')
        if pedOptsMenu then
            pedOptsMenu:IsVisible(function(I)
                I = I or Items
                if not SelectedPedEntity or not DoesEntityExist(SelectedPedEntity) then
                    I:AddSeparator('Ped no longer exists')
                    return
                end
                local ped = SelectedPedEntity
                I:AddButton('Play Emote', 'Search and play', { RightLabel = '>' }, function(Sel)
                    if Sel then UpdateEmoteList() end
                end, RMenu:Get('pd', 'emotes'))

                local fol = PedDir.following[ped] and '[x]' or '[ ]'
                I:AddButton('Follow Me ' .. fol, 'Toggle follow', {}, function(Sel)
                    if Sel then PedDir.ToggleFollow(ped) end
                end)
                I:AddButton('Move to Me', 'Teleport here', {}, function(Sel)
                    if Sel then
                        local c = GetEntityCoords(PlayerPedId())
                        SetEntityCoords(ped, c.x + 1.0, c.y, c.z - 1.0, false, false, false, true)
                    end
                end)
                I:AddButton('Walk to Waypoint', 'Walk to map marker', {}, function(Sel)
                    if Sel then
                        if IsWaypointActive() then
                            PedDir.behaviors[ped] = { mode = 'towp', speed = 18.0, drivingStyle = 786603, lastTask = GetGameTimer(), arriveDistance = 8.0 }
                            if PedDir.sceneMode == 'active' then
                                FreezeEntityPosition(ped, false)
                                SetBlockingOfNonTemporaryEvents(ped, false)
                                local wp = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                                TaskGoStraightToCoord(ped, wp.x, wp.y, wp.z, 1.2, -1, 0.0, 0.2)
                            end
                            Notify('Walking to waypoint')
                        else
                            Notify('No waypoint set')
                        end
                    end
                end)
                I:AddButton('Positioning', 'Move & rotate', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'positioning'))
                I:AddButton('Place In Front', 'Position facing you', {}, function(Sel)
                    if Sel then
                        local pp = PlayerPedId()
                        local t = GetOffsetFromEntityInWorldCoords(pp, 0.0, 1.5, -1.0)
                        SetEntityCoords(ped, t.x, t.y, t.z, false, false, false, true)
                        SetEntityHeading(ped, GetEntityHeading(pp) + 180.0)
                    end
                end)
                local frz = IsEntityPositionFrozen(ped) and '[x]' or '[ ]'
                I:AddButton('Frozen ' .. frz, 'Toggle freeze', {}, function(Sel)
                    if Sel then FreezeEntityPosition(ped, not IsEntityPositionFrozen(ped)) end
                end)
                I:AddButton('Clothing', 'Customize appearance', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'clothing'))
                I:AddButton('Walking Style', 'Movement clipset', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'walks'))
                I:AddButton('Weapons', 'Give weapon', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'weapons'))
                I:AddButton('~r~Delete', 'Remove this ped', {}, function(Sel)
                    if Sel then
                        PedDir.DeletePed(ped, SelectedPedIndex)
                        PendingGoBack = true
                    end
                end)
            end, function() end)
        end

        -- POSITIONING
        local posMenu = RMenu:Get('pd', 'positioning')
        if posMenu then
            posMenu:IsVisible(function(I)
                I = I or Items
                if not SelectedPedEntity or not DoesEntityExist(SelectedPedEntity) then return end
                local ped = SelectedPedEntity
                local c = GetEntityCoords(ped)
                local h = GetEntityHeading(ped)
                I:AddSeparator(string.format('X:%.1f Y:%.1f Z:%.1f H:%.0f', c.x, c.y, c.z, h))
                I:AddButton('Snap to Ground', '', {}, function(Sel) if Sel then PedDir.SnapToGround(ped) end end)
                local relLabel = MovementRelative and 'Relative [x]' or 'Relative [ ]'
                I:AddButton(relLabel, 'Toggle relative/world', {}, function(Sel)
                    if Sel then MovementRelative = not MovementRelative end
                end)
                I:AddButton(string.format('Step: %.2fm', NudgeAmount), 'Click to cycle', {}, function(Sel)
                    if Sel then
                        if NudgeAmount == 0.05 then NudgeAmount = 0.1
                        elseif NudgeAmount == 0.1 then NudgeAmount = 0.5
                        elseif NudgeAmount == 0.5 then NudgeAmount = 1.0
                        else NudgeAmount = 0.05 end
                    end
                end)
                I:AddSeparator('Move')
                I:AddButton('Forward/North', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, 0, NudgeAmount, 0, 0, MovementRelative) end end)
                I:AddButton('Backward/South', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, 0, -NudgeAmount, 0, 0, MovementRelative) end end)
                I:AddButton('Left/West', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, -NudgeAmount, 0, 0, 0, MovementRelative) end end)
                I:AddButton('Right/East', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, NudgeAmount, 0, 0, 0, MovementRelative) end end)
                I:AddButton('Up', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, 0, 0, NudgeAmount, 0, false) end end)
                I:AddButton('Down', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, 0, 0, -NudgeAmount, 0, false) end end)
                I:AddSeparator('Rotate')
                I:AddButton('Rotate Left', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, 0, 0, 0, 5.0, MovementRelative) end end)
                I:AddButton('Rotate Right', '', {}, function(Sel) if Sel then PedDir.AdjustOffset(ped, 0, 0, 0, -5.0, MovementRelative) end end)
                I:AddSeparator('Absolute')
                I:AddButton('Place In Front', '', {}, function(Sel)
                    if Sel then
                        local pp = PlayerPedId()
                        local t = GetOffsetFromEntityInWorldCoords(pp, 0.0, 1.5, -1.0)
                        SetEntityCoords(ped, t.x, t.y, t.z, false, false, false, true)
                        SetEntityHeading(ped, GetEntityHeading(pp) + 180.0)
                    end
                end)
                I:AddButton('Enter Coords', 'Type X, Y, Z', {}, function(Sel)
                    if Sel then
                        local input = KeyboardInput('X, Y, Z', string.format('%.2f, %.2f, %.2f', c.x, c.y, c.z), 50)
                        if input then
                            local x, y, z = string.match(input, '([^,]+),%s*([^,]+),%s*([^,]+)')
                            if x and y and z then
                                SetEntityCoords(ped, tonumber(x), tonumber(y), tonumber(z), false, false, false, true)
                            else
                                Notify('Invalid format')
                            end
                        end
                    end
                end)
            end, function() end)
        end

        -- EMOTES
        local emoteMenu = RMenu:Get('pd', 'emotes')
        if emoteMenu then
            emoteMenu:IsVisible(function(I)
                I = I or Items
                I:AddButton('Search...', 'Filter: ' .. EmoteSearchText, {}, function(Sel)
                    if Sel then
                        local t = KeyboardInput('Search Emotes', '', 20)
                        if t then EmoteSearchText = t; UpdateEmoteList() end
                    end
                end)
                local maxPage = math.max(1, math.ceil(#EmoteList / EmotePerPage))
                if EmoteStartIndex > #EmoteList and #EmoteList > 0 then EmoteStartIndex = 1 end
                I:AddButton('Page ' .. math.ceil(EmoteStartIndex / EmotePerPage) .. '/' .. maxPage, 'Next page', {}, function(Sel)
                    if Sel then
                        EmoteStartIndex = EmoteStartIndex + EmotePerPage
                        if EmoteStartIndex > #EmoteList then EmoteStartIndex = 1 end
                    end
                end)
                local endIdx = math.min(EmoteStartIndex + EmotePerPage - 1, #EmoteList)
                if #EmoteList > 0 then
                    for i = EmoteStartIndex, endIdx do
                        local em = EmoteList[i]
                        if em then
                            I:AddButton(em.label, 'Play', {}, function(Sel)
                                if Sel and SelectedPedEntity then PedDir.PlayEmote(SelectedPedEntity, em.value) end
                            end)
                        end
                    end
                    I:AddSeparator(string.format('%d-%d of %d', EmoteStartIndex, endIdx, #EmoteList))
                else
                    I:AddSeparator('No emotes found')
                end
            end, function() end)
        end

        -- WALKING STYLES
        local walksMenu = RMenu:Get('pd', 'walks')
        if walksMenu then
            walksMenu:IsVisible(function(I)
                I = I or Items
                if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) then
                    for _, s in ipairs(WalkingStyles) do
                        I:AddButton(s.label, '', {}, function(Sel)
                            if Sel then PedDir.SetWalkStyle(SelectedPedEntity, s.value) end
                        end)
                    end
                end
            end, function() end)
        end

        -- WEAPONS
        local weaponsMenu = RMenu:Get('pd', 'weapons')
        if weaponsMenu then
            weaponsMenu:IsVisible(function(I)
                I = I or Items
                if SelectedPedEntity and DoesEntityExist(SelectedPedEntity) then
                    for _, w in ipairs(Weapons) do
                        I:AddButton(w.label, '', {}, function(Sel)
                            if Sel then
                                if w.value == 'REMOVE_ALL' then PedDir.RemoveWeapons(SelectedPedEntity)
                                else PedDir.GiveWeapon(SelectedPedEntity, w.value) end
                            end
                        end)
                    end
                end
            end, function() end)
        end

        -- CLOTHING
        local clothingMenu = RMenu:Get('pd', 'clothing')
        if clothingMenu then
            clothingMenu:IsVisible(function(I)
                I = I or Items
                if not SelectedPedEntity or not DoesEntityExist(SelectedPedEntity) then return end
                PedDir.FocusClothCam(SelectedPedEntity, 'Body')
                KeepClothCam = true
                local ped = SelectedPedEntity
                I:AddButton('Copy Player Outfit', 'Clone your clothes', {}, function(Sel)
                    if Sel then
                        local pp = PlayerPedId()
                        for i = 0, 11 do
                            SetPedComponentVariation(ped, i,
                                GetPedDrawableVariation(pp, i),
                                GetPedTextureVariation(pp, i),
                                GetPedPaletteVariation(pp, i))
                        end
                        for _, pid in ipairs({0, 1, 2, 6, 7}) do
                            local pi = GetPedPropIndex(pp, pid)
                            if pi ~= -1 then SetPedPropIndex(ped, pid, pi, GetPedPropTextureIndex(pp, pid), true)
                            else ClearPedProp(ped, pid) end
                        end
                        Notify('Outfit copied')
                    end
                end)
                I:AddSeparator('Components')
                local components = {
                    {l='Face',id=0},{l='Mask',id=1},{l='Hair',id=2},{l='Torso',id=3},{l='Legs',id=4},
                    {l='Bags/Chute',id=5},{l='Shoes',id=6},{l='Accessories',id=7},{l='Undershirt',id=8},
                    {l='Kevlar',id=9},{l='Badge',id=10},{l='Torso 2',id=11},
                    {l='Hat/Helmet',id=0,prop=true},{l='Glasses',id=1,prop=true},
                    {l='Ears',id=2,prop=true},{l='Watches',id=6,prop=true},{l='Bracelets',id=7,prop=true},
                }
                for _, comp in ipairs(components) do
                    local d, t
                    if comp.prop then
                        d = GetPedPropIndex(ped, comp.id)
                        t = GetPedPropTextureIndex(ped, comp.id)
                    else
                        d = GetPedDrawableVariation(ped, comp.id)
                        t = GetPedTextureVariation(ped, comp.id)
                    end
                    I:AddButton(comp.l, string.format('D:%d T:%d', d, t), { RightLabel = '>' }, function(Sel)
                        if Sel then SelectedComponent = comp end
                    end, RMenu:Get('pd', 'clothing_edit'))
                end
            end, function() end)
        end

        -- CLOTHING EDIT
        local editMenu = RMenu:Get('pd', 'clothing_edit')
        if editMenu then
            editMenu:IsVisible(function(I)
                I = I or Items
                if not SelectedPedEntity or not DoesEntityExist(SelectedPedEntity) or not SelectedComponent then
                    PendingGoBack = true
                    return
                end
                PedDir.FocusClothCam(SelectedPedEntity, SelectedComponent.l or 'Body')
                KeepClothCam = true
                local ped = SelectedPedEntity
                local comp = SelectedComponent
                local minD = comp.prop and -1 or 0
                local maxD, curD, maxT, curT

                if comp.prop then
                    maxD = GetNumberOfPedPropDrawableVariations(ped, comp.id) - 1
                    curD = GetPedPropIndex(ped, comp.id)
                    if curD == -1 then maxT = 0; curT = 0
                    else
                        maxT = GetNumberOfPedPropTextureVariations(ped, comp.id, curD) - 1
                        curT = GetPedPropTextureIndex(ped, comp.id)
                    end
                else
                    maxD = GetNumberOfPedDrawableVariations(ped, comp.id) - 1
                    curD = GetPedDrawableVariation(ped, comp.id)
                    maxT = GetNumberOfPedTextureVariations(ped, comp.id, curD) - 1
                    curT = GetPedTextureVariation(ped, comp.id)
                end

                local function Apply(d, t)
                    if comp.prop then
                        if d == -1 then ClearPedProp(ped, comp.id)
                        else SetPedPropIndex(ped, comp.id, d, t, true) end
                    else
                        PedDir.SetClothing(ped, comp.id, d, t)
                    end
                end

                local dLabels, dValues = BuildNumberList(minD, maxD)
                local dIdx = FindListIndex(dValues, curD)
                I:AddList('Drawable', dLabels, dIdx, 'Left/right to change', {}, function(Idx, Sel, Changed)
                    if Changed then Apply(dValues[Idx], 0) end
                end)

                if maxT < 0 then maxT = 0 end
                local tLabels, tValues = BuildNumberList(0, maxT)
                local tIdx = FindListIndex(tValues, curT)
                I:AddList('Texture', tLabels, tIdx, 'Left/right to change', {}, function(Idx, Sel, Changed)
                    if Changed then
                        if comp.prop and curD == -1 then return end
                        Apply(curD, tValues[Idx])
                    end
                end)

                if comp.prop then
                    I:AddButton('Clear Prop', '', {}, function(Sel)
                        if Sel then ClearPedProp(ped, comp.id) end
                    end)
                end
            end, function() end)
        end

        -- SCENE DIRECTOR
        local sceneMenu = RMenu:Get('pd', 'scene')
        if sceneMenu then
            sceneMenu:IsVisible(function(I)
                I = I or Items
                local modeStr = PedDir.sceneMode == 'setup' and 'SETUP' or 'ACTIVE'
                I:AddButton('Mode: ' .. modeStr, 'Toggle mode', {}, function(Sel)
                    if Sel then PedDir.ToggleSceneMode() end
                end)
                I:AddButton('Actor Slots', 'Manage slots', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'actor_slots'))
                I:AddButton('Global Actions', 'All peds', { RightLabel = '>' }, function() end, RMenu:Get('pd', 'global_actions'))
                I:AddButton('Possess Nearest', 'Camera control', {}, function(Sel)
                    if Sel then ExecuteCommand('possess') end
                end)
                I:AddButton('Clone Nearest', 'Duplicate ped', {}, function(Sel)
                    if Sel then ExecuteCommand('cloneped') end
                end)
                I:AddButton('Reset Scene', 'Clear everything', {}, function(Sel)
                    if Sel then PedDir.SceneReset() end
                end)
                I:AddButton('Teleport All', 'To waypoint', {}, function(Sel)
                    if Sel then ExecuteCommand('teleportall') end
                end)
            end, function() end)
        end

        -- ACTOR SLOTS
        local slotsMenu = RMenu:Get('pd', 'actor_slots')
        if slotsMenu then
            slotsMenu:IsVisible(function(I)
                I = I or Items
                for slot = 1, 9 do
                    local ped = PedDir.slots[slot]
                    local occupied = ped and DoesEntityExist(ped)
                    local label = 'Slot ' .. slot .. (occupied and ' (Occupied)' or ' (Empty)')
                    I:AddButton(label, '', { RightLabel = occupied and 'SWAP' or 'ASSIGN' }, function(Sel)
                        if Sel then
                            if occupied then PedDir.StartPossess(ped)
                            else ExecuteCommand('assignslot ' .. slot) end
                        end
                    end)
                end
            end, function() end)
        end

        -- GLOBAL ACTIONS
        local globalMenu = RMenu:Get('pd', 'global_actions')
        if globalMenu then
            globalMenu:IsVisible(function(I)
                I = I or Items
                I:AddButton('Waypoint All', 'Set waypoint for all', {}, function(Sel)
                    if Sel then ExecuteCommand('waypointall') end
                end)
                I:AddButton('Emote All', 'Apply emote to all', {}, function(Sel)
                    if Sel then
                        local em = KeyboardInput('Emote Name', '', 30)
                        if em then ExecuteCommand('emoteall ' .. em) end
                    end
                end)
                I:AddButton('Stop All', 'Stop all animations', {}, function(Sel)
                    if Sel then ExecuteCommand('stopall') end
                end)
                local chaseLabel = PedDir.chasing and 'Stop Chase' or 'Start Chase'
                I:AddButton(chaseLabel, 'Vehicle chase', {}, function(Sel)
                    if Sel then ExecuteCommand('pedchase') end
                end)
                local escortLabel = PedDir.escorting and 'Stop Escort' or 'Start Escort'
                I:AddButton(escortLabel, 'Vehicle escort', {}, function(Sel)
                    if Sel then ExecuteCommand('pedescort') end
                end)
            end, function() end)
        end

        -- PENDING GO-BACK
        if PendingGoBack then
            PendingGoBack = false
            if RageUI and RageUI.GoBack and RageUI.CurrentMenu then
                RageUI.GoBack()
            end
        end

        -- CLOTHING CAMERA CLEANUP
        if not KeepClothCam then
            PedDir.ClearClothCam()
        end

        ::continue::
    end
end)

-- =============================================
-- COMMAND & KEYBIND
-- =============================================

RegisterCommand('pedmenu', function()
    if not WaitForRageUI(5000) then
        Notify('RageUI still loading, try again')
        return
    end
    InitMenus()
    local m = RMenu:Get('pd', 'main')
    if m then RageUI.Visible(m, not RageUI.Visible(m)) end
end)

RegisterKeyMapping('pedmenu', 'Open Ped Director Menu', 'keyboard', 'F6')

-- =============================================
-- LIFECYCLE
-- =============================================

AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ALIVE = false
end)
