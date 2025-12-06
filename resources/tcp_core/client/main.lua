
-- example spawn hook: listen for server spawn event
RegisterNetEvent('tcp_core:client:spawn', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.heading or 0.0)
    FreezeEntityPosition(ped, false)
end)
