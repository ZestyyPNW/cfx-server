RegisterServerEvent("ZestyyMDC:CreateOBS")
AddEventHandler("ZestyyMDC:CreateOBS", function(location, radioCode, unitOverride, remarks, callX, callY, callZ)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local license = nil

    for _, id in pairs(identifiers) do
        if string.match(id, "license:") then
            license = id:gsub("license:", "")
            break
        end
    end

    if not license then
        print("^1[ZestyyMDC] Could not find license for player " .. src .. "^0")
        return
    end

    -- Get player's unit/callsign
    local unit = unitOverride or GetPlayerName(src)

    -- Make API call to MDC backend
    PerformHttpRequest('http://172.17.0.1:3002/api/observations', function(statusCode, response, headers)
        if statusCode == 200 or statusCode == 201 then
            print("^2[ZestyyMDC] OBS created successfully for " .. unit .. "^0")
            TriggerClientEvent("chat:addMessage", src, {
                args = {"^2[MDC]^7", "OBS created: " .. radioCode .. " at " .. location}
            })
        else
            print("^1[ZestyyMDC] Failed to create OBS. Status: " .. statusCode .. "^0")
            TriggerClientEvent("chat:addMessage", src, {
                args = {"^1[MDC]^7", "Failed to create OBS. Status: " .. statusCode}
            })
        end
    end, 'POST', json.encode({
        officer_unit = unit,
        location = location,
        radio_code = radioCode,
        remarks = remarks or "",
        call_x = callX,
        call_y = callY,
        call_z = callZ
    }), {
        ['Content-Type'] = 'application/json'
    })
end)

local function oxQueryAwait(query, params)
    local p = promise.new()
    exports.oxmysql:query(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

local function oxInsertAwait(query, params)
    local p = promise.new()
    exports.oxmysql:insert(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

local function dbQuery(query, params)
    if MySQL and MySQL.query and MySQL.query.await then
        return MySQL.query.await(query, params)
    end
    if exports.oxmysql then
        return oxQueryAwait(query, params)
    end
    return nil
end

local function dbInsert(query, params)
    if MySQL and MySQL.insert and MySQL.insert.await then
        return MySQL.insert.await(query, params)
    end
    if exports.oxmysql then
        return oxInsertAwait(query, params)
    end
    return nil
end

local function splitArgs(args)
    local options = {}
    local positionals = {}
    for _, token in ipairs(args or {}) do
        local key, value = token:match("^(%w+)%=(.+)$")
        if key and value then
            options[key:lower()] = value
        else
            table.insert(positionals, token)
        end
    end
    return options, positionals
end

local function getActiveCharacter(src)
    if GetResourceState('ND_Core') ~= 'started' then return nil end
    local ok, player = pcall(function()
        return exports['ND_Core']:getPlayer(src)
    end)
    if ok then return player end
    return nil
end

local function findCharacterId(firstName, lastName)
    if not firstName or not lastName then return nil end
    local result = dbQuery(
        "SELECT charid FROM nd_characters WHERE firstname = ? AND lastname = ? LIMIT 1",
        { firstName, lastName }
    )
    if result and result[1] then
        return result[1].charid
    end
    return nil
end

local function getUnitFromState(src)
    local player = Player(src)
    if not player then return nil end
    local unit = player.state and player.state.unitid or nil
    if unit == nil or unit == "" then return nil end
    return tostring(unit)
end

local function sendChat(src, prefix, message)
    TriggerClientEvent("chat:addMessage", src, {
        args = { prefix, message }
    })
end

RegisterCommand("booking", function(source, args)
    local src = source
    if src == 0 then return end
    local options, positionals = splitArgs(args)

    local lastName = options.ln or options.last or positionals[1]
    local firstName = options.fn or options.first or positionals[2]
    local location = options.loc or options.location
    if not location and #positionals > 2 then
        location = table.concat(positionals, " ", 3)
    end
    local middleName = options.mi or options.middle
    local suffix = options.suf or options.suffix
    local uoCode = options.uo

    if not lastName and not firstName and not location then
        sendChat(src, "^1[MDC]^7", "Usage: /booking LAST FIRST LOCATION (optional: loc=, mi=, suf=, uo=)")
        return
    end

    local characterId = nil
    if firstName and lastName then
        characterId = findCharacterId(firstName, lastName)
    end
    if not characterId then
        local active = getActiveCharacter(src)
        if active then characterId = active.id end
    end

    local insertId = dbInsert(
        "INSERT INTO nd_bookings (booking_location, last_name, first_name, middle_name, suffix, uo_code, character_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
        { location, lastName, firstName, middleName, suffix, uoCode, characterId }
    )

    if insertId then
        sendChat(src, "^2[MDC]^7", ("Booking saved (ID %s)"):format(insertId))
    else
        sendChat(src, "^1[MDC]^7", "Booking save failed.")
    end
end, false)

RegisterCommand("cleartag", function(source, args, rawCommand)
    local src = source
    if src == 0 then return end
    local options, positionals = splitArgs(args)

    local tagNumber = options.tag or options.tag_number or positionals[1]
    local callTag = options.call or options.calltag or positionals[2]
    local unit = options.unit or options.u or positionals[3] or getUnitFromState(src)
    local remarks = options.nar or options.remarks or options.rmk
    local raw = rawCommand and rawCommand:gsub("^/cleartag%s*", "") or ""

    if not tagNumber and not callTag and not unit then
        sendChat(src, "^1[MDC]^7", "Usage: /cleartag tag=TAG call=CALL unit=UNIT nar=REMARKS")
        return
    end

    local active = getActiveCharacter(src)
    local characterId = active and active.id or nil

    local data = {
        remarks = remarks,
        raw = raw,
        options = options,
        positionals = positionals
    }

    local insertId = dbInsert(
        "INSERT INTO nd_clear_tags (tag_number, call_tag, unit, character_id, data) VALUES (?, ?, ?, ?, ?)",
        { tagNumber, callTag, unit, characterId, json.encode(data) }
    )

    if insertId then
        sendChat(src, "^2[MDC]^7", ("Clear tag saved (ID %s)"):format(insertId))
    else
        sendChat(src, "^1[MDC]^7", "Clear tag save failed.")
    end
end, false)

RegisterCommand("gun", function(source, args)
    local src = source
    if src == 0 then return end
    local options, positionals = splitArgs(args)

    local serial = options.serial or options.ser or positionals[1]
    local ownerName = options.owner or options.name
    if not ownerName and #positionals > 1 then
        ownerName = table.concat(positionals, " ", 2)
    end

    local gunType = options.type
    local category = options.category or options.cat
    local make = options.make
    local caliber = options.caliber or options.cal
    local documentCode = options.doc or options.document
    local stolen = options.stolen == "1" or options.stolen == "true"

    if not serial then
        sendChat(src, "^1[MDC]^7", "Usage: /gun SERIAL (optional: owner=, type=, category=, make=, caliber=, doc=, stolen=1)")
        return
    end

    local ownerId = nil
    if ownerName then
        local first, last = ownerName:match("^(%S+)%s+(%S+)$")
        if first and last then
            ownerId = findCharacterId(first, last)
        end
    else
        local active = getActiveCharacter(src)
        if active then
            ownerId = active.id
            ownerName = ("%s %s"):format(active.firstname or "", active.lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")
        end
    end

    local insertId = dbInsert(
        "INSERT INTO nd_guns (serial, type, category, make, caliber, document_code, owner_character_id, owner_name, stolen) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        { serial, gunType, category, make, caliber, documentCode, ownerId, ownerName, stolen and 1 or 0 }
    )

    if insertId then
        sendChat(src, "^2[MDC]^7", ("Gun record saved (ID %s)"):format(insertId))
    else
        sendChat(src, "^1[MDC]^7", "Gun record save failed.")
    end
end, false)

RegisterCommand("bike", function(source, args)
    local src = source
    if src == 0 then return end
    local options, positionals = splitArgs(args)

    local serial = options.serial or options.ser or positionals[1]
    local oan = options.oan or positionals[2]
    local brand = options.brand
    if not brand and #positionals > 2 then
        brand = table.concat(positionals, " ", 3)
    end

    local speed = options.speed
    local flagMake = options.make == "1" or options.make == "true"
    local flagFemale = options.female == "1" or options.female == "true"
    local flagUndefined = options.undefined == "1" or options.undefined == "true"

    if not serial and not oan and not brand then
        sendChat(src, "^1[MDC]^7", "Usage: /bike SERIAL OAN BRAND (optional: speed=, make=1, female=1, undefined=1)")
        return
    end

    local active = getActiveCharacter(src)
    local ownerId = active and active.id or nil
    local ownerName = active and (("%s %s"):format(active.firstname or "", active.lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")) or nil

    local insertId = dbInsert(
        "INSERT INTO nd_bikes (serial, oan, brand, speed, flag_make, flag_female, flag_undefined, owner_character_id, owner_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        { serial, oan, brand, speed, flagMake and 1 or 0, flagFemale and 1 or 0, flagUndefined and 1 or 0, ownerId, ownerName }
    )

    if insertId then
        sendChat(src, "^2[MDC]^7", ("Bike record saved (ID %s)"):format(insertId))
    else
        sendChat(src, "^1[MDC]^7", "Bike record save failed.")
    end
end, false)

RegisterCommand("boat", function(source, args)
    local src = source
    if src == 0 then return end
    local options, positionals = splitArgs(args)

    local registrationNumber = options.reg or options.registration or positionals[1]
    local registrationState = options.state
    local hullNumber = options.hull or positionals[2]
    local oan = options.oan or positionals[3]
    local engineNumber = options.engine or positionals[4]
    local stolen = options.stolen == "1" or options.stolen == "true"

    if not registrationNumber and not hullNumber and not oan then
        sendChat(src, "^1[MDC]^7", "Usage: /boat REG HULL OAN (optional: state=, engine=, stolen=1)")
        return
    end

    local active = getActiveCharacter(src)
    local ownerId = active and active.id or nil
    local ownerName = active and (("%s %s"):format(active.firstname or "", active.lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")) or nil

    local insertId = dbInsert(
        "INSERT INTO nd_boats (registration_number, registration_state, hull_number, oan, engine_number, owner_character_id, owner_name, stolen) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        { registrationNumber, registrationState, hullNumber, oan, engineNumber, ownerId, ownerName, stolen and 1 or 0 }
    )

    if insertId then
        sendChat(src, "^2[MDC]^7", ("Boat record saved (ID %s)"):format(insertId))
    else
        sendChat(src, "^1[MDC]^7", "Boat record save failed.")
    end
end, false)

local lastBlipPayloadJson = nil
local lastEmptySentAt = 0

CreateThread(function()
    while true do
        PerformHttpRequest('http://172.17.0.1:3002/api/calls?limit=200', function(statusCode, response, headers)
            if statusCode ~= 200 then return end
            local decoded = nil
            pcall(function() decoded = json.decode(response) end)
            if not decoded or not decoded.success or type(decoded.calls) ~= "table" then return end

            local payload = {}
            for _, call in ipairs(decoded.calls) do
                if call.status ~= "CLOSED" and call.call_x and call.call_y and call.call_z then
                    table.insert(payload, {
                        id = call.id,
                        call_tag = call.call_tag,
                        code = call.code,
                        unit = call.unit,
                        character_name = call.character_name,
                        created_at = call.created_at,
                        call_x = call.call_x,
                        call_y = call.call_y,
                        call_z = call.call_z
                    })
                end
            end

            local payloadJson = json.encode(payload)
            if payloadJson == lastBlipPayloadJson then
                return
            end

            if #payload == 0 then
                local now = os.time()
                if now - lastEmptySentAt < 30 then
                    return
                end
                lastEmptySentAt = now
            end

            lastBlipPayloadJson = payloadJson
            TriggerClientEvent("ZestyyMDC:UpdateCallBlips", -1, payload)
        end, 'GET')
        Wait(5000)
    end
end)
