-- TCP DMV Server Logic

if not lib then return end

lib.load('@ND_Core.init')

-- Wait for ND_Core to be ready
CreateThread(function()
    while not NDCore do
        NDCore = exports['ND_Core']
        Wait(100)
    end
end)

---@param charid number
---@return table|nil
function getPersonData(charid)
    if not charid then return nil end
    
    local licenses = MySQL.query.await("SELECT * FROM dmv_licenses WHERE charid = ?", {charid})
    local vehicles = MySQL.query.await("SELECT * FROM dmv_vehicles WHERE owner_id = ?", {charid})
    
    return {
        licenses = licenses or {},
        vehicles = vehicles or {}
    }
end
exports("getPersonData", getPersonData)

---@param plate string
---@return table|nil
function getVehicleData(plate)
    if not plate then return nil end
    
    local result = MySQL.single.await([[
        SELECT v.*, c.firstname, c.lastname 
        FROM dmv_vehicles v 
        JOIN nd_characters c ON v.owner_id = c.charid 
        WHERE v.plate = ?
    ]], {plate})
    
    if result then
        result.owner_name = result.firstname .. " " .. result.lastname
        if result.flags then
            result.flags = json.decode(result.flags)
        end
    end
    
    return result
end
exports("getVehicleData", getVehicleData)

---@param charid number
---@param type string
---@param status string
function updateLicense(charid, type, status)
    local success, result = pcall(function()
        return MySQL.update.await([[
            INSERT INTO dmv_licenses (charid, type, status) 
            VALUES (?, ?, ?) 
            ON DUPLICATE KEY UPDATE status = ?
        ]], {charid, type, status, status})
    end)
    
    if not success then
        error("Database error: " .. tostring(result))
    end
    
    return result and result > 0
end
exports("updateLicense", updateLicense)

---@param plate string
---@param flag string|nil
function flagVehicle(plate, flag)
    local currentFlags = {}
    local result = MySQL.scalar.await("SELECT flags FROM dmv_vehicles WHERE plate = ?", {plate})
    
    if result then
        currentFlags = json.decode(result) or {}
    end
    
    if flag then
        table.insert(currentFlags, flag)
    else
        currentFlags = {} -- Clear flags if nil
    end
    
    local affectedRows = MySQL.update.await("UPDATE dmv_vehicles SET flags = ? WHERE plate = ?", {
        json.encode(currentFlags), plate
    })
    
    return affectedRows > 0
end
exports("flagVehicle", flagVehicle)

-- Handle license test completion
RegisterNetEvent('tcp_dmv:grantLicense', function(licenseType)
    local src = source
    
    -- Ensure NDCore is loaded
    if not NDCore then
        NDCore = exports['ND_Core']
    end
    
    if not NDCore then
        TriggerClientEvent('tcp_dmv:licenseError', src, 'System error: ND_Core not available')
        return
    end
    
    local player = NDCore.getPlayer(src)
    
    if not player then
        TriggerClientEvent('tcp_dmv:licenseError', src, 'Player not found')
        return
    end
    
    if not licenseType or type(licenseType) ~= 'string' then
        TriggerClientEvent('tcp_dmv:licenseError', src, 'Invalid license type')
        return
    end
    
    -- Use license type directly (ND_Core accepts any string)
    local success, err = pcall(function()
        -- Grant license via ND_Core
        player.createLicense(licenseType)
    end)
    
    if not success then
        print(string.format("^1[tcp_dmv]^7 Error granting license via ND_Core to player %d: %s", src, tostring(err)))
        TriggerClientEvent('tcp_dmv:licenseError', src, 'Failed to grant license via ND_Core. Error: ' .. tostring(err))
        return
    end
    
    -- Try to update in DMV database (non-critical, so we don't fail if table doesn't exist)
    local dbSuccess, dbErr = pcall(function()
        updateLicense(player.charid, licenseType, 'valid')
    end)
    
    if not dbSuccess then
        print(string.format("^3[tcp_dmv]^7 Warning: Could not update license in DMV database for player %d: %s", src, tostring(dbErr)))
        print("^3[tcp_dmv]^7 This usually means the dmv_licenses table doesn't exist. License was still granted via ND_Core.")
        -- Don't fail the whole operation, just log the warning
    end
    
    TriggerClientEvent('tcp_dmv:licenseGranted', src, licenseType)
    
    print(string.format("^2[tcp_dmv]^7 Player %s (%d) passed %s test and received license", player.firstname .. ' ' .. player.lastname, src, licenseType))
end)

print("^2[tcp_dmv]^7 API Exports Loaded")
