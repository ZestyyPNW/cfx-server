--[[
    Imperial CAD <-> LASD MDC Bridge
    Wraps ImperialCAD exports to automatically sync calls to web MDC
]]--

local function debugPrint(msg)
    print("^3[IMPERIAL-MDC-BRIDGE]^7 " .. msg)
end

-- Wrapper for Create911Call export
-- Intercepts 911 calls and triggers MDC sync
local original_Create911Call = exports['ImperialCAD']:Create911Call

function Create911CallWithSync(data, callback)
    debugPrint("Intercepting 911 call creation...")

    exports['ImperialCAD']:Create911Call(data, function(success, res)
        if callback then callback(success, res) end

        if success then
            local response = json.decode(res)

            if response and response.response then
                debugPrint("911 Call created successfully. Syncing to MDC...")

                local syncData = {
                    callId = response.response.callId,
                    callnum = response.response.callnum,
                    nature = data.info,
                    priority = 1,
                    status = "PENDING",
                    street = data.street,
                    crossStreet = data.crossStreet,
                    city = data.city,
                    county = data.county,
                    postal = data.postal,
                    info = data.info,
                    name = data.name,
                    phone = data.phone or "(000) 000-0000",
                    units = {}
                }

                TriggerEvent('mdc:sync911Call', syncData)
                debugPrint("MDC sync triggered for call #" .. tostring(response.response.callnum))
            end
        else
            debugPrint("^1911 Call creation failed. Not syncing to MDC.^7")
        end
    end)
end

-- Wrapper for CreateCall export
function CreateCallWithSync(data, callback)
    debugPrint("Intercepting manual call creation...")

    exports['ImperialCAD']:CreateCall(data, function(success, res)
        if callback then callback(success, res) end

        if success then
            local response = json.decode(res)

            if response and response.response then
                debugPrint("Manual call created successfully. Syncing to MDC...")

                local syncData = {
                    callId = response.response.callId,
                    callnum = response.response.callnum,
                    nature = data.nature,
                    priority = data.priority or 3,
                    status = data.status or "PENDING",
                    street = data.street,
                    crossStreet = data.crossStreet,
                    city = data.city,
                    county = data.county,
                    postal = data.postal,
                    info = data.info,
                    name = "OFFICER CREATED",
                    phone = "(000) 000-0000",
                    units = {}
                }

                TriggerEvent('mdc:sync911Call', syncData)
                debugPrint("MDC sync triggered for call #" .. tostring(response.response.callnum))
            end
        else
            debugPrint("^1Manual call creation failed. Not syncing to MDC.^7")
        end
    end)
end

-- Wrapper for AttachCall export
-- Updates MDC when units are attached
function AttachCallWithSync(data, callback)
    debugPrint("Intercepting unit attachment to call...")

    exports['ImperialCAD']:AttachCall(data, function(success, res)
        if callback then callback(success, res) end

        if success then
            debugPrint("Unit attached successfully. Triggering MDC update...")

            TriggerEvent('mdc:syncCallUpdate', {
                callnum = data.callnum,
                users_discordID = data.users_discordID,
                updateType = "UNIT_ATTACHED"
            })
        end
    end)
end

-- Wrapper for DeleteCall export
-- Removes call from MDC when deleted
function DeleteCallWithSync(data, callback)
    debugPrint("Intercepting call deletion...")

    exports['ImperialCAD']:DeleteCall(data, function(success, res)
        if callback then callback(success, res) end

        if success then
            debugPrint("Call deleted successfully. Syncing to MDC...")

            TriggerEvent('mdc:syncCallUpdate', {
                callId = data.callId,
                updateType = "CALL_DELETED"
            })
        end
    end)
end

-- Export wrapped functions for other resources to use
exports('Create911Call', Create911CallWithSync)
exports('CreateCall', CreateCallWithSync)
exports('AttachCall', AttachCallWithSync)
exports('DeleteCall', DeleteCallWithSync)

-- Startup message
Citizen.CreateThread(function()
    Wait(2000)
    print("^2======================================^7")
    print("^2[IMPERIAL-MDC-BRIDGE]^7 Started")
    print("^2[IMPERIAL-MDC-BRIDGE]^7 Version: 1.0.0")
    print("^2[IMPERIAL-MDC-BRIDGE]^7")
    print("^3[USAGE]^7 Other resources should now use:")
    print("^3  exports['imperial-mdc-bridge']:Create911Call(data, callback)^7")
    print("^3  exports['imperial-mdc-bridge']:CreateCall(data, callback)^7")
    print("^3  exports['imperial-mdc-bridge']:AttachCall(data, callback)^7")
    print("^3  exports['imperial-mdc-bridge']:DeleteCall(data, callback)^7")
    print("^2======================================^7")
end)

-- Command to test the bridge
RegisterCommand('testbridge', function(source, args, rawCommand)
    if source ~= 0 then
        print("^1[IMPERIAL-MDC-BRIDGE]^7 This command can only be run from the server console")
        return
    end

    print("^3[IMPERIAL-MDC-BRIDGE]^7 Testing bridge with sample 911 call...")

    Create911CallWithSync({
        name = "TEST CALLER",
        street = "PACIFIC COAST HWY",
        crossStreet = "CORRAL CANYON RD",
        postal = "102",
        city = "Malibu",
        county = "Los Angeles County",
        info = "TEST CALL - 417 245 510 - Road rage shooting"
    }, function(success, res)
        if success then
            print("^2[IMPERIAL-MDC-BRIDGE]^7 Test call created and synced!")
        else
            print("^1[IMPERIAL-MDC-BRIDGE]^7 Test call failed: " .. tostring(res))
        end
    end)
end, false)
