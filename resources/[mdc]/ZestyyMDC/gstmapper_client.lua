local blips = {}
local lastmodel

local function IsEmergencyVehicle(veh)
    if not DoesEntityExist(veh) then
        return false
    end
    -- If on duty, we can see blips
    if LocalPlayer.state.onduty ~= true then
        return false
    end
    local model = GetEntityModel(veh)
    if Config and Config.AllowedVehicles and Config.AllowedVehicles[model] then
        return true
    end
    -- Fallback to vehicle class 18 (Emergency)
    return GetVehicleClass(veh) == 18
end

local function GetPlayerBlipName(playerSrc)
    local player = Player(playerSrc)
    if not player or not player.state then 
        return "Unknown" 
    end
    
    local unit = player.state.unitid or ""
    
    -- Attempt to get names from state bags
    local first = player.state.firstname or player.state.firstName or ""
    local last = player.state.lastname or player.state.lastName or ""
    
    local name = "Unknown"
    if first ~= "" and last ~= "" then
        name = first .. " " .. last
    elseif first ~= "" then
        name = first
    end

    if unit ~= "" then
        return "[" .. unit .. "] " .. name
    end
    
    return name
end

local function RemoveAllEmergencyBlips()
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blips = {}
end

RegisterNetEvent("c_cargps")
AddEventHandler("c_cargps", function(model, x, y, z, playerSrc, siren)
    -- DEBUG: print("Received GPS for: " .. tostring(playerSrc) .. " | Coords: " .. tostring(x) .. ", " .. tostring(y))
    
    -- Only show blips if the LOCAL player is on duty
    if LocalPlayer.state.onduty ~= true then 
        RemoveAllEmergencyBlips()
        return 
    end

    -- We use playerSrc as the key instead of model to ensure unique blips per person
    local blipKey = tostring(playerSrc)
    
    if blips[blipKey] and DoesBlipExist(blips[blipKey]) then
        SetBlipCoords(blips[blipKey], x, y, z + 0.0)
    else
        local new_blip = AddBlipForCoord(x, y, z)
        if new_blip and DoesBlipExist(new_blip) then
            SetBlipSprite(new_blip, siren and 184 or 225)
            SetBlipAlpha(new_blip, 225)
            SetBlipScale(new_blip, 1.15)
            SetBlipAsShortRange(new_blip, false)

            blips[blipKey] = new_blip
        end
    end
    
    -- Continuously update name and sprite in case they change
    if blips[blipKey] then
        SetBlipSprite(blips[blipKey], siren and 184 or 225)
        
        local blipName = GetPlayerBlipName(playerSrc)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(blipName)
        EndTextCommandSetBlipName(blips[blipKey])
    end
end)

RegisterNetEvent("c_cargpsr")
AddEventHandler("c_cargpsr", function(playerSrc)
    local blipKey = tostring(playerSrc)
    if blips[blipKey] then
        RemoveBlip(blips[blipKey])
        blips[blipKey] = nil
    end
end)

-- Detect duty status change to remove blips
CreateThread(function()
    local lastDuty = LocalPlayer.state.onduty
    while true do
        Wait(1000)
        if lastDuty == true and LocalPlayer.state.onduty ~= true then
            RemoveAllEmergencyBlips()
        end
        lastDuty = LocalPlayer.state.onduty
    end
end)

-- Local player sending updates
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local playerped = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerped, false)
        
        -- If on duty and in emergency vehicle
        if LocalPlayer.state.onduty == true and veh ~= 0 and IsEmergencyVehicle(veh) then
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
            local coords = GetEntityCoords(veh)
            lastmodel = model
            TriggerServerEvent("gpsinfo", model, coords.x, coords.y, coords.z, GetPlayerServerId(PlayerId()), IsVehicleSirenOn(veh))
            lastVeh = veh
        elseif lastVeh ~= 0 then
            -- We just left a vehicle or went off duty
            TriggerServerEvent("gpsinfor", GetPlayerServerId(PlayerId()))
            lastVeh = 0
        end
    end
end)

-- Hide main player blip when in emergency vehicle to avoid double blips
CreateThread(function()
    local wasInEmergencyVehicle = false
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inEmergencyVehicle = veh ~= 0 and IsEmergencyVehicle(veh)
        local playerMainBlip = GetMainPlayerBlipId()
        
        if playerMainBlip and DoesBlipExist(playerMainBlip) then
            if inEmergencyVehicle and not wasInEmergencyVehicle then
                SetBlipAlpha(playerMainBlip, 0)
                wasInEmergencyVehicle = true
            elseif not inEmergencyVehicle and wasInEmergencyVehicle then
                SetBlipAlpha(playerMainBlip, 225)
                wasInEmergencyVehicle = false
            end
        end
    end
end)
