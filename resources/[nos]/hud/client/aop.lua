local peacetimeNS = true
local maxPTSpeed = 100

local currentAOP = "None Set"
local peacetimeActive = false
local currentPriority = nil
local priorityActive = false

RegisterNetEvent('hud:client:sound', function()
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
end)

RegisterNetEvent('hud:client:env:update', function(newCurAOP, peacetime, priority)
    currentAOP = newCurAOP
    peacetimeActive = peacetime
    currentPriority = priority or "Normal"
    priorityActive = (currentPriority and currentPriority ~= "Normal") or false

    print(currentAOP, peacetimeActive, priorityActive, currentPriority)

    TriggerEvent('hud:client:aop:update', {
        aop = currentAOP,
        peacetime = peacetimeActive,
        priority = {
            enabled = priorityActive,
            name = currentPriority
        },
    })
end)

CreateThread(function()
    local lastSpeedWarning = 0
    local lastPeacetimeWarning = 0
    
    while true do
        local currentTime = GetGameTimer()
        local sleep = 1000

        if peacetimeActive then
            local player = PlayerPedId()

            if peacetimeNS then
                -- Block punching/melee attacks
                if IsControlPressed(0, 106) or IsControlPressed(0, 140) then
                    if currentTime >= lastPeacetimeWarning then
                        ShowInfo("Peacetime is enabled. You cannot cause violence.")
                        lastPeacetimeWarning = currentTime + 2000
                    end
                end

                local data = lib.callback.await("hud:server:hasAce", false, "group.law_enforcement")
                if data then
                    goto continue
                end

                -- Force unarmed weapon
                if GetSelectedPedWeapon(player) ~= GetHashKey('WEAPON_UNARMED') then
                    SetCurrentPedWeapon(player, GetHashKey('WEAPON_UNARMED'), true)
                end

                -- Disable all combat actions
                SetPlayerCanDoDriveBy(PlayerId(), false)
                DisablePlayerFiring(player, true)
                DisableControlAction(0, 140, true) -- Melee R
                DisableControlAction(0, 141, true) -- Melee Q
                DisableControlAction(0, 142, true) -- Melee E
                DisableControlAction(0, 263, true) -- Melee Attack 2
                DisableControlAction(0, 264, true) -- Melee Attack Alt
                DisableControlAction(0, 37, true)  -- Disable weapon wheel (Tab)
                DisableControlAction(0, 24, true)  -- Attack/Shoot
                DisableControlAction(0, 25, true)  -- Aim
                DisableControlAction(0, 106, true) -- Vehicle Mouse Control Override (Punch in vehicle)
                
                ::continue::
            end

            local veh = GetVehiclePedIsIn(player, false)
            if veh and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == player then
                local mph = math.ceil(GetEntitySpeed(veh) * 2.23694) -- mph
                if mph > maxPTSpeed and currentTime >= lastSpeedWarning then
                    ShowInfo("Please keep in mind peacetime is active! Slow down or stop.")
                    lastSpeedWarning = currentTime + 5000
                end
            end

            sleep = 0
        end

        Wait(sleep)
    end
end)

function ShowInfo(text)
    lib.notify({
        description = text,
        type = "info"
    })
end
