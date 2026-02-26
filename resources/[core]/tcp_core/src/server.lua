-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

-- Used to retrive the players discord server nickname, discord name and tag, and the roles.
function getUserDiscordInfo(discordUserId)
    local data
    PerformHttpRequest("https://discordapp.com/api/guilds/" .. server_config.guildId .. "/members/" .. discordUserId, function(errorCode, resultData, resultHeaders)
		if errorCode ~= 200 then
            return
        end
        local result = json.decode(resultData)
        local roles = {}
        for _, roleId in pairs(result.roles) do
            roles[roleId] = roleId
        end
        data = {
            nickname = result.nick,
            discordTag = tostring(result.user.username) .. "#" .. tostring(result.user.discriminator),
            roles = roles
        }
    end, "GET", "", {["Content-Type"] = "application/json", ["Authorization"] = "Bot " .. server_config.discordServerToken})
    while not data do
        Citizen.Wait(0)
    end
    return data
end

-- Get player any identifier, available types: steam, license, xbl, ip, discord, live.
function GetPlayerIdentifierFromType(type, source)
    local identifierCount = GetNumPlayerIdentifiers(source)
    for count = 0, identifierCount do
        local identifier = GetPlayerIdentifier(source, count)
        if identifier and string.find(identifier, type) then
            return identifier
        end
    end
    return nil
end

local function normalizeApiBase(value)
    local base = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if base == "" then return nil end
    return base:gsub("/+$", "")
end

local function getMdcApiBase()
    local base = normalizeApiBase(GetConvar("tcp_mdc_api_base", ""))
    if not base and server_config then
        base = normalizeApiBase(server_config.mdcApiBase)
    end
    return base
end

local function getMdcApiKey()
    local key = tostring(GetConvar("tcp_mdc_api_key", "") or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" and server_config then
        key = tostring(server_config.mdcApiKey or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end
    if key == "" then return nil end
    return key
end

local lastMissingApiBaseWarning = 0

local function warnMissingApiBase()
    local now = os.time()
    if now - lastMissingApiBaseWarning > 60 then
        lastMissingApiBaseWarning = now
        print("^1[tcp_core] MDC API base missing. Set server_config.mdcApiBase or tcp_mdc_api_base.^0")
    end
end

local function buildMdcHeaders(extra)
    local headers = {}
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            headers[key] = value
        end
    end
    local apiKey = getMdcApiKey()
    if apiKey then
        headers["X-MDC-KEY"] = apiKey
    end
    return headers
end

RegisterNetEvent("tcp_core:911", function(payload)
    local src = source
    if type(payload) ~= "table" then 
        print(("[tcp_core] /911 invalid payload from source %d"):format(src))
        return 
    end

    local message = tostring(payload.message or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then 
        print(("[tcp_core] /911 empty message from source %d"):format(src))
        TriggerClientEvent("tcp_core:911Result", src, false)
        return 
    end

    local location = tostring(payload.location or "UNKNOWN LOCATION")
    local caller = payload.caller and tostring(payload.caller) or "UNKNOWN CALLER"
    local coords = payload.coords or {}

    local description = message
    if caller and caller ~= "UNKNOWN CALLER" then
        description = ("[%s] %s"):format(caller, message)
    end

    local body = {
        title = "911",
        code = "911",
        location = location,
        description = description,
        priority = 2,
        status = "PENDING",
        call_type = "911",
        unit = nil,
        station_prefix = server_config.stationPrefix or "EWP",
        call_x = coords.x,
        call_y = coords.y,
        call_z = coords.z
    }

    local apiBase = getMdcApiBase()
    if not apiBase then
        warnMissingApiBase()
        TriggerClientEvent("tcp_core:911Result", src, false)
        return
    end
    local url = apiBase .. "/api/calls/create"
    
    print(("[tcp_core] /911 sending request to: %s"):format(url))
    print(("[tcp_core] /911 request body: %s"):format(json.encode(body)))
    
    PerformHttpRequest(url, function(status, response, headers)
        if not status then
            print(("[tcp_core] /911 ERROR: No status code received. Response: %s"):format(tostring(response or "nil")))
            TriggerClientEvent("tcp_core:911Result", src, false)
            return
        end
        
        print(("[tcp_core] /911 response status: %s"):format(tostring(status)))
        print(("[tcp_core] /911 response body: %s"):format(tostring(response or "nil")))
        
        local ok = status >= 200 and status < 300
        if not ok then
            print(("[tcp_core] /911 failed: HTTP %s - %s"):format(tostring(status), tostring(response or "no response")))
            print(("[tcp_core] /911 attempted URL: %s"):format(url))
        else
            print(("[tcp_core] /911 call created successfully from %s at %s"):format(caller, location))
            -- Notify SCC auto-dispatch to broadcast over radio
            TriggerEvent("scc:911Created", caller, location, message, coords)
        end
        TriggerClientEvent("tcp_core:911Result", src, ok)
    end, "POST", json.encode(body), buildMdcHeaders({ ["Content-Type"] = "application/json" }))
end)

-- MDC unread message polling (server-side)
Citizen.CreateThread(function()
    local lastCountsByPlayer = {}
    while true do
        local apiBase = getMdcApiBase()
        if not apiBase then
            warnMissingApiBase()
            Citizen.Wait(10000)
        else
            local players = GetPlayers()
            local unitPlayers = {}
            local activePlayers = {}

            for _, playerId in ipairs(players) do
                local numericId = tonumber(playerId)
                if numericId then
                    activePlayers[numericId] = true
                end
                local state = Player(playerId).state
                local unit = state and state.unitid or nil
                if unit and tostring(unit) ~= "" and numericId then
                    local cleanUnit = tostring(unit):upper()
                    if not unitPlayers[cleanUnit] then
                        unitPlayers[cleanUnit] = {}
                    end
                    table.insert(unitPlayers[cleanUnit], numericId)
                end
            end

            for unit, playerList in pairs(unitPlayers) do
                local url = apiBase .. "/api/messages/unread/" .. unit
                PerformHttpRequest(url, function(status, response)
                    if status and status >= 200 and status < 300 and response then
                        local ok, data = pcall(json.decode, response)
                        if ok and data and data.success then
                            local count = tonumber(data.count) or 0
                            for _, playerId in ipairs(playerList) do
                                if lastCountsByPlayer[playerId] ~= count then
                                    lastCountsByPlayer[playerId] = count
                                    TriggerClientEvent("SimpleHUD:updateMDC", playerId, count)
                                end
                            end
                        end
                    end
                end, "GET", "", buildMdcHeaders())
            end

            for playerId in pairs(lastCountsByPlayer) do
                if not activePlayers[playerId] then
                    lastCountsByPlayer[playerId] = nil
                end
            end

            Citizen.Wait(10000)
        end
    end
end)

local function countWaitingIncidents(calls)
    if type(calls) ~= "table" then
        return 0
    end

    local count = 0
    for _, call in ipairs(calls) do
        local unit = tostring(call.unit or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if unit == "" then
            local status = tostring(call.status or ""):upper()
            local callType = tostring(call.call_type or ""):upper()
            if status ~= "CLOSED" and callType ~= "OBSERVATION" then
                count = count + 1
            end
        end
    end
    return count
end

Citizen.CreateThread(function()
    local lastWaitingCounts = {}
    while true do
        local apiBase = getMdcApiBase()
        if not apiBase then
            warnMissingApiBase()
            Citizen.Wait(10000)
        else
            local url = apiBase .. "/api/calls?limit=200"
            PerformHttpRequest(url, function(status, response)
                if status and status >= 200 and status < 300 and response then
                    local ok, data = pcall(json.decode, response)
                    if ok and data and data.success then
                        local waitingCount = countWaitingIncidents(data.calls)
                        for _, playerId in ipairs(GetPlayers()) do
                            local numericId = tonumber(playerId)
                            if numericId and lastWaitingCounts[numericId] ~= waitingCount then
                                lastWaitingCounts[numericId] = waitingCount
                                TriggerClientEvent("SimpleHUD:updateWaitingIncidents", numericId, waitingCount)
                            end
                        end
                    end
                end
            end, "GET", "", buildMdcHeaders())
            Citizen.Wait(10000)
        end
    end
end)

if config.enablePriorityStatus then
    local priority = "~s~Priority: ~g~Available"
    local priorityPlayers = {}
    local isPriorityCooldown = false
    local isPriorityActive = false

    -- concat tables that doesn't work with table.concat().
    function tableConcat(table, concat)
        local string = ""
        local first = true
        for _, v in pairs(table) do
            if first then
                string = tostring(v)
                first = false
            else
                string = string .. concat .. tostring(v)
            end
        end
        return string
    end

    -- count how many values the table has, when #table doesn't work.
    function tableCount(table)
        local count = 0
        for _ in pairs(table) do
            count = count + 1
        end
        return count
    end

    -- Priority cooldown countdown.
    function priorityCooldown(time)
        isPriorityActive = false
        isPriorityCooldown = true
        for cooldown = time, 1, -1 do
            if cooldown > 1 then
                priority = "~s~Priority Cooldown: ~c~" .. cooldown .. " minutes"
            else
                priority = "~s~Priority Cooldown: ~c~" .. cooldown .. " minute"
            end
            TriggerClientEvent("AndyHUD:returnPriority", -1, priority)
            Citizen.Wait(60000)
        end
        priority = "~s~Priority: ~g~Available"
        TriggerClientEvent("AndyHUD:returnPriority", -1, priority)
        isPriorityCooldown = false
    end

    -- update priority on new client.
    RegisterNetEvent("AndyHUD:getPriority")
    AddEventHandler("AndyHUD:getPriority", function()
        local player = source
        TriggerClientEvent("AndyHUD:returnPriority", player, priority)
    end)

    -- Start a priority.
    RegisterCommand("prio-start", function(source, args, rawCommand)
        local player = source
        if isPriorityCooldown then
            TriggerClientEvent("tcp_notify:show", player, "Priority: Cannot start due to cooldown.", 4000)
            return
        end
        if isPriorityActive then
            TriggerClientEvent("tcp_notify:show", player, "Priority: There's already an active priority.", 4000)
            return
        end
        isPriorityActive = true
        priorityPlayers[player] = GetPlayerName(player) .. " #" .. player
        priority = "~s~Priority: ~r~Active ~c~(" .. tableConcat(priorityPlayers, ", ") .. ")"
        TriggerClientEvent("AndyHUD:returnPriority", -1, priority)
    end, false)

    -- stop the priority.
    RegisterCommand("prio-stop", function(source, args, rawCommand)
        local player = source
        if not isPriorityActive then
            TriggerClientEvent("tcp_notify:show", player, "Priority: There's no active priority to stop.", 4000)
            return
        end
        priorityPlayers = {}
        priorityCooldown(config.cooldownAfterPriorityStops)
    end, false)

    -- priority cooldown.
    RegisterCommand("prio-cd", function(source, args, rawCommand)
        local player = source

        if #server_config.discordServerToken > 1 and #server_config.guildId > 1 then
            local discordUserId = string.gsub(GetPlayerIdentifierFromType("discord", player), "discord:", "")
            local roles = getUserDiscordInfo(discordUserId).roles
            local hasPerms = false
        
            for _, roleId in pairs(config.cooldownAccess) do
                if roles[roleId] or roleId == "0" or roleId == 0 then
                    hasPerms = true
                    break
                end
            end

            if not hasPerms then
                TriggerClientEvent("tcp_notify:show", player, "Priority: You don't have permission to use this command.", 4000)
                return
            end
        end

        print("test")

        local time = tonumber(args[1])
        if time and time > 0 then
            priorityCooldown(time)
        end
    end, false)

    -- joining priorities.
    RegisterCommand("prio-join", function(source, args, rawCommand)
        local player = source
        if not isPriorityActive then
            TriggerClientEvent("tcp_notify:show", player, "Priority: There's no active priority to join.", 4000)
            return
        end
        if priorityPlayers[player] then
            TriggerClientEvent("tcp_notify:show", player, "Priority: You're already in this priority.", 4000)
            return
        end
        priorityPlayers[player] = GetPlayerName(player) .. " #" .. player
        priority = "~s~Priority: ~r~Active ~c~(" .. tableConcat(priorityPlayers, ", ") .. ")"
        TriggerClientEvent("AndyHUD:returnPriority", -1, priority)
    end, false)


    -- leaving priorities.
    RegisterCommand("prio-leave", function(source, args, rawCommand)
        local player = source
        if not isPriorityActive then
            TriggerClientEvent("tcp_notify:show", player, "Priority: There's no active priority to leave.", 4000)
            return
        end
        if tableCount(priorityPlayers) == 1 and priorityPlayers[player] == (GetPlayerName(player) .. " #" .. player) then
            priorityPlayers = {}
            priority = "~s~Priority: ~g~Available"
            isPriorityActive = false
        else
            priorityPlayers[player] = nil
            priority = "~s~Priority: ~r~Active ~c~(" .. tableConcat(priorityPlayers, ", ") .. ")"
        end
        TriggerClientEvent("AndyHUD:returnPriority", -1, priority)
    end, false)
end

-- update and set aop.
if config.enableAopStatus then
    local aop = config.defaultAopStatus
    RegisterNetEvent("AndyHUD:getAop")
    AddEventHandler("AndyHUD:getAop", function()
        local player = source
        TriggerClientEvent("AndyHUD:ChangeAOP", player, aop)
    end)
end

local postals = {}
CreateThread(function()
    postals = json.decode(LoadResourceFile(GetCurrentResourceName(), "postals.json"))
    for i = 1, #postals do
        local postal = postals[i]
        postals[i] = {
            coords = vec(postal.x, postal.y),
            code = postal.code
        }
    end
end)

RegisterCommand("dvall", function(source, args)
    local seconds = tonumber(args[1]) or 10
    if seconds < 1 then
        seconds = 1
    elseif seconds > 60 then
        seconds = 60
    end
    TriggerClientEvent("tcp_core:dvallCountdown", -1, seconds)
end, true)

function getPostal(source)
    local ped = GetPlayerPed(source)
    local pedCoords = GetEntityCoords(ped)
    local coords = vec(pedCoords.x, pedCoords.y)
    local nearestPostal = nil
    local nearestDist = nil
    local nearestIndex = nil

    for i = 1, #postals do
        local dist = #(coords - postals[i].coords)
        if not nearestDist or dist < nearestDist then
            nearestIndex = i
            nearestDist = dist
        end
    end
    nearestPostal = postals[nearestIndex]

    return nearestPostal.code, nearestPostal
end

local function clampStat(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function normalizeStats(stats)
    stats = type(stats) == "table" and stats or {}
    local stamina = clampStat(stats.stamina)
    local strength = clampStat(stats.strength)
    local agility = stats.agility
    if agility == nil then
        agility = math.floor((stamina + strength) / 2 + 0.5)
    end
    agility = clampStat(agility)

    return {
        stamina = stamina,
        strength = strength,
        agility = agility,
        driving = clampStat(stats.driving),
        shooting = clampStat(stats.shooting),
        swimming = clampStat(stats.swimming),
        stealth = clampStat(stats.stealth),
    }
end

local function getPlayerStats(source)
    if GetResourceState("ND_Core") ~= "started" then
        return normalizeStats({})
    end

    local player = exports["ND_Core"]:getPlayer(source)
    if not player then
        return normalizeStats({})
    end

    local stored = player.getMetadata and player.getMetadata("stats") or nil
    return normalizeStats(stored)
end

RegisterNetEvent("tcp_core:updatePlayerStats", function(stats)
    local src = source
    if type(stats) ~= "table" then return end
    if GetResourceState("ND_Core") ~= "started" then return end

    local player = exports["ND_Core"]:getPlayer(src)
    if not player or not player.setMetadata then return end

    local normalized = normalizeStats(stats)
    player.setMetadata("stats", normalized)
    if player.save then
        player.save("metadata")
    end
end)

RegisterNetEvent("tcp_core:requestPlayerStats", function()
    local src = source
    TriggerClientEvent("tcp_core:receivePlayerStats", src, getPlayerStats(src))
end)

exports("getPlayerStats", function(source)
    return getPlayerStats(source)
end)
