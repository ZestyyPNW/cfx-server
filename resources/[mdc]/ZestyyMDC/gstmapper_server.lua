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

local function getOnDutyPlayers()
    local targets = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if id then
            local onduty = Player(id).state.onduty
            if onduty == true then
                targets[#targets + 1] = id
            end
        end
    end
    return targets
end

RegisterNetEvent('gpsinfo')
AddEventHandler('gpsinfo', function(model, x, y, z, _, siren)
    local src = source
    if not isAllowedMdcUser(src) then return end
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if not x or not y or not z then return end
    for _, target in ipairs(getOnDutyPlayers()) do
        TriggerClientEvent('c_cargps', target, model, x, y, z, src, siren)
    end
end)

RegisterNetEvent('gpsinfor')
AddEventHandler('gpsinfor', function(_)
    local src = source
    if not isAllowedMdcUser(src) then return end
    for _, target in ipairs(getOnDutyPlayers()) do
        TriggerClientEvent('c_cargpsr', target, src)
    end
end)
