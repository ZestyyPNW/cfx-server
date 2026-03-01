SpawnedPeds = {}
local MAX_PEDS = 20 -- Resource utilization threshold
local FollowPeds = {} -- Table to track peds that should follow the player
local PedBehaviors = {} -- Advanced behavior state per ped
local PatrolRouteNodes = {} -- Shared local patrol route nodes
local PedFactionAssignments = {} -- Ped -> faction name
local RelationshipGroups = {}
local RelationshipGroupsInitialized = false
local SavedPresets = {} -- Table to store saved ped presets
local PresetsFile = 'presets.json' -- File name for saved presets
local NativeRemoveAllPedWeapons = RemoveAllPedWeapons

-- Gizmo State
local GizmoPed = nil
local GizmoMode = "MOVE" -- "MOVE" or "ROTATE"
local GizmoActive = false

-- Clothing camera state
local PedDirectorCamera = nil
local PedDirectorCameraActive = false

-- Scene Director enhancements
local SCENE_MODE_SETUP = "setup"
local SCENE_MODE_ACTIVE = "active"
local SceneMode = SCENE_MODE_SETUP -- Current scene mode

local ActorSlots = {} -- Slot 1-9 -> Ped
local SlotBlips = {} -- Slot -> Blip ID
local PedSlotAssignments = {} -- Ped -> Slot number

-- Possess state
local PossessedPed = nil
local PossessCamera = nil
local IsPossessing = false

-- Lighting state
local StageLights = {}
local NextLightId = 1

-- Notification helper to replace ox_lib
function Notify(msg, type)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, true)
end

local function resolveClothingFocus(focusPart)
    local key = string.lower(tostring(focusPart or "body"))
    if key:find("face", 1, true) or key:find("mask", 1, true) or key:find("hair", 1, true) or key:find("hat", 1, true)
        or key:find("glasses", 1, true) or key:find("ear", 1, true) then
        return { distance = 0.8, height = 0.72, targetZ = 0.72, fov = 34.0 }
    end
    if key:find("legs", 1, true) or key:find("shoes", 1, true) or key:find("ankle", 1, true) then
        return { distance = 1.0, height = 0.2, targetZ = 0.25, fov = 36.0 }
    end
    if key:find("watch", 1, true) or key:find("bracelet", 1, true) or key:find("arm", 1, true) then
        return { distance = 0.95, height = 0.45, targetZ = 0.45, fov = 35.0 }
    end
    return { distance = 1.3, height = 0.52, targetZ = 0.55, fov = 40.0 }
end

function FocusPedDirectorCamera(ped, focusPart)
    if not DoesEntityExist(ped) then return end

    if not PedDirectorCamera or not DoesCamExist(PedDirectorCamera) then
        PedDirectorCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end

    local cfg = resolveClothingFocus(focusPart)
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.08, cfg.distance, cfg.height)
    local targetCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, cfg.targetZ)

    SetCamCoord(PedDirectorCamera, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(PedDirectorCamera, targetCoords.x, targetCoords.y, targetCoords.z)
    SetCamFov(PedDirectorCamera, cfg.fov)

    if not PedDirectorCameraActive then
        SetCamActive(PedDirectorCamera, true)
        RenderScriptCams(true, true, 250, true, true)
        PedDirectorCameraActive = true
    end
end

function ClearPedDirectorCamera()
    if PedDirectorCamera and DoesCamExist(PedDirectorCamera) then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(PedDirectorCamera, false)
    end
    PedDirectorCamera = nil
    PedDirectorCameraActive = false
end

-- Helper: Draw Text 3D
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

-- Gizmo Logic Thread (simplified for stability)
CreateThread(function()
    while isResourceActive do
        Wait(50)
        
        if not GizmoActive then
            Wait(500)
            goto continue
        end
        
        if not GizmoPed or not DoesEntityExist(GizmoPed) then
            GizmoActive = false
            GizmoPed = nil
            goto continue
        end
        
        local success, err = pcall(function()
            -- Instructions
            local coords = GetEntityCoords(GizmoPed)
            DrawText3D(coords.x, coords.y, coords.z + 1.2, "Gizmo Mode: " .. GizmoMode)
            DrawText3D(coords.x, coords.y, coords.z + 1.1, "[W/A/S/D] Move  [Q/E] Height  [TAB] Mode  [ENTER] Save")

            local speed = IsDisabledControlPressed(0, 21) and 0.01 or 0.05
            if GizmoMode == "ROTATE" then speed = speed * 20.0 end

            if GizmoMode == "MOVE" then
                if IsDisabledControlPressed(0, 32) then -- W
                    AdjustPedOffset(GizmoPed, 0.0, speed, 0.0, 0.0, false)
                end
                if IsDisabledControlPressed(0, 33) then -- S
                    AdjustPedOffset(GizmoPed, 0.0, -speed, 0.0, 0.0, false)
                end
                if IsDisabledControlPressed(0, 34) then -- A
                    AdjustPedOffset(GizmoPed, -speed, 0.0, 0.0, 0.0, false)
                end
                if IsDisabledControlPressed(0, 30) then -- D
                    AdjustPedOffset(GizmoPed, speed, 0.0, 0.0, 0.0, false)
                end
                if IsDisabledControlPressed(0, 44) then -- Q
                    AdjustPedOffset(GizmoPed, 0.0, 0.0, speed, 0.0, false)
                end
                if IsDisabledControlPressed(0, 38) then -- E
                    AdjustPedOffset(GizmoPed, 0.0, 0.0, -speed, 0.0, false)
                end
                DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0, 255, 0, 100, false, false, 2, nil, nil, false)
            elseif GizmoMode == "ROTATE" then
                if IsDisabledControlPressed(0, 34) or IsDisabledControlPressed(0, 44) then
                    AdjustPedOffset(GizmoPed, 0.0, 0.0, 0.0, speed, false)
                end
                if IsDisabledControlPressed(0, 30) or IsDisabledControlPressed(0, 38) then
                    AdjustPedOffset(GizmoPed, 0.0, 0.0, 0.0, -speed, false)
                end
                local heading = GetEntityHeading(GizmoPed)
                local rad = math.rad(heading)
                local forwardX = -math.sin(rad) * 2.0
                local forwardY = math.cos(rad) * 2.0
                DrawLine(coords.x, coords.y, coords.z, coords.x + forwardX, coords.y + forwardY, coords.z, 255, 0, 0, 255)
            end

            if IsDisabledControlJustPressed(0, 37) then -- TAB
                if GizmoMode == "MOVE" then GizmoMode = "ROTATE" else GizmoMode = "MOVE" end
            end

            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 18) then -- ENTER
                GizmoActive = false
                GizmoPed = nil
                Notify("Gizmo Mode Exited")
            end
        end)
        
        if not success then
            print("[ped-director] Gizmo error: " .. tostring(err))
            GizmoActive = false
            GizmoPed = nil
        end
        
        ::continue::
    end
end)

-- Global function to start gizmo
function StartGizmo(ped)
    if not DoesEntityExist(ped) then return end
    GizmoPed = ped
    GizmoActive = true
    GizmoMode = "MOVE"
    Notify("Entering Gizmo Mode...")
    
    -- Close Menu if open
    if RageUI then RageUI.CloseAll() end
end

-- Spawn a ped at your current location
RegisterCommand('spawnped', function(source, args)
    -- Check resource utilization threshold
    if #SpawnedPeds >= MAX_PEDS then
        Notify("Cannot spawn more peds. Max limit reached (" .. MAX_PEDS .. ").")
        return
    end

    local model = args[1] or 'a_m_m_skater_01'
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    RequestModel(GetHashKey(model))
    
    -- Timeout implementation for model loading
    local timeout = 0
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(100)
        timeout = timeout + 1
        if timeout > 50 then -- 5 seconds timeout
            Notify("Failed to load model: " .. model)
            return
        end
    end
    
    -- Create the ped
    -- isNetwork = true, bScriptHostPed = false
    local ped = CreatePed(4, GetHashKey(model), coords.x + 1.0, coords.y, coords.z - 1.0, heading, true, false)
    
    if not DoesEntityExist(ped) then
        Notify("Failed to create ped!")
        return
    end
    
    -- Set ped properties
    SetEntityAsMissionEntity(ped, true, true)
    NetworkRegisterEntityAsNetworked(ped)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    
    -- Add to spawned peds table
    table.insert(SpawnedPeds, ped)
    
    Notify("Spawned ped: " .. model .. " (Total: " .. #SpawnedPeds .. ")")
end)

-- Track props attached to peds so we can clean them up
PedProps = PedProps or {}

local function attachEmoteProp(ped, propModel, bone, placement)
    if not propModel or propModel == '' then return nil end

    local hash = GetHashKey(propModel)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do
        Wait(100)
        t = t + 1
    end
    if not HasModelLoaded(hash) then return nil end

    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    if not obj or obj == 0 then return nil end

    local boneIndex = GetPedBoneIndex(ped, bone or 28422)
    local p = placement or {}
    AttachEntityToEntity(obj, ped, boneIndex,
        p[1] or 0.0, p[2] or 0.0, p[3] or 0.0,
        p[4] or 0.0, p[5] or 0.0, p[6] or 0.0,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function clearPedProps(ped)
    if PedProps[ped] then
        for _, obj in ipairs(PedProps[ped]) do
            if DoesEntityExist(obj) then
                DeleteObject(obj)
            end
        end
        PedProps[ped] = nil
    end
end

-- Event to play emote on a specific ped (Called from Menu)
AddEventHandler('ped-director:playEmoteOnPed', function(ped, emoteName)
    local emoteData = GetEmote(emoteName)
    if not emoteData then return end

    RequestAnimDict(emoteData.dict)
    local timeout = 0
    while not HasAnimDictLoaded(emoteData.dict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if HasAnimDictLoaded(emoteData.dict) then
        clearPedProps(ped)
        TaskPlayAnim(ped, emoteData.dict, emoteData.anim, 8.0, -8.0, -1, 1, 0, false, false, false)

        local opts = emoteData.options
        if opts then
            local props = {}
            if opts.Prop then
                local obj = attachEmoteProp(ped, opts.Prop, opts.PropBone, opts.PropPlacement)
                if obj then table.insert(props, obj) end
            end
            if opts.SecondProp then
                local obj = attachEmoteProp(ped, opts.SecondProp, opts.SecondPropBone, opts.SecondPropPlacement)
                if obj then table.insert(props, obj) end
            end
            if #props > 0 then
                PedProps[ped] = props
            end
        end

        Notify('Playing emote: ' .. emoteData.name)
    else
        Notify('Failed to load animation')
    end
end)

-- Global function to toggle follow mode for a ped
function TogglePedFollow(ped)
    if FollowPeds[ped] then
        FollowPeds[ped] = nil
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, true) -- Re-freeze when stopping
        Notify('Follow Stopped')
    else
        FollowPeds[ped] = true
        FreezeEntityPosition(ped, false) -- Unfreeze to move
        Notify('Follow Started')
    end
end

-- Global function to set ped clothing
function SetPedClothing(ped, componentId, drawableId, textureId)
    SetPedComponentVariation(ped, componentId, drawableId, textureId, 0)
end

-- Global function to get max drawables for a component
function GetMaxDrawables(ped, componentId)
    return GetNumberOfPedDrawableVariations(ped, componentId)
end

-- Global function to get max textures for a component
function GetMaxTextures(ped, componentId, drawableId)
    return GetNumberOfPedTextureVariations(ped, componentId, drawableId)
end

-- Function to set walking style
function SetPedWalkingStyle(ped, clipSet)
    RequestClipSet(clipSet)
    while not HasClipSetLoaded(clipSet) do
        Wait(10)
    end
    SetPedMovementClipset(ped, clipSet, 1.0)
    Notify("Walking style set: " .. clipSet)
end

-- Function to give weapon
function GivePedWeapon(ped, weaponName)
    if not ped or not DoesEntityExist(ped) then
        Notify("Invalid ped.")
        return
    end

    local weaponHash = GetHashKey(weaponName)
    local ok, valid = pcall(IsWeaponValid, weaponHash)
    if ok and not valid then
        Notify("Invalid weapon: " .. tostring(weaponName))
        return
    end

    local wasFrozen = IsEntityPositionFrozen(ped)
    if wasFrozen then
        FreezeEntityPosition(ped, false)
    end

    -- Clear current anim/scenario so the weapon can be visibly equipped.
    clearPedProps(ped)
    ClearPedTasksImmediately(ped)
    SetPedCanSwitchWeapon(ped, true)

    GiveWeaponToPed(ped, weaponHash, 999, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
    SetPedCurrentWeaponVisible(ped, true, true, true, true)

    if wasFrozen then
        FreezeEntityPosition(ped, true)
    end

    Notify("Equipped weapon: " .. weaponName)
end

-- Function to remove all weapons
function RemoveAllPedWeapons(ped)
    if NativeRemoveAllPedWeapons then
        NativeRemoveAllPedWeapons(ped, true)
        Notify("All weapons removed.")
    end
end

-- Global function to save ped as preset
function SavePedPreset(ped, presetName)
    if not DoesEntityExist(ped) then
        Notify("Invalid ped for preset.")
        return false
    end
    
    -- Get all ped data
    local pedModel = GetEntityModel(ped)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Get all clothing components with proper error checking
    local clothing = {}
    local components = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}
    local validComponents = 0
    
    for _, compId in ipairs(components) do
        local drawable = GetPedDrawableVariation(ped, compId)
        local texture = GetPedTextureVariation(ped, compId)
        
        -- Check props too? Yes, logic below does check props
        local prop = GetPedPropIndex(ped, compId)
        local propTex = GetPedPropTextureIndex(ped, compId)
        
        -- Only save if data is valid
        if drawable ~= -1 or texture ~= -1 or prop ~= -1 then
            local compData = {}
            
            if drawable ~= -1 then
                compData.drawable = drawable
                compData.texture = texture
                validComponents = validComponents + 1
            end
            
            if prop ~= -1 then
                compData.prop = prop
                compData.propTexture = propTex
                validComponents = validComponents + 1
            end
            
            if compData.drawable or compData.prop then
                clothing[compId] = compData
            end
        end
    end
    
    -- Validate we actually got clothing data
    if validComponents == 0 then
        Notify("Failed to get ped clothing data. Preset not saved.")
        return false
    end
    
    -- Save preset data locally and send to server
    local presetData = {
        model = pedModel,
        coords = coords,
        heading = heading,
        clothing = clothing,
        timestamp = GetGameTimer()
    }
    
    SavedPresets[presetName] = presetData
    TriggerServerEvent('ped-director:savePreset', presetName, presetData)
    
    Notify(("Preset '%s' saved with %d valid components!"):format(presetName, validComponents))
    return true
end

function RefreshPedPresets()
    TriggerServerEvent('ped-director:requestPresets')
end

function GetSavedPresetNames()
    local presetNames = {}
    for name, _ in pairs(SavedPresets) do
        table.insert(presetNames, name)
    end
    table.sort(presetNames)
    return presetNames
end

function GetClosestSpawnedPed(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = tonumber(maxDistance) or 10.0
    local validPeds = {}

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end

    SpawnedPeds = validPeds
    return closestPed, closestDist
end

-- Load presets from server on start
CreateThread(function()
    RefreshPedPresets()
end)

RegisterNetEvent('ped-director:receivePresets', function(serverPresets)
    if serverPresets then
        SavedPresets = serverPresets
        print('[ped-director] Loaded ' .. CountTable(SavedPresets) .. ' presets from server.')
    end
end)

function CountTable(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- Function to load ped from preset
function LoadPedPreset(presetName)
    local preset = SavedPresets[presetName]
    if not preset then
        Notify("Preset not found: " .. presetName)
        return false
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    -- Request ped model
    local modelHash = preset.model
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        Notify("Failed to load preset model.")
        return false
    end
    
    -- Create ped
    -- isNetwork = true, bScriptHostPed = false
    local ped = CreatePed(4, modelHash, playerCoords.x + 1.0, playerCoords.y, playerCoords.z - 1.0, playerHeading, true, false)
    if not DoesEntityExist(ped) then
        Notify("Failed to create ped from preset.")
        return false
    end
    
    -- Set ped properties
    SetEntityAsMissionEntity(ped, true, true)
    NetworkRegisterEntityAsNetworked(ped)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    -- Apply clothing
    if preset.clothing then
        for compId, data in pairs(preset.clothing) do
            -- Ensure compId is a number
            compId = tonumber(compId)
            if data.drawable ~= nil then
                SetPedComponentVariation(ped, compId, data.drawable, data.texture or 0, 0)
            end
            if data.prop ~= nil then
                SetPedPropIndex(ped, compId, data.prop, data.propTexture or 0, true)
            end
        end
    end
    
    -- Add to spawned peds table
    table.insert(SpawnedPeds, ped)
    
    Notify("Loaded preset: " .. presetName)
    return ped
end

-- Function to list saved presets
function ListSavedPresets()
    local presetNames = GetSavedPresetNames()

    if #presetNames == 0 then
        Notify("No saved presets found.")
    else
        Notify("Saved Presets:")
        for i, name in ipairs(presetNames) do
            Notify(("%d. %s"):format(i, name))
        end
    end
end

-- Function to make ped walk to waypoint
function MakePedWalkToWaypoint(ped)
    if IsWaypointActive() then
        local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
        -- Z coord is usually 0 from blip, need ground z
        local foundGround, zPos = GetGroundZFor_3dCoord(waypointCoords.x, waypointCoords.y, 1000.0, 0)

        if not foundGround then zPos = waypointCoords.z end -- Fallback

        if SceneMode == SCENE_MODE_SETUP then
            -- Store waypoint for later execution
            PedBehaviors[ped] = {
                mode = "towp",
                speed = 18.0,
                drivingStyle = 786603,
                lastTaskAt = GetGameTimer(),
                arriveDistance = 8.0
            }
            Notify("Waypoint stored for ped (Setup Mode)")
        else
            -- Execute immediately
            FreezeEntityPosition(ped, false)
            TaskGoToCoordAnyMeans(ped, waypointCoords.x, waypointCoords.y, zPos, 1.0, 0, 0, 786603, 0xbf800000)
            Notify("Walking to waypoint...")
        end
    else
        Notify("No waypoint set!")
    end
end

-- Helper: Snap Ped to Ground
function SnapPedToGround(ped)
    local coords = GetEntityCoords(ped)
    local foundGround, zPos = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, 0)
    if foundGround then
        SetEntityCoords(ped, coords.x, coords.y, zPos, false, false, false, true)
        Notify("Snapped to ground.")
    else
        -- Try higher up
        foundGround, zPos = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 500.0, 0)
        if foundGround then
            SetEntityCoords(ped, coords.x, coords.y, zPos, false, false, false, true)
            Notify("Snapped to ground (from height).")
        else
            Notify("Could not find ground.")
        end
    end
end

-- Helper: Adjust Ped Offset (Position & Heading)
function AdjustPedOffset(ped, xOff, yOff, zOff, headingOff, relative)
    if not DoesEntityExist(ped) then return end
    
    -- Heading
    if headingOff ~= 0.0 then
        local currentHeading = GetEntityHeading(ped)
        SetEntityHeading(ped, currentHeading + headingOff)
    end
    
    -- Position
    if xOff ~= 0.0 or yOff ~= 0.0 or zOff ~= 0.0 then
        if relative then
            -- Relative to ped's current facing
            local offset = GetOffsetFromEntityInWorldCoords(ped, xOff, yOff, zOff)
            SetEntityCoords(ped, offset.x, offset.y, offset.z, false, false, false, true)
        else
            -- Absolute world coordinates (X is always East/West, Y is North/South)
            local currentCoords = GetEntityCoords(ped)
            SetEntityCoords(ped, currentCoords.x + xOff, currentCoords.y + yOff, currentCoords.z + zOff, false, false, false, true)
        end
    end
end

-- Thread to handle following logic
local isResourceActive = true

CreateThread(function()
    while isResourceActive do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for ped, isFollowing in pairs(FollowPeds) do
            if isFollowing and DoesEntityExist(ped) then
                sleep = 200
                local pedCoords = GetEntityCoords(ped)
                local dist = #(playerCoords - pedCoords)

                if dist > 2.0 then
                    -- If far, run/walk to player
                    TaskGoToEntity(ped, playerPed, -1, 1.5, 2.0, 1073741824.0, 0)
                else
                    -- If close, stop
                    -- TaskStandStill(ped, 1000)
                end
            else
                FollowPeds[ped] = nil -- Cleanup if ped deleted
            end
        end
        Wait(sleep)
    end
end)

-- =========================
-- Phase 1: Driving/Patrol/Factions
-- =========================

local FactionProfiles = {
    civilian = {
        group = "PEDDIR_CIV",
        accuracy = 12,
        combatAbility = 0,
        combatRange = 0,
        combatMovement = 1,
        alertness = 1
    },
    police = {
        group = "PEDDIR_POLICE",
        accuracy = 55,
        combatAbility = 2,
        combatRange = 2,
        combatMovement = 2,
        alertness = 3
    },
    gang = {
        group = "PEDDIR_GANG",
        accuracy = 42,
        combatAbility = 1,
        combatRange = 1,
        combatMovement = 2,
        alertness = 3
    },
    guard = {
        group = "PEDDIR_GUARD",
        accuracy = 50,
        combatAbility = 2,
        combatRange = 2,
        combatMovement = 1,
        alertness = 2
    }
}

local function normalizeFactionName(name)
    return string.lower(tostring(name or ""))
end

local function initializeRelationshipGroups()
    if RelationshipGroupsInitialized then return end

    for factionName, profile in pairs(FactionProfiles) do
        local groupHash = AddRelationshipGroup(profile.group)
        RelationshipGroups[factionName] = groupHash
    end

    -- Default all to neutral.
    for sourceFaction, sourceHash in pairs(RelationshipGroups) do
        for targetFaction, targetHash in pairs(RelationshipGroups) do
            SetRelationshipBetweenGroups(3, sourceHash, targetHash)
        end
    end

    -- Key oppositions.
    local policeHash = RelationshipGroups.police
    local gangHash = RelationshipGroups.gang
    local guardHash = RelationshipGroups.guard
    local civilianHash = RelationshipGroups.civilian

    if policeHash and gangHash then
        SetRelationshipBetweenGroups(5, policeHash, gangHash)
        SetRelationshipBetweenGroups(5, gangHash, policeHash)
    end

    if guardHash and gangHash then
        SetRelationshipBetweenGroups(5, guardHash, gangHash)
        SetRelationshipBetweenGroups(5, gangHash, guardHash)
    end

    if policeHash and civilianHash then
        SetRelationshipBetweenGroups(1, policeHash, civilianHash)
        SetRelationshipBetweenGroups(3, civilianHash, policeHash)
    end

    RelationshipGroupsInitialized = true
end

local function getNearestSpawnedPed(maxDistance, excludePed, predicate)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = tonumber(maxDistance) or 10.0
    local validPeds = {}

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)

            if ped ~= excludePed then
                local allowed = true
                if predicate then
                    allowed = predicate(ped)
                end

                if allowed then
                    local pedCoords = GetEntityCoords(ped)
                    local dist = #(playerCoords - pedCoords)
                    if dist < closestDist then
                        closestPed = ped
                        closestDist = dist
                    end
                end
            end
        end
    end

    SpawnedPeds = validPeds
    return closestPed, closestDist
end

local function applyFactionProfile(ped, factionName)
    local normalized = normalizeFactionName(factionName)
    local profile = FactionProfiles[normalized]
    if not profile then
        Notify("Unknown faction. Use: civilian, police, gang, guard")
        return false
    end

    initializeRelationshipGroups()
    local groupHash = RelationshipGroups[normalized]
    if not groupHash then
        Notify("Failed to initialize relationship group.")
        return false
    end

    SetPedRelationshipGroupHash(ped, groupHash)
    SetPedAccuracy(ped, profile.accuracy)
    SetPedCombatAbility(ped, profile.combatAbility)
    SetPedCombatRange(ped, profile.combatRange)
    SetPedCombatMovement(ped, profile.combatMovement)
    SetPedAlertness(ped, profile.alertness)
    SetPedCanSwitchWeapon(ped, true)
    SetCanAttackFriendly(ped, false, false)

    -- A few useful combat attributes for more natural fights.
    SetPedCombatAttributes(ped, 0, true)   -- use cover
    SetPedCombatAttributes(ped, 5, true)   -- can fight armed peds
    SetPedCombatAttributes(ped, 46, true)  -- always fight

    PedFactionAssignments[ped] = normalized
    Notify(("Faction set to %s"):format(normalized))
    return true
end

local function getWaypointGroundedCoords()
    if not IsWaypointActive() then return nil end
    local wp = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
    local found, zPos = GetGroundZFor_3dCoord(wp.x, wp.y, 1000.0, 0)
    if found then
        return vector3(wp.x, wp.y, zPos)
    end
    return vector3(wp.x, wp.y, wp.z)
end

function ensurePedVehicle(ped, vehicleModel)
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(vehicle, -1) == ped then
            return vehicle
        end
    end

    local model = tostring(vehicleModel or "blista")
    local hash = GetHashKey(model)
    RequestModel(hash)

    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(hash) then
        Notify("Failed to load vehicle model: " .. model)
        return nil
    end

    local pedCoords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)
    local spawn = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, pedHeading, true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    return vehicle
end

local function clearPedBehavior(ped)
    PedBehaviors[ped] = nil
end

local function issueBehaviorTask(ped, behavior)
    if not behavior or not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)

    local mode = behavior.mode
    local speed = tonumber(behavior.speed) or 18.0
    local drivingStyle = tonumber(behavior.drivingStyle) or 786603

    if mode == "wander" then
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                TaskVehicleDriveWander(ped, vehicle, speed, drivingStyle)
                behavior.lastTaskAt = GetGameTimer()
                return
            end
        end
        TaskWanderStandard(ped, 10.0, 10)
        behavior.lastTaskAt = GetGameTimer()
        return
    end

    if mode == "towp" then
        local dest = getWaypointGroundedCoords()
        if not dest then
            Notify("No waypoint set.")
            clearPedBehavior(ped)
            return
        end

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                TaskVehicleDriveToCoordLongrange(ped, vehicle, dest.x, dest.y, dest.z, speed, drivingStyle, 8.0)
            else
                TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
            end
        else
            TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
        end

        behavior.lastTaskAt = GetGameTimer()
        return
    end

    if mode == "patrol" then
        local route = behavior.route or {}
        if #route < 2 then
            Notify("Patrol route needs at least 2 nodes. Use /pedrouteadd.")
            clearPedBehavior(ped)
            return
        end

        local idx = behavior.routeIndex or 1
        if idx < 1 or idx > #route then idx = 1 end
        local dest = route[idx]
        if not dest then return end

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                TaskVehicleDriveToCoordLongrange(ped, vehicle, dest.x, dest.y, dest.z, speed, drivingStyle, 10.0)
            else
                TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
            end
        else
            TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
        end

        behavior.lastTaskAt = GetGameTimer()
        return
    end
end

CreateThread(function()
    while isResourceActive do
        local sleep = 500
        local now = GetGameTimer()

        for ped, behavior in pairs(PedBehaviors) do
            if not DoesEntityExist(ped) then
                PedBehaviors[ped] = nil
            else
                if behavior.mode == "patrol" then
                    local route = behavior.route or {}
                    if #route >= 1 then
                        local idx = behavior.routeIndex or 1
                        if idx < 1 or idx > #route then idx = 1 end
                        local dest = route[idx]
                        local dist = #(GetEntityCoords(ped) - vector3(dest.x, dest.y, dest.z))
                        if dist <= (behavior.arriveDistance or 12.0) then
                            behavior.routeIndex = (idx % #route) + 1
                            issueBehaviorTask(ped, behavior)
                        elseif now - (behavior.lastTaskAt or 0) > 4500 then
                            issueBehaviorTask(ped, behavior)
                        end
                    end
                elseif behavior.mode == "towp" then
                    local dest = getWaypointGroundedCoords()
                    if not dest then
                        PedBehaviors[ped] = nil
                    else
                        local dist = #(GetEntityCoords(ped) - dest)
                        if dist <= (behavior.arriveDistance or 8.0) then
                            Notify("Ped reached waypoint.")
                            PedBehaviors[ped] = nil
                            TaskStandStill(ped, 1500)
                        elseif now - (behavior.lastTaskAt or 0) > 4500 then
                            issueBehaviorTask(ped, behavior)
                        end
                    end
                elseif behavior.mode == "wander" then
                    if now - (behavior.lastTaskAt or 0) > 10000 then
                        issueBehaviorTask(ped, behavior)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterCommand('pedvehicle', function(source, args)
    local ped = GetClosestSpawnedPed(12.0)
    if not ped then
        Notify("No ped found nearby!")
        return
    end

    local model = args[1] or "blista"
    local vehicle = ensurePedVehicle(ped, model)
    if vehicle then
        Notify("Spawned vehicle and seated ped.")
    end
end)

RegisterCommand('pedrouteadd', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, 0)
    local node = {
        x = coords.x,
        y = coords.y,
        z = found and z or coords.z
    }
    table.insert(PatrolRouteNodes, node)
    Notify(("Added patrol node #%d"):format(#PatrolRouteNodes))
end)

RegisterCommand('pedrouteclear', function()
    PatrolRouteNodes = {}
    Notify("Cleared patrol route nodes.")
end)

RegisterCommand('pedrouteinfo', function()
    Notify(("Patrol route nodes: %d"):format(#PatrolRouteNodes))
end)

RegisterCommand('peddrive', function(source, args)
    local mode = string.lower(tostring(args[1] or ""))
    if mode == "" then
        Notify("Usage: /peddrive [wander|towp|patrol|stop] [speed]")
        return
    end

    local ped = GetClosestSpawnedPed(12.0)
    if not ped then
        Notify("No ped found nearby!")
        return
    end

    if mode == "stop" then
        clearPedBehavior(ped)
        ClearPedTasks(ped)
        Notify("Drive behavior stopped.")
        return
    end

    local speed = tonumber(args[2]) or 18.0
    local behavior = {
        mode = mode,
        speed = speed,
        drivingStyle = 786603,
        lastTaskAt = 0,
        arriveDistance = 10.0
    }

    if mode == "patrol" then
        if #PatrolRouteNodes < 2 then
            Notify("Need at least 2 patrol nodes. Use /pedrouteadd.")
            return
        end
        behavior.route = PatrolRouteNodes
        behavior.routeIndex = 1
        behavior.arriveDistance = 12.0
    elseif mode == "towp" then
        if not IsWaypointActive() then
            Notify("Set a map waypoint first.")
            return
        end
        behavior.arriveDistance = 8.0
    elseif mode ~= "wander" then
        Notify("Unknown mode. Use: wander, towp, patrol, stop")
        return
    end

    PedBehaviors[ped] = behavior
    issueBehaviorTask(ped, behavior)
    Notify(("Ped drive mode: %s"):format(mode))
end)

RegisterCommand('pedfaction', function(source, args)
    local faction = normalizeFactionName(args[1])
    if faction == "" then
        Notify("Usage: /pedfaction [civilian|police|gang|guard]")
        return
    end

    local ped = GetClosestSpawnedPed(12.0)
    if not ped then
        Notify("No ped found nearby!")
        return
    end

    applyFactionProfile(ped, faction)
end)

RegisterCommand('pedcombat', function(source, args)
    local mode = string.lower(tostring(args[1] or ""))
    if mode == "" then
        Notify("Usage: /pedcombat [player|nearest|faction] [factionName]")
        return
    end

    local attacker = GetClosestSpawnedPed(12.0)
    if not attacker then
        Notify("No attacker ped found nearby!")
        return
    end

    if mode == "stop" then
        ClearPedTasks(attacker)
        Notify("Combat stopped.")
        return
    end

    local target = nil

    if mode == "player" then
        target = PlayerPedId()
    elseif mode == "nearest" then
        target = getNearestSpawnedPed(60.0, attacker)
    elseif mode == "faction" then
        local targetFaction = normalizeFactionName(args[2])
        if targetFaction == "" then
            Notify("Usage: /pedcombat faction [civilian|police|gang|guard]")
            return
        end
        target = getNearestSpawnedPed(80.0, attacker, function(ped)
            return PedFactionAssignments[ped] == targetFaction
        end)
    else
        Notify("Unknown mode. Use: player, nearest, faction, stop")
        return
    end

    if not target or not DoesEntityExist(target) then
        Notify("No valid target found.")
        return
    end

    FreezeEntityPosition(attacker, false)
    SetBlockingOfNonTemporaryEvents(attacker, false)
    TaskCombatPed(attacker, target, 0, 16)
    Notify("Combat started.")
end)

-- Play rpemotes animation on nearest ped
RegisterCommand('pedemote', function(source, args)
    if #args < 1 then
        Notify("Usage: /pedemote [emote name]\nExamples: dance, smoke, sitchair")
        return
    end

    local emoteName = args[1]
    local emoteData = GetEmote(emoteName)

    if not emoteData then
        Notify("Emote '" .. emoteName .. "' not found.")
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = 10.0

    -- Cleanup invalid peds while iterating
    local validPeds = {}
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end
    SpawnedPeds = validPeds -- Update main table

    if closestPed then
        TriggerEvent('ped-director:playEmoteOnPed', closestPed, emoteName)
    else
        Notify("No ped found nearby!")
    end
end)

-- Save current ped as preset
RegisterCommand('savepedpreset', function(source, args)
    local presetName = args[1]
    if not presetName or presetName == "" then
        Notify("Usage: /savepedpreset [name]")
        return
    end

    local closestPed = GetClosestSpawnedPed(10.0)
    if closestPed then
        SavePedPreset(closestPed, presetName)
    else
        Notify("No ped found nearby to save.")
    end
end, false)

-- Load ped from preset
RegisterCommand('loadpedpreset', function(source, args)
    if not args[1] then
        -- Show list of saved presets
        ListSavedPresets()
        Notify("Usage: /loadpedpreset [number] or /loadpedpreset [name]")
        return
    end
    
    -- Check if argument is a number
    local presetIndex = tonumber(args[1])
    if presetIndex then
        -- Load by index number
        local presetNames = GetSavedPresetNames()
        
        if presetNames[presetIndex] then
            LoadPedPreset(presetNames[presetIndex])
        else
            Notify(("Invalid preset number. Available presets: 1-%d"):format(#presetNames))
        end
    else
        -- Load by name
        local presetName = args[1]
        if SavedPresets[presetName] then
            LoadPedPreset(presetName)
        else
            Notify("Preset not found: " .. presetName)
        end
    end
end, false)

-- List saved presets
RegisterCommand('listpedpresets', function(source, args)
    ListSavedPresets()
end, false)

-- Play animation on nearest ped using dict and anim
RegisterCommand('pedanim', function(source, args)
    if #args < 2 then
        Notify("Usage: /pedanim [dict] [anim]")
        return
    end

    local dict = args[1]
    local anim = args[2]
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = 10.0

    local validPeds = {}
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end
    SpawnedPeds = validPeds

    if closestPed then
        RequestAnimDict(dict)
        
        -- Timeout implementation for anim dict loading
        local timeout = 0
        while not HasAnimDictLoaded(dict) do
            Wait(100)
            timeout = timeout + 1
            if timeout > 50 then -- 5 seconds timeout
                 Notify("Failed to load animation dictionary: " .. dict)
                return
            end
        end

        TaskPlayAnim(closestPed, dict, anim, 8.0, -8.0, -1, 1, 0, false, false, false)

        Notify("Playing animation: " .. dict .. " - " .. anim)
    else
        Notify("No ped found nearby!")
    end
end)

-- Play scenario on nearest ped
RegisterCommand('pedscenario', function(source, args)
    if #args < 1 then
        Notify("Usage: /pedscenario [scenario]")
        return
    end

    local scenario = string.upper(args[1])
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = 10.0

    local validPeds = {}
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end
    SpawnedPeds = validPeds

    if closestPed then
        TaskStartScenarioInPlace(closestPed, scenario, 0, true)
        Notify("Playing scenario: " .. scenario)
    else
        Notify("No ped found nearby!")
    end
end)

-- Delete nearest ped
RegisterCommand('deleteped', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = 5.0
    local closestIndex = nil

    local validPeds = {}
    for i, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
                closestIndex = #validPeds -- It's the last one added to validPeds
            end
        end
    end
    SpawnedPeds = validPeds

    if closestPed then
        clearPedBehavior(closestPed)
        FollowPeds[closestPed] = nil
        PedFactionAssignments[closestPed] = nil
        clearPedProps(closestPed)
        DeleteEntity(closestPed)
        if closestIndex then
            table.remove(SpawnedPeds, closestIndex)
        end
        Notify("Deleted ped (Remaining: " .. #SpawnedPeds .. ")")
    else
        Notify("No ped found nearby!")
    end
end)

-- Clear all spawned peds
RegisterCommand('clearallpeds', function()
    local count = 0
    for _, ped in ipairs(SpawnedPeds) do
        clearPedBehavior(ped)
        FollowPeds[ped] = nil
        PedFactionAssignments[ped] = nil
        clearPedProps(ped)
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
            count = count + 1
        end
    end
    SpawnedPeds = {}
    PedProps = {}
    PedBehaviors = {}
    PedFactionAssignments = {}
    Notify("Deleted " .. count .. " peds")
end)

-- Freeze/Unfreeze nearest ped
RegisterCommand('freezeped', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = 5.0

    local validPeds = {}
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end
    SpawnedPeds = validPeds

    if closestPed then
        local isFrozen = IsEntityPositionFrozen(closestPed)
        FreezeEntityPosition(closestPed, not isFrozen)
        Notify("Ped " .. (not isFrozen and "frozen" or "unfrozen"))
    else
        Notify("No ped found nearby!")
    end
end)

-- Move ped to your location
RegisterCommand('moveped', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local closestPed = nil
    local closestDist = 50.0

    local validPeds = {}
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end
    SpawnedPeds = validPeds

    if closestPed then
        SetEntityCoords(closestPed, playerCoords.x + 1.0, playerCoords.y, playerCoords.z - 1.0, false, false, false, true)
        SetEntityHeading(closestPed, heading)
        Notify("Moved ped to your location")
    else
        Notify("No ped found nearby!")
    end
end)

-- Stop ped animation
RegisterCommand('stopanimp', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = 10.0

    local validPeds = {}
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            table.insert(validPeds, ped)
            local pedCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - pedCoords)
            if dist < closestDist then
                closestPed = ped
                closestDist = dist
            end
        end
    end
    SpawnedPeds = validPeds

    if closestPed then
        clearPedProps(closestPed)
        ClearPedTasks(closestPed)
        Notify("Stopped ped animation")
    else
        Notify("No ped found nearby!")
    end
end)

-- List available emotes
RegisterCommand('listemotes', function()
    -- Count total emotes from rpemotes
    local count = CountEmotes()

    Notify("Total emotes available: " .. count)

    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255},
        multiline = true,
        args = {"Popular Emotes (from rpemotes-reborn)", [[ 
DANCE: dance, dance2, dance3, dance4, danceslow, dancesilly, djing
SMOKE/DRINK: smoke, cigarette, cigar, drink, beer, coffee, wine
PHONE: phone, phonecall, phonetext, text, selfie
SIT: sit, sitchair, sit2, sitground, sitknees, sitdrunk, sitscared
LEAN: lean, lean2, leanbar
EMOTIONS: clap, slowclap, salute, wave, point, shrug, facepalm, cry
POSES: crossarms, crossarms2, guard, clipboard, kneel
ACTIONS: pushup, situp, yoga, stretch, camera, photo, film, fishing
WORK: mechanic, workout, argue, cop, cop2, traffic, medic, type
FUN: dab, thumbsup, peace, rock, nervous, flex, knock, rawr
PARTY: djing, drinking, drinkwhiskey, moonwalk
Try any emote name! Examples: cop3, smoke2, dance5, sitchair2, etc.
        ]]}
    })
end)

-- Save presets to file and cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('[ped-director] Resource stopping - cleaning up...')
        
        -- Stop the follow thread
        isResourceActive = false
        
        -- Delete all spawned peds and their props
        local count = 0
        for _, ped in ipairs(SpawnedPeds) do
            clearPedProps(ped)
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
                count = count + 1
            end
        end
        
        -- Clear tables
        SpawnedPeds = {}
        FollowPeds = {}
        PedProps = {}
        PedBehaviors = {}
        PedFactionAssignments = {}
        PatrolRouteNodes = {}
        RelationshipGroups = {}
        RelationshipGroupsInitialized = false
        
        print('[ped-director] Cleaned up ' .. count .. ' peds')
    end
end)

-- Help command
RegisterCommand('peddirector', function()
    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255},
        multiline = true,
        args = {"Ped Director - Scene Director Commands", [[
/spawnped [model] - Spawn a ped (default: skater)
/pedemote [emote] - Play emote animation (1636+ emotes!)
/listemotes - Show popular emotes
/pedanim [dict] [anim] - Play animation on nearest ped
/pedscenario [scenario] - Play scenario on nearest ped
/moveped - Move nearest ped to you
/freezeped - Toggle freeze on nearest ped
/stopanimp - Stop ped animation
/deleteped - Delete nearest ped
/clearallpeds - Delete all spawned peds

Scene Director:
/scenemode - Toggle between SETUP and ACTIVE scene modes
/assignslot [1-9] - Assign nearest ped to slot
/swapslot [1-9] - Swap to ped in slot (possess mode)
/possess - Possess nearest ped with camera control
/cloneped - Clone nearest ped
/waypointall - Set same waypoint for all peds
/teleportall - Teleport all peds to waypoint
/emoteall [emote] - Apply emote to all peds
/stopall - Stop animations for all peds
/scenereset - Reset scene director state
/addlight - DISABLED (causes crashes)
/removelight [id] - DISABLED (causes crashes)

Driving/Patrol:
/pedvehicle [model] - Spawn vehicle and put nearest ped in driver seat
/pedrouteadd - Add your current location as a patrol node
/pedrouteclear - Clear all patrol route nodes
/pedrouteinfo - Show patrol node count
/peddrive [wander|towp|patrol|stop] [speed] - Set drive behavior
/pedchase - Toggle vehicle chase mode (all peds chase player)
/pedescort - Toggle vehicle escort mode (all peds escort player)

Factions/Combat:
/pedfaction [civilian|police|gang|guard] - Assign nearest ped faction profile
/pedcombat [player|nearest|faction|stop] [factionName] - Start/stop combat behavior

Preset System:
/savepedpreset [name] - Save nearest ped as preset with name
/loadpedpreset [number] - Load preset by number from list
/loadpedpreset [name] - Load preset by name
/listpedpresets - Show numbered list of saved presets

Menu:
/pedmenu - Open GUI Menu

Quick Scene Example:
/scenemode (set to SETUP)
/spawnped s_m_y_cop_01
/assignslot 1
/spawnped a_m_m_skater_01
/assignslot 2
/waypointall (waypoint stored)
/scenemode (set to ACTIVE - waypoints execute)
/pedchase
        ]]}
    })
end)

-- Scene Director functions
function ToggleSceneMode()
    if SceneMode == SCENE_MODE_SETUP then
        SceneMode = SCENE_MODE_ACTIVE
        Notify("Scene mode: ACTIVE - Waypoints will execute immediately")
        -- Trigger all stored waypoints
        for slot, ped in pairs(ActorSlots) do
            if PedBehaviors[ped] and PedBehaviors[ped].mode == "towp" then
                issueBehaviorTask(ped, PedBehaviors[ped])
            end
        end
    else
        SceneMode = SCENE_MODE_SETUP
        Notify("Scene mode: SETUP - Waypoints will be stored")
    end
end

function AssignPedToSlot(slot, ped)
    if slot < 1 or slot > 9 then return false end
    if not DoesEntityExist(ped) then return false end

    -- Remove from old slot
    local oldSlot = PedSlotAssignments[ped]
    if oldSlot then
        ActorSlots[oldSlot] = nil
        if SlotBlips[oldSlot] then
            RemoveBlip(SlotBlips[oldSlot])
            SlotBlips[oldSlot] = nil
        end
    end

    -- Assign to new slot
    ActorSlots[slot] = ped
    PedSlotAssignments[ped] = slot

    -- Create blip
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Slot " .. slot)
    EndTextCommandSetBlipName(blip)
    SlotBlips[slot] = blip

    Notify(("Assigned ped to slot %d"):format(slot))
    return true
end

function SwapToSlot(slot)
    if slot < 1 or slot > 9 then return end
    local ped = ActorSlots[slot]
    if not ped or not DoesEntityExist(ped) then
        Notify("No ped in slot " .. slot)
        return
    end

    -- Start possessing this ped
    StartPossess(ped)
end

function StartPossess(ped)
    if not DoesEntityExist(ped) then return end

    -- Stop previous possess
    if IsPossessing then
        StopPossess()
    end

    PossessedPed = ped
    IsPossessing = true

    -- Create camera attached to ped
    if not PossessCamera or not DoesCamExist(PossessCamera) then
        PossessCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end

    local pedCoords = GetEntityCoords(ped)
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, -3.0, 1.5)
    SetCamCoord(PossessCamera, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(PossessCamera, ped, 0.0, 0.0, 0.0, true)
    SetCamFov(PossessCamera, 45.0)
    SetCamActive(PossessCamera, true)
    RenderScriptCams(true, false, 3000, true, true)

    Notify("Possessing ped - Press ENTER to stop")
end

function StopPossess()
    if PossessCamera and DoesCamExist(PossessCamera) then
        SetCamActive(PossessCamera, false)
        RenderScriptCams(false, false, 3000, true, true)
        DestroyCam(PossessCamera, false)
    end
    PossessCamera = nil
    PossessedPed = nil
    IsPossessing = false
    Notify("Stopped possessing")
end

function ClonePed(ped)
    if not DoesEntityExist(ped) then return end

    local model = GetEntityModel(ped)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        Notify("Failed to load model for cloning")
        return
    end

    local clone = CreatePed(4, model, coords.x + 1.0, coords.y, coords.z, heading, true, false)
    if not DoesEntityExist(clone) then
        Notify("Failed to create clone")
        return
    end

    SetEntityAsMissionEntity(clone, true, true)
    NetworkRegisterEntityAsNetworked(clone)
    local netId = NetworkGetNetworkIdFromEntity(clone)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)

    SetPedCanRagdoll(clone, false)
    SetBlockingOfNonTemporaryEvents(clone, true)

    table.insert(SpawnedPeds, clone)
    Notify("Cloned ped")

    return clone
end

-- Lighting system
function CreateStageLight(pos, color, intensity)
    local lightId = NextLightId
    NextLightId = NextLightId + 1

    local light = {
        id = lightId,
        pos = pos,
        color = color or {r = 255, g = 255, b = 255},
        intensity = intensity or 1.0,
        range = 20.0,
        enabled = true
    }

    StageLights[lightId] = light

    if light.enabled then
        DRAW_LIGHT_WITH_RANGE(pos.x, pos.y, pos.z, light.color.r, light.color.g, light.color.b, light.range, intensity)
    end

    return lightId
end

function RemoveStageLight(lightId)
    if StageLights[lightId] then
        StageLights[lightId] = nil
        Notify("Stage light removed")
    end
end

function ToggleStageLight(lightId)
    if StageLights[lightId] then
        StageLights[lightId].enabled = not StageLights[lightId].enabled
        Notify("Stage light " .. (StageLights[lightId].enabled and "enabled" or "disabled"))
    end
end

function ClearAllStageLights()
    StageLights = {}
    NextLightId = 1
    Notify("All stage lights cleared")
end

-- Update lights in a thread (disabled for stability)
--[[
CreateThread(function()
    while isResourceActive do
        Wait(100)
        for _, light in pairs(StageLights) do
            if light.enabled then
                -- Disabled: DRAW_LIGHT_WITH_RANGE can cause crashes
            end
        end
    end
end)
--]]

-- Vehicle formations
local IsChasingPlayer = false
local IsEscortingPlayer = false

function StartVehicleChase()
    local playerPed = PlayerPedId()
    if not IsPedInAnyVehicle(playerPed, false) then
        Notify("Player not in vehicle")
        return
    end

    IsChasingPlayer = true
    Notify("Vehicle chase started")

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) and ped ~= playerPed then
            local vehicle = ensurePedVehicle(ped, nil) -- Use default vehicle
            if vehicle then
                TaskVehicleChase(ped, playerPed)
            end
        end
    end
end

function StartVehicleEscort()
    local playerPed = PlayerPedId()
    if not IsPedInAnyVehicle(playerPed, false) then
        Notify("Player not in vehicle")
        return
    end

    IsEscortingPlayer = true
    Notify("Vehicle escort started")

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) and ped ~= playerPed then
            local vehicle = ensurePedVehicle(ped, nil)
            if vehicle then
                TaskVehicleEscort(ped, GetVehiclePedIsIn(playerPed, false), -1, 30.0, 786603, 10.0)
            end
        end
    end
end

function StopVehicleFormations()
    IsChasingPlayer = false
    IsEscortingPlayer = false

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            ClearPedTasks(ped)
        end
    end

    Notify("Vehicle formations stopped")
end

-- Debug command to inspect saved preset data
RegisterCommand('inspectpreset', function(source, args)
    local presetName = args[1]
    if not presetName or presetName == "" then
        Notify("Usage: /inspectpreset [name]")
        return
    end
    
    local preset = SavedPresets[presetName]
    if not preset then
        Notify("Preset not found: " .. presetName)
        return
    end
    
    Notify(("Preset: %s"):format(presetName))
    Notify(("Model: %s"):format(preset.model))
    Notify(("Coords: %.2f, %.2f, %.2f"):format(preset.coords.x, preset.coords.y, preset.coords.z))
    Notify(("Components: %d saved"):format(preset.clothing and #preset.clothing or 0))
end, false)

-- Scene Director commands
RegisterCommand('scenemode', function()
    ToggleSceneMode()
end)

RegisterCommand('assignslot', function(source, args)
    local slot = tonumber(args[1])
    if not slot then
        Notify("Usage: /assignslot [1-9]")
        return
    end

    local ped = GetClosestSpawnedPed(10.0)
    if ped then
        AssignPedToSlot(slot, ped)
    else
        Notify("No ped nearby")
    end
end)

RegisterCommand('swapslot', function(source, args)
    local slot = tonumber(args[1])
    if not slot then
        Notify("Usage: /swapslot [1-9]")
        return
    end
    SwapToSlot(slot)
end)

RegisterCommand('possess', function()
    local ped = GetClosestSpawnedPed(10.0)
    if ped then
        StartPossess(ped)
    else
        Notify("No ped nearby")
    end
end)

RegisterCommand('cloneped', function()
    local ped = GetClosestSpawnedPed(10.0)
    if ped then
        ClonePed(ped)
    else
        Notify("No ped nearby")
    end
end)

RegisterCommand('waypointall', function()
    if not IsWaypointActive() then
        Notify("No waypoint set")
        return
    end

    local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
    local foundGround, zPos = GetGroundZFor_3dCoord(waypointCoords.x, waypointCoords.y, 1000.0, 0)
    if foundGround then
        waypointCoords = vector3(waypointCoords.x, waypointCoords.y, zPos)
    end

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            PedBehaviors[ped] = {
                mode = "towp",
                speed = 18.0,
                drivingStyle = 786603,
                lastTaskAt = GetGameTimer(),
                arriveDistance = 8.0
            }
            if SceneMode == SCENE_MODE_ACTIVE then
                issueBehaviorTask(ped, PedBehaviors[ped])
            end
        end
    end

    Notify("Set waypoint for all peds")
end)

RegisterCommand('scenereset', function()
    -- Reset scene director state
    SceneMode = SCENE_MODE_SETUP
    ActorSlots = {}
    PedSlotAssignments = {}

    -- Remove all slot blips
    for slot, blip in pairs(SlotBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    SlotBlips = {}

    -- Stop formations
    StopVehicleFormations()

    -- Clear all behaviors
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            PedBehaviors[ped] = nil
            clearPedProps(ped)
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, true)
        end
    end

    -- Stop possess if active
    if IsPossessing then
        StopPossess()
    end

    Notify("Scene director reset - all slots cleared, behaviors stopped")
end)

RegisterCommand('teleportall', function()
    if not IsWaypointActive() then
        Notify("No waypoint set")
        return
    end

    local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
    local foundGround, zPos = GetGroundZFor_3dCoord(waypointCoords.x, waypointCoords.y, 1000.0, 0)
    if foundGround then
        waypointCoords = vector3(waypointCoords.x, waypointCoords.y, zPos)
    end

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            SetEntityCoords(ped, waypointCoords.x, waypointCoords.y, waypointCoords.z, false, false, false, true)
        end
    end

    Notify("Teleported all peds to waypoint")
end)

RegisterCommand('pedchase', function()
    if IsChasingPlayer then
        StopVehicleFormations()
    else
        StartVehicleChase()
    end
end)

RegisterCommand('pedescort', function()
    if IsEscortingPlayer then
        StopVehicleFormations()
    else
        StartVehicleEscort()
    end
end)

-- Stage lighting commands disabled for stability
--[[
RegisterCommand('addlight', function()
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    pos = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.0, 0.0)
    local lightId = CreateStageLight(pos)
    Notify("Stage light created (ID: " .. lightId .. ")")
end)

RegisterCommand('removelight', function(source, args)
    local lightId = tonumber(args[1])
    if lightId then
        RemoveStageLight(lightId)
    else
        ClearAllStageLights()
    end
end)
--]]

RegisterCommand('addlight', function()
    Notify("Stage lighting disabled for stability")
end)

RegisterCommand('removelight', function()
    Notify("Stage lighting disabled for stability")
end)

RegisterCommand('emoteall', function(source, args)
    if #args < 1 then
        Notify("Usage: /emoteall [emote name]")
        return
    end

    local emoteName = args[1]
    local emoteData = GetEmote(emoteName)

    if not emoteData then
        Notify("Emote '" .. emoteName .. "' not found.")
        return
    end

    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            TriggerEvent('ped-director:playEmoteOnPed', ped, emoteName)
        end
    end

    Notify("Applied emote to all peds: " .. emoteName)
end)

RegisterCommand('stopall', function()
    for _, ped in ipairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            clearPedProps(ped)
            ClearPedTasks(ped)
        end
    end
    Notify("Stopped animations for all peds")
end)

-- Thread for possess controls (simplified for stability)
CreateThread(function()
    while isResourceActive do
        Wait(100) -- Changed from 0 to 100ms for stability
        
        if not IsPossessing then
            Wait(500) -- Longer wait when not possessing
            goto continue
        end
        
        if not PossessedPed or not DoesEntityExist(PossessedPed) then
            IsPossessing = false
            goto continue
        end
        
        -- Only process when actually possessing
        local success, err = pcall(function()
            -- Camera controls - only check every 100ms
            if IsDisabledControlPressed(0, 32) then -- W
                AdjustPedOffset(PossessedPed, 0.0, 0.1, 0.0, 0.0, false)
            end
            if IsDisabledControlPressed(0, 33) then -- S
                AdjustPedOffset(PossessedPed, 0.0, -0.1, 0.0, 0.0, false)
            end
            if IsDisabledControlPressed(0, 34) then -- A
                AdjustPedOffset(PossessedPed, -0.1, 0.0, 0.0, 0.0, false)
            end
            if IsDisabledControlPressed(0, 30) then -- D
                AdjustPedOffset(PossessedPed, 0.1, 0.0, 0.0, 0.0, false)
            end

            -- Stop possess
            if IsDisabledControlJustPressed(0, 191) then -- Enter
                StopPossess()
            end
        end)

        if not success then
            print("[ped-director] Possess controls error: " .. tostring(err))
            IsPossessing = false -- Stop possessing on error
        end
        
        ::continue::
    end
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ClearPedDirectorCamera()
end)
