local function notify(message)
    TriggerEvent('chat:addMessage', {
        color = {0, 200, 255},
        args = {'INFO', message}
    })
end

local function openGallery()
    if GetResourceState('ox_inventory') ~= 'started' then
        notify('ox_inventory is not running.')
        return
    end

    exports.ox_inventory:openInventory('shop', { type = 'TarkovGuns' })
end

RegisterCommand('tarkovguns', function()
    openGallery()
end, false)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerEvent('chat:addSuggestion', '/tarkovguns', 'Open the Tarkov gun gallery')
end)
