-- Sheriff NPC Server Script
-- Handles vehicle spawning for authorized players

local NDCore = exports['ND_Core']

-- Function to check if player is authorized
local function isPlayerAuthorized(source)
    return true -- Allow anyone
end

-- Function to find a valid spawn location
local function findValidSpawnLocation()
    -- Use first location for now
    return VehicleSpawnLocations[1]
end

-- Function to spawn vehicle for player
local function spawnVehicleForPlayer(source, vehicleData)
    print('[tcp_core] Spawning ' .. vehicleData.model .. ' for ' .. GetPlayerName(source))
    if not isPlayerAuthorized(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'You are not authorized to use this service.'
        })
        return
    end
    
    local spawnLocation = findValidSpawnLocation()
    if not spawnLocation then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error', 
            description = 'No valid spawn location available.'
        })
        return
    end
    
    -- Create vehicle using server-side native
    local modelHash = GetHashKey(vehicleData.model)
    local spawnCoords = spawnLocation.coords
    local vehicle = CreateVehicleServerSetter(modelHash, 'automobile', spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w)

    if DoesEntityExist(vehicle) then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)

        -- Get ND vehicle object
        local ndVehicle = NDCore.getVehicle(vehicle)
        if ndVehicle then
            ndVehicle.setOwner(source)
        end

        -- Trigger client to set properties and put player in
        TriggerClientEvent('tcp_core:vehicleSpawned', source, netId, vehicleData)

        -- Notify player
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = ('Spawned %s'):format(vehicleData.label)
        })

        print(('[tcp_core] %s spawned %s'):format(GetPlayerName(source), vehicleData.label))
    else
        print('[tcp_core] Failed to create vehicle ' .. vehicleData.model)
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Failed to spawn vehicle. Model not found.'
        })
    end
end

-- Event handler for vehicle spawn requests
RegisterServerEvent('tcp_core:sheriff:spawnVehicle', function(vehicleModel)
    local source = source
    print('[tcp_core] Sheriff spawn request from ' .. GetPlayerName(source) .. ' for ' .. vehicleModel)
    
    -- Find vehicle data by model
    local vehicleData = nil
    for _, vehicle in ipairs(PatrolVehicles) do
        if vehicle.model == vehicleModel then
            vehicleData = vehicle
            break
        end
    end
    
    if vehicleData then
        spawnVehicleForPlayer(source, vehicleData)
    else
        print('[tcp_core] Invalid vehicle model: ' .. vehicleModel)
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Invalid vehicle model.'
        })
    end
end)

-- Debug command to test authorization
RegisterCommand('test_sheriff_auth', function(source)
    local authorized = isPlayerAuthorized(source)
    TriggerClientEvent('ox_lib:notify', source, {
        type = authorized and 'success' or 'error',
        description = authorized and 'Authorized' or 'Not authorized'
    })
end, false)