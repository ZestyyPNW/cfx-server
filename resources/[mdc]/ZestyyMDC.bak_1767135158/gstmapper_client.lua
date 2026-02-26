local blips = {}
local lastmodel
local function IsEmergencyVehicle(veh)
    if not DoesEntityExist(veh) then
        return false
    end
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
    if not player or not player.state then return "Unknown" end
    
    local unit = player.state.unitid or "N/A"
    local full = player.state.nd_players_name
    local first = player.state.firstname or player.state.firstName
    local last = player.state.lastname or player.state.lastName
    
    if full and tostring(full) ~= "" then
        return tostring(full) .. " | " .. unit
    end
    if first and last then
        return tostring(first) .. " " .. tostring(last) .. " | " .. unit
    end
    return unit ~= "N/A" and ("UNIT " .. unit) or "Unknown"
end

local function RemoveAllEmergencyBlips()
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}
end

RegisterNetEvent("c_cargps")
AddEventHandler("c_cargps", function(model, x, y, z, playerSrc, siren)
    local playerped = PlayerPedId()
    local veh = GetVehiclePedIsIn(playerped, false)
    if IsEmergencyVehicle(veh) then
        if GetPedInVehicleSeat(veh, -1) == playerped or GetPedInVehicleSeat(veh, 0) == playerped then
            RemoveBlip(blips[model])
            local new_blip = AddBlipForCoord(x, y, z)
            if new_blip and DoesBlipExist(new_blip) then
                SetBlipSprite(new_blip, siren and 184 or 225)
                SetBlipAlpha(new_blip, 225)
                SetBlipScale(new_blip, 1.15)

                -- Set blip name to player's unit ID
                local blipName = GetPlayerBlipName(playerSrc)
                if blipName and blipName ~= "" then
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentSubstringPlayerName(blipName)
                    EndTextCommandSetBlipName(new_blip)
                end

                blips[model] = new_blip
            end
        end
    end
end)

RegisterNetEvent("c_cargpsr")
AddEventHandler("c_cargpsr", function(model)
    RemoveBlip(blips[model])
end)

-- Detect duty status change to remove blips
CreateThread(function()
    local lastDuty = LocalPlayer.state.onduty
    while true do
        Wait(1000)
        if lastDuty and not LocalPlayer.state.onduty then
            RemoveAllEmergencyBlips()
        end
        lastDuty = LocalPlayer.state.onduty
    end
end)

-- Only remove blips if the vehicle is deleted, not when player exits
CreateThread(function()
    while true do
        Wait(1000)
        for model, blip in pairs(blips) do
            local found = false
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) and GetDisplayNameFromVehicleModel(GetEntityModel(veh)) == model then
                    found = true
                    break
                end
            end
            if not found then
                RemoveBlip(blip)
                blips[model] = nil
            end
        end
    end
end)

CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(500)
        local playerped = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerped, false)
        if veh ~= 0 and veh ~= lastVeh and IsEmergencyVehicle(veh) then
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
            local x, y, z = table.unpack(GetEntityCoords(veh))
            lastmodel = model
            TriggerServerEvent("gpsinfo", model, x, y, z, GetPlayerServerId(PlayerId()), IsVehicleSirenOn(veh))
            lastVeh = veh
        elseif veh == 0 then
            lastVeh = 0
        end
    end
end)

CreateThread(function()
    while true do
        Wait(3000)
        local playerped = PlayerPedId()
        local veh = GetPlayersLastVehicle()
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))

        if not DoesEntityExist(veh) then
            veh = GetVehiclePedIsIn(playerped, false)
        end

        if model ~= lastmodel then
            TriggerServerEvent("gpsinfor", lastmodel)
        end

        if (GetLastPedInVehicleSeat(veh, -1) == playerped or GetPedInVehicleSeat(veh, -1) == playerped) and IsEmergencyVehicle(veh) then
            local x, y, z = table.unpack(GetEntityCoords(veh))
            lastmodel = model
            TriggerServerEvent("gpsinfo", model, x, y, z, GetPlayerServerId(PlayerId()), IsVehicleSirenOn(veh))
        end

        if not DoesEntityExist(veh) then
            TriggerServerEvent("gpsinfor", lastmodel)
        end
    end
end)

-- Hide main player blip when in emergency vehicle to avoid overlap
CreateThread(function()
    local wasInEmergencyVehicle = false
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inEmergencyVehicle = veh ~= 0 and IsEmergencyVehicle(veh)
        local playerMainBlip = GetMainPlayerBlipId()

        if inEmergencyVehicle and not wasInEmergencyVehicle then
            SetBlipAlpha(playerMainBlip, 0)
            wasInEmergencyVehicle = true
        elseif not inEmergencyVehicle and wasInEmergencyVehicle then
            SetBlipAlpha(playerMainBlip, 255)
            wasInEmergencyVehicle = false
        end
    end
end)

CreateThread(function()
    local wasInEmergencyVehicle = false
    local playerMainBlip = GetMainPlayerBlipId()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inEmergencyVehicle = veh ~= 0 and IsEmergencyVehicle(veh)
        if inEmergencyVehicle and not wasInEmergencyVehicle then
            SetBlipAlpha(playerMainBlip, 0)
            wasInEmergencyVehicle = true
        end
        if not inEmergencyVehicle and wasInEmergencyVehicle then
            SetBlipAlpha(playerMainBlip, 225)
            wasInEmergencyVehicle = false
        end
    end
end)
