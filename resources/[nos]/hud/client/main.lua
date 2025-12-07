local IS_DEAD = false
local IS_LOADED = false
local HUD_ENABLED = false
local MINIMAP_TOGGLED = false
local RECEIVED_ENV = false

local THRESHOLD_SPEED = 1
local THRESHOLD_FUEL = 1
local THRESHOLD_HEALTH = 5
local THRESHOLD_HEADING = 2

local UPDATE_ONFOOT = 300
local UPDATE_COMPASS = 200
local UPDATE_HEALTH = 250

RegisterNetEvent('hud:client:env:update', function()
    RECEIVED_ENV = true
end)

HUD = {}
HUD.Send = function(action, data)
    SendNUIMessage({
        action = action,
        data = data
    })
end

HUD.Show = function(visible, vehicle)
    if not HUD_ENABLED then return end

    HUD.Send('setVisible', visible)

    SendNUIMessage({
        action = 'setInVehicle',
        data = {
            isInVehicle = vehicle,
            minimap = MINIMAP_TOGGLED
        }
    })

    SetResourceKvp('soc:hud:visibility', visible and '1' or '0')
end

HUD.Init = function()
    local ped = cache.ped
    local inVehicle = IsPedInAnyVehicle(ped, false)

    HUD.Show(HUD_ENABLED, inVehicle)
end

local function setupPlayerStatus()
    if IS_LOADED then
        return
    end

    IS_LOADED = true

    local hudKvp = GetResourceKvpString('soc:hud:visibility') or '1'
    HUD_ENABLED = hudKvp == '1'

    local minimapKvp = GetResourceKvpString('soc:minimap:visibility') or '1'
    MINIMAP_TOGGLED = minimapKvp == '1'

    HUD.Init()

    Wait(300)
    if not RECEIVED_ENV then
        TriggerServerEvent('hud:server:fetchEnvironment')
    end
end

RegisterNetEvent("onResourceStart", function(resourceName)
    if cache.resource ~= resourceName then return end
    Wait(500)

    setupPlayerStatus()
end)

RegisterNetEvent("playerLoaded", function()
    Wait(500)
    setupPlayerStatus()
end)

CreateThread(function()
    if NetworkIsSessionStarted() then
        Wait(500)
        setupPlayerStatus()
    end
end)

RegisterNetEvent('playerUnloaded', function()
    HUD.Show(false, false)
    IS_LOADED = false
end)

CreateThread(function()
    Wait(1000)
    if IS_LOADED then
        setupPlayerStatus()
    end
end)

RegisterNetEvent('hud:client:aop:update', function(data)
    SendNUIMessage({
        action = 'setAOP',
        data = {
            aop = data.aop,
            peacetime = data.peacetime,
            priority = data.priority
        }
    })
end)

-- compass

local function getCardinalFromHeading(heading)
    if heading < 45 or heading >= 315 then
        return 'N'
    end
    if heading >= 45 and heading < 135 then
        return 'W'
    end
    if heading >= 135 and heading < 225 then
        return 'S'
    end
    return 'E'
end

local function getLocation()
    local ped = PlayerPedId()
    if not ped then
        return { a = "", b = "", street = "", crossStreet = "", heading = 0, direction = "" }
    end

    local plyPos = GetEntityCoords(ped)
    local currentStreetHash, intersectStreetHash = GetStreetNameAtCoord(plyPos.x, plyPos.y, plyPos.z)
    local currentStreetName = GetStreetNameFromHashKey(currentStreetHash)
    local zone = GetNameOfZone(plyPos.x, plyPos.y, plyPos.z)
    local area = GetLabelText(zone)

    if not area or area == "" then area = "UNKNOWN" end

    return {
        a = currentStreetName or "",
        b = area,
        street = currentStreetName or "",
        crossStreet = GetStreetNameFromHashKey(intersectStreetHash) or "",
        heading = math.ceil(GetEntityHeading(ped) % 360),
        direction = getCardinalFromHeading(math.ceil(GetEntityHeading(ped) % 360))
    }
end

CreateThread(function()
    local cachedDegrees = nil
    local absoluteHeading = 0.0
    local locationUpdateTimer = 0

    while true do
        if IS_LOADED and IsPedInAnyVehicle(PlayerPedId(), false) then
            local camRot = GetGameplayCamRot(2)
            local currentHeading = (360.0 - ((camRot.z + 360.0) % 360.0)) % 360.0
            local degrees = math.ceil(currentHeading)

            if cachedDegrees == nil then
                cachedDegrees = currentHeading
                absoluteHeading = currentHeading
                locationUpdateTimer = 0

                SendNUIMessage({
                    action = 'setHeading',
                    data = degrees
                })
                SendNUIMessage({
                    action = 'setStreet',
                    data = getLocation()
                })
            else
                local angleDiff = currentHeading - cachedDegrees

                if angleDiff > 180.0 then
                    angleDiff = angleDiff - 360.0
                elseif angleDiff < -180.0 then
                    angleDiff = angleDiff + 360.0
                end

                if cachedDegrees > 270.0 and currentHeading < 90.0 then
                    angleDiff = (currentHeading + 360.0) - cachedDegrees
                elseif cachedDegrees < 90.0 and currentHeading > 270.0 then
                    angleDiff = currentHeading - (cachedDegrees + 360.0)
                end

                absoluteHeading = absoluteHeading + angleDiff
                cachedDegrees = currentHeading

                SendNUIMessage({
                    action = 'setHeading',
                    data = degrees
                })

                locationUpdateTimer = locationUpdateTimer + 1
                if locationUpdateTimer >= 10 then
                    SendNUIMessage({
                        action = 'setStreet',
                        data = getLocation()
                    })
                    locationUpdateTimer = 0
                end
            end

            Wait(200)
        else
            cachedDegrees = nil
            Wait(1000)
        end
    end
end)

CreateThread(function()
    local lastData = {
        inVehicle = false,
        speed = 0,
        fuel = 0,
        health = 0,
        armor = 0,
        heading = 0,
        street = "",
        crossStreet = "",
        rpm = 0,
        gear = 0,
        engineHealth = 100,
        seatbelt = false,
        hudVisible = false
    }

    local nextCompassUpdate = 0
    local nextHealthUpdate = 0
    local nextPostalUpdate = 0
    local nextVehicleUpdate = 0

    local currentPed
    local inVehicle
    local vehicleChanged

    while true do
        local currentTime = GetGameTimer()
        local sleep = inVehicle and 50 or 300

        if not IS_LOADED then
            Wait(1000)
            goto continue
        end

        if not HUD_ENABLED then
            SendNUIMessage({ action = 'setVisible', data = false })
            SendNUIMessage({
                action = 'setInVehicle',
                data = {
                    isInVehicle = false,
                    minimap = MINIMAP_TOGGLED
                }
            })
            Wait(1000)
            goto continue
        end

        currentPed = cache.ped
        inVehicle = IsPedInAnyVehicle(currentPed, false)
        vehicleChanged = inVehicle ~= lastData.inVehicle

        if IsPauseMenuActive() then
            if lastData.hudVisible then
                HUD.Show(false, false)
                lastData.hudVisible = false
            end
        else
            if not IS_DEAD then
                if vehicleChanged or not lastData.hudVisible then
                    HUD.Show(true, inVehicle)
                    lastData.hudVisible = true
                end
            end
        end

        if vehicleChanged then
            HUD.Show(true, inVehicle and not IS_DEAD)
            lastData.inVehicle = inVehicle
        end

        if inVehicle then
            if MINIMAP_TOGGLED then
                DisplayRadar(true)
            else
                if IsVehicleEngineOn(GetVehiclePedIsIn(PlayerPedId(), false)) then
                    DisplayRadar(true)
                else
                    DisplayRadar(false)
                end
            end

            local vehicle = GetVehiclePedIsIn(currentPed, false)
            if vehicle and vehicle ~= 0 then
                local engineOn = GetIsVehicleEngineRunning(vehicle)

                if engineOn ~= lastData.engineOn or IS_DEAD ~= lastData.isDead then
                    HUD.Show(true, engineOn and not IS_DEAD)
                    lastData.engineOn = engineOn
                    lastData.isDead = IS_DEAD
                end

                if currentTime >= nextVehicleUpdate then
                    local fuel = math.floor(GetVehicleFuelLevel(vehicle))
                    local speed = math.floor(GetEntitySpeed(vehicle) * 2.237)
                    local rpm = math.floor(GetVehicleCurrentRpm(vehicle) * 8000)
                    local gear = GetVehicleCurrentGear(vehicle)
                    local engineHealth = math.floor(GetVehicleEngineHealth(vehicle) / 10)
                    local seatbelt = LocalPlayer.state.seatbelt

                    local shouldUpdate = vehicleChanged or
                        math.abs(speed - lastData.speed) >= THRESHOLD_SPEED or
                        math.abs(fuel - lastData.fuel) >= THRESHOLD_FUEL or
                        gear ~= lastData.gear or
                        seatbelt ~= lastData.seatbelt or
                        math.abs(engineHealth - lastData.engineHealth) >= 5

                    if shouldUpdate then
                        if HUD_ENABLED then
                            SendNUIMessage({
                                action = 'updateVehicle',
                                data = {
                                    fuel = fuel,
                                    speed = speed,
                                    rpm = rpm,
                                    gear = gear,
                                    seatbelt = seatbelt,
                                    engineHealth = engineHealth,
                                    engineLight = engineHealth < 60,
                                    oilLight = engineHealth < 40,
                                    batteryLight = engineHealth < 30,
                                }
                            })
                        end

                        lastData.speed = speed
                        lastData.fuel = fuel
                        lastData.rpm = rpm
                        lastData.gear = gear
                        lastData.engineHealth = engineHealth
                        lastData.seatbelt = seatbelt
                    end

                    nextVehicleUpdate = currentTime + 50
                end
            end
        else
            if vehicleChanged then
                HUD.Show(true, false)
                DisplayRadar(MINIMAP_TOGGLED)
            end

            DisplayRadar(MINIMAP_TOGGLED)
        end

        if currentTime >= nextHealthUpdate then
            IS_DEAD = IsEntityDead(currentPed)
            local health = IS_DEAD and 0 or (GetEntityHealth(currentPed) - 100)
            local armor = GetPedArmour(currentPed)

            if math.abs(health - lastData.health) >= THRESHOLD_HEALTH or
                armor ~= lastData.armor or vehicleChanged then
                if HUD_ENABLED then
                    SendNUIMessage({
                        action = 'setStatuses',
                        data = {
                            health = health,
                            armor = armor,
                        }
                    })
                end

                lastData.health = health
                lastData.armor = armor
            end

            nextHealthUpdate = currentTime + UPDATE_HEALTH
        end

        if currentTime >= nextPostalUpdate then
            if HUD_ENABLED then
                UpdatePostals()
                nextPostalUpdate = currentTime + (UPDATE_ONFOOT or 300)
            end
        end

        if currentTime >= nextCompassUpdate then
            local compass = getLocation()

            if math.abs(compass.heading - lastData.heading) >= THRESHOLD_HEADING or
                compass.street ~= lastData.street or
                compass.crossStreet ~= lastData.crossStreet then
                if HUD_ENABLED then
                    SendNUIMessage({
                        action = 'setCompass',
                        data = {
                            heading = compass.heading,
                            street = compass.street,
                            crossStreet = compass.crossStreet
                        }
                    })
                end

                lastData.heading = compass.heading
                lastData.street = compass.street
                lastData.crossStreet = compass.crossStreet
            end

            nextCompassUpdate = currentTime + UPDATE_COMPASS
        end

        ::continue::
        Wait(sleep)
    end
end)

RegisterCommand('togglehud', function()
    HUD_ENABLED = not HUD_ENABLED
    SetResourceKvp('soc:hud:visibility', HUD_ENABLED and '1' or '0')
    if not HUD_ENABLED then
        SendNUIMessage({ action = 'setVisible', data = false })
        SendNUIMessage({
            action = 'setInVehicle',
            data = {
                isInVehicle = false,
                minimap = MINIMAP_TOGGLED
            }
        })
    else
        HUD.Init()
    end
end, false)

RegisterCommand('toggleminimap', function()
    MINIMAP_TOGGLED = not MINIMAP_TOGGLED
    SetResourceKvp('soc:minimap:visibility', MINIMAP_TOGGLED and '1' or '0')
    if MINIMAP_TOGGLED then
        DisplayRadar(true)
        TriggerEvent('chat:addMessage', { args = { '^2Minimap', 'Always ON' } })
    else
        DisplayRadar(false)
        TriggerEvent('chat:addMessage', { args = { '^2Minimap', 'Vehicle/Engine Only' } })
    end
end, false)
