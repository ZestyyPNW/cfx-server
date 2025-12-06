-- LASD MDC Auto Call Sync
-- Synchronizes ImperialCAD calls to the LASD web MDC via MySQL

-- Cache for active units (refreshed periodically)
local activeUnits = {}
local lastUnitRefresh = 0
local UNIT_REFRESH_INTERVAL = 30000 -- Refresh every 30 seconds

-- Helper function to generate LASD call ID format
local function generateLASDCallId(imperialCallNum)
    return "CPT" .. tostring(imperialCallNum)
end

-- Get active units from LEOClock
local function getActiveUnits()
    -- Return cached units if recent
    if (GetGameTimer() - lastUnitRefresh) < UNIT_REFRESH_INTERVAL and #activeUnits > 0 then
        return activeUnits
    end

    -- Query LEOClock for active units
    local units = {}
    local activeUnitsTable = exports['SCRP_LEOClock']:GetActiveUnits() or {}

    -- activeUnits is indexed by base callsign, each has primary/partner officers
    for baseCallsign, unit in pairs(activeUnitsTable) do
        -- Add primary officer's callsign
        if unit.primary and unit.primary.callsign then
            table.insert(units, unit.primary.callsign)
        end

        -- Add partner officer's callsign if present
        if unit.partner and unit.partner.callsign then
            table.insert(units, unit.partner.callsign)
        end
    end

    activeUnits = units
    lastUnitRefresh = GetGameTimer()

    if Config.Debug then
        print(string.format("^3[MDC-SYNC]^7 Refreshed active units: %d units on duty", #units))
    end

    return units
end

-- Helper function to get current date/time in LASD format
local function getCurrentDateTime()
    local timestamp = os.date("*t")
    local date = string.format("%04d-%02d-%02d", timestamp.year, timestamp.month, timestamp.day)
    local time = string.format("%02d:%02d", timestamp.hour, timestamp.min)
    return date, time
end

-- Helper function to format units for LASD
local function formatUnits(unitsList)
    if not unitsList or #unitsList == 0 then
        return "NONE", "NONE"
    end
    local indexFormat = table.concat(unitsList, " ")
    local detailFormat = table.concat(unitsList, ", ")
    return indexFormat, detailFormat
end

-- Helper function to determine radio code from call nature
local function getRadioCode(nature, priority)
    if not nature then return "11-99" end
    if Config.RadioCodes[nature] then return Config.RadioCodes[nature] end
    nature = string.upper(nature)
    for key, code in pairs(Config.RadioCodes) do
        if string.find(nature, string.upper(key)) then return code end
    end
    return "11-99"
end

-- Main conversion function
local function convertToLASDFormat(imperialCall)
    if Config.Debug then
        print("^3[MDC-SYNC]^7 Converting ImperialCAD call to LASD format...")
    end

    local currentDate, currentTime = getCurrentDateTime()
    local callId = generateLASDCallId(imperialCall.callnum or math.random(1000, 9999))
    local radioCodes = getRadioCode(imperialCall.nature, imperialCall.priority)
    local status = Config.StatusMap[imperialCall.status] or "(D)"
    local priority = Config.PriorityMap[imperialCall.priority or 3] or "PRIORITY 3"

    local location = string.format("%s, %s",
        imperialCall.street or "UNKNOWN LOCATION",
        string.upper(imperialCall.city or "LOS ANGELES")
    )
    if imperialCall.crossStreet and imperialCall.crossStreet ~= "" then
        location = string.format("%s / %s, %s",
            imperialCall.street, imperialCall.crossStreet,
            string.upper(imperialCall.city or "LOS ANGELES")
        )
    end

    -- Get units: use provided units, or pull active units from LEOClock if none provided
    local units = imperialCall.units
    if not units or #units == 0 then
        -- No units assigned yet - get active units from LEOClock
        units = getActiveUnits()
        if Config.Debug then
            print(string.format("^3[MDC-SYNC]^7 Auto-assigned %d active units to call", #units))
        end
    end

    local unitIndexFormat, unitDetailFormat = formatUnits(units)
    local callerName = imperialCall.name or "ANONYMOUS"
    local phoneNumber = imperialCall.phone or "(000) 000-0000"
    local description = string.upper(imperialCall.info or "NO DETAILS PROVIDED")

    local lasdFormat = {
        time = currentTime,
        tag = callId,
        code = radioCodes,
        status = status,
        units = unitIndexFormat,
        detailLines = {
            string.format("%s  %s", callId, radioCodes),
            string.format("%s %s", status, unitIndexFormat),
            location,
            string.format("RMK %s", description)
        },
        messageText = string.format([[INCIDENT RECORD %s    %s
%s-A   %s
UNITS:  %s
PRIORITY: %s   RADIO CODES: %s
LOCATION: %s
INF: %s, %s
RMK %s
/%s W911 CPT%02d]],
            currentDate, currentTime, callId, status, unitDetailFormat,
            priority, radioCodes, location, callerName, phoneNumber,
            description, currentTime, math.random(1, 3)
        ),
        sonoranCallId = imperialCall.callId,
        isAttached = false,
        priority = imperialCall.priority or 3,
        postal = imperialCall.postal
    }

    if Config.Debug then
        print("^2[MDC-SYNC]^7 Converted successfully: " .. callId)
    end

    return lasdFormat
end

-- Function to send call via MySQL queue
local function sendCallToMDC(lasdCall)
    if Config.Debug then
        print("^3[MDC-SYNC]^7 Queuing call in database...")
    end

    local callJson = json.encode(lasdCall)

    exports.oxmysql:insert('INSERT INTO mdc_call_queue (call_data) VALUES (?)', {callJson}, function(insertId)
        if insertId then
            if Config.Debug then
                print("^2[MDC-SYNC]^7 Call queued successfully: " .. lasdCall.tag .. " (ID: " .. insertId .. ")")
            end
        else
            print("^1[MDC-SYNC ERROR]^7 Failed to queue call in database")
        end
    end)
end

-- Event handlers
RegisterNetEvent('mdc:sync911Call')
AddEventHandler('mdc:sync911Call', function(imperialCall)
    if Config.Debug then print("^3[MDC-SYNC]^7 Received new 911 call event") end
    if Config.AutoSync then
        local lasdCall = convertToLASDFormat(imperialCall)

        -- Mark call as needing TTS generation (will be done by Node.js watcher)
        lasdCall.needsTTS = true

        sendCallToMDC(lasdCall)
    end
end)

RegisterNetEvent('mdc:syncCallUpdate')
AddEventHandler('mdc:syncCallUpdate', function(imperialCall)
    if Config.Debug then print("^3[MDC-SYNC]^7 Received call update event") end
    if Config.AutoSync then
        local lasdCall = convertToLASDFormat(imperialCall)
        sendCallToMDC(lasdCall)
    end
end)

-- Test command
RegisterCommand('testmdcsync', function(source, args, rawCommand)
    if source ~= 0 then
        print("^1[MDC-SYNC]^7 This command can only be run from the server console")
        return
    end

    print("^3[MDC-SYNC]^7 Testing MDC sync with sample call...")

    local testCall = {
        callId = "TEST123ABC",
        callnum = 12847,
        nature = "Assault With Deadly Weapon",
        priority = 1,
        status = "PENDING",
        street = "15200 PACIFIC COAST HWY",
        crossStreet = "CORRAL CANYON RD",
        city = "Malibu",
        county = "Los Angeles County",
        postal = "102",
        info = "VICTIM SHOT DURING ROAD RAGE INCIDENT, SUSPECT FLED NB IN BLACK DODGE CHARGER",
        name = "WITNESS AT SCENE",
        phone = "(310) 555-8472",
        units = {"281A", "280B", "91A", "92B"}  -- LASD Compton (281A, 280B) and West Hollywood (91A, 92B)
    }

    local lasdCall = convertToLASDFormat(testCall)
    sendCallToMDC(lasdCall)

    print("^2[MDC-SYNC]^7 Test call queued in database!")
end, false)

-- Startup
Citizen.CreateThread(function()
    Wait(1000)
    print("^2======================================^7")
    print("^2[MDC-SYNC]^7 Auto Call Sync Started")
    print("^2[MDC-SYNC]^7 Version: 1.0.1 (Database)")
    print("^2[MDC-SYNC]^7 Auto Sync: " .. (Config.AutoSync and "ENABLED" or "DISABLED"))
    print("^2[MDC-SYNC]^7 Debug Mode: " .. (Config.Debug and "ON" or "OFF"))
    print("^2======================================^7")
    print("^3[MDC-SYNC]^7 Use 'testmdcsync' in server console to test")
end)

exports('ConvertToLASDFormat', convertToLASDFormat)
exports('SendCallToMDC', sendCallToMDC)
