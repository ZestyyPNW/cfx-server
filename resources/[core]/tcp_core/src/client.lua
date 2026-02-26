-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

local NDCore = nil
if GetResourceState("ND_Core") == "started" then
    NDCore = exports["ND_Core"]
end

local priorityText = ""
local aopText = ""
local zoneName = ""
local streetName = ""
local aheadStreet = ""
local crossingRoad = ""
local nearestPostal = {}
local compass = ""
local time = ""
local hidden = false
local unreadCount = 0
local waitingCount = 0
local mdcUnit = ""
local mdcLoggedIn = false
local mdcWorksheetSubmitted = false
local postals = {}
local aiDisabled = false
local dvallActive = false

if config.enableSpeedometerMetric then
    speedCalc = 3.6
    speedText = "KMH"
else
    speedCalc = 2.236936
    speedText = "MPH"
end
for _, vehicleName in pairs(config.electricVehiles) do
    config.electricVehiles[GetHashKey(vehicleName)] = vehicleName
end

function getAOP()
    return aopText
end

local function applyStreetAlias(name)
    if not name then return "" end
    local value = tostring(name)
    if value == "" then return "" end
    if config and config.streetNames and config.streetNames[value] then
        return config.streetNames[value]
    end
    return value
end

function getStreetAndCrossAtCoord(x, y, z)
    local streetHash, crossHash = GetStreetNameAtCoord(x, y, z)
    local street = GetStreetNameFromHashKey(streetHash)
    local cross = GetStreetNameFromHashKey(crossHash)
    return applyStreetAlias(street), applyStreetAlias(cross)
end

function getLocationAtCoord(x, y, z, separator)
    local street, cross = getStreetAndCrossAtCoord(x, y, z)
    local sep = separator and tostring(separator) or " / "
    local location = street
    if cross and cross ~= "" then
        location = ("%s%s%s"):format(street, sep, cross)
    end
    return location, street, cross
end

function getHeading(heading)
    if ((heading >= 0 and heading < 45) or (heading >= 315 and heading < 360)) then
        return "N"
    elseif (heading >= 45 and heading < 135) then
        return "W"
    elseif (heading >= 135 and heading < 225) then
        return "S"
    elseif (heading >= 225 and heading < 315) then
        return "E"
    else
        return " "
    end
end

function getTime()
    hour = GetClockHours()
    minute = GetClockMinutes()
    if hour <= 9 then hour = "0" .. hour end
    if minute <= 9 then minute = "0" .. minute end
    return hour .. ":" .. minute
end

if config.enableAopStatus then
    RegisterNetEvent("AndyHUD:ChangeAOP")
    AddEventHandler("AndyHUD:ChangeAOP", function(aop)
        aopText = aop
    end)
end

if config.enablePriorityStatus then
    RegisterNetEvent("AndyHUD:returnPriority")
    AddEventHandler("AndyHUD:returnPriority", function(priority)
        priorityText = priority
    end)
end

-- Strictly local event from ZestyyMDC NUI
RegisterNetEvent("SimpleHUD:updateMDC")
AddEventHandler("SimpleHUD:updateMDC", function(count)
    unreadCount = count
end)

RegisterNetEvent("SimpleHUD:updateWaitingIncidents")
AddEventHandler("SimpleHUD:updateWaitingIncidents", function(count)
    waitingCount = count
end)

RegisterNetEvent("SimpleHUD:mdcLogin")
AddEventHandler("SimpleHUD:mdcLogin", function()
    mdcLoggedIn = true
end)

RegisterNetEvent("SimpleHUD:mdcWorksheetSubmitted")
AddEventHandler("SimpleHUD:mdcWorksheetSubmitted", function()
    mdcWorksheetSubmitted = true
    mdcLoggedIn = true
end)

RegisterNUICallback("updateMDC", function(data, cb)
    local count = tonumber(data and data.count) or 0
    TriggerEvent("SimpleHUD:updateMDC", count)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback("mdcLogin", function(data, cb)
    TriggerEvent("SimpleHUD:mdcLogin")
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback("mdcWorksheetSubmitted", function(data, cb)
    TriggerEvent("SimpleHUD:mdcWorksheetSubmitted")
    TriggerServerEvent("SimpleHUD:mdcWorksheetSubmitted")
    if cb then cb({ ok = true }) end
end)

local function formatUnitDisplay(unit)
    local cleanedUnit = unit and tostring(unit):gsub("%%s+", "") or ""
    if cleanedUnit == "" then
        return ""
    end
    local state = LocalPlayer and LocalPlayer.state or {}
    local name = state.nd_players_name
    if not name or tostring(name) == "" then
        local first = state.firstname or state.firstName
        local last = state.lastname or state.lastName
        if first and last and tostring(first) ~= "" and tostring(last) ~= "" then
            name = ("%s %s"):format(first, last)
        end
    end
    if name and tostring(name) ~= "" then
        return ("%s | %s"):format(tostring(name), tostring(cleanedUnit):upper())
    end
    return tostring(cleanedUnit):upper()
end

AddEventHandler("SimpleHUD:updateUnit", function(unit)
    mdcUnit = formatUnitDisplay(unit)
end)

local function syncMdcUnitFromState()
    local unit = LocalPlayer and LocalPlayer.state and LocalPlayer.state.unitid or nil
    mdcUnit = formatUnitDisplay(unit)
    if unit and tostring(unit) ~= "" then
        mdcWorksheetSubmitted = true
        mdcLoggedIn = true
    end
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    syncMdcUnitFromState()
    setupGpsSuggestions()
end)

AddStateBagChangeHandler('unitid', nil, function(_bagName, _key, value)
    mdcUnit = formatUnitDisplay(value)
    if value and tostring(value) ~= "" then
        mdcWorksheetSubmitted = true
        mdcLoggedIn = true
    end
end)

AddStateBagChangeHandler('nd_players_name', nil, function()
    syncMdcUnitFromState()
end)

AddStateBagChangeHandler('firstname', nil, function()
    syncMdcUnitFromState()
end)

AddStateBagChangeHandler('lastname', nil, function()
    syncMdcUnitFromState()
end)

AddStateBagChangeHandler('firstName', nil, function()
    syncMdcUnitFromState()
end)

AddStateBagChangeHandler('lastName', nil, function()
    syncMdcUnitFromState()
end)

AddEventHandler("playerSpawned", function()
    if config.enableAopStatus then TriggerServerEvent("AndyHUD:getAop") end
    if config.enablePriorityStatus then TriggerServerEvent("AndyHUD:getPriority") end
end)

function markPostal(code)
    for i = 1, #postals do
        local postal = postals[i]
        if postal.code == code then
            SetNewWaypoint(postal.coords.x, postal.coords.y)
            return
        end
    end
end

RegisterCommand("postal", function(source, args)
    if not args[1] then return end
    markPostal(args[1])
end, false)

local function register911Command()
    RegisterCommand("911", function(source, args)
        local message = table.concat(args, " "):gsub("^%s+", ""):gsub("%s+$", "")
        if message == "" then
            TriggerEvent("tcp_notify:show", "911: Usage: /911 <message>", 4000)
            return
        end

        local ped = PlayerPedId()
        if not ped or ped == 0 then
            TriggerEvent("tcp_notify:show", "911: Unable to get your location. Please try again.", 4000)
            return
        end

        local coords = GetEntityCoords(ped)
        local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street = GetStreetNameFromHashKey(streetHash)
        local cross = GetStreetNameFromHashKey(crossHash)
        local location = street or "UNKNOWN STREET"
        if cross and cross ~= "" then
            location = ("%s / %s"):format(location, cross)
        end
        if config.enablePostals and nearestPostal and nearestPostal.code then
            location = ("%s (%s)"):format(location, nearestPostal.code)
        end

        local state = LocalPlayer and LocalPlayer.state or {}
        local caller = state.nd_players_name
        if not caller or tostring(caller) == "" then
            local first = state.firstname or state.firstName
            local last = state.lastname or state.lastName
            if first and last and tostring(first) ~= "" and tostring(last) ~= "" then
                caller = ("%s %s"):format(first, last)
            else
                caller = GetPlayerName(PlayerId()) or "UNKNOWN CALLER"
            end
        end

        TriggerServerEvent("tcp_core:911", {
            message = message,
            location = location,
            caller = caller,
            coords = { x = coords.x, y = coords.y, z = coords.z }
        })

        -- Feedback will be provided via tcp_core:911Result event
    end, false)
end

register911Command()
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == "ND_MDT" then
        register911Command()
    end
end)

RegisterCommand("ai", function()
    aiDisabled = not aiDisabled
    local state = aiDisabled and "disabled" or "enabled"
    TriggerEvent("tcp_notify:show", ("AI: AI is now %s."):format(state), 3000)
end, false)

local function requestControl(entity)
    if not DoesEntityExist(entity) then
        return false
    end
    NetworkRequestControlOfEntity(entity)
    local start = GetGameTimer()
    while not NetworkHasControlOfEntity(entity) and (GetGameTimer() - start) < 1000 do
        Wait(10)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function deleteVehicleEntity(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end
    if requestControl(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

RegisterCommand("dv", function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        TriggerEvent("tcp_notify:show", "DV: You are not in a vehicle.", 3000)
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TriggerEvent("tcp_notify:show", "DV: You must be the driver.", 3000)
        return
    end

    deleteVehicleEntity(vehicle)
end, false)

RegisterNetEvent("tcp_core:dvallCountdown", function(seconds)
    if dvallActive then
        return
    end
    dvallActive = true
    local duration = tonumber(seconds) or 10
    if duration < 1 then
        duration = 1
    end

    CreateThread(function()
        for i = duration, 1, -1 do
            TriggerEvent("tcp_notify:show", ("DVALL: Clearing vehicles in %d..."):format(i), 1500)
            Wait(1000)
        end

        local vehicles = GetGamePool("CVehicle")
        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver == 0 or not IsPedAPlayer(driver) then
                deleteVehicleEntity(vehicle)
            end
        end

        TriggerEvent("tcp_notify:show", "DVALL: Vehicle cleanup complete.", 4000)
        dvallActive = false
    end)
end)

CreateThread(function()
    while true do
        if aiDisabled then
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            SetGarbageTrucks(false)
            SetRandomBoats(false)
        end
        Wait(0)
    end
end)

RegisterNetEvent("tcp_core:911Result", function(ok)
    local text = ok and "911: Call received by dispatch. Dispatchers have been notified." or "911: Call failed to send. Please try again or contact dispatch directly."
    TriggerEvent("tcp_notify:show", text, 5000)
end)

function getPostal()
    return nearestPostal.code, nearestPostal
end

CreateThread(function()
    postals = json.decode(LoadResourceFile(GetCurrentResourceName(), "postals.json"))
    for i = 1, #postals do
        local postal = postals[i]
        postals[i] = { coords = vec(postal.x, postal.y), code = postal.code }
    end
end)

CreateThread(function()
    local totalPostals = #postals
    while true do
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local nearestDist = nil
        local nearestIndex = nil
        local coords = vec(pedCoords.x, pedCoords.y)

        for i = 1, totalPostals do
            local dist = #(coords - postals[i].coords)
            if not nearestDist or dist < nearestDist then
                nearestDist = dist
                nearestIndex = i
            end
        end

        nearestPostal = postals[nearestIndex]

        local forward = GetEntityForwardVector(ped)
        local aheadCoords = pedCoords + (forward * 50.0)

        streetName, crossingRoad = GetStreetNameAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        streetName = GetStreetNameFromHashKey(streetName)
        crossingRoad = GetStreetNameFromHashKey(crossingRoad)

        local aheadHash, _ = GetStreetNameAtCoord(aheadCoords.x, aheadCoords.y, aheadCoords.z)
        aheadStreet = GetStreetNameFromHashKey(aheadHash)

        zoneName = GetLabelText(GetNameOfZone(pedCoords.x, pedCoords.y, pedCoords.z))
        if config.streetNames[streetName] then streetName = config.streetNames[streetName] end
        if config.streetNames[crossingRoad] then crossingRoad = config.streetNames[crossingRoad] end
        if config.streetNames[aheadStreet] then aheadStreet = config.streetNames[aheadStreet] end
        if config.zoneNames[zoneName] then zoneName = config.zoneNames[zoneName] end
        
        compass = getHeading(GetEntityHeading(ped))
        if crossingRoad ~= "" then streetName = streetName .. " x " .. crossingRoad end

        Wait(1000)
    end
end)

-- Main HUD Loop (NUI Update)
CreateThread(function()
    while true do
        Wait(200)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local inVehicle = (vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped)
        local isElectric = false
        local fuelLevel = 0
        local speed = 0
        local engineHealth = 1000
        local gear = ""
        local lightsOn, highbeamsOn = false, false
        local lockStatus = 1

        hidden = IsHudHidden() or IsPauseMenuActive()

        if inVehicle then
            speed = math.ceil(GetEntitySpeed(vehicle) * speedCalc)
            fuelLevel = GetVehicleFuelLevel(vehicle)
            engineHealth = GetVehicleEngineHealth(vehicle)
            local _, lights, highbeams = GetVehicleLightsState(vehicle)
            lightsOn = (lights == 1)
            highbeamsOn = (highbeams == 1)
            lockStatus = GetVehicleDoorLockStatus(vehicle)
            if config.electricVehiles[GetEntityModel(vehicle)] then isElectric = true end
            local gearNum = GetVehicleCurrentGear(vehicle)
            if gearNum == 0 then
                local velocity = GetEntitySpeedVector(vehicle, true)
                if velocity.y < -0.2 then
                    gear = "R"
                else
                    gear = "N"
                end
            else
                gear = tostring(gearNum)
            end
        end

        local currentVehicle = GetVehiclePedIsIn(ped, false)
        local isAllowedVehicle = false
        if currentVehicle ~= 0 and Config and Config.AllowedVehicles then
            isAllowedVehicle = Config.AllowedVehicles[GetEntityModel(currentVehicle)]
        end

        SendNUIMessage({
            action = "updateHUD",
            hidden = hidden,
            zone = zoneName,
            street = streetName,
            ahead = aheadStreet,
            compass = compass,
            postal = (config.enablePostals and nearestPostal) and nearestPostal.code or nil,
            time = getTime(),
            aop = config.enableAopStatus and aopText or nil,
            unreadCount = (isAllowedVehicle and mdcLoggedIn and mdcWorksheetSubmitted) and unreadCount or 0,
            waitingCount = (isAllowedVehicle and mdcLoggedIn and mdcWorksheetSubmitted) and waitingCount or 0,
            unit = mdcUnit,
            inVehicle = inVehicle,
            speed = speed,
            speedUnit = speedText,
            showFuel = config.enableFuelHUD,
            fuel = fuelLevel,
            isElectric = isElectric,
            engineHealth = engineHealth,
            lightsOn = lightsOn,
            highbeamsOn = highbeamsOn,
            lockStatus = lockStatus,
            gear = gear
        })
    end
end)

local function mergeHudVars(target, source)
    if type(source) ~= "table" then return target end
    for key, value in pairs(source) do
        if type(key) == "string" and key:sub(1, 2) == "--" then
            target[key] = value
        end
    end
    return target
end

local function buildHudLayoutVars(width, height)
    local layout = config and config.hudLayout or nil
    if type(layout) ~= "table" or layout.enabled == false then
        return nil
    end

    local vars = {}
    mergeHudVars(vars, layout.default)

    local aspect = 0
    if tonumber(width) and tonumber(height) and tonumber(height) > 0 then
        aspect = tonumber(width) / tonumber(height)
    end

    local aspectRules = layout.aspect
    if type(aspectRules) == "table" and aspect > 0 then
        local ultrawide = aspectRules.ultrawide
        if type(ultrawide) == "table" and type(ultrawide.vars) == "table" and ultrawide.min and aspect >= tonumber(ultrawide.min) then
            mergeHudVars(vars, ultrawide.vars)
        end
        local narrow = aspectRules.narrow
        if type(narrow) == "table" and type(narrow.vars) == "table" and narrow.max and aspect <= tonumber(narrow.max) then
            mergeHudVars(vars, narrow.vars)
        end
    end

    local resolutions = layout.resolutions
    if type(resolutions) == "table" and tonumber(width) and tonumber(height) then
        local key = ("%dx%d"):format(width, height)
        local resVars = resolutions[key]
        if type(resVars) == "table" then
            mergeHudVars(vars, resVars)
        end
    end

    return vars, aspect
end

CreateThread(function()
    local lastWidth, lastHeight = nil, nil
    while true do
        local width, height = GetActiveScreenResolution()
        if width ~= lastWidth or height ~= lastHeight then
            lastWidth, lastHeight = width, height
            local vars, aspect = buildHudLayoutVars(width, height)
            if vars then
                SendNUIMessage({
                    action = "hudConfig",
                    vars = vars,
                    screen = { width = width, height = height, aspect = aspect }
                })
            end
        end
        Wait(2000)
    end
end)

-- GPS to Street Command with Autofill
function setupGpsSuggestions()
    local suggestions = {}
    -- Sort names alphabetically for better UX
    local streetList = {}
    for _, customName in pairs(config.streetNames) do
        table.insert(streetList, customName)
    end
    table.sort(streetList)

    for i=1, #streetList do
        table.insert(suggestions, { text = streetList[i], help = "Set GPS to " .. streetList[i] })
    end

    TriggerEvent('chat:addSuggestion', '/gps', 'Set a waypoint to a street name', {
        { name="street", help="Type the name of the street", suggestions = suggestions }
    })
end

RegisterCommand("gps", function(source, args)
    if not args[1] then
        TriggerEvent("tcp_notify:show", "GPS: Usage: /gps <street name>", 4000)
        return
    end

    local input = table.concat(args, " "):lower()
    local foundStreet = nil
    local originalGtaName = nil

    for gtaName, customName in pairs(config.streetNames) do
        if customName:lower() == input or customName:lower():find(input) then
            foundStreet = customName
            originalGtaName = gtaName
            break
        end
    end

    if not foundStreet then
        TriggerEvent("tcp_notify:show", "GPS: Street not found in the directory.", 4000)
        return
    end

    local hash = GetHashKey(originalGtaName)
    TriggerEvent("tcp_notify:show", "GPS: Calculating route to " .. foundStreet .. "...", 3000)

    local playerPos = GetEntityCoords(PlayerPedId())
    local success = false
    
    for radius = 100.0, 8000.0, 500.0 do
        local found, coords, heading = GetRandomVehicleNode(playerPos.x, playerPos.y, playerPos.z, radius, false, false, false)
        if found then
            local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            if streetHash == hash then
                SetNewWaypoint(coords.x, coords.y)
                TriggerEvent("tcp_notify:show", "GPS: Waypoint set to " .. foundStreet .. ".", 4000)
                success = true
                break
            end
        end
        if success then break end
    end

    if not success then
        TriggerEvent("tcp_notify:show", "GPS: Unable to find precise coordinates for " .. foundStreet .. ".", 4000)
    end
end, false)

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

local statsState = normalizeStats({})
local statsDirty = false
local statsReady = false
local sprintDistance = 0.0
local swimDistance = 0.0
local driveDistance = 0.0
local crouchTime = 0
local shotCount = 0
local lastPedCoords = nil
local lastVehicleCoords = nil
local lastWeapon = nil
local lastAmmo = nil

local function updateAgility()
    statsState.agility = clampStat(math.floor((statsState.stamina + statsState.strength) / 2 + 0.5))
end

local function applyStatDelta(stat, delta)
    if not statsReady then return end
    local current = statsState[stat] or 0
    local nextValue = clampStat(current + delta)
    if nextValue == current then return end
    statsState[stat] = nextValue
    if stat == "stamina" or stat == "strength" then
        updateAgility()
    end
    statsDirty = true
end

local function sendStatsIfDirty()
    if not statsReady or not statsDirty then return end
    statsDirty = false
    TriggerServerEvent("tcp_core:updatePlayerStats", statsState)
end

local function isPedStealth(ped)
    local ok, value = pcall(GetPedStealthMovement, ped)
    if not ok then return false end
    if type(value) == "boolean" then
        return value
    end
    return value ~= 0
end

RegisterNetEvent("tcp_core:receivePlayerStats", function(stats)
    statsState = normalizeStats(stats)
    updateAgility()
    statsReady = true
    statsDirty = false
end)

local function requestPlayerStats()
    TriggerServerEvent("tcp_core:requestPlayerStats")
end

AddEventHandler("ox_inventory:openInventory", function()
    if not statsReady then
        requestPlayerStats()
    end
    sendStatsIfDirty()
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(5000)
        requestPlayerStats()
    end)
end)

CreateThread(function()
    while true do
        Wait(5000)
        sendStatsIfDirty()
    end
end)

AddEventHandler("gameEventTriggered", function(name, args)
    if name ~= "CEventNetworkEntityDamage" or not statsReady then return end
    local victim = args[1]
    local attacker = args[2]
    local weaponHash = args[7]
    if attacker ~= PlayerPedId() or not DoesEntityExist(victim) then return end
    local damageType = GetWeaponDamageType(weaponHash)
    if weaponHash == `WEAPON_UNARMED` or damageType == 1 then
        applyStatDelta("strength", 1)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if not statsReady then goto continue end
        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        local coords = GetEntityCoords(ped)
        if lastPedCoords then
            local dist = #(coords - lastPedCoords)
            if IsPedSprinting(ped) then
                sprintDistance = sprintDistance + dist
            end
            if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
                swimDistance = swimDistance + dist
            end
        end
        lastPedCoords = coords

        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local vehicleCoords = GetEntityCoords(vehicle)
            if lastVehicleCoords then
                driveDistance = driveDistance + #(vehicleCoords - lastVehicleCoords)
            end
            lastVehicleCoords = vehicleCoords
        else
            lastVehicleCoords = nil
        end

        if isPedStealth(ped) then
            crouchTime = crouchTime + 1
        end

        while sprintDistance >= 100.0 do
            applyStatDelta("stamina", 1)
            sprintDistance = sprintDistance - 100.0
        end

        while swimDistance >= 100.0 do
            applyStatDelta("swimming", 1)
            swimDistance = swimDistance - 100.0
        end

        while driveDistance >= 1609.0 do
            applyStatDelta("driving", 1)
            driveDistance = driveDistance - 1609.0
        end

        while crouchTime >= 60 do
            applyStatDelta("stealth", 1)
            crouchTime = crouchTime - 60
        end

        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(200)
        if not statsReady then goto continue end
        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` and IsPedArmed(ped, 4) then
            local ammo = GetAmmoInPedWeapon(ped, weapon)
            if lastWeapon == weapon and lastAmmo and ammo < lastAmmo then
                shotCount = shotCount + (lastAmmo - ammo)
            end
            lastWeapon = weapon
            lastAmmo = ammo
        else
            lastWeapon = nil
            lastAmmo = nil
        end

        while shotCount >= 10 do
            applyStatDelta("shooting", 1)
            shotCount = shotCount - 10
        end

        ::continue::
    end
end)
