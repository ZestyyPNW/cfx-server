local isOpen = false
local lastUrl = Config.DefaultUrl
local firstLoad = true
local toggleCommand = "mdc"
local ndCharacter = nil

local function canOpenMdc()
  local ped = PlayerPedId()
  if not ped or ped == 0 then
    return false
  end

  local vehicle = GetVehiclePedIsIn(ped, false)
  if Config.RequireInVehicle and (not vehicle or vehicle == 0) then
    return false
  end

  if Config.RequireAllowedVehicle and vehicle and vehicle ~= 0 then
    local allowed = Config.AllowedVehicles
    if type(allowed) == "table" and next(allowed) ~= nil then
      local model = GetEntityModel(vehicle)
      if not allowed[model] then
        return false
      end
    end
  end

  return true
end

local function notifyDenied()
  local message = Config.DenyOpenMessage or "You can't open MDC right now."
  TriggerEvent("tcp_notify:show", "MDC: " .. tostring(message), 4000)
end

local function dbg(...)
  if Config.Debug then
    print("^3[MDC-WEB]^7", ...)
  end
end

local function getMappedLocation(coords)
  if not coords then return "", "", "" end

  local x, y, z = coords.x, coords.y, coords.z

  if GetResourceState("tcp_core") == "started" then
    local ok, location, street, crossing = pcall(function()
      return exports["tcp_core"]:getLocationAtCoord(x, y, z, " / ")
    end)
    if ok and type(location) == "string" and location ~= "" then
      return location, tostring(street or ""), tostring(crossing or "")
    end

    local ok2, street2, crossing2 = pcall(function()
      return exports["tcp_core"]:getStreetAndCrossAtCoord(x, y, z)
    end)
    if ok2 and type(street2) == "string" and street2 ~= "" then
      local loc = street2
      if crossing2 and tostring(crossing2) ~= "" then
        loc = ("%s / %s"):format(street2, crossing2)
      end
      return loc, tostring(street2 or ""), tostring(crossing2 or "")
    end
  end

  local streetHash, crossingHash = GetStreetNameAtCoord(x, y, z)
  local streetName = GetStreetNameFromHashKey(streetHash)
  local crossing = GetStreetNameFromHashKey(crossingHash)
  local location = streetName
  if crossing and crossing ~= "" then
    location = location .. " / " .. crossing
  end
  return location, streetName, crossing
end

local postalIndex = nil
local function getPostalCoordsByCode(code)
  local clean = tostring(code or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if clean == "" then return nil end
  if not postalIndex then
    postalIndex = {}
    local raw = LoadResourceFile("tcp_core", "postals.json")
    if raw and raw ~= "" then
      local ok, decoded = pcall(json.decode, raw)
      if ok and type(decoded) == "table" then
        for _, entry in ipairs(decoded) do
          local key = tostring(entry.code or ""):gsub("^%s+", ""):gsub("%s+$", "")
          local x = tonumber(entry.x)
          local y = tonumber(entry.y)
          if key ~= "" and x and y then
            postalIndex[key] = { x = x, y = y }
          end
        end
      end
    end
  end
  return postalIndex[clean]
end

local function cleanLocationText(value)
  local text = tostring(value or ""):upper():gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return "" end
  text = text:gsub("%s+%([^()]+%)%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

local function findCoordsForLocationText(locationText, fallbackCoords)
  local cleaned = cleanLocationText(locationText)
  if cleaned == "" then return nil end
  local primary, cross = cleaned:match("^([^/]+)%s*/%s*(.+)$")
  primary = tostring(primary or cleaned):gsub("^%s+", ""):gsub("%s+$", "")
  cross = tostring(cross or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if primary == "" then return nil end

  local primaryHash = GetHashKey(primary)
  local crossHash = cross ~= "" and GetHashKey(cross) or nil
  local fallbackZ = fallbackCoords and fallbackCoords.z or 30.0
  local origins = {
    fallbackCoords,
    vector3(0.0, 0.0, fallbackZ),
    vector3(1700.0, 2600.0, fallbackZ),
    vector3(-800.0, -1300.0, fallbackZ)
  }

  for _, origin in ipairs(origins) do
    if origin then
      for radius = 300.0, 12000.0, 600.0 do
        for _ = 1, 8 do
          local found, node = GetRandomVehicleNode(origin.x, origin.y, origin.z, radius, false, false, false)
          if found and node then
            local a, b = GetStreetNameAtCoord(node.x, node.y, node.z)
            if a == primaryHash and (not crossHash or b == crossHash) then
              return vector3(node.x, node.y, node.z)
            end
            if crossHash and a == crossHash and b == primaryHash then
              return vector3(node.x, node.y, node.z)
            end
          end
        end
      end
    end
  end

  return nil
end

-- Session latch: once the player has gone on-duty this session, periodic sync
-- checks cannot flip them back off. Only a character change resets this.
local worksheetLatchedOnDuty = false

local function setOndutyState(value, reason)
    if value == false and worksheetLatchedOnDuty then
        return
    end
    LocalPlayer.state:set("onduty", value == true, true)
end

RegisterNetEvent("ND:characterLoaded", function(character)
  ndCharacter = character
  -- Reset latch on actual character change so a fresh session starts clean
  worksheetLatchedOnDuty = false
  setOndutyState(false, "ND:characterLoaded")
end)

RegisterNetEvent("ND:updateCharacter", function(character)
  ndCharacter = character
end)

-- Initialize onduty state to false on resource start
CreateThread(function()
  Wait(1000)
  if not worksheetLatchedOnDuty then
    setOndutyState(false, "resource_start")
  end
end)

-- Handle server response for worksheet status check
RegisterNetEvent("ZestyyMDC:SetOnduty")
AddEventHandler("ZestyyMDC:SetOnduty", function(onduty)
    setOndutyState(onduty, "ZestyyMDC:SetOnduty")
end)

local function setOpen(open, url)
  isOpen = open

  if url and url ~= "" then
    lastUrl = url
  end

  if open then
    -- When MDC opens, check if user has submitted worksheet today
    -- If not, ensure onduty is false to prevent blips from appearing
    TriggerServerEvent("ZestyyMDC:CheckWorksheetStatus")
    
    if Config.FocusOnOpen then
      SetNuiFocus(true, true)
      SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({
      action = "open", 
      url = lastUrl,
      firstLoad = firstLoad,
      cacheBust = true  -- Force cache bust on every open
    })

    firstLoad = false
    dbg("Opened with URL:", lastUrl)
    
    -- Request RID to auto-fill box 20 when MDC opens
    Citizen.CreateThread(function()
      Citizen.Wait(1000) -- Delay to ensure MDC is fully loaded
      TriggerServerEvent("zestyymdc:requestPlayerRID")
    end)
  else
    if Config.FocusOnClose then
      SetNuiFocus(false, false)
      SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({
      action = "close",
      persist = Config.PersistIframe
    })

    dbg("Closed (persist=" .. tostring(Config.PersistIframe) .. ")")
  end
end

RegisterCommand(toggleCommand, function(_, args)
  if isOpen then
    setOpen(false)
    return
  end

  if not canOpenMdc() then
    notifyDenied()
    return
  end

  -- Optional: /mdc https://whatever.site
  local url = args[1]
  if url and url ~= "" then
    setOpen(true, url)
  else
    setOpen(true, lastUrl)
  end
end, false)

-- Key mapping (default F11)
RegisterKeyMapping(toggleCommand, "Open MDC", "keyboard", "F11")

RegisterCommand("obs", function(_, args, rawCommand)
  local radioCode = args and args[1] or ""
  if radioCode == "" then
    TriggerEvent("tcp_notify:show", "MDC: Usage: /obs <RADIO_CODE> <remarks...>", 4000)
    return
  end

  local remarks = ""
  if rawCommand and rawCommand ~= "" then
    local trimmed = rawCommand:gsub("^/obs%s*", "")
    local firstSpace = trimmed:find("%s")
    if firstSpace then
      remarks = trimmed:sub(firstSpace + 1)
    end
  end
  remarks = tostring(remarks or ""):gsub("^%s+", ""):gsub("%s+$", "")

  local ped = PlayerPedId()
  if not ped or ped == 0 then
    TriggerEvent("tcp_notify:show", "MDC: Unable to create OBS (no ped).", 4000)
    return
  end

  local coords = GetEntityCoords(ped)
  local location = nil
  location = (select(1, getMappedLocation(coords)))

  local unit = LocalPlayer.state and LocalPlayer.state.unitid or nil
  if not unit or tostring(unit) == "" then
    TriggerEvent("tcp_notify:show", "MDC: Set your unit first (open MDC and set unit).", 4000)
    return
  end

  TriggerServerEvent("ZestyyMDC:CreateOBS", location, radioCode, tostring(unit), remarks, coords.x, coords.y, coords.z)
end, false)

-- Always clean up focus/UI if the resource is restarted while open.
AddEventHandler("onClientResourceStop", function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ action = "close", persist = false })
end)

-- Optional keybind toggle
CreateThread(function()
  while true do
    Wait(0)
    if Config.ToggleKey and IsControlJustPressed(0, Config.ToggleKey) then
      ExecuteCommand("mdc")
      Wait(250)
    end
  end
end)

-- If desired, auto-close MDC when leaving allowed vehicles.
CreateThread(function()
  while true do
    Wait(500)
    if isOpen and Config.AutoCloseWhenNotAllowed and not canOpenMdc() then
      setOpen(false)
    end
  end
end)

-- Allow the UI to tell us to close (ESC button in UI, etc.)
RegisterNUICallback("close", function(_, cb)
  setOpen(false)
  cb({ ok = true })
end)

-- Allow the UI to save/restore “last URL” (state)
RegisterNUICallback("setLastUrl", function(data, cb)
  if data and type(data.url) == "string" and data.url ~= "" then
    lastUrl = data.url
    dbg("Saved lastUrl from UI:", lastUrl)
  end
  cb({ ok = true })
end)

RegisterNUICallback("getLocation", function(data, cb)
  local ped = PlayerPedId()
  if not ped or ped == 0 then
    cb({ error = "no_ped" })
    return
  end

  local coords = GetEntityCoords(ped)
  local postalCoords = getPostalCoordsByCode(data and data.postal)
  if postalCoords then
    coords = vector3(postalCoords.x, postalCoords.y, coords.z)
  else
    local locationCoords = findCoordsForLocationText(data and data.location, coords)
    if locationCoords then
      coords = locationCoords
    end
  end
  local location, streetName, crossing = getMappedLocation(coords)

  cb({
    x = coords.x,
    y = coords.y,
    z = coords.z,
    location = location,
    street = streetName,
    crossing = crossing
  })
end)

RegisterNUICallback("setUnit", function(data, cb)
  local unit = data and data.unit or ""
  local fullName = data and data.name or ""

  if ndCharacter and ndCharacter.firstname and ndCharacter.lastname then
    fullName = (ndCharacter.firstname .. " " .. ndCharacter.lastname)
  end

  local first, last = tostring(fullName):match("^(.-)%s+(.*)$")
  if not first then
    first = tostring(fullName)
    last = ""
  end

  unit = tostring(unit or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()

  LocalPlayer.state:set("unitid", unit, true)
  LocalPlayer.state:set("firstname", first, true)
  LocalPlayer.state:set("lastname", last, true)
  LocalPlayer.state:set("firstName", first, true)
  LocalPlayer.state:set("lastName", last, true)
  -- DO NOT set onduty here - only set it when worksheet is submitted
  -- LocalPlayer.state:set("onduty", true, true)

  TriggerEvent("SimpleHUD:updateUnit", unit)
  cb({ ok = true })
end)

RegisterNUICallback("updateUnread", function(data, cb)
  local count = data and tonumber(data.count) or 0
  TriggerEvent("SimpleHUD:updateMDC", count)
  cb({ ok = true })
end)

RegisterNUICallback("mdcLogin", function(data, cb)
  -- Re-sync onduty only when unit exists to avoid false negatives during init.
  local unit = LocalPlayer.state and LocalPlayer.state.unitid or nil
  local normalized = unit and tostring(unit):gsub("^%s+", ""):gsub("%s+$", ""):upper() or ""
  if normalized ~= "" then
    TriggerServerEvent("ZestyyMDC:CheckWorksheetStatus")
  end
  TriggerEvent("SimpleHUD:mdcLogin")
  cb({ ok = true })
end)

RegisterNUICallback("mdcWorksheetSubmitted", function(data, cb)
  -- Lock the latch first, then set state — periodic syncs can no longer flip false
  worksheetLatchedOnDuty = true
  setOndutyState(true, "mdcWorksheetSubmitted")
  TriggerEvent("SimpleHUD:mdcWorksheetSubmitted")
  TriggerServerEvent("SimpleHUD:mdcWorksheetSubmitted")
  cb({ ok = true })
end)

-- Receive mileage data from server when worksheet is submitted
RegisterNetEvent("zestyymdc:worksheetMileageData")
AddEventHandler("zestyymdc:worksheetMileageData", function(data)
  -- Send mileage data to MDC frontend
  SendNUIMessage({
    type = "setMileageData",
    rid = data.rid,
    begMileage = data.begMileage
  })
end)

-- NUI callback to get player RID
RegisterNUICallback("getPlayerRID", function(data, cb)
  TriggerServerEvent("zestyymdc:requestPlayerRID")
  cb({ ok = true })
end)

-- NUI callback to get the active ND character name (Box 14)
RegisterNUICallback("getCharacterName", function(data, cb)
  local first = ""
  local last = ""

  -- Pull directly from ND_Core client export (no arg = local player)
  if GetResourceState('ND_Core') == 'started' then
    local ok, player = pcall(function()
      return exports['ND_Core']:getPlayer()
    end)
    if ok and player then
      first = tostring(player.firstname or ""):gsub("^%s+", ""):gsub("%s+$", "")
      last  = tostring(player.lastname  or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end
  end

  -- Fallback: ndCharacter cached on characterLoaded
  if first == "" and ndCharacter then
    first = tostring(ndCharacter.firstname or ""):gsub("^%s+", ""):gsub("%s+$", "")
    last  = tostring(ndCharacter.lastname  or ""):gsub("^%s+", ""):gsub("%s+$", "")
  end

  -- Last resort: state bags
  if first == "" then
    first = tostring(LocalPlayer.state.firstname or LocalPlayer.state.firstName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    last  = tostring(LocalPlayer.state.lastname  or LocalPlayer.state.lastName  or ""):gsub("^%s+", ""):gsub("%s+$", "")
  end

  local formatted = ""
  if first ~= "" and last ~= "" then
    formatted = first:sub(1,1):upper() .. ". " .. last:sub(1,1):upper() .. last:sub(2):lower()
  elseif last ~= "" then
    formatted = last
  end

  cb({ ok = true, name = formatted })
end)

-- Receive RID from server
RegisterNetEvent("zestyymdc:playerRID")
AddEventHandler("zestyymdc:playerRID", function(rid)
  -- Send RID to MDC frontend to auto-fill box 20
  SendNUIMessage({
    type = "setRID",
    rid = rid
  })
end)

-- NUI callback to get current vehicle mileage
RegisterNUICallback("getCurrentMileage", function(data, cb)
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  local mileage = 0
  
  if vehicle ~= 0 then
    -- Request mileage from server
    TriggerServerEvent("zestyymdc:getCurrentMileage")
  end
  
  cb({ ok = true, mileage = mileage })
end)

-- Receive mileage from server
RegisterNetEvent("zestyymdc:currentMileage")
AddEventHandler("zestyymdc:currentMileage", function(mileage)
  SendNUIMessage({
    type = "setCurrentMileage",
    mileage = mileage
  })
end)

RegisterNUICallback("console", function(data, cb)
  local level = data and tostring(data.level or "error") or "error"
  local message = data and tostring(data.message or "") or ""
  local href = data and tostring(data.href or "") or ""
  local user = data and tostring(data.user or "") or ""
  local stack = data and tostring(data.stack or "") or ""

  local line = message
  if href ~= "" then
    line = ("%s (%s)"):format(line, href)
  end
  if user ~= "" then
    line = ("%s user=%s"):format(line, user)
  end

  print(("[ZestyyMDC] %s %s"):format(level:upper(), line))
  if stack ~= "" then
    print(("[ZestyyMDC] %s STACK %s"):format(level:upper(), stack))
  end

  if Config and Config.ForwardConsoleErrorsToServer then
    TriggerServerEvent("ZestyyMDC:NuiConsole", {
      level = level,
      message = message,
      href = href,
      user = user,
      stack = stack
    })
  end

  cb({ ok = true })
end)

RegisterNUICallback("chat", function(data, cb)
  local channel = data and data.channel or "MDC"
  local text = data and data.text or ""

  local prefix = ("^2[%s]^7"):format(tostring(channel))
  local lines = {}
  for line in tostring(text):gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  if #lines == 0 then
    table.insert(lines, "")
  end

  for i, line in ipairs(lines) do
    TriggerEvent("chat:addMessage", {
      args = { i == 1 and prefix or " ", line }
    })
  end

  cb({ ok = true })
end)

-- Optional hard reload if you need it without restarting resource
RegisterCommand("mdc_reload", function()
  firstLoad = true
  if isOpen then
    SendNUIMessage({ action = "reload" })
    dbg("Reload requested")
  end
end, false)

-- Call blips management
local callBlips = {}

local function removeCallBlip(callId)
    if callBlips[callId] and DoesBlipExist(callBlips[callId]) then
        RemoveBlip(callBlips[callId])
        callBlips[callId] = nil
    end
end

local function createCallBlip(call)
    if not call then
        return
    end
    local x = tonumber(call.call_x)
    local y = tonumber(call.call_y)
    local z = tonumber(call.call_z)
    if not x or not y or not z then
        return
    end

    local callId = tostring(call.id or call.call_tag or "")
    if callId == "" then return end

    -- Remove existing blip if it exists
    removeCallBlip(callId)

    -- Create new blip
    local blip = AddBlipForCoord(x, y, z)
    if not blip or not DoesBlipExist(blip) then
        return
    end

    -- Configure blip appearance
    SetBlipSprite(blip, 280) -- Standard blip sprite
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 1) -- Red color
    SetBlipAsShortRange(blip, false)
    SetBlipAlpha(blip, 200)

    -- Set blip name
    local blipName = call.call_tag or call.code or "CALL"
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blipName)
    EndTextCommandSetBlipName(blip)

    callBlips[callId] = blip
end

RegisterNetEvent("ZestyyMDC:UpdateCallBlips", function(payload)
    if not payload or type(payload) ~= "table" then
        -- Clear all blips if payload is empty or invalid
        for callId, _ in pairs(callBlips) do
            removeCallBlip(callId)
        end
        return
    end

    -- Track which calls should exist
    local activeCallIds = {}
    for _, call in ipairs(payload) do
        local callId = tostring(call.id or call.call_tag or "")
        if callId ~= "" then
            activeCallIds[callId] = true
            createCallBlip(call)
        end
    end

    -- Remove blips for calls that no longer exist
    for callId, _ in pairs(callBlips) do
        if not activeCallIds[callId] then
            removeCallBlip(callId)
        end
    end
end)

-- Clean up blips when resource stops
AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for callId, _ in pairs(callBlips) do
            removeCallBlip(callId)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(res)
  if res == GetCurrentResourceName() then
    dbg("ZestyyMDC web wrapper loaded. Command /" .. toggleCommand .. " (F11).")
  end
end)

-- ============================================================
-- SCC AUTO-DISPATCH — client-side detectors
-- ============================================================

-- Track last death to detect PvP kills
local lastDeathCoords = nil
local lastDeathTime   = 0

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then
            local now = GetGameTimer()
            if now - lastDeathTime > 5000 then -- debounce 5s
                lastDeathTime = now
                local coords  = GetEntityCoords(ped)
                local killer  = GetPedSourceOfDeath(ped)
                local killerSrc = -1
                -- Only report PvP kills (killer is another player ped)
                if killer and killer ~= 0 and killer ~= ped and IsPedAPlayer(killer) then
                    killerSrc = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killer))
                end
                if killerSrc > 0 then
                    TriggerServerEvent("scc:playerKilled", killerSrc, GetPedCauseOfDeath(ped), { x = coords.x, y = coords.y, z = coords.z })
                end
            end
        end
        Wait(500)
    end
end)

-- Vehicle crash detector: fire event when player hits something at speed > 40 mph
CreateThread(function()
    local lastCrashTime = 0
    while true do
        Wait(500)
        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            local speed = GetEntitySpeed(vehicle) * 2.237 -- m/s to mph
            if speed > 40 and HasEntityCollidedWithAnything(vehicle) then
                local now = GetGameTimer()
                if now - lastCrashTime > 15000 then
                    lastCrashTime = now
                    local coords = GetEntityCoords(vehicle)
                    TriggerServerEvent("scc:vehicleCrash", { x = coords.x, y = coords.y, z = coords.z }, speed)
                end
            end
        end
    end
end)

-- Shots-fired detector: report gunfire when player fires a weapon (PvP context)
CreateThread(function()
    local lastShotTime = 0
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if IsPedShootingInArea(ped, -3000, -3000, 0, 3000, 3000, 0) or
           IsPedShooting(ped) then
            local now = GetGameTimer()
            if now - lastShotTime > 30000 then -- 30s client-side debounce before server checks zone
                lastShotTime = now
                local coords = GetEntityCoords(ped)
                TriggerServerEvent("scc:shotsFired", { x = coords.x, y = coords.y, z = coords.z })
            end
        end
        Wait(200)
    end
end)

-- Play phone call animation on dispatch notification
RegisterNetEvent("ZestyyMDC:PlayDispatchAnim")
AddEventHandler("ZestyyMDC:PlayDispatchAnim", function()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local dict = "cellphone@"
    local anim = "cellphone_call_listen_base"
    local duration = math.random(5000, 8000)

    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end
    if not HasAnimDictLoaded(dict) then return end

    TaskPlayAnim(ped, dict, anim, 3.0, -4.0, duration, 49, 0, false, false, false)
    Wait(duration)
    if GetCurrentPedWeapon(ped, true) == 0 then
        ClearPedTasks(ped)
    end
end)

