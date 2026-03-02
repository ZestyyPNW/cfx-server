--[[
    Ped Director v2.0 - Core Client Module
    Manages ped spawning, state, behaviors, scene direction, and cleanup.
    Single-responsibility: all ped data lives here, menu.lua reads/writes via exposed API.
]]

-- =============================================
-- RUNTIME FLAG
-- =============================================
local ALIVE = true
local NativeRemoveAllPedWeapons = RemoveAllPedWeapons

-- =============================================
-- CENTRAL STATE
-- =============================================
local MAX_PEDS = 20

PedDir = PedDir or {}

PedDir.peds       = {}   -- ordered list of ped handles
PedDir.props      = {}   -- ped -> {obj, obj, ...}
PedDir.behaviors  = {}   -- ped -> { mode, speed, ... }
PedDir.factions   = {}   -- ped -> faction name
PedDir.following  = {}   -- ped -> true
PedDir.presets    = {}   -- name -> preset data

PedDir.slots      = {}   -- slot 1-9 -> ped
PedDir.slotBlips  = {}   -- slot -> blip
PedDir.pedSlots   = {}   -- ped -> slot

PedDir.sceneMode  = 'setup' -- 'setup' | 'active'
PedDir.chasing    = false
PedDir.escorting  = false

PedDir.gizmo      = { active = false, ped = nil, mode = 'MOVE' }
PedDir.possess    = { active = false, ped = nil, cam = nil }
PedDir.clothCam   = { handle = nil, active = false }

PedDir.patrolNodes = {}

-- Faction definitions
local FactionProfiles = {
    civilian = { group = 'PEDDIR_CIV',    accuracy = 12, ability = 0, range = 0, movement = 1, alertness = 1 },
    police   = { group = 'PEDDIR_POLICE', accuracy = 55, ability = 2, range = 2, movement = 2, alertness = 3 },
    gang     = { group = 'PEDDIR_GANG',   accuracy = 42, ability = 1, range = 1, movement = 2, alertness = 3 },
    guard    = { group = 'PEDDIR_GUARD',  accuracy = 50, ability = 2, range = 2, movement = 1, alertness = 2 },
}
local RelGroups = {}
local RelGroupsReady = false

-- =============================================
-- HELPERS
-- =============================================

local function Notify(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(tostring(msg))
    DrawNotification(false, true)
end
PedDir.Notify = Notify

local function DrawText3D(x, y, z, text)
    local ok, sx, sy = World3dToScreen2d(x, y, z)
    if not ok then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(sx, sy)
    DrawRect(sx, sy + 0.0125, 0.015 + #text / 370, 0.03, 41, 11, 41, 68)
end

local function LoadModel(hash, timeoutMs)
    if type(hash) == 'string' then hash = GetHashKey(hash) end
    if HasModelLoaded(hash) then return true end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

local function LoadAnimDict(dict, timeoutMs)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

local function LoadClipSet(name, timeoutMs)
    RequestClipSet(name)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasClipSetLoaded(name) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

-- Remove dead peds from the ordered list, return cleaned list
local function PrunePeds()
    local clean = {}
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then
            clean[#clean + 1] = ped
        else
            PedDir.props[ped]      = nil
            PedDir.behaviors[ped]  = nil
            PedDir.factions[ped]   = nil
            PedDir.following[ped]  = nil
            local slot = PedDir.pedSlots[ped]
            if slot then
                PedDir.slots[slot] = nil
                if PedDir.slotBlips[slot] and DoesBlipExist(PedDir.slotBlips[slot]) then
                    RemoveBlip(PedDir.slotBlips[slot])
                end
                PedDir.slotBlips[slot] = nil
                PedDir.pedSlots[ped] = nil
            end
        end
    end
    PedDir.peds = clean
    return clean
end
PedDir.Prune = PrunePeds

local function GetClosest(maxDist)
    maxDist = maxDist or 10.0
    PrunePeds()
    local pCoords = GetEntityCoords(PlayerPedId())
    local best, bestDist, bestIdx = nil, maxDist, nil
    for i, ped in ipairs(PedDir.peds) do
        local d = #(pCoords - GetEntityCoords(ped))
        if d < bestDist then
            best, bestDist, bestIdx = ped, d, i
        end
    end
    return best, bestDist, bestIdx
end
PedDir.GetClosest = GetClosest

local function GetClosestExcluding(maxDist, exclude, predicate)
    PrunePeds()
    local pCoords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, maxDist or 10.0
    for _, ped in ipairs(PedDir.peds) do
        if ped ~= exclude then
            local allowed = not predicate or predicate(ped)
            if allowed then
                local d = #(pCoords - GetEntityCoords(ped))
                if d < bestDist then
                    best, bestDist = ped, d
                end
            end
        end
    end
    return best, bestDist
end

-- =============================================
-- PED SPAWNING
-- =============================================

local function SetupNetworkedPed(ped)
    SetEntityAsMissionEntity(ped, true, true)
    NetworkRegisterEntityAsNetworked(ped)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

function PedDir.SpawnPed(model)
    if #PedDir.peds >= MAX_PEDS then
        Notify('Max ped limit reached (' .. MAX_PEDS .. ')')
        return nil
    end

    model = model or 'a_m_m_skater_01'
    local hash = GetHashKey(model)
    if not LoadModel(hash) then
        Notify('Failed to load model: ' .. model)
        return nil
    end

    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    local h = GetEntityHeading(p)

    local ped = CreatePed(4, hash, c.x + 1.0, c.y, c.z - 1.0, h, true, false)
    SetModelAsNoLongerNeeded(hash)

    if not DoesEntityExist(ped) then
        Notify('Failed to create ped')
        return nil
    end

    SetupNetworkedPed(ped)
    FreezeEntityPosition(ped, true)
    PedDir.peds[#PedDir.peds + 1] = ped
    Notify('Spawned: ' .. model .. ' (' .. #PedDir.peds .. '/' .. MAX_PEDS .. ')')
    return ped
end

-- =============================================
-- PROP MANAGEMENT
-- =============================================

local function AttachProp(ped, propModel, bone, placement)
    if not propModel or propModel == '' then return nil end
    local hash = GetHashKey(propModel)
    if not LoadModel(hash) then return nil end

    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end

    local bi = GetPedBoneIndex(ped, bone or 28422)
    local p = placement or {}
    AttachEntityToEntity(obj, ped, bi,
        p[1] or 0.0, p[2] or 0.0, p[3] or 0.0,
        p[4] or 0.0, p[5] or 0.0, p[6] or 0.0,
        true, true, false, true, 1, true)
    return obj
end

function PedDir.ClearProps(ped)
    local list = PedDir.props[ped]
    if not list then return end
    for _, obj in ipairs(list) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
    PedDir.props[ped] = nil
end

-- =============================================
-- EMOTE PLAYBACK
-- =============================================

function PedDir.PlayEmote(ped, emoteName)
    if not DoesEntityExist(ped) then return end
    local data = GetEmote(emoteName)
    if not data then
        Notify("Emote '" .. emoteName .. "' not found")
        return
    end

    if not LoadAnimDict(data.dict) then
        Notify('Failed to load anim dict')
        return
    end

    PedDir.ClearProps(ped)
    TaskPlayAnim(ped, data.dict, data.anim, 8.0, -8.0, -1, 1, 0, false, false, false)

    local opts = data.options
    if opts then
        local props = {}
        if opts.Prop then
            local o = AttachProp(ped, opts.Prop, opts.PropBone, opts.PropPlacement)
            if o then props[#props + 1] = o end
        end
        if opts.SecondProp then
            local o = AttachProp(ped, opts.SecondProp, opts.SecondPropBone, opts.SecondPropPlacement)
            if o then props[#props + 1] = o end
        end
        if #props > 0 then PedDir.props[ped] = props end
    end

    Notify('Emote: ' .. (data.name or emoteName))
end

-- =============================================
-- POSITIONING
-- =============================================

function PedDir.AdjustOffset(ped, xOff, yOff, zOff, headingOff, relative)
    if not DoesEntityExist(ped) then return end
    if headingOff and headingOff ~= 0.0 then
        SetEntityHeading(ped, GetEntityHeading(ped) + headingOff)
    end
    if xOff ~= 0.0 or yOff ~= 0.0 or zOff ~= 0.0 then
        if relative then
            local o = GetOffsetFromEntityInWorldCoords(ped, xOff, yOff, zOff)
            SetEntityCoords(ped, o.x, o.y, o.z, false, false, false, true)
        else
            local c = GetEntityCoords(ped)
            SetEntityCoords(ped, c.x + xOff, c.y + yOff, c.z + zOff, false, false, false, true)
        end
    end
end

function PedDir.SnapToGround(ped)
    if not DoesEntityExist(ped) then return end
    local c = GetEntityCoords(ped)
    local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 10.0, false)
    if not found then
        found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 500.0, false)
    end
    if found then
        SetEntityCoords(ped, c.x, c.y, z, false, false, false, true)
        Notify('Snapped to ground')
    else
        Notify('Could not find ground')
    end
end

-- =============================================
-- CLOTHING
-- =============================================

function PedDir.SetClothing(ped, compId, drawable, texture)
    SetPedComponentVariation(ped, compId, drawable, texture, 0)
end

-- =============================================
-- WALKING STYLE
-- =============================================

function PedDir.SetWalkStyle(ped, clipSet)
    if not DoesEntityExist(ped) then return end
    if not LoadClipSet(clipSet) then
        Notify('Failed to load clip set')
        return
    end
    SetPedMovementClipset(ped, clipSet, 1.0)
    Notify('Walk style: ' .. clipSet)
end

-- =============================================
-- WEAPONS
-- =============================================

function PedDir.GiveWeapon(ped, weaponName)
    if not DoesEntityExist(ped) then return end
    local hash = GetHashKey(weaponName)
    local ok, valid = pcall(IsWeaponValid, hash)
    if ok and not valid then
        Notify('Invalid weapon: ' .. weaponName)
        return
    end

    local wasFrozen = IsEntityPositionFrozen(ped)
    if wasFrozen then FreezeEntityPosition(ped, false) end

    PedDir.ClearProps(ped)
    ClearPedTasksImmediately(ped)
    SetPedCanSwitchWeapon(ped, true)
    GiveWeaponToPed(ped, hash, 999, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    SetPedCurrentWeaponVisible(ped, true, true, true, true)

    if wasFrozen then FreezeEntityPosition(ped, true) end
    Notify('Weapon: ' .. weaponName)
end

function PedDir.RemoveWeapons(ped)
    if not DoesEntityExist(ped) then return end
    NativeRemoveAllPedWeapons(ped, true)
    Notify('Weapons removed')
end

-- =============================================
-- FOLLOW MODE
-- =============================================

function PedDir.ToggleFollow(ped)
    if not DoesEntityExist(ped) then return end
    if PedDir.following[ped] then
        PedDir.following[ped] = nil
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, true)
        Notify('Follow stopped')
    else
        PedDir.following[ped] = true
        FreezeEntityPosition(ped, false)
        Notify('Follow started')
    end
end

-- =============================================
-- FACTIONS & COMBAT
-- =============================================

local function InitRelGroups()
    if RelGroupsReady then return end
    for name, prof in pairs(FactionProfiles) do
        RelGroups[name] = AddRelationshipGroup(prof.group)
    end
    for _, h1 in pairs(RelGroups) do
        for _, h2 in pairs(RelGroups) do
            SetRelationshipBetweenGroups(3, h1, h2)
        end
    end
    if RelGroups.police and RelGroups.gang then
        SetRelationshipBetweenGroups(5, RelGroups.police, RelGroups.gang)
        SetRelationshipBetweenGroups(5, RelGroups.gang, RelGroups.police)
    end
    if RelGroups.guard and RelGroups.gang then
        SetRelationshipBetweenGroups(5, RelGroups.guard, RelGroups.gang)
        SetRelationshipBetweenGroups(5, RelGroups.gang, RelGroups.guard)
    end
    if RelGroups.police and RelGroups.civilian then
        SetRelationshipBetweenGroups(1, RelGroups.police, RelGroups.civilian)
        SetRelationshipBetweenGroups(3, RelGroups.civilian, RelGroups.police)
    end
    RelGroupsReady = true
end

function PedDir.SetFaction(ped, faction)
    if not DoesEntityExist(ped) then return false end
    faction = string.lower(faction or '')
    local prof = FactionProfiles[faction]
    if not prof then
        Notify('Unknown faction. Use: civilian, police, gang, guard')
        return false
    end
    InitRelGroups()
    local gh = RelGroups[faction]
    if not gh then return false end

    SetPedRelationshipGroupHash(ped, gh)
    SetPedAccuracy(ped, prof.accuracy)
    SetPedCombatAbility(ped, prof.ability)
    SetPedCombatRange(ped, prof.range)
    SetPedCombatMovement(ped, prof.movement)
    SetPedAlertness(ped, prof.alertness)
    SetPedCanSwitchWeapon(ped, true)
    SetCanAttackFriendly(ped, false, false)
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 46, true)
    PedDir.factions[ped] = faction
    Notify('Faction: ' .. faction)
    return true
end

function PedDir.StartCombat(ped, targetMode, factionTarget)
    if not DoesEntityExist(ped) then return end

    if targetMode == 'stop' then
        ClearPedTasks(ped)
        Notify('Combat stopped')
        return
    end

    local target
    if targetMode == 'player' then
        target = PlayerPedId()
    elseif targetMode == 'nearest' then
        target = GetClosestExcluding(60.0, ped)
    elseif targetMode == 'faction' then
        local ft = string.lower(factionTarget or '')
        target = GetClosestExcluding(80.0, ped, function(p)
            return PedDir.factions[p] == ft
        end)
    end

    if not target or not DoesEntityExist(target) then
        Notify('No valid target')
        return
    end

    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    TaskCombatPed(ped, target, 0, 16)
    Notify('Combat started')
end

-- =============================================
-- DRIVING / PATROL BEHAVIORS
-- =============================================

local function GetWaypointGround()
    if not IsWaypointActive() then return nil end
    local wp = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
    local found, z = GetGroundZFor_3dCoord(wp.x, wp.y, 1000.0, false)
    return vector3(wp.x, wp.y, found and z or wp.z)
end

function PedDir.EnsureVehicle(ped, vehModel)
    if IsPedInAnyVehicle(ped, false) then
        local v = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(v, -1) == ped then return v end
    end

    vehModel = vehModel or 'blista'
    local hash = GetHashKey(vehModel)
    if not LoadModel(hash) then
        Notify('Failed to load vehicle: ' .. vehModel)
        return nil
    end

    local spawn = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    return veh
end

local function IssueBehaviorTask(ped, beh)
    if not beh or not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)

    local speed = beh.speed or 18.0
    local style = beh.drivingStyle or 786603

    if beh.mode == 'wander' then
        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(v, -1) == ped then
                TaskVehicleDriveWander(ped, v, speed, style)
            end
        else
            TaskWanderStandard(ped, 10.0, 10)
        end
        beh.lastTask = GetGameTimer()
        return
    end

    if beh.mode == 'towp' then
        local dest = GetWaypointGround()
        if not dest then
            PedDir.behaviors[ped] = nil
            Notify('No waypoint set')
            return
        end
        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(v, -1) == ped then
                TaskVehicleDriveToCoordLongrange(ped, v, dest.x, dest.y, dest.z, speed, style, 8.0)
            else
                TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
            end
        else
            TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
        end
        beh.lastTask = GetGameTimer()
        return
    end

    if beh.mode == 'patrol' then
        local route = beh.route or {}
        if #route < 2 then
            PedDir.behaviors[ped] = nil
            Notify('Need 2+ patrol nodes')
            return
        end
        local idx = beh.routeIndex or 1
        if idx < 1 or idx > #route then idx = 1 end
        local dest = route[idx]
        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(v, -1) == ped then
                TaskVehicleDriveToCoordLongrange(ped, v, dest.x, dest.y, dest.z, speed, style, 10.0)
            else
                TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
            end
        else
            TaskGoStraightToCoord(ped, dest.x, dest.y, dest.z, 1.2, -1, 0.0, 0.2)
        end
        beh.lastTask = GetGameTimer()
    end
end

-- =============================================
-- SCENE DIRECTOR
-- =============================================

function PedDir.ToggleSceneMode()
    if PedDir.sceneMode == 'setup' then
        PedDir.sceneMode = 'active'
        Notify('Scene: ACTIVE')
        for _, ped in ipairs(PedDir.peds) do
            local beh = PedDir.behaviors[ped]
            if beh and beh.mode == 'towp' then
                IssueBehaviorTask(ped, beh)
            end
        end
    else
        PedDir.sceneMode = 'setup'
        Notify('Scene: SETUP')
    end
end

function PedDir.AssignSlot(slot, ped)
    if slot < 1 or slot > 9 or not DoesEntityExist(ped) then return false end

    local old = PedDir.pedSlots[ped]
    if old then
        PedDir.slots[old] = nil
        if PedDir.slotBlips[old] and DoesBlipExist(PedDir.slotBlips[old]) then
            RemoveBlip(PedDir.slotBlips[old])
        end
        PedDir.slotBlips[old] = nil
    end

    PedDir.slots[slot] = ped
    PedDir.pedSlots[ped] = slot

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Slot ' .. slot)
    EndTextCommandSetBlipName(blip)
    PedDir.slotBlips[slot] = blip

    Notify('Slot ' .. slot .. ' assigned')
    return true
end

-- =============================================
-- POSSESS CAMERA
-- =============================================

function PedDir.StartPossess(ped)
    if not DoesEntityExist(ped) then return end
    PedDir.StopPossess()

    local pos = PedDir.possess
    pos.ped = ped
    pos.active = true

    if not pos.cam or not DoesCamExist(pos.cam) then
        pos.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end
    local cc = GetOffsetFromEntityInWorldCoords(ped, 0.0, -3.0, 1.5)
    SetCamCoord(pos.cam, cc.x, cc.y, cc.z)
    PointCamAtEntity(pos.cam, ped, 0.0, 0.0, 0.0, true)
    SetCamFov(pos.cam, 45.0)
    SetCamActive(pos.cam, true)
    RenderScriptCams(true, false, 3000, true, true)
    Notify('Possessing - ENTER to stop')
end

function PedDir.StopPossess()
    local pos = PedDir.possess
    if pos.cam and DoesCamExist(pos.cam) then
        SetCamActive(pos.cam, false)
        RenderScriptCams(false, false, 3000, true, true)
        DestroyCam(pos.cam, false)
    end
    pos.cam = nil
    pos.ped = nil
    pos.active = false
end

-- =============================================
-- CLOTHING CAMERA
-- =============================================

local function ResolveClothFocus(part)
    local key = string.lower(tostring(part or 'body'))
    if key:find('face', 1, true) or key:find('mask', 1, true) or key:find('hair', 1, true)
       or key:find('hat', 1, true) or key:find('glasses', 1, true) or key:find('ear', 1, true) then
        return { dist = 0.8, height = 0.72, targetZ = 0.72, fov = 34.0 }
    end
    if key:find('legs', 1, true) or key:find('shoes', 1, true) or key:find('ankle', 1, true) then
        return { dist = 1.0, height = 0.2, targetZ = 0.25, fov = 36.0 }
    end
    if key:find('watch', 1, true) or key:find('bracelet', 1, true) or key:find('arm', 1, true) then
        return { dist = 0.95, height = 0.45, targetZ = 0.45, fov = 35.0 }
    end
    return { dist = 1.3, height = 0.52, targetZ = 0.55, fov = 40.0 }
end

function PedDir.FocusClothCam(ped, focusPart)
    if not DoesEntityExist(ped) then return end
    local cam = PedDir.clothCam
    if not cam.handle or not DoesCamExist(cam.handle) then
        cam.handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end
    local cfg = ResolveClothFocus(focusPart)
    local cc = GetOffsetFromEntityInWorldCoords(ped, 0.08, cfg.dist, cfg.height)
    local tc = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, cfg.targetZ)
    SetCamCoord(cam.handle, cc.x, cc.y, cc.z)
    PointCamAtCoord(cam.handle, tc.x, tc.y, tc.z)
    SetCamFov(cam.handle, cfg.fov)
    if not cam.active then
        SetCamActive(cam.handle, true)
        RenderScriptCams(true, true, 250, true, true)
        cam.active = true
    end
end

function PedDir.ClearClothCam()
    local cam = PedDir.clothCam
    if not cam.handle then return end
    if DoesCamExist(cam.handle) then
        RenderScriptCams(false, false, 0, false, false)
        DestroyCam(cam.handle, false)
    end
    cam.handle = nil
    cam.active = false
end

-- =============================================
-- CLONE
-- =============================================

function PedDir.ClonePed(ped)
    if not DoesEntityExist(ped) then return nil end
    local model = GetEntityModel(ped)
    if not LoadModel(model) then
        Notify('Failed to load model for clone')
        return nil
    end
    local c = GetEntityCoords(ped)
    local clone = CreatePed(4, model, c.x + 1.0, c.y, c.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(clone) then
        Notify('Clone failed')
        return nil
    end
    SetupNetworkedPed(clone)
    PedDir.peds[#PedDir.peds + 1] = clone
    Notify('Cloned')
    return clone
end

-- =============================================
-- PRESETS
-- =============================================

function PedDir.SavePreset(ped, name)
    if not DoesEntityExist(ped) then
        Notify('Invalid ped')
        return false
    end
    local clothing = {}
    local count = 0
    for compId = 0, 11 do
        local d = GetPedDrawableVariation(ped, compId)
        local t = GetPedTextureVariation(ped, compId)
        local p = GetPedPropIndex(ped, compId)
        local pt = GetPedPropTextureIndex(ped, compId)
        local entry = {}
        if d ~= -1 then entry.drawable = d; entry.texture = t; count = count + 1 end
        if p ~= -1 then entry.prop = p; entry.propTexture = pt; count = count + 1 end
        if entry.drawable or entry.prop then clothing[compId] = entry end
    end
    if count == 0 then
        Notify('No clothing data found')
        return false
    end
    local data = {
        model = GetEntityModel(ped),
        coords = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
        clothing = clothing,
        timestamp = GetGameTimer()
    }
    PedDir.presets[name] = data
    TriggerServerEvent('ped-director:savePreset', name, data)
    Notify("Preset '" .. name .. "' saved")
    return true
end

function PedDir.LoadPreset(name)
    local preset = PedDir.presets[name]
    if not preset then
        Notify('Preset not found: ' .. name)
        return nil
    end
    if not LoadModel(preset.model) then
        Notify('Failed to load preset model')
        return nil
    end
    local pc = GetEntityCoords(PlayerPedId())
    local ped = CreatePed(4, preset.model, pc.x + 1.0, pc.y, pc.z - 1.0, GetEntityHeading(PlayerPedId()), true, false)
    SetModelAsNoLongerNeeded(preset.model)
    if not DoesEntityExist(ped) then
        Notify('Failed to create preset ped')
        return nil
    end
    SetupNetworkedPed(ped)
    if preset.clothing then
        for compId, d in pairs(preset.clothing) do
            compId = tonumber(compId)
            if d.drawable then SetPedComponentVariation(ped, compId, d.drawable, d.texture or 0, 0) end
            if d.prop then SetPedPropIndex(ped, compId, d.prop, d.propTexture or 0, true) end
        end
    end
    PedDir.peds[#PedDir.peds + 1] = ped
    Notify('Loaded preset: ' .. name)
    return ped
end

function PedDir.GetPresetNames()
    local names = {}
    for n in pairs(PedDir.presets) do names[#names + 1] = n end
    table.sort(names)
    return names
end

function PedDir.RefreshPresets()
    TriggerServerEvent('ped-director:requestPresets')
end

RegisterNetEvent('ped-director:receivePresets', function(data)
    if data then
        PedDir.presets = data
        local c = 0; for _ in pairs(data) do c = c + 1 end
        print('[ped-director] Loaded ' .. c .. ' presets')
    end
end)

-- =============================================
-- DELETE / CLEANUP
-- =============================================

function PedDir.DeletePed(ped, idx)
    if not DoesEntityExist(ped) then return end
    PedDir.ClearProps(ped)
    PedDir.behaviors[ped] = nil
    PedDir.following[ped] = nil
    PedDir.factions[ped] = nil
    local slot = PedDir.pedSlots[ped]
    if slot then
        PedDir.slots[slot] = nil
        if PedDir.slotBlips[slot] and DoesBlipExist(PedDir.slotBlips[slot]) then
            RemoveBlip(PedDir.slotBlips[slot])
        end
        PedDir.slotBlips[slot] = nil
        PedDir.pedSlots[ped] = nil
    end
    DeleteEntity(ped)
    if idx then
        table.remove(PedDir.peds, idx)
    else
        PrunePeds()
    end
end

function PedDir.DeleteAll()
    for _, ped in ipairs(PedDir.peds) do
        PedDir.ClearProps(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    PedDir.peds      = {}
    PedDir.props     = {}
    PedDir.behaviors = {}
    PedDir.factions  = {}
    PedDir.following = {}
    for slot, blip in pairs(PedDir.slotBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    PedDir.slots     = {}
    PedDir.slotBlips = {}
    PedDir.pedSlots  = {}
end

function PedDir.SceneReset()
    PedDir.sceneMode = 'setup'
    for slot, blip in pairs(PedDir.slotBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    PedDir.slots     = {}
    PedDir.slotBlips = {}
    PedDir.pedSlots  = {}
    PedDir.chasing   = false
    PedDir.escorting = false
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then
            PedDir.behaviors[ped] = nil
            PedDir.ClearProps(ped)
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, true)
        end
    end
    PedDir.StopPossess()
    Notify('Scene reset')
end

-- =============================================
-- VEHICLE FORMATIONS
-- =============================================

function PedDir.StartChase()
    local pp = PlayerPedId()
    if not IsPedInAnyVehicle(pp, false) then
        Notify('Player not in vehicle')
        return
    end
    PedDir.chasing = true
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) and ped ~= pp then
            local v = PedDir.EnsureVehicle(ped)
            if v then TaskVehicleChase(ped, pp) end
        end
    end
    Notify('Chase started')
end

function PedDir.StartEscort()
    local pp = PlayerPedId()
    if not IsPedInAnyVehicle(pp, false) then
        Notify('Player not in vehicle')
        return
    end
    PedDir.escorting = true
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) and ped ~= pp then
            local v = PedDir.EnsureVehicle(ped)
            if v then
                TaskVehicleEscort(ped, GetVehiclePedIsIn(pp, false), -1, 30.0, 786603, 10.0)
            end
        end
    end
    Notify('Escort started')
end

function PedDir.StopFormations()
    PedDir.chasing = false
    PedDir.escorting = false
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then ClearPedTasks(ped) end
    end
    Notify('Formations stopped')
end

-- =============================================
-- BACKGROUND THREADS (all check ALIVE flag)
-- =============================================

-- Follow thread
CreateThread(function()
    while ALIVE do
        local sleep = 1000
        local pp = PlayerPedId()
        local pc = GetEntityCoords(pp)
        for ped, active in pairs(PedDir.following) do
            if active and DoesEntityExist(ped) then
                sleep = 200
                if #(pc - GetEntityCoords(ped)) > 2.0 then
                    TaskGoToEntity(ped, pp, -1, 1.5, 2.0, 1073741824.0, 0)
                end
            else
                PedDir.following[ped] = nil
            end
        end
        Wait(sleep)
    end
end)

-- Behavior (patrol/drive) thread
CreateThread(function()
    while ALIVE do
        Wait(500)
        local now = GetGameTimer()
        for ped, beh in pairs(PedDir.behaviors) do
            if not DoesEntityExist(ped) then
                PedDir.behaviors[ped] = nil
            elseif beh.mode == 'patrol' then
                local route = beh.route or {}
                if #route >= 1 then
                    local idx = beh.routeIndex or 1
                    if idx < 1 or idx > #route then idx = 1 end
                    local dest = route[idx]
                    local dist = #(GetEntityCoords(ped) - vector3(dest.x, dest.y, dest.z))
                    if dist <= (beh.arriveDistance or 12.0) then
                        beh.routeIndex = (idx % #route) + 1
                        IssueBehaviorTask(ped, beh)
                    elseif now - (beh.lastTask or 0) > 4500 then
                        IssueBehaviorTask(ped, beh)
                    end
                end
            elseif beh.mode == 'towp' then
                local dest = GetWaypointGround()
                if not dest then
                    PedDir.behaviors[ped] = nil
                else
                    if #(GetEntityCoords(ped) - dest) <= (beh.arriveDistance or 8.0) then
                        PedDir.behaviors[ped] = nil
                        TaskStandStill(ped, 1500)
                        Notify('Ped reached waypoint')
                    elseif now - (beh.lastTask or 0) > 4500 then
                        IssueBehaviorTask(ped, beh)
                    end
                end
            elseif beh.mode == 'wander' then
                if now - (beh.lastTask or 0) > 10000 then
                    IssueBehaviorTask(ped, beh)
                end
            end
        end
    end
end)

-- Gizmo thread
CreateThread(function()
    while ALIVE do
        local g = PedDir.gizmo
        if not g.active then
            Wait(500)
        elseif not g.ped or not DoesEntityExist(g.ped) then
            g.active = false
            g.ped = nil
            Wait(100)
        else
            Wait(0) -- needs per-frame for key checks + drawing
            local coords = GetEntityCoords(g.ped)
            DrawText3D(coords.x, coords.y, coords.z + 1.2, 'Gizmo: ' .. g.mode)
            DrawText3D(coords.x, coords.y, coords.z + 1.1, '[WASD] Move [QE] Height [TAB] Mode [ENTER] Done')

            local speed = IsDisabledControlPressed(0, 21) and 0.01 or 0.05
            if g.mode == 'ROTATE' then speed = speed * 20.0 end

            if g.mode == 'MOVE' then
                if IsDisabledControlPressed(0, 32) then PedDir.AdjustOffset(g.ped, 0, speed, 0, 0, false) end
                if IsDisabledControlPressed(0, 33) then PedDir.AdjustOffset(g.ped, 0, -speed, 0, 0, false) end
                if IsDisabledControlPressed(0, 34) then PedDir.AdjustOffset(g.ped, -speed, 0, 0, 0, false) end
                if IsDisabledControlPressed(0, 30) then PedDir.AdjustOffset(g.ped, speed, 0, 0, 0, false) end
                if IsDisabledControlPressed(0, 44) then PedDir.AdjustOffset(g.ped, 0, 0, speed, 0, false) end
                if IsDisabledControlPressed(0, 38) then PedDir.AdjustOffset(g.ped, 0, 0, -speed, 0, false) end
                DrawMarker(28, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, 0, 255, 0, 100, false, false, 2, nil, nil, false)
            elseif g.mode == 'ROTATE' then
                if IsDisabledControlPressed(0, 34) or IsDisabledControlPressed(0, 44) then
                    PedDir.AdjustOffset(g.ped, 0, 0, 0, speed, false)
                end
                if IsDisabledControlPressed(0, 30) or IsDisabledControlPressed(0, 38) then
                    PedDir.AdjustOffset(g.ped, 0, 0, 0, -speed, false)
                end
                local h = GetEntityHeading(g.ped)
                local r = math.rad(h)
                local fx, fy = -math.sin(r) * 2.0, math.cos(r) * 2.0
                DrawLine(coords.x, coords.y, coords.z, coords.x + fx, coords.y + fy, coords.z, 255, 0, 0, 255)
            end

            if IsDisabledControlJustPressed(0, 37) then
                g.mode = g.mode == 'MOVE' and 'ROTATE' or 'MOVE'
            end
            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 18) then
                g.active = false
                g.ped = nil
                Notify('Gizmo closed')
            end
        end
    end
end)

-- Possess controls thread
CreateThread(function()
    while ALIVE do
        local pos = PedDir.possess
        if not pos.active then
            Wait(500)
        elseif not pos.ped or not DoesEntityExist(pos.ped) then
            pos.active = false
            Wait(100)
        else
            Wait(50)
            if IsDisabledControlPressed(0, 32) then PedDir.AdjustOffset(pos.ped, 0, 0.1, 0, 0, false) end
            if IsDisabledControlPressed(0, 33) then PedDir.AdjustOffset(pos.ped, 0, -0.1, 0, 0, false) end
            if IsDisabledControlPressed(0, 34) then PedDir.AdjustOffset(pos.ped, -0.1, 0, 0, 0, false) end
            if IsDisabledControlPressed(0, 30) then PedDir.AdjustOffset(pos.ped, 0.1, 0, 0, 0, false) end
            if IsDisabledControlJustPressed(0, 191) then PedDir.StopPossess() end
        end
    end
end)

-- =============================================
-- COMMANDS
-- =============================================

RegisterCommand('spawnped', function(_, args)
    PedDir.SpawnPed(args[1])
end)

RegisterCommand('deleteped', function()
    local ped, _, idx = GetClosest(5.0)
    if ped then
        PedDir.DeletePed(ped, idx)
        Notify('Deleted (' .. #PedDir.peds .. ' remaining)')
    else
        Notify('No ped nearby')
    end
end)

RegisterCommand('clearallpeds', function()
    local n = #PedDir.peds
    PedDir.DeleteAll()
    Notify('Deleted ' .. n .. ' peds')
end)

RegisterCommand('pedemote', function(_, args)
    if #args < 1 then Notify('Usage: /pedemote [name]') return end
    local ped = GetClosest(10.0)
    if ped then PedDir.PlayEmote(ped, args[1]) else Notify('No ped nearby') end
end)

RegisterCommand('pedanim', function(_, args)
    if #args < 2 then Notify('Usage: /pedanim [dict] [anim]') return end
    local ped = GetClosest(10.0)
    if not ped then Notify('No ped nearby') return end
    if not LoadAnimDict(args[1]) then Notify('Failed to load dict: ' .. args[1]) return end
    TaskPlayAnim(ped, args[1], args[2], 8.0, -8.0, -1, 1, 0, false, false, false)
    Notify('Anim: ' .. args[1] .. ' ' .. args[2])
end)

RegisterCommand('pedscenario', function(_, args)
    if #args < 1 then Notify('Usage: /pedscenario [name]') return end
    local ped = GetClosest(10.0)
    if ped then
        TaskStartScenarioInPlace(ped, string.upper(args[1]), 0, true)
        Notify('Scenario: ' .. args[1])
    else
        Notify('No ped nearby')
    end
end)

RegisterCommand('moveped', function()
    local ped = GetClosest(50.0)
    if not ped then Notify('No ped nearby') return end
    local c = GetEntityCoords(PlayerPedId())
    SetEntityCoords(ped, c.x + 1.0, c.y, c.z - 1.0, false, false, false, true)
    SetEntityHeading(ped, GetEntityHeading(PlayerPedId()))
    Notify('Moved')
end)

RegisterCommand('freezeped', function()
    local ped = GetClosest(5.0)
    if not ped then Notify('No ped nearby') return end
    local frozen = IsEntityPositionFrozen(ped)
    FreezeEntityPosition(ped, not frozen)
    Notify(frozen and 'Unfrozen' or 'Frozen')
end)

RegisterCommand('stopanimp', function()
    local ped = GetClosest(10.0)
    if not ped then Notify('No ped nearby') return end
    PedDir.ClearProps(ped)
    ClearPedTasks(ped)
    Notify('Stopped')
end)

RegisterCommand('pedvehicle', function(_, args)
    local ped = GetClosest(12.0)
    if not ped then Notify('No ped nearby') return end
    local v = PedDir.EnsureVehicle(ped, args[1])
    if v then Notify('Vehicle spawned') end
end)

RegisterCommand('pedrouteadd', function()
    local c = GetEntityCoords(PlayerPedId())
    local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 50.0, false)
    PedDir.patrolNodes[#PedDir.patrolNodes + 1] = { x = c.x, y = c.y, z = found and z or c.z }
    Notify('Node #' .. #PedDir.patrolNodes)
end)

RegisterCommand('pedrouteclear', function()
    PedDir.patrolNodes = {}
    Notify('Route cleared')
end)

RegisterCommand('pedrouteinfo', function()
    Notify('Nodes: ' .. #PedDir.patrolNodes)
end)

RegisterCommand('peddrive', function(_, args)
    local mode = string.lower(args[1] or '')
    if mode == '' then Notify('Usage: /peddrive [wander|towp|patrol|stop] [speed]') return end
    local ped = GetClosest(12.0)
    if not ped then Notify('No ped nearby') return end

    if mode == 'stop' then
        PedDir.behaviors[ped] = nil
        ClearPedTasks(ped)
        Notify('Stopped')
        return
    end

    local speed = tonumber(args[2]) or 18.0
    local beh = { mode = mode, speed = speed, drivingStyle = 786603, lastTask = 0, arriveDistance = 10.0 }

    if mode == 'patrol' then
        if #PedDir.patrolNodes < 2 then Notify('Need 2+ patrol nodes') return end
        beh.route = PedDir.patrolNodes
        beh.routeIndex = 1
        beh.arriveDistance = 12.0
    elseif mode == 'towp' then
        if not IsWaypointActive() then Notify('Set a waypoint first') return end
        beh.arriveDistance = 8.0
    elseif mode ~= 'wander' then
        Notify('Unknown mode')
        return
    end

    PedDir.behaviors[ped] = beh
    IssueBehaviorTask(ped, beh)
    Notify('Drive: ' .. mode)
end)

RegisterCommand('pedfaction', function(_, args)
    local f = string.lower(args[1] or '')
    if f == '' then Notify('Usage: /pedfaction [civilian|police|gang|guard]') return end
    local ped = GetClosest(12.0)
    if ped then PedDir.SetFaction(ped, f) else Notify('No ped nearby') end
end)

RegisterCommand('pedcombat', function(_, args)
    local mode = string.lower(args[1] or '')
    if mode == '' then Notify('Usage: /pedcombat [player|nearest|faction|stop]') return end
    local ped = GetClosest(12.0)
    if ped then PedDir.StartCombat(ped, mode, args[2]) else Notify('No ped nearby') end
end)

RegisterCommand('savepedpreset', function(_, args)
    if not args[1] or args[1] == '' then Notify('Usage: /savepedpreset [name]') return end
    local ped = GetClosest(10.0)
    if ped then PedDir.SavePreset(ped, args[1]) else Notify('No ped nearby') end
end)

RegisterCommand('loadpedpreset', function(_, args)
    if not args[1] then
        local names = PedDir.GetPresetNames()
        if #names == 0 then Notify('No presets') return end
        for i, n in ipairs(names) do Notify(i .. '. ' .. n) end
        return
    end
    local idx = tonumber(args[1])
    if idx then
        local names = PedDir.GetPresetNames()
        if names[idx] then PedDir.LoadPreset(names[idx]) else Notify('Invalid #') end
    else
        PedDir.LoadPreset(args[1])
    end
end)

RegisterCommand('listpedpresets', function()
    local names = PedDir.GetPresetNames()
    if #names == 0 then Notify('No presets') return end
    for i, n in ipairs(names) do Notify(i .. '. ' .. n) end
end)

RegisterCommand('scenemode', function() PedDir.ToggleSceneMode() end)

RegisterCommand('assignslot', function(_, args)
    local slot = tonumber(args[1])
    if not slot then Notify('Usage: /assignslot [1-9]') return end
    local ped = GetClosest(10.0)
    if ped then PedDir.AssignSlot(slot, ped) else Notify('No ped nearby') end
end)

RegisterCommand('swapslot', function(_, args)
    local slot = tonumber(args[1])
    if not slot then Notify('Usage: /swapslot [1-9]') return end
    local ped = PedDir.slots[slot]
    if ped and DoesEntityExist(ped) then PedDir.StartPossess(ped) else Notify('Empty slot') end
end)

RegisterCommand('possess', function()
    local ped = GetClosest(10.0)
    if ped then PedDir.StartPossess(ped) else Notify('No ped nearby') end
end)

RegisterCommand('cloneped', function()
    local ped = GetClosest(10.0)
    if ped then PedDir.ClonePed(ped) else Notify('No ped nearby') end
end)

RegisterCommand('waypointall', function()
    if not IsWaypointActive() then Notify('No waypoint set') return end
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then
            PedDir.behaviors[ped] = { mode = 'towp', speed = 18.0, drivingStyle = 786603, lastTask = GetGameTimer(), arriveDistance = 8.0 }
            if PedDir.sceneMode == 'active' then IssueBehaviorTask(ped, PedDir.behaviors[ped]) end
        end
    end
    Notify('Waypoint set for all')
end)

RegisterCommand('teleportall', function()
    if not IsWaypointActive() then Notify('No waypoint set') return end
    local dest = GetWaypointGround()
    if not dest then return end
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then
            SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, true)
        end
    end
    Notify('Teleported all')
end)

RegisterCommand('emoteall', function(_, args)
    if #args < 1 then Notify('Usage: /emoteall [emote]') return end
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then PedDir.PlayEmote(ped, args[1]) end
    end
    Notify('Emote applied to all')
end)

RegisterCommand('stopall', function()
    for _, ped in ipairs(PedDir.peds) do
        if DoesEntityExist(ped) then
            PedDir.ClearProps(ped)
            ClearPedTasks(ped)
        end
    end
    Notify('All stopped')
end)

RegisterCommand('scenereset', function() PedDir.SceneReset() end)

RegisterCommand('pedchase', function()
    if PedDir.chasing then PedDir.StopFormations() else PedDir.StartChase() end
end)

RegisterCommand('pedescort', function()
    if PedDir.escorting then PedDir.StopFormations() else PedDir.StartEscort() end
end)

RegisterCommand('listemotes', function()
    local count = CountEmotes and CountEmotes() or 0
    Notify('Total emotes: ' .. count)
    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255}, multiline = true,
        args = {'Emotes', 'dance, smoke, sit, lean, guard, phone, cop, wave, salute, clap, crossarms, pushup, yoga, dab, thumbsup, peace'}
    })
end)

RegisterCommand('peddirector', function()
    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255}, multiline = true,
        args = {'Ped Director v2.0', [[
/spawnped /deleteped /clearallpeds /pedemote /pedanim /pedscenario
/moveped /freezeped /stopanimp /cloneped /possess
/pedvehicle /peddrive /pedrouteadd /pedrouteclear
/pedfaction /pedcombat /savepedpreset /loadpedpreset
/scenemode /assignslot /swapslot /waypointall /teleportall
/emoteall /stopall /scenereset /pedchase /pedescort
/pedmenu (F6) - Full GUI Menu]]}
    })
end)

-- =============================================
-- LIFECYCLE
-- =============================================

CreateThread(function()
    PedDir.RefreshPresets()
end)

AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ALIVE = false
end)
