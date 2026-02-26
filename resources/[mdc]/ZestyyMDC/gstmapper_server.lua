local function isAllowedMdcUser(src)
    if not Config or not Config.AllowedGroups then return true end
    if GetResourceState('ND_Core') ~= 'started' then return false end
    local ok, player = pcall(function()
        return exports['ND_Core']:getPlayer(src)
    end)
    if not ok or not player then return false end
    if player.job and Config.AllowedGroups[player.job] then return true end
    if player.groups then
        for name in pairs(player.groups) do
            if Config.AllowedGroups[name] then return true end
        end
    end
    return false
end

RegisterNetEvent('gpsinfo')
AddEventHandler('gpsinfo', function(model, x, y, z, _, siren)
    local src = source
    if not isAllowedMdcUser(src) then return end
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if not x or not y or not z then return end
    TriggerClientEvent('c_cargps', -1, model, x, y, z, src, siren)
end)

RegisterNetEvent('gpsinfor')
AddEventHandler('gpsinfor', function(_)
    local src = source
    if not isAllowedMdcUser(src) then return end
    TriggerClientEvent('c_cargpsr', -1, src)
end)
