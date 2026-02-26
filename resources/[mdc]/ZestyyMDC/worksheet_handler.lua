-- Worksheet Handler for RID Generation and Mileage Tracking
-- Handles RID generation (50000-59999) and mileage tracking when worksheets are submitted

local playerVehicles = {} -- Track player-spawned vehicles: [playerId] = {vehicle = entity, model = string, mileage = number, startMileage = number}
local worksheetVehicles = {} -- Track which vehicle was used for worksheet submission: [playerId] = vehicle entity

local DEPUTY_RID_MIN = 50000
local DEPUTY_RID_MAX = 59999

local function normalizeDeputyRID(value)
    local rid = tonumber(value)
    if not rid then return nil end
    if rid < DEPUTY_RID_MIN or rid > DEPUTY_RID_MAX then return nil end
    return math.floor(rid)
end

-- Deterministic deputy RID from character id (never random)
local function generateRID(characterId)
    local raw = tostring(characterId or "")
    local digits = raw:gsub("%D", "")
    local offset = 0

    if digits ~= "" then
        offset = (tonumber(digits) or 0) % 10000
    else
        -- Fallback deterministic hash for non-numeric ids
        local hash = 0
        for i = 1, #raw do
            hash = (hash * 31 + string.byte(raw, i)) % 10000
        end
        offset = hash
    end

    return DEPUTY_RID_MIN + offset
end

-- Ensure a player has an RID in metadata; generate and persist if missing
local function ensurePlayerRID(src, player)
    if not player then
        return nil, false
    end

    local existing = nil
    if player.metadata and player.metadata.rid then
        existing = normalizeDeputyRID(player.metadata.rid)
    end

    if existing then
        return existing, false
    end

    local rid = generateRID(player.id)

    if player.metadata then
        player.metadata.rid = rid
    else
        player.metadata = { rid = rid }
    end

    if player.id then
        exports.oxmysql:update('UPDATE nd_characters SET metadata = ? WHERE charid = ?', {
            json.encode(player.metadata),
            player.id
        })
    end

    if src then
        Citizen.SetTimeout(250, function()
            TriggerClientEvent('whackerlink:setRID', src, tostring(rid))
        end)
    end

    return rid, true
end

-- Check if vehicle is in allowed vehicles list
local function isAllowedVehicle(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    
    local model = GetEntityModel(vehicle)
    local modelHash = tostring(model)
    
    if Config and Config.AllowedVehicles then
        -- Check if model hash exists in allowed vehicles
        for vehicleName, allowed in pairs(Config.AllowedVehicles) do
            if allowed and GetHashKey(vehicleName) == model then
                return true
            end
        end
    end
    
    return false
end

-- Get vehicle mileage (odometer reading)
local function getVehicleMileage(vehicle)
    if not DoesEntityExist(vehicle) then
        return 0
    end
    
    -- Use entity state bags instead of decorators
    local state = Entity(vehicle).state
    return state.vehicle_mileage or 0
end

-- Set vehicle mileage
local function setVehicleMileage(vehicle, mileage)
    if DoesEntityExist(vehicle) then
        local state = Entity(vehicle).state
        state.vehicle_mileage = math.floor(mileage)
    end
end

-- Track when players enter vehicles
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        
        local players = GetPlayers() or GetActivePlayers()
        for _, playerId in ipairs(players) do
            local src = tonumber(playerId)
            local ped = GetPlayerPed(src)
            
            if ped and ped ~= 0 then
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                    -- Player is driver
                    if isAllowedVehicle(vehicle) then
                        -- Check if this is a new vehicle for this player
                        if not playerVehicles[src] or playerVehicles[src].vehicle ~= vehicle then
                            local model = GetEntityModel(vehicle)
                            local modelHash = tostring(model)
                            local currentMileage = getVehicleMileage(vehicle)
                            
                            playerVehicles[src] = {
                                vehicle = vehicle,
                                model = modelHash,
                                mileage = currentMileage,
                                startMileage = currentMileage,
                                lastPos = GetEntityCoords(vehicle)
                            }
                        end
                    end
                elseif vehicle == 0 and playerVehicles[src] then
                    -- Player exited vehicle, but keep tracking in case they get back in
                    -- Only clear if vehicle is deleted
                    if not DoesEntityExist(playerVehicles[src].vehicle) then
                        playerVehicles[src] = nil
                    end
                end
            end
        end
    end
end)

-- Track mileage while driving
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100) -- Update every 100ms for more accurate tracking
        
        for playerId, vehicleData in pairs(playerVehicles) do
            if DoesEntityExist(vehicleData.vehicle) then
                local ped = GetPlayerPed(playerId)
                if ped and ped ~= 0 then
                    local currentVehicle = GetVehiclePedIsIn(ped, false)
                    
                    -- Only track if player is still in their tracked vehicle and is the driver
                    if currentVehicle == vehicleData.vehicle and GetPedInVehicleSeat(vehicleData.vehicle, -1) == ped then
                        -- Calculate distance traveled using entity position changes
                        local currentPos = GetEntityCoords(vehicleData.vehicle)
                        if vehicleData.lastPos then
                            local distance = #(currentPos - vehicleData.lastPos)
                            -- Convert game units to miles (1 game unit ≈ 0.000621371 miles)
                            -- More accurate: 1 meter = 0.000621371 miles, GTA units are roughly meters
                            local miles = distance * 0.000621371
                            vehicleData.mileage = vehicleData.mileage + miles
                            setVehicleMileage(vehicleData.vehicle, math.floor(vehicleData.mileage))
                        end
                        vehicleData.lastPos = currentPos
                    elseif currentVehicle ~= vehicleData.vehicle then
                        -- Player left the vehicle, stop tracking
                        playerVehicles[playerId] = nil
                    end
                end
            else
                -- Vehicle no longer exists
                playerVehicles[playerId] = nil
            end
        end
    end
end)

-- Handle worksheet submission
RegisterNetEvent("SimpleHUD:mdcWorksheetSubmitted")
AddEventHandler("SimpleHUD:mdcWorksheetSubmitted", function()
    local src = source
    
    -- Get player's character data
    if GetResourceState('ND_Core') ~= 'started' then
        return
    end
    
    local ok, player = pcall(function()
        return exports['ND_Core']:getPlayer(src)
    end)
    
    if not ok or not player then
        return
    end
    
    local characterId = player.id
    local rid = ensurePlayerRID(src, player)
    
    -- Get mileage from current vehicle if player is in one
    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local begMileage = 0
    
    if vehicle ~= 0 and playerVehicles[src] and playerVehicles[src].vehicle == vehicle then
        -- Player is in their tracked vehicle
        begMileage = math.floor(playerVehicles[src].startMileage)
        worksheetVehicles[src] = vehicle
        
        -- Update worksheet with BEG mileage via API
        -- This will be handled by the MDC backend when it receives the worksheet data
    end
    
    -- Store worksheet vehicle and mileage for later retrieval
    if vehicle ~= 0 then
        worksheetVehicles[src] = {
            vehicle = vehicle,
            begMileage = begMileage,
            rid = rid
        }
    end
    
    -- Send mileage data to client so it can be included in worksheet
    TriggerClientEvent('zestyymdc:worksheetMileageData', src, {
        rid = rid,
        begMileage = begMileage
    })
    
    print(string.format("^2[ZestyyMDC]^7 Player %s (CharID: %s) submitted worksheet. RID: %s, BEG Mileage: %s^0", 
        GetPlayerName(src), characterId, rid or "N/A", begMileage))
end)

-- Export function to get RID for a player
exports('getPlayerRID', function(playerId)
    if GetResourceState('ND_Core') ~= 'started' then
        return nil
    end
    
    local ok, player = pcall(function()
        return exports['ND_Core']:getPlayer(playerId)
    end)
    
    if ok and player then
        local rid = ensurePlayerRID(tonumber(playerId), player)
        return rid
    end
    
    return nil
end)

-- Export function to get current mileage for player's vehicle
exports('getPlayerVehicleMileage', function(playerId)
    if playerVehicles[playerId] then
        return math.floor(playerVehicles[playerId].mileage)
    end
    return 0
end)

-- Export function to get BEG mileage from worksheet vehicle
exports('getWorksheetBEGMileage', function(playerId)
    if worksheetVehicles[playerId] then
        return worksheetVehicles[playerId].begMileage
    end
    return 0
end)

-- Handle request for current mileage
RegisterNetEvent("zestyymdc:getCurrentMileage")
AddEventHandler("zestyymdc:getCurrentMileage", function()
    local src = source
    local mileage = 0
    
    if playerVehicles[src] then
        mileage = math.floor(playerVehicles[src].startMileage)
    end
    
    TriggerClientEvent("zestyymdc:currentMileage", src, mileage)
end)

-- Handle request for player RID
RegisterNetEvent("zestyymdc:requestPlayerRID")
AddEventHandler("zestyymdc:requestPlayerRID", function()
    local src = source
    
    -- Get player's character data
    if GetResourceState('ND_Core') ~= 'started' then
        TriggerClientEvent("zestyymdc:playerRID", src, nil)
        return
    end
    
    local ok, player = pcall(function()
        return exports['ND_Core']:getPlayer(src)
    end)
    
    if not ok or not player then
        TriggerClientEvent("zestyymdc:playerRID", src, nil)
        return
    end
    
    local rid = ensurePlayerRID(src, player)
    
    TriggerClientEvent("zestyymdc:playerRID", src, rid)
end)
