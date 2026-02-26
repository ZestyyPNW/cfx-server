-- tcp_core/modules/notifications (server)
-- Send notifications to players

function SendNotification(source, text, duration)
    TriggerClientEvent('tcp_notify:show', source, text, duration or 5000)
end

function SendNotificationAll(text, duration)
    TriggerClientEvent('tcp_notify:show', -1, text, duration or 5000)
end

exports('SendNotification', SendNotification)
exports('SendNotificationAll', SendNotificationAll)
