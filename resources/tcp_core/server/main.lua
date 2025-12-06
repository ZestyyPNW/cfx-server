
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Utils.info('tcp_core started.')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Utils.info('tcp_core stopped.')
end)
