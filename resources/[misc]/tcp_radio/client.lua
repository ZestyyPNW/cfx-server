local radioOpen = false
local myVehicle = 0
local myNetId = 0
local myUrl = nil
local radioVolume = 0.5
local MAX_DISTANCE = 10.0

local activeRadios = {} -- [netId] = true, tracks all radios we know about

RegisterCommand('music', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        if myUrl then
            radioOpen = not radioOpen
            SetNuiFocus(radioOpen, radioOpen)
            SendNUIMessage({ type = 'toggle', show = radioOpen })
        else
            exports['ox_lib']:notify({ title = 'Radio', description = 'You need to be in a vehicle', type = 'error' })
        end
        return
    end

    radioOpen = not radioOpen
    SetNuiFocus(radioOpen, radioOpen)
    SendNUIMessage({ type = 'toggle', show = radioOpen })

    myVehicle = veh
    myNetId = NetworkGetNetworkIdFromEntity(veh)
end, false)

RegisterNUICallback('close', function(_, cb)
    radioOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('playStream', function(data, cb)
    local url = data.url
    if not url or url == '' then cb('err') return end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then cb('err') return end

    myVehicle = veh
    myNetId = NetworkGetNetworkIdFromEntity(veh)
    myUrl = url

    TriggerServerEvent('tcp_radio:play', myNetId, url, radioVolume)
    cb('ok')
end)

RegisterNUICallback('stopStream', function(_, cb)
    if myNetId ~= 0 then
        TriggerServerEvent('tcp_radio:stop', myNetId)
    end
    myUrl = nil
    cb('ok')
end)

RegisterNUICallback('setVolume', function(data, cb)
    radioVolume = tonumber(data.volume) or 0.5
    if myNetId ~= 0 then
        TriggerServerEvent('tcp_radio:volume', myNetId, radioVolume)
    end
    cb('ok')
end)

-- All clients: start playing a vehicle radio with 3D audio
RegisterNetEvent('tcp_radio:sync_play', function(netId, url, volume)
    local soundId = 'tcp_radio_' .. netId
    local veh = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(veh) then
        local pos = GetEntityCoords(veh)

        if exports.xsound:soundExists(soundId) then
            exports.xsound:Destroy(soundId)
        end

        exports.xsound:PlayUrlPos(soundId, url, volume, pos, true)
        exports.xsound:Distance(soundId, MAX_DISTANCE)
    end

    activeRadios[netId] = true
end)

-- All clients: stop a vehicle radio
RegisterNetEvent('tcp_radio:sync_stop', function(netId)
    local soundId = 'tcp_radio_' .. netId

    if exports.xsound:soundExists(soundId) then
        exports.xsound:Destroy(soundId)
    end

    activeRadios[netId] = nil

    if myNetId == netId then
        myUrl = nil
    end
end)

-- All clients: update volume
RegisterNetEvent('tcp_radio:sync_volume', function(netId, volume)
    local soundId = 'tcp_radio_' .. netId

    if exports.xsound:soundExists(soundId) then
        exports.xsound:setVolume(soundId, volume)
    end
end)

-- Position update: keep ALL active radio sounds following their vehicles
Citizen.CreateThread(function()
    while true do
        local hasSounds = false

        for netId, _ in pairs(activeRadios) do
            local soundId = 'tcp_radio_' .. netId
            local veh = NetworkGetEntityFromNetworkId(netId)

            if DoesEntityExist(veh) and exports.xsound:soundExists(soundId) then
                local pos = GetEntityCoords(veh)
                exports.xsound:Position(soundId, pos)
                hasSounds = true
            end
        end

        Citizen.Wait(hasSounds and 200 or 1000)
    end
end)
