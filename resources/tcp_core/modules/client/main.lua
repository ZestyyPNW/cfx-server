-- SCRP Core - Roleplay Chat Commands (Client)

-- ═══════════════════════════════════════════════════════════════
-- TIMESTAMP FUNCTION (replaces cc-chat)
-- ═══════════════════════════════════════════════════════════════

local function getTimestamp()
    local meridiem = 'AM'
    local year, month, day, hour, minute, second = GetLocalTime()
    
    if hour >= 13 then
        hour = hour - 12
        meridiem = 'PM'
    end
    if hour == 12 then
        meridiem = 'PM'
    end
    if hour == 0 then
        hour = 12
    end
    if minute <= 9 then
        minute = '0' .. minute
    end
    
    return hour .. ':' .. minute .. ' ' .. meridiem
end

exports('getTimestamp', getTimestamp)

-- ═══════════════════════════════════════════════════════════════
-- COLOR DEFINITIONS
-- ═══════════════════════════════════════════════════════════════

local Colors = {
    me = {186, 85, 211},      -- Light purple for /me
    do_cmd = {255, 140, 0},   -- Orange for /do
    try_cmd = {100, 200, 255}, -- Light blue for /try
    ooc = {220, 220, 220},    -- Light gray for OOC
    whisper = {169, 169, 169}, -- Gray for whisper
    shout = {255, 99, 71},    -- Tomato red for shout
    low = {176, 196, 222},    -- Light steel blue for low voice
    emote = {255, 182, 193}   -- Light pink for emotes
}

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER DATA
-- ═══════════════════════════════════════════════════════════════

local currentCharacter = nil

-- Listen for character loaded event
RegisterNetEvent('scrp:characters:characterLoaded')
AddEventHandler('scrp:characters:characterLoaded', function(charData)
    currentCharacter = charData
    print('^2[SCRP Chat]^7 Character loaded: ' .. charData.firstname .. ' ' .. charData.lastname)
end)

-- Listen for character selection opened (to clear character data)
RegisterNetEvent('scrp:characters:selectionOpened')
AddEventHandler('scrp:characters:selectionOpened', function()
    currentCharacter = nil
    print('^3[SCRP Chat]^7 Character selection opened - character data cleared')
end)

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Get player's character name
local function GetCharacterName()
    -- Check if character is loaded
    if currentCharacter and currentCharacter.firstname and currentCharacter.lastname then
        return currentCharacter.firstname .. ' ' .. currentCharacter.lastname
    end

    -- Fallback to player name
    return GetPlayerName(PlayerId())
end

-- ═══════════════════════════════════════════════════════════════
-- /ME COMMAND - First-person actions
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('me', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /me [action]'}
        })
        return
    end

    local action = table.concat(args, ' ')
    local characterName = GetCharacterName()
    local message = '^** ' .. characterName .. ' ' .. action .. '.^r'

    -- Send to server to broadcast to nearby players
    TriggerServerEvent('scrp:chat:sendProximityMessage', message, Colors.me, 15.0)
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /DO COMMAND - Third-person descriptions
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('do', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /do [description]'}
        })
        return
    end

    local description = table.concat(args, ' ')
    local message = '^** ' .. description .. '.^r'

    -- Send to server to broadcast to nearby players
    TriggerServerEvent('scrp:chat:sendProximityMessage', message, Colors.do_cmd, 15.0)
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /TRY COMMAND - Actions with random success/failure
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('try', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /try [action]'}
        })
        return
    end

    local action = table.concat(args, ' ')
    local characterName = GetCharacterName()

    -- 50/50 chance of success
    local success = math.random(1, 2) == 1
    local message = ''
    
    if success then
        message = '^** ' .. characterName .. ' would successfully ' .. action .. ' and succeed.^r'
    else
        message = '^** ' .. characterName .. ' would ' .. action .. ' and fail.^r'
    end

    -- Send to server to broadcast to nearby players
    TriggerServerEvent('scrp:chat:sendProximityMessage', message, Colors.try_cmd, 15.0)
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /GME  COMMAND -First-person action for global chat
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('gme', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /gme [action]'}
        })
        return
    end

    local action = table.concat(args, ' ')
    local characterName = GetCharacterName()
    local message = '^**[GME] ' .. characterName .. ' ' .. action .. '.^r'

    -- Send to server to broadcast to nearby players
    TriggerServerEvent('scrp:chat:sendProximityMessage', message, Colors.me, 40000.0)
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /WHISPER COMMAND - Quiet speech (5m range)
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('whisper', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /whisper [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    local characterName = GetCharacterName()
    local formattedMessage = '^*' .. characterName .. ' whispers:^r ' .. message

    TriggerServerEvent('scrp:chat:sendProximityMessage', formattedMessage, Colors.whisper, 5.0)
end, false)

RegisterCommand('w', function(_, args)
    ExecuteCommand('whisper ' .. table.concat(args, ' '))
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /LOW COMMAND - Quiet speaking (8m range)
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('low', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /low [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    local characterName = GetCharacterName()
    local formattedMessage = '^*' .. characterName .. ' says quietly:^r ' .. message

    TriggerServerEvent('scrp:chat:sendProximityMessage', formattedMessage, Colors.low, 8.0)
end, false)

RegisterCommand('q', function(_, args)
    ExecuteCommand('low ' .. table.concat(args, ' '))
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /SHOUT COMMAND - Loud speech (30m range)
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('shout', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /shout [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    local characterName = GetCharacterName()
    local formattedMessage = '^*' .. characterName .. ' shouts:^r ' .. message:upper()

    TriggerServerEvent('scrp:chat:sendProximityMessage', formattedMessage, Colors.shout, 30.0)
end, false)

RegisterCommand('s', function(_, args)
    ExecuteCommand('shout ' .. table.concat(args, ' '))
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /EMOTE COMMAND - Visual emotes (15m range)
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('emote', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /emote [action]'}
        })
        return
    end

    local action = table.concat(args, ' ')
    local characterName = GetCharacterName()
    local formattedMessage = '^** ' .. characterName .. ' ' .. action .. '^r'

    TriggerServerEvent('scrp:chat:sendProximityMessage', formattedMessage, Colors.emote, 15.0)
end, false)

RegisterCommand('em', function(_, args)
    ExecuteCommand('emote ' .. table.concat(args, ' '))
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /OOC COMMAND - Out of character global chat
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('ooc', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /ooc [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    TriggerServerEvent('scrp:chat:sendGlobalMessage', message, 'ooc')
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /TWT COMMAND - Twitter/social media messages
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('twt', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /twt [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    TriggerServerEvent('scrp:chat:sendGlobalMessage', message, 'twt')
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /AD COMMAND - Advertisements
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('ad', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /ad [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    TriggerServerEvent('scrp:chat:sendGlobalMessage', message, 'ad')
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /NEWS COMMAND - News broadcasts
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('news', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /news [headline]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    TriggerServerEvent('scrp:chat:sendGlobalMessage', message, 'news')
end, false)

-- ═══════════════════════════════════════════════════════════════
-- /ANON COMMAND - Anonymous messages
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('anon', function(_, args)
    if #args == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = false,
            args = {'Usage: /anon [message]'}
        })
        return
    end

    local message = table.concat(args, ' ')
    TriggerServerEvent('scrp:chat:sendGlobalMessage', message, 'anon')
end, false)

-- ═══════════════════════════════════════════════════════════════
-- RECEIVE PROXIMITY MESSAGES
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scrp:chat:receiveProximityMessage')
AddEventHandler('scrp:chat:receiveProximityMessage', function(message, color)
    TriggerEvent('chat:addMessage', {
        color = color,
        multiline = false,
        args = {message}
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- RECEIVE GLOBAL MESSAGES
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scrp:chat:receiveGlobalMessage')
AddEventHandler('scrp:chat:receiveGlobalMessage', function(message, color)
    TriggerEvent('chat:addMessage', {
        color = color,
        multiline = false,
        args = {message}
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- /CLEAR COMMAND - Clear chat history
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('clear', function()
    -- Use FiveM's chat:clear event
    TriggerEvent('chat:clear')
    
    -- Optional: Add a confirmation message
    TriggerEvent('chat:addMessage', {
        color = {100, 255, 100},
        multiline = false,
        args = {'^*Chat cleared^r'}
    })
end, false)

RegisterCommand('clearchat', function()
    ExecuteCommand('clear')
end, false)

-- ═══════════════════════════════════════════════════════════════
-- HELP COMMAND
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('rp', function()
    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255},
        multiline = false,
        args = {'^*=== Roleplay Actions ===^r'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.me,
        multiline = false,
        args = {'^*/me [action]^r - First-person action (15m)'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.emote,
        multiline = false,
        args = {'^*/emote (/em) [action]^r - Visual emote (15m)'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.do_cmd,
        multiline = false,
        args = {'^*/do [description]^r - Scene description (15m)'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.try_cmd,
        multiline = false,
        args = {'^*/try [action]^r - Success/fail action (15m)'}
    })

    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255},
        multiline = false,
        args = {'^*=== Speech Commands ===^r'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.whisper,
        multiline = false,
        args = {'^*/whisper (/w) [message]^r - Whisper (5m)'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.low,
        multiline = false,
        args = {'^*/low (/q) [message]^r - Quiet speech (8m)'}
    })

    TriggerEvent('chat:addMessage', {
        color = Colors.shout,
        multiline = false,
        args = {'^*/shout (/s) [message]^r - Shout (30m, CAPS)'}
    })

    TriggerEvent('chat:addMessage', {
        color = {100, 200, 255},
        multiline = false,
        args = {'^*=== Global Commands ===^r'}
    })

    TriggerEvent('chat:addMessage', {
        color = {52, 152, 219},
        multiline = false,
        args = {'^*/ooc [message]^r - Out of character'}
    })

    TriggerEvent('chat:addMessage', {
        color = {41, 128, 185},
        multiline = false,
        args = {'^*/twt [message]^r - Twitter post'}
    })

    TriggerEvent('chat:addMessage', {
        color = {241, 196, 15},
        multiline = false,
        args = {'^*/ad [message]^r - Advertisement'}
    })

    TriggerEvent('chat:addMessage', {
        color = {192, 57, 43},
        multiline = false,
        args = {'^*/news [headline]^r - News broadcast'}
    })

    TriggerEvent('chat:addMessage', {
        color = {44, 62, 80},
        multiline = false,
        args = {'^*/anon [message]^r - Anonymous tip'}
    })
end, false)

print('^2[SCRP Core]^7 Roleplay chat commands loaded')
