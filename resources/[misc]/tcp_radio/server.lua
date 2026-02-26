local activeRadios = {} -- [netId] = { url, volume, owner }

RegisterNetEvent('tcp_radio:play', function(netId, url, volume)
    local src = source
    activeRadios[netId] = { url = url, volume = volume or 0.5, owner = src }

    -- Tell every client to start playing this sound at the vehicle
    TriggerClientEvent('tcp_radio:sync_play', -1, netId, url, volume or 0.5)
end)

RegisterNetEvent('tcp_radio:stop', function(netId)
    activeRadios[netId] = nil
    TriggerClientEvent('tcp_radio:sync_stop', -1, netId)
end)

RegisterNetEvent('tcp_radio:volume', function(netId, volume)
    if activeRadios[netId] then
        activeRadios[netId].volume = volume
    end
    TriggerClientEvent('tcp_radio:sync_volume', -1, netId, volume)
end)

-- When a new player joins, sync all active radios to them
AddEventHandler('playerJoining', function()
    local src = source
    for netId, data in pairs(activeRadios) do
        TriggerClientEvent('tcp_radio:sync_play', src, netId, data.url, data.volume)
    end
end)

-- Clean up when owner disconnects
AddEventHandler('playerDropped', function()
    local src = source
    for netId, data in pairs(activeRadios) do
        if data.owner == src then
            activeRadios[netId] = nil
            TriggerClientEvent('tcp_radio:sync_stop', -1, netId)
        end
    end
end)
