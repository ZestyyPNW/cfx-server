-- Sheriff NPC Client Script
-- Creates Sheriff NPC and handles ox_target interactions

local spawnedNPCs = {}

-- Function to create Sheriff NPC
local function createSheriffNPC()
    for _, npcConfig in ipairs(SheriffNPC) do
        -- Load ped model
        local modelHash = GetHashKey(npcConfig.model)
        RequestModel(modelHash)
        
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if HasModelLoaded(modelHash) then
            -- Create NPC
            local ped = CreatePed(4, modelHash, npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z - 1.0, npcConfig.coords.w, false, true)
            
            if DoesEntityExist(ped) then
                -- Set ped properties
                SetEntityAsMissionEntity(ped, true, true)
                SetPedFleeAttributes(ped, 0, 0)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedRelationshipGroupHash(ped, GetHashKey("COP"))
                
                -- Make ped immovable
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetPedDiesWhenInjured(ped, false)
                SetPedCanRagdoll(ped, false)
                
                -- Give sheriff equipment
                if config.GiveSheriffEquipment then
                    GiveWeaponToPed(ped, GetHashKey("WEAPON_COMBATPISTOL"), 100, false, true)
                    SetPedCurrentWeaponVisible(ped, true, false, false, false)
                end
                
                -- Set animation if configured
                if npcConfig.animation then
                    RequestAnimDict(npcConfig.animation.dict)
                    while not HasAnimDictLoaded(npcConfig.animation.dict) do
                        Wait(100)
                    end
                    TaskPlayAnim(ped, npcConfig.animation.dict, npcConfig.animation.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
                end
                
                -- Create ox_target interaction with list of vehicles
                local options = {}
                for _, vehicle in ipairs(PatrolVehicles) do
                    table.insert(options, {
                        name = 'spawn_' .. vehicle.model,
                        icon = 'fas fa-car',
                        label = 'Request ' .. vehicle.label,
                        distance = 2.0,
                        onSelect = function()
                            TriggerServerEvent('tcp_core:sheriff:spawnVehicle', vehicle.model)
                        end
                    })
                end
                
                exports.ox_target:addLocalEntity(ped, options)
                
                -- Store NPC reference for cleanup
                table.insert(spawnedNPCs, ped)
                
                print(('[tcp_core] Created Sheriff NPC at %.2f, %.2f, %.2f'):format(
                    npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z
                ))
                
                -- Debug: Check if ox_target is available
                if GetResourceState('ox_target') == 'started' then
                    print('[tcp_core] ox_target is running, added interaction to Sheriff NPC')
                else
                    print('[tcp_core] WARNING: ox_target is not running!')
                end
            else
                print(('[tcp_core] Failed to create Sheriff NPC'))
            end
        else
            print(('[tcp_core] Failed to load Sheriff NPC model: %s'):format(npcConfig.model))
        end
        
        SetModelAsNoLongerNeeded(modelHash)
    end
end

-- Initialize NPCs when resource starts
CreateThread(function()
    Wait(2000) -- Wait for everything to load
    createSheriffNPC()
    
    -- Debug command to test NPC interaction
    RegisterCommand('test_sheriff_npc', function()
        if #spawnedNPCs > 0 then
            local ped = spawnedNPCs[1]
            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                print(('Sheriff NPC exists at: %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z))
                print('Try walking closer (within 2m) and pressing E')
            else
                print('Sheriff NPC does not exist!')
            end
        else
            print('No Sheriff NPCs spawned!')
        end
    end, false)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, ped in ipairs(spawnedNPCs) do
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
        spawnedNPCs = {}
    end
end)

-- Handle vehicle spawn
RegisterNetEvent('tcp_core:vehicleSpawned', function(netId, vehicleData)
    local timeout = 0
    local vehicle = nil

    while timeout < 50 do
        vehicle = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(vehicle) then
            break
        end
        Wait(100)
        timeout = timeout + 1
    end

    if DoesEntityExist(vehicle) then
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleEngineOn(vehicle, false, true, false)

        if vehicleData.livery then
            SetVehicleLivery(vehicle, vehicleData.livery)
        end

        local plate = GetVehicleNumberPlateText(vehicle)
        TriggerServerEvent('ND_Vehicles:giveKeys', plate)

        local ped = PlayerPedId()
        SetPedIntoVehicle(ped, vehicle, -1)
    end
end)

-- Register context menu for vehicle selection
CreateThread(function()
    if lib and lib.registerContext then
        lib.registerContext({
            id = 'sheriff_vehicle_menu',
            title = 'Select Patrol Vehicle',
            options = {} -- Options will be populated dynamically
        })
    end
end)