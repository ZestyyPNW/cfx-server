local function sendChat(src, prefix, message)
    TriggerClientEvent("chat:addMessage", src, {
        args = { prefix, message }
    })
end

local function safeStr(value, fallback)
    if value == nil then return fallback end
    local str = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then return fallback end
    return str
end

RegisterNetEvent("ZestyyMDC:NuiConsole")
AddEventHandler("ZestyyMDC:NuiConsole", function(payload)
    local src = source
    if not Config or not Config.ForwardConsoleErrorsToServer then return end

    local level = safeStr(payload and payload.level, "error"):upper()
    local msg = safeStr(payload and payload.message, "unknown error")
    local href = safeStr(payload and payload.href, "")
    local user = safeStr(payload and payload.user, "")
    local stack = safeStr(payload and payload.stack, "")

    local head = ("[ZestyyMDC] WEB %s from %s"):format(level, tostring(src))
    if user ~= "" then head = head .. (" user=%s"):format(user) end
    if href ~= "" then head = head .. (" href=%s"):format(href) end
    print(head)
    print(("[ZestyyMDC] WEB %s %s"):format(level, msg))
    if stack ~= "" then
        print(("[ZestyyMDC] WEB %s STACK %s"):format(level, stack))
    end
end)

local getUnitFromState
local dbQuery
local dbInsert
local dbUpdate


local function normalizeApiBase(value)
    local base = tostring(value or ""):gsub("%s+$", ""):gsub("^%s+", "")
    if base == "" then return nil end
    return base:gsub("/+$", "")
end

local function getMdcApiBase()
    local base = normalizeApiBase(GetConvar("zestyy_mdc_api_base", ""))
    if not base and Config then
        base = normalizeApiBase(Config.MdcApiBase)
    end
    return base
end

local function getMdcApiKey()
    local key = safeStr(GetConvar("zestyy_mdc_api_key", ""), "")
    if key == "" and Config then
        key = safeStr(Config.MdcApiKey, "")
    end
    if key == "" then return nil end
    return key
end

local lastMissingApiBaseWarning = 0

local function warnMissingApiBase()
    local now = os.time()
    if now - lastMissingApiBaseWarning > 60 then
        lastMissingApiBaseWarning = now
        print("^1[ZestyyMDC] MDC API base missing. Set Config.MdcApiBase or zestyy_mdc_api_base.^0")
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

local function performMdcRequest(path, cb, method, body, headers)
    local base = getMdcApiBase()
    if not base then
        warnMissingApiBase()
        cb(0, nil, nil)
        return
    end

    PerformHttpRequest(base .. path, function(statusCode, response, respHeaders)
        cb(statusCode or 0, response, respHeaders)
    end, method or "GET", body, buildMdcHeaders(headers))
end

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

RegisterServerEvent("ZestyyMDC:CreateOBS")
AddEventHandler("ZestyyMDC:CreateOBS", function(location, radioCode, unitOverride, remarks, callX, callY, callZ)
    local src = source
    if not isAllowedMdcUser(src) then
        TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use MDC OBS.", 4000)
        return
    end
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
    local unit = getUnitFromState(src) or unitOverride or GetPlayerName(src)

    -- Make API call to MDC backend using /api/calls/create (doesn't require auth)
    performMdcRequest('/api/calls/create', function(statusCode, response, headers)
        if statusCode == 200 or statusCode == 201 then
            print("^2[ZestyyMDC] OBS created successfully for " .. unit .. "^0")
            TriggerClientEvent("tcp_notify:show", src, "MDC: OBS created: " .. radioCode .. " at " .. location, 5000)
        else
            print("^1[ZestyyMDC] Failed to create OBS. Status: " .. statusCode .. "^0")
            TriggerClientEvent("tcp_notify:show", src, "MDC: Failed to create OBS. Status: " .. statusCode, 5000)
        end
    end, 'POST', json.encode({
        title = radioCode or 'OBS',
        code = radioCode or 'OBS',
        location = location,
        description = remarks or "",
        priority = 2,
        status = 'PENDING',
        call_type = 'OBSERVATION',
        unit = unit,
        call_x = callX,
        call_y = callY,
        call_z = callZ
    }), {
        ['Content-Type'] = 'application/json'
    })
end)

local function sendChatLines(src, prefix, message)
    local text = tostring(message or "")
    if text == "" then
        sendChat(src, prefix, "")
        return
    end
    for line in text:gmatch("[^\r\n]+") do
        sendChat(src, prefix, line)
    end
end

local function safeJsonDecode(value, fallback)
    if fallback == nil then fallback = {} end
    if type(value) ~= "string" or value == "" then return fallback end
    local ok, decoded = pcall(function()
        return json.decode(value)
    end)
    if not ok or type(decoded) ~= "table" then
        return fallback
    end
    return decoded
end

local function safeUpper(value, fallback)
    return safeStr(value, fallback):upper()
end

-- Strip Julian date format from tag (EWP26004-0019 -> EWP0019)
local function stripJulianDateFromTag(tag)
    if not tag or tag == "" then return tag end
    local str = safeUpper(tag, "")
    -- Match Julian format: EWP26004-0019 -> EWP0019
    local julianMatch = str:match("^([A-Z][A-Z][A-Z])(%d%d%d%d%d)%-(%d%d%d%d)$")
    if julianMatch then
        return julianMatch[1] .. julianMatch[3]
    end
    -- Already in simple format or invalid, return as-is
    return str
end

local function fetchActiveDutyLogs(cb)
    performMdcRequest('/api/logs/active', function(statusCode, body)
        if statusCode ~= 200 or type(body) ~= "string" then
            cb(false, nil)
            return
        end
        local ok, decoded = pcall(function()
            return json.decode(body)
        end)
        if not ok or type(decoded) ~= "table" or decoded.success ~= true or type(decoded.data) ~= "table" then
            cb(false, nil)
            return
        end
        cb(true, decoded.data)
    end, "GET")
end

local function firstChar(value, fallback)
    local str = safeStr(value, fallback)
    if str == "" then return fallback end
    return str:sub(1, 1)
end

local function oxUpdateAwait(query, params)
    local p = promise.new()
    exports.oxmysql:update(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

dbUpdate = function(query, params)
    if MySQL and MySQL.update and MySQL.update.await then
        return MySQL.update.await(query, params)
    end
    if exports.oxmysql then
        return oxUpdateAwait(query, params)
    end
    return nil
end

local function nowDateMMDDYY()
    return os.date("%m/%d/%y")
end

local function nowTime24()
    return os.date("%H:%M")
end

local function formatLogDate(value)
    local str = safeStr(value, "")
    if str == "" then return "UNK" end
    local iso = str:match("^(%d%d%d%d%-%d%d%-%d%d)T")
    if iso then return iso end
    if str:match("^%d%d%d%d%-%d%d%-%d%d$") then return str end
    return str
end

local function formatPERS(personRow)
    local meta = safeJsonDecode(personRow and personRow.metadata, {})

    local last = safeUpper(personRow and personRow.lastname, "UNK")
    local first = safeUpper(personRow and personRow.firstname, "UNK")
    local sex = safeUpper(meta.sex or meta.gender or personRow.gender, "U")
    local race = safeUpper(meta.race or meta.ethnicity, "UNK")
    local raceInitial = firstChar(race, "U")
    local age = safeUpper(meta.age, "UNK")
    local dob = safeStr(personRow and personRow.dob, "NOT ON FILE")

    local height = safeUpper(meta.height, "UNK")
    local weight = safeUpper(meta.weight, "UNK")
    local hair = safeUpper(meta.hair or meta.hair_color, "UNK"):sub(1, 3)
    local eyes = safeUpper(meta.eyes or meta.eye_color, "UNK"):sub(1, 3)

    local addr = safeUpper(meta.address or meta.addr or meta.location, "NOT ON FILE")
    local zip = safeUpper(meta.zip or meta.postal, "UNK")
    local phone = safeUpper(personRow and personRow.phonenumber, "N/A")
    local gang = safeUpper(meta.gang_affiliation or meta.gangAffiliation or meta.gang, "NONE")
    local ssn = safeStr(meta.ssn, "N/A")

    local warrantStatus = "NONE"
    if personRow and personRow._warrant_count and tonumber(personRow._warrant_count) and tonumber(personRow._warrant_count) > 0 then
        warrantStatus = ("ACTIVE(%d)"):format(tonumber(personRow._warrant_count))
    end

    return table.concat({
        ("//PERS RESPONSE//%s//%s///"):format(nowDateMMDDYY(), nowTime24()),
        ("%s,%s//%s/%s/%s//DOB:%s///"):format(last, first, sex, raceInitial, age, dob),
        ("PHY:%s/%s/%s/%s///"):format(height, weight, hair, eyes),
        ("ADDR:%s/%s///"):format(addr, zip),
        ("PH:%s//SSN:%s///"):format(phone, ssn),
        ("//WARRANTS:%s//GANG:%s///"):format(warrantStatus, gang),
        "//END PERS////"
    }, "\n")
end

local function formatVehicleRecord(vehicleRow, ownerRow)
    local ownerMeta = safeJsonDecode(ownerRow and ownerRow.metadata, {})
    local props = safeJsonDecode(vehicleRow and vehicleRow.properties, {})

    local plate = safeUpper(vehicleRow and vehicleRow.plate, "UNK")
    local state = safeUpper(vehicleRow and (vehicleRow.state or ownerMeta.state) or "CA", "CA")
    local vin = safeUpper(vehicleRow and (vehicleRow.vin or props.vin or props.VIN) or nil, "N/A")
    local year = safeUpper(vehicleRow and vehicleRow.vehicle_year or nil, "UNK")
    local make = safeUpper(vehicleRow and vehicleRow.vehicle_make or nil, "UNKNOWN")
    local model = safeUpper(vehicleRow and vehicleRow.vehicle_model or (props.model or props.vehicle or props.make) or nil, "UNKNOWN")
    local color = safeUpper(vehicleRow and vehicleRow.vehicle_color or (props.color or props.primaryColor or props.color1) or nil, "UNK")
    local registration = safeUpper(vehicleRow and vehicleRow.registration or nil, "CURRENT")
    local insurance = safeUpper(vehicleRow and vehicleRow.insurance or nil, "UNKNOWN")
    local status = safeUpper(vehicleRow and vehicleRow.status or nil, "CLEAR")
    local flags = safeUpper(vehicleRow and vehicleRow.flags or nil, "")

    local ownerName = "NOT ON FILE"
    if ownerRow and ownerRow.lastname and ownerRow.firstname then
        ownerName = ("%s,%s"):format(safeUpper(ownerRow.lastname, "UNK"), safeUpper(ownerRow.firstname, "UNK"))
    end

    local addr = safeUpper(ownerMeta.address or ownerMeta.addr or ownerMeta.location, "NOT ON FILE")
    local city = safeUpper(ownerMeta.city, "UNK")

    return table.concat({
        ("//DMV RESPONSE//%s//%s///"):format(nowDateMMDDYY(), nowTime24()),
        ("LIC#:%s  ST:%s"):format(plate, state),
        ("VIN:%s"):format(vin),
        ("YEAR:%s  MAKE:%s"):format(year, make),
        ("VEH:%s  COLOR:%s"):format(model, color),
        ("R/O:%s  ADDR:%s"):format(ownerName, addr),
        ("CITY:%s"):format(city),
        ("STATUS:%s  REG:%s  INS:%s"):format(status, registration, insurance),
        (flags ~= "" and ("FLAGS:%s"):format(flags) or "NO FLAGS ON FILE"),
        "//END DMV////"
    }, "\n")
end

local function normalizeLike(value)
    local str = safeStr(value, "")
    if str == "" then return nil end
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

local function requireMdcAccessOrReply(src)
    if isAllowedMdcUser(src) then return true end
    TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use the MDC.", 4000)
    return false
end

RegisterCommand("want", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local lastName = args and args[1] or nil
    local firstName = args and args[2] or nil
    if not lastName and not firstName then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /want LAST FIRST", 4000)
        return
    end

    local query = [[
        SELECT charid, firstname, lastname, dob, gender, phonenumber, metadata
        FROM nd_characters
        WHERE 1=1
    ]]
    local params = {}

    if normalizeLike(lastName) then
        query = query .. " AND lastname LIKE ?"
        table.insert(params, ("%%%s%%"):format(lastName))
    end
    if normalizeLike(firstName) then
        query = query .. " AND firstname LIKE ?"
        table.insert(params, ("%%%s%%"):format(firstName))
    end
    query = query .. " ORDER BY charid DESC LIMIT 1"

    local result = dbQuery(query, params) or {}
    local row = result and result[1] or nil
    if not row then
        local msg = table.concat({
            ("//PERS RESPONSE//%s//%s///"):format(nowDateMMDDYY(), nowTime24()),
            ("SEARCH: %s, %s//"):format(safeUpper(lastName, "UNK"), safeUpper(firstName, "UNK")),
            "*** NO RECORDS FOUND ***",
            "//END PERS//"
        }, "\n")
        sendChatLines(src, "^2[MDC]^7", msg)
        return
    end

    local warrantCountResult = dbQuery(
        "SELECT COUNT(*) AS count FROM nd_warrants WHERE character_id = ? AND status = 'active'",
        { row.charid }
    )
    row._warrant_count = warrantCountResult and warrantCountResult[1] and warrantCountResult[1].count or 0

    sendChatLines(src, "^2[MDC]^7", formatPERS(row))
end, false)

RegisterCommand("veh", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local plate = args and args[1] or nil
    if not plate then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /veh PLATE", 4000)
        return
    end

    local vehResult = dbQuery(
        "SELECT id, owner, plate, state, vin, vehicle_year, vehicle_make, vehicle_model, vehicle_color, status, flags, registration, insurance, properties FROM nd_vehicles WHERE plate LIKE ? ORDER BY id DESC LIMIT 1",
        { ("%%%s%%"):format(plate) }
    )
    local vehRow = vehResult and vehResult[1] or nil
    if not vehRow then
        local msg = table.concat({
            ("//DMV RESPONSE//%s//%s///"):format(nowDateMMDDYY(), nowTime24()),
            ("LIC#:%s"):format(safeUpper(plate, "UNK")),
            "*** NO VEHICLE RECORD FOUND ***",
            "//END DMV//"
        }, "\n")
        sendChatLines(src, "^2[MDC]^7", msg)
        return
    end

    local ownerRow = nil
    if vehRow.owner then
        local ownerResult = dbQuery(
            "SELECT charid, firstname, lastname, metadata FROM nd_characters WHERE charid = ? LIMIT 1",
            { vehRow.owner }
        )
        ownerRow = ownerResult and ownerResult[1] or nil
    end

    sendChatLines(src, "^2[MDC]^7", formatVehicleRecord(vehRow, ownerRow))
end, false)

RegisterCommand("wi", function(source)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local calls = dbQuery(
        "SELECT id, call_tag, code, location, status, priority, unit, UNIX_TIMESTAMP(created_at) AS created_unix FROM calls ORDER BY created_at DESC LIMIT 50"
    ) or {}

    local waiting = {}
    for _, call in ipairs(calls) do
        -- Only show calls with no unit assigned (regardless of status)
        local hasNoUnit = call.unit == nil or tostring(call.unit) == "" or tostring(call.unit) == "Unassigned" or tostring(call.unit):match("^%s*$")
        if hasNoUnit then
            table.insert(waiting, call)
        end
    end

    local header = ("WAITING INCIDENT STATUS %s   %s"):format(nowDateMMDDYY(), nowTime24())
    if #waiting == 0 then
        sendChatLines(src, "^2[MDC]^7", header .. "\n\nTHERE ARE NO WAITING INCIDENTS")
        return
    end

    local function padRight(str, width)
        str = tostring(str or "")
        if #str >= width then return str:sub(1, width) end
        return str .. string.rep(" ", width - #str)
    end

    local function padLeft(str, width)
        str = tostring(str or "")
        if #str >= width then return str:sub(1, width) end
        return string.rep(" ", width - #str) .. str
    end

    local lines = { header, "" }
    for _, call in ipairs(waiting) do
        local fullTag = safeUpper(call.call_tag or ("UNK" .. tostring(call.id)), "UNK")
        local tag = stripJulianDateFromTag(fullTag) -- Strip Julian date format for display
        local code = safeUpper(call.code, "UNK")
        local waitMinutes = "**"
        local createdUnix = tonumber(call.created_unix)
        if createdUnix then
            local diff = math.floor((os.time() - createdUnix) / 60)
            if diff >= 0 then waitMinutes = tostring(diff) end
        end
        local loc = safeStr(call.location, "UNKNOWN LOCATION")
        -- Remove any format string artifacts
        loc = loc:gsub("%%S", ""):gsub("%%s", ""):gsub("%%(%S+)", ""):gsub("^%s+", ""):gsub("%s+$", "")
        -- Format: Tag, Code, Wait Minutes, Location
        table.insert(lines, ("%s %s %s %s"):format(
            padRight(tag, 18),
            padRight(code, 12),
            padLeft(waitMinutes, 4),
            loc
        ))
    end

    sendChatLines(src, "^2[MDC]^7", table.concat(lines, "\n"))
end, false)

RegisterCommand("ai", function(source)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local calls = dbQuery(
        "SELECT call_tag, code, status, unit FROM calls ORDER BY created_at DESC LIMIT 25"
    ) or {}

    local lines = { "ALL INCIDENTS - LOCAL", "" }
    for _, call in ipairs(calls) do
        local tag = safeUpper(call.call_tag, "UNK")
        local code = safeUpper(call.code, "UNK")
        local status = safeUpper(call.status, "PENDING")
        local unit = safeUpper(call.unit, "UNASSIGNED")
        table.insert(lines, ("%s - %s - %s - %s"):format(tag, code, status, unit))
    end

    sendChatLines(src, "^2[MDC]^7", table.concat(lines, "\n"))
end, false)

local function priorityToLetter(priority)
    local p = tonumber(priority)
    if p == nil then return "R" end
    if p == 1 or p == 0 then return "E" end
    if p == 2 then return "P" end
    if p == 3 then return "R" end
    return "R"
end

local function sendIncidentRecord(src, tagInput, label)
    local tag = safeUpper(tagInput, "")
    if tag == "" then
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Usage: /%s <CALL_TAG>"):format(label), 4000)
        return
    end

    local query = "SELECT id, call_tag, code, location, description, priority, status, unit, created_at FROM calls WHERE UPPER(call_tag) = ?"
    local params = { tag }
    if tag:match("^%a%a%a%d%d%d%d$") then
        local prefix = tag:sub(1, 3)
        local seq = tag:sub(4)
        local likePattern = ("%s_____-%s"):format(prefix, seq)
        query = query .. " OR UPPER(call_tag) LIKE ?"
        table.insert(params, likePattern)
    end
    query = query .. " ORDER BY created_at DESC LIMIT 1"

    local result = dbQuery(query, params) or {}
    local row = result[1]
    if not row then
        sendChatLines(src, "^1[MDC]^7", ("INCIDENT RECORD: %s\nNO INCIDENT FOUND"):format(tag))
        return
    end

    local dateStr = nowDateMMDDYY()
    local timeStr = os.date("%H:%M")
    local timeStrNoColon = os.date("%H%M")
    local units = safeUpper(row.unit, "UNASSIGNED")
    local status = safeUpper(row.status, "ACTIVE")
    local code = safeUpper(row.code, "UNK")
    local loc = safeUpper(row.location, "UNKNOWN LOCATION")
    local remarks = safeUpper(row.description, "NO DETAILS PROVIDED")
    local priorityLetter = priorityToLetter(row.priority)
    local callTag = safeUpper(row.call_tag, tag)

    local body = table.concat({
        ("INCIDENT RECORD    %s    %s"):format(dateStr, timeStr),
        ("%s      %s"):format(callTag, status),
        ("UNITS:  %s"):format(units),
        ("PRIORITY: %s    RADIO CODES: %s"):format(priorityLetter, code),
        ("LOCATION: %s"):format(loc),
        remarks,
        ("/%s W911 %s"):format(timeStrNoColon, callTag)
    }, "\n")

    sendChatLines(src, "^2[MDC]^7", body)
end

RegisterCommand("id", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    sendIncidentRecord(src, args and args[1], "id")
end, false)

RegisterCommand("ir", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    sendIncidentRecord(src, args and args[1], "ir")
end, false)

RegisterCommand("is", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    sendIncidentRecord(src, args and args[1], "is")
end, false)

RegisterCommand("us", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local unit = args and args[1] or nil
    if not unit then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /us <UNIT>", 4000)
        return
    end

    local unitUpper = safeUpper(unit, "UNK")
    local call = (dbQuery(
        "SELECT call_tag, code, location, status FROM calls WHERE unit LIKE ? ORDER BY created_at DESC LIMIT 1",
        { ("%%%s%%"):format(unitUpper) }
    ) or {})[1]

    local status = call and safeUpper(call.status, "ACTIVE") or "AVAILABLE"
    local tag = call and safeUpper(call.call_tag, "NONE") or "NONE"
    local code = call and safeUpper(call.code, "UNK") or "N/A"
    local loc = call and safeUpper(call.location, "STATION") or "STATION"

    local body = table.concat({
        ("UNIT STATUS - %s"):format(unitUpper),
        ("STATUS: %s"):format(status),
        ("CALL: %s  CODE: %s"):format(tag, code),
        ("LOC: %s"):format(loc)
    }, "\n")

    sendChatLines(src, "^2[MDC]^7", body)
end, false)

RegisterCommand("ud", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local unit = args and args[1] or nil
    if not unit then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /ud <UNIT>", 4000)
        return
    end

    fetchActiveDutyLogs(function(ok, logs)
        local row = nil
        if ok and type(logs) == "table" then
            local needle = safeUpper(unit, "")
            for _, log in ipairs(logs) do
                if safeUpper(log.unit, "") == needle then
                    row = log
                    break
                end
            end
        end

        if not row then
            row = (dbQuery(
                "SELECT unit, shift, log_date, time_on, time_off, deputy_1, deputy_2, deputy_3, deputy_4, or_name, vehicle_id, radio_mobile, updated_at FROM duty_logs WHERE unit = ? ORDER BY updated_at DESC LIMIT 1",
                { unit }
            ) or {})[1]
        end

        if not row then
            sendChatLines(src, "^1[MDC]^7", ("UNIT DETAILS: %s\nNO DUTY LOG FOUND"):format(safeUpper(unit, "UNK")))
            return
        end

        local details = table.concat({
            ("UNIT DETAILS %s   %s"):format(nowDateMMDDYY(), nowTime24()),
            ("UNIT: %s  SHIFT: %s  DATE: %s"):format(safeUpper(row.unit, "UNK"), safeUpper(row.shift, "UNK"), formatLogDate(row.log_date)),
            ("TIME ON: %s  TIME OFF: %s"):format(safeUpper(row.time_on, "UNK"), safeUpper(row.time_off, "UNK")),
            ("DEPUTY 1: %s"):format(safeStr(row.deputy_1_username or row.deputy_1, "")),
            ("DEPUTY 2: %s"):format(safeStr(row.deputy_2, "")),
            ("DEPUTY 3: %s"):format(safeStr(row.deputy_3, "")),
            ("DEPUTY 4: %s"):format(safeStr(row.deputy_4, "")),
            ("OR: %s"):format(safeStr(row.or_name, "")),
            ("VEHICLE: %s  RADIO: %s"):format(safeUpper(row.vehicle_id, "UNK"), safeUpper(row.radio_mobile, "UNK"))
        }, "\n")

        sendChatLines(src, "^2[MDC]^7", details)
    end)
end, false)

RegisterCommand("ur", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local filter = args and args[1] or nil

    local rows = {}
    if filter and filter ~= "" then
        rows = dbQuery(
            "SELECT unit, shift, log_date, deputy_1, or_name, vehicle_id FROM duty_logs WHERE unit LIKE ? GROUP BY unit ORDER BY updated_at DESC",
            { ("%%%s%%"):format(filter) }
        ) or {}
    else
        rows = dbQuery(
            "SELECT DISTINCT unit, shift, log_date, deputy_1, or_name, vehicle_id FROM duty_logs GROUP BY unit ORDER BY MAX(updated_at) DESC"
        ) or {}
    end

    local header = ("UNIT ROSTER %s   %s"):format(nowDateMMDDYY(), nowTime24())
    if type(rows) ~= "table" or #rows == 0 then
        sendChatLines(src, "^2[MDC]^7", header .. "\n\nNO ACTIVE UNITS FOUND")
        return
    end

    local lines = { header, "" }
    for _, row in ipairs(rows) do
        table.insert(lines, ("%s  %s  %s  %s  %s"):format(
            safeUpper(row.unit, "UNK"),
            safeUpper(row.shift, "UNK"),
            formatLogDate(row.log_date),
            safeUpper(row.vehicle_id, "UNK"),
            safeUpper(row.deputy_1_username or row.or_name or row.deputy_1, "UNK")
        ))
    end
    sendChatLines(src, "^2[MDC]^7", table.concat(lines, "\n"))
end, false)

RegisterCommand("as", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    local tag = args and args[1] or nil
    if not tag then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /as <CALL_TAG>", 4000)
        return
    end
    sendChatLines(src, "^2[MDC]^7", ("ASSIGNED ASSIST %s\n(Info only) Use the MDC UI to attach units to calls."):format(safeUpper(tag, "UNK")))
end, false)

RegisterCommand("monitor", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    if not args or #args == 0 then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /monitor <UNIT1> [UNIT2 ...]", 4000)
        return
    end
    sendChatLines(src, "^2[MDC]^7", ("MONITORING UNITS: %s\nSTATUS: ACTIVE MONITORING"):format(table.concat(args, ", ")))
end, false)

RegisterCommand("chgc", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    local tag = args and args[1] or nil
    if not tag then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /chgc <CALL_TAG> [NEW_STATUS]", 4000)
        return
    end
    sendChatLines(src, "^2[MDC]^7", ("CHANGE CALL: %s\nSTATUS CHANGE REQUESTED\n(This command is informational in-game.)"):format(safeUpper(tag, "UNK")))
end, false)

RegisterCommand("chgl", function(source, args, raw)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    local unit = args and args[1] or nil
    if not unit then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /chgl <UNIT>", 4000)
        return
    end
    sendChatLines(src, "^2[MDC]^7", ("CHANGE LOG: %s\n%s - %s LOG UPDATED\nSTATUS: LOG UPDATED"):format(safeUpper(unit, "UNK"), nowTime24(), safeUpper(unit, "UNK")))
end, false)

RegisterCommand("chgo", function(source, args)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    local tag = args and args[1] or nil
    if not tag then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /chgo <CALL_TAG>", 4000)
        return
    end
    sendChatLines(src, "^2[MDC]^7", ("CHANGE OBS: %s\n(Info only) Active-call selection is handled in the MDC UI."):format(safeUpper(tag, "UNK")))
end, false)

RegisterCommand("upd", function(source, args, rawCommand)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end

    local tag = args and args[1] or nil
    if not tag then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /upd <CALL_TAG> <remarks...>", 4000)
        return
    end

    local remarks = ""
    if rawCommand and rawCommand ~= "" then
        remarks = rawCommand:gsub("^/upd%s+", ""):gsub("^%S+%s*", "")
    end
    remarks = safeStr(remarks, "")
    if remarks == "" then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /upd <CALL_TAG> <remarks...>", 4000)
        return
    end

    local normalizedTag = safeUpper(tag, "")
    local rows = dbQuery("SELECT id, description FROM calls WHERE UPPER(call_tag) = ? ORDER BY created_at DESC LIMIT 1", { normalizedTag }) or {}
    local row = rows[1]
    if not row then
        sendChatLines(src, "^1[MDC]^7", ("UPD ERROR\nCall with tag %s not found"):format(normalizedTag))
        return
    end

    local stamp = os.date("%m/%d/%y %H%M")
    local appended = ("%s\n/%s %s"):format(safeStr(row.description, ""), stamp, remarks)
    dbUpdate("UPDATE calls SET description = ?, updated_at = NOW() WHERE id = ?", { appended, row.id })

    sendChatLines(src, "^2[MDC]^7", ("UPDATED CALL %s\nRMK %s"):format(normalizedTag, safeUpper(remarks, "")))
end, false)

RegisterCommand("clrindex", function(source)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    sendChatLines(src, "^2[MDC]^7", "DISPATCH INDEX CLEARED (web UI only).")
end, false)

RegisterCommand("restart", function(source)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    sendChatLines(src, "^2[MDC]^7", "RESTART is restricted to the web MDC admin panel.")
end, false)

RegisterCommand("mdchelp", function(source)
    local src = source
    if src == 0 then return end
    if not requireMdcAccessOrReply(src) then return end
    local helpText = table.concat({
        "AVAILABLE MDC CHAT COMMANDS:",
        "/mdc, /obs",
        "/want, /veh",
        "/us, /is, /ai",
        "/id, /ir, /ud, /ur, /wi",
        "/as, /monitor",
        "/chgc, /chgl, /chgo, /upd",
        "/clrindex, /restart",
        "/mdcall, /ewpall"
    }, "\n")
    sendChatLines(src, "^2[MDC]^7", helpText)
end, false)

local function getSenderUnit(src)
    local unit = getUnitFromState and getUnitFromState(src) or nil
    if unit and unit ~= "" then return tostring(unit):upper() end
    return safeUpper(GetPlayerName(src), "UNKNOWN")
end

local function broadcastMessage(src, mode, messageText)
    if not requireMdcAccessOrReply(src) then return end

    local trimmed = safeStr(messageText, "")
    if trimmed == "" then
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Usage: /%s <message...>"):format(mode), 4000)
        return
    end

    local where = "last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE)"
    if mode == "ewpall" then
        where = where .. " AND unit_num LIKE '19%%'"
    end

    local recipients = dbQuery(("SELECT DISTINCT unit_num FROM user_presence WHERE %s"):format(where)) or {}
    if #recipients == 0 then
        TriggerClientEvent("tcp_notify:show", src, ("MDC: No recipients online for %s."):format(mode:upper()), 4000)
        return
    end

    local fromUnit = getSenderUnit(src)
    local inserted = 0
    for _, row in ipairs(recipients) do
        local toUnit = safeStr(row.unit_num, "")
        if toUnit ~= "" then
            local ok = dbInsert(
                "INSERT INTO officer_messages (from_unit, to_unit, message) VALUES (?, ?, ?)",
                { fromUnit, toUnit, trimmed }
            )
            if ok then inserted = inserted + 1 end
        end
    end

    TriggerClientEvent("tcp_notify:show", src, ("MDC: %s sent to %d unit(s)."):format(mode:upper(), inserted), 4000)
end

RegisterCommand("mdcall", function(source, args, rawCommand)
    local src = source
    if src == 0 then return end
    local messageText = rawCommand and rawCommand:gsub("^/mdcall%s*", "") or ""
    broadcastMessage(src, "mdcall", messageText)
end, false)

RegisterCommand("ewpall", function(source, args, rawCommand)
    local src = source
    if src == 0 then return end
    local messageText = rawCommand and rawCommand:gsub("^/ewpall%s*", "") or ""
    broadcastMessage(src, "ewpall", messageText)
end, false)

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

dbQuery = function(query, params)
    if MySQL and MySQL.query and MySQL.query.await then
        return MySQL.query.await(query, params)
    end
    if exports.oxmysql then
        return oxQueryAwait(query, params)
    end
    return nil
end

-- Check if player has submitted worksheet today (must be after dbQuery is defined)
RegisterNetEvent("ZestyyMDC:CheckWorksheetStatus")
AddEventHandler("ZestyyMDC:CheckWorksheetStatus", function()
    local src = source
    local unit = getUnitFromState and getUnitFromState(src) or nil

    if not unit or unit == "" then
        local player = Player(src)
        local currentState = player and player.state and player.state.onduty or false
        -- Never set false if they're already on-duty (latch handled client-side)
        if not currentState then
            TriggerClientEvent("ZestyyMDC:SetOnduty", src, false)
        end
        return
    end

    local today = os.date("%Y-%m-%d")
    local result = dbQuery(
        "SELECT id FROM duty_logs WHERE UPPER(TRIM(unit)) = ? AND log_date = ? LIMIT 1",
        { unit, today }
    )

    local hasWorksheet = result and #result > 0 and result[1] ~= nil
    TriggerClientEvent("ZestyyMDC:SetOnduty", src, hasWorksheet)
end)

dbInsert = function(query, params)
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

getUnitFromState = function(src)
    local player = Player(src)
    if not player then return nil end
    local unit = player.state and player.state.unitid or nil
    if unit == nil or unit == "" then return nil end
    local normalized = tostring(unit):gsub("^%s+", ""):gsub("%s+$", ""):upper()
    if normalized == "" then return nil end
    return normalized
end

RegisterCommand("booking", function(source, args)
    local src = source
    if src == 0 then return end
    if not isAllowedMdcUser(src) then
        TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use MDC booking.", 4000)
        return
    end
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
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /booking LAST FIRST LOCATION", 4000)
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
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Booking saved (ID %s)"):format(insertId), 4000)
    else
        TriggerClientEvent("tcp_notify:show", src, "MDC: Booking save failed.", 4000)
    end
end, false)

RegisterCommand("cleartag", function(source, args, rawCommand)
    local src = source
    if src == 0 then return end
    if not isAllowedMdcUser(src) then
        TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use MDC clear tags.", 4000)
        return
    end
    local options, positionals = splitArgs(args)

    local tagNumber = options.tag or options.tag_number or positionals[1]
    local callTag = options.call or options.calltag or positionals[2]
    local unit = options.unit or options.u or positionals[3] or getUnitFromState(src)
    local remarks = options.nar or options.remarks or options.rmk
    local raw = rawCommand and rawCommand:gsub("^/cleartag%s*", "") or ""

    if not tagNumber and not callTag and not unit then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /cleartag tag=TAG call=CALL unit=UNIT nar=REMARKS", 4000)
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
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Clear tag saved (ID %s)"):format(insertId), 4000)
    else
        TriggerClientEvent("tcp_notify:show", src, "MDC: Clear tag save failed.", 4000)
    end
end, false)

RegisterCommand("gun", function(source, args)
    local src = source
    if src == 0 then return end
    if not isAllowedMdcUser(src) then
        TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use MDC gun records.", 4000)
        return
    end
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
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /gun SERIAL", 4000)
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
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Gun record saved (ID %s)"):format(insertId), 4000)
    else
        TriggerClientEvent("tcp_notify:show", src, "MDC: Gun record save failed.", 4000)
    end
end, false)

-- Auto-sync weapons from ox_inventory to nd_guns table
AddEventHandler('ox_inventory:weaponCreated', function(weaponData)
    if not weaponData or not weaponData.serial then return end
    
    local serial = weaponData.serial
    local weaponName = weaponData.weapon or 'UNKNOWN'
    local owner = weaponData.owner or 'UNKNOWN'
    local metadata = weaponData.metadata or {}
    
    -- Extract weapon type info from weapon name
    local cleanedWeaponName = tostring(weaponName):gsub("^WEAPON_", ""):gsub("_", " ")
    local make, weaponType, category = cleanedWeaponName, 'UNKNOWN', 'UNKNOWN'
    
    if weaponName:find('GLOCK') then
        make = 'GLOCK'
        weaponType = 'PISTOL'
        category = 'HANDGUN'
    elseif weaponName:find('M4') or weaponName:find('AR15') or weaponName:find('CARBINE') then
        make = 'COLT'
        weaponType = 'RIFLE'
        category = 'ASSAULT'
    elseif weaponName:find('SHOTGUN') or weaponName:find('M870') then
        make = 'REMINGTON'
        weaponType = 'SHOTGUN'
        category = 'PUMP'
    elseif weaponName:find('PISTOL') then
        weaponType = 'PISTOL'
        category = 'HANDGUN'
    elseif weaponName:find('RIFLE') then
        weaponType = 'RIFLE'
        category = 'ASSAULT'
    elseif weaponName:find('SMG') or weaponName:find('MP') then
        weaponType = 'SMG'
        category = 'AUTOMATIC'
    elseif weaponName:find('SNIPER') then
        weaponType = 'RIFLE'
        category = 'SNIPER'
    elseif weaponName:find('TASER') or weaponName:find('STUNGUN') then
        weaponType = 'TASER'
        category = 'LESS-LETHAL'
    end
    
    -- Determine caliber based on weapon
    local caliber = 'UNK'
    if weaponName:find('GLOCK17') or weaponName:find('MP5') then
        caliber = '9MM'
    elseif weaponName:find('GLOCK22') or weaponName:find('PISTOL') then
        caliber = '.40'
    elseif weaponName:find('1911') or weaponName:find('FNX45') then
        caliber = '.45'
    elseif weaponName:find('M4') or weaponName:find('AR15') or weaponName:find('HK416') then
        caliber = '5.56MM'
    elseif weaponName:find('SHOTGUN') or weaponName:find('M870') then
        caliber = '12GA'
    elseif weaponName:find('SNIPER') then
        caliber = '.308'
    end
    
    -- Set document code based on serial prefix
    local documentCode = 'CIV'
    if serial:sub(1,2) == 'LA' then
        documentCode = 'LASD'
    elseif serial:sub(1,2) == 'PO' then
        documentCode = 'POL'
    end
    
    -- Get owner character ID if possible
    local ownerId = nil
    local src = tonumber(weaponData.playerId)
    if src and GetPlayerName(src) then
        local active = getActiveCharacter(src)
        if active then
            ownerId = active.id
            owner = ("%s %s"):format(active.firstname or "", active.lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")
        end
    end

    if not ownerId then
        local ownerRefId = tonumber(weaponData.ownerRef)
        if ownerRefId then
            local row = dbQuery(
                "SELECT charid, firstname, lastname FROM nd_characters WHERE charid = ? LIMIT 1",
                { ownerRefId }
            )
            if row and row[1] then
                ownerId = row[1].charid
                owner = ("%s %s"):format(row[1].firstname or "", row[1].lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
    end

    if not ownerId and owner and owner ~= "UNKNOWN" then
        local first, last = tostring(owner):match("^(%S+)%s+(%S+)$")
        if first and last then
            local row = dbQuery(
                "SELECT charid, firstname, lastname FROM nd_characters WHERE firstname = ? AND lastname = ? LIMIT 1",
                { first, last }
            )
            if row and row[1] then
                ownerId = row[1].charid
                owner = ("%s %s"):format(row[1].firstname or "", row[1].lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
    end
    
    -- Insert into nd_guns table
    local insertId = dbInsert(
        "INSERT INTO nd_guns (serial, type, category, make, caliber, document_code, owner_character_id, owner_name, stolen) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        { serial, weaponType, category, make, caliber, documentCode, ownerId, owner, 0 }
    )
    
    if insertId then
        print(("[MDC] Auto-registered weapon: %s (%s) to %s"):format(serial, weaponName, owner))
    else
        print(("[MDC] Failed to auto-register weapon: %s"):format(serial))
    end
end)

RegisterCommand("bike", function(source, args)
    local src = source
    if src == 0 then return end
    if not isAllowedMdcUser(src) then
        TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use MDC bike records.", 4000)
        return
    end
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
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /bike SERIAL OAN BRAND", 4000)
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
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Bike record saved (ID %s)"):format(insertId), 4000)
    else
        TriggerClientEvent("tcp_notify:show", src, "MDC: Bike record save failed.", 4000)
    end
end, false)

RegisterCommand("boat", function(source, args)
    local src = source
    if src == 0 then return end
    if not isAllowedMdcUser(src) then
        TriggerClientEvent("tcp_notify:show", src, "MDC: You are not authorized to use MDC boat records.", 4000)
        return
    end
    local options, positionals = splitArgs(args)

    local registrationNumber = options.reg or options.registration or positionals[1]
    local registrationState = options.state
    local hullNumber = options.hull or positionals[2]
    local oan = options.oan or positionals[3]
    local engineNumber = options.engine or positionals[4]
    local stolen = options.stolen == "1" or options.stolen == "true"

    if not registrationNumber and not hullNumber and not oan then
        TriggerClientEvent("tcp_notify:show", src, "MDC: Usage: /boat REG HULL OAN", 4000)
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
        TriggerClientEvent("tcp_notify:show", src, ("MDC: Boat record saved (ID %s)"):format(insertId), 4000)
    else
        TriggerClientEvent("tcp_notify:show", src, "MDC: Boat record save failed.", 4000)
    end
end, false)

-- ============================================================
-- SCC AUTO-DISPATCH
-- Creates MDC calls + SCC radio broadcasts for in-game events.
-- ============================================================

local SCC_MDC_URL  = "http://127.0.0.1:3002/api/calls/create"
local SCC_STATION  = "EWP"

-- Per-event cooldowns to prevent spam (key = zone hash or player, value = os.time())
local autoDispatchCooldowns = {}
local AUTO_DISPATCH_COOLDOWN_SEC = 90

local function isOnCooldown(key)
    local last = autoDispatchCooldowns[key] or 0
    return (os.time() - last) < AUTO_DISPATCH_COOLDOWN_SEC
end

local function setCooldown(key)
    autoDispatchCooldowns[key] = os.time()
end

-- Derive spoken tag from full tag string e.g. "EWP0092" -> "Nine Two"
local digitWords = {"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"}
local function spokenTag(tag)
    local digits = tostring(tag or ""):match("%d+$") or ""
    digits = digits:gsub("^0+", "") -- strip leading zeros
    if digits == "" then return tag end
    local words = {}
    for i = 1, #digits do
        local d = tonumber(digits:sub(i,i)) or 0
        table.insert(words, digitWords[d+1])
    end
    return table.concat(words, " ")
end

local function pick(t) return t[math.random(#t)] end

-- Phrase pools keyed by call type
local SCC_PHRASES = {
    -- 927H = 9-1-1 hang-up / caller (NOT "911" — 911 is not an LASD code)
    ["927H"] = {
        openings = {
            "Attention East LA Units,",
            "East LA Units,",
            "Attention units,",
        },
        templates = {
            "{opening} Nine Twenty Seven Henry at {loc}. {remarks} {tag} Do I have a unit to take the handle?",
            "{opening} Nine Twenty Seven Henry, {loc}. Caller reports {remarks} {tag} Is there a unit available?",
            "{opening} Nine Twenty Seven Henry in the area of {loc}. {remarks} {tag} Unit to respond?",
            "{opening} we have a Nine Twenty Seven Henry, {loc}. {remarks} {tag} Do I have a unit?",
        },
    },
    ["187"] = {
        openings = {
            "Attention East LA Units,",
            "East LA Units,",
        },
        templates = {
            "{opening} Code 3 response needed. One Eight Seven, {loc}. {remarks} {tag} Is there a unit to respond?",
            "{opening} One Eight Seven at {loc}. {remarks} {tag} Do I have a unit to take the handle?",
            "{opening} shots fired, person down. {loc}. {remarks} {tag} Code 3, unit to respond?",
            "{opening} Code 3. One Eight Seven in progress at {loc}. {remarks} {tag} Is there a unit?",
        },
    },
    ["415"] = {
        openings = {
            "Attention East LA Units,",
            "East LA Units,",
            "Attention units,",
        },
        templates = {
            "{opening} Four Fifteen, shots fired at {loc}. {remarks} {tag} Is there a unit to respond?",
            "{opening} Code 2, shots fired. {loc}. {remarks} {tag} Do I have a unit?",
            "{opening} Four Fifteen in the area of {loc}. {remarks} {tag} Unit to respond?",
            "{opening} shots fired reported, {loc}. {remarks} {tag} Is there a unit available?",
        },
    },
    ["TC"] = {
        openings = { "Attention East LA Units,", "East LA Units," },
        templates = {
            "{opening} traffic collision at {loc}. {remarks} {tag} Is there a unit to respond?",
            "{opening} Code 2, {loc}. {remarks} {tag} Do I have a unit?",
        },
    },
    ["902T"] = {
        openings = { "Attention East LA Units,", "East LA Units,", "Attention units," },
        templates = {
            "{opening} Nine Oh Two Tom at {loc}. {remarks} {tag} Is there a unit to respond?",
            "{opening} Code 2, Nine Oh Two Tom. {loc}. {remarks} {tag} Do I have a unit to take the handle?",
            "{opening} traffic collision, {loc}. {remarks} {tag} Nine Oh Two Tom. Unit to respond?",
            "{opening} Nine Oh Two Tom reported at {loc}. {remarks} {tag} Is there a unit available?",
        },
    },
    ["417S"] = {
        openings = { "Attention East LA Units,", "East LA Units,", "Attention units," },
        templates = {
            "{opening} Four Seventeen Sam at {loc}. {remarks} {tag} Is there a unit to respond?",
            "{opening} Code 2, Four Seventeen Sam. {loc}. {remarks} {tag} Do I have a unit?",
            "{opening} shots fired in the area of {loc}. Four Seventeen Sam. {remarks} {tag} Unit to respond?",
            "{opening} Four Seventeen Sam reported, {loc}. {remarks} {tag} Is there a unit available?",
        },
    },
    -- fallback for any other code
    ["DEFAULT"] = {
        openings = {
            "Attention East LA Units,",
            "East LA Units,",
        },
        templates = {
            "{opening} Code {priority} response needed. {code} at {loc}. {remarks} {tag} Is there a unit to respond?",
            "{opening} {code}, {loc}. {remarks} {tag} Do I have a unit to take the handle?",
            "{opening} Code {priority}, {code} in progress at {loc}. {remarks} {tag} Unit to respond?",
        },
    },
}

local function buildAutoPhrase(opts, tag)
    local code    = tostring(opts.code or ""):upper()
    local pool    = SCC_PHRASES[code] or SCC_PHRASES["DEFAULT"]
    local opening = pick(pool.openings)
    local tmpl    = pick(pool.templates)
    local loc     = tostring(opts.location or "unknown location")
    local remarks = tostring(opts.spoken_remarks or "")
    local tagStr  = tag and ("Tag is %s."):format(spokenTag(tag)) or ""
    local priority= tostring(opts.priority or 2)
    -- prefer explicit spoken_code, then look up from codes.lua reference, then raw code
    local spCode  = opts.spoken_code or getSpokenCode(code)

    local phrase = tmpl
        :gsub("{opening}",  opening)
        :gsub("{loc}",      loc)
        :gsub("{remarks}",  remarks)
        :gsub("{tag}",      tagStr)
        :gsub("{priority}", priority)
        :gsub("{code}",     spCode)

    phrase = phrase:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return phrase
end

-- Create MDC call and broadcast over SCC radio
local function autoDispatch(opts)
    local body = json.encode({
        title          = opts.title or opts.code,
        code           = opts.code,
        location       = opts.location or "UNKNOWN LOCATION",
        description    = opts.description or "",
        priority       = opts.priority or 2,
        status         = "PENDING",
        call_type      = "AUTO",
        station_prefix = SCC_STATION,
        call_x         = opts.call_x,
        call_y         = opts.call_y,
        call_z         = opts.call_z
    })

    PerformHttpRequest(SCC_MDC_URL, function(status, response)
        local tag = nil
        local callId = nil
        if status and status >= 200 and status < 300 then
            local decoded = nil
            pcall(function() decoded = json.decode(response) end)
            tag    = decoded and (decoded.call_tag or (decoded.call and decoded.call.call_tag))
            callId = decoded and (decoded.call_id  or (decoded.call and decoded.call.id))
        end

        if tag and callId then
            local priorityLabel = opts.priority == 1 and "E" or opts.priority == 2 and "P" or "R"
            local loc     = opts.location or "UNKNOWN"
            local remarks = tostring(opts.description or "")
            local line    = ("^3[%s] [%s] ^7%s^5 | Tag: %s"):format(opts.code, priorityLabel, loc, tag)
            if remarks ~= "" then
                line = line .. (" ^0— %s"):format(remarks)
            end
            TriggerClientEvent("chat:addMessage", -1, {
                color     = { 255, 60, 60 },
                multiline = true,
                args      = { "^1SCC", line }
            })
            TriggerClientEvent("ZestyyMDC:PlayDispatchAnim", -1)
        end
    end, "POST", body, { ["Content-Type"] = "application/json" })
end

-- Hook: 927H (9-1-1 hang-up / caller) → SCC radio announcement
-- MDC call is already created by tcp_core; we just broadcast it.
AddEventHandler("scc:911Created", function(caller, location, message, coords)
    local pool    = SCC_PHRASES["927H"]
    local opening = pick(pool.openings)
    local tmpl    = pick(pool.templates)
    local loc     = tostring(location or "unknown location")
    local remarks = tostring(message or "")

    local line = ("^3[927H] [E] ^7%s^5 | 911 Call"):format(loc)
    if remarks ~= "" then
        line = line .. (" ^0— %s"):format(remarks)
    end
    if caller ~= "" then
        line = line .. (" ^8(Caller: %s)"):format(caller)
    end
    TriggerClientEvent("chat:addMessage", -1, {
        color     = { 255, 60, 60 },
        multiline = true,
        args      = { "^1SCC", line }
    })
    TriggerClientEvent("ZestyyMDC:PlayDispatchAnim", -1)
end)

-- Hook: player killed by another player → 187 call
AddEventHandler("playerDropped", function() end) -- ensure handler table exists

RegisterNetEvent("scc:playerKilled")
AddEventHandler("scc:playerKilled", function(killerSrc, weaponHash, coords)
    local src = source
    local key = ("kill_%d"):format(src)
    if isOnCooldown(key) then return end
    setCooldown(key)

    local location = "Unknown Location"
    if coords and coords.x then
        local ok2, street, cross = pcall(function()
            return GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        end)
        if ok2 and street then
            location = street
        end
    end

    autoDispatch({
        title          = "187",
        code           = "187",
        location       = location,
        description    = "Person down. PvP event.",
        priority       = 1,
        spoken_remarks = "Person down.",
        call_x         = coords and coords.x,
        call_y         = coords and coords.y,
        call_z         = coords and coords.z
    })
end)

-- Hook: vehicle crash reported from client
RegisterNetEvent("scc:vehicleCrash")
AddEventHandler("scc:vehicleCrash", function(coords, speed)
    local src = source
    local key = ("crash_%d"):format(src)
    if isOnCooldown(key) then return end
    setCooldown(key)

    local location = "Unknown Location"
    if coords and coords.x then
        local ok2, street = pcall(function()
            return GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        end)
        if ok2 and street then location = street end
    end

    autoDispatch({
        title          = "902T",
        code           = "902T",
        location       = location,
        description    = ("Traffic collision. Speed approx %d mph."):format(math.floor(speed or 0)),
        priority       = 2,
        spoken_remarks = "Possible injuries.",
        call_x         = coords and coords.x,
        call_y         = coords and coords.y,
        call_z         = coords and coords.z
    })
end)

-- Hook: shots fired area (client detects nearby gunfire, server dedupes by zone)
RegisterNetEvent("scc:shotsFired")
AddEventHandler("scc:shotsFired", function(coords)
    local src = source
    -- zone key: bucket coords to ~100m grid to avoid spam per area
    local zx = math.floor((coords and coords.x or 0) / 100)
    local zy = math.floor((coords and coords.y or 0) / 100)
    local key = ("shots_%d_%d"):format(zx, zy)
    if isOnCooldown(key) then return end
    setCooldown(key)

    local location = "Unknown Location"
    if coords and coords.x then
        local ok2, street = pcall(function()
            return GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        end)
        if ok2 and street then location = street end
    end

    autoDispatch({
        title          = "417S",
        code           = "417S",
        location       = location,
        description    = "Shots fired reported in the area.",
        priority       = 2,
        spoken_remarks = "Unknown suspects.",
        call_x         = coords and coords.x,
        call_y         = coords and coords.y,
        call_z         = coords and coords.z
    })
end)

-- Dev test commands — trigger auto-dispatch events manually
-- Usage in FiveM console or chat: /testdispatch 417S | 902T | 187 | 927H
RegisterCommand("testdispatch", function(source, args)
    local src = source
    if src ~= 0 and not IsPlayerAceAllowed(tostring(src), "command.testdispatch") then
        if src ~= 0 then TriggerClientEvent("tcp_notify:show", src, "Not authorized.", 3000) end
        return
    end
    local code = (args[1] or "417S"):upper()
    local coords = { x = -33.5, y = -1450.2, z = 30.7 } -- test coords near Compton Blvd

    if code == "927H" then
        TriggerEvent("scc:911Created", "Test Caller", "Compton Boulevard and Willowbrook Avenue", "disturbance in progress", coords)
    elseif code == "187" then
        TriggerEvent("scc:playerKilled", 0, 0, coords)
    elseif code == "902T" then
        TriggerEvent("scc:vehicleCrash", coords, 65)
    elseif code == "417S" then
        TriggerEvent("scc:shotsFired", coords)
    else
        print("[testdispatch] Unknown code. Use: 927H | 187 | 902T | 417S")
    end
end, true)

local lastBlipPayloadJson = nil
local lastEmptySentAt = 0
local lastBlipSentAt = 0
local blipResendIntervalSec = 15

CreateThread(function()
    while true do
        performMdcRequest('/api/calls?limit=200', function(statusCode, response, headers)
            if statusCode ~= 200 then return end
            local decoded = nil
            pcall(function() decoded = json.decode(response) end)
            if not decoded or not decoded.success or type(decoded.calls) ~= "table" then return end

            local payload = {}
            for _, call in ipairs(decoded.calls) do
                local status = tostring(call.status or ""):upper()
                local x = tonumber(call.call_x)
                local y = tonumber(call.call_y)
                local z = tonumber(call.call_z)
                if status ~= 'CLOSED' and x and y and z then
                    table.insert(payload, {
                        id = call.id,
                        call_tag = call.call_tag,
                        code = call.code,
                        created_at = call.created_at,
                        call_x = x,
                        call_y = y,
                        call_z = z
                    })
                end
            end

            local payloadJson = json.encode(payload)
            local now = os.time()
            local shouldResend = (now - lastBlipSentAt) >= blipResendIntervalSec
            if payloadJson == lastBlipPayloadJson and not shouldResend then
                return
            end

            if #payload == 0 then
                if now - lastEmptySentAt < 30 then
                    return
                end
                lastEmptySentAt = now
            end

            lastBlipPayloadJson = payloadJson
            lastBlipSentAt = now
            TriggerClientEvent("ZestyyMDC:UpdateCallBlips", -1, payload)
        end, 'GET')
        Wait(5000)
    end
end)

-- Automatically sync worksheet status for all players every 30 seconds
CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds
        
        local today = os.date("%Y-%m-%d")
        local players = GetPlayers()
        
        for _, playerId in ipairs(players) do
            local src = tonumber(playerId)
            if src then
                local unit = getUnitFromState and getUnitFromState(src) or nil
                
                if unit and unit ~= "" then
                    -- Check if worksheet exists for today
                    local result = dbQuery(
                        "SELECT id FROM duty_logs WHERE UPPER(TRIM(unit)) = ? AND log_date = ? LIMIT 1",
                        { unit, today }
                    )
                    
                    local hasWorksheet = result and #result > 0 and result[1] ~= nil
                    local currentState = Player(src).state.onduty

                    -- Only update if state changed to avoid spam
                    if hasWorksheet and not currentState then
                        TriggerClientEvent("ZestyyMDC:SetOnduty", src, true)
                        TriggerClientEvent("tcp_notify:show", src, "MDC: Worksheet detected! You are now on-duty.", 5000)
                    elseif not hasWorksheet and currentState then
                        TriggerClientEvent("ZestyyMDC:SetOnduty", src, false)
                    end
                end
            end
        end
    end
end)

-- Manual command to force sync (optional for troubleshooting)
RegisterCommand("syncworksheet", function(source, args, rawCommand)
    local src = source
    if src == 0 then return end
    
    local unit = getUnitFromState and getUnitFromState(src) or nil
    
    if not unit or unit == "" then
        TriggerClientEvent("tcp_notify:show", src, "MDC: No unit set. Please set your unit first.", 4000)
        return
    end
    
    -- Check if worksheet exists for today
    local today = os.date("%Y-%m-%d")
    local result = dbQuery(
        "SELECT id FROM duty_logs WHERE UPPER(TRIM(unit)) = ? AND log_date = ? LIMIT 1",
        { unit, today }
    )
    
    local hasWorksheet = result and #result > 0 and result[1] ~= nil
    
    if hasWorksheet then
        TriggerClientEvent("ZestyyMDC:SetOnduty", src, true)
        TriggerClientEvent("tcp_notify:show", src, "MDC: Worksheet synced! You are now on-duty.", 5000)
    else
        TriggerClientEvent("ZestyyMDC:SetOnduty", src, false)
        TriggerClientEvent("tcp_notify:show", src, "MDC: No worksheet found for today. Submit a worksheet to go on-duty.", 5000)
    end
end, false)
