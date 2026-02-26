RegisterNetEvent("gpsinfo")
AddEventHandler("gpsinfo", function(model, x, y, z, playerSrc, siren)
    TriggerClientEvent("c_cargps", -1, model, x, y, z, playerSrc, siren)
end)

RegisterNetEvent("gpsinfor")
AddEventHandler("gpsinfor", function(model)
    TriggerClientEvent("c_cargpsr", -1, model)
end)
