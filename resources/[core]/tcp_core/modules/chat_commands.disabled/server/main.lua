-- SCRP Core - Roleplay Chat Commands (Server)

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════

local MAX_MESSAGE_LENGTH = 256
local MAX_RANGE = 50000.0  -- Allow global messages (50km)
local RATE_LIMIT_TIME = 1000
local ENABLE_CHAT_LOGGING = false  -- Set to true to enable chat logging to file
local lastMessageTime = {}

-- ═══════════════════════════════════════════════════════════════
-- GLOBAL MESSAGE COLORS
-- ═══════════════════════════════════════════════════════════════

local GlobalColors = {
    ooc = {52, 152, 219},      -- Blue for OOC
    twt = {41, 128, 185},      -- Twitter blue
    ad = {241, 196, 15},       -- Yellow for ads
    news = {192, 57, 43},      -- Red for news
    anon = {44, 62, 80}        -- Dark for anonymous
}

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Chat logging (optional feature from cc-chat)
local function LogChatMessage(message)
    if not ENABLE_CHAT_LOGGING then return end
    
    local logFile = LoadResourceFile(GetCurrentResourceName(), 'modules/chat_commands/chat_log.log')
    if logFile == nil then
        SaveResourceFile(GetCurrentResourceName(), 'modules/chat_commands/chat_log.log', '')
        logFile = ''
    end
    
    logFile = logFile .. os.date("[%H:%M:%S] ") .. message .. '\n'
    SaveResourceFile(GetCurrentResourceName(), 'modules/chat_commands/chat_log.log', logFile)
end

local function GetCharacterName(source)
    local ok, player = pcall(function()
        return exports["ND_Core"] and exports["ND_Core"]:getPlayer(source) or nil
    end)

    if ok and player and player.firstname and player.lastname then
        return (player.fullname and tostring(player.fullname)) or (tostring(player.firstname) .. ' ' .. tostring(player.lastname))
    end
    
    return GetPlayerName(source)
end

local function CheckRateLimit(source)
    local currentTime = GetGameTimer()
    local lastTime = lastMessageTime[source] or 0
    
    if currentTime - lastTime < RATE_LIMIT_TIME then
        return false
    end
    
    lastMessageTime[source] = currentTime
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- PROXIMITY MESSAGE HANDLER
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scrp:chat:sendProximityMessage')
AddEventHandler('scrp:chat:sendProximityMessage', function(message, color, range)
    local source = source
    
    -- Input validation
    if type(message) ~= 'string' or #message == 0 or #message > MAX_MESSAGE_LENGTH then
        return
    end
    
    if type(color) ~= 'table' or #color ~= 3 then
        return
    end
    
    if type(range) ~= 'number' or range <= 0 or range > MAX_RANGE then
        return
    end
    
    -- Validate color values
    for i = 1, 3 do
        if type(color[i]) ~= 'number' or color[i] < 0 or color[i] > 255 then
            return
        end
    end
    
    local sourcePed = GetPlayerPed(source)
    if not sourcePed or sourcePed == 0 then
        return
    end
    
    local sourceCoords = GetEntityCoords(sourcePed)

    -- Send message to all nearby players
    for _, playerId in ipairs(GetPlayers()) do
        local targetPed = GetPlayerPed(tonumber(playerId))

        if targetPed and targetPed ~= 0 then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(sourceCoords - targetCoords)

            if distance <= range then
                TriggerClientEvent('scrp:chat:receiveProximityMessage', tonumber(playerId), message, color)
            end
        end
    end

    -- Log the message
    local logMsg = '[RP Chat] ' .. GetPlayerName(source) .. ': ' .. message
    print(logMsg)
    LogChatMessage(logMsg)
end)

-- ═══════════════════════════════════════════════════════════════
-- GLOBAL MESSAGE HANDLER
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scrp:chat:sendGlobalMessage')
AddEventHandler('scrp:chat:sendGlobalMessage', function(message, messageType)
    local source = source
    
    -- Input validation
    if type(message) ~= 'string' or #message == 0 or #message > MAX_MESSAGE_LENGTH then
        return
    end
    
    if type(messageType) ~= 'string' or not GlobalColors[messageType] then
        return
    end
    
    -- Rate limit check
    if not CheckRateLimit(source) then
        TriggerClientEvent('scrp:chat:receiveGlobalMessage', source, '^1[Rate Limit]^7 Please wait before sending another message.', {255, 0, 0})
        return
    end
    
    local playerName = GetCharacterName(source)
    local color = GlobalColors[messageType]
    local formattedMessage = ''
    
    if messageType == 'ooc' then
        formattedMessage = '^*[OOC] ' .. playerName .. ':^r ' .. message
    elseif messageType == 'twt' then
        formattedMessage = '^*[Twitter] @' .. playerName .. ':^r ' .. message
    elseif messageType == 'ad' then
        formattedMessage = '^*[Advertisement] ' .. playerName .. ':^r ' .. message
    elseif messageType == 'news' then
        formattedMessage = '^*[Breaking News]^r ' .. message
    elseif messageType == 'anon' then
        formattedMessage = '^*[Anonymous]^r ' .. message
        local anonLog = '[Anon Chat] ' .. GetPlayerName(source) .. ' (ID: ' .. source .. '): ' .. message
        print(anonLog)
        LogChatMessage(anonLog)
    end
    
    -- Send to all players
    TriggerClientEvent('scrp:chat:receiveGlobalMessage', -1, formattedMessage, color)
    
    -- Log the message (except anon which is logged separately)
    if messageType ~= 'anon' then
        local logMsg = '[Global Chat/' .. messageType:upper() .. '] ' .. GetPlayerName(source) .. ': ' .. message
        print(logMsg)
        LogChatMessage(logMsg)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP ON PLAYER DISCONNECT
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local source = source
    lastMessageTime[source] = nil
end)

print('^2[tcp_core]^7 Chat commands module loaded (server)')
