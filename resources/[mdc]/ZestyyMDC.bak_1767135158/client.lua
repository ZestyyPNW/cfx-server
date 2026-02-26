local isOpen = false
local callBlips = {}
local knownCallKeys = {}
local callNotificationsReady = false
local mdcTargetRegistered = false
local lastMdcContextCheck = 0
local lastMdcContextActive = false
local lastAudioEnabled = nil

local function notify(message)
    TriggerEvent("chat:addMessage", {
        color = {0, 200, 255},
        args = {"MDC", message}
    })
end

local function getUnixSeconds()
    local cloud = GetCloudTimeAsInt()
    if cloud and cloud > 0 then return cloud end
    return math.floor(GetGameTimer() / 1000)
end

local function civilFromDays(days)
    local z = days + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp + (mp < 10 and 3 or -9)
    y = y + (m <= 2 and 1 or 0)
    return y, m, d, doy + 1
end

local function toJulianDate(timestamp)
    if not timestamp then return nil end
    local seconds = tonumber(timestamp)
    if not seconds then return nil end
    if seconds > 1000000000000 then seconds = math.floor(seconds / 1000) end
    local days = math.floor(seconds / 86400)
    local year, _, _, dayOfYear = civilFromDays(days)
    if not year or not dayOfYear then return nil end
    local yearShort = tostring(year):sub(-2)
    return string.format("%s%03d", yearShort, dayOfYear)
end

local function removeCallBlip(key)
    local blip = callBlips[key]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    callBlips[key] = nil
end

local function isMdcContextActive()
    local now = GetGameTimer()
    if lastMdcContextCheck ~= 0 and (now - lastMdcContextCheck) < 1500 then
        return lastMdcContextActive
    end
    lastMdcContextCheck = now
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        lastMdcContextActive = false
        return false
    end
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local model = GetEntityModel(veh)
            if Config.AllowedVehicles and Config.AllowedVehicles[model] then
                lastMdcContextActive = true
                return true
            end
        end
    end
    local coords = GetEntityCoords(ped)
    local range = tonumber(Config.MdcTargetRange) or 1.5
    if Config.MdcTargetModels then
        for _, modelName in ipairs(Config.MdcTargetModels) do
            local model = type(modelName) == "string" and GetHashKey(modelName) or modelName
            local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, range, model, false, false, false)
            if obj ~= 0 then
                local objCoords = GetEntityCoords(obj)
                local dist = #(coords - objCoords)
                if dist <= range and HasEntityClearLosToEntity(ped, obj, 17) then
                    lastMdcContextActive = true
                    return true
                end
            end
        end
    end
    lastMdcContextActive = false
    return false
end

local function setNuiAudioEnabled(enabled)
    if lastAudioEnabled == enabled then return end
    lastAudioEnabled = enabled
    SendNUIMessage({ action = "setAudio", enabled = enabled and true or false })
end

function ToggleMDC(openObs, force)
    if not force and not isMdcContextActive() then return end
    isOpen = not isOpen
    SetNuiFocus(isOpen, isOpen)
    SendNUIMessage({ action = isOpen and "open" or "close", openObs = openObs })
    setNuiAudioEnabled(isOpen and isMdcContextActive())
end

local function updateCallBlips(calls)
    local seen = {}
    for _, call in ipairs(calls) do
        local key = call.call_tag or tostring(call.id)
        seen[key] = true
        if call.call_x and call.call_y and call.call_z then
            local x = tonumber(call.call_x)
            local y = tonumber(call.call_y)
            local z = tonumber(call.call_z)
            local blip = callBlips[key]
            if not blip then
                blip = AddBlipForCoord(x, y, z)
                callBlips[key] = blip
            else
                SetBlipCoords(blip, x, y, z)
            end
            if DoesBlipExist(blip) then
                SetBlipSprite(blip, 388)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, 0.8)
                SetBlipColour(blip, 1)
                SetBlipAsShortRange(blip, true)
                local julian = toJulianDate(call.created_at or call.createdAt) or toJulianDate(getUnixSeconds())
                local tag = julian and ("EWP" .. julian) or "EWP"
                local code = tostring(call.code or "")
                local label = (call.unit or "UNK")
                if call.character_name then label = label .. " - " .. call.character_name:upper() end
                if label ~= "" and DoesBlipExist(blip) then
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString(label)
                    EndTextCommandSetBlipName(blip)
                end
            end
        end
        knownCallKeys[key] = true
    end
    for key, _ in pairs(callBlips) do if not seen[key] then removeCallBlip(key) end end
    for key, _ in pairs(knownCallKeys) do if not seen[key] then knownCallKeys[key] = nil end end
    if not callNotificationsReady then callNotificationsReady = true end
end

local function registerMdcTargets()
    if mdcTargetRegistered then return end
    mdcTargetRegistered = true
    CreateThread(function()
        local timeout = 0
        while GetResourceState("ox_target") ~= "started" and timeout < 30 do 
            Wait(1000) 
            timeout = timeout + 1
        end
        if GetResourceState("ox_target") ~= "started" then return end

        if Config.MdcTargetModels and #Config.MdcTargetModels > 0 then
            exports.ox_target:addModel(Config.MdcTargetModels, {
                {
                    name = "zestyy_mdc:open",
                    icon = "fa-solid fa-desktop",
                    label = "Open MDC",
                    distance = 2.5,
                    onSelect = function() ToggleMDC(nil, true) end
                }
            })
        end
        
        local vehicleModels = {}
        if Config.AllowedVehicles then
            for hash, allowed in pairs(Config.AllowedVehicles) do
                if allowed then table.insert(vehicleModels, hash) end
            end
        end
        
        if #vehicleModels > 0 then
            exports.ox_target:addModel(vehicleModels, {
                {
                    name = "zestyy_mdc:open_veh",
                    icon = "fa-solid fa-car",
                    label = "Open Vehicle MDC",
                    distance = 2.5,
                    onSelect = function() ToggleMDC(nil, true) end
                }
            })
        end
    end)
end

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerEvent("chat:addSuggestion", "/mdc", "Open or close the MDC UI.")
    registerMdcTargets()
end)

RegisterCommand("mdc", function() ToggleMDC(nil, true) end, false)

RegisterCommand("obs", function(source, args, rawCommand)
    local radioCode = args[1] or ""
    local remarks = ""
    if rawCommand and rawCommand ~= "" then
        local trimmed = rawCommand:gsub("^/obs%s*", "")
        local firstSpace = trimmed:find("%s")
        if firstSpace then remarks = trimmed:sub(firstSpace + 1) end
    end
    if radioCode == "" then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    local crossing = GetStreetNameFromHashKey(crossingHash)
    local location = streetName
    if crossing and crossing ~= "" then location = location .. " / " .. crossing end
    local unit = LocalPlayer.state.unitid
    if not unit or unit == "" then return end
    TriggerServerEvent("ZestyyMDC:CreateOBS", location, radioCode, unit, remarks, coords.x, coords.y, coords.z)
end, false)

RegisterCommand("ur", function(source, args)
    SendNUIMessage({ action = "runUR", unit = args[1] or "" })
end, false)

RegisterNUICallback("close", function(data, cb)
    ToggleMDC()
    cb("ok")
end)

RegisterNUICallback("getLocation", function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    local crossing = GetStreetNameFromHashKey(crossingHash)
    local location = streetName
    if crossing and crossing ~= "" then location = location .. " / " .. crossing end
    cb({ x = coords.x, y = coords.y, z = coords.z, location = location, street = streetName, crossing = crossing })
end)

RegisterNUICallback("setUnit", function(data, cb)
    local unit, fullName = data.unit, data.name or ""
    local first, last = fullName:match("^(.-)%s+(.*)$")
    if not first then first, last = fullName, "" end
    LocalPlayer.state:set("unitid", unit, true)
    LocalPlayer.state:set("firstname", first, true)
    LocalPlayer.state:set("lastname", last, true)
    LocalPlayer.state:set("firstName", first, true)
    LocalPlayer.state:set("lastName", last, true)
    LocalPlayer.state:set("onduty", true, true)
    TriggerEvent("SimpleHUD:updateUnit", unit)
    cb("ok")
end)

RegisterNUICallback("updateUnread", function(data, cb)
    TriggerEvent("SimpleHUD:updateMDC", data.count)
    cb("ok")
end)

RegisterNUICallback("chat", function(data, cb)
    local prefix = ("^2[%s]^7"):format(data.channel or "MDC")
    for line in tostring(data.text or ""):gmatch("[^\r\n]+") do
        TriggerEvent("chat:addMessage", { args = {prefix, line} })
    end
    cb("ok")
end)

RegisterNetEvent("ZestyyMDC:UpdateCallBlips")
AddEventHandler("ZestyyMDC:UpdateCallBlips", function(calls)
    if type(calls) == "table" then updateCallBlips(calls) end
end)
