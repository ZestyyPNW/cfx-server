local function ensureControl(entity, timeoutMs)
    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + (timeoutMs or 2000)

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function isBroken(entity)
    local engineHealth = GetVehicleEngineHealth(entity)
    return engineHealth <= 0.0 or engineHealth < Config.minEngineHealth
end

local function setRepairDoors(entity, open)
    if type(Config.openDoors) ~= 'table' then return end

    for i = 1, #Config.openDoors do
        local door = Config.openDoors[i]
        if open then
            SetVehicleDoorOpen(entity, door, false, false)
        else
            SetVehicleDoorShut(entity, door, false)
        end
    end
end

local function getRepairAnim()
    if Config.repairAnim and Config.repairAnim.dict and Config.repairAnim.clip then
        return { dict = Config.repairAnim.dict, clip = Config.repairAnim.clip }
    end

    if Config.repairScenario then
        return { scenario = Config.repairScenario }
    end
end

local function moveToRepairSpot(entity)
    local offset = Config.repairOffset or { x = 0.0, y = 2.5, z = 0.0 }
    local target = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    local ped = cache.ped
    local timeout = GetGameTimer() + (Config.approachTimeout or 3000)
    local heading = GetEntityHeading(entity) + 180.0

    TaskGoStraightToCoord(ped, target.x, target.y, target.z, 1.0, Config.approachTimeout or 3000, heading, 0.5)

    while GetGameTimer() < timeout do
        if not DoesEntityExist(entity) then
            ClearPedTasks(ped)
            return false
        end
        local coords = GetEntityCoords(ped)
        if #(coords - target) <= (Config.approachDistance or 1.0) then
            ClearPedTasks(ped)
            return true
        end
        Wait(50)
    end

    ClearPedTasks(ped)
    return false
end

local function repairVehicle(data)
    local entity = data.entity
    if not DoesEntityExist(entity) then return end
    if cache.vehicle then return end
    if not isBroken(entity) then
        lib.notify({ type = 'info', description = 'Vehicle does not need repairs.' })
        return
    end

    if not ensureControl(entity) then
        lib.notify({ type = 'error', description = 'Cannot access vehicle right now.' })
        return
    end

    if not moveToRepairSpot(entity) then
        lib.notify({ type = 'error', description = 'Move closer to the vehicle.' })
        return
    end

    TaskTurnPedToFaceEntity(cache.ped, entity, 1000)
    Wait(250)
    setRepairDoors(entity, true)

    local success = lib.progressCircle({
        duration = Config.repairDuration,
        label = Config.progressLabel,
        position = Config.progressPosition,
        useWhileDead = false,
        allowRagdoll = false,
        allowCuffed = false,
        allowFalling = false,
        canCancel = true,
        anim = getRepairAnim(),
        disable = {
            move = true,
            car = true,
            combat = true
        },
        prop = Config.prop
    })

    ClearPedTasks(cache.ped)

    if not success then
        setRepairDoors(entity, false)
        return
    end

    if not ensureControl(entity) then
        lib.notify({ type = 'error', description = 'Lost access to vehicle.' })
        setRepairDoors(entity, false)
        return
    end

    SetVehicleFixed(entity)
    SetVehicleDeformationFixed(entity)
    SetVehicleEngineHealth(entity, Config.fullEngineHealth)
    SetVehicleBodyHealth(entity, Config.fullBodyHealth)
    SetVehiclePetrolTankHealth(entity, Config.fullPetrolHealth)
    SetVehicleDirtLevel(entity, 0.0)
    SetVehicleUndriveable(entity, false)
    setRepairDoors(entity, false)

    lib.notify({ type = 'success', description = Config.successMessage })
end

local function toggleDoor(entity, door)
    if GetVehicleDoorAngleRatio(entity, door) > 0.0 then
        SetVehicleDoorShut(entity, door, false)
    else
        SetVehicleDoorOpen(entity, door, false, false)
    end
end

local function canUseVehicleTarget(entity)
    if not DoesEntityExist(entity) then return false end
    if cache.vehicle then return false end
    if IsEntityDead(cache.ped) then return false end
    return true
end

local function toggleHoodOrRepair(entity)
    if isBroken(entity) then
        repairVehicle({ entity = entity })
        return
    end

    toggleDoor(entity, 4)
end

local highlightBones = {
    'door_dside_f',
    'door_pside_f',
    'door_dside_r',
    'door_pside_r',
    'bonnet',
    'boot'
}

local function getClosestHighlightBone(entity, hitCoords)
    local closestBone
    local closestDist

    for i = 1, #highlightBones do
        local boneName = highlightBones[i]
        local boneId = GetEntityBoneIndexByName(entity, boneName)

        if boneId ~= -1 then
            local boneCoords = GetEntityBonePosition_2(entity, boneId)
            local dist = #(hitCoords - boneCoords)

            if dist <= 1.2 and (not closestDist or dist < closestDist) then
                closestBone = boneCoords
                closestDist = dist
            end
        end
    end

    return closestBone
end

CreateThread(function()
    while true do
        if not exports.ox_target:isActive() then
            Wait(200)
        else
            local hit, entityHit, endCoords = lib.raycast.fromCamera(511, 4, 7)

            if hit and entityHit and GetEntityType(entityHit) == 2 then
                local pedCoords = GetEntityCoords(cache.ped)

                if #(pedCoords - endCoords) <= (Config.distance or 2.0) then
                    local boneCoords = getClosestHighlightBone(entityHit, endCoords)

                    if boneCoords then
                        DrawMarker(2, boneCoords.x, boneCoords.y, boneCoords.z + 0.05, 0.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.12, 0.12, 0.12, 0, 200, 80, 200, false, false, 2, true, nil, nil, false)
                    end
                end
            end

            Wait(0)
        end
    end
end)

exports.ox_target:addGlobalVehicle({
    {
        name = 'z_vehicle_door_driver',
        icon = 'fa-solid fa-door-open',
        label = 'Door',
        bones = { 'door_dside_f' },
        distance = Config.distance or 2.0,
        canInteract = function(entity)
            return canUseVehicleTarget(entity) and GetIsDoorValid(entity, 0)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, 0)
        end
    },
    {
        name = 'z_vehicle_door_passenger',
        icon = 'fa-solid fa-door-open',
        label = 'Door',
        bones = { 'door_pside_f' },
        distance = Config.distance or 2.0,
        canInteract = function(entity)
            return canUseVehicleTarget(entity) and GetIsDoorValid(entity, 1)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, 1)
        end
    },
    {
        name = 'z_vehicle_door_driver_rear',
        icon = 'fa-solid fa-door-open',
        label = 'Door',
        bones = { 'door_dside_r' },
        distance = Config.distance or 2.0,
        canInteract = function(entity)
            return canUseVehicleTarget(entity) and GetIsDoorValid(entity, 2)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, 2)
        end
    },
    {
        name = 'z_vehicle_door_passenger_rear',
        icon = 'fa-solid fa-door-open',
        label = 'Door',
        bones = { 'door_pside_r' },
        distance = Config.distance or 2.0,
        canInteract = function(entity)
            return canUseVehicleTarget(entity) and GetIsDoorValid(entity, 3)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, 3)
        end
    },
    {
        name = 'z_vehicle_hood',
        icon = 'fa-solid fa-car',
        label = 'Hood',
        bones = { 'bonnet' },
        distance = Config.distance or 2.0,
        canInteract = function(entity)
            return canUseVehicleTarget(entity) and GetIsDoorValid(entity, 4)
        end,
        onSelect = function(data)
            toggleHoodOrRepair(data.entity)
        end
    },
    {
        name = 'z_vehicle_trunk',
        icon = 'fa-solid fa-car-rear',
        label = 'Trunk',
        bones = { 'boot' },
        distance = Config.distance or 2.0,
        canInteract = function(entity)
            return canUseVehicleTarget(entity) and GetIsDoorValid(entity, 5)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, 5)
        end
    }
})
