-- tcp_core/modules/notifications (client)
-- Draws a transparent black box with white text in the top-left corner

local activeNotifications = {}
local notificationId = 0

RegisterNetEvent('tcp_notify:show', function(text, duration)
    notificationId = notificationId + 1
    local id = notificationId
    duration = duration or 5000

    activeNotifications[id] = {
        text = text,
        expiry = GetGameTimer() + duration
    }

    SendNUIMessage({ action = 'playNotifySound' })

    SetTimeout(duration, function()
        activeNotifications[id] = nil
    end)
end)

RegisterCommand('testnotify', function(_, args)
    local msg = table.concat(args, ' ')
    if msg == '' then msg = 'Test notification' end
    TriggerEvent('tcp_notify:show', msg, 5000)
end, false)

local function getTextWidth(text)
    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    BeginTextCommandWidth('STRING')
    AddTextComponentSubstringPlayerName(text)
    return EndTextCommandGetWidth(true)
end

Citizen.CreateThread(function()
    while true do
        local hasAny = false
        for _ in pairs(activeNotifications) do
            hasAny = true
            break
        end

        if hasAny then
            local now = GetGameTimer()
            local y = 0.02

            for id, notif in pairs(activeNotifications) do
                if now < notif.expiry then
                    local text = notif.text
                    local padding = 0.006
                    local lineH = 0.018

                    local w = getTextWidth(text)
                    local boxW = w + (padding * 2)
                    local boxH = lineH + (padding * 2)
                    local boxX = 0.01 + (boxW / 2)
                    local boxY = y + (boxH / 2)

                    DrawRect(boxX, boxY, boxW, boxH, 0, 0, 0, 160)

                    SetTextFont(4)
                    SetTextScale(0.35, 0.35)
                    SetTextColour(255, 255, 255, 255)
                    SetTextOutline()
                    SetTextEntry('STRING')
                    AddTextComponentSubstringPlayerName(text)
                    DrawText(0.01 + padding, y + (padding * 0.5))

                    y = y + boxH + 0.004
                end
            end

            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)
